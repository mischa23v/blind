"""Portable source contracts only; does not execute Swift, speech, or a recipe."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PATHS = {
 'core': 'BlindCore/Sources/BlindCore/LocalRecipeCompanion.swift',
 'native': 'ios/BlindAssist/NavigationModel.swift',
 'view': 'ios/BlindAssist/LocalRecipeView.swift',
 'dashboard': 'ios/BlindAssist/DashboardView.swift',
 'tests': 'ios/BlindAssistTests/ConversationRuntimeFailureTests.swift',
}

def check(s):
 n, c, v = s['native'], s['core'], s['view']
 required = {
  'core': ['guard origin == .trustedInterface, selection == selected,',
    'selected.generation == generation, enabled || readerControl,',
    'candidate == response && candidate.selection == selection && session != nil &&',
    'candidate.selection.generation == generation && uptime.isFinite &&',
    'uptime - candidate.issuedAt < Self.responseLifetime',
    'let value = Selection(id: UUID(), revision: UUID(), sha256: sha256, generation: generation)',
    'BoundedReferenceChunkPlan.make(text: current.step.text, prefix: prefix,',
    'maximumUTF8Bytes: 4000, phraseWordLimit: 30)',
    'unverified source text: «', 'Timer reading when requested:',
    'This does not establish that food is ready.', 'if command == .forget { clear(); return nil }'],
  'native': ['if routeLocalRecipeCommand(text, origin: origin) { return }',
    'guard origin == .trustedInterface, let command = LocalRecipeCommand.parse(text) else { return false }',
    'recipeImportOwner?.id == owner && recipeImportOwner?.generation == assistantSession.generation &&',
    'guard ownsLocalRecipeSelection(owner) else { return false }',
    'let hash = SHA256.hash(data: data)',
    'if self.recipeSpeechIDs.contains(id)',
    'if self.finishRecipeSpeech(id: id, text: text, outcome: outcome) { return }',
    'selectedDocumentSpeechIDs.contains($0) || recipeSpeechIDs.contains($0)',
    '(self?.recipeSpeechPermission(id: id, text: text) ?? false) &&',
    'playback.response.parts[playback.index].utf8.elementsEqual(text.utf8)',
    'localRecipe.validates(playback.response, generation: assistantSession.generation,',
    'guard valid, outcome == .completed else { retireRecipePlayback(); return true }',
    'if !speakRequested(text, replace: false, speechID: id)',
    'recipeSpeechIDs.remove(id); retireRecipePlayback()',
    'self.recipePlayback?.response.id == owner',
    'retireRecipePlayback() // interruption retires only speech, not source/step/timer',
    'if textOnly {\n            // Private source output is volatile: never dialogue/model context/history.'],
  'view': ['@ObservedObject var model: NavigationModel',
    'private var session: LocalRecipeSession? { model.localRecipe.session }',
    'model.enableLocalRecipeCommands(selected)',
    'guard let owner, model.ownsLocalRecipeSelection(owner) else { return }',
    'model.selectLocalRecipe(data, owner: owner)',
    '.onDisappear { model.localRecipeReaderDisappeared() }'],
  'dashboard': ['LocalRecipeView(model: model)'],
 }
 for key, tokens in required.items():
  for token in tokens:
   assert token in s[key], (key, token)
 for function in ['endConversation', 'muteConversation', 'suspendExperience', 'clearAssistantConversation', 'clearNarrationHistory']:
  assert 'func '+function+'() {\n        clearLocalEmailDraft()\n        clearLocalRecipe()' in n, function
 route = n[n.index('private func routeLocalRecipeCommand'):n.index('private func showRecipeReply')]
 assert route.index('guard origin == .trustedInterface') < route.index('interruptOrdinaryConversation')
 assert 'toolExecutor' not in route and 'LocalImageAssistant' not in route
 extension = n[n.index('// MARK: - Explicitly selected recipe ->'):n.index('// MARK: - Private user-authored email draft,')]
 for forbidden in ['persistDialogue', 'persistWorkingState', 'assistantDialogue.record', 'enqueueNarration', 'URLSession', 'UNUserNotification', 'deliverConversationReply(response', 'queueCodeConversationSpeech']:
  assert forbidden not in extension, forbidden
 assert re.search(r'if oldValue.generation != assistantSession.generation \{\s+clearLocalEmailDraft\(\)\s+clearLocalRecipe\(\)', n)
 assert len(re.findall(r'func test', s['tests'][s['tests'].index('final class LocalRecipeCompanionAdapterTests'):])) >= 7
 return sum(map(len, required.values())) + 17

class SourceControls(unittest.TestCase):
 @classmethod
 def setUpClass(cls): cls.s = {key:(ROOT/path).read_text() for key,path in PATHS.items()}
 def test_actual_source_contracts(self): self.assertGreaterEqual(check(self.s), 50)
 def test_authority_generation_private_speech_and_lifecycle_mutations_are_rejected(self):
  mutations = [
   ('core', 'guard origin == .trustedInterface, selection == selected,', 'guard selection == selected,'),
   ('core', 'selected.generation == generation, enabled || readerControl,', 'enabled || readerControl,'),
   ('core', 'candidate == response && candidate.selection == selection && session != nil &&', 'session != nil &&'),
   ('core', 'maximumUTF8Bytes: 4000, phraseWordLimit: 30)', 'maximumUTF8Bytes: 4000, phraseWordLimit: 90)'),
   ('native', 'guard origin == .trustedInterface, let command = LocalRecipeCommand.parse(text)', 'guard let command = LocalRecipeCommand.parse(text)'),
   ('native', 'guard ownsLocalRecipeSelection(owner) else { return false }', '// stale picker admitted'),
   ('native', 'selectedDocumentSpeechIDs.contains($0) || recipeSpeechIDs.contains($0)', 'selectedDocumentSpeechIDs.contains($0)'),
   ('native', '(self?.recipeSpeechPermission(id: id, text: text) ?? false) &&', ''),
   ('native', 'guard valid, outcome == .completed else { retireRecipePlayback(); return true }', 'guard valid else { retireRecipePlayback(); return true }'),
   ('native', 'func endConversation() {\n        clearLocalEmailDraft()\n        clearLocalRecipe()', 'func endConversation() {\n        clearLocalEmailDraft()'),
   ('native', 'func endConversation() {\n        clearLocalEmailDraft()\n        clearLocalRecipe()', 'func endConversation() {\n        clearLocalRecipe()'),
   ('native', 'private func showRecipeReply(_ text: String) {', 'private func showRecipeReply(_ text: String) {\n        assistantDialogue.record(role: "assistant", text: text)'),
   ('view', 'model.enableLocalRecipeCommands(selected)', '/* no explicit source consent */'),
  ]
  for key, old, new in mutations:
   with self.subTest(token=old):
    self.assertIn(old,self.s[key]); damaged=dict(self.s);damaged[key]=damaged[key].replace(old,new)
    with self.assertRaises(AssertionError):check(damaged)

if __name__ == '__main__': unittest.main()
