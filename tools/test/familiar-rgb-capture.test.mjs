// Source contracts and an optional executable extraction of the production capture
// gates. This does not execute ARKit/Vision or establish native identity accuracy.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const model = read('ios/BlindAssist/NavigationModel.swift');
const controller = read('ios/BlindAssist/FamiliarFaceExperiment.swift');
const view = read('ios/BlindAssist/FamiliarPeopleView.swift');
function declaration(source, signature) {
  const start = source.indexOf(signature);
  assert.ok(start >= 0, signature);
  const brace = source.indexOf('{', start);
  let depth = 0;
  for (let i = brace; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  assert.fail(`Unclosed declaration: ${signature}`);
}
const capture = declaration(model, 'func captureFamiliarFace(');
const current = declaration(model, 'private func familiarContextIsCurrent(');

test('familiar RGB capture is independent of floor depth and map calibration but bound to frame session and optical pose', () => {
  for (const code of [capture, current]) {
    assert.doesNotMatch(code, /lastObservation|awaitingPlace|perceptionGeneration|sceneDepth|hazard == \.observing/);
    for (const guard of ['assistantSession.shouldRunCamera', 'cameraAwareness', '!simulation', '!places.scanning',
      '!detection.hazard.isUrgent', 'attention.stationary', '.portrait', 'case .normal = frame.camera.trackingState',
      'FamiliarFacePolicy.fresh(capturedAt: lastFrameWallTime', 'transform.columns.2.y', 'RequestedVisualCapturePose.poseStable']) {
      assert.ok(code.includes(guard), guard);
    }
  }
  assert.match(capture, /capturedAt: frame.timestamp, generation: passiveObservationGeneration/);
  assert.match(capture, /sessionGeneration: assistantSession.generation/);
  assert.match(current, /passiveObservationGeneration == capture.generation, assistantSession.generation == capture.sessionGeneration/);
  assert.match(current, /snapshotSpeechFresh\(capturedAt: capture.capturedAt, now: now, frameAt: frame.timestamp\)/);
  assert.match(current, /fresh\(capturedAt: capture.capturedAt, now: now, frameAt: frame.timestamp\)/);
});

test('face notices remain tentative exact-capture checked and enrollment still requires AR world tracking', () => {
  const arrival = declaration(model, 'familiarPeople.onArrivalHint =');
  assert.match(arrival, /!self.detection.hazard.isUrgent, self.familiarCaptureIsCurrent\(hint.capture\)/);
  assert.match(arrival, /I might see/);
  assert.match(arrival, /verifiedFamiliarCapture: true/);
  assert.ok(arrival.indexOf('familiarCaptureIsCurrent') < arrival.indexOf('verifiedFamiliarCapture: true'));
  assert.match(controller, /Snapshot: might be .*Could be wrong. Ask them to speak./);
  assert.match(controller, /candidateForAttempt\(/);
  assert.match(view, /import ARKit/);
  assert.match(declaration(view, 'private func startCameraForEnrollment('), /guard ARWorldTrackingConfiguration.isSupported, !model.textOnly/);
  assert.doesNotMatch(view, /!model.supported|guard model.supported/);
  assert.doesNotMatch(controller, /calibrated monitoring|Calibrate monitoring and try again/);
  assert.match(declaration(controller, 'func revalidate('), /model.detection.hazard.isUrgent/);
});

test('extracted production familiar capture gates execute RGB lifecycle freshness and full optical rejection', {
  skip: !process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC to run the bounded extracted-source gate harness.',
}, () => {
  const methods = [capture, declaration(model, 'func familiarCaptureIsCurrent('),
    declaration(model, 'func familiarSnapshotContextIsCurrent('), current]
    .join('\n').replaceAll('ProcessInfo.processInfo.systemUptime', 'TestClock.now');
  const swift = `import Foundation
${declaration(read('BlindCore/Sources/BlindCore/Geometry.swift'), 'public struct Point3:')}
${read('BlindCore/Sources/BlindCore/FamiliarFacePolicy.swift')}
${read('BlindCore/Sources/BlindCore/RequestedVisualCapturePose.swift')}
${read('BlindCore/Sources/BlindCore/AssistantSession.swift')}
typealias CVPixelBuffer = Int
${declaration(controller, 'struct FamiliarCapture')}
enum TestClock { static var now = 100.0 }
enum Orientation { case portrait, landscape }
class UIScene {}
final class UIWindowScene: UIScene { var interfaceOrientation = Orientation.portrait }
final class UIApplication {
    static let shared = UIApplication()
    var connectedScenes: [UIScene] = [UIWindowScene()]
}
enum Tracking { case normal, limited, notAvailable }
struct Transform {
    var columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) =
        (.init(1,0,0,0), .init(0,1,0,0), .init(0,0,1,0), .init(0,0,0,1))
}
struct Camera { var trackingState = Tracking.normal; var transform = Transform() }
struct ARFrame { var camera = Camera(); var timestamp = 100.0; let capturedImage = 7 }
final class Session { var currentFrame: ARFrame? = ARFrame() }
struct Places { var scanning = false }
struct Attention { var stationary = true }
enum Hazard {
    case observing, uncertain, needsCalibration, obstacle
    var isUrgent: Bool { self == .obstacle }
}
struct Detection { var hazard = Hazard.uncertain }
final class NavigationModel {
    var assistantSession = AssistantSession()
    var cameraAwareness = true
    var running = true
    var simulation = false
    var places = Places()
    var attention = Attention()
    var detection = Detection()
    let session = Session()
    var lastFrameWallTime = 100.0
    var passiveObservationGeneration = UUID()
    // Deliberately no depth, floor, map, awaitingPlace or lastObservation fixture.
    ${methods}
}
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    precondition(condition(), name); checks += 1
}
func ready() -> NavigationModel {
    TestClock.now = 100
    UIApplication.shared.connectedScenes = [UIWindowScene()]
    let model = NavigationModel(); model.assistantSession.start(); return model
}
var m = ready()
let original = m.captureFamiliarFace()!
check(original.image == 7 && original.capturedAt == 100, "Exact RGB buffer and timestamp captured without depth")
check(m.familiarCaptureIsCurrent(original), "Missing depth does not suppress valid nonspatial name evidence")
m.detection.hazard = .needsCalibration
check(m.captureFamiliarFace() != nil && m.familiarCaptureIsCurrent(original), "Missing floor calibration does not suppress face comparison")
m.detection.hazard = .obstacle
check(m.captureFamiliarFace() == nil && !m.familiarCaptureIsCurrent(original), "Urgent hazard rejects capture and result")
m = ready(); m.cameraAwareness = false
check(m.captureFamiliarFace() == nil, "Explicit camera off")
m = ready(); m.running = false
check(m.captureFamiliarFace() == nil, "Stopped camera")
m = ready(); m.simulation = true
check(m.captureFamiliarFace() == nil, "Simulation cannot name")
m = ready(); m.places.scanning = true
check(m.captureFamiliarFace() == nil, "RoomPlan camera ownership")
m = ready(); m.attention.stationary = false
check(m.captureFamiliarFace() == nil, "Stationary requirement retained")
m = ready(); (UIApplication.shared.connectedScenes[0] as! UIWindowScene).interfaceOrientation = .landscape
check(m.captureFamiliarFace() == nil, "Portrait requirement retained")
m = ready(); m.session.currentFrame = nil
check(m.captureFamiliarFace() == nil, "No frame")
m = ready(); m.session.currentFrame!.camera.trackingState = .limited
check(m.captureFamiliarFace() == nil, "Limited tracking")
m = ready(); m.session.currentFrame!.timestamp = 99.49
check(m.captureFamiliarFace() == nil, "Stale native frame is not fresh callback time")
m = ready(); m.lastFrameWallTime = 99.49
check(m.captureFamiliarFace() == nil, "Stale processed sensor callback")
m = ready(); m.session.currentFrame!.timestamp = 101
check(m.captureFamiliarFace() == nil, "Future native timestamp")
m = ready(); m.session.currentFrame!.timestamp = .nan
check(m.captureFamiliarFace() == nil, "Nonfinite native timestamp")
m = ready(); m.lastFrameWallTime = 99.8
check(m.captureFamiliarFace() != nil, "Newer current frame than dispatched callback remains usable")
m = ready(); m.session.currentFrame!.camera.transform.columns.2 = .init(0,0,0,0)
check(m.captureFamiliarFace() == nil, "Malformed optical axis")
m = ready(); m.session.currentFrame!.camera.transform.columns.3.x = .nan
check(m.captureFamiliarFace() == nil, "Malformed origin")
m = ready(); let rgb = m.captureFamiliarFace()!
m.passiveObservationGeneration = UUID()
check(!m.familiarCaptureIsCurrent(rgb), "Old RGB generation cannot name")
m = ready(); let beforeMute = m.captureFamiliarFace()!; m.assistantSession.mute()
check(!m.familiarCaptureIsCurrent(beforeMute), "Mute retires old session result")
check(m.captureFamiliarFace() != nil, "Microphone mute does not disable separate camera control")
m = ready(); let beforeEnd = m.captureFamiliarFace()!; m.assistantSession.end()
check(m.captureFamiliarFace() == nil && !m.familiarCaptureIsCurrent(beforeEnd), "Ended session")
m = ready(); let beforeBackground = m.captureFamiliarFace()!; m.assistantSession.enterBackground()
check(m.captureFamiliarFace() == nil && !m.familiarCaptureIsCurrent(beforeBackground), "Background camera off")
m.assistantSession.enterForeground()
check(!m.familiarCaptureIsCurrent(beforeBackground), "Foreground cannot revive old capture")
m = ready(); let beforeRouteLoss = m.captureFamiliarFace()!; m.assistantSession.losePrivateAudioRoute()
check(!m.familiarCaptureIsCurrent(beforeRouteLoss), "Private route loss retires old speech evidence")
m = ready(); let pose = m.captureFamiliarFace()!
m.session.currentFrame!.camera.transform.columns.2 = .init(0, sin(Float.pi/18), cos(Float.pi/18), 0)
check(!m.familiarCaptureIsCurrent(pose) && !m.familiarSnapshotContextIsCurrent(pose), "Pitch-only movement invalidates live and snapshot")
m.session.currentFrame!.camera.transform.columns.2 = .init(0,0,1,0)
m.session.currentFrame!.camera.transform.columns.3.x = 0.11
check(!m.familiarCaptureIsCurrent(pose), "Translation beyond ten centimeters")
m.session.currentFrame!.camera.transform.columns.3.x = 0.09
check(m.familiarCaptureIsCurrent(pose), "Small translation within existing bound")
m = ready(); let life = m.captureFamiliarFace()!
TestClock.now = 102; m.lastFrameWallTime = 102; m.session.currentFrame!.timestamp = 102
check(!m.familiarCaptureIsCurrent(life), "Live name expires after 1.5 seconds")
check(m.familiarSnapshotContextIsCurrent(life), "Explicit past-snapshot utterance may finish")
TestClock.now = 112; m.lastFrameWallTime = 112; m.session.currentFrame!.timestamp = 112
check(m.familiarSnapshotContextIsCurrent(life), "Snapshot maximum remains twelve seconds")
TestClock.now = 112.01; m.lastFrameWallTime = 112.01; m.session.currentFrame!.timestamp = 112.01
check(!m.familiarSnapshotContextIsCurrent(life), "Snapshot cannot outlive twelve seconds")
m = ready(); let futureFrame = m.captureFamiliarFace()!
m.session.currentFrame!.timestamp = 99.9
check(!m.familiarCaptureIsCurrent(futureFrame), "Replayed current frame cannot postdate capture")
m = ready(); let currentLost = m.captureFamiliarFace()!; m.session.currentFrame!.camera.trackingState = .notAvailable
check(!m.familiarCaptureIsCurrent(currentLost), "Tracking loss invalidates result")
m = ready(); let stationaryLost = m.captureFamiliarFace()!; m.attention.stationary = false
check(!m.familiarSnapshotContextIsCurrent(stationaryLost), "Movement also cancels explicit snapshot completion")
print("familiar RGB capture gates: \\(checks) checks passed")
`;
  const directory = mkdtempSync(join(tmpdir(), 'familiar-rgb-'));
  try {
    const input = join(directory, 'capture.swift'), output = join(directory, 'capture');
    writeFileSync(input, swift);
    execFileSync(process.env.BLIND_SWIFTC, ['-module-cache-path', process.env.CLANG_MODULE_CACHE_PATH || join(directory, 'module-cache'), input, '-o', output], { encoding: 'utf8', timeout: 60_000 });
    const result = execFileSync(output, [], { encoding: 'utf8', timeout: 10_000 });
    assert.match(result, /familiar RGB capture gates: 36 checks passed/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('periodic missing-monitoring notices interrupt speech without discarding consented RGB work', () => {
  const announce = declaration(model, 'private func announceDetection(');
  assert.match(announce, /value.hazard.isUrgent \? \.hazard\s*: value.hazard.requiresImmediateAttention \? \.mobility/);
  assert.match(announce, /GuidanceText.detection\(value, arabic: arabic\)/);
  assert.match(announce, /alert: value/);
  const delivery = declaration(model, '@discardableResult private func deliverCandidate(');
  assert.match(delivery, /if candidate.kind == \.hazard \{[\s\S]*familiarPeople.cancel\(announce: false\)/);
  assert.match(delivery, /else if candidate.kind != \.mobility/);
});

test('extracted monitoring dispatch preserves urgent danger and nonurgent warning priority for all states', {
  skip: !process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC to run the bounded extracted-source dispatch harness.',
}, () => {
  const swift = `import Foundation
${declaration(read('BlindCore/Sources/BlindCore/HazardDetector.swift'), 'public enum Hazard:')}
struct Detection { let hazard: Hazard; init(_ hazard: Hazard) { self.hazard = hazard } }
enum InformationCandidate { enum Kind { case hazard, mobility, answer } }
enum GuidanceText { static func detection(_ value: Detection, arabic: Bool) -> String { value.hazard.rawValue } }
final class NavigationModel {
    var arabic = false
    var dispatched: (kind: InformationCandidate.Kind, requested: Bool, replace: Bool, hazard: Hazard, text: String)?
    func dispatchText(_ text: String, kind: InformationCandidate.Kind, requested: Bool, replace: Bool, alert: Detection) -> Bool {
        dispatched = (kind, requested, replace, alert.hazard, text); return true
    }
    ${declaration(model, 'private func announceDetection(')}
    func announce(_ hazard: Hazard, requested: Bool) { announceDetection(Detection(hazard), requested: requested) }
}
var checks = 0
let model = NavigationModel()
for hazard in [Hazard.stopped, .calibrating, .needsCalibration, .observing, .uncertain, .drop, .obstacle, .overhead] {
    for requested in [false, true] {
        model.announce(hazard, requested: requested)
        let result = model.dispatched!
        let expected: InformationCandidate.Kind
        switch hazard {
        case .drop, .obstacle, .overhead: expected = .hazard
        case .uncertain, .needsCalibration: expected = .mobility
        default: expected = requested ? .answer : .mobility
        }
        precondition(result.kind == expected && result.requested == requested && result.hazard == hazard && result.text == hazard.rawValue,
            "Every dispatch retains exact notice and requested state, with danger only for actual hazards")
        precondition(result.replace == (requested && !hazard.requiresImmediateAttention), "Existing speech replacement contract")
        checks += 1
    }
}
print("monitoring dispatch: \\(checks) cases passed")
`;
  const directory = mkdtempSync(join(tmpdir(), 'monitoring-dispatch-'));
  try {
    const input = join(directory, 'dispatch.swift'), output = join(directory, 'dispatch');
    writeFileSync(input, swift);
    execFileSync(process.env.BLIND_SWIFTC, ['-module-cache-path', process.env.CLANG_MODULE_CACHE_PATH || join(directory, 'module-cache'), input, '-o', output], { encoding: 'utf8', timeout: 60_000 });
    const result = execFileSync(output, [], { encoding: 'utf8', timeout: 10_000 });
    assert.match(result, /monitoring dispatch: 16 cases passed/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
