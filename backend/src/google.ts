import { type Attribution, type Category, type Coordinate, type Place, type PlacesProvider, type RouteInput, type RoutePlan, type RouteProvider, type SearchResult, ServiceError } from './contracts.js';

interface GooglePlace {
  id: string; displayName?: { text: string }; formattedAddress?: string;
  location?: Coordinate; primaryType?: string; types?: string[];
  rating?: number; userRatingCount?: number; googleMapsUri?: string;
  photos?: { name: string; googleMapsUri?: string; authorAttributions?: { displayName: string; uri?: string; photoUri?: string }[] }[];
  regularOpeningHours?: { weekdayDescriptions?: string[] };
  currentOpeningHours?: { openNow?: boolean; weekdayDescriptions?: string[] };
  allowsDogs?: boolean; goodForChildren?: boolean; restroom?: boolean;
  parkingOptions?: Record<string, boolean>;
  reviews?: { text?: { text: string }; authorAttribution: { displayName: string; uri?: string; photoUri?: string }; relativePublishTimeDescription?: string; googleMapsUri?: string }[];
}
const fields = 'id,displayName,formattedAddress,location,primaryType,types,rating,userRatingCount,googleMapsUri,photos,regularOpeningHours,currentOpeningHours,allowsDogs,goodForChildren,restroom,parkingOptions';
const seconds = (s: string | undefined) => Number((s || '0s').replace(/s$/, ''));
const attribution = (a: { displayName: string; uri?: string; photoUri?: string }): Attribution => ({ name: a.displayName, uri: a.uri, photoURI: a.photoUri });

export function categoryFor(types: string[]): Category {
  if (types.some(t => /cafe|coffee/.test(t))) return 'coffee';
  if (types.some(t => /restaurant|bakery|food|meal/.test(t))) return 'food';
  if (types.some(t => /gas_station|charging/.test(t))) return 'fuel';
  if (types.some(t => /restroom/.test(t))) return 'toilets';
  if (types.some(t => /playground/.test(t))) return 'playgrounds';
  return 'scenic';
}
export function mapPlace(p: GooglePlace): Place {
  if (!p.id || !p.location) throw new ServiceError('invalid_place', 'This place has no usable location.');
  const amenities: string[] = [];
  if (p.allowsDogs === true) amenities.push('Dogs welcome');
  if (p.goodForChildren === true) amenities.push('Good for children');
  if (p.restroom === true) amenities.push('Toilets');
  if (p.types?.includes('electric_vehicle_charging_station')) amenities.push('EV charging');
  if (p.parkingOptions && Object.values(p.parkingOptions).some(Boolean)) amenities.push('Parking');
  return {
    id: p.id, name: p.displayName?.text || 'Unnamed place', subtitle: p.formattedAddress || '',
    coordinate: p.location, category: categoryFor([p.primaryType || '', ...(p.types || [])]),
    rating: p.rating, ratingCount: p.userRatingCount, mapsURI: p.googleMapsUri || `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(p.displayName?.text || 'Place')}&query_place_id=${encodeURIComponent(p.id)}`,
    photoName: p.photos?.[0]?.name, photoURI: p.photos?.[0]?.googleMapsUri, photoAttributions: (p.photos?.[0]?.authorAttributions || []).map(attribution),
    hours: p.currentOpeningHours?.weekdayDescriptions || p.regularOpeningHours?.weekdayDescriptions || [],
    openNow: p.currentOpeningHours?.openNow, amenities, allowsDogs: p.allowsDogs, goodForChildren: p.goodForChildren,
    reviews: (p.reviews || []).slice(0, 2).map(r => ({ text: r.text?.text || '', author: attribution(r.authorAttribution), relativeTime: r.relativePublishTimeDescription || '', uri: r.googleMapsUri })).filter(r => r.text),
  };
}

export class GoogleProvider implements PlacesProvider, RouteProvider {
  constructor(private apiKey = process.env.GOOGLE_MAPS_API_KEY) {}
  private async request<T>(url: string, body: unknown | undefined, mask: string | undefined, signal: AbortSignal): Promise<T> {
    if (!this.apiKey) throw new ServiceError('not_configured', 'Live services are not configured yet.', 503);
    const combined = AbortSignal.any([signal, AbortSignal.timeout(20_000)]);
    const response = await fetch(url, {
      method: body === undefined ? 'GET' : 'POST', signal: combined,
      headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': this.apiKey, ...(mask ? { 'X-Goog-FieldMask': mask } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!response.ok) throw new ServiceError(response.status === 429 ? 'provider_busy' : 'provider_error', response.status === 429 ? 'The map service is busy. Please try again shortly.' : 'The map service could not complete this request. Please retry.');
    return response.json() as Promise<T>;
  }
  async autocomplete(input: string, sessionToken: string, signal: AbortSignal): Promise<SearchResult[]> {
    const response = await this.request<{ suggestions?: { placePrediction?: { placeId: string; structuredFormat?: { mainText?: { text: string }; secondaryText?: { text: string } } } }[] }>(
      'https://places.googleapis.com/v1/places:autocomplete', { input, includedRegionCodes: ['za'], languageCode: 'en', sessionToken }, undefined, signal);
    return (response.suggestions || []).flatMap(s => s.placePrediction ? [{ id: s.placePrediction.placeId, name: s.placePrediction.structuredFormat?.mainText?.text || input, subtitle: s.placePrediction.structuredFormat?.secondaryText?.text || '' }] : []);
  }
  async details(id: string, signal: AbortSignal, sessionToken?: string): Promise<Place> {
    const query = new URLSearchParams({ languageCode: 'en', ...(sessionToken ? { sessionToken } : {}) });
    return mapPlace(await this.request<GooglePlace>(`https://places.googleapis.com/v1/places/${encodeURIComponent(id)}?${query}`, undefined, `${fields},reviews`, signal));
  }
  async nearby(coordinate: Coordinate, signal: AbortSignal): Promise<Place[]> {
    const response = await this.request<{ places?: GooglePlace[] }>('https://places.googleapis.com/v1/places:searchNearby', {
      includedTypes: ['cafe', 'tourist_attraction', 'park'], maxResultCount: 8, languageCode: 'en',
      locationRestriction: { circle: { center: coordinate, radius: 15000 } },
    }, fields.split(',').map(f => `places.${f}`).join(','), signal);
    return (response.places || []).filter(p => p.location).map(mapPlace);
  }
  async searchAlongRoute(query: string, polyline: string, signal: AbortSignal): Promise<Place[]> {
    const response = await this.request<{ places?: GooglePlace[] }>('https://places.googleapis.com/v1/places:searchText', {
      textQuery: query, pageSize: 8, languageCode: 'en', regionCode: 'ZA',
      searchAlongRouteParameters: { polyline: { encodedPolyline: polyline } },
    }, fields.split(',').map(f => `places.${f}`).join(','), signal);
    return (response.places || []).filter(p => p.location).map(mapPlace);
  }
  async photo(name: string, signal: AbortSignal): Promise<{ uri: string }> {
    if (!/^places\/[^/]+\/photos\/[^/]+$/.test(name)) throw new ServiceError('invalid_photo', 'Invalid photo reference.', 400);
    const result = await this.request<{ photoUri: string }>(`https://places.googleapis.com/v1/${name}/media?maxWidthPx=1000&skipHttpRedirect=true`, undefined, undefined, signal);
    return { uri: result.photoUri };
  }
  async route(input: RouteInput, signal: AbortSignal): Promise<RoutePlan> {
    const waypoint = (p: RouteInput['origin']) => p.id === 'current-location' && p.coordinate
      ? { location: { latLng: p.coordinate } } : { placeId: p.id };
    const response = await this.request<{ routes?: { duration: string; distanceMeters: number; polyline: { encodedPolyline: string }; legs: { duration: string; distanceMeters: number }[] }[] }>(
      'https://routes.googleapis.com/directions/v2:computeRoutes', {
        origin: waypoint(input.origin), destination: waypoint(input.destination),
        intermediates: input.stops.map(s => waypoint(s.place)), travelMode: 'DRIVE', routingPreference: 'TRAFFIC_UNAWARE',
        computeAlternativeRoutes: false, languageCode: 'en-ZA', units: 'METRIC',
      }, 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.duration,routes.legs.distanceMeters', signal);
    const route = response.routes?.[0];
    if (!route?.legs.length) throw new ServiceError('no_route', 'No driving route connects these places. Try another destination.', 422);
    return { encodedPolyline: route.polyline.encodedPolyline, durationSeconds: seconds(route.duration), distanceMeters: route.distanceMeters, legs: route.legs.map(l => ({ durationSeconds: seconds(l.duration), distanceMeters: l.distanceMeters })), calculatedAt: new Date().toISOString() };
  }
}
