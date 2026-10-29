"""Source contracts only; native policy tests are separate and must execute on Apple."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
class RuntimeFailureSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.adapter = (ROOT / 'ios/BlindAssist/LocalImageAssistant.swift').read_text()
        cls.controller = (ROOT / 'ios/BlindAssist/NavigationModel.swift').read_text()
    def test_generation_failure_keeps_nil_text_and_no_retry(self):
        factory = self.adapter.split('static func conversationFailure(', 1)[1].split('/// Controllers', 1)[0]
        self.assertIn('LocalImageAnswer(text: nil, status: message, conversationRuntimeFailure: failure)', factory)
        self.assertNotIn('respond(', factory)
        self.assertNotIn('taskUpdate:', factory)
    def test_generic_catch_honors_cancellation(self):
        catch = self.adapter.split('conversation.failed; errorDetailsOmitted', 1)[1].split('static func spot', 1)[0]
        self.assertLess(catch.index('guard !Task.isCancelled'), catch.index('conversationFailure(.generationFailed'))
        self.assertNotIn('onPartial?', catch)
        self.assertNotIn('onSpeechCandidate?', catch)
        self.assertNotIn('onReplyComplete?', catch)
    def test_anonymous_fallback_is_after_current_session_fence(self):
        block = self.controller.split('let answer = await LocalImageAssistant.converse', 1)[1].split('/// Select existing adapters', 1)[0]
        self.assertLess(block.index('guard !Task.isCancelled'), block.index('answer.conversationOperationalFallback'))
        self.assertLess(block.index('self.assistantSession.accepts(generation:'), block.index('answer.conversationOperationalFallback'))
        self.assertLess(block.index('self.requestID == request'), block.index('answer.conversationOperationalFallback'))
    def test_trusted_fallback_is_after_reactive_admission(self):
        block = self.controller.split('let admission = CompanionReactiveSequence.tick([', 1)[1]
        self.assertLess(block.index('guard admission == .success'), block.index('answer.conversationOperationalFallback'))
        self.assertIn('Task.isCancelled ? .failure : .success', block)
        self.assertIn('self.conversationMemoryRevision == memoryRevision', block)
    def test_runtime_failure_not_in_evidence_rejection_path(self):
        block = self.adapter.split('if finalRejected {', 1)[1].split('catch is CancellationError', 1)[0]
        self.assertNotIn('conversationFailure(', block)
        self.assertIn('CompanionEvidenceGuard.unavailableReply', block)
if __name__ == '__main__': unittest.main()
