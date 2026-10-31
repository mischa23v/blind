"""Bounded source contracts only. Does not execute Swift, UIKit or microphone code.
Run: python3 tools/test/accessibility-voice-continuity.test.py
BLIND_SOURCE_ROOT may point to an isolated after/ overlay. No installs required.
"""
from pathlib import Path
import hashlib
import os
import unittest

ROOT = Path(os.environ.get("BLIND_SOURCE_ROOT", Path(__file__).resolve().parents[2]))
FILES = {
    "policy": "BlindCore/Sources/BlindCore/VoiceCaptureRecoveryPolicy.swift",
    "voice": "ios/BlindAssist/VoiceInput.swift",
    "model": "ios/BlindAssist/NavigationModel.swift",
    "ui": "ios/BlindAssist/DashboardView.swift",
    "uitests": "ios/BlindAssistUITests/LaunchTests.swift",
    "coretests": "BlindCore/Tests/BlindCoreTests/VoiceCaptureRecoveryPolicyTests.swift",
    "hosted": "ios/BlindAssistTests/ConversationRuntimeFailureTests.swift",
}
def block(source, start, end):
    begin = source.index(start)
    return source[begin:source.index(end, begin)]
def ordered(source, *tokens):
    positions = [source.index(token) for token in tokens]
    return positions == sorted(positions)
def sha(source):
    return hashlib.sha256(source.encode()).hexdigest()

def contracts(s):
    p, v, m, u, t = (s[x] for x in ["policy", "voice", "model", "ui", "uitests"])
    begin = block(p, "public mutating func begin(", "public mutating func cancel()")
    cancel = block(p, "public mutating func cancel()", "/// A disconnected")
    voice_begin = block(v, "private func begin(", "private func permissionUnavailable()")
    start = block(v, "func startContinuous(", "private var inBackground")
    explicit = block(m, "    func startConversation()", "    func muteConversation()")
    foreground = block(m, "    func resumeExperienceIfNeeded()", "    /// Camera work always")
    ask = block(u, "    private var assistant: some View", "    private var sceneQuestion:")
    quiet = block(u, 'Button(model.ambientDescriptions ? t("Quiet descriptions', "// Alternative access")
    return {
        "automatic begin cannot clear hold": ordered(begin, "guard !requiresExplicitRestart || explicitlyRequested", "requiresExplicitRestart = false", "cancel()", "requested = true"),
        "ordinary cancellation preserves hold": "requiresExplicitRestart = false" not in cancel,
        "terminal hold retires session first": "cancel()\n        requiresExplicitRestart = true" in p,
        "private route terminal": "privateRouteLost() { requireExplicitRestart() }" in p,
        "exhaustion terminal": "guard attempts < 3 else { requireExplicitRestart(); return nil }" in p,
        "system no resume terminal": "guard continuous, shouldResume else { requireExplicitRestart(); return false }" in p,
        "capture retains source and OS fences": all(x in p for x in ["requested && self.session == session && !interrupted && mediaServicesAvailable", "(!inBackground || backgroundAllowed)", "retry.token == pendingRetry"]),
        "bounded retries unchanged": all(x in p for x in ["attempts < 3", "now - healthySince >= 30", "pow(2, Double(attempts - 1))"]),
        "voice guard before cancellation": ordered(voice_begin, "guard !lifecycle.requiresExplicitRestart || explicitlyRequested", "cancel(); self.arabic", "lifecycle.begin(continuous: continuous, explicitlyRequested: explicitlyRequested)", "guard canCapture"),
        "explicit does not bypass active interruption": ordered(start, "guard !continuous || !lifecycle.requested || self.arabic != arabic else { return }", "begin(arabic:"),
        "terminal notification sees hold": "cancel(); lifecycle.requireExplicitRestart()\n        state = .failed; message = text; onUnavailable?(text)" in v,
        "permission checks retained": all(x in v for x in ["SFSpeechRecognizer.authorizationStatus() == .authorized", "recordPermission == .granted", "recognizer.supportsOnDeviceRecognition", "self.lifecycle.session == session, self.canCapture"]),
        "only explicit controller start clears hold": m.count("voice.startContinuous(arabic: arabic, explicitlyRequested: true)") == 1 and "voice.startContinuous(arabic: arabic, explicitlyRequested: true)" in explicit,
        "foreground remains automatic": "voice.startContinuous(arabic: arabic)" in foreground and "explicitlyRequested:" not in foreground,
        "manual offer remains automatic": "begin(arabic: arabic, continuous: false, timeout: timeout)" in v and "voice.start(arabic: arabic, timeout: 5)" in m,
        "reconnect uses existing owner": "if model.voice.requiresExplicitRestart" in u and 'identifier: "reconnect-conversation", prominent: true, action: model.reconnectListening' in u,
        "quiet resume only existing controls": "model.stopDescriptions()" in quiet and "model.resumeDescriptions()" in quiet and all(x not in quiet for x in ["startConversation", "muteConversation", "cameraAwareness", "startReading"]),
        "quiet accessibility state explicit": '.accessibilityIdentifier("conversation-descriptions")' in quiet and '.accessibilityValue(' in quiet,
        "Ask eager reflow": "ScrollView {\n            VStack(alignment: .leading, spacing: 20)" in ask and "Form {" not in ask and "LazyVStack" not in ask,
        "Ask no size clamping or hidden warning": all(x not in ask for x in [".dynamicTypeSize(", ".minimumScaleFactor(", ".accessibilityHidden(true)", ".frame(height:", ".font(.system(size:"]),
        "Ask reason retains multiline native text": all(x in ask for x in ['Text(localAnswerDisabledReason)', '.accessibilityIdentifier("local-answer-unavailable-reason")', '.lineLimit(nil)', '.fixedSize(horizontal: false, vertical: true)', '.multilineTextAlignment(.leading)']),
        "Ask actual permission and native picker preserved": '.disabled(model.busy || model.simulation || !model.running)' in ask and '.pickerStyle(.inline)' in ask and all(f'.tag("{x}")' in ask for x in ['surroundings', 'room', 'people', 'object', 'path', 'text']),
        "Ask heading navigation preserved": ask.count('.accessibilityAddTraits(.isHeader)') == 5,
        "practice production exact": sha(block(m, '    func startSimulation()', '    func simulate(_ hazard:')) == 'bf17ea9febb15cca2d226eca7c7db52cc287f29c67e2023a0bf5351322ffadb1',
        "practice 90s End witness exact": sha(block(t, '    func testPracticeIsAnnouncedAndCanStop()', '    func testAccessibleMainModesAndOfflineDefault()')) == 'c5bcbc7d745782b417db4ffb04bc915c5567ea79dcde4a380db468cdef8c12cb',
        "full audit exact no new exclusions": sha(block(t, '    @MainActor\n    private func auditFullDestination', '    func testOfflineCommunityLibraryKeepsLocalImportAvailable()')) == '9c1ee5444c5f451d3d76d45b3bb37106a928ff0b880d924fae0edb73b7c8d671',
        "new Core negatives authored": all(x in s['coretests'] for x in ['testTerminalFailureSurvivesCancelForegroundAndMediaReset', 'testAutomaticManualAnswerWindowCannotClearTerminalHold', 'testSystemRefusalToResumeNeedsExplicitRestartNotForegroundRetry', 'testExhaustedRetryBudgetCannotBeReplenishedByAutomaticBegin']),
        "hosted scope and source retention explicit": all(x in s['hosted'] for x in ['XCTAssertTrue(model.textOnly)', 'testQuietAndResumeDoNotMuteEndOrStartSensors', 'testMuteAndEndRemainStoppedAcrossForegroundAndDescriptionResume', 'testReportedCompletionKeepsExactParentSourceAcrossPauseAndRestart', 'XCTAssertEqual(restored.goalSource?.sourceID, "typed-parent")', 'XCTAssertTrue(restored.proposedStep.isEmpty']),
    }

class SourceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = {}
        for key, path in FILES.items():
            target = ROOT / path
            if target.stat().st_size > 2 * 1024 * 1024:
                raise ValueError("bounded source input exceeded")
            cls.source[key] = target.read_text()
    def test_all_contracts(self):
        for name, passed in contracts(self.source).items():
            with self.subTest(name=name): self.assertTrue(passed)
    def test_each_mutation_is_rejected(self):
        mutations = [
            ("policy", "guard !requiresExplicitRestart || explicitlyRequested else { return session }", "", "automatic begin cannot clear hold"),
            ("policy", "public mutating func cancel() {", "public mutating func cancel() {\n        requiresExplicitRestart = false", "ordinary cancellation preserves hold"),
            ("policy", "privateRouteLost() { requireExplicitRestart() }", "privateRouteLost() { cancel() }", "private route terminal"),
            ("policy", "guard attempts < 3 else { requireExplicitRestart(); return nil }", "guard attempts < 4 else { cancel(); return nil }", "exhaustion terminal"),
            ("voice", "cancel(); lifecycle.requireExplicitRestart()", "cancel()", "terminal notification sees hold"),
            ("model", "explicitlyRequested: true", "explicitlyRequested: false", "only explicit controller start clears hold"),
            ("ui", 'ScrollView {\n            VStack(alignment: .leading, spacing: 20)', 'ScrollView {\n            LazyVStack(alignment: .leading, spacing: 20)', "Ask eager reflow"),
            ("ui", '.pickerStyle(.inline)', '.dynamicTypeSize(.large)\n                .pickerStyle(.inline)', "Ask no size clamping or hidden warning"),
            ("uitests", "let cancellationEvidenceLimit: TimeInterval = 90", "let cancellationEvidenceLimit: TimeInterval = 120", "practice 90s End witness exact"),
            ("uitests", "end.tap()", "// end.tap()", "practice 90s End witness exact"),
            ("model", "Timer.scheduledTimer(withTimeInterval: 120, repeats: false)", "Timer.scheduledTimer(withTimeInterval: 90, repeats: false)", "practice production exact"),
        ]
        for key, old, new, name in mutations:
            with self.subTest(name=name):
                self.assertIn(old, self.source[key])
                changed = dict(self.source); changed[key] = changed[key].replace(old, new)
                try: accepted = contracts(changed)[name]
                except ValueError: accepted = False
                self.assertFalse(accepted, "mutated source must not satisfy the contract")

if __name__ == '__main__': unittest.main()
