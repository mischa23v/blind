// Source integration checks complement WorkRevision's executable Swift tests. Apple framework
// callbacks still require the Mac/iPhone harness; these checks ensure the adapters use the gates.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = file => readFile(new URL(`../../${file}`, import.meta.url), 'utf8');

test('all fast image-answer completions revalidate their request and current scene', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  for (const name of ['locate(', 'findItemByLook(', 'verifyHeldItem(']) {
    const start = source.indexOf(`private func ${name}`);
    const end = source.indexOf('\n    private func ', start + 1);
    const body = source.slice(start, end < 0 ? undefined : end);
    assert.match(body, /perceptionResultAllowed\(/, name);
    assert.match(body, /mapRevision: mapRevision, alignmentRevision: alignmentRevision/, name);
  }
  const gate = source.slice(source.indexOf('private func perceptionResultAllowed'), source.indexOf('private func cancelDescription'));
  for (const required of ['running', '!simulation', '!places.scanning', 'requestID == request', 'perceptionGeneration == generation', 'SceneDelivery.allowed', 'indoor.revision == mapRevision', 'indoor.alignmentRevision == alignmentRevision']) {
    assert.ok(gate.includes(required), required);
  }
});

test('voice deletion uses the same appearance cleanup as UI deletion', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const voice = source.slice(source.indexOf('case .forget(let name):'), source.indexOf('/// Live search'));
  assert.match(voice, /forgetItem\(saved\)/);
  const deletion = source.slice(source.indexOf('func forgetItem('), source.indexOf('var savedRooms:'));
  assert.match(deletion, /updated.forget/); assert.match(deletion, /itemAppearance.forget/);
  assert.match(deletion, /learningItem = nil/); assert.match(deletion, /cancelDescription\(\)/);
});

test('queued private image writes honor record deletion revisions', async () => {
  for (const [file, key] of [['ItemAppearance.swift', 'key'], ['RoomRecall.swift', 'room']]) {
    const source = await read(`ios/BlindAssist/${file}`);
    assert.ok(source.includes(`workRevision.token(for: ${key})`));
    assert.match(source, /workRevision.accepts\(revision\)/);
    assert.ok(source.includes(`workRevision.invalidate(${key})`));
    assert.match(source, /func cancelPendingWork\(\) \{ workRevision.invalidateAll\(\) \}/);
  }
});

test('OCR cannot convert an ambiguous appearance match to an ownership assertion', async () => {
  const source = await read('ios/BlindAssist/ItemAppearance.swift');
  assert.match(source, /let result = ItemAppearanceMatch.decide\(distances\)/);
  assert.doesNotMatch(source, /result = \.same\(/);
});

test('unresolved room evidence clears both identity and trusted learning basis', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const start = source.indexOf('private func updateRoomRecognition(');
  const body = source.slice(start, source.indexOf('private func askRoom(', start));
  assert.match(body, /case \.unknown:\s*self.invalidateRecognizedRoom\(\)/);
  assert.match(source, /recognizedRoomID = nil; recognizedBasis = \[\]/);
  assert.doesNotMatch(body, /clues.append\(\.movedThrough/, 'one connected door is not proof of a crossing');
});

test('microphone permission explains opt-in answer windows', async () => {
  const plist = await read('ios/BlindAssist/Info.plist');
  assert.match(plist, /brief answer after an assistant question/);
  assert.doesNotMatch(plist, /only when you tap Talk/);
});
