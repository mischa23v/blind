// E14: time Claude models on a real frame with the relay's compact prompt. Streams, so it
// records time to the first words (when speech could start) as well as the total.
// Reads ANTHROPIC_API_KEY from the environment (pass --env-file); never prints it.
// Usage: node --env-file=<file> tools/measure-claude-latency.mjs --frame <jpeg> [--out <json>] [--check]
import Anthropic from '@anthropic-ai/sdk';
import { readFileSync, writeFileSync } from 'node:fs';
import { SYSTEM_COMPACT, userPrompt } from '../server/src/scene-policy.mjs';
import { containsSpatialClaim } from '../server/src/spatial-guard.mjs';

const option = name => { const i = process.argv.indexOf(name); return i < 0 ? undefined : process.argv[i + 1]; };
const client = new Anthropic();

if (process.argv.includes('--check')) {
  // Smallest possible request: confirms the key works.
  const response = await client.messages.create({ model: 'claude-haiku-5-5', max_tokens: 16,
    messages: [{ role: 'user', content: 'Reply with the single word: ready' }] });
  const text = response.content.filter(block => block.type === 'text').map(block => block.text).join('');
  console.log(`key works: model=${response.model} reply=${JSON.stringify(text.trim())}`);
  process.exit(0);
}

const frame = option('--frame');
if (!frame) throw new Error('Explicit --frame is required.');
const data = readFileSync(frame).toString('base64');
const scene = { question: 'Describe what is in front of me.', language: 'en', detail: 'balanced', focus: 'surroundings',
  context: { version: 1, motion: 'unknown', monitoring: 'unknown', observations: [] }, wordAllowance: 55 };

// Thinking kept minimal for speed: off where the model allows it, otherwise lowest effort.
const variants = [
  { model: 'claude-haiku-5-5', thinking: { type: 'disabled' } },
  { model: 'claude-sonnet-5-5', thinking: { type: 'between_tools' }, effort: 'low' },
  { model: 'claude-opus-5-5', effort: 'low' }
];
const results = [];
for (const v of variants) {
  const started = performance.now();
  let firstText = null;
  try {
    const stream = client.messages.stream({ model: v.model, max_tokens: 1024, system: SYSTEM_COMPACT,
      ...(v.thinking ? { thinking: v.thinking } : {}), ...(v.effort ? { output_config: { effort: v.effort } } : {}),
      messages: [{ role: 'user', content: [
        { type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data } },
        { type: 'text', text: userPrompt(scene) }
      ] }] });
    stream.on('text', () => { if (firstText === null) firstText = performance.now(); });
    const message = await stream.finalMessage();
    const text = message.content.filter(block => block.type === 'text').map(block => block.text).join(' ').trim();
    const row = { model: v.model, firstWordsMS: firstText && Math.round(firstText - started), totalMS: Math.round(performance.now() - started),
      inputTokens: message.usage.input_tokens, outputTokens: message.usage.output_tokens, stopReason: message.stop_reason,
      spatialCheckCaught: containsSpatialClaim(text), answer: text };
    results.push(row);
    console.log(`${v.model}: first words ${row.firstWordsMS} ms, total ${row.totalMS} ms, in ${row.inputTokens} out ${row.outputTokens}`);
  } catch (error) {
    const status = error instanceof Anthropic.APIError ? error.status : 'network';
    results.push({ model: v.model, error: `${status}: ${error.message}` });
    console.log(`${v.model}: did not complete (${status}) ${error.message}`);
  }
}
if (option('--out')) writeFileSync(option('--out'), JSON.stringify(results, null, 2));
