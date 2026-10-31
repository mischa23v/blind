// Source and mutation contracts only. Native rendered contrast still needs Apple CI.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { assertFullAuditDestinations } from './helpers/full-audit-contract.mjs';
const read = p => readFileSync(new URL('../../' + p, import.meta.url), 'utf8');
const dashboard = read('ios/BlindAssist/DashboardView.swift');
const ui = read('ios/BlindAssistUITests/LaunchTests.swift');
function guardCameraAnswer(source) {
 const style = source.match(/private struct AskCameraAnswerButtonStyle: ButtonStyle \{([\s\S]*?)\n\}/)?.[1];
 assert.ok(style);
 assert.match(style,/@Environment\(\\\.isEnabled\) private var isEnabled/);
 assert.match(style,/\.foregroundStyle\(isEnabled \? tint : Color\.primary\)/);
 assert.match(style,/\.opacity\(isEnabled && configuration\.isPressed \? 0\.9 : 1\)/);
 assert.match(style,/\.fixedSize\(horizontal: false, vertical: true\)/);
 assert.match(style,/\.frame\(minWidth: 44, minHeight: 44, alignment: \.leading\)/);
 assert.doesNotMatch(style,/\.font\(|\.minimumScaleFactor|\.dynamicTypeSize|\.clipped|\.allowsHitTesting|\.accessibilityHidden|\.environment\(/);
 const start = source.indexOf('                Button(t("Ask about the camera view",');
 const end = source.indexOf('                Button(model.voice.listening',start);
 assert.ok(start >= 0 && end > start);
 const action = source.slice(start,end);
 assert.match(action,/model\.readScene\(cloud: false, question: sceneQuestion, focus: focus\)/);
 assert.match(action,/\.font\(\.headline\)/);
 assert.match(action,/\.disabled\(model\.busy \|\| model\.simulation \|\| !model\.running\)/);
 assert.match(action,/\.buttonStyle\(AskCameraAnswerButtonStyle\(tint: accent\)\)/);
 assert.match(action,/\.accessibilityIdentifier\("local-answer"\)/);
 assert.match(action,/\.accessibilityHint\(localAnswerDisabledReason\)/);
 assert.match(action,/if !localAnswerDisabledReason\.isEmpty \{\s*Text\(localAnswerDisabledReason\)/);
 assert.match(action,/\.foregroundStyle\(\.primary\)/);
 assert.match(action,/\.accessibilityIdentifier\("local-answer-unavailable-reason"\)/);
 assert.doesNotMatch(action,/\.accessibilityHidden|\.accessibilityLabel|\.allowsHitTesting|\.onTapGesture|\.minimumScaleFactor|\.dynamicTypeSize/);
 const reason = source.match(/    private var localAnswerDisabledReason: String \{([\s\S]*?)\n    \}/)?.[1];
 assert.ok(reason);
 for(const condition of ['if model.simulation {','if !model.running {','if model.busy {']) assert.ok(reason.includes(condition));
 for(const message of [
  ['Practice uses generated readings, not a live camera view.','التدريب يستخدم قراءات مولّدة، وليس صورة مباشرة من الكاميرا.'],
  ['Camera monitoring is not running. Open Camera and safety to start it.','مراقبة الكاميرا لا تعمل. افتح الكاميرا والسلامة لبدئها.'],
  ['Another request is in progress. Wait for it to finish.','هناك طلب آخر قيد التنفيذ. انتظر حتى ينتهي.'],
 ]) assert.ok(reason.includes(`return t("${message[0]}", "${message[1]}")`));
 assert.match(reason,/return ""\s*$/);
}
test('identified disabled camera action retains readable label, actual disabled state and explanation',()=>guardCameraAnswer(dashboard));
test('full native audit retains original unsuppressed local-answer findings',()=>assertFullAuditDestinations(ui));
for(const [name,from,to] of [
 ['dimmed disabled foreground','isEnabled ? tint : Color.primary','isEnabled ? tint : Color.secondary'],
 ['disabled opacity','isEnabled && configuration.isPressed ? 0.9 : 1','isEnabled ? 1 : 0.4'],
 ['disabled behavior','.disabled(model.busy || model.simulation || !model.running)','.disabled(false)'],
 ['visible reason','if !localAnswerDisabledReason.isEmpty {','if false {'],
 ['semantic hint','.accessibilityHint(localAnswerDisabledReason)','.accessibilityHint("")'],
 ['action','model.readScene(cloud: false, question: sceneQuestion, focus: focus)','model.startSimulation()'],
 ]) test(name+' regression is rejected',()=>assert.throws(()=>guardCameraAnswer(dashboard.replace(from,to))));
