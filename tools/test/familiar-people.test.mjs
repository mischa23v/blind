import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { generateProject, familiarModelHashes } from '../generate-xcode-project.mjs';
const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');

// Native source contracts, not execution of Apple callbacks.
function bodyAfter(source, marker) {
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, `Missing source contract: ${marker}`);
  const open = source.indexOf('{', start);
  let depth = 1;
  for (let i = open + 1; i < source.length; i += 1) {
    if (source[i] === '{') depth += 1;
    if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  assert.fail(`Unclosed source contract: ${marker}`);
}

test('default project does not enable or link experimental face inference', () => {
  const value = generateProject(['FamiliarFaceExperiment.swift']);
  assert.doesNotMatch(value, /BLIND_FAMILIAR_PEOPLE|BAFaceEngine\.mm|wrapper\.framework|face_detection_yunet/);
});
test('explicit experimental project links static upstream and controlled model resources', () => {
  assert.throws(() => generateProject([], { familiarPeople: true }));
  const value = generateProject(['FamiliarFaceExperiment.swift'], { familiarPeople: true, opencvFramework: '/external/OpenCV/opencv2.framework', familiarModels: '/external/models' });
  assert.match(value, /BLIND_FAMILIAR_PEOPLE/);
  assert.match(value, /BAFaceEngine\.mm/);
  assert.match(value, /SWIFT_OBJC_BRIDGING_HEADER/);
  assert.match(value, /PBXResourcesBuildPhase/);
  assert.match(value, /EXCLUDED_ARCHS\[sdk=iphonesimulator\*\]/);
  assert.match(value, /-lc\+\+/);
  assert.doesNotMatch(value, /PBXCopyFilesBuildPhase|CodeSignOnCopy/); // static framework must not be embedded
  for (const name of Object.keys(familiarModelHashes)) assert.ok(value.includes(`/external/models/${name}`));
  const both = generateProject([], { multimodal: true, familiarPeople: true, opencvFramework: '/x/opencv2.framework', familiarModels: '/m' });
  assert.match(both, /BLIND_APPLE_MULTIMODAL BLIND_FAMILIAR_PEOPLE/);
});
test('native pipeline uses actual upstream detection, landmark alignment and cosine matching', async () => {
  const code = await read('ios/BlindAssist/FamiliarNative/BAFaceEngine.mm');
  for (const literal of ['cv::FaceDetectorYN::create', 'cv::FaceRecognizerSF::create', 'setInputSize', '->detect', '->alignCrop', '->feature', '->match', 'cv::FaceRecognizerSF::FR_COSINE', 'cv::COLOR_RGBA2BGR', 'faces.rows != 1', 'probe.clone()', 'CV_VERSION_MINOR != 14']) assert.ok(code.includes(literal), literal);
  assert.doesNotMatch(code, /imwrite|NSLog|printf|std::cout/);
});
test('encrypted gallery has device-only key, complete protection, backup exclusion and no image persistence', async () => {
  const code = await read('ios/BlindAssist/FamiliarFaceStore.swift');
  for (const literal of ['AES.GCM.seal', 'AES.GCM.open', 'kSecAttrAccessibleWhenUnlockedThisDeviceOnly', 'kSecAttrSynchronizable as String: false', 'isExcludedFromBackup = true', '.completeFileProtection', 'FileProtectionType.complete', 'SecItemDelete', 'consentAt', 'FamiliarFacePolicy.validFeature']) assert.ok(code.includes(literal), literal);
  assert.doesNotMatch(code, /UIImage|CGImage|CVPixelBuffer|URLSession|UserDefaults/);
});
test('experimental controller discards cancellation, obsolete gallery and stale camera results', async () => {
  const code = await read('ios/BlindAssist/FamiliarFaceExperiment.swift');
  for (const literal of ['var enabled = false', 'generation == token', '!Task.isCancelled', 'model.familiarCaptureIsCurrent(capture)', 'result.faceCount == 1', 'Task.sleep', 'func revalidate', 'FamiliarFacePolicy.candidateForAttempt(', 'try store.save', 'resultCapture = nil']) assert.ok(code.includes(literal), literal);
  assert.match(code.slice(code.indexOf('func reload('), code.indexOf('func prepareForForegroundSession')), /cancel\(\)/);
  assert.match(code.slice(code.indexOf('func deleteAll('), code.indexOf('func review(')), /cancel\(\)/);
  assert.doesNotMatch(code, /URLSession|feedback\.speak|AVSpeech|NSUbiquitousKeyValueStore/);
  // Only a Boolean control is persisted in preferences. All names, consent and
  // biometric records remain in the separately tested encrypted, device-only store.
  assert.match(code, /static func save\(_ value: Bool, in preferences: UserDefaults\)/);
  assert.deepEqual(code.match(/preferences\.set\([^\n]+/g), ['preferences.set(value, forKey: key)']);
  assert.doesNotMatch(code, /UserDefaults\.standard\.(set|register)|preferences\.register/);
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const invalidate = model.slice(model.indexOf('private func invalidatePerceptionWork('), model.indexOf('private func invalidatePerceptionWork(') + 1000);
  assert.match(invalidate, /#if BLIND_FAMILIAR_PEOPLE\s*if !preserveRGBHistoryWork && familiarPeople.enabled && familiarPeople.hasActiveWork \{ familiarPeople.cancel\((?:announce: false)?\)/);
  assert.match(model, /familiarPeople.revalidate\(model: self\)/);
  assert.match(model, /passiveObservationGeneration == capture.generation/);
});
test('enrollment is explicit consent and recognition can always be switched off accessibly', async () => {
  const view = await read('ios/BlindAssist/FamiliarPeopleView.swift');
  for (const literal of ['acknowledged = false', 'familiar-consent', '.disabled(!acknowledged && !experiment.enabled)', 'familiar-disclosure', 'experiment.setEnabled(false)', 'phase != .active', 'familiar-delete-all', 'Confirm exact spoken face action']) {
    assert.ok(view.includes(literal), literal);
  }
  assert.match(view, /Photos or screens may fool it/);
  assert.match(view, /falsely named 7 of 200/);
  assert.match(view, /Child enrollment is unavailable/);
  assert.doesNotMatch(view, /tag\("guardian-for-child"\)/);
  assert.match(view, /cannot establish consent or a family relationship/);
});
test('optional Apple comparison consumes only upstream aligned face and versioned secure prints', async () => {
  const bridge = await read('ios/BlindAssist/FamiliarNative/BAFaceEngine.mm');
  assert.match(bridge, /if \(includeAlignedFace\)/);
  assert.match(bridge, /cv::cvtColor\(aligned, rgb, cv::COLOR_BGR2RGB\)/);
  assert.match(bridge, /aligned.rows != 112 \|\| aligned.cols != 112/);
  const vision = await read('ios/BlindAssist/FamiliarVisionComparison.swift');
  for (const literal of ['alignedRGB.count == 112 * 112 * 3', 'VNGenerateImageFeaturePrintRequestRevision2', 'request.imageCropAndScaleOption = .scaleFill', 'orientation: .up', 'requiringSecureCoding: true', 'stored.revision == Int(revision)', 'stored.cropContract == cropContract', 'stored.osVersion == osVersion', 'reference.requestRevision == revision', 'computeDistance', 'distance.isFinite']) assert.ok(vision.includes(literal), literal);
  assert.doesNotMatch(vision, /CVPixelBuffer|VNGenerateForegroundInstanceMaskRequest|VNRecognizeTextRequest|URLSession|UIImage/);
});
test('second pipeline is opt-in veto only, invalidates toggles, and never silently bypasses missing references', async () => {
  const controller = await read('ios/BlindAssist/FamiliarFaceExperiment.swift');
  assert.match(controller, /var dualPipeline = false/);
  assert.match(controller, /setDualPipeline[^}]*cancel\(\); dualPipeline = value/);
  assert.match(controller, /if !value \{ dualPipeline = false; encounters.reset\(\) \}/);
  assert.ok(controller.indexOf('FamiliarFacePolicy.candidateForAttempt(') < controller.indexOf('FamiliarFacePolicy.corroboratedCandidate(sface: id'));
  assert.match(controller, /includeAlignedFace: dualPipeline/);
  assert.match(controller, /if !enrolling \{ visionDistances = try FamiliarVisionComparison.distances/);
  assert.match(controller, /let token = generation, gallery = people, useVision = dualPipeline/);
  const view = await read('ios/BlindAssist/FamiliarPeopleView.swift');
  assert.match(view, /Both can agree on the wrong person/);
  assert.match(view, /No improvement has been measured on Apple hardware/);
  const store = await read('ios/BlindAssist/FamiliarFaceStore.swift');
  assert.match(store, /guard sealed.count < 512_000/);
  assert.match(store, /visionPrint: FamiliarVisionPrint\?/);
  assert.doesNotMatch(store, /guardian-for-child/);
});

test('multiple examples use bounded per-person means and strict build-selected encrypted profiles', async () => {
  const store = await read('ios/BlindAssist/FamiliarFaceStore.swift');
  for (const literal of ['version: 2', 'archive.version == 2', 'archive.model == Self.modelID', 'examples: [FamiliarExample]', '(1...6).contains(person.examples.count)', 'FamiliarFacePolicy.normalizedMean', 'expectedDimension:', 'profile.backendKind', 'profile.recognizerSHA256', 'profile.detectorSHA256', 'profile.embeddingDimension', 'guard sealed.count < 512_000']) assert.ok(store.includes(literal), literal);
  const vision = await read('ios/BlindAssist/FamiliarVisionComparison.swift');
  assert.match(vision, /person.examples.map/);
  assert.match(vision, /FamiliarFacePolicy.meanVisionDistance/);
  const controller = await read('ios/BlindAssist/FamiliarFaceExperiment.swift');
  for (const literal of ['draft.examples.count >= 3', 'draft.examples.count < 6', 'quality >= 0.25', 'result.faceWidth >= 80', 'result.faceHeight >= 80', 'confirmation.consume(token', 'confirmation.cancel()', 'Labels do not verify relationships']) assert.ok(controller.includes(literal), literal);
});
test('real local PhotosPicker imports bind to enrollment token and never store original images', async () => {
  const view = await read('ios/BlindAssist/FamiliarPeopleView.swift');
  for (const literal of ['import PhotosUI', '.photosPicker(', 'loadTransferable(type: Data.self)', 'photoGeneration == id', 'experiment.enrollmentToken == enrollmentToken', 'photoTask?.cancel()', 'experiment.importPhotos(data)', '.onChange(of: experiment.enrollmentToken)', 'Voice can open it but cannot choose its photos']) assert.ok(view.includes(literal), literal);
  const controller = await read('ios/BlindAssist/FamiliarFaceExperiment.swift');
  for (const literal of ['CGImageSourceCreateWithData', 'CGImageSourceGetCount(source) == 1', 'kCGImageSourceCreateThumbnailWithTransform: true', '20_000_000', 'photos.count <= remainingExamples', 'try accept(result, source: "selected-photo")', 'draft.previews[example.id] = result.alignedRGB']) assert.ok(controller.includes(literal), literal);
  assert.doesNotMatch(view + controller, /URLSession|PHPhotoLibrary.shared\(\).performChanges/);
});
test('voice commands route before generic assistant actions and retain urgent speech priority', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  for (const literal of ['routeFamiliarPeopleCommand(text)', 'routeFamiliarPeopleCommand(question)', 'FamiliarPeopleCommand.parse(text)', 'familiarPeople.handle(command, model: self)', 'speakOperation(text, revision: self.familiarPeople.operationRevision.uuidString)', 'feedback.stopInformation()']) assert.ok(model.includes(literal), literal);
  const view = await read('ios/BlindAssist/FamiliarPeopleView.swift');
  for (const literal of ['.accessibilityAction(.magicTap)', 'model.startVoiceQuestion()', 'model.voice.finish()', 'familiar-voice', 'Generic yes or no does not confirm']) assert.ok(view.includes(literal), literal);
  const feedback = await read('ios/BlindAssist/Feedback.swift');
  assert.match(feedback, /func stopInformation[\s\S]*?delivery\.active\?\.priority != \.mobility, delivery\.active\?\.priority != \.danger/);
});

test('named search is exact-label bounded quiet and reuses current candidate and snapshot publication', async () => {
  const code = await read('ios/BlindAssist/FamiliarFaceExperiment.swift');
  const search = code.slice(code.indexOf('func find(_ label:'), code.indexOf('func handle(_ command:'));
  for (const literal of ['caseInsensitiveCompare(label)', 'FamiliarSearchBudget(', 'for poll in 0..<10', '2_000_000_000', '20_000_000_000', 'budget.consumeAttempt(now: now)', 'model.familiarCaptureIsCurrent(capture)', '== target.id', 'generation == token', 'publishSnapshot(match: target', 'setSilentStatus']) assert.ok(search.includes(literal), literal);
  assert.doesNotMatch(search, /Comparing locally|showFaceGuidance/);
  assert.match(search, /setSilentStatus\("Looking briefly/);
  assert.match(search, /guard !announcedMiss else \{ return \}/);
  assert.ok(search.indexOf('reportFirstMiss(); continue') > search.indexOf('for poll in 0..<10'));
  assert.match(search, /onSearchStarted\?\(\)/);
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(model, /if !automatic \{ familiarPeople.cancelSearchForNewGoal\(\) \}/);
  for (const method of ['setAssistantObjective', 'clearAssistantConversation']) {
    const body = bodyAfter(model, `func ${method}()`);
    assert.match(body, /#if BLIND_FAMILIAR_PEOPLE\s+familiarPeople\.cancelSearchForNewGoal\(\)\s+#endif/);
    const cancellation = body.indexOf('familiarPeople.cancelSearchForNewGoal()');
    const taskMutation = body.indexOf('everydayTasks.');
    assert.ok(taskMutation > cancellation, `${method} cancels familiar search before task mutation`);
    assert.doesNotMatch(body.slice(0, cancellation), /\b(?:return|throw|await)\b/);
  }
  assert.match(code, /searching && \(!model.assistantSession.shouldRunCamera \|\| !model.cameraAwareness \|\| !model.running \|\| model.simulation \|\| model.places.scanning \|\| model.detection.hazard.isUrgent\)/);
});

test('source contract: debug privacy purge cannot bypass familiar search cancellation', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const clear = bodyAfter(model, 'func clearAssistantConversation()');
  // Purge is a standalone side effect, not a success guard or async prerequisite.
  // Its DEBUG block must close before the independent familiar-feature block.
  assert.match(clear, /^\s*#if DEBUG\s+purgeDebugSessionDiagnostics\(\)\s+#endif\s+#if BLIND_FAMILIAR_PEOPLE\s+familiarPeople\.cancelSearchForNewGoal\(\)\s+#endif/);
  assert.ok(clear.indexOf('familiarPeople.cancelSearchForNewGoal()') < clear.indexOf('cancelDescription()'));
  assert.match(clear, /cancelDescription\(\); _ = feedback\.stopInformation\(announceCancellation: false\); stopReturn\(\); indoor\.cancelRoute\(\)/);
  assert.doesNotMatch(clear, /feedback\.stop\(/); // Task changes must preserve independent hazard/status output.
});
test('past snapshot speech has separate bounded lifetime without extending live display', async () => {
  const code = await read('ios/BlindAssist/FamiliarFaceExperiment.swift');
  const publish = code.slice(code.indexOf('private func publishSnapshot'), code.indexOf('func find(_ label:'));
  for (const literal of ['1.5 -', 'resultCapture = nil', 'setSilentStatus', '10_500_000_000', 'snapshotCapture = nil; onCancelSpeech?()', 'Snapshot: might be']) assert.ok(publish.includes(literal), literal);
  assert.match(code, /familiarSnapshotContextIsCurrent/);
  assert.match(code, /shouldSpeakFaceGuidance/);
  assert.match(code, /ask them to look toward you/);
});

test('recognition batches use each detector row and never weaken single-face enrollment', async () => {
  const native = await read('ios/BlindAssist/FamiliarNative/BAFaceEngine.mm');
  const header = await read('ios/BlindAssist/FamiliarNative/BAFaceEngine.h');
  const single = native.slice(native.indexOf('inspectImage:'), native.indexOf('inspectFacesInImage:'));
  assert.match(single, /if \(faces.rows != 1\) return result/);
  for (const text of ['faces.row(row)', 'faces.ptr<float>(row)', 'order[slot]', 'normalizedBounds',
    'ba_face::slots(faces.rows, offset)', 'batch.nextOffset = (slot + 1) % faces.rows',
    'std::chrono::steady_clock', '>= 0.8', 'batch.overCapacity = faces.rows > 32']) assert.ok(native.includes(text), text);
  assert.match(header, /Never an identity or a cross-frame tracking identifier/);
  assert.doesNotMatch(native, /sort[^\n]*area|largestFace|nearestFace|URLSession/);
});

test('active-camera recognition is bounded fresh gallery-bound and has no cached track naming', async () => {
  const code = await read('ios/BlindAssist/FamiliarFaceExperiment.swift');
  const live = code.slice(code.indexOf('func consume(model:'), code.indexOf('func setDualPipeline'));
  for (const text of ['model.captureFamiliarFace()', 'liveTask == nil', 'now - lastLiveAttempt >= 0.75',
    'request == generation', 'token == liveRevision', 'model.familiarCaptureIsCurrent(capture)',
    'nextFaceOffset = batch.nextOffset', 'FamiliarFaceBatchPolicy.uniqueCandidates(raw)',
    'frameID: frameID', 'capturedAt: capture.capturedAt', 'encounters.markAnnounced(identity)',
    'onArrivalHint?', 'onCancelArrivalHint?', '1.5 -']) assert.ok(code.includes(text), text);
  assert.doesNotMatch(live, /peopleTracking|model.start\(|URLSession|onSnapshotHint\?\(/);
  assert.match(code, /if let arrivalCapture, !model.familiarCaptureIsCurrent\(arrivalCapture\)/);
  assert.match(code, /func leaveEnrollmentScreen\(\)[\s\S]*?if draft != nil \|\| pending != nil \|\| showPicker \{ cancel\(\) \}/);
});

test('photos-first enrollment uses an unnamed consented draft but never saves a placeholder identity', async () => {
  const code = await read('ios/BlindAssist/FamiliarFaceExperiment.swift');
  const view = await read('ios/BlindAssist/FamiliarPeopleView.swift');
  for (const text of ['var label: String?', 'requestUnnamedEnrollment()', 'ask(.begin(nil, nil, .new)',
    'setDraftLabel(_ value: String)', 'let label = draft.label', 'cancelSaveConfirmation()',
    'draft.label = name', 'confirmationToken = nil']) assert.ok(code.includes(text), text);
  assert.match(view, /if experiment.hasEnrollmentDraft/);
  assert.match(view, /if experiment.draftExamples.count >= 3/);
  assert.match(view, /if experiment.setDraftLabel\(label\) \{ experiment.finishEnrollment\(\) \}/);
  assert.match(view, /\.onDisappear \{[^\n]*experiment.leaveEnrollmentScreen\(\)/);
  assert.doesNotMatch(view, /\.onDisappear \{[^\n]*setEnabled\(false\)/);
  assert.match(code, /result.faceCount == 1/);
});

