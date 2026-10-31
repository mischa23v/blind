"""Portable source contract only; not a rendered contrast or native UI result."""
import hashlib
import os
from pathlib import Path
import unittest

ROOT = Path(os.environ.get('BLIND_SOURCE_ROOT', Path(__file__).resolve().parents[2]))
BUTTON = '''                Button(t("Repeat answer", "كرر الإجابة")) { model.speakRequested(model.sceneAnswer) }
                    .disabled(model.sceneAnswer.isEmpty)
                    // Reuse the readable disabled-state style; do not enable empty speech.
                    .buttonStyle(AskCameraAnswerButtonStyle(tint: accent))
                    .accessibilityIdentifier("repeat-answer")'''


def validate(dashboard, ui):
    assert dashboard.count(BUTTON) == 1, 'Exact action, disabled gate and readable style required'
    style = dashboard.split('private struct AskCameraAnswerButtonStyle:', 1)[1].split('\n/// The child', 1)[0]
    assert hashlib.sha256(style.encode()).hexdigest() == 'b1fa1aa3c6ebf21c0c17b424b238896ff2700912690ed8ad8107de79ca093d1e', 'Reuse the unchanged existing style'
    audit = ui.split('    private func auditFullDestination(', 1)[1].split('\n    @MainActor\n    func testAccessibilityAuditOfCameraAndAsk()', 1)[0]
    assert hashlib.sha256(audit.encode()).hexdigest() == '3091c683f16c1791133a0f258c92596ba52e825313eb0a7832d6cdb7e6e52b06', 'Do not weaken the exact failed audit'
    test = ui.split('    func testAskControlsAndUnavailableReasonRemainReachableWithoutCamera()', 1)[1].split('\n    func testRooms', 1)[0]
    assert 'let repeatAnswer = app.buttons["repeat-answer"]' in test
    assert 'reveal(repeatAnswer)' in test
    assert 'XCTAssertFalse(repeatAnswer.isEnabled, "Readable styling must not enable an empty answer")' in test
    assert '("repeat-answer", app.buttons["repeat-answer"]),' in ui, 'Include the identified control in existing audit evidence'


class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dashboard = (ROOT / 'ios/BlindAssist/DashboardView.swift').read_text()
        cls.ui = (ROOT / 'ios/BlindAssistUITests/LaunchTests.swift').read_text()

    def test_actual_source_contract(self):
        validate(self.dashboard, self.ui)

    def test_dimmed_style_or_disabled_action_bypasses_are_rejected(self):
        for old, new in [
            ('.buttonStyle(AskCameraAnswerButtonStyle(tint: accent))', '.buttonStyle(CameraControlButtonStyle())'),
            ('.disabled(model.sceneAnswer.isEmpty)', '.disabled(false)'),
            ('model.speakRequested(model.sceneAnswer)', 'model.speakRequested("invented answer")'),
            ('.accessibilityIdentifier("repeat-answer")', '.accessibilityHidden(true)'),
        ]:
            with self.subTest(change=new):
                altered = self.dashboard.replace(BUTTON, BUTTON.replace(old, new), 1)
                self.assertNotEqual(altered, self.dashboard)
                with self.assertRaises(AssertionError):
                    validate(altered, self.ui)

    def test_new_audit_exemption_is_rejected(self):
        altered = self.ui.replace('return element.identifier == "retrace-session" && !element.isEnabled', 'return !element.isEnabled')
        self.assertNotEqual(altered, self.ui)
        with self.assertRaises(AssertionError):
            validate(self.dashboard, altered)

    def test_native_disabled_state_assertion_is_required(self):
        altered = self.ui.replace('XCTAssertFalse(repeatAnswer.isEnabled, "Readable styling must not enable an empty answer")', 'XCTAssertTrue(repeatAnswer.exists)')
        self.assertNotEqual(altered, self.ui)
        with self.assertRaises(AssertionError):
            validate(self.dashboard, altered)


if __name__ == '__main__':
    unittest.main()
