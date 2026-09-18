import Fastify from 'fastify';
import rateLimit from '@fastify/rate-limit';
import { timingSafeEqual } from 'node:crypto';
import { z } from 'zod';
import { CoordinateSchema, DiscoveryInputSchema, RouteInputSchema, ServiceError, type IntentProvider, type PlacesProvider, type RouteProvider } from './contracts.js';
import { discover } from './discovery.js';
import { GoogleProvider } from './google.js';
import { OpenAIIntentProvider } from './intent.js';

export function buildApp(dependencies?: { places: PlacesProvider; routes: RouteProvider; intent: IntentProvider }, accessToken = process.env.DETOUR_ACCESS_TOKEN) {
  const google = new GoogleProvider();
  const providers = dependencies || { places: google, routes: google, intent: new OpenAIIntentProvider() };
  const app = Fastify({ bodyLimit: 32_768, logger: false, requestTimeout: 120_000 });
  app.register(rateLimit, { max: 90, timeWindow: '1 minute' });
  app.addHook('onRequest', async (request, reply) => {
    if (!accessToken || request.url === '/health') return;
    const given = Buffer.from(request.headers.authorization || '');
    const expected = Buffer.from(`Bearer ${accessToken}`);
    if (given.length !== expected.length || !timingSafeEqual(given, expected)) return reply.code(401).send({ code: 'unauthorized', message: 'This development server requires an access token.' });
  });
  app.addHook('onResponse', async (request, reply) => {
    // Do not log URLs, bodies, coordinates, prompts, tokens or provider responses.
    if (process.env.NODE_ENV !== 'test') console.info(JSON.stringify({ event: 'request', operation: request.routeOptions.url, status: reply.statusCode, elapsedMs: Math.round(reply.elapsedTime) }));
  });
  app.setErrorHandler((error, _request, reply) => {
    if ((error as { statusCode?: number }).statusCode === 429) return reply.code(429).send({ code: 'rate_limited', message: 'Please wait a moment before trying again.' });
    if (error instanceof z.ZodError) return reply.code(400).send({ code: 'invalid_request', message: 'Check the locations and trip preferences, then try again.' });
    if (error instanceof ServiceError) return reply.code(error.status).send({ code: error.code, message: error.message });
    return reply.code(502).send({ code: 'service_error', message: 'We could not finish this request. Please try again.' });
  });
  const withSignal = async <T>(reply: { raw: import('node:http').ServerResponse }, work: (signal: AbortSignal) => Promise<T>) => {
    const controller = new AbortController();
    const abort = () => controller.abort();
    reply.raw.on('close', abort);
    try { return await work(AbortSignal.any([controller.signal, AbortSignal.timeout(90_000)])); }
    finally { reply.raw.off('close', abort); }
  };
  app.get('/health', async () => ({ status: 'ok', version: 1 }));
  app.post('/v1/autocomplete', async (request, reply) => {
    const body = z.object({ input: z.string().min(2).max(160), sessionToken: z.string().uuid() }).parse(request.body);
    return withSignal(reply, signal => providers.places.autocomplete(body.input, body.sessionToken, signal));
  });
  app.get('/v1/places/:id', async (request, reply) => {
    const { id } = z.object({ id: z.string().min(1).max(256) }).parse(request.params);
    const { sessionToken } = z.object({ sessionToken: z.string().uuid().optional() }).parse(request.query);
    return withSignal(reply, signal => providers.places.details(id, signal, sessionToken));
  });
  app.post('/v1/nearby', async (request, reply) => {
    const coordinate = CoordinateSchema.parse(request.body);
    return withSignal(reply, signal => providers.places.nearby(coordinate, signal));
  });
  app.post('/v1/photo', async (request, reply) => {
    const { name } = z.object({ name: z.string().max(1000) }).parse(request.body);
    return withSignal(reply, signal => providers.places.photo(name, signal));
  });
  app.post('/v1/route', async (request, reply) => {
    const input = RouteInputSchema.parse(request.body);
    return withSignal(reply, signal => providers.routes.route(input, signal));
  });
  app.post('/v1/discover', { config: { rateLimit: { max: 6, timeWindow: '1 minute' } } }, async (request, reply) => {
    const input = DiscoveryInputSchema.parse(request.body);
    if (input.stops.length >= 12) throw new ServiceError('stop_limit', 'This driving day already has twelve stops.', 400);
    const controller = new AbortController();
    reply.raw.on('close', () => controller.abort());
    reply.hijack();
    reply.raw.writeHead(200, { 'Content-Type': 'application/x-ndjson', 'Cache-Control': 'no-store', 'X-Accel-Buffering': 'no' });
    const emit = (event: unknown) => { if (!reply.raw.destroyed) reply.raw.write(`${JSON.stringify(event)}\n`); };
    try { await discover(input, providers, emit, AbortSignal.any([controller.signal, AbortSignal.timeout(90_000)])); }
    catch (error) {
      if (!controller.signal.aborted) emit({ type: 'error', code: error instanceof ServiceError ? error.code : 'discovery_failed', message: error instanceof ServiceError ? error.message : 'The search could not finish. Please retry.' });
    } finally { reply.raw.end(); }
  });
  return app;
}
