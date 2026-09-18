import { buildApp } from './app.js';

if (process.env.NODE_ENV === 'production' && !process.env.DETOUR_ACCESS_TOKEN) {
  throw new Error('Set DETOUR_ACCESS_TOKEN before deploying this private development API.');
}
const app = buildApp();
await app.listen({ port: Number(process.env.PORT || 8080), host: '0.0.0.0' });
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, async () => { await app.close(); process.exit(0); });
