// Source-level integration contracts. These complement executable CompanionAttention tests;
// they do not claim that Apple audio/VoiceOver callbacks or the native app were device-tested.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';

const root = new URL('../../', import.meta.url);
const read = file => readFile(new URL(file, root), 'utf8');

async function swiftFiles(directory) {
  const result = [];
  for (const entry of await readdir(new URL(directory, root), { withFileTypes: true })) {
    const path = `${directory}/${entry.name}`;
    if (entry.isDirectory()) result.push(...await swiftFiles(path));
    else if (entry.isFile() && entry.name.endsWith('.swift')) result.push(path);
  }
  return result;
}

function method(source, name) {
  const start = source.indexOf(`func ${name}(`);
  assert.ok(start >= 0, `missing method ${name}`);
  const opening = source.indexOf('{', start);
  let depth = 0;
  for (let end = opening; end < source.length; end++) {
    if (source[end] === '{') depth++;
    else if (source[end] === '}' && --depth === 0) return source.slice(start, end + 1);
  }
  assert.fail(`unclosed method ${name}`);
}

test('every app speech producer uses the central admission route, including UI actions', async () => {
  for (const file of await swiftFiles('ios/BlindAssist')) {
    if (file.endsWith('/Feedback.swift')) continue;
    const source = await read(file);
    assert.doesNotMatch(source, /\bfeedback\??\s*\.\s*(?:speak(?:Ambient|ReplacingInformation)?|alert)\s*\(/, file);
    assert.doesNotMatch(source, /AVSpeechSynthesizer\s*\(|UIAccessibility\.post\s*\(\s*notification:\s*\.announcement/, file);
    if (!file.endsWith('/NavigationModel.swift')) {
      assert.doesNotMatch(source, /\bfeedback\??\s*\.\s*deliver\s*\(|AdmittedSpeech\s*\(/, file);
    }
  }
});

test('the raw sink requires a capability constructible only beside the attention gate', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const feedback = await read('ios/BlindAssist/Feedback.swift');
  assert.match(model, /struct AdmittedSpeech[\s\S]*?fileprivate init\s*\(/);
  assert.equal((model.match(/AdmittedSpeech\s*\(/g) ?? []).length, 1, 'one capability construction site');
  assert.equal((model.match(/\bfeedback\.deliver\s*\(/g) ?? []).length, 1, 'one raw delivery site');
  assert.match(feedback, /func deliver\s*\([^)]*AdmittedSpeech/);
  for (const line of feedback.split('\n').filter(line => /func (?:speak|speakAmbient|speakReplacingInformation|alert)\s*\(/.test(line))) {
    assert.match(line, /private func/, 'raw speech helpers must not be producer APIs');
  }
  for (const name of ['interruptAmbient', 'stop']) {
    assert.doesNotMatch(method(feedback, name), /\bannounce\s*\(/, `${name} cannot emit a hidden VoiceOver bypass`);
  }
});

test('admission is synchronous and already-admitted information is not charged twice', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const dispatch = method(model, 'deliverCandidate');
  assert.match(dispatch, /alreadyAdmitted/);
  assert.match(dispatch, /companion\.decide\s*\(/);
  assert.match(dispatch, /feedback\.deliver\s*\(/);
  assert.doesNotMatch(dispatch, /\bawait\b|Task\s*\{|DispatchQueue|sleep\(/, 'hazards cannot wait for async admission');
  assert.match(method(model, 'speakCompanionCandidates'), /alreadyAdmitted:\s*true/);
  assert.match(method(model, 'updateCompanionRoom'), /alreadyAdmitted:\s*true/);
});

test('the existing attention moment uses actual sink priority and explicit stationary task focus', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const moment = method(model, 'companionMoment');
  assert.match(moment, /speechPriority/);
  assert.doesNotMatch(moment, /canSpeakAmbient\s*\?\s*nil\s*:\s*\.information/);
  assert.match(moment, /focusedTaskActive:\s*focusedFaceSearch/);
  assert.match(model, /private var focusedFaceSearch:\s*Bool\s*\{\s*#if BLIND_FAMILIAR_PEOPLE\s*return familiarPeople\.isSearching/);
  assert.match(moment, /attention\.stationary\s*\?\s*\.stationary/);
});

test('scene answers still validate evidence and model spatial claims before admission', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const scene = method(model, 'readScene');
  const spatial = scene.indexOf('SpatialClaimGuard.containsSpatialClaim(answer)');
  const delivery = scene.lastIndexOf('deliverCandidate(');
  assert.ok(spatial >= 0 && delivery > spatial, 'model spatial guard precedes answer dispatch');
  for (const required of ['SceneDelivery.allowed(', 'peopleTracking.stillMatches(', 'WearableEvidence.stillMatches(',
    'self.requestID == currentRequest', 'self.assistantDialogue.goalRevision == dialogue.goalRevision',
    'self.indoor.revision == mapRevision', 'self.indoor.alignmentRevision == alignmentRevision']) {
    assert.ok(scene.includes(required), required);
  }
  assert.match(scene, /requested:\s*!automatic/);
});

test('hazards invalidate pending questions and familiar work before admitted alert delivery', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const publish = method(model, 'publish');
  assert.match(publish, /requiresImmediateAttention/);
  assert.match(publish, /cancelDescription\(\)/);
  assert.match(publish, /familiarPeople\.(?:cancel|revalidate)\s*\(/);
  assert.match(publish, /companion\.withdrawOffer\(\)/);
  assert.match(method(model, 'cancelDescription'), /pendingQuestion\s*=\s*nil/);
  const resume = method(model, 'resumePendingQuestion');
  assert.ok(resume.indexOf('pending.isCurrent(') < resume.indexOf('readScene('), 'queued questions revalidate before fresh generation');
  assert.doesNotMatch(resume, /deliverCandidate\(|speakRequested\(|feedback\.deliver\(/, 'old answer text must not resume');
});

test('identity-only snapshot hints remain requested answers, separate from operational status', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const controller = await read('ios/BlindAssist/FamiliarFaceExperiment.swift');
  assert.match(model, /familiarPeople\.onSnapshotHint\s*=/);
  const snapshot = method(controller, 'publishSnapshot');
  assert.ok(snapshot.includes('onSnapshotHint?("Snapshot: might be \\(match.label)'), 'only the tentative label enters the snapshot hint');
  assert.doesNotMatch(snapshot, /clothing|outfit|shirt|trousers|\.describe\(/i);
  assert.match(controller, /var isSearching:\s*Bool\s*\{\s*searching\s*\}/);
  assert.match(controller, /generation == token/);
  assert.match(controller, /familiarSnapshotContextIsCurrent/);
});

test('operation budget exemption is not used for scene, identity or repeat descriptions', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(method(model, 'speakRequested'), /kind:\s*\.answer,\s*requested:\s*true/);
  assert.match(method(model, 'speakOperation'), /kind:\s*\.operation,\s*requested:\s*true/);
  assert.match(model, /familiarPeople\.onStatus\s*=[\s\S]*?speakOperation\(text,\s*revision:\s*self\.familiarPeople\.operationRevision\.uuidString/);
  assert.match(model, /familiarPeople\.onSnapshotHint\s*=\s*\{[^\n]*speakRequested\(text\)/);
  assert.match(method(model, 'repeatDescription'), /speakRequested\(text,\s*narrationID:/);
  assert.match(method(model, 'say'), /speakRequested\(text\)/);
  assert.doesNotMatch(method(model, 'say'), /speakOperation/);
});

test('replacing information preserves safety speech and failed replacement has admitted cancellation feedback', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const feedback = await read('ios/BlindAssist/Feedback.swift');
  const stop = method(feedback, 'stopInformation');
  assert.match(stop, /activePriority\s*!=\s*\.mobility,\s*activePriority\s*!=\s*\.danger/);
  assert.ok(stop.indexOf('activePriority != .danger') < stop.indexOf('speech.stopSpeaking('));
  assert.doesNotMatch(stop, /player\.stop\(/, 'ordinary speech cancellation must not silence the hazard beacon');
  assert.match(method(model, 'dispatchText'), /replace\s*&&\s*!delivered[\s\S]*?requestCancellationAnnouncement\(\)/);
  assert.match(model, /feedback\.onControlAnnouncement\s*=\s*\{[^\n]*speakOperation\(text,\s*replace:\s*false\)/);
});
