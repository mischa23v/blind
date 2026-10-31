"""Portable source contracts, not Swift/runtime/Mail/speech acceptance."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]
PATHS = {
 'core':'BlindCore/Sources/BlindCore/LocalEmailDraft.swift',
 'native':'ios/BlindAssist/NavigationModel.swift',
 'view':'ios/BlindAssist/LocalEmailDraftView.swift',
 'dashboard':'ios/BlindAssist/DashboardView.swift',
 'voice':'ios/BlindAssist/VoiceInput.swift',
 'tests':'ios/BlindAssistTests/ConversationRuntimeFailureTests.swift',
 'core_tests':'BlindCore/Tests/BlindCoreTests/LocalEmailDraftTests.swift',
}

def between(s, a, b):
 return s[s.index(a):s.index(b,s.index(a)+len(a))]

def check(s):
 c,n,v,d,voice=(s[k] for k in ['core','native','view','dashboard','voice'])
 required={
 'core':[
 'isPrivateInput(raw) ? nil : raw',
 'text.contains("email draft") || text.contains("مسودة البريد")',
 'raw.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars',
 'return make(literal) // preserve case, punctuation and literal content',
 'public static let maximumBodyBytes = 32 * 1024', 'public static let maximumCheckpoints = 5\n',
 'public static let responseLifetime: Double = 60',
 'snapshot == expected && expected.generation == generation',
 'guard origin == .trustedInterface, owns(expected, generation: generation), handoff == nil',
 'guard origin == .trustedInterface, commandsEnabled, owns(expected, generation: generation),',
 'snapshot = Snapshot(id: expected.id, revision: UUID(), generation: expected.generation, content: content)',
 'response = nil; review = nil', 'public mutating func clear() { self = Self() }',
 'guard value.utf8.count <= limit,', 'history.removeFirst(history.count - Self.maximumCheckpoints)',
 'guard ownsHandoff(expected, generation: generation) else { return false }',
 'handoff == expected && owns(expected.snapshot, generation: generation)',
 'handoff == nil, expected.content.permitsMailReview else { return nil }',
 'guard let review, review.revision == expected.revision else { return nil }',
 'maximumUTF8Bytes: Self.maximumBodyBytes, phraseWordLimit: 30)',
 'parts.allSatisfy({ $0.attributed.utf8.count <= 4000 })',
 'value == response && owns(value.snapshot, generation: generation) && handoff == nil &&',
 'uptime - value.issuedAt < Self.responseLifetime',
 ],
 'native':[
 'let privateDraftInput = text', 'routePrivateEmailDraftInput(privateDraftInput, origin: origin)',
 'let origin: CompanionCommandOrigin = fromVoice ? .unverifiedMicrophone : .trustedInterface',
 'if LocalEmailDraftCommand.isPrivateInput(question) {', 'if assistantQuestion == question { assistantQuestion = "" }',
 'Private draft commands require typed controls.',
 'guard localEmailDraft.commandsEnabled, let expected = localEmailDraft.snapshot else {',
 'localEmailDraft.owns(expected, generation: assistantSession.generation) else { return }',
 'let combined = expected.content.body.isEmpty ? literal : expected.content.body + "\\n\\n" + literal',
 'case .handoff: requestLocalEmailMailReview(expected: expected); return',
 'assistantSession.foregroundActive && localEmailDraft.ownsHandoff(handoff, generation: assistantSession.generation)',
 'guard let handoff = localEmailDraft.handoff, handoff.id == id,',
 'Delivery and receipt are not confirmed.',
 'if self.finishEmailSpeech(id: id, text: text, outcome: outcome) { return }',
 '(self?.emailSpeechPermission(id: id, text: text) ?? false) &&',
 'recipeSpeechIDs.contains($0) || emailSpeechIDs.contains($0)',
 'response.text.utf8.elementsEqual(text.utf8) else { return false }',
 'localEmailDraft.validates(response, generation: assistantSession.generation,',
 'LocalEmailDraft.responseLifetime - (ProcessInfo.processInfo.systemUptime - response.issuedAt)',
 'if textOnly { showLocalEmailReply(response.text); return }',
 'guard emailSpeechID == id else { return true } // retired callback remains private',
 'return true // never pass private text to dialogue, task completion or logging',
 'if !localEmailDraft.commandsEnabled && localEmailDraft.handoff == nil { clearLocalEmailDraft() }',
 'emailSpeechID = nil; emailSpeechResponse = nil; localEmailDraft.retireResponse()',
 'if currentReplyRevision == revisions.reply, currentReply == display { currentReply = "" }',
 'if sceneAnswerRevision == revisions.scene, sceneAnswer == display { sceneAnswer = "" }',
 ],
 'view':[
 '@ObservedObject var model: NavigationModel',
 'guard model.localEmailDraft.snapshot == expected else { return "" }',
 'model.editLocalEmailField(field, text: $0, expected: expected)',
 'model.checkpointLocalEmailDraft(expected: draft)', 'model.undoLocalEmailDraft(expected: draft)',
 'model.enableLocalEmailCommands(draft)', 'model.requestLocalEmailMailReview(expected: draft)',
 'model.discardLocalEmailDraft(expected: draft)',
 'guard isCurrent() else { return controller }',
 'controller.setToRecipients([draft.snapshot.content.recipient])',
 'controller.setSubject(draft.snapshot.content.subject)',
 'controller.setMessageBody(draft.snapshot.content.body, isHTML: false)',
 'guard !completed else { return }; completed = true',
 'case .sent: finish(id, .queued)',
 '.onDisappear { model.localEmailReaderDisappeared(owner: owner) }',
 'if phase != .active { model.clearLocalEmailDraft() }',
 ],
 'dashboard':['LocalEmailDraftView(model: model)',
 '.sheet(item: Binding(get: { model.localEmailDraft.handoff }, set: { _ in }))',
 'isCurrent: { model.ownsLocalEmailHandoff(draft) }', '.interactiveDismissDisabled()'],
 'voice':['let isOwnSpeechEcho = shouldIgnore?(utterance.text) == true',
 'let text = utterance.deliverable(isEcho: isOwnSpeechEcho)',
 'text: isOwnSpeechEcho ? nil : LocalEmailDraftCommand.diagnosticText(utterance.text)'],
 }
 for key,tokens in required.items():
  for token in tokens:assert token in s[key],(key,token)
 ingress=between(n,'func receiveCompanionUtterance(', '// This compatibility entry point')
 assert 'if LocalEmailDraftCommand.isPrivateInput(text)' in ingress
 assert ingress.index('if LocalEmailDraftCommand.isPrivateInput(text)') < ingress.index('debugTrace?.event')
 assert 'return // private namespace never enters diagnostics, dialogue, or model fallback' in ingress
 scene=between(n,'func readScene(', 'if automatic, contextualTask')
 assert 'if LocalEmailDraftCommand.isPrivateInput(question)' in scene and 'return\n        }' in scene
 assert 'routePrivateEmailDraftInput' not in scene and 'debugTrace' not in scene
 asr=between(voice,'func finish()', '/// Scene operations')
 assert asr.index('LocalEmailDraftCommand.diagnosticText') < asr.index('onFinished?(completed)')
 route=between(n,'private func routePrivateEmailDraftInput(', 'private func showLocalEmailReply(')
 assert 'guard origin == .trustedInterface' in route
 assert route.index('guard origin == .trustedInterface') < route.index('LocalEmailDraftCommand.parse')
 assert 'LocalImageAssistant' not in route and 'toolExecutor' not in route
 private=between(n,'// MARK: - Private user-authored email draft,', '#if DEBUG\nextension NavigationModel')
 for token in ['assistantDialogue.record', 'persistDialogue', 'persistWorkingState', 'enqueueNarration', 'URLSession', 'deliverConversationReply(response.text)', 'queueCodeConversationSpeech', 'requestJSON', 'UserDefaults']:
  assert token not in private,token
 for method in ['endConversation','muteConversation','suspendExperience','clearAssistantConversation','clearNarrationHistory']:
  assert 'func '+method+'() {\n        clearLocalEmailDraft()\n        clearLocalRecipe()' in n,method
 assert re.search(r'if oldValue.generation != assistantSession.generation \{\s+clearLocalEmailDraft\(\)',n)
 assert v.index('guard isCurrent()') < v.index('controller.setToRecipients')
 for token in ['@State private var recipient','@State private var message','ReviewedEmailDraft']:
  assert token not in v,token
 for token in ['URLSession','EventKit','MFMessageComposeViewController','mailto:', 'case send', 'Codable']:
  # The explanatory intentional-not-Codable comment is allowed, not conformance.
  assert token not in (c.replace('intentionally not Codable','volatile')+v+private),token
 assert len(re.findall(r'func test',s['core_tests'])) == 11
 assert len(re.findall(r'func test',s['tests'].split('final class LocalEmailCompanionAdapterTests:')[1])) == 11
 return sum(map(len,required.values())) + 24

class SourceControls(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.s={key:(ROOT/path).read_text() for key,path in PATHS.items()}
 def test_private_command_source_contracts(self):self.assertGreaterEqual(check(self.s),90)
 def test_privacy_authority_ownership_lifecycle_and_handoff_mutants_fail(self):
  mutations=[
   ('core','isPrivateInput(raw) ? nil : raw','raw'),
   ('core','snapshot == expected && expected.generation == generation','snapshot?.id == expected.id'),
   ('core','guard origin == .trustedInterface, commandsEnabled, owns(expected, generation: generation),','guard commandsEnabled, owns(expected, generation: generation),'),
   ('core','public static let maximumCheckpoints = 5\n','public static let maximumCheckpoints = 500'),
   ('core','response = nil; review = nil','response = nil'),
   ('core','uptime - value.issuedAt < Self.responseLifetime','true'),
   ('core','handoff == expected && owns(expected.snapshot, generation: generation)','handoff != nil'),
   ('native','if LocalEmailDraftCommand.isPrivateInput(text) {','if false {'),
   ('native','if LocalEmailDraftCommand.isPrivateInput(question) {','if false {'),
   ('native','guard origin == .trustedInterface else {','guard true else {'),
   ('native','recipeSpeechIDs.contains($0) || emailSpeechIDs.contains($0)','recipeSpeechIDs.contains($0)'),
   ('native','(self?.emailSpeechPermission(id: id, text: text) ?? false) &&',''),
   ('native','if self.finishEmailSpeech(id: id, text: text, outcome: outcome) { return }',''),
   ('native','func endConversation() {\n        clearLocalEmailDraft()','func endConversation() {'),
   ('native','private func showLocalEmailReply(_ text: String) {','private func showLocalEmailReply(_ text: String) {\n        assistantDialogue.record(role: "assistant", text: text)'),
   ('view','guard model.localEmailDraft.snapshot == expected else { return "" }',''),
   ('view','guard isCurrent() else { return controller }',''),
   ('view','model.discardLocalEmailDraft(expected: draft)','model.clearLocalEmailDraft()'),
   ('view','case .sent: finish(id, .queued)','case .sent: finish(id, .saved)'),
   ('voice','text: isOwnSpeechEcho ? nil : LocalEmailDraftCommand.diagnosticText(utterance.text)','text: utterance.text'),
   ('voice','text: isOwnSpeechEcho ? nil : LocalEmailDraftCommand.diagnosticText(utterance.text)','text: LocalEmailDraftCommand.diagnosticText(utterance.text)'),
  ]
  for key,old,new in mutations:
   with self.subTest(token=old):
    self.assertIn(old,self.s[key]);damaged=dict(self.s);damaged[key]=damaged[key].replace(old,new)
    with self.assertRaises(AssertionError):check(damaged)

if __name__=='__main__':unittest.main()
