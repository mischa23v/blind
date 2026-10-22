// Where does description time go? Splits one image request into network connection, upload,
// model processing (OpenAI's `openai-processing-ms` header) and the remainder, for a few
// request settings. Uses the relay's own prompt so results match the real request shape.
// Bounded: one frame, one call per variant. Requires an explicit --frame JPEG and API key.
import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { SYSTEM, SYSTEM_COMPACT, userPrompt } from '../server/src/scene-policy.mjs';

const option = name => { const i = process.argv.indexOf(name); return i < 0 ? undefined : process.argv[i + 1]; };
const frame = option('--frame'), outFile = option('--out');
if (!frame || !process.env.OPENAI_API_KEY) throw new Error('Explicit --frame and an API key are required.');
const image = 'data:image/jpeg;base64,' + readFileSync(frame).toString('base64');
const scene = { question: 'Describe what is in front of me.', image, language: 'en', detail: 'balanced', focus: 'surroundings',
  context: { version: 1, motion: 'unknown', monitoring: 'unknown', observations: [] }, wordAllowance: 55 };

// Connection timing to the API host, without a model call.
// The key goes to curl on stdin (-H @-), never on the command line where `ps` would show it.
const curl = spawnSync('curl', ['-s', '-o', '/dev/null', '-w', '%{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total}',
  'https://api.openai.com/v1/models', '-H', '@-'], { encoding: 'utf8', input: `Authorization: Bearer ${process.env.OPENAI_API_KEY}\n` });
const [dns, tcp, tls, firstByte, total] = curl.stdout.trim().split(' ').map(v => Math.round(Number(v) * 1000));
const results = { imageBytes: readFileSync(frame).length, network: { dnsMS: dns, tcpConnectMS: tcp, tlsDoneMS: tls, firstByteMS: firstByte, totalMS: total }, variants: [] };

const variants = (option('--set') === 'prompt' ? [
  { model: 'gpt-5.4-mini', imageDetail: 'low', prompt: 'full' },
  { model: 'gpt-5.4-mini', imageDetail: 'low', prompt: 'compact' },
  { model: 'gpt-5.4-nano', imageDetail: 'low', prompt: 'compact' },
  { model: 'gpt-6.1-sol', imageDetail: 'low', prompt: 'full' },
  { model: 'gpt-6.1-sol', imageDetail: 'low', prompt: 'compact' }
] : [
  { model: 'gpt-6.1-sol', imageDetail: 'auto' },
  { model: 'gpt-6.1-sol', imageDetail: 'auto', reasoning: 'low' },
  { model: 'gpt-6.1-sol', imageDetail: 'low', reasoning: 'low' },
  { model: 'gpt-5.4-mini', imageDetail: 'auto' },
  { model: 'gpt-5.4-mini', imageDetail: 'low' },
  { model: 'gpt-5.4-mini', imageDetail: 'low', reasoning: 'low' }
]);
for (const v of variants) {
  const body = { model: v.model, store: false, instructions: v.prompt === 'compact' ? SYSTEM_COMPACT : SYSTEM, max_output_tokens: 1400,
    ...(v.reasoning ? { reasoning: { effort: v.reasoning } } : {}),
    input: [{ role: 'user', content: [{ type: 'input_text', text: userPrompt(scene) }, { type: 'input_image', image_url: image, detail: v.imageDetail }] }] };
  const started = performance.now();
  const response = await fetch('https://api.openai.com/v1/responses', { method: 'POST',
    headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const headersAt = performance.now();
  const result = await response.json();
  const finished = performance.now();
  const processing = Number(response.headers.get('openai-processing-ms'));
  const text = (result.output ?? []).filter(i => i.type === 'message').flatMap(i => i.content ?? []).filter(i => i.type === 'output_text').map(i => i.text).join(' ');
  results.variants.push({ ...v, status: response.status, totalMS: Math.round(finished - started), untilHeadersMS: Math.round(headersAt - started),
    modelProcessingMS: Number.isFinite(processing) ? processing : null,
    networkAndQueueMS: Number.isFinite(processing) ? Math.round(headersAt - started - processing) : null,
    inputTokens: result.usage?.input_tokens, outputTokens: result.usage?.output_tokens,
    reasoningTokens: result.usage?.output_tokens_details?.reasoning_tokens, error: result.error?.message ?? null, answer: text });
  console.log(`${v.model} prompt=${v.prompt ?? 'full'} detail=${v.imageDetail} reasoning=${v.reasoning ?? 'default'} in=${result.usage?.input_tokens}: ${Math.round(finished - started)} ms (model ${processing} ms)`);
}
if (outFile) writeFileSync(outFile, JSON.stringify(results, null, 2));
console.log(JSON.stringify(results.network));
