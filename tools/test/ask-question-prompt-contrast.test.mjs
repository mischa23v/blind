// Source contract only; native contrast, typing and snapshots remain required.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL('../../'+p,import.meta.url),'utf8');
const source=read('ios/BlindAssist/DashboardView.swift');
const baseline=read('research/ask-contrast-review-20261028/DashboardView.before.swift.txt');
const delta=JSON.parse(read('research/ask-contrast-review-20261028/prompt-delta.json'));
function assertPrompt(s){
 assert.equal(s.split(delta.after).length,2);
 assert.equal(s.replace(delta.after,delta.before),baseline);
 assert.match(delta.after,/prompt: Text\(t\("Your question", "سؤالك"\)\)\.foregroundColor\(\.primary\), axis: \.vertical/);
 assert.match(s.slice(s.indexOf(delta.after),s.indexOf(delta.after)+delta.after.length+110),/accessibilityLabel\(t\("Question or target", "السؤال أو الهدف"\)\)/);
}
test('only enabled question prompt color differs from published adb8fd8',()=>{assertPrompt(source);});
test('prompt regression mutations fail without allowing unrelated UI changes',()=>{
 for(const s of [baseline,source.replace('.foregroundColor(.primary)','.foregroundColor(.secondary)'),source.replace('prompt: Text(t("Your question", "سؤالك"))','prompt: Text("Question")'),source.replace('$model.assistantQuestion','$model.objectiveDraft'),source.replace('axis: .vertical','axis: .horizontal'),source.replace('Question or target','Question'),source+'\n// unrelated']) assert.throws(()=>assertPrompt(s));
});
