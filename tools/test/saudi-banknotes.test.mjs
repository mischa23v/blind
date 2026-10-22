// Source contracts only, not an Apple build or recognition-accuracy evaluation.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = file => readFile(new URL(`../../${file}`, import.meta.url), 'utf8');
test('missing SAR model is explicit and cannot fall through to scene guesses', async () => {
  const adapter = await read('ios/BlindAssist/SaudiBanknoteRecognition.swift');
  const navigation = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(adapter, /static let selected: SaudiBanknoteModelProfile\? = nil/);
  assert.match(navigation, /if !automatic, routeSaudiBanknoteCommand\(question\) \{ return \}/);
  assert.match(navigation, /guard SaudiBanknoteModelProfile.selected != nil else \{[\s\S]*?won't guess the value.[\s\S]*?return true/);
});
test('adapter is local full-view inference with checksum, no top-note shortcut', async () => {
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
  assert.match(source, /private func cancelDescription\(\) \{\s*currencyActive = false/);
  assert.match(source, /focusedTaskActive: focusedFaceSearch \|\| currencyActive/);
  assert.doesNotMatch(body, /feedback\.deliver|feedback\.speak|cloud: true/);
});

test('generic scene answers cannot bypass monetary value guard', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(source, /SaudiBanknotePolicy.containsUnverifiedMoneyValue\(answer\)/);
  assert.ok(source.indexOf('SaudiBanknotePolicy.containsUnverifiedMoneyValue(answer)') < source.indexOf('let spoken = self.deliverCandidate(candidate'));
});
