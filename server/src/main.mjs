import { createApp } from './app.mjs';
const token = process.env.SCENE_ACCESS_TOKEN ?? '';
if (token && token.length < 24) throw new Error('SCENE_ACCESS_TOKEN must contain at least 24 characters.');
const config = { token, apiKey: process.env.OPENAI_API_KEY, model: process.env.OPENAI_MODEL,
                 timeoutMS: Number(process.env.SCENE_TIMEOUT_MS ?? 15000) };
const port = Number(process.env.PORT ?? 8787), host = process.env.HOST ?? '127.0.0.1';
if (!Number.isInteger(port) || port < 1 || port > 65535 || !Number.isFinite(config.timeoutMS) || config.timeoutMS < 1000 || config.timeoutMS > 30000) {
  throw new Error('Invalid port or timeout configuration.');
}
const server = createApp(config);
server.listen(port, host, () => process.stdout.write(`Blind Assist scene relay listening on ${host}:${port}; configured: ${Boolean(config.apiKey && config.model && token)}\n`));
function shutdown() { server.close(() => process.exit(0)); setTimeout(() => process.exit(1), 5000).unref(); }
process.on('SIGTERM', shutdown); process.on('SIGINT', shutdown);
