import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { assertDepthHazardsBefore } from './helpers/navigation-source-contract.mjs';
const model = readFileSync(new URL('../../ios/BlindAssist/NavigationModel.swift', import.meta.url), 'utf8');
const vision = readFileSync(new URL('../../ios/BlindAssist/VisionService.swift', import.meta.url), 'utf8');
const section = (start, end) => model.slice(model.indexOf(start), model.indexOf(end, model.indexOf(start)));
const contextual = section('private var contextualGoalText', '/// Explicit single-photo money request');

// Source contracts, not native execution or acoustic identity verification.
function declaration(source, signature) {
  const start = source.indexOf(signature);
  assert.ok(start >= 0, `Missing declaration: ${signature}`);
  const first = source.indexOf('{', start);
  assert.ok(first >= 0, `Missing body: ${signature}`);
  let depth = 0;
  for (let index = first; index < source.length; index++) {
    if (source[index] === '{') depth++;
    if (source[index] === '}' && --depth === 0) return source.slice(start, index + 1);
  }
  assert.fail(`Unclosed declaration: ${signature}`);
}
const scanCancellationEntries = [
  ['private func stopCameraMonitoring()', ['nativeObservations.stop()', 'voiceRoomScan.cancel()']],
  ['func suspendExperience()', ['voiceRoomScan.cancel()']],
  ['func endConversation()', ['voiceRoomScan.cancel()']]
];
function assertScanCancellationPrefixes(source) {
  for (const [signature, calls] of scanCancellationEntries) {
    const scoped = declaration(source, signature);
    const body = scoped.slice(scoped.indexOf('{') + 1);
    const escaped = calls.map(call => call.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    // Only whitespace may precede/between these synchronous calls: no Task,
    // dispatch, await, early return or unrelated state mutation may intervene.
    assert.match(body, new RegExp(`^\\s*${escaped.join('\\s*')}\\s*(?:\\n|$)`), signature);
  }
}
function assertTrustedScanEntry(source) {
  const receive = declaration(source, 'func receiveCompanionUtterance(');
  const origin = 'let origin: CompanionCommandOrigin = fromVoice ? .unverifiedMicrophone : .trustedInterface';
  const gate = 'guard CommandAuthority.permits(.changeGoal, from: origin) else';
  const route = 'if routeVoiceRoomScan(text) { return }';
  assert.ok(receive.includes(origin));
  assert.ok(receive.indexOf(origin) < receive.indexOf(gate));
  const denial = declaration(receive, gate);
  assert.match(denial, /receiveUnverifiedConversation\(text, origin: origin\)\s*return\s*\}/);
  assert.doesNotMatch(denial, /routeVoiceRoomScan/);
  assert.ok(receive.indexOf(gate) + denial.length < receive.indexOf(route));
  assert.equal((source.match(/routeVoiceRoomScan\(text\)/g) ?? []).length, 1);
}

test('foreground frame loop schedules contextual capabilities without a mode command', () => {
  assert.match(model, /updateBackgroundPerception\(frame: frame, observation: observation, nonspatialOnly: !observation.trackingNormal\)/);
  assertDepthHazardsBefore(model, 'updateBackgroundPerception(frame: frame, observation: observation, nonspatialOnly: !observation.trackingNormal)');
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
  const assertRectangleCandidate = source => {
    // The actual balanced method, not a later prose-comment sentinel. Adjacent
    // barcode/exploration methods may legitimately contain labels or OCR.
    const probe = declaration(source, 'static func currencyRectangleCandidate(');
    assert.match(probe, /throws -> Bool \{/);
    assert.match(probe, /VNDetectRectanglesRequest/);
    assert.match(probe, /maximumObservations = 4/);
    assert.match(probe, /return request\.results\?\.count == 1\s*\}$/);
    assert.doesNotMatch(probe, /denomination|speech\(|label|OCR/);
    return probe;
  };
  const probe = assertRectangleCandidate(vision);
  // Every original reference-verifier/payment gate remains required.
  assert.match(contextual, /if case .denomination\(let value\) = result/);
  assert.match(contextual, /if goal.contains\(.payment\)/);
  for (const forbidden of ['let denomination = 100', 'speech("100 riyals")', 'let label = "100"', 'OCR()']) {
    const changed = probe.replace('return request.results?.count == 1',
      `if true { ${forbidden} }\n        return request.results?.count == 1`);
    assert.notEqual(changed, probe);
    assert.throws(() => assertRectangleCandidate(vision.replace(probe, changed)), { name: 'AssertionError' });
  }
  const neighbor = '\n    static func unrelatedNeighbor() { let denomination = 100; speech("label OCR") }';
  assert.equal(assertRectangleCandidate(vision.replace(probe, probe + neighbor)), probe,
    'Unrelated next-method text must not expand the rectangle candidate boundary');
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
test('room scan requests require trusted UI rather than microphone authority and confirm before start', () => {
  assertTrustedScanEntry(model);
  assert.match(contextual, /voiceRoomScan.consume\(text, source: .directUser/);
  assert.match(contextual, /case .requestConfirmation/);
  assert.match(contextual, /if !dispatchText\(prompt, kind: .operation, requested: true, replace: true, speechID: id\)/);
  assert.match(contextual, /guard let promptContext, promptContext.delivered/);
  assert.match(contextual, /case .cancel:[\s\S]*?places.cancelScanAndResume/);
  assert.match(contextual, /case .stop:[\s\S]*?places.finishScan/);
  assertScanCancellationPrefixes(model);
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


test('room-scan lifecycle prefix contracts reject missing, reordered or asynchronously deferred cancellation', () => {
  for (const [signature, calls] of scanCancellationEntries) {
    const original = declaration(model, signature);
    const replaceBody = changed => model.replace(original, changed);
    for (const call of calls) {
      assert.throws(() => assertScanCancellationPrefixes(replaceBody(original.replace(call, ''))), `${signature}: missing ${call}`);
    }
    for (const call of calls) {
      for (const gap of ['Task { await pause() }', 'DispatchQueue.main.async {}', 'await pause()', 'return', 'cameraRecovery.pause()']) {
        const changed = original.replace(call, `${gap}\n        ${call}`);
        assert.throws(() => assertScanCancellationPrefixes(replaceBody(changed)), `${signature}: gap ${gap} before ${call}`);
      }
    }
  }
  const reversed = model.replace('nativeObservations.stop()\n        voiceRoomScan.cancel()',
    'voiceRoomScan.cancel()\n        nativeObservations.stop()');
  assert.notEqual(reversed, model);
  assert.throws(() => assertScanCancellationPrefixes(reversed));
});

test('optional mesh diagnostics follow critical lifecycle retirement and precede pause or recovery', () => {
  const hook = '#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n        meshCandidateDiagnostics.stop()\n        #endif';
  const entries = [
    ['private func stopCameraMonitoring()', 'nativeObservations.stop()\n        voiceRoomScan.cancel()\n        retireBodyWarning(publishChange: false)\n        withObservedScene { $0.stop() }', 'cameraRecovery.pause()'],
    ['func sessionWasInterrupted(_ session: ARSession)', 'retireBodyWarning(publishChange: false)\n        nativeObservations.stop()\n        withObservedScene { $0.stop() }', 'cameraRecovery.pause()'],
    ['func session(_ session: ARSession, didFailWithError error: Error)', 'retireBodyWarning(publishChange: false)\n        nativeObservations.stop()\n        withObservedScene { $0.stop() }', 'requestCameraRecovery(now: ProcessInfo.processInfo.systemUptime)']
  ];
  const normalize = value => value.replace(/\s+/g, ' ').trim();
  const assertLifecycle = source => {
    for (const [signature, prefix, after] of entries) {
      const scoped = declaration(source, signature);
      const body = scoped.slice(scoped.indexOf('{') + 1, -1);
      assert.ok(normalize(body).startsWith(normalize(prefix)), `${signature}: critical retirement stays first`);
      assert.equal(body.split(hook).length, 2, `${signature}: one exact fenced synchronous hook`);
      if (signature.includes('didFailWithError')) {
        assert.ok(normalize(body).endsWith(normalize(`publish()\n${hook}\n${after}`)),
          'Failure publishes retired authority before optional diagnostics and bounded recovery');
      } else {
        assert.ok(normalize(body).startsWith(normalize(`${prefix}\n${hook}\n${after}`)),
          `${signature}: diagnostic hook cannot delay critical retirement or follow pause`);
      }
    }
  };
  assertLifecycle(model);
  for (const [signature, , after] of entries) {
    const original = declaration(model, signature);
    const mutations = [
      original.replace(hook, '').replace('{', `{\n${hook}`),
      original.replace(hook, '').replace(after, `${after}\n${hook}`),
      original.replace('meshCandidateDiagnostics.stop()', 'Task { meshCandidateDiagnostics.stop() }'),
      original.replace('nativeObservations.stop()', 'Task { nativeObservations.stop() }'),
      original.replace('withObservedScene { $0.stop() }', '')
    ];
    for (const changed of mutations) {
      assert.notEqual(changed, original);
      assert.throws(() => assertLifecycle(model.replace(original, changed)), { name: 'AssertionError' });
    }
  }
});

test('room-scan entry contract rejects microphone promotion, missing denial return and routes before the gate', () => {
  const gate = 'guard CommandAuthority.permits(.changeGoal, from: origin) else';
  const route = 'if routeVoiceRoomScan(text) { return }';
  const mutations = [
    model.replace('fromVoice ? .unverifiedMicrophone : .trustedInterface', 'fromVoice ? .trustedInterface : .trustedInterface'),
    model.replace(gate, 'guard true else'),
    model.replace('receiveUnverifiedConversation(text, origin: origin)\n            return', 'receiveUnverifiedConversation(text, origin: origin)'),
    model.replace(route, '').replace(gate, `${route}\n        ${gate}`),
    model.replace(route, `${route}\n        ${route}`)
  ];
  for (const mutated of mutations) {
    assert.notEqual(mutated, model);
    assert.throws(() => assertTrustedScanEntry(mutated));
  }
});
