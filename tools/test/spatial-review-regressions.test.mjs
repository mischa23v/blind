// Independent adversarial review contracts for the 2026-10-23 spatial checkpoint.
// These execute against the Swift SOURCE. They do not execute UIKit/ARKit,
// simulate recognition accuracy, or prove that native persistence/speech works.
// Keep the scenarios below in the supervised/native acceptance matrix too.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');
const section = (source, start, end) => {
  const first = source.indexOf(start);
  const last = source.indexOf(end, first + start.length);
  assert.ok(first >= 0 && last > first, `Expected source section ${start} → ${end}`);
  return source.slice(first, last);
};
const before = (source, first, second) => {
  const a = source.indexOf(first), b = source.indexOf(second);
  assert.ok(a >= 0 && b > a, `Expected ${first} before ${second}`);
};

function declaration(source, signature) {
 const start=source.indexOf(signature); assert.ok(start>=0,signature);
 const open=source.indexOf('{',start); let depth=0;
 for(let i=open;i<source.length;i++) {
  if(source[i]==='{') depth++;
  if(source[i]==='}' && --depth===0) return source.slice(start,i+1);
 }
 assert.fail(`Unclosed declaration: ${signature}`);
}

test('room A to B during debounce cannot attach the previous room to a new capture (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const capture = section(source, 'private func updatePassiveObjectMemory', 'private func importFurnitureHistory');
  // Compute a measured-map room from this capture, not the half-second UI cache.
  assert.match(capture, /indoor\.situation\(camera: observation\.camera, forward: observation\.forward/);
  assert.doesNotMatch(capture, /let establishedRoom = alignedRoomID/);
  assert.match(capture, /let roomID = !nonspatialOnly && establishedRoom == companion\.currentRoom \? establishedRoom : nil/);
  before(capture, 'let roomID =', 'Task.detached');
  before(capture, 'let roomName =', 'Task.detached');
  assert.match(capture, /roomID == recognizedPlace\.map/);
  assert.doesNotMatch(capture, /\?\? recognizedPlace\?\.name/);
});

test('yesterday generic cup cannot outrank today explicitly saved cup or user report (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const find = declaration(source, 'private func findWithSensors(');
  const checkPrecedence = body => {
    assert.match(body, /let explicitEvidenceAt = max\(fact\?\.at \?\? \.distantPast, companionWorkingState\.currentContextItem\(name, in: items\)\?\.savedAt \?\? \.distantPast\)/);
    // Strict comparison also keeps equally dated, stronger scoped evidence first.
    assert.match(body, /recall\.sightings\.contains\(where: \{ \$0\.observedAt > explicitEvidenceAt \}\)/);
    before(body, 'let explicitEvidenceAt =', 'ObservedObjectMemory.answer(');
    before(body, '$0.observedAt > explicitEvidenceAt', 'ObservedObjectMemory.answer(');
    assert.match(body, /if let item = companionWorkingState\.currentContextItem\(name, in: items\), fact\.map\(\{ item\.savedAt > \$0\.at \}\) \?\? true/);
    assert.doesNotMatch(body, /items\.find\(name\)/, 'Global label matching cannot select another scope.');
  };
  checkPrecedence(find);
  for (const [from, to] of [
    ['companionWorkingState.currentContextItem(name, in: items)', 'items.find(name)'],
    ['$0.observedAt > explicitEvidenceAt', '$0.observedAt >= explicitEvidenceAt'],
    ['item.savedAt > $0.at', 'item.savedAt >= $0.at'],
  ]) {
    assert.ok(find.includes(from));
    assert.throws(() => checkPrecedence(find.replaceAll(from, to)), { name: 'AssertionError' }, from);
  }
});

test('scoped deletion cutoffs reload from private storage after restart (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const init = section(source, 'override init()', 'var supported: Bool');
  assert.match(init, /places\.memory\?\.value\(namespace: "observed-objects", id: "deletion-cutoffs"\)/);
  assert.match(init, /JSONDecoder\(\)\.decode\(ObservationDeletionCutoffs\.self, from: data\)/);
  assert.match(init, /observationDeletionCutoffs = saved/);
  const fields = section(source, 'private struct ObservationDeletionCutoffs', 'private var observedObjects');
  assert.match(fields, /var all: Date/);
  assert.match(fields, /var rooms: \[String: Date\]/);
  assert.match(fields, /var categories: \[String: Date\]/);
  // Item names and their deletion times must not leak into normally backed-up preferences.
  assert.doesNotMatch(source, /UserDefaults[^\n]*(?:object-history|deletion-cutoffs)/);
});

test('reopening an old map after scoped deletion checks room and normalized category cutoffs before import (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const imported = section(source, 'private func importFurnitureHistory', 'private func persistObservedObjects');
  assert.match(imported, /frame\.capturedAt > observationDeletionCutoffs\.all/);
  assert.match(imported, /let roomID = "place:" \+ place\.id\.uuidString/);
  assert.match(imported, /item\.observedAt > \(observationDeletionCutoffs\.rooms\[roomID\] \?\? \.distantPast\)/);
  assert.match(imported, /item\.observedAt > \(observationDeletionCutoffs\.categories\[ItemMemory\.key\(for: item\.category\)\] \?\? \.distantPast\)/);
  before(imported, 'observationDeletionCutoffs.rooms[roomID]', 'observedObjects.observe(');
  before(imported, 'observationDeletionCutoffs.categories[', 'observedObjects.observe(');
  // New scans remain admissible; suppression is dated, not a permanent category blacklist.
  assert.doesNotMatch(imported, /guard\s+observationDeletionCutoffs\.(?:rooms|categories)\[[^\]]+\]\s*==\s*nil/);
});

test('scoped deletion commits durable suppression before replacing history and exposes write failures (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const remove = section(source, 'private func removeObservedHistory', 'var savedItems');
  assert.match(remove, /cutoffs\.categories\[ItemMemory\.key\(for: category\)\] = Date\(\)/);
  assert.match(remove, /cutoffs\.rooms\[room\] = Date\(\)/);
  assert.match(remove, /try memory\.saveValue\(namespace: "observed-objects", id: "deletion-cutoffs", payload: JSONEncoder\(\)\.encode\(cutoffs\)\)/);
  before(remove, 'id: "deletion-cutoffs"', 'id: "all"');
  before(remove, 'id: "all"', 'observedObjects = updated');
  assert.doesNotMatch(remove, /try\?/);
});

test('full clear commits suppression before removal and cancels already captured callbacks (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const clear = section(source, 'func clearObservedObjects()', 'private func removeObservedHistory');
  assert.match(clear, /cutoffs\.all = Date\(\)/);
  before(clear, 'invalidatePerceptionWork()', 'id: "deletion-cutoffs"');
  before(clear, 'id: "deletion-cutoffs"', 'memory.deleteValue(');
  before(clear, 'memory.deleteValue(', 'observedObjects.clear()');
  const capture = section(source, 'private func updatePassiveObjectMemory', 'private func importFurnitureHistory');
  assert.ok((capture.match(/self\.passiveObservationGeneration == generation/g) ?? []).length >= 2,
    'Both asynchronous completion stages must reject the deleted capture generation');
});

test('RGB-only history survives depth and tracking failure without acquiring spatial authority (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const frames = section(source, 'func session(_ session: ARSession, didUpdate frame:', '#if BLIND_FAMILIAR_PEOPLE\n    @discardableResult');
  const missingDepth = section(frames, 'guard let observation = DepthSampler.observation(from: frame) else {', 'if !observation.trackingNormal');
  assert.match(missingDepth, /invalidatePerceptionWork\(preserveRGBHistoryWork: true\)/);
  assert.match(missingDepth, /updateNonspatialObjectMemory\(frame: frame\)/);
  const rgb = section(source, 'private func updateNonspatialObjectMemory', 'private func updatePassiveObjectMemory');
  assert.match(rgb, /Observation\(timestamp: frame\.timestamp/);
  assert.match(rgb, /samples: \[\], trackingNormal: normal/);
  assert.match(rgb, /updateBackgroundPerception\(frame: frame, observation: pose, nonspatialOnly: true\)/);
  const localizing = section(frames, 'if let place = awaitingPlace', 'if let place = recognizedPlace');
  assert.match(localizing, /updateNonspatialObjectMemory\(frame: frame\)/);
  assert.match(frames, /updateBackgroundPerception\(frame: frame, observation: observation, nonspatialOnly: !observation.trackingNormal\)/);
  const capture = section(source, 'private func updatePassiveObjectMemory', 'private func importFurnitureHistory');
  assert.match(capture, /let frameID: String\? = nonspatialOnly \? nil :/);
  assert.match(capture, /let captureSituation = !nonspatialOnly && indoor\.isAligned \?/);
  assert.match(capture, /let roomID = !nonspatialOnly &&/);
  assert.ok((capture.match(/position: nonspatialOnly \? nil : DepthSampler\.worldPoint/g) ?? []).length === 2,
    'Neither detector nor appearance candidates may attach depth in RGB-only mode');
  assert.match(capture, /if !nonspatialOnly \{ self\.offerObservedGoalMatch/);
  assert.match(source, /now >= observation\.timestamp && now - observation\.timestamp <= 0\.5/);
  assert.match(capture, /completed >= observation\.timestamp, completed - observation\.timestamp <= 3/);
  assert.match(capture, /capturedDate = Date\(\)\.addingTimeInterval\(observation\.timestamp - ProcessInfo\.processInfo\.systemUptime\)/);
});

test('tracking recovery cannot resurrect pre-failure spatial work or permanently block RGB collection (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const capture = section(source, 'private func updatePassiveObjectMemory', 'private func importFurnitureHistory');
  assert.match(capture, /generation = passiveObservationGeneration, spatialGeneration = perceptionGeneration/);
  assert.equal((capture.match(/self\.passiveObservationGeneration == generation/g) ?? []).length, 2);
  assert.equal((capture.match(/nonspatialOnly \|\| self\.perceptionGeneration == spatialGeneration/g) ?? []).length, 2);
  assert.match(capture, /self\.backgroundPerception\.accepts\(resourceLease/);
  assert.match(capture, /self\.expireBackgroundPerception\(now:/);
  assert.match(capture, /if self\.backgroundPerception\.finish\(resourceLease/);
  assert.match(capture, /self\.observationFrameID == sessionFrameID/);
});

test('privacy and session resets cancel RGB work while depth-only failure keeps its bounded token (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const invalidate = section(source, 'private func invalidatePerceptionWork(', 'private func invalidateRecognizedRoom');
  assert.match(invalidate, /preserveRGBHistoryWork: Bool = false/);
  assert.match(invalidate, /perceptionGeneration = UUID\(\)/);
  assert.match(invalidate, /if !preserveRGBHistoryWork \{ backgroundPerception.invalidate\(\); passiveObservationGeneration = UUID\(\) \}/);
  assert.match(invalidate, /observedObjects\.invalidateGeometry\(\)/);
  const stop = section(source, 'private func stopCameraMonitoring()', 'private func startWatchdog()');
  const launch = section(source, 'private func launch(', 'func stop()');
  assert.match(stop, /invalidatePerceptionWork\(\)/);
  assert.match(launch, /invalidatePerceptionWork\(\)/);
  // Preservation is limited to per-frame depth/tracking loss and a newly lost
  // monitoring state with an independently verified fresh RGB capture.
  assert.equal((source.match(/invalidatePerceptionWork\(preserveRGBHistoryWork: true\)/g) ?? []).length, 3);
});

test('item and room forget paths invalidate captured work and perform scoped history deletion (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const item = section(source, 'func forgetItem(', 'var savedRooms');
  const room = section(source, 'func forgetRoom(_ id:', 'var learnedHints');
  before(item, 'invalidatePerceptionWork()', 'try removeObservedHistory(category: item.name)');
  before(room, 'invalidatePerceptionWork()', 'try removeObservedHistory(room: id)');
  assert.match(item, /catch[\s\S]*return false/);
  assert.match(room, /catch[\s\S]*return/);
});

test('cancelled route cannot repeat its retired physical distance while alignment survives (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const navigator = await read('ios/BlindAssist/IndoorNavigator.swift');
  const cancel = section(navigator, 'func cancelRoute()', 'func invalidatePosition()');
  assert.match(cancel, /route = \[\]; waypointIndex = 0; suggestedDestination = nil/);
  assert.match(cancel, /message = text\("No active route\."/);
  assert.doesNotMatch(cancel, /(?:anchorWorld|anchorMap|worldForward|mapForward|alignedLevel)\s*=/);
  const beacon = section(source, 'func indoorBeacon(', 'func routeSaudiBanknoteCommand(');
  assert.match(beacon, /if connectedJourneyOwnsNavigation \{ connectedJourneyBeacon\(automatic: automatic\); return \}/);
  assert.doesNotMatch(section(source, 'func indoorBeacon(', '/// No mode selection:'), /indoor\.next\(|spatialRouteOutput\.deliver/);
  assert.ok(source.includes('if !returning, fixedBodyMount, connectedJourneyOwnsNavigation, journeys.withConnectedJourney({ $0.goal?.status == .active }), detection.hazard == .observing,'));
  const ownership = section(source, 'private enum IndoorGuidanceOwner', 'func indoorBeacon(');
  assert.match(ownership, /if indoorGuidanceOwner == \.connectedJourney \{ return true \}/);
  assert.match(ownership, /indoorGuidanceOwner == \.legacyPreview && indoor\.journeyPreviewIsCurrent/);
  assert.match(ownership, /No obstruction was recorded/);
  assert.equal((ownership.match(/guard indoorPreviewControlsAvailable else/g) ?? []).length, 2);
  const ui = await read('ios/BlindAssist/DashboardView.swift');
  assert.doesNotMatch(ui, /model\.indoor\.(?:blockNextLeg|confirmArrival)\(/);
  assert.match(ui, /model\.reportIndoorWayBlocked\(\) \}\.disabled\(!model\.indoorPreviewControlsAvailable\)/);
  assert.match(ui, /model\.confirmIndoorPreviewArrival\(\) \}\.disabled\(!model\.indoorPreviewControlsAvailable\)/);
  const connected = section(source, 'private func connectedJourneyBeacon(', 'func stopReturn()');
  assert.match(connected, /try \$0\.next\(now: now\)/);
  assert.match(connected, /held\.route\.directionalCue\(\)/);
  assert.match(connected, /spatialRouteOutput\.deliver\(ticket: ticket, goalRevision: revision/);
  const runtime = await read('ios/BlindAssist/ConnectedJourneyRuntime.swift');
  assert.match(runtime, /guard canOutput, let coordinator/);
  assert.match(runtime, /!loading && !externalMapPending && !mapValidationBlocked && mapWorkID == nil && durable && !storageError && !commandBlocked/);
});

test('new world-map recovery rejects queued frames captured before its own beginning (source)', async () => {
  const source = await read('BlindCore/Sources/BlindCore/SavedWorldFrame.swift');
  const observe = section(source, 'public mutating func observe(', 'public func current(');
  assert.match(observe, /frameTime >= startedAt/);
  before(observe, 'frameTime >= startedAt', 'switch tracking');
  assert.match(observe, /now - frameTime <= Self\.maximumFrameAge else \{ reset\(\); return nil \}/);
  assert.match(observe, /self\.sessionID == sessionID/);
});

test('recorded-spot empirical receipt is debug-only and never enables object handling (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const receipt = section(source, 'private func recordedSpotReceipt(', 'private struct ObservationDeletionCutoffs');
  assert.match(receipt, /#if DEBUG[\s\S]*BLIND_RECORDED_SPOT_TEST_RECEIPT[\s\S]*#else\s+return nil\s+#endif/);
  assert.match(receipt, /value\.schema == 1, value\.frameID == frameID, value\.reviewedByAdult/);
  assert.match(receipt, /value\.expiresAt > Date\(\)/);
  assert.match(receipt, /value\.expiresAt\.timeIntervalSinceNow <= 86_400/);
  assert.match(receipt, /!value\.pointIDs\.isEmpty, value\.pointIDs\.count <= 256/);
  assert.match(source, /private static let objectInteractionGuidanceValidated = false/);
});

test('recorded-spot promotion binds exact re-read scan frame point ID and position, not a category label (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const imported = section(source, 'private func importFurnitureHistory', 'private func recordedSpotRecallContext');
  before(imported, 'places.measuredFurnitureHistory(for: place)', 'applyRecordedPointValidation(');
  assert.match(imported, /receipt\?\.pointIDs\.contains\(item\.id\) == true/);
  assert.match(imported, /applyRecordedPointValidation\(frameID: frame\.frameID,\s*sourceObservationID: item\.id, position: item\.position/);
  assert.match(imported, /source: \.roomPlanScan, sourceObservationID: item\.id/);
  assert.match(imported, /associationValidated: false, recordedSpotValidated: eligible/);
  const core = await read('BlindCore/Sources/BlindCore/ObservedObjectMemory.swift');
  const promote = section(core, 'public mutating func applyRecordedPointValidation', 'public mutating func revalidateRecordedFrame');
  for (const required of ['.source == .roomPlanScan', '.frameID == frameID',
    '.sourceObservationID == sourceObservationID', '.position == position']) assert.ok(promote.includes(required), required);
  assert.match(promote, /\.isActive = false/);
  assert.match(promote, /\.geometryValid = false/);
});

test('historical-spot renderer rechecks the receipt and never substitutes present object location (source)', async () => {
  const source = await read('BlindCore/Sources/BlindCore/ObservedObjectMemory.swift');
  const render = section(source, 'public static func recordedSpotAnswer', 'private static func nameMatches');
  assert.match(render, /recall\.sightings\.count == 1/);
  assert.match(render, /recordedOrientation\(for: item, context: recall\.context, now: now\)/);
  assert.match(render, /Earlier recorded spot/);
  assert.match(render, /does not confirm the object is there now or that the route is clear/);
  const orientation = section(source, 'private static func recordedOrientation', 'private static func contextValid');
  assert.match(orientation, /context\.allowedRecordedPointIDs\.contains\(pointID\)/);
  assert.match(orientation, /context\.frameID == frameID/);
  assert.match(orientation, /contextValid\(context, at: now\), scopeAgrees\(item, context\)/);
  assert.match(orientation, /relation\.distance > 1/);
  assert.match(orientation, /context\.headingUncertaintyDegrees\.isFinite/);
});

test('receipt is bound to the current local device and app build rather than only iPhone family (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const receipt = section(source, 'private func recordedSpotReceipt(', 'private struct ObservationDeletionCutoffs');
  assert.match(receipt, /value\.deviceVendorID == UIDevice\.current\.identifierForVendor\?\.uuidString/);
  assert.match(receipt, /value\.appBuild == Bundle\.main\.object\(forInfoDictionaryKey: "CFBundleVersion"\) as\? String/);
  assert.doesNotMatch(receipt, /identifierForVendor[^\n]*\?\?/);
  const generator = await read('tools/generate-xcode-project.mjs');
  assert.match(generator, /const configurationConditions = conditions \+ \(name === 'Debug' \? ' DEBUG' : ''\)/);
});

test('spoken recorded direction is cancelled if target, heading freshness or rendered relation changes (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const frames = section(source, 'func session(_ session: ARSession, didUpdate frame:', '#if BLIND_FAMILIAR_PEOPLE\n    @discardableResult');
  before(frames, 'bodyHeadingEstimator.observe(', 'if let speech = recordedSpotSpeech');
  const speech = section(frames, 'if let speech = recordedSpotSpeech', 'updateReturn(observation)');
  assert.match(speech, /recordedSpotRecallContext\(\), context\.frameID == speech\.frameID/);
  assert.match(speech, /observedObjects\.recall\(category: speech\.target, at: Date\(\), context: context\)/);
  assert.match(speech, /recall\.recordedSpotOrientation\?\.sightingID == speech\.sightingID/);
  assert.match(speech, /recordedSpotAnswer\(for: recall, now: Date\(\), arabic: arabic\) == speech\.orientation/);
  assert.match(speech, /if !sameSpokenRelation \{ feedback\.stopRequestedSpeech\(speech\.id\)/);
  assert.doesNotMatch(speech, /SceneDelivery\.allowed/);
});

test('recorded pose age uses sensor capture time rather than delayed main-queue receipt (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const context = section(source, 'private func recordedSpotRecallContext()', 'private func persistObservedObjects');
  assert.match(context, /now >= observation\.timestamp, now - observation\.timestamp <= 0\.5/);
  assert.match(context, /capturedAt: Date\(\)\.addingTimeInterval\(observation\.timestamp - now\)/);
  assert.doesNotMatch(context, /lastFrameWallTime/);
});

test('delayed world-map callbacks cannot extend a captured frame lease (source)', async () => {
  const source = await read('BlindCore/Sources/BlindCore/SavedWorldFrame.swift');
  const observe = section(source, 'public mutating func observe(', 'public func current(');
  assert.match(observe, /lastValidatedAt = frameTime/);
  assert.doesNotMatch(observe, /lastValidatedAt = now/);
  const fixtures = await read('BlindCore/Tests/BlindCoreTests/SavedWorldFrameTests.swift');
  assert.match(fixtures, /func testDelayedDeliveryDoesNotExtendCaptureTimeLease\(\)/);
  assert.match(fixtures, /frameTime: 10, now: 10\.49/);
  assert.match(fixtures, /XCTAssertNil\(recovery\.current\(sessionID: session, now: 10\.98\)\)/);
});

test('positional bearing interval uses tangent uncertainty and guards both sector boundaries (source)', async () => {
  const source = await read('BlindCore/Sources/BlindCore/ObservedObjectMemory.swift');
  const orientation = section(source, 'private static func recordedOrientation', 'private static func contextValid');
  assert.match(orientation, /combinedPositionError = uncertainty \+ context\.uncertaintyMetres/);
  assert.match(orientation, /relation\.distance > combinedPositionError/);
  assert.match(orientation, /let positionalAngle = asin\(combinedPositionError \/ relation\.distance\)/);
  assert.match(orientation, /relation\.angleDegrees - angularError/);
  assert.match(orientation, /relation\.angleDegrees \+ angularError/);
  // Numerical counterexample from the independent review. The old atan shortcut
  // understated the disk's bearing envelope and incorrectly admitted 'ahead'.
  const nominalDegrees = 19.6, distance = 1.1, error = 0.2;
  assert.ok(nominalDegrees + Math.atan2(error, distance) * 180 / Math.PI < 30);
  assert.ok(nominalDegrees + Math.asin(error / distance) * 180 / Math.PI > 30);
});


test('connected issuer is retired by mount or frame ownership loss before frame throttling (source)', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const mount = section(source, '@Published var fixedBodyMount', '@Published private(set) var serviceStatus');
  before(mount, 'journeys.breakTracking()', 'cancelDescription()');
  const frames = section(source, 'func session(_ session: ARSession, didUpdate frame:', '#if BLIND_FAMILIAR_PEOPLE\n    @discardableResult');
  const assertRawRetirement = candidate => {
    const opening = candidate.indexOf('{');
    const throttle = candidate.indexOf('guard running');
    assert.ok(opening >= 0 && throttle > opening);
    const prefix = candidate.slice(opening + 1, throttle).replace(/\/\/[^\n]*/g, '').trim();
    const registrationHook = `if places.scanning, let scanSession = UUID(uuidString: observationFrameID) {
            places.observeRegistrationFrame(frame, sessionID: scanSession, now: ProcessInfo.processInfo.systemUptime)
        }`;
    assert.ok(prefix.endsWith(registrationHook), 'Bounded registration capture is synchronous after all loss retirements and before scan throttle');
    const retirementPrefix = prefix.slice(0, -registrationHook.length).trim();
    assert.match(retirementPrefix, /^if case \.normal = frame\.camera\.trackingState \{\} else \{ invalidateNativeLocalization\(\.trackingUnavailable\) \}\s*if case \.normal = frame\.camera\.trackingState \{\} else \{\s*journeys\.breakTracking\(\)\s*nativeObservations\.trackingLost\(\)\s*clearBoardingReading\(\)\s*if readingTool != nil \{ stopReadingTool\(announce: false\) \}\s*\}$/,
      'All exact ownership retirements are synchronous and before throttle; normal frames do not retire them');
    before(candidate, 'journeys.breakTracking()', 'frame.timestamp - lastProcessed');
    before(candidate, 'nativeObservations.trackingLost()', 'frame.timestamp - lastProcessed');
    before(candidate, 'stopReadingTool(announce: false)', 'frame.timestamp - lastProcessed');
    before(candidate, 'clearBoardingReading()', 'frame.timestamp - lastProcessed');
    assert.match(candidate, /phoneDetection = detector\.process\(observation\)/);
    before(candidate, 'phoneDetection = detector.process(observation)', 'updateReadingTool(frame: frame)');
    const missingDepth = section(candidate, 'guard let observation = DepthSampler.observation(from: frame)', 'if !observation.trackingNormal');
    before(missingDepth, 'detector.invalidateRecentEvidence()', 'updateNonspatialObjectMemory(frame: frame)');
    before(missingDepth, 'publish()', 'updateNonspatialObjectMemory(frame: frame)');
  };
  assertRawRetirement(frames);
  const mutations = [
    frames.replace('places.observeRegistrationFrame(frame, sessionID: scanSession, now: ProcessInfo.processInfo.systemUptime)', '/* missing registration capture */'),
    frames.replace('places.observeRegistrationFrame(frame, sessionID: scanSession, now: ProcessInfo.processInfo.systemUptime)', 'Task { places.observeRegistrationFrame(frame, sessionID: scanSession, now: ProcessInfo.processInfo.systemUptime) }'),
    frames.replace('clearBoardingReading()', '/* missing boarding retirement */'),
    frames.replace('clearBoardingReading()', 'Task { clearBoardingReading() }'),
    frames.replace('journeys.breakTracking()', '/* missing journey retirement */'),
    frames.replace('nativeObservations.trackingLost()', '/* missing route-history retirement */'),
    frames.replace('nativeObservations.trackingLost()', 'Task { nativeObservations.trackingLost() }'),
    frames.replace('nativeObservations.trackingLost()', '').replace('let receivedAt =', 'nativeObservations.trackingLost(); let receivedAt ='),
    frames.replace('if readingTool != nil { stopReadingTool(announce: false) }', '/* missing reader retirement */'),
    frames.replace('if readingTool != nil { stopReadingTool(announce: false) }', 'return'),
    frames.replace('invalidateNativeLocalization(.trackingUnavailable)', '/* missing selected-owner retirement */'),
    frames.replace('phoneDetection = detector.process(observation)', 'phoneDetection = Detection(.observing)'),
    frames.replace('detector.invalidateRecentEvidence()', '/* missing depth-loss hazard retirement */')
  ];
  for (const mutant of mutations) assert.throws(() => assertRawRetirement(mutant));
  assert.match(frames, /if place\.worldFrame != nil, verifiedFrame == nil \{\s*journeys\.breakTracking\(\)/);
  assert.match(frames, /if !observation\.trackingNormal \{\s*journeys\.breakTracking\(\)/);
  const store = await read('ios/BlindAssist/JourneyStore.swift');
  assert.match(store, /func breakTracking\(\) \{ withConnectedJourney \{ \$0\.cameraRestarted\(\) \}/);
  const runtime = await read('ios/BlindAssist/ConnectedJourneyRuntime.swift');
  assert.match(runtime, /func cameraRestarted\(\) \{ retire\(\); lastEndpoint = nil; coordinator\?\.loseTracking\(\)/);
});
