// Reconstructed from the reviewed source-contract checks after workspace loss.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const root = new URL('../../', import.meta.url);
const read = name => readFile(new URL(name, root), 'utf8');

test('colour command is requested-only and shared cancellation/focus gates include it', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(source, /if !automatic, routeClothingColorCommand\(question\)/);
  assert.match(source, /if automatic, currencyActive \|\| colorActive \|\| readingTool != nil \|\| currencyRetake\.isPending \{ return \}/);
  assert.match(source, /focusedTaskActive: focusedFaceSearch \|\| currencyActive \|\| currencyRetake\.isPending \|\| colorActive/);
  const cancel = source.slice(source.indexOf('private func cancelDescription()'), source.indexOf('private func publish()'));
  assert.match(cancel, /colorActive = false/);
  assert.match(cancel, /requestID = UUID\(\); questionTask\?\.cancel\(\)/);
  assert.match(source, /if currencyActive \|\| colorActive \|\| readingTool != nil \|\| currencyRetake\.isPending \{ cancelDescription\(\) \}/);
});

test('colour delivery rechecks freshness, pose, current request, hazard policy and attention admission', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const route = source.slice(source.indexOf('func routeClothingColorCommand('), source.indexOf('func readScene('));
  assert.match(route, /attention\.stationary, detection\.hazard == \.observing/);
  assert.equal((route.match(/ClothingColorCapturePolicy\.fresh/g) ?? []).length, 3);
  assert.equal((route.match(/perceptionResultAllowed\(/g) ?? []).length, 3);
  assert.match(route, /try Task\.checkCancellation\(\)/);
  assert.equal((route.match(/visualCapturePoseAllowed\(origin: colorOrigin, forward: colorForward\)/g) ?? []).length, 2);
  assert.match(route, /transform\.columns\.2\.y/);
  assert.match(route, /preciseNeutral \? ClothingColor\.Result\.nearNeutral : result/);
  assert.match(route, /speakRequested\(self\.message, narrationID: request\)/);
  assert.doesNotMatch(route, /feedback\.|LocalImageAssistant|LanguageModelSession|SceneQuestionClient/);
  const policy = source.slice(source.indexOf('private func perceptionResultAllowed('), source.indexOf('private func cancelDescription()'));
  assert.match(policy, /requestID == request && perceptionGeneration == generation/);
  assert.match(policy, /hazard: detection\.hazard/);
});

test('colour reader uses the same normalized buffer for mask and pixels, never whole-frame average', async () => {
  const source = await read('ios/BlindAssist/ClothingColorReader.swift');
  assert.match(source, /CGColorSpace\(name: CGColorSpace\.sRGB\)/);
  assert.match(source, /context\.render\(normalized, to: buffer/);
  assert.match(source, /VNImageRequestHandler\(cvPixelBuffer: buffer, orientation: \.up\)/);
  assert.match(source, /VNGenerateForegroundInstanceMaskRequest/);
  assert.match(source, /kCVPixelFormatType_OneComponent8/);
  assert.match(source, /target > 0, observation\.allInstances\.contains\(target\)/);
  assert.match(source, /height\*3\/10/);
  assert.match(source, /label\(mx\+dx,my\+dy\) == target/);
  assert.match(source, /Double\(samples\.count\)\/Double\(candidates\) >= 0\.8/);
  assert.match(source, /VNDetectHumanRectanglesRequest/);
  assert.doesNotMatch(source, /URLSession|UserDefaults|FileManager|\.write\(/);
});

test('model-written and stored appearance descriptions cannot bypass the colour guard', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(source, /fromModel && ClothingColorCommand\.containsUnverifiedColorClaim\(answer\)/);
  const inputGate = source.indexOf('if !automatic, ClothingColorCommand.requiresNeutralVerification(question)');
  assert.ok(inputGate > 0 && inputGate < source.indexOf('questionTask = Task', inputGate));
  assert.match(source.slice(inputGate, inputGate + 300), /ClothingColor\.Result\.nearNeutral\.speech/);
  assert.equal((source.match(/!ClothingColorCommand\.containsUnverifiedColorClaim\(text\)/g) ?? []).length, 2);
  const docs = await read('research/CLOTHING_COLOR.md');
  assert.match(docs, /not a calibrated fabric-colour instrument/);
  assert.match(docs, /require an Apple SDK\/device/);
});
