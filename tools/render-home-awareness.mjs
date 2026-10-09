import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const report = JSON.parse(await readFile(resolve(root, 'artifacts/home-awareness/sol-6-1.json'), 'utf8'));
const conversation = JSON.parse(await readFile(resolve(root, 'artifacts/home-awareness/conversation-sol-6-1.json'), 'utf8'));
const baseline = JSON.parse(await readFile(resolve(root, 'artifacts/home-awareness/baseline.json'), 'utf8'));
if (!report.summary || !conversation.summary) throw new Error('Wait for evaluation completion before rendering.');
const originalSummary = { ...report.summary };
report.cases.push(...conversation.cases);
report.summary.contextPassed += conversation.summary.contextPassed;
report.summary.total += conversation.summary.total;
report.summary.actualModelResponses += conversation.summary.actualModelResponses;
report.evaluationRuns = ['sol-6-1.json', 'conversation-sol-6-1.json'];
const escape = text => String(text).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const diagram = `<svg viewBox="0 0 900 500" role="img" aria-labelledby="map-title map-description"><title id="map-title">Fictional home scenario</title><desc id="map-description">Schematic room arrangement, not surveyed geometry. Living room contains Maya on a sofa, Omar in a chair, an apparently unoccupied cushion, a chair with a bag, a coffee table, art and a fish tank. Hallway connects to the bedroom and home entrance.</desc>
<rect x="20" y="20" width="860" height="460" rx="12" fill="#edf2f4"/>
<g stroke="#3c5665" stroke-width="3" fill="#d9e3e9"><rect x="45" y="60" width="210" height="365"/><rect x="295" y="60" width="550" height="210"/><rect x="295" y="310" width="550" height="115"/></g>
<g fill="#193a4a" font-family="system-ui" font-size="17"><text x="80" y="100">Hallway</text><text x="60" y="455">Home entrance</text><text x="310" y="88">Living room</text><text x="310" y="340">Bedroom</text></g>
<path d="M150 445V205H290 M150 205V370H290" fill="none" stroke="#a97717" stroke-width="5" stroke-dasharray="9 7"/>
<rect x="385" y="115" width="235" height="48" rx="7" fill="#849dc5"/><rect x="400" y="92" width="160" height="14" fill="#5278a5"/>
<circle cx="425" cy="136" r="17" fill="#478960"/><rect x="705" y="139" width="62" height="47" rx="5" fill="#849dc5"/><circle cx="735" cy="157" r="16" fill="#397fab"/>
<rect x="680" y="87" width="125" height="26" rx="4" fill="#60bfc6"/><rect x="458" y="190" width="150" height="35" rx="5" fill="#a8866b"/>
<rect x="710" y="215" width="55" height="30" fill="#b19b81"/><rect x="720" y="211" width="25" height="22" fill="#aa5c4c"/>
<g font-family="system-ui" font-size="13" fill="#102d3b"><text x="385" y="182">Maya · sofa · unoccupied cushion</text><text x="687" y="202">Omar · armchair</text><text x="680" y="80">Aquarium</text><text x="458" y="243">Low coffee table</text><text x="709" y="263">Bag on chair</text><text x="422" y="81">Seascape art</text><text x="335" y="395">Blue bed cover · wardrobe</text><text x="47" y="290">Connections from</text><text x="47" y="310">existing example map</text></g></svg>`;
const data = JSON.stringify(report).replaceAll('<', '\\u003c');
const html = `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Home awareness evaluation</title>
<style>body{font:17px/1.55 system-ui;background:#10212d;color:#edf4f6;margin:0}main{max-width:1120px;margin:auto;padding:28px}h1{line-height:1.2}section{background:#1d3443;padding:22px;border-radius:12px;margin:22px 0}svg{width:100%;height:auto}select{width:100%;font:inherit;padding:12px}a{color:#a4dbff}pre{white-space:pre-wrap;overflow-wrap:anywhere}#answer{font-size:1.2rem}.note{color:#c2d5df}button:focus,select:focus{outline:3px solid #ffcf5e}dt{font-weight:700}dd{margin-bottom:12px}</style>
<main><p>Fictional scene · real relay code · ${escape(report.model ?? 'no model')}</p><h1>Living room → conversation → another room</h1>
<p>Original context suite: baseline ${baseline.summary.contextPassed}/${baseline.summary.total}; connected ${originalSummary.contextPassed}/${originalSummary.total}. Additional conversation cases: ${conversation.summary.contextPassed}/${conversation.summary.total}. Actual model responses across both runs: ${report.summary.actualModelResponses}. These figures are not a percentage of the complete product achieved.</p>
<p class="note">The map, people, identities and observations are supplied fixtures. The model received text context, not this drawing or a camera photograph. No real face recognition, localisation, navigation or iPhone speech test occurred.</p>
<section>${diagram}<p>The additional conversation fixture adds a bathroom inside the bedroom; it is not drawn in this original room schematic.</p></section><label for="scenario">Inspect a scenario</label><select id="scenario">${report.cases.map((item,i)=>`<option value="${i}">${escape(item.title)}</option>`).join('')}</select>
<section aria-live="polite"><h2 id="title"></h2><dl><dt>User asks</dt><dd id="question"></dd><dt>Expected behavior</dt><dd id="expected"></dd><dt>Actual model answer</dt><dd id="answer"></dd><dt>Evidence status</dt><dd id="status"></dd></dl></section>
<section><h2>Inspect the evidence</h2><p>Keyword checks are review aids, not semantic correctness or safety scores.</p><details><summary>Exact model input and results</summary><pre id="trace"></pre></details></section>
<p>Reproduce the conversation subset: <code>node tools/evaluate-home-awareness.mjs --model gpt-6.1-sol --label conversation-recheck --cases bathroom-arrival,bathroom-heading,goal-change,ambiguous-goal</code>. Four bounded, sequential API calls. Other runs require explicit selection of at most eight model cases. No Docker.</p></main>
<script>const report=${data};const el=id=>document.getElementById(id);function show(){const c=report.cases[Number(el('scenario').value)];el('title').textContent=c.title;el('question').textContent=c.question;el('expected').textContent=c.expectedBehavior;el('answer').textContent=c.answer??'No model answer: '+c.modelStatus;el('status').textContent='Context '+(c.contextPassed?'passed':'gap')+'; model '+c.modelStatus+(c.words!==undefined?'; '+c.words+' words; '+c.latencyMS+' ms':'');el('trace').textContent=JSON.stringify(c,null,2)}el('scenario').addEventListener('change',show);show();</script></html>`;
await writeFile(resolve(root, 'artifacts/home-awareness/report.html'), html);
await writeFile(resolve(root, 'artifacts/home-awareness/home-schematic.svg'), diagram);
console.log('Wrote artifacts/home-awareness/report.html and home-schematic.svg.');
