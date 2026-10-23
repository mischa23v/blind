// Source contracts only, not an Apple build or recognition-accuracy evaluation.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = file => readFile(new URL(`../../${file}`, import.meta.url), 'utf8');
test('missing SAR reference pack is explicit and cannot fall through to scene guesses', async () => {
  const adapter = await read('ios/BlindAssist/SaudiBanknoteReferenceRecognition.swift');
  const navigation = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(adapter, /static let selected: SaudiBanknoteReferenceProfile\? = nil/);
  assert.match(navigation, /if !automatic, routeSaudiBanknoteCommand\(question\) \{ return \}/);
  assert.match(navigation, /guard SaudiBanknoteReferenceRecognition.isAvailable else \{[\s\S]*?won't guess the value.[\s\S]*?return true/);
});
test('dormant legacy adapter remains local full-view inference with checksum, no top-note shortcut', async () => {
  const adapter = await read('ios/BlindAssist/SaudiBanknoteRecognition.swift');
  assert.match(adapter, /SHA256.hash/);
  assert.match(adapter, /VNCoreMLRequest/);
  assert.match(adapter, /\.scaleFit/);
  assert.match(adapter, /for object in objects/);
  assert.match(adapter, /String\(value\) == label.identifier/);
  assert.doesNotMatch(adapter, /URLSession|VNRecognizeTextRequest|\.prefix\(1\)|\.max\(/);
});
test('money result is fresh, cancellable and uses existing speech gate', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const body = source.split('func routeSaudiBanknoteCommand')[1].split('func readScene')[0];
  assert.match(body, /Task.checkCancellation\(\)/);
  assert.match(body, /self.perceptionResultAllowed/);
  assert.match(body, /self.attention.stationary/);
  assert.match(body, /speakRequested\(self.message, narrationID: request\)/);
  const cancellation = source.slice(source.indexOf('private func cancelDescription()'), source.indexOf('private func publish()'));
  assert.match(cancellation, /currencyActive = false/);
  assert.match(cancellation, /questionTask\?\.cancel\(\)/);
  assert.match(source, /focusedTaskActive: focusedFaceSearch \|\| currencyActive \|\| currencyRetake.isPending/);
  assert.doesNotMatch(body, /feedback\.deliver|feedback\.speak|cloud: true/);
});

test('generic scene answers cannot bypass monetary value guard', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(source, /SaudiBanknotePolicy.containsUnverifiedMoneyValue\(answer\)/);
  assert.ok(source.indexOf('SaudiBanknotePolicy.containsUnverifiedMoneyValue(answer)') < source.indexOf('let spoken = self.deliverCandidate(candidate'));
});

test('active money route uses actual local reference matching, never the dormant model', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const adapter = await read('ios/BlindAssist/SaudiBanknoteReferenceRecognition.swift');
  assert.match(source, /private let saudiBanknotes = SaudiBanknoteReferenceRecognition\(\)/);
  assert.match(adapter, /VNDetectRectanglesRequest/);
  assert.match(adapter, /engine.inspect\(image: cg\)/);
  assert.match(adapter, /SaudiBanknoteReferencePolicy.decide/);
  assert.match(adapter, /observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft/);
  assert.doesNotMatch(adapter, /URLSession|VNCoreMLRequest|VNRecognizeTextRequest/);
});

test('currency checks full optical pose before success or error speech', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const body = source.split('func routeSaudiBanknoteCommand')[1].split('func routeClothingColorCommand')[0];
  assert.match(body, /currencyForward = Point3\(-Double\(transform.columns.2.x\), -Double\(transform.columns.2.y\), -Double\(transform.columns.2.z\)\)/);
  assert.equal((body.match(/visualCapturePoseAllowed\(origin: currencyOrigin, forward: currencyForward\)/g) || []).length, 2);
  assert.match(source, /return RequestedVisualCapturePose.poseStable/);
});

