// Source contracts only, not Apple SDK typechecking, Vision accuracy, latency,
// physical-device freshness, thread-sanitizer or camera-permission validation.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const source = await readFile(new URL('../../ios/BlindAssist/RoomRecall.swift', import.meta.url), 'utf8');
const start = source.indexOf('final class ConversationFrameProbe:');
assert.ok(start > 0);
const probe = source.slice(start);
function between(text, from, to) {
  const start = text.indexOf(from);
  const end = text.indexOf(to, start + from.length);
  assert.ok(start >= 0 && end > start, `${from} -> ${to}`);
  return text.slice(start, end);
}

test('fresh frame probe is separate, read-only and does not invoke language or identity models', () => {
  assert.match(probe, /struct Result: Sendable/);
  assert.match(probe, /func inspect\(image: CVPixelBuffer, orientation: CGImagePropertyOrientation\) async -> Result\?/);
  assert.doesNotMatch(probe, /RoomRecall\.|MemoryStore|saveValue|UserDefaults|FileManager|URLSession|URLRequest|write\(to:|jpegData|pngData|LanguageModelSession|LocalImageAssistant|VNDetectFace|VNGenerateImageFeaturePrint|VNGenerateForeground/);
  assert.doesNotMatch(probe, /CVPixelBufferGetBaseAddress|CVPixelBufferCreate|CIContext|\.render\(/);
});

test('one-flight admission bounds queued and running work, including cancelled reads', () => {
  const inspect = between(probe, 'func inspect(', 'private func claim()');
  assert.ok(inspect.indexOf('claim()') < inspect.indexOf('queue.async'));
  assert.match(inspect, /guard !Task.isCancelled, claim\(\) else \{ return nil \}/);
  assert.match(inspect, /queue\.async \{ \[self, read\] in/);
  assert.ok(inspect.indexOf('Self.analyze(read)') < inspect.indexOf('release()'));
  assert.ok(inspect.indexOf('release()') < inspect.indexOf('read.finish(result)'));
  assert.match(inspect, /onCancel: \{\s*read.cancel\(\)\s*\}/);
  const claim = between(probe, 'private func claim()', 'private static func analyze(');
  assert.match(claim, /lock.lock\(\); defer \{ lock.unlock\(\) \}/);
  assert.match(claim, /guard !busy else \{ return false \}/);
  assert.match(claim, /busy = true/);
  assert.match(claim, /lock.lock\(\); busy = false; lock.unlock\(\)/);
});

test('cancel-before-start and cancellation after synchronous Vision discard results', () => {
  assert.match(probe, /withTaskCancellationHandler/);
  assert.match(probe, /return Task.isCancelled \? nil : result/);
  const analyze = between(probe, 'private static func analyze(', 'private static func boundedWholeString(');
  assert.ok((analyze.match(/guard !read.isCancelled else \{ return nil \}/g) ?? []).length >= 4);
  assert.match(analyze, /perform\(\[text, classify\]\)[\s\S]*guard !read.isCancelled/);
  const cancel = between(probe, 'func cancel()', 'func finish(');
  assert.match(cancel, /cancelled = true/);
  assert.match(cancel, /self.continuation = nil; completed = true/);
  assert.ok(cancel.indexOf('lock.unlock()') < cancel.indexOf('continuation?.resume'));
  assert.doesNotMatch(cancel, /release\(|busy = false/);
  assert.match(probe, /if completed \{ lock.unlock\(\); continuation.resume\(returning: nil\); return \}/);
  assert.match(probe, /guard !completed else \{ lock.unlock\(\); return \}/);
});

test('Vision uses caller orientation and fast uncorrected OCR with bounded input and output', () => {
  assert.match(probe, /DispatchQueue\(label: "org.blindassist.conversation-frame-probe"/);
  assert.match(probe, /VNRecognizeTextRequest\(\)/);
  assert.match(probe, /text.recognitionLevel = \.fast/);
  assert.match(probe, /text.usesLanguageCorrection = false/);
  assert.match(probe, /VNClassifyImageRequest\(\)/);
  assert.match(probe, /VNImageRequestHandler\(cvPixelBuffer: read.image, orientation: read.orientation\)/);
  assert.match(probe, /width <= 4096, height <= 4096/);
  assert.match(probe, /width \* height <= 12_000_000/);
  assert.match(probe, /texts.count < 8/);
  assert.match(probe, /labels.count < 6/);
  assert.match(probe, /candidate.confidence >= 0.65/);
  assert.match(probe, /observation.confidence >= 0.55/);
  assert.equal((probe.match(/\.prefix\(32\)/g) ?? []).length, 2);
  assert.match(probe, /genericLabels.contains\(value\)/);
});

test('whole strings and neutral empty results cannot become truncated claims or absence', () => {
  const bounded = between(probe, 'private static func boundedWholeString(', 'private static let genericLabels:');
  assert.match(bounded, /value.unicodeScalars.count <= maximumScalars/);
  assert.doesNotMatch(bounded, /\.prefix\(|\.suffix\(/);
  assert.match(probe, /maximumScalars: 160/);
  assert.match(probe, /maximumScalars: 64/);
  assert.match(probe, /return Result\(texts: texts, labels: labels\)/);
  const labels = between(probe, 'private static let genericLabels:', 'private final class Read:');
  assert.doesNotMatch(labels, /"(?:person|face|child|woman|man|red|blue|white|black|banknote|currency|money|riyal|dollar)"/);
});
