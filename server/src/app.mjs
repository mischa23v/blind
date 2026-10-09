import http from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { systemFor, FOCUSES, cleanContext, userPrompt, keepSafeSentences, fitToBudget } from './scene-policy.mjs';
import { containsSpatialClaim } from './spatial-guard.mjs';

const MAX_BODY = 3_000_000;

export class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
function authorized(header, secret) {
  if (!secret || typeof header !== 'string' || !header.startsWith('Bearer ')) return false;
  const expected = Buffer.from(secret), supplied = Buffer.from(header.slice(7));
  return supplied.length === expected.length && timingSafeEqual(supplied, expected);
}
async function body(req) {
  let size = 0; const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY) throw new HttpError(413, 'Image request is too large.');
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw new HttpError(400, 'Invalid JSON.'); }
}
export function validateScene(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new HttpError(400, 'Expected an object.');
  const { question, image, language = 'en', detail = 'balanced', focus = 'surroundings' } = input;
  if (input.wordAllowance !== undefined && (!Number.isInteger(input.wordAllowance) || input.wordAllowance < 1 || input.wordAllowance > 300)) throw new HttpError(400, 'Invalid word allowance.');
  if (!FOCUSES.includes(focus)) throw new HttpError(400, 'Unsupported description focus.');
  let context;
  try { context = cleanContext(input.context); } catch { throw new HttpError(400, 'Invalid scene context.'); }
  if (!['observing', 'unknown'].includes(context.monitoring)) throw new HttpError(409, 'Local monitoring takes priority.');
  if (typeof question !== 'string' || !question.trim() || question.length > 1000) throw new HttpError(400, 'Question must contain 1–1000 characters.');
  if (!['en', 'ar'].includes(language) || !['minimal', 'balanced', 'detailed'].includes(detail)) throw new HttpError(400, 'Unsupported language or detail.');
  if (typeof image !== 'string' || !/^data:image\/jpeg;base64,[A-Za-z0-9+/]+={0,2}$/.test(image)) throw new HttpError(400, 'A JPEG data URL is required.');
  const encoded = image.slice('data:image/jpeg;base64,'.length);
  if (encoded.length % 4 !== 0) throw new HttpError(400, 'Invalid base64.');
  const jpeg = Buffer.from(encoded, 'base64');
  if (jpeg.length < 4 || jpeg.length > 2_000_000 || jpeg[0] !== 0xff || jpeg[1] !== 0xd8 ||
      jpeg.at(-2) !== 0xff || jpeg.at(-1) !== 0xd9) throw new HttpError(400, 'Invalid JPEG image.');
  return { question: question.trim(), image, language, detail, focus, context,
    ...(input.wordAllowance === undefined ? {} : { wordAllowance: input.wordAllowance }) };
}
export async function describe(scene, config, signal) {
  const response = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST', signal,
    headers: { 'Authorization': `Bearer ${config.apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: config.model, store: false, instructions: systemFor(scene),
      max_output_tokens: scene.wordAllowance !== undefined ? 1400 : scene.detail === 'detailed' ? 700 : 400,
      input: [{ role: 'user', content: [
        { type: 'input_text', text: userPrompt(scene) },
        // E14: low detail is measurably faster; reading text and full room descriptions keep more detail.
        { type: 'input_image', image_url: scene.image, detail: scene.focus === 'text' ? 'high' : scene.detail === 'detailed' ? 'auto' : 'low' }
      ] }]
    })
  });
  if (!response.ok) throw new HttpError(502, 'Scene provider is unavailable.');
  const result = await response.json();
  if (result.status !== 'completed') throw new HttpError(502, 'Scene provider did not complete the answer.');
  const answer = (result.output ?? []).filter(item => item.type === 'message')
    .flatMap(item => item.content ?? []).filter(item => item.type === 'output_text')
    .map(item => item.text).join('\n').trim();
  if (!answer) throw new HttpError(502, 'Scene provider returned no answer.');
  return answer;
}
export function createApp(config, provider = describe) {
  const rate = new Map(); let inFlight = 0;
  const server = http.createServer(async (req, res) => {
    const reply = (status, value) => {
      if (res.destroyed) return;
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store',
                             'X-Content-Type-Options': 'nosniff' });
      res.end(JSON.stringify(value));
    };
    if (req.method === 'GET' && req.url === '/health') { reply(200, { status: 'ok', sceneConfigured: Boolean(config.apiKey && config.model && config.token) }); return; }
    if (req.method === 'GET' && req.url === '/v1/status') {
      if (!authorized(req.headers.authorization, config.token)) { reply(401, { error: 'Unauthorized.' }); return; }
      reply(200, { sceneConfigured: Boolean(config.apiKey && config.model), policyVersion: 1 }); return;
    }
    if (req.method !== 'POST' || req.url !== '/v1/scene') { reply(404, { error: 'Not found.' }); return; }
    if (!authorized(req.headers.authorization, config.token)) { reply(401, { error: 'Unauthorized.' }); req.resume(); return; }
    if (!config.apiKey || !config.model) { reply(503, { error: 'Scene provider is not configured.' }); req.resume(); return; }
    if (!String(req.headers['content-type']).startsWith('application/json')) { reply(415, { error: 'Use application/json.' }); req.resume(); return; }
    const length = Number(req.headers['content-length']);
    if (Number.isFinite(length) && length > MAX_BODY) { reply(413, { error: 'Image request is too large.' }); req.resume(); return; }
    // Bound concurrency before awaiting the request body.
    if (inFlight >= 2) { reply(429, { error: 'Scene service is busy.' }); req.resume(); return; }
    const address = req.socket.remoteAddress ?? 'unknown', now = Date.now();
    for (const [key, history] of rate) if (history.every(time => now - time >= 60_000)) rate.delete(key);
    const history = (rate.get(address) ?? []).filter(time => now - time < 60_000);
    if (history.length >= (config.ratePerMinute ?? 6)) { reply(429, { error: 'Too many scene questions. Try again shortly.' }); req.resume(); return; }
    history.push(now); rate.set(address, history); inFlight += 1;
    const controller = new AbortController();
    const abort = () => { if (!res.writableEnded) controller.abort(); };
    req.on('aborted', abort); res.on('close', abort);
    const timeout = setTimeout(() => controller.abort(), config.timeoutMS ?? 15_000);
    try {
      const scene = validateScene(await body(req));
      const valid = text => typeof text === 'string' && text.trim() && text.length <= 2000;
      let answer = await provider(scene, config, controller.signal);
      if (!valid(answer)) throw new HttpError(502, 'Scene provider returned an invalid answer.');
      // Spatial safety rule: hazard position/distance/step count/clearance come only from sensors.
      // Only offending sentences are dropped; a second call happens only when nothing usable is left.
      let kept = keepSafeSentences(answer, scene.language);
      if (!kept) {
        answer = await provider({ ...scene, spatialRetry: true }, config, controller.signal);
        if (!valid(answer)) throw new HttpError(502, 'Scene provider returned an invalid answer.');
        kept = keepSafeSentences(answer, scene.language);
        if (!kept) throw new HttpError(502, 'Scene answer gave hazard geometry, a step count or a clear-path statement; those come only from sensors.');
      }
      // Whole leading sentences within the reservation; ask once for a shorter answer only if none fits.
      answer = fitToBudget(kept, scene);
      if (!answer) {
        const shorter = await provider({ ...scene, shorterRetry: true }, config, controller.signal);
        answer = valid(shorter) ? fitToBudget(keepSafeSentences(shorter, scene.language), scene) : '';
        if (!answer) throw new HttpError(502, 'Scene provider exceeded the requested information budget.');
      }
      if (containsSpatialClaim(answer)) throw new HttpError(502, 'Scene answer gave hazard geometry; those come only from sensors.');
      reply(200, { answer, source: 'cloud', navigationClearance: false });
    } catch (error) {
      reply(error instanceof HttpError ? error.status : controller.signal.aborted ? 504 : 502,
            { error: error instanceof HttpError ? error.message : 'Scene service is unavailable.' });
    } finally { clearTimeout(timeout); inFlight -= 1; req.removeListener('aborted', abort); res.removeListener('close', abort); }
  });
  server.requestTimeout = 20_000; server.headersTimeout = 10_000;
  return server;
}
