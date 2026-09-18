import { type Category, type Coordinate, type DiscoveryEvent, type DiscoveryInput, type Intent, type IntentProvider, type Place, type PlacesProvider, type RouteProvider, type Suggestion, ServiceError } from './contracts.js';

const categoryQueries: Record<Category, string> = {
  coffee: 'coffee shop', food: 'restaurant bakery farm stall', scenic: 'scenic viewpoint nature attraction',
  fuel: 'petrol station', toilets: 'public restroom rest stop', playgrounds: 'playground family park',
};

export function decodePolyline(encoded: string): Coordinate[] {
  let index = 0, latitude = 0, longitude = 0;
  const points: Coordinate[] = [];
  function component(): number {
    let value = 0, shift = 0, byte = 0;
    do {
      if (index >= encoded.length || shift > 30) throw new Error('Invalid route polyline');
      byte = encoded.charCodeAt(index++) - 63;
      value |= (byte & 31) << shift; shift += 5;
    } while (byte >= 32);
    return value & 1 ? ~(value >> 1) : value >> 1;
  }
  while (index < encoded.length) {
    latitude += component(); longitude += component();
    points.push({ latitude: latitude / 1e5, longitude: longitude / 1e5 });
  }
  return points;
}

// Project onto route segments, not the straight line between the trip endpoints.
export function progressOnRoute(point: Coordinate, route: Coordinate[]): number {
  let nearest = Infinity, best = 0, travelled = 0;
  const cos = Math.cos(point.latitude * Math.PI / 180);
  for (let i = 1; i < route.length; i++) {
    const a = route[i - 1]!, b = route[i]!;
    const dx = (b.longitude - a.longitude) * cos, dy = b.latitude - a.latitude;
    const length2 = dx * dx + dy * dy;
    const t = length2 ? Math.max(0, Math.min(1, (((point.longitude - a.longitude) * cos) * dx + (point.latitude - a.latitude) * dy) / length2)) : 0;
    const distance = ((point.longitude - a.longitude) * cos - t * dx) ** 2 + (point.latitude - a.latitude - t * dy) ** 2;
    const length = Math.sqrt(length2);
    if (distance < nearest) { nearest = distance; best = travelled + t * length; }
    travelled += length;
  }
  return travelled ? best / travelled : 0;
}

export function unverified(place: Place, requirements: Intent['requirements']): string[] {
  return requirements.filter(r => {
    switch (r) {
      case 'dogs': return place.allowsDogs !== true;
      case 'children': return place.goodForChildren !== true && place.category !== 'playgrounds';
      case 'charging': return !place.amenities.includes('EV charging');
      case 'toilets': return !place.amenities.includes('Toilets');
    }
  });
}
function conflicts(place: Place, intent: Intent): boolean {
  return (intent.requirements.includes('dogs') && place.allowsDogs === false) ||
    (intent.requirements.includes('children') && place.goodForChildren === false);
}

export async function discover(input: DiscoveryInput, providers: { places: PlacesProvider; routes: RouteProvider; intent: IntentProvider }, emit: (event: DiscoveryEvent) => void, signal: AbortSignal): Promise<void> {
  signal.throwIfAborted();
  let intent: Intent = { queries: [], categories: input.preferences.categories, requirements: [], timing: 'any', visitMinutes: null };
  emit({ type: 'progress', message: 'Understanding your kind of stop', count: 0 });
  if (input.preferences.customRequest.trim()) {
    try { intent = await providers.intent.interpret(input.preferences.customRequest, input.preferences.categories, signal); }
    catch (error) {
      signal.throwIfAborted();
      emit({ type: 'warning', message: 'Custom matching is unavailable. Showing category matches; retry to use your request.' });
      // Do not silently treat a custom-only request as successfully interpreted.
      if (!input.preferences.categories.length) { emit({ type: 'complete', suggestions: [] }); return; }
    }
  }
  const baseline = await providers.routes.route(input, signal);
  const points = decodePolyline(baseline.encodedPolyline);
  const queries = [...new Set([...intent.queries, ...[...new Set([...input.preferences.categories, ...intent.categories])].map(c => categoryQueries[c])])].slice(0, 6);
  if (!queries.length) queries.push(categoryQueries.scenic);
  const excluded = new Set([...input.reviewedIDs, input.origin.id, input.destination.id, ...input.stops.map(s => s.place.id)]);
  const found = new Map<string, Place>();
  let failedSearches = 0;
  for (const query of queries) {
    signal.throwIfAborted();
    emit({ type: 'progress', message: `Looking for ${query} along your route`, count: found.size });
    try {
      for (const place of await providers.places.searchAlongRoute(query, baseline.encodedPolyline, signal)) {
        if (!excluded.has(place.id) && !conflicts(place, intent)) found.set(place.id, place);
      }
    } catch { signal.throwIfAborted(); failedSearches++; }
  }
  if (failedSearches === queries.length) throw new ServiceError('search_unavailable', 'Place searches could not finish. Please retry.');
  if (failedSearches) emit({ type: 'warning', message: 'Some place searches could not finish. You can retry for more stops.' });
  const progress = (place: Place) => progressOnRoute(place.coordinate, points);
  const timingTarget = { early: 0.15, middle: 0.5, late: 0.85, any: 0.5 }[intent.timing];
  const stops = await Promise.all(input.stops.map(s => s.place.coordinate ? Promise.resolve(s.place.coordinate) : providers.places.details(s.place.id, signal).then(p => p.coordinate)));
  const acceptedProgress = stops.map(p => progressOnRoute(p, points));
  const score = (p: Place) =>
      (intent.categories.includes(p.category) || input.preferences.categories.includes(p.category) ? 3 : 0) +
      (!input.coveredCategories.includes(p.category) ? 1 : 0) + (p.rating || 0) / 5 -
      unverified(p, intent.requirements).length * 2 - (intent.timing === 'any' ? 0 : Math.abs(progress(p) - timingTarget) * 3) +
      (acceptedProgress.length ? Math.min(0.25, ...acceptedProgress.map(s => Math.abs(progress(p) - s))) * 2 : 0);
  const sorted = [...found.values()].sort((a, b) => score(b) - score(a)).slice(0, 18);
  const suggestions: Suggestion[] = [];
  let failedRoutes = 0;
  // Bound expensive route calls; check three candidates at a time.
  for (let offset = 0; offset < sorted.length && suggestions.length < 6; offset += 3) {
    const candidates = sorted.slice(offset, offset + 3);
    const checked = await Promise.all(candidates.map(async place => {
      const routeProgress = progress(place);
      const insertionIndex = stops.filter(p => progressOnRoute(p, points) <= routeProgress).length;
      const candidateStops = [...input.stops];
      candidateStops.splice(insertionIndex, 0, { place: { id: place.id, coordinate: place.coordinate }, visitMinutes: intent.visitMinutes || 20 });
      try {
        const route = await providers.routes.route({ ...input, stops: candidateStops }, signal);
        const detourSeconds = Math.max(0, route.durationSeconds - baseline.durationSeconds);
        if (detourSeconds > input.preferences.maxDetourMinutes * 60) return undefined;
        const arrivalOffsetSeconds = route.legs.slice(0, insertionIndex + 1).reduce((sum, leg) => sum + leg.durationSeconds, 0) + input.stops.slice(0, insertionIndex).reduce((sum, s) => sum + s.visitMinutes * 60, 0);
        const missing = unverified(place, intent.requirements);
        const category = place.category === 'scenic' ? 'A scenic stop' : `A ${place.category === 'playgrounds' ? 'playground' : place.category} stop`;
        return { place, detourSeconds, arrivalOffsetSeconds, insertionIndex, visitMinutes: intent.visitMinutes || 20,
          reason: `${category} ${Math.round(routeProgress * 100)}% along your journey, adding ${Math.ceil(detourSeconds / 60)} min of driving.${missing.length ? ' Some requested amenities are not confirmed.' : ''}`,
          unverifiedRequirements: missing,
        } satisfies Suggestion;
      } catch { signal.throwIfAborted(); failedRoutes++; return undefined; }
    }));
    // Rank each verified group by fit and actual added driving, while streaming
    // promptly instead of waiting for the entire provider-call budget.
    const verified = checked.filter((s): s is Suggestion => s !== undefined);
    const verifiedScore = (s: Suggestion) => score(s.place) - s.detourSeconds / Math.max(60, input.preferences.maxDetourMinutes * 60);
    verified.sort((a, b) => verifiedScore(b) - verifiedScore(a));
    for (const suggestion of verified) if (suggestions.length < 6) {
      suggestions.push(suggestion); emit({ type: 'candidate', suggestion });
      emit({ type: 'progress', message: 'Checking driving time and route fit', count: suggestions.length });
    }
  }
  signal.throwIfAborted();
  if (failedRoutes > 0) {
    if (!suggestions.length) throw new ServiceError('routes_unavailable', 'We could not verify driving times for these stops. Please retry.');
    emit({ type: 'warning', message: 'Some stops could not be checked for driving time. Retry to look for more.' });
  }
  emit({ type: 'complete', suggestions });
}
