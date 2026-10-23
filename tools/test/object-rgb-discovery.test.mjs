// Executes extracted production RGB admission and native-callback ownership with
// deterministic camera/inference fixtures. Not an ARKit build or detection benchmark.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const model = read('ios/BlindAssist/NavigationModel.swift');
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
const capture = declaration(model, 'private func captureObjectView(');
const current = declaration(model, 'private func objectViewIsCurrent(');

test('requested object candidates have RGB capture authority while physical branches retain separate spatial gates', () => {
  assert.match(capture, /generation: passiveObservationGeneration/);
  assert.match(capture, /sessionGeneration: assistantSession.generation, capturedAt: frame.timestamp/);
  for (const required of ['assistantSession.shouldRunCamera', '!detection.hazard.isUrgent', '!assistantSession.privateAudioHeld',
    'requestID == capture.request', 'passiveObservationGeneration == capture.generation',
    'assistantSession.generation == capture.sessionGeneration', 'snapshotPlayback',
    'case .normal = frame.camera.trackingState', 'transform.columns.2.y', 'RequestedVisualCapturePose.poseStable']) {
    assert.ok(current.includes(required), required);
  }
  assert.doesNotMatch(capture + current, /lastObservation|awaitingPlace|hazard == \.observing|sceneDepth/);
  assert.match(current, /snapshotPlayback: Bool = false/);
  assert.match(current, /snapshotPlayback \? 12 : 0\.5/);
  for (const signature of ['private func continueSearch(', 'private func findItemByLook(', 'private func verifyHeldItem(']) {
    const code = declaration(model, signature);
    assert.match(code, /captureObjectView\(frame\)/);
    assert.match(code, /objectViewIsCurrent\(capture\)/);
    assert.match(code, /objectInteractionGuidanceValidated/);
    assert.match(code, /perceptionResultAllowed\(/);
    assert.ok(code.indexOf('objectInteractionGuidanceValidated') < code.indexOf('perceptionResultAllowed('));
  }
  assert.match(model, /private static let objectInteractionGuidanceValidated = false/);
  const verify = declaration(model, 'private func verifyHeldItem(');
  assert.match(verify, /guard itemAppearance.viewCount\(item.key\) > 0 else/);
  assert.match(verify, /A fresh camera view isn't available to compare/);
  assert.doesNotMatch(verify, /while holding it/);
  assert.match(model, /self.expireItemAppearanceLookup\(now: now\)/);
  for (const signature of ['private func findItemByLook(', 'private func verifyHeldItem(']) {
    assert.match(declaration(model, signature), /finishItemAppearanceLookup\(nativeLease\), self.requestID == request/);
    assert.match(declaration(model, signature), /settleUnusableItemAppearanceView\(capture\)/);
  }
  const finish = declaration(model, 'private func finishItemAppearanceLookup(');
  assert.ok(finish.indexOf('objectSearchNativeLease == lease') < finish.indexOf('expireItemAppearanceLookup'));
  const native = read('ios/BlindAssist/VisionService.swift');
  assert.match(declaration(native, 'static func locate('), /guard objectDetectorAvailable else \{ return nil \}/);
});

test('no-depth foreground loop continues and resumes the same bounded object search', () => {
  const loop = declaration(model, 'private func updateNonspatialObjectMemory(');
  assert.match(loop, /resumeInterruptedSearchIfPossible\(\)/);
  assert.match(loop, /continueSearch\(\)/);
  assert.match(loop, /nonspatialOnly: true/);
  assert.match(declaration(model, 'private func resumeInterruptedSearchIfPossible('), /captureObjectView\(frame\) != nil/);
  const search = declaration(model, 'private func continueSearch(');
  assert.ok(search.indexOf('now - search.startedAt >= ObjectSearch.duration') < search.indexOf('captureObjectView(frame)'));
  assert.match(search, /current.startedAt == search.startedAt/);
  assert.ok(search.indexOf('now - search.startedAt >= ObjectSearch.duration') < search.indexOf('!searchInFlight'));
  assert.match(search, /objectSearchNativeLease == nil/);
  assert.match(search, /finishObjectSearchNativeLease\(nativeLease\)/);
  assert.doesNotMatch(search, /offerSearchHint\(|LocalImageAssistant|ObjectSearch\.hint\(/);
  assert.match(search, /self.searchInFlight = false[\s\S]*self.objectViewIsCurrent\(capture\)/);
});

test('extracted object discovery and saved-item callbacks accept no-depth RGB and reject stale superseded evidence', {
  skip: !process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC for the bounded production-method harness.',
}, () => {
  const signatures = ['private struct ObjectViewCapture', 'private func captureObjectView(', 'private func objectViewIsCurrent(',
    'private func locate(', 'private func finishObjectSearchNativeLease(', 'private func continueSearch(',
    'private func beginItemAppearanceLookup(', 'private func expireItemAppearanceLookup(', 'private func finishItemAppearanceLookup(', 'private func settleUnusableItemAppearanceView(', 'private func findItemByLook(', 'private func verifyHeldItem('];
  const methods = signatures.map(signature => declaration(model, signature)).join('\n')
    .replaceAll('ProcessInfo.processInfo.systemUptime', 'TestClock.now').replaceAll('private ', '');
  const swift = `import Foundation
${declaration(read('BlindCore/Sources/BlindCore/Geometry.swift'), 'public struct Point3:')}
${read('BlindCore/Sources/BlindCore/RequestedVisualCapturePose.swift')}
${read('BlindCore/Sources/BlindCore/AssistantSession.swift')}
${declaration(read('BlindCore/Sources/BlindCore/ContextualTextPolicy.swift'), 'public enum FrameTimestampPolicy')}
${declaration(read('BlindCore/Sources/BlindCore/HazardDetector.swift'), 'public enum Hazard:')}
enum CompanionNaming {
    static func phrase(_ value: String, arabic: Bool) -> String { value }
    static func generic(_ value: String, arabic: Bool) -> String { value }
}
enum SpatialClaimGuard { static func containsSpatialClaim(_ value: String) -> Bool { false } }
${declaration(read('BlindCore/Sources/BlindCore/ObjectSearch.swift'), 'public struct ObjectSearch:')}
enum TestClock { static var now = 100.0 }
enum Orientation { case portrait, landscape }
class UIScene {}
final class UIWindowScene: UIScene { var interfaceOrientation = Orientation.portrait }
final class UIApplication { static let shared = UIApplication(); var connectedScenes: [UIScene] = [UIWindowScene()] }
enum Tracking { case normal, limited }
struct Transform {
    var columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) =
        (.init(1,0,0,0), .init(0,1,0,0), .init(0,0,1,0), .init(0,0,0,1))
}
struct Camera { var trackingState = Tracking.normal; var transform = Transform() }
struct ARFrame { var camera = Camera(); var timestamp = 100.0; let capturedImage = 7 }
final class Session { var currentFrame: ARFrame? = ARFrame() }
struct Places { var scanning = false }
struct Detection { var hazard = Hazard.uncertain }
struct Observation { let camera: Point3; let forward: Point3; let trackingNormal: Bool }
struct Indoor { let revision = UUID(); let alignmentRevision = UUID() }
struct Ticket { let id = UUID() }
struct RememberedItem { let name: String; let key: String }
final class ItemMemory {
    var items = [RememberedItem(name: "cup", key: "cup")]
    func find(_ name: String) -> RememberedItem? { items.first { $0.name == name } }
    static func answer(for item: RememberedItem?, asked: String, now: Date, sameFrame: Bool, measuredRelation: String?, arabic: Bool) -> String { "Historical item record" }
}
enum ItemAppearanceMatch { enum Result { case same(String), similar(String), none } }
final class ItemAppearance {
    var views = 3
    var pending: [(ItemAppearanceMatch.Result, Double, Double) -> Void] = []
    var images: [Int] = []
    func viewCount(_ key: String) -> Int { views }
    func find(_ key: String, among keys: [String], image: Int, completion: @escaping (ItemAppearanceMatch.Result, Double, Double) -> Void) {
        images.append(image); pending.append(completion)
    }
    func finish(_ result: ItemAppearanceMatch.Result) { pending.removeFirst()(result, 0.5, 0.5) }
}
enum ImageOrientation { case right }
enum VisionService {
    static var result: (label: String, x: Double, y: Double)? = ("cup",0.5,0.5)
    static var hold = false
    static let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    static func locate(target: String, image: Int, orientation: ImageOrientation, arabic: Bool) throws -> (label: String, x: Double, y: Double)? {
        if hold { started.signal(); release.wait() }
        return result
    }
}
enum DepthSampler { static func worldPoint(from: ARFrame, uprightX: Double, uprightY: Double) -> Point3? { nil } }
enum SpatialFacts {
    struct Relation {}
    static func relation(from: Point3, facing: Point3, to: Point3) -> Relation? { nil }
    static func phrase(label: String, relation: Relation, arabic: Bool, inView: Bool?) -> String { "Physical branch must not execute" }
}
struct TrackedTarget { init(label: String, query: String, point: Point3, now: Double) {} }
@MainActor final class NavigationModel {
    static let objectInteractionGuidanceValidated = false
    var assistantSession = AssistantSession()
    var cameraAwareness = true, running = true, simulation = false, arabic = false
    var places = Places(), detection = Detection(), session = Session()
    var lastFrameWallTime = 100.0
    var requestID = UUID(), passiveObservationGeneration = UUID(), perceptionGeneration = UUID(), itemMemoryRevision = UUID()
    var lastObservation: Observation? = nil
    var indoor = Indoor(), everydayTicket: Ticket? = nil
    var objectSearch: ObjectSearch?, trackedTarget: TrackedTarget?
    var searchInFlight = false, lookupInFlight = false
    var objectSearchNativeLease: UUID?
    var itemAppearanceLookup: (lease: UUID, capture: ObjectViewCapture, expiresAt: Double)?
    var lastTrackLook = 0.0
    let items = ItemMemory(), itemAppearance = ItemAppearance()
    var spoken: [String] = [], matches: [String] = [], records: [Bool] = []
    var modelHints = 0
    func say(_ value: String) { spoken.append(value) }
    func currentBodyForward() -> Point3? { nil }
    func recordSearch(_ target: String, located: Bool) { records.append(located) }
    func deliverObjectSearchMatch(_ text: String, target: String, ticketID: UUID?) { matches.append(text) }
    func offerSearchHint(target: String, startedAt: Double) { modelHints += 1 }
    func spokenDescription(_ item: RememberedItem) -> String { "" }
    func perceptionResultAllowed(request: UUID, generation: UUID, capturedAt: Double, observation: Observation, mapRevision: UUID, alignmentRevision: UUID) -> Bool { false }
    ${methods}
}
@MainActor func ready() -> NavigationModel {
    TestClock.now = 100; UIApplication.shared.connectedScenes = [UIWindowScene()]
    VisionService.result = ("cup",0.5,0.5); VisionService.hold = false
    let model = NavigationModel(); model.assistantSession.start(); return model
}
@MainActor func waitForSearch(_ model: NavigationModel) async {
    for _ in 0..<1000 {
        if !model.searchInFlight { return }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    preconditionFailure("Fixture native callback failed to return")
}
@main struct Main {
 @MainActor static func main() async {
    var checks = 0
    func check(_ value: @autoclosure () -> Bool, _ name: String) { precondition(value(), name); checks += 1 }
    var m = ready(); let c = m.captureObjectView(m.session.currentFrame!)!
    check(m.lastObservation == nil && m.objectViewIsCurrent(c), "RGB candidate needs no depth observation")
    m.detection.hazard = .needsCalibration
    check(m.objectViewIsCurrent(c), "Floor calibration adds no nonspatial authority")
    m.perceptionGeneration = UUID()
    check(m.objectViewIsCurrent(c), "Spatial generation loss alone cannot invalidate RGB")
    m.passiveObservationGeneration = UUID()
    check(!m.objectViewIsCurrent(c), "RGB generation changed")
    m = ready(); let requestCapture = m.captureObjectView(m.session.currentFrame!)!; m.requestID = UUID()
    check(!m.objectViewIsCurrent(requestCapture), "New question rejects old result")
    m = ready(); let sessionCapture = m.captureObjectView(m.session.currentFrame!)!; m.assistantSession.mute()
    check(!m.objectViewIsCurrent(sessionCapture), "Session transition rejects old result")
    m = ready(); m.assistantSession.losePrivateAudioRoute()
    check(m.captureObjectView(m.session.currentFrame!) == nil, "Private-route hold")
    m = ready(); m.cameraAwareness = false
    check(m.captureObjectView(m.session.currentFrame!) == nil, "Camera explicitly disabled")
    m = ready(); m.assistantSession.enterBackground()
    check(m.captureObjectView(m.session.currentFrame!) == nil, "Background capture disabled")
    m = ready(); m.detection.hazard = .obstacle
    check(m.captureObjectView(m.session.currentFrame!) == nil, "Actual urgent hazard")
    m = ready(); m.session.currentFrame!.camera.trackingState = .limited
    check(m.captureObjectView(m.session.currentFrame!) == nil, "Tracking unavailable")
    m = ready(); m.lastFrameWallTime = 99
    check(m.captureObjectView(m.session.currentFrame!) == nil, "Stale processed sensor clock")
    m = ready(); m.session.currentFrame!.timestamp = 99.5
    check(m.captureObjectView(m.session.currentFrame!) == nil, "Existing strict half-second result limit")
    m = ready(); m.session.currentFrame!.timestamp = 101
    check(m.captureObjectView(m.session.currentFrame!) == nil, "Future frame")
    m = ready(); let pitch = m.captureObjectView(m.session.currentFrame!)!
    m.session.currentFrame!.camera.transform.columns.2 = .init(0,sin(Float.pi/18),cos(Float.pi/18),0)
    check(!m.objectViewIsCurrent(pitch), "Pitch-only rotation rejected")
    m = ready(); let moved = m.captureObjectView(m.session.currentFrame!)!; m.session.currentFrame!.camera.transform.columns.3.x = 0.11
    check(!m.objectViewIsCurrent(moved), "Translation rejected")
    m = ready(); let snapshot = m.captureObjectView(m.session.currentFrame!)!
    TestClock.now = 102; m.lastFrameWallTime = 102; m.session.currentFrame!.timestamp = 102
    check(!m.objectViewIsCurrent(snapshot) && m.objectViewIsCurrent(snapshot, snapshotPlayback: true), "Snapshot authority never extends default live candidate admission")
    TestClock.now = 111.99; m.lastFrameWallTime = 111.99; m.session.currentFrame!.timestamp = 111.99
    check(m.objectViewIsCurrent(snapshot, snapshotPlayback: true), "Explicit captured-view speech can finish within twelve seconds")
    TestClock.now = 112.01; m.lastFrameWallTime = 112.01; m.session.currentFrame!.timestamp = 112.01
    check(!m.objectViewIsCurrent(snapshot, snapshotPlayback: true), "Captured-view authority is bounded to twelve seconds")
    TestClock.now = 102; m.lastFrameWallTime = 102; m.session.currentFrame!.timestamp = 102
    m.session.currentFrame!.camera.transform.columns.2 = .init(0,sin(Float.pi/18),cos(Float.pi/18),0)
    check(!m.objectViewIsCurrent(snapshot, snapshotPlayback: true), "Snapshot permission does not relax optical association")
    m = ready(); check(m.locate("cup", question: "find cup"), "No-depth search begins")
    await waitForSearch(m)
    check(m.matches.count == 1 && m.matches[0].contains("cannot confirm"), "Real callback path delivers only unconfirmed candidate")
    check(m.trackedTarget == nil && m.records == [false], "No physical tracking or located assertion")
    m = ready(); _ = m.locate("cup", question: "find cup"); TestClock.now = 100.6
    await waitForSearch(m)
    check(m.matches.isEmpty && m.objectSearch != nil, "Stale callback silently releases for a fresh attempt")
    m.session.currentFrame!.timestamp = 100.6; m.lastFrameWallTime = 100.6; m.continueSearch()
    await waitForSearch(m)
    check(m.matches.count == 1, "Fresh later RGB frame continues the same search")
    m = ready(); _ = m.locate("cup", question: "find cup"); m.assistantSession.mute()
    await waitForSearch(m)
    check(m.matches.isEmpty, "Callback cannot name after session change")
    m = ready(); VisionService.hold = true; _ = m.locate("cup", question: "find cup")
    precondition(VisionService.started.wait(timeout: .now() + 2) == .success)
    let heldLease = m.objectSearchNativeLease!
    m.requestID = UUID(); m.searchInFlight = false; m.objectSearch = nil
    _ = m.locate("book", question: "find book")
    check(m.objectSearch == nil && m.objectSearchNativeLease == heldLease && m.matches.isEmpty, "Cancellation cannot enqueue replacement behind occupied native slot")
    VisionService.hold = false; VisionService.release.signal()
    for _ in 0..<1000 { if m.objectSearchNativeLease == nil { break }; try? await Task.sleep(nanoseconds: 1_000_000) }
    check(m.objectSearchNativeLease == nil && m.matches.isEmpty, "Retired request callback frees only its own resource, never old output")
    _ = m.locate("book", question: "find book")
    let successor = m.objectSearchNativeLease!
    check(!m.finishObjectSearchNativeLease(heldLease) && m.objectSearchNativeLease == successor, "Duplicate old callback cannot retire successor")
    await waitForSearch(m)
    check(m.matches.count == 1, "New native look becomes available only after exact completion")
    m = ready(); VisionService.hold = true; _ = m.locate("cup", question: "find cup")
    precondition(VisionService.started.wait(timeout: .now() + 2) == .success)
    let stalledLease = m.objectSearchNativeLease!
    TestClock.now = 120; m.lastFrameWallTime = 120; m.session.currentFrame!.timestamp = 120; m.continueSearch()
    check(m.objectSearch == nil && !m.searchInFlight && m.objectSearchNativeLease == stalledLease && m.spoken.last!.contains("doesn't mean"), "Logical deadline completes while stalled native resource remains occupied")
    _ = m.locate("book", question: "find book")
    check(m.objectSearch == nil && m.objectSearchNativeLease == stalledLease, "A never-returning native job cannot stack replacements")
    VisionService.hold = false; VisionService.release.signal()
    for _ in 0..<1000 { if m.objectSearchNativeLease == nil { break }; try? await Task.sleep(nanoseconds: 1_000_000) }
    check(m.objectSearchNativeLease == nil && m.matches.isEmpty, "Late stalled result cannot revive expired search")
    m = ready(); VisionService.result = nil; _ = m.locate("cup", question: "find cup")
    await waitForSearch(m)
    TestClock.now = 100.6; m.lastFrameWallTime = 100.6; m.session.currentFrame!.timestamp = 100.6; m.continueSearch()
    await waitForSearch(m)
    check(m.objectSearch?.attempts == 2 && m.modelHints == 0 && m.matches.isEmpty, "Failed native looks never invoke image-model presence or side guesses")
    TestClock.now = 120; m.continueSearch()
    check(m.objectSearch == nil && m.matches.isEmpty && m.spoken.last!.contains("doesn't mean"), "Unsupported detection ends unknown, never invented absence or location")
    m = ready(); m.objectSearch = ObjectSearch(target: "cup", now: 70); m.session.currentFrame = nil
    m.continueSearch()
    check(m.objectSearch == nil && m.spoken.last!.contains("doesn't mean"), "Search expiry does not wait forever for another usable frame")
    m = ready(); m.findItemByLook(m.items.items[0], name: "cup", frame: m.session.currentFrame!)
    check(m.itemAppearance.images == [7], "Saved appearance receives the exact RGB buffer with no depth")
    m.itemAppearance.finish(.same("cup"))
    check(m.spoken.last!.contains("cannot confirm"), "Even strongest saved comparison stays unconfirmed")
    m = ready(); m.findItemByLook(m.items.items[0], name: "cup", frame: m.session.currentFrame!); TestClock.now = 100.6
    m.itemAppearance.finish(.same("cup"))
    check(m.spoken == ["I couldn't confirm the item from that view."] && !m.lookupInFlight && m.objectSearchNativeLease == nil && m.itemAppearanceLookup == nil, "Still-owned stale comparison settles honestly without stale positive output")
    m = ready(); _ = m.verifyHeldItem("cup"); TestClock.now = 100.6
    m.itemAppearance.finish(.same("cup"))
    check(m.spoken == ["I couldn't confirm the item from that view."] && !m.lookupInFlight, "Still-owned stale verification settles instead of losing its timeout silently")
    m = ready(); _ = m.verifyHeldItem("cup"); m.session.currentFrame!.camera.transform.columns.3.x = 0.2
    m.itemAppearance.finish(.same("cup"))
    check(m.spoken == ["I couldn't confirm the item from that view."], "Changed view gets inability, never an old positive")
    for invalidation in 0..<8 {
        m = ready(); _ = m.verifyHeldItem("cup"); TestClock.now = 100.6
        switch invalidation {
        case 0: m.requestID = UUID()
        case 1: m.assistantSession.mute()
        case 2: m.passiveObservationGeneration = UUID()
        case 3: m.assistantSession.losePrivateAudioRoute()
        case 4: m.detection.hazard = .drop
        case 5: m.cameraAwareness = false
        case 6: m.running = false
        default: m.places.scanning = true
        }
        m.itemAppearance.finish(.same("cup"))
        check(m.spoken.isEmpty && m.objectSearchNativeLease == nil, "Cancelled or unsafe stale comparison retires silently")
    }
    m = ready(); m.findItemByLook(m.items.items[0], name: "cup", frame: m.session.currentFrame!); m.itemMemoryRevision = UUID()
    m.itemAppearance.finish(.same("cup"))
    check(m.spoken.isEmpty, "Changed saved references invalidate comparison")
    m = ready(); m.findItemByLook(m.items.items[0], name: "cup", frame: m.session.currentFrame!); m.items.items = []
    m.itemAppearance.finish(.same("cup"))
    check(m.spoken.isEmpty, "Deleted item cannot be named")
    m = ready(); m.findItemByLook(m.items.items[0], name: "cup", frame: m.session.currentFrame!)
    let cancelledCallback = m.itemAppearance.pending[0], cancelledLease = m.objectSearchNativeLease!
    m.requestID = UUID(); m.lookupInFlight = false
    m.findItemByLook(m.items.items[0], name: "cup", frame: m.session.currentFrame!)
    check(m.itemAppearance.pending.count == 1 && m.objectSearchNativeLease == cancelledLease, "Cancel cannot stack saved comparisons behind an occupied slot")
    m.spoken = []; m.itemAppearance.finish(.same("cup"))
    check(m.objectSearchNativeLease == nil && m.spoken.isEmpty, "Cancelled comparison frees only its native slot")
    m.findItemByLook(m.items.items[0], name: "cup", frame: m.session.currentFrame!)
    let currentLookup = m.objectSearchNativeLease!
    cancelledCallback(.same("cup"),0.5,0.5)
    check(m.spoken.isEmpty && m.lookupInFlight && m.objectSearchNativeLease == currentLookup, "Old saved-item duplicate cannot release or expire successor")
    m.itemAppearance.finish(.similar("cup"))
    check(!m.lookupInFlight && m.spoken.count == 1, "Successor owns its result")
    m = ready(); _ = m.verifyHeldItem("cup")
    let stalledComparison = m.objectSearchNativeLease!
    TestClock.now = 105.99; m.expireItemAppearanceLookup(now: TestClock.now)
    check(m.lookupInFlight, "Comparison stays live before exact deadline")
    TestClock.now = 106; m.lastFrameWallTime = 106; m.session.currentFrame!.timestamp = 106; m.expireItemAppearanceLookup(now: TestClock.now)
    check(!m.lookupInFlight && m.itemAppearanceLookup == nil && m.objectSearchNativeLease == stalledComparison && m.spoken.last!.contains("didn't finish"), "Comparison timeout gives truthful answer without freeing native resource")
    let notices = m.spoken.count; m.expireItemAppearanceLookup(now: 107)
    check(m.spoken.count == notices, "No repeated timeout chatter")
    _ = m.verifyHeldItem("cup")
    check(m.itemAppearance.pending.count == 1 && m.objectSearchNativeLease == stalledComparison, "Hung appearance native work cannot accumulate replacements")
    m.spoken = []; m.itemAppearance.finish(.same("cup"))
    check(m.objectSearchNativeLease == nil && m.spoken.isEmpty, "Late comparison cannot revive an expired logical result")
    m = ready(); _ = m.verifyHeldItem("cup"); m.requestID = UUID(); m.lookupInFlight = false
    TestClock.now = 106; m.expireItemAppearanceLookup(now: TestClock.now)
    check(m.spoken.isEmpty && m.objectSearchNativeLease != nil, "Cancelled request timeout stays silent and retains native ownership")
    m.itemAppearance.finish(.same("cup"))
    m = ready(); check(m.verifyHeldItem("cup"), "Requested saved-item verification accepts no-depth capture")
    m.itemAppearance.finish(.same("cup"))
    check(m.spoken.last!.contains("cannot confirm"), "Verification does not promote ownership or handling authority")
    m = ready(); m.cameraAwareness = false; _ = m.verifyHeldItem("cup")
    check(m.spoken.last!.contains("fresh camera view") && !m.spoken.last!.contains("haven't saved"), "Unavailable camera is not missing saved appearance")
    m = ready(); m.itemAppearance.views = 0; _ = m.verifyHeldItem("cup")
    check(m.spoken.last!.contains("haven't saved") && m.itemAppearance.pending.isEmpty, "Missing template is stated without handling instructions")
    print("object RGB discovery: \\(checks) checks passed")
 }
}
`;
  const directory = mkdtempSync(join(tmpdir(), 'object-rgb-'));
  try {
    const input = join(directory, 'discovery.swift'), output = join(directory, 'discovery');
    writeFileSync(input, swift);
    execFileSync(process.env.BLIND_SWIFTC, ['-parse-as-library', '-module-cache-path', process.env.CLANG_MODULE_CACHE_PATH || join(directory, 'module-cache'), input, '-o', output], { encoding: 'utf8', timeout: 60_000 });
    const result = execFileSync(output, [], { encoding: 'utf8', timeout: 10_000 });
    assert.match(result, /object RGB discovery: 65 checks passed/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
