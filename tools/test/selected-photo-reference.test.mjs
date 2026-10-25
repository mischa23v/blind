import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const base = process.env.PHOTO_SOURCE_ROOT ? pathToFileURL(process.env.PHOTO_SOURCE_ROOT + '/') : new URL('../../', import.meta.url);
const read = p => readFile(new URL(p, base), 'utf8');
const section = (text, start, end) => text.slice(text.indexOf(start), text.indexOf(end, text.indexOf(start) + start.length));
test('private photo intent runs after command-origin authorization but before physical mutation', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift'); const body = section(s, 'func receiveCompanionUtterance(', 'private var clockSample:');
  for (const earlier of ['routeClockInquiry(', 'CommandAuthority.permits(.changeGoal']) assert.ok(body.indexOf('routeSelectedPhotoInquiry(') > body.indexOf(earlier), earlier);
  for (const later of ['routeVoiceRoomScan(', 'cancelDescription()', 'routeUnverifiedPhysicalRequest(']) assert.ok(body.indexOf('routeSelectedPhotoInquiry(') < body.indexOf(later), later);
  assert.match(section(s, 'private func routeSelectedPhotoInquiry(', 'func beginExplorePresentation'), /guard origin == \.trustedInterface/);
  const route = section(s, 'private func routeSelectedPhotoInquiry(', 'func beginExplorePresentation');
  assert.match(route, /photoPickerRequested = true/); assert.match(route, /if photoViewID == nil/);
  assert.doesNotMatch(route, /cancelDescription|stopReturn|cancelRoute|objectSearch|readScene|setGoal|recordCompanionMessage/);
});
test('picker assigns source ownership before bounded asynchronous file loading', async () => {
  const s = await read('ios/BlindAssist/ExplorePictureView.swift'); const load = section(s, '.onChange(of: photo)', 'if let snapshot =');
  assert.ok(load.indexOf('model.beginSelectedPhoto(viewID: viewID)') < load.indexOf('loadTransferable'));
  assert.match(load, /loadTransferable\(type: SelectedPhotoTransfer.self\)/); assert.match(load, /selectedPhotoLoadIsCurrent\(selection\)/);
  assert.match(s, /photosPicker\(isPresented: \$pickerPresented/); assert.match(s, /model.photoPickerRequested/); assert.match(s, /model.endExplorePresentation\(viewID\)/);
  assert.doesNotMatch(s, /UIImage\(data:/);
});
test('ImageIO bounds headers and decoded pixels and never persists the transfer', async () => {
  const s = await read('ios/BlindAssist/SelectedPhotoDecoder.swift');
  for (const token of ['FileRepresentation(importedContentType: .image)', 'maximumEncodedBytes + 1', 'data.count == size', 'CGImageSourceGetCount(source) == 1', 'maximumSourcePixels / height', 'CGImageSourceCreateThumbnailWithTransform', 'maximumDecodedSide', 'SHA256.hash(data: data)']) assert.ok(s.includes(token), token);
  assert.ok(s.indexOf('width <= SelectedPhotoReference.maximumSourcePixels / height') < s.indexOf('CGImageSourceCreateThumbnailAtIndex'));
  assert.doesNotMatch(s.replace(/\/\/[^\n]*/g, ''), /write\(|URLSession|upload|UIImage\(data:/);
});
test('native photo reader preserves complete source records outside model budgets', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift'); const photo = section(s, 'func explorePhoto(', '\nextension CGImagePropertyOrientation');
  assert.match(photo, /SelectedPhotoReference.neutralCategories/); assert.match(photo, /kind: \.historicalMemory/); assert.match(photo, /sourceID: selection.id/);
  assert.match(photo, /blocks \+= texts.map/); assert.match(photo, /selectedPhoto.install/); assert.match(photo, /selectedPhoto.revalidate/);
  assert.doesNotMatch(photo.replace(/\/\/[^\n]*/g, ''), /\.prefix\(|cancelDescription\(|CompanionToolRuntime|LocalImageAssistant|answerConversation|URLSession|saveValue/);
  const privacy = section(s, 'func clearAssistantConversation()', '@discardableResult func correctConversationRecord'); assert.match(privacy, /clearExploreSnapshot\(\)/);
});
test('photo output uses normal gates, actual callbacks, and original source expiry', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift'); const speech = section(s, 'private func speakNextSelectedPhotoPhrase()', '/// User-selected library photo,');
  for (const token of ['selectedPhoto.revalidate(context)', 'feedback.speechPriority == nil', 'selectedPhoto.begin', 'dispatchText(phrase.text, kind: .answer, requested: true, replace: false, speechID: phrase.id)', 'selectedPhoto.finish(id: id, text: text, outcome: outcome, context: context)']) assert.ok(speech.includes(token), token);
  assert.match(s, /self.finishSelectedPhotoSpeech\(id: id, text: text, outcome: outcome\)/);
  const timer = section(s, 'private func startSelectedPhotoExpiry()', 'private func speakNextSelectedPhotoPhrase()'); assert.match(timer, /selectedPhoto.revalidate/); assert.doesNotMatch(timer, /\.finish\(/);
});

test('selected photo Vision retains low-confidence OCR qualifiers without weakening camera threshold', async () => {
  const s = await read('ios/BlindAssist/VisionService.swift');
  assert.match(s, /VNImageRequestHandler\(cgImage: photo, orientation: orientation\).*retainAllText: true/);
  assert.match(s, /retainAllText: Bool = false/); assert.match(s, /retainAllText \|\| line.confidence >= 0.5/);
  assert.match(s, /\[low confidence\]/); assert.match(s, /qualifier \+ line.string/);
});

test('one native photo lease survives UI cancellation until actual decode or Vision completion', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift'); const view = await read('ios/BlindAssist/ExplorePictureView.swift');
  const begin = section(s, 'func beginSelectedPhoto(', 'func finishSelectedPhotoNativeWork(');
  assert.match(begin, /selectedPhotoNativeLease == nil/); assert.match(begin, /selectedPhotoNativeLease = selection\?\.id/);
  const clear = section(s, 'private func clearSelectedPhotoReference()', 'private func startSelectedPhotoExpiry()'); assert.doesNotMatch(clear, /selectedPhotoNativeLease = nil/);
  assert.match(view, /if !handedToVision \{ model.finishSelectedPhotoNativeWork\(selection\)/);
  assert.match(s, /defer \{ self\?\.finishSelectedPhotoNativeWork\(selection\) \}/);
});

test('camera cancellation is separate; photo interruption and quiet clear the whole snapshot', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  const cancel = section(s, 'private func cancelDescription()', 'private func publish()'); assert.doesNotMatch(cancel, /selectedPhotoTask|selectedPhotoNativeLease|selectedPhoto\./);
  const photo = section(s, 'func explorePhoto(', '\nextension CGImagePropertyOrientation'); assert.match(photo, /selectedPhotoTask = Task/); assert.match(photo, /self.selectedPhoto.selection\?\.id == token/); assert.doesNotMatch(photo, /self.exploreRequest/);
  assert.match(s, /if selectedPhoto.selection != nil \{ clearExploreSnapshot\(\) \}/); assert.match(s, /func stopDescriptions\(\) \{\s*clearExploreSnapshot\(\)/);
});

test('helper ingress and delayed actual speech start enforce photo ownership', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift'), f = await read('ios/BlindAssist/Feedback.swift'), v = await read('ios/BlindAssist/ExplorePictureView.swift');
  const ingress = section(s, 'func readScene(', 'private static func wordCount(');
  assert.ok(ingress.indexOf('routeSelectedPhotoInquiry(question, origin: .trustedInterface)') < ingress.indexOf('stopReadingTool(announce: false)'));
  const start = section(f, 'didStart utterance:', 'func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish');
  assert.match(start, /requestedSpeechPermission\?\(id, active.text\) == false/); assert.match(start, /stopSynthesizer: true/);
  assert.match(v, /if photoLoadGeneration == generation \{ photoLoadTask = nil \}/);
});

test('selected-photo source text is omitted from opt-in debug output records', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift'), f = await read('ios/BlindAssist/Feedback.swift');
  assert.match(s, /privateReference = speechID.map \{ selectedPhotoSpeechIDs.contains/);
  assert.match(s, /privateReference \? nil : candidate.text/); assert.match(s, /AdmittedSpeech\(candidate, privateReference: privateReference\)/);
  for (const token of ['admitted.privateReference ? nil : admitted.text', 'admitted.privateReference ? nil : attempt.text', 'currentPrivateReference ? nil : completion.attempt.text', 'currentPrivateReference ? nil : active.text']) assert.ok(f.includes(token), token);
});

test('failed Vision extraction is unreadable, never a successful empty reference', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift'), v = await read('ios/BlindAssist/ExplorePictureView.swift');
  const photo = section(s, 'func explorePhoto(', '\nextension CGImagePropertyOrientation');
  assert.match(photo, /guard let recognizedRegions = result.0 else/); assert.match(photo, /self.failSelectedPhotoReference\(\); return/);
  assert.doesNotMatch(photo, /exploreRegions[^\n]*\?\? \[\]/); assert.match(v, /photoLoadFailed \|\| model.photoReferenceFailed/);
});

test('the normal generated Xcode source phase includes the bounded photo decoder', async () => {
  const { readdir } = await import('node:fs/promises');
  const { generateProject } = await import('../generate-xcode-project.mjs');
  const files = (await readdir(new URL('ios/BlindAssist/', base))).filter(f => f.endsWith('.swift')).sort();
  assert.ok(files.includes('SelectedPhotoDecoder.swift'));
  const project = generateProject(files);
  assert.match(project, /BlindAssist\/SelectedPhotoDecoder\.swift/);
  const { createHash } = await import('node:crypto');
  const buildID = createHash('sha256').update('build:SelectedPhotoDecoder.swift').digest('hex').slice(0, 24).toUpperCase();
  assert.ok(project.includes(buildID + ' = { isa = PBXBuildFile;'));
  assert.ok(project.includes('files = (') && project.includes(buildID + ','));
  const checkedIn = await read('ios/BlindAssist.xcodeproj/project.pbxproj');
  assert.equal(checkedIn, project, 'Checked-in normal project must match generated source membership');
});
