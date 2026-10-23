// Wiring checks; real recognition, depth association and Apple runtime remain device gates.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = p => readFile(new URL(`../../${p}`, import.meta.url), 'utf8');
const section = (s, a, b) => s.slice(s.indexOf(a), s.indexOf(b, s.indexOf(a)));
test('passive observations enter foreground loop independently of a find command', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(s, /updateBackgroundPerception\(frame: frame, observation: observation, nonspatialOnly: !observation.trackingNormal\)/);
  const p = section(s, 'private func updatePassiveObjectMemory', 'private func importFurnitureHistory');
  assert.match(p, /Task.detached\(priority: .utility\)/);
  assert.match(p, /passiveObservationGeneration == generation/);
  assert.match(p, /observationFrameID == sessionFrameID/);
  assert.match(p, /assistantSession.foregroundActive/);
  assert.match(p, /associationValidated: false/);
  assert.doesNotMatch(p, /LocalImageAssistant|confirmedInstanceID:/);
});
test('historical retrieval precedes another current-view search and never saves camera as object', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  const p = section(s, 'private func findWithSensors', 'private func locate(');
  assert.ok(p.indexOf('observedObjects.recall') < p.indexOf('findItemByLook'));
  assert.match(s, /let position: Point3\? = nil/);
  assert.match(s, /private static let objectInteractionGuidanceValidated = false/);
});
test('voice onset captures original search, explicit controls cancel and current delivery checks pose', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  const onset = section(s, 'voice.onSpeechBegan', 'voice.onReadyForReply');
  assert.ok(onset.indexOf('interruptedSearch.capture') < onset.indexOf('cancelDescription'));
  const resume = section(s, 'private func resumeInterruptedSearchIfPossible', 'private func persistItems');
  assert.match(resume, /interruptedSearch.restore/);
  assert.doesNotMatch(resume, /ObjectSearch\(target:/);
  const offer = section(s, 'private func offerObservedGoalMatch', 'private func deliverObjectSearchMatch');
  assert.match(offer, /SceneDelivery.allowed/);
  assert.match(offer, /!companionWorkingState.goal.isEmpty/);
  assert.match(offer, /pendingPassiveNotice == nil/);
  assert.match(s, /outcome == .completed, pending.revision == self.companionWorkingState.goalRevision/);
});
test('runtime detector rejects incompatible raw tensor results and has no classifier geometry fallback', async () => {
  const s = await read('ios/BlindAssist/VisionService.swift');
  assert.match(s, /private static let detectorModel: Result<VNCoreMLModel, Error>/);
  assert.match(s, /guard let objects = results as\? \[VNRecognizedObjectObservation\]/);
  const p = section(s, 'static func objectCandidates', '/// Accept any compatible');
  assert.doesNotMatch(p, /VNClassifyImageRequest/);
  assert.match(p, /\.prefix\(16\)/);
});
test('history is bounded private storage, deletable and old scans do not resurrect after clear', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(s, /namespace: "observed-objects"/);
  assert.match(s, /memory.deleteValue\(namespace: "observed-objects", id: "all"\)/);
  assert.match(s, /deletion-cutoffs/);
  assert.match(await read('ios/BlindAssist/SavedMemoryView.swift'), /Delete sighting history/);
  assert.match(await read('BlindMemory/Sources/BlindMemory/MemoryStore.swift'), /case "observed-objects": return 256 \* 1024/);
});
test('completion is accounted on the actual speech callback and stopped sessions stay quiet', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  const callback = section(s, 'feedback.onRequestedSpeechFinished', 'feedback.onIdle');
  assert.match(callback, /pendingPassiveNotice/);
  assert.match(callback, /outcome == .completed/);
  const offer = section(s, 'private func offerObservedGoalMatch', 'private func deliverObjectSearchMatch');
  assert.match(offer, /assistantSession.state == .active/);
});
test('room transitions and privacy changes cannot relabel or resurrect old captures', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(s, /establishedRoom == companion.currentRoom \? establishedRoom : nil/);
  const forget = section(s, 'func forgetItem(', 'var savedRooms');
  assert.match(forget, /invalidatePerceptionWork\(\)/);
  assert.match(forget, /try removeObservedHistory\(category: item.name\)/);
  const remove = section(s, 'private func removeObservedHistory', 'var savedItems');
  assert.match(remove, /try memory.saveValue/);
  assert.doesNotMatch(remove, /try\?/);
  const deletion = section(s, 'func deletePlace(', 'func forgetRoom(');
  assert.match(deletion, /try removeObservedHistory\(room: roomID\)/);
});

test('continuous pose/hazard cadence is separate from bounded async visual observations', async () => {
  const source = await readFile(new URL('../../ios/BlindAssist/NavigationModel.swift', import.meta.url), 'utf8');
  const frames = source.slice(source.indexOf('func session(_ session: ARSession, didUpdate frame: ARFrame)'), source.indexOf('// MARK:', source.indexOf('func session(_ session: ARSession, didUpdate frame: ARFrame)')));
  assert.match(frames, /frame.timestamp - lastProcessed >= 1.0 \/ 15/);
  assert.ok(frames.indexOf('detector.process(observation)') < frames.indexOf('updateBackgroundPerception(frame: frame, observation: observation, nonspatialOnly: !observation.trackingNormal)'));
  const beforeSampling = frames.slice(0, frames.indexOf('DepthSampler.observation(from: frame)'));
  assert.doesNotMatch(beforeSampling, /guard[^\n]*(?:busy|feedback\.speaking|currencyActive|objectSearch)/);
  assert.match(source, /now - lastPassiveObservation >= 3/);
  assert.match(source, /Task.detached\(priority: \.utility\)/);
});
