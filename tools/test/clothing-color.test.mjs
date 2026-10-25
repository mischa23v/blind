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
  assert.match(source, /if currencyActive \|\| \(!preserveRGBHistoryWork && \(colorActive \|\| readingTool != nil\)\) \|\| currencyRetake\.isPending \{ cancelDescription\(\) \}/);
});

test('requested colour checks fresh RGB capture and typed ambiguity without a depth or manual-centre gate', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const route = source.slice(source.indexOf('func routeClothingColorCommand('), source.indexOf('private func visualCapturePoseAllowed('));
  assert.match(route, /let capturedAt = frame\.timestamp/);
  assert.match(route, /clothingColors\.inspect\(image: image, orientation: \.right\)/);
  assert.match(route, /case \.anonymousAppearance\(let result, _\)/);
  assert.match(route, /case \.unresolved\(let reason\)/);
  assert.match(route, /reason\.speech\(arabic: self\.arabic\)/);
  assert.equal((route.match(/requestedColorCaptureAllowed\(/g) ?? []).length, 6);
  assert.match(route, /requestID == request, passiveObservationGeneration == generation, attention\.stationary/);
  assert.match(route, /assistantSession\.generation == sessionGeneration/);
  assert.match(route, /!detection\.hazard\.isUrgent/);
  assert.match(route, /now - capturedAt <= \(playback \? 12 : 2\)/);
  assert.match(route, /FrameTimestampPolicy\.isFresh\(capturedAt: frame\.timestamp, receivedAt: now\)/);
  assert.match(route, /visualCapturePoseAllowed\(origin: origin, forward: forward\)/);
  assert.match(route, /if case \.normal = frame\.camera\.trackingState/);
  assert.match(route, /try Task\.checkCancellation\(\)/);
  assert.match(route, /transform\.columns\.2\.y/);
  assert.match(route, /if ClothingColorCommand\.requiresNeutralVerification\(text\)/);
  assert.match(route, /ClothingColor\.Result\.nearNeutral\.speech/);
  assert.match(route, /I haven't confirmed it's the item you mean/);
  assert.match(route, /speakRequested\(text, speechID: id\)/);
  assert.match(route, /requestedColorSpeech = \(id, request, generation, sessionGeneration, capturedAt, origin, forward, requiresCapture\)/);
  assert.match(route, /!assistantSession\.privateAudioHeld/);
  assert.match(route, /forward: speech\.forward, playback: true/);
  assert.match(route, /feedback\.stopRequestedSpeech\(speech\.id\)/);
  assert.doesNotMatch(route, /narrationID:/);
  assert.doesNotMatch(route, /perceptionResultAllowed|SceneDelivery|lastObservation|awaitingPlace|hazard == \.observing|Hold one|in the centre|isolate the fabric/);
  assert.doesNotMatch(route, /LocalImageAssistant|LanguageModelSession|SceneQuestionClient/);
});

test('depth-only loss preserves requested RGB colour ownership while full camera invalidation retires it', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const route = source.slice(source.indexOf('func routeClothingColorCommand('), source.indexOf('private func visualCapturePoseAllowed('));
  const invalidation = source.slice(source.indexOf('private func invalidatePerceptionWork('), source.indexOf('private func invalidateRecognizedRoom()'));
  assert.match(route, /let capturedAt = frame\.timestamp, generation = passiveObservationGeneration, request = requestID/);
  assert.match(route, /requestID == request, passiveObservationGeneration == generation/);
  assert.doesNotMatch(route, /generation = perceptionGeneration|perceptionGeneration == generation/);
  assert.match(invalidation, /\(!preserveRGBHistoryWork && \(colorActive \|\| readingTool != nil\)\)/);
  assert.match(invalidation, /if !preserveRGBHistoryWork \{ backgroundPerception\.invalidate\(\); passiveObservationGeneration = UUID\(\) \}/);
  assert.match(route, /assistantSession\.generation == sessionGeneration/);
  assert.match(route, /!detection\.hazard\.isUrgent/);
  assert.match(route, /FrameTimestampPolicy\.isFresh/);
  assert.match(route, /visualCapturePoseAllowed/);
  assert.match(route, /if case \.normal = frame\.camera\.trackingState/);
});

test('requested color playback clears only its exact ownership on completion and cancellation', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(source, /if self\.requestedColorSpeech\?\.id == id \{ self\.requestedColorSpeech = nil \}/);
  const cancel = source.slice(source.indexOf('private func cancelDescription()'), source.indexOf('private func publish()'));
  assert.match(cancel, /if let speech = requestedColorSpeech \{\s*requestedColorSpeech = nil; feedback\.stopRequestedSpeech\(speech\.id\)/);
  const publish = source.slice(source.indexOf('private func publish()'), source.indexOf('func session(', source.indexOf('private func publish()')));
  assert.match(publish, /revalidateRequestedColorSpeech\(\)/);
  const watchdog = source.slice(source.indexOf('private func startWatchdog()'), source.indexOf('func session(_ session: ARSession, didUpdate frame: ARFrame)'));
  assert.match(watchdog, /self\.revalidateRequestedColorSpeech\(\)/);
});

test('contextual captured-view pose retains optical pitch rather than navigation heading', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const start = source.indexOf('let image = frame.capturedImage, arabic = self.arabic, goalText = contextualGoalText');
  const capture = source.slice(start, source.indexOf('contextualTaskLease = lease', start));
  assert.match(capture, /let transform = frame\.camera\.transform/);
  assert.match(capture, /let forward = Point3\(-Double\(transform\.columns\.2\.x\), -Double\(transform\.columns\.2\.y\), -Double\(transform\.columns\.2\.z\)\)/);
  assert.doesNotMatch(capture, /forward = observation\.forward/);
});

test('colour reader uses one anonymous isolated instance, not centre or whole-frame averages', async () => {
  const source = await read('ios/BlindAssist/ClothingColorReader.swift');
  const policy = await read('BlindCore/Sources/BlindCore/ClothingColorTarget.swift');
  assert.match(source, /CGColorSpace\(name: CGColorSpace\.sRGB\)/);
  assert.match(source, /context\.render\(normalized, to: buffer/);
  assert.match(source, /VNImageRequestHandler\(cvPixelBuffer: buffer, orientation: \.up\)/);
  assert.match(source, /VNGenerateForegroundInstanceMaskRequest/);
  assert.match(source, /kCVPixelFormatType_OneComponent8/);
  assert.match(source, /ClothingColorTarget\.select\(labels: labels/);
  assert.match(source, /selection\.samplePixels\.map/);
  assert.match(source, /anonymousAppearance\(ClothingColor\.evaluate\(samples\), bounds: selection\.bounds\)/);
  assert.match(source, /VNDetectHumanRectanglesRequest/);
  assert.match(source, /y: Double\(1 - box\.maxY\)/);
  assert.doesNotMatch(source, /label\(mw\/2|height\*3\/10|boundingBox\.contains\(CGPoint\(x: 0\.5/);
  assert.match(policy, /instances\.count > 1.*multipleForegroundItems/);
  assert.match(policy, /validInstances\.contains\(label\)/);
  assert.match(policy, /!bounds\.overlaps\(\$0\)/);
  assert.match(policy, /samples\.count >= 64, Double\(samples\.count\) \/ Double\(candidates\) >= 0\.8/);
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


test('requested and contextual colour share a native lease that timeout and cancellation cannot release', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const state = await read('BlindCore/Sources/BlindCore/ColorInspectionWork.swift');
  const route = source.slice(source.indexOf('func routeClothingColorCommand('), source.indexOf('private func visualCapturePoseAllowed('));
  const cancel = source.slice(source.indexOf('private func cancelDescription()'), source.indexOf('private func publish()'));
  const timeout = route.slice(route.indexOf('private func expireRequestedColor('), route.indexOf('private func requestedColorOwnerAllowed('));
  assert.match(source, /colorInspectionWork\.isAvailable \? \.available : \.unavailable/);
  assert.match(source, /colorInspectionWork\.begin\(owner: \.contextual\(lease\.id\)/);
  assert.match(route, /colorInspectionWork\.begin\(owner: \.requested\(request\)/);
  assert.equal((source.match(/colorInspectionWork\.completeNative\(nativeLease\)/g) ?? []).length, 2);
  assert.match(cancel, /colorInspectionWork\.cancelRequested\(\); requestedColorWork = nil/);
  assert.doesNotMatch(cancel, /completeNative|colorInspectionWork =/);
  assert.match(source, /self\.expireRequestedColor\(now: now\)/);
  assert.match(timeout, /colorInspectionWork\.expireRequested\(now: now\)/);
  assert.match(timeout, /busy = false; colorActive = false; questionTask = nil/);
  assert.match(timeout, /settleUnavailableColor\(/);
  assert.doesNotMatch(timeout, /completeNative|colorInspectionWork =/);
  assert.match(state, /requestedLifetime: Double = 6/);
  assert.match(state, /guard nativeLease\?\.id == lease\.id else \{ return false \}/);
  assert.equal((route.match(/completionDisposition\(nativeLease/g) ?? []).length, 2);
  assert.equal((route.match(/case \.unavailable:\s*self\.settleUnavailableColor/g) ?? []).length, 2);
  assert.match(route, /outcome: \.unavailable, ticketID: everydayID/);
  assert.match(route, /requiresCapture: false/);
  assert.match(route, /let evidenceAllowed = speech\.requiresCapture/);
  assert.match(route, /guard ownerAllowed, evidenceAllowed else/);
});
