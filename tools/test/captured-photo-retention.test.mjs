import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const root = new URL('../../', import.meta.url);
const source = readFileSync(new URL('ios/BlindAssist/NavigationModel.swift', root), 'utf8');
const fixture = readFileSync(new URL('BlindCore/Tests/BlindCoreTests/NativeCaptureRetentionTests.swift', root), 'utf8');
function method(source, name) {
  const at = source.indexOf(`func ${name}(`); assert.ok(at >= 0, name);
  const start = source.lastIndexOf('\n', at) + 1;
  let end = source.indexOf('{', at) + 1, depth = 1;
  for (; depth && end < source.length; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  assert.equal(depth, 0); return source.slice(start, end);
}
function contracts(text) {
  const capture = method(text, 'captureExploreSnapshot');
  const clear = method(text, 'clearExploreSnapshot');
  const begin = method(text, 'beginSelectedPhoto');
  const finish = method(text, 'finishSelectedPhotoNativeWork');
  const guardAt = capture.indexOf('guard selectedPhotoNativeLease == nil else');
  assert.ok(guardAt >= 0 && guardAt < capture.indexOf('clearSelectedDocument()'), 'Refuse busy capture before invalidation/allocation');
  assert.ok(guardAt < capture.indexOf('frame.capturedImage'), 'Do not retain rejected frames');
  assert.match(begin, /selectedPhotoNativeLease == nil/);
  assert.match(begin, /selectedPhotoNativeLease = selection\?\.id/);
  assert.match(text, /@MainActor private var selectedPhotoNativeLease: UUID\?/);
  for (const name of ['captureExploreSnapshot', 'beginSelectedPhoto', 'finishSelectedPhotoNativeWork', 'explorePhoto']) {
    assert.match(method(text, name), /^\s*@MainActor(?: @discardableResult)? func/);
  }
  assert.match(capture, /let nativeLease = UUID\(\)\s+selectedPhotoNativeLease = nativeLease/);
  assert.ok(capture.indexOf('selectedPhotoNativeLease = nativeLease') < capture.indexOf('clearSelectedDocument()'));
  assert.ok(capture.indexOf('selectedPhotoNativeLease = nativeLease') < capture.indexOf('frame.capturedImage'));
  assert.match(capture, /if !handedToNativeTask, selectedPhotoNativeLease == nativeLease \{ selectedPhotoNativeLease = nil \}/);
  assert.ok(capture.lastIndexOf('handedToNativeTask = true') > capture.indexOf('exploreTask = Task'));
  assert.match(capture, /defer \{\s+if self\?\.selectedPhotoNativeLease == nativeLease \{ self\?\.selectedPhotoNativeLease = nil \}\s+\}/);
  assert.match(capture, /guard !Task\.isCancelled else \{ return \}\s+let regions = await Task\.detached/);
  assert.match(finish, /if selectedPhotoNativeLease == selection.id \{ selectedPhotoNativeLease = nil \}/);
  assert.doesNotMatch(clear, /selectedPhotoNativeLease\s*=/);
  const afterWorker = capture.slice(capture.indexOf('}.value'));
  assert.match(afterWorker, /!Task\.isCancelled, self\.exploreRequest == token/);
  assert.match(afterWorker, /self\.assistantSession\.generation == generation, self\.assistantSession\.foregroundActive/);
  assert.ok(afterWorker.indexOf('foregroundActive') < afterWorker.indexOf('self.exploreSnapshot ='));
  assert.doesNotMatch(capture + clear, /removeItem|deleteValue|PHAsset|PHPhotoLibrary|URLSession|savePhoto|roomRecall\.forget|itemAppearance\.forget/);
  assert.equal((capture.match(/selectedPhotoNativeLease = nil/g) ?? []).length, 2, 'Only pre-handoff failure or exact native completion releases capture slot');
}
test('captured and library pictures share one lease until actual native completion', () => contracts(source));
test('logical clear/cancel retains no snapshot but does not release the native lease', () => {
  const clear = method(source, 'clearExploreSnapshot');
  assert.match(clear, /exploreRequest = UUID\(\); exploreTask\?\.cancel\(\); exploreTask = nil; exploreSnapshot = nil/);
  assert.doesNotMatch(clear, /selectedPhotoNativeLease\s*=/);
});
test('synthetic Swift harness executes exact production owner methods', () => {
  for (const name of ['captureExploreSnapshot', 'clearExploreSnapshot', 'beginSelectedPhoto', 'finishSelectedPhotoNativeWork']) {
    assert.equal(method(fixture, name), method(source, name), name);
  }
  assert.equal((fixture.match(/func test[A-Z]/g) ?? []).length, 7);
  assert.match(fixture, /weak var pixels/);
  assert.match(fixture, /for _ in 0\.\.<100/);
  assert.match(fixture, /group.addTask \{ await m.captureExploreSnapshot\(\) \}/);
  const concurrentCase = method(fixture, 'testRepeatedCaptureRetainsOnlyOneNativeFrameWithoutReplacingOwner');
  assert.ok(concurrentCase.indexOf('withTaskGroup') < concurrentCase.indexOf('m.captureExploreSnapshot()'), 'First acquisition also overlaps; no manual first capture');
  assert.match(fixture, /XCTAssertNil\(pixels/);
});
test('negative mutations reject early release, missing admission, stale ownership and missing cancellation checks', () => {
  const mutations = [
    s => s.replace('@MainActor private var selectedPhotoNativeLease', 'private var selectedPhotoNativeLease'),
    s => s.replace('@MainActor func captureExploreSnapshot', 'func captureExploreSnapshot'),
    s => s.replace('selectedPhotoNativeLease = nativeLease\n        var handedToNativeTask', 'var handedToNativeTask'),
    s => s.replace('guard selectedPhotoNativeLease == nil else', 'guard true else'),
    s => s.replace('exploreRequest = UUID(); exploreTask?.cancel(); exploreTask = nil; exploreSnapshot = nil', 'selectedPhotoNativeLease = nil; exploreRequest = UUID(); exploreTask?.cancel(); exploreTask = nil; exploreSnapshot = nil'),
    s => s.replace('if self?.selectedPhotoNativeLease == nativeLease { self?.selectedPhotoNativeLease = nil }', 'self?.selectedPhotoNativeLease = nil'),
    s => s.replace('guard !Task.isCancelled else { return }\n            let regions = await Task.detached', 'let regions = await Task.detached'),
    s => s.replace('self.exploreRequest == token,', 'true,'),
    s => s.replace('self.assistantSession.generation == generation, self.assistantSession.foregroundActive else', 'true else'),
  ];
  for (const mutate of mutations) {
    const changed = mutate(source); assert.notEqual(changed, source);
    assert.throws(() => contracts(changed));
  }
});
