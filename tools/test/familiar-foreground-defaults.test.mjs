// Source contracts plus an optional extracted Swift lifecycle test. Neither is an
// Apple build, recognition-accuracy result, camera test or child-use acceptance.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
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

test('compiled familiar-person controller restores preference and validated gallery before first camera session', () => {
  assert.ok(controller.startsWith('#if BLIND_FAMILIAR_PEOPLE\n'));
  const init = declaration(controller, 'init(preferences:');
  assert.match(init, /enabled = FamiliarRecognitionPreference\.isEnabled\(in: preferences\)/);
  assert.match(init, /reload\(announce: false\)/);
  const preference = declaration(controller, 'private enum FamiliarRecognitionPreference');
  assert.match(preference, /guard let stored = preferences\.object\(forKey: key\) else \{ return true \}/);
  assert.match(preference, /return stored as\? Bool \?\? false/);
  const reload = declaration(controller, 'func reload(');
  assert.match(reload, /people = try store\.load\(\); storageReady = true/);
  assert.match(reload, /catch \{ people = \[\]; storageReady = false/);
  assert.doesNotMatch(reload, /enabled =|FamiliarRecognitionPreference\.save|store\.save/);
  assert.doesNotMatch(init, /setEnabled\(true\)|requestEnable\(|model\.start\(/);
});

test('explicit off and on persist but foreground retry never overrides a choice or active enrollment', () => {
  const toggle = declaration(controller, 'func setEnabled(');
  assert.match(toggle, /cancel\(\); enabled = value/);
  assert.match(toggle, /FamiliarRecognitionPreference\.save\(value, in: preferences\)/);
  const deletion = declaration(controller, 'func deleteAll(');
  assert.match(deletion, /enabled = false/);
  assert.match(deletion, /FamiliarRecognitionPreference\.save\(false, in: preferences\)/);
  const retry = declaration(controller, 'func prepareForForegroundSession(');
  assert.match(retry, /applicationState == \.active, !storageReady, !hasActiveWork/);
  assert.match(retry, /reload\(announce: false\)/);
  assert.doesNotMatch(retry, /enabled =|FamiliarRecognitionPreference\.save|requestEnable\(/);
  assert.doesNotMatch(declaration(controller, 'func consume('), /store\.load|prepareForForegroundSession/);
  assert.doesNotMatch(declaration(controller, 'func leaveEnrollmentScreen('), /setEnabled\(|enabled =/);
  assert.match(view, /\.disabled\(!acknowledged && !experiment\.enabled\)/);
  assert.doesNotMatch(view, /enable for this visit|Enable experimental hints for this visit/i);
});

test('automatic eligibility retains validated consent model hashes capture gates and late-result rejection', () => {
  const store = read('ios/BlindAssist/FamiliarFaceStore.swift');
  assert.match(store, /archive\.model == Self\.modelID, valid\(archive\.people\)/);
  assert.match(store, /FamiliarEnrollmentConsent\(rawValue: person\.consent\) != nil/);
  assert.match(controller, /SHA256\.hash\(data: Data\(contentsOf: url, options: \.mappedIfSafe\)\)/);
  const consume = declaration(controller, 'func consume(');
  for (const text of ['UIApplication.shared.applicationState == .active', 'enabled, storageReady, !people.isEmpty',
    'draft == nil, pending == nil', 'model.captureFamiliarFace()', 'token == liveRevision',
    'request == generation', '!Task.isCancelled, enabled', 'model.familiarCaptureIsCurrent(capture)']) {
    assert.ok(consume.includes(text), text);
  }
  assert.match(controller, /confirmation\.consume\(token/);
  assert.match(controller, /consentAt: Date\(\)/);
  assert.match(controller, /consent: draft\.consent\.rawValue, consentAt: draft\.consentAt/);
  assert.match(controller, /Confirm this adult permits on-phone face templates and automatic tentative hints/);
  assert.doesNotMatch(declaration(controller, 'private enum FamiliarRecognitionPreference'), /people\.count|examples\.count|consentAt|FamiliarTemplate/);
});

test('enrollment addresses the sighted adult and never requires giving away the child phone', () => {
  const instructions = declaration(controller, 'var captureInstruction:');
  assert.match(instructions, /Keep the phone with the child/);
  assert.match(instructions, /Adult being added: face the child and their camera/);
  assert.match(instructions, /Adult being added: turn your head slightly left/);
  assert.match(instructions, /Adult being added: turn your head slightly right/);
  assert.match(controller, /Ask the participant or guardian to adjust their position or lighting while the child keeps the phone/);
  assert.match(view, /Keep the phone with the child throughout/);
  assert.doesNotMatch(view + controller, /give (?:the|your) phone|hand (?:the|your) phone|Move closer or improve lighting/i);
});

test('passive context cancellation stays silent and cancels only its own arrival speech', () => {
  const cancel = declaration(controller, 'func cancel(announce:');
  assert.match(cancel, /if announce \{ status = message \} else \{ setSilentStatus\(message\) \}/);
  const work = declaration(controller, 'private func cancelWork(');
  assert.match(work, /let hadExplicitFaceWork = busy \|\| searching \|\| snapshotCapture != nil \|\| resultCapture != nil \|\| draft != nil \|\| pending != nil \|\| showPicker/);
  assert.match(work, /if hadExplicitFaceWork \{ onCancelSpeech\?\(\) \}/);
  assert.match(work, /invalidateLiveEvidence\(\)/);
  assert.match(declaration(controller, 'private func invalidateLiveEvidence('), /cancelArrivalHint\(\)/);
  assert.match(declaration(controller, 'private func cancelArrivalHint('), /onCancelArrivalHint\?\(id\)/);
});

test('extracted Swift preference and foreground lifecycle preserves explicit choices', {
  skip: !process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC to run the bounded extracted-source lifecycle harness.',
}, () => {
  const methods = ['init(preferences:', 'func reload(', 'func prepareForForegroundSession(', 'func setEnabled(', 'func deleteAll(',
    'private func cancelWork(', 'func cancel(announce:', 'private func setSilentStatus(']
    .map(signature => declaration(controller, signature)).join('\n');
  const swift = `import Foundation
import Dispatch
${declaration(controller, 'private enum FamiliarRecognitionPreference')}
enum ApplicationState { case active, inactive }
final class UIApplication {
    static let shared = UIApplication()
    var applicationState = ApplicationState.active
}
struct FamiliarTemplate { let label: String }
final class FamiliarFaceStore {
    enum Failure: Error { case unavailable }
    static var unavailable = false
    static var saved = [FamiliarTemplate(label: "Consented adult fixture")]
    static var loads = 0
    func load() throws -> [FamiliarTemplate] {
        Self.loads += 1
        if Self.unavailable { throw Failure.unavailable }
        return Self.saved
    }
    func deleteAll() throws { Self.saved = [] }
}
struct Encounters { mutating func reset() {} }
struct Confirmation { mutating func cancel() {} }
final class Cancellable { func cancel() {} }
final class FamiliarFaceExperiment {
    private let preferences: UserDefaults
    private let store = FamiliarFaceStore()
    var enabled = false
    var storageReady = false
    var people: [FamiliarTemplate] = []
    var hasActiveWork = false
    var silenceStatus = false
    var dualPipeline = false
    var encounters = Encounters()
    var confirmation = Confirmation()
    var confirmationToken: UUID?
    var awaitingConfirmation = false
    var generation = UUID()
    var task: Cancellable?
    var expiry: Cancellable?
    var busy = false
    var searching = false
    var snapshotCapture: Int?
    var resultCapture: Int?
    var draft: Int?
    var pending: Int?
    var showPicker = false
    var onCancelSpeech: (() -> Void)?
    var onEvidenceInvalidated: (() -> Void)?
    var spoken = 0
    var cancellations = 0
    var status = "" { didSet { if !silenceStatus { spoken += 1 } } }
    func invalidateLiveEvidence() { cancellations += 1 }
    func publishDraft() {}
    ${methods}
}
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    precondition(condition(), name); checks += 1
}
let suite = "familiar-foreground-tests." + UUID().uuidString
let preferences = UserDefaults(suiteName: suite)!
defer { preferences.removePersistentDomain(forName: suite) }
let first = FamiliarFaceExperiment(preferences: preferences)
check(first.enabled, "Unset preference permits automatic checking")
check(first.storageReady && first.people.count == 1, "Validated gallery loaded before helper visit")
check(first.spoken == 0, "Initialization is silent")
check(first.cancellations == 0, "Initialization cannot cancel unrelated speech")
check(preferences.object(forKey: FamiliarRecognitionPreference.key) == nil, "Default does not save an inferred user choice")
first.setEnabled(false)
check(!first.enabled, "Explicit off takes effect")
check(preferences.object(forKey: FamiliarRecognitionPreference.key) as? Bool == false, "Explicit off saved")
let afterOff = FamiliarFaceExperiment(preferences: preferences)
check(!afterOff.enabled, "Explicit off survives reconstruction")
afterOff.reload(announce: false)
check(!afterOff.enabled, "Gallery reload cannot enable recognition")
check(afterOff.spoken == 0, "Silent reload stays silent")
afterOff.setEnabled(true)
let afterOn = FamiliarFaceExperiment(preferences: preferences)
check(afterOn.enabled, "Explicit on survives reconstruction")
check(preferences.object(forKey: FamiliarRecognitionPreference.key) as? Bool == true, "Explicit on saved")
let loaded = FamiliarFaceStore.loads
afterOn.prepareForForegroundSession()
check(FamiliarFaceStore.loads == loaded, "Ready gallery is not loaded on each session hook")
preferences.set("invalid", forKey: FamiliarRecognitionPreference.key)
check(!FamiliarRecognitionPreference.isEnabled(in: preferences), "Malformed preference fails closed")
FamiliarRecognitionPreference.save(false, in: preferences)
FamiliarFaceStore.unavailable = true
let locked = FamiliarFaceExperiment(preferences: preferences)
check(!locked.storageReady && locked.people.isEmpty, "Unavailable gallery yields no identities")
check(!locked.enabled, "Unavailable storage cannot override off")
check(locked.spoken == 0, "Failed initial load is silent")
let failedLoads = FamiliarFaceStore.loads
UIApplication.shared.applicationState = .inactive
locked.prepareForForegroundSession()
check(FamiliarFaceStore.loads == failedLoads, "No retry in background")
UIApplication.shared.applicationState = .active
locked.hasActiveWork = true
locked.prepareForForegroundSession()
check(FamiliarFaceStore.loads == failedLoads && locked.hasActiveWork, "Foreground retry preserves active consent or enrollment")
locked.hasActiveWork = false
FamiliarFaceStore.unavailable = false
locked.prepareForForegroundSession()
check(locked.storageReady && locked.people.count == 1, "Foreground retry restores unlocked gallery")
check(!locked.enabled, "Unlock cannot override explicit off")
check(locked.spoken == 0, "Foreground storage recovery stays silent")
check(locked.cancellations == 0, "Foreground storage recovery cannot cancel unrelated speech")
locked.setEnabled(true)
locked.deleteAll()
check(!locked.enabled && locked.people.isEmpty, "Delete-all cancels and disables recognition")
check(preferences.object(forKey: FamiliarRecognitionPreference.key) as? Bool == false, "Delete-all keeps explicit off across restart")
let afterDelete = FamiliarFaceExperiment(preferences: preferences)
check(!afterDelete.enabled && afterDelete.people.isEmpty, "Deleted gallery does not restart recognition")
let passive = FamiliarFaceExperiment(preferences: preferences)
var canceledSpeech = 0
passive.onCancelSpeech = { canceledSpeech += 1 }
let oldGeneration = passive.generation
passive.cancel(announce: false)
check(passive.spoken == 0, "Automatic cancellation is silent")
check(canceledSpeech == 0, "Passive cancellation does not stop unrelated speech")
check(passive.generation != oldGeneration, "Silent cancellation still invalidates stale results")
passive.snapshotCapture = 1
passive.cancel(announce: false)
check(canceledSpeech == 1 && passive.snapshotCapture == nil, "Own snapshot speech and evidence are canceled")
passive.pending = 1
passive.draft = 1
passive.awaitingConfirmation = true
passive.cancel(announce: false)
check(canceledSpeech == 2 && passive.pending == nil && passive.draft == nil, "Silent cancellation discards unfinished consent and enrollment")
check(!passive.awaitingConfirmation && passive.spoken == 0, "No stale consent or cancellation announcement survives")
passive.cancel()
check(passive.spoken == 1, "Explicit user cancellation still acknowledges")
print("familiar foreground lifecycle: \\(checks) checks passed")
`;
  const directory = mkdtempSync(join(tmpdir(), 'familiar-foreground-'));
  try {
    const input = join(directory, 'lifecycle.swift'), output = join(directory, 'lifecycle');
    writeFileSync(input, swift);
    execFileSync(process.env.BLIND_SWIFTC, ['-module-cache-path', join(directory, 'module-cache'), input, '-o', output], { encoding: 'utf8', timeout: 60_000 });
    const result = execFileSync(output, [], { encoding: 'utf8', timeout: 10_000 });
    assert.match(result, /familiar foreground lifecycle: 33 checks passed/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
