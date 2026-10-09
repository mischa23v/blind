// Tests the real relay validation/prompt path. Optional bounded model calls use
// synthetic text context only, never the placeholder JPEG used by validation.
import { mkdir, writeFile, readFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { cases, map } from './fixtures/home-awareness.mjs';
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const option = name => { const index = process.argv.indexOf(name); return index < 0 ? undefined : process.argv[index + 1]; };
const source = resolve(option('--source') ?? root);
const label = option('--label') ?? 'current';
if (!/^[a-z0-9-]+$/.test(label)) throw new Error('Invalid report label.');
const live = process.argv.includes('--model');
const model = option('--model') ?? process.env.OPENAI_MODEL;
const selectedIDs = option('--cases')?.split(',');
if (selectedIDs?.some(id => !cases.some(item => item.id === id))) throw new Error('Unknown scenario ID.');
const selectedCases = selectedIDs ? cases.filter(item => selectedIDs.includes(item.id)) : cases;
if (live && selectedCases.filter(item => item.modelCase).length > 8) throw new Error('Select at most eight model cases with --cases.');
if (live && (!model || model.startsWith('--') || !process.env.OPENAI_API_KEY)) throw new Error('Explicit model and API key required.');
const { validateScene } = await import(pathToFileURL(join(source, 'server/src/app.mjs')));
const { userPrompt, SYSTEM } = await import(pathToFileURL(join(source, 'server/src/scene-policy.mjs')));
const output = join(root, 'artifacts/home-awareness'); await mkdir(output, { recursive: true });
const report = { label, generatedAt: new Date().toISOString(), syntheticInputsOnly: true,
  evaluationScope: 'relay context delivery; optional text-only model reasoning, not real perception or navigation',
  model: live ? model : null, map, cases: [], sourceHashes: {} };
for (const path of ['server/src/app.mjs', 'server/src/scene-policy.mjs', 'server/src/situation-context.mjs', 'package-lock.json']) {
  try { report.sourceHashes[path] = createHash('sha256').update(await readFile(join(source, path))).digest('hex'); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
}
report.fixtureHash = createHash('sha256').update(await readFile(join(root, 'tools/fixtures/home-awareness.mjs'))).digest('hex');
for (const item of selectedCases) {
  const result = { id: item.id, title: item.title, question: item.request.question,
    expectedBehavior: item.expectedBehavior, contextPassed: false, modelStatus: 'not_run', answer: null };
  let prompt;
  try {
    const validated = validateScene(item.request);
    prompt = JSON.parse(userPrompt(validated));
    const delivered = prompt.context?.situation;
    result.missingContext = item.required.filter(key => JSON.stringify(delivered?.[key]) !== JSON.stringify(item.request.context.situation[key]));
    result.maximumWords = prompt.maximumWords;
    result.contextPassed = !item.danger && !result.missingContext.length && prompt.maximumWords === item.request.wordAllowance;
    result.modelInput = prompt;
  } catch (error) {
    result.httpStatus = error.status ?? null;
    result.contextPassed = Boolean(item.danger && error.status === 409);
  }
  if (live && item.modelCase && result.contextPassed) {
    const started = performance.now();
    try {
      const response = await fetch('https://api.openai.com/v1/responses', {
        method: 'POST', signal: AbortSignal.timeout(30000),
        headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model, store: false, max_output_tokens: 1600, reasoning: { effort: 'low' },
          instructions: SYSTEM,
          input: `Evaluation: these are fictional supplied observations and a graph-only map. There is no photograph in this text-only test. Do not pretend to see one.\n${JSON.stringify(prompt)}` })
      });
      result.httpStatus = response.status;
      if (!response.ok) throw new Error('provider_failed');
      const value = await response.json(); result.usage = value.usage;
      if (value.status !== 'completed') throw new Error('incomplete');
      result.answer = (value.output ?? []).filter(x => x.type === 'message').flatMap(x => x.content ?? [])
        .filter(x => x.type === 'output_text').map(x => x.text).join('\n').trim();
      if (!result.answer) throw new Error('empty');
      result.modelStatus = 'completed';
      const lower = result.answer.toLowerCase();
      result.referenceChecks = (item.concepts ?? []).map(alternatives => ({ alternatives,
        found: alternatives.some(word => lower.includes(word.toLowerCase())) }));
      result.unwantedTopics = (item.forbiddenTopics ?? []).filter(word => lower.includes(word.toLowerCase()));
      result.words = [...new Intl.Segmenter(item.request.language, { granularity: 'word' }).segment(result.answer)].filter(x => x.isWordLike).length;
      result.withinBudget = result.words <= prompt.maximumWords;
      // These checks flag candidates for human review; they are NOT a semantic
      // correctness/safety score and cannot detect every unsupported assertion.
    } catch { result.modelStatus = 'failed_or_incomplete'; }
    result.latencyMS = Math.round(performance.now() - started);
  }
  report.cases.push(result);
  await writeFile(join(output, `${label}.json`), JSON.stringify(report, null, 2));
  console.log(`${item.id}: context ${result.contextPassed ? 'PASS' : 'GAP'}; model ${result.modelStatus}`);
}
report.summary = { contextPassed: report.cases.filter(x => x.contextPassed).length, total: selectedCases.length,
  actualModelResponses: report.cases.filter(x => x.modelStatus === 'completed').length,
  modelQuality: 'Requires review of actual answers; keyword checks are not a quality score.',
  untested: ['real camera/face recognition', 'physical localisation and clearance', 'Swift/iPhone delivery', 'persistent memory', 'rolling word budget', 'booking'] };
await writeFile(join(output, `${label}.json`), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report.summary));
if (report.summary.contextPassed !== selectedCases.length || report.cases.some(x => x.modelStatus === 'failed_or_incomplete')) process.exitCode = 1;
