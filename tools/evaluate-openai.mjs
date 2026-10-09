// Optional benchmark of synthetic text only. Never invoked by the offline simulator.
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const key = process.env.OPENAI_API_KEY, model = process.env.OPENAI_MODEL;
if (!key || !model) throw new Error('Set OPENAI_API_KEY and OPENAI_MODEL in server/.env locally. No request was sent.');
const report = JSON.parse(await readFile(resolve(root, 'artifacts/simulation/report.json'), 'utf8'));
// A small bounded comparison; no automatic retries and no continuous camera processing.
const selected = ['route', 'detail', 'route-ar', 'detail-ar', 'missing-ar', 'ambiguous'];
const results = [];
for (const id of selected) {
  const item = report.cases.find(item => item.id === id);
  if (!item || item.hazard !== 'observing') continue;
  const started = performance.now();
  const result = { id, language: item.language, provider: 'OpenAI real model', model, expectedIDs: item.expectedModelIDs };
  try {
    const response = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST', signal: AbortSignal.timeout(30_000),
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model, store: false, max_output_tokens: 1024,
        instructions: item.modelInstructions.replace('a JSON array', 'a JSON object with an ids array'), input: item.modelInput,
        text: { format: { type: 'json_schema', name: 'evidence_selection', strict: true,
          schema: { type: 'object', additionalProperties: false, required: ['ids'], properties: { ids: { type: 'array', items: { type: 'string' } } } } } }
      })
    });
    result.httpStatus = response.status;
    if (!response.ok) throw new Error('provider_failed');
    const data = await response.json();
    result.usage = data.usage; result.status = data.status;
    const text = (data.output ?? []).filter(item => item.type === 'message').flatMap(item => item.content ?? [])
      .filter(item => item.type === 'output_text').map(item => item.text).join('');
    const value = JSON.parse(text);
    if (data.status !== 'completed' || !Array.isArray(value.ids) || value.ids.length > 3 || value.ids.some(id => typeof id !== 'string')) throw new Error('invalid_output');
    result.ids = value.ids;
    const allowed = item.id.startsWith('detail') ? item.sceneContext.observations.map(item => item.id) : item.mapContext.destinations.map(item => item.id);
    result.acceptedIDs = value.ids.filter(id => allowed.includes(id));
    result.grounded = result.acceptedIDs.length === value.ids.length;
    result.exactMatch = JSON.stringify([...new Set(value.ids)].sort()) === JSON.stringify([...new Set(item.expectedModelIDs)].sort());
  } catch { result.status = 'failed_or_incomplete'; result.exactMatch = false; }
  result.latencyMS = Math.round(performance.now() - started); results.push(result);
  await writeFile(resolve(root, 'artifacts/simulation/openai-results.json'), JSON.stringify({ syntheticInputsOnly: true, results }, null, 2));
  console.log(`${id}: ${result.exactMatch ? 'MATCH' : 'NO MATCH'}; ${result.latencyMS} ms`);
}
if (results.some(item => !item.exactMatch)) process.exitCode = 1;
