import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/app.js';
import type { Place, PlacesProvider, RouteProvider, IntentProvider } from '../src/contracts.js';

const place: Place = { id: 'p1', name: 'A place', subtitle: 'South Africa', coordinate: { latitude: -33.9, longitude: 18.4 }, category: 'coffee', mapsURI: '', photoAttributions: [], hours: [], amenities: [], reviews: [] };
const places: PlacesProvider = { autocomplete: async () => [{ id: place.id, name: place.name, subtitle: place.subtitle }], details: async () => place, nearby: async () => [place], searchAlongRoute: async () => [], photo: async () => ({ uri: 'https://example.com/photo' }) };
const routes: RouteProvider = { route: async () => ({ encodedPolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@', durationSeconds: 1000, distanceMeters: 20000, legs: [{ durationSeconds: 1000, distanceMeters: 20000 }], calculatedAt: new Date().toISOString() }) };
const intent: IntentProvider = { interpret: async () => ({ queries: [], categories: [], requirements: [], timing: 'any', visitMinutes: null }) };
const request = { origin: { id: 'o' }, destination: { id: 'd' }, stops: [], departure: '2026-09-18T09:30:00Z' };

test('API validates inputs and preserves typed error envelopes', async () => {
  const app = buildApp({ places, routes, intent });
  try {
    const invalid = await app.inject({ method: 'POST', url: '/v1/route', payload: {} });
    assert.equal(invalid.statusCode, 400);
    assert.equal(invalid.json().code, 'invalid_request');
    const route = await app.inject({ method: 'POST', url: '/v1/route', payload: request });
    assert.equal(route.statusCode, 200);
    assert.equal(route.json().legs.length, 1);
    const tooMany = await app.inject({ method: 'POST', url: '/v1/route', payload: { ...request, stops: Array.from({ length: 13 }, () => ({ place: { id: 'a' }, visitMinutes: 20 })) } });
    assert.equal(tooMany.statusCode, 400);
  } finally { await app.close(); }
});
test('private development token protects paid endpoints, not health', async () => {
  const app = buildApp({ places, routes, intent }, 'test-token');
  try {
    assert.equal((await app.inject('/health')).statusCode, 200);
    assert.equal((await app.inject('/v1/places/p1')).statusCode, 401);
    assert.equal((await app.inject({ url: '/v1/places/p1', headers: { authorization: 'Bearer test-token' } })).statusCode, 200);
  } finally { await app.close(); }
});
test('discovery sends parseable NDJSON with a terminal completion event', async () => {
  const app = buildApp({ places, routes, intent });
  try {
    const response = await app.inject({ method: 'POST', url: '/v1/discover', payload: { ...request, preferences: { categories: ['coffee'], maxDetourMinutes: 20, customRequest: '' }, reviewedIDs: [], coveredCategories: [] } });
    assert.equal(response.statusCode, 200);
    assert.match(response.headers['content-type'] as string, /x-ndjson/);
    const events = response.body.trim().split('\n').map(line => JSON.parse(line));
    assert.equal(events.at(-1).type, 'complete');
    assert.deepEqual(events.at(-1).suggestions, []);
  } finally { await app.close(); }
});
