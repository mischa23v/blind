"""Source wiring contracts, not native/model execution or Swift type checking."""
from pathlib import Path
import unittest,re
ROOT=Path(__file__).resolve().parents[2]

class ConversationDiagnosticSourceTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.source=(ROOT/'ios/BlindAssist/LocalImageAssistant.swift').read_text()
  cls.diagnostic=cls.source.split('struct ConversationFailureDiagnostic:',1)[1].split('/// App-owned state:',1)[0]
  cls.tests=(ROOT/'ios/BlindAssistTests/CommunityTests.swift').read_text()
 def test_no_private_error_payload_is_accessed_or_printed(self):
  for forbidden in ['.localizedDescription','.debugDescription','.userInfo','String(describing:', 'String(reflecting:', 'print(', 'Logger(', 'underlyingError']:
   self.assertNotIn(forbidden,self.diagnostic)
  self.assertIn('switch native.domain {',self.diagnostic)
  self.assertNotIn('native.domain)',self.diagnostic)
 def test_unknown_domains_and_out_of_range_codes_fail_closed(self):
  self.assertIn('default: family = .unclassified',self.diagnostic)
  self.assertIn('family != .unclassified && (0...255).contains(native.code) ? native.code : nil',self.diagnostic)
  domains=re.findall(r'case "([^"]+)": family =',self.diagnostic)
  self.assertEqual(domains,['FoundationModels.LanguageModelSession.GenerationError','FoundationModels.LanguageModelError','FoundationModels.LanguageModelSession.Error','FoundationModels.SystemLanguageModel.Error'])
 def test_no_recovery_or_generation_in_diagnostic(self):
  for forbidden in ['respond(', 'streamResponse(', 'Task {', 'retry', 'guardrails:', 'onPartial?', 'onSpeechCandidate?']:
   self.assertNotIn(forbidden,self.diagnostic)
  self.assertIn('let opaqueCode: Int?',self.diagnostic)
 def test_cancellation_fence_precedes_diagnostic_capture(self):
  catch=self.source.split('conversation.failed; errorDetailsOmitted',1)[1].split('static func spot',1)[0]
  self.assertLess(catch.index('guard !Task.isCancelled'),catch.index('ConversationFailureDiagnostic.capture(error'))
  self.assertLess(catch.index('ConversationFailureDiagnostic.capture(error'),catch.index('conversationFailure(.generationFailed'))
 def test_phases_and_sdk_boundaries_are_explicit(self):
  converse=self.source.split('static func converse(',1)[1].split('static func spot(',1)[0]
  self.assertIn('var failurePhase = ConversationFailureDiagnostic.Phase.prepareContext',converse)
  self.assertLess(converse.index('failurePhase = .generateReply'),converse.index('let stream = session.streamResponse'))
  self.assertIn('#if BLIND_FOUNDATION_MODELS_V2 || BLIND_APPLE_MULTIMODAL\n        if #available(iOS 27.0, *)',self.diagnostic)
  self.assertIn('v2Handling=\\(Self.v2HandlingCompiled)',self.diagnostic)
 def test_existing_nil_model_assertions_include_safe_diagnostic_not_fallback(self):
  lines=[line for line in self.tests.splitlines() if 'MODEL_FIXTURE' in line]
  self.assertEqual(len(lines),7)
  for line in lines:
   self.assertIn('#require(',line)
   self.assertIn('.text,',line)
   self.assertIn('.conversationFailureDiagnostic?.receipt ?? "none"',line)
   self.assertNotIn('conversationOperationalFallback',line)
if __name__=='__main__':unittest.main()
