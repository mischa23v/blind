import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const model = readFileSync(new URL('../../ios/BlindAssist/NavigationModel.swift', import.meta.url), 'utf8');
const vision = readFileSync(new URL('../../ios/BlindAssist/VisionService.swift', import.meta.url), 'utf8');
const section = (start, end) => model.slice(model.indexOf(start), model.indexOf(end, model.indexOf(start)));
const contextual = section('private var contextualGoalText', '/// Explicit single-photo money request');

test('foreground frame loop schedules contextual capabilities without a mode command', () => {
  assert.match(model, /updateBackgroundPerception\(frame: frame, observation: observation, nonspatialOnly: !observation.trackingNormal\)/);
  assert.ok(model.indexOf('phoneDetection = detector.process(observation)') < model.indexOf('updateBackgroundPerception(frame: frame, observation: observation, nonspatialOnly: !observation.trackingNormal)'));
  assert.match(contextual, /ContextualCapabilityScheduler.Goal.infer\(from: contextualGoalText\)/);
  assert.doesNotMatch(section("private var contextualGoalText", "private func cancelVoiceRoomScanConfirmation"), /startReadingTool\(|routeSaudiBanknoteCommand\(|routeClothingColorCommand\(|cancelDescription\(/);
});
test('contextual jobs retain capture leases, existing verifier and final target gates', () => {
  for (const value of ['requestID: requestID', 'perceptionGeneration: passiveObservationGeneration', 'sessionGeneration: assistantSession.generation', 'goalGeneration: companionWorkingState.goalRevision', 'self.contextualCapabilities.beforeSpeech', 'self.visualCapturePoseAllowed', 'self.contextualCaptureAllowed']) assert.ok(contextual.includes(value), value);
  assert.match(contextual, /SaudiBanknoteReferenceRecognition.isAvailable/);
  assert.match(contextual, /promoteCurrencyCandidate/);
  assert.match(contextual, /saudiBanknotes.inspect\(image: image, orientation: .right\)/);
  assert.match(contextual, /observe\(verifiedDenomination: value/);
  assert.match(contextual, /finish\(activeLease, outcome: outcome/);
  assert.doesNotMatch(contextual, /languageModel|FoundationModels|URLSession|cloud: true/);
});
test('passive rectangles never speak a value without the reference verifier', () => {
  const probe = vision.slice(vision.indexOf('static func currencyRectangleCandidate'), vision.indexOf('/// The first decoded barcode'));
  assert.match(probe, /VNDetectRectanglesRequest/);
  assert.match(probe, /maximumObservations = 4/);
  assert.doesNotMatch(probe, /denomination|speech\(|label|OCR/);
  assert.match(contextual, /if case .denomination\(let value\) = result/);
  assert.match(contextual, /if goal.contains\(.payment\)/);
});
test('relevant OCR/barcode/color use existing native evidence, not unsolicited mode speech', () => {
  assert.match(contextual, /VisionService.textLines/);
  assert.match(contextual, /ContextualTextPolicy.select/);
  assert.match(contextual, /!code.isQR, let name = self.products.name/);
  assert.match(contextual, /self.clothingColors.inspect/);
  assert.match(contextual, /centralIsolatedItem: true/);
  assert.doesNotMatch(contextual, /feedback.beacon|CodeReading.speech|startReadingTool/);
  assert.match(contextual, /self.deliverCandidate\(candidate, speechID: id, nonspatialCapture: activeLease\)/);
});
test('room scan requests originate only in direct utterance path and confirm before start', () => {
  assert.match(model, /if routeVoiceRoomScan\(text\) \{ return \}/);
  assert.match(contextual, /voiceRoomScan.consume\(text, source: .directUser/);
  assert.match(contextual, /case .requestConfirmation/);
  assert.match(contextual, /if !dispatchText\(prompt, kind: .operation, requested: true, replace: true, speechID: id\)/);
  assert.match(contextual, /guard let promptContext, promptContext.delivered/);
  assert.match(contextual, /case .cancel:[\s\S]*?places.cancelScanAndResume/);
  assert.match(contextual, /case .stop:[\s\S]*?places.finishScan/);
  assert.match(model, /private func stopCameraMonitoring\(\) \{\s*voiceRoomScan.cancel\(\)/);
  assert.match(model, /func suspendExperience\(\) \{\s*voiceRoomScan.cancel\(\)/);
  assert.match(model, /func endConversation\(\) \{\s*voiceRoomScan.cancel\(\)/);
});
test('room scanning does not end continuous listening or falsely retain camera path alerts', () => {
  const scan = section('func scanPlace(name:', 'func recognize(_ place:');
  assert.doesNotMatch(scan, /voice.endManualTurn|voice.cancel/);
  assert.match(scan, /Camera path alerts are off until the scan ends/);
});

test('contextual job cleanup and native timeout retain exact lease ownership', () => {
  assert.match(contextual, /self.contextualTaskLease\?\.id == lease.id/);
  assert.match(contextual, /contextualOutstanding.values.filter/);
  assert.match(contextual, /contextualTimedOut.insert\(active.capability\)/);
  assert.match(contextual, /self.contextualOutstanding\[lease.id\] = nil/);
  assert.match(model, /if automatic, contextualTask != nil \|\| !contextualOutstanding.isEmpty \{ return \}/);
});
test('contextual outputs honor existing signs and objects settings', () => {
  assert.match(contextual, /activeLease.capability == .text \? "signs" : "objects"/);
  assert.match(contextual, /category: category, requested: false/);
});
test('scan approval waits for matching completed warning and starts its response clock then', () => {
  const completion = section('feedback.onRequestedSpeechFinished =', 'feedback.onIdle =');
  assert.match(completion, /prompt.id == id/);
  assert.match(completion, /outcome == .completed/);
  assert.match(completion, /prompt.session == self.assistantSession.generation/);
  assert.match(completion, /prompt.goal == self.companionWorkingState.goalRevision/);
  assert.match(completion, /self.voiceRoomScan.promptDidFinish\(now:/);
  assert.match(completion, /else \{ self.cancelVoiceRoomScanConfirmation\(\) \}/);
});
