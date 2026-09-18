import { test } from 'node:test';
import assert from 'node:assert/strict';
import { discover, progressOnRoute, decodePolyline, unverified } from '../src/discovery.js';
import { mapPlace } from '../src/google.js';
import { type DiscoveryEvent, type DiscoveryInput, type IntentProvider, type Place, type PlacesProvider, type RouteProvider } from '../src/contracts.js';

const place = (id: string, longitude = -120.2): Place => ({ id, name: id, subtitle: '', coordinate: { latitude: 38.5, longitude }, category: 'coffee', mapsURI: '', photoAttributions: [], hours: [], amenities: [], reviews: [] });
const input: DiscoveryInput = { origin: { id: 'origin' }, destination: { id: 'destination' }, stops: [], departure: '2026-09-18T09:30:00Z', preferences: { categories: ['coffee'], customRequest: '', maxDetourMinutes: 20 }, reviewedIDs: [], coveredCategories: [] };
const intent: IntentProvider = { interpret: async () => ({ queries: ['coffee'], categories: ['coffee'], requirements: [], timing: 'any', visitMinutes: 25 }) };
const makeProviders = (places: Place[]) => ({
  places: {
    autocomplete: async () => [], details: async (id: string) => place(id), nearby: async () => places,
    searchAlongRoute: async () => places, photo: async () => ({ uri: 'https://example.com' }),
  } satisfies PlacesProvider,
  routes: { route: async request => ({ encodedPolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@', durationSeconds: 1000 + request.stops.length * 240, distanceMeters: 50000, legs: Array.from({ length: request.stops.length + 1 }, () => ({ durationSeconds: 500, distanceMeters: 25000 })), calculatedAt: new Date().toISOString() }) } satisfies RouteProvider,
  intent,
});

test('polyline decoding and segment projection follow a bent route', () => {
  const points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
  assert.deepEqual(points[0], { latitude: 38.5, longitude: -120.2 });
  assert.equal(points.length, 3);
  assert.equal(progressOnRoute(points[0]!, points), 0);
  assert.equal(progressOnRoute(points[2]!, points), 1);
  assert.throws(() => decodePolyline('_'));
});
test('discovery deduplicates and excludes accepted, skipped and endpoint IDs', async () => {
  const events: DiscoveryEvent[] = [];
  const providers = makeProviders([place('a'), place('a'), place('b'), place('origin'), place('destination'), place('accepted')]);
  await discover({ ...input, reviewedIDs: ['b'], stops: [{ place: { id: 'accepted' }, visitMinutes: 20 }] }, providers, e => events.push(e), new AbortController().signal);
  const complete = events.find(e => e.type === 'complete');
  assert.equal(complete?.type, 'complete');
  if (complete?.type === 'complete') {
    assert.deepEqual(complete.suggestions.map(s => s.place.id), ['a']);
    assert.equal(complete.suggestions[0]?.detourSeconds, 240);
  }
});
test('strict detour limit removes candidates and caps the batch at six', async () => {
  const events: DiscoveryEvent[] = [];
  const providers = makeProviders(Array.from({ length: 25 }, (_, i) => place(String(i))));
  await discover(input, providers, e => events.push(e), new AbortController().signal);
  assert.equal(events.filter(e => e.type === 'candidate').length, 6);
  events.length = 0;
  await discover({ ...input, preferences: { ...input.preferences, maxDetourMinutes: 1 } }, providers, e => events.push(e), new AbortController().signal);
  assert.equal(events.filter(e => e.type === 'candidate').length, 0);
});
test('AI outage retains categories and does not pretend to interpret a custom-only request', async () => {
  const providers = makeProviders([place('a')]);
  providers.intent = { interpret: async () => { throw Error('offline'); } };
  const events: DiscoveryEvent[] = [];
  await discover({ ...input, preferences: { ...input.preferences, customRequest: 'pies' } }, providers, e => events.push(e), new AbortController().signal);
  assert.equal(events.some(e => e.type === 'warning'), true);
  assert.equal(events.some(e => e.type === 'candidate'), true);
  events.length = 0;
  await discover({ ...input, preferences: { ...input.preferences, categories: [], customRequest: 'pies' } }, providers, e => events.push(e), new AbortController().signal);
  assert.equal(events.some(e => e.type === 'candidate'), false);
});
test('unknown amenities stay unknown and explicitly disallowed dogs are excluded', async () => {
  assert.deepEqual(unverified(place('a'), ['dogs', 'children', 'charging', 'toilets']), ['dogs', 'children', 'charging', 'toilets']);
  const providers = makeProviders([{ ...place('a'), allowsDogs: false }, { ...place('b'), allowsDogs: true }]);
  providers.intent = { interpret: async () => ({ queries: ['dog friendly coffee'], categories: ['coffee'], requirements: ['dogs'], timing: 'any', visitMinutes: null }) };
  const events: DiscoveryEvent[] = [];
  await discover({ ...input, preferences: { ...input.preferences, customRequest: 'dog friendly' } }, providers, e => events.push(e), new AbortController().signal);
  assert.deepEqual(events.flatMap(e => e.type === 'candidate' ? [e.suggestion.place.id] : []), ['b']);
});
test('cancellation stops discovery before subsequent provider calls', async () => {
  const controller = new AbortController(); controller.abort();
  await assert.rejects(discover(input, makeProviders([place('a')]), () => {}, controller.signal));
});
test('provider mapping does not invent ratings, hours or amenities', () => {
  const mapped = mapPlace({ id: 'a', location: { latitude: -33, longitude: 20 }, displayName: { text: 'Coffee' } });
  assert.equal(mapped.rating, undefined);
  assert.deepEqual(mapped.hours, []);
  assert.deepEqual(mapped.amenities, []);
  assert.equal(mapped.allowsDogs, undefined);
});

test('routing failures are not presented as an empty preference match', async () => {
  const providers = makeProviders([place('a')]);
  const original = providers.routes.route;
  providers.routes.route = async request => {
    if (request.stops.length) throw new Error('provider offline');
    return original(request);
  };
  await assert.rejects(discover(input, providers, () => {}, new AbortController().signal), /could not verify driving times/);
});
test('failure of every search remains a retryable error', async () => {
  const providers = makeProviders([]);
  providers.places.searchAlongRoute = async () => { throw new Error('offline'); };
  await assert.rejects(discover(input, providers, () => {}, new AbortController().signal), /Place searches could not finish/);
});

test('equally matched verified stops prefer less additional driving', async () => {
  const providers = makeProviders([place('long'), place('short')]);
  const original = providers.routes.route;
  providers.routes.route = async request => ({ ...await original(request), durationSeconds: 1000 + (request.stops[0]?.place.id === 'long' ? 900 : request.stops.length ? 120 : 0) });
  const events: DiscoveryEvent[] = [];
  await discover(input, providers, e => events.push(e), new AbortController().signal);
  assert.deepEqual(events.flatMap(e => e.type === 'candidate' ? [e.suggestion.place.id] : []), ['short', 'long']);
});
