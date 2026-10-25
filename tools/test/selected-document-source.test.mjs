import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = path => readFile(new URL('../../' + path, import.meta.url), 'utf8');
const section = (s, a, b) => {
  const start = s.indexOf(a); assert.ok(start >= 0, a);
  const end = s.indexOf(b, start + a.length); assert.ok(end > start, b);
  return s.slice(start, end);
};
test('PDF privacy attribution and exact callback routing precede ordinary history handling', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  const dispatch = section(s, 'private func deliverCandidate(', 'private func dispatchText(');
  assert.ok(dispatch.indexOf('selectedDocumentSpeechIDs.contains') < dispatch.indexOf('debugTrace?.event'));
  assert.match(dispatch, /privateReference \? nil : candidate\.text/);
  const callbacks = section(s, 'feedback.requestedSpeechPermission =', 'feedback.onIdle =');
  assert.match(callbacks, /selectedDocumentSpeechPermission\(id: id, text: text\)/);
  assert.match(callbacks, /selectedDocument\.started\(id: id, text: text, context: context\)/);
  assert.ok(callbacks.indexOf('finishSelectedDocumentSpeech(') < callbacks.indexOf('assistantDialogue.record('));
  assert.match(callbacks, /if self\.finishSelectedDocumentSpeech\(id: id, text: text, outcome: outcome\) \{ return \}/);
  const feedback = await read('ios/BlindAssist/Feedback.swift');
  assert.match(feedback, /admitted\.privateReference \? nil : admitted\.text/);
  assert.match(feedback, /currentPrivateReference = admitted\.privateReference/);
  assert.match(feedback, /admitted\.privateReference \? nil : attempt\.text/);
});
test('trusted PDF commands intercept before persisted conversation; source data never enters a model or history', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  const route = section(s, 'func receiveCompanionUtterance(', 'private var clockSample:');
  assert.match(route, /if origin == \.trustedInterface \{\s*if routeSelectedDocumentCommand/);
  assert.ok(route.indexOf('routeSelectedDocumentCommand(') < route.indexOf('routeClockInquiry('));
  assert.ok(route.indexOf('clearSelectedDocument()') < route.indexOf('routeClockInquiry('));
  const document = s.slice(s.indexOf('// MARK: - Explicit, local selected-PDF page quotation'));
  assert.doesNotMatch(document, /assistantDialogue\.record|persistDialogue|persistWorkingState|enqueueNarration|OfflineSummary|UserDefaults|JSONEncoder|debugTrace\?\.event/);
  assert.doesNotMatch(document, /\$0\.localizedDescription|error\.localizedDescription|url\.lastPathComponent/);
  assert.match(document, /guard origin == \.trustedInterface else \{ return false \}/);
  assert.match(document, /selectedDocumentSpeechIDs\.insert\(phrase\.id\)[\s\S]*dispatchText\(phrase\.text/);
});
test('parsed trusted PDF requests retire prior ordinary captured and photo sources even on invalid or missing pages', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  const route = section(s, 'private func routeSelectedDocumentCommand(', 'func selectedDocumentPickerCancelled(');
  const parser = route.indexOf('guard let command = SelectedDocumentCommand.parse(text) else { return false }');
  const allowed = route.indexOf('guard selectedDocumentAllowed');
  assert.ok(parser >= 0 && allowed > parser);
  assert.ok(route.indexOf('guard origin == .trustedInterface') < parser);
  assert.ok(route.indexOf('repeatSelectedDocumentGuidance(); return true') < parser);
  for (const cleanup of ['interruptOrdinaryConversation(origin: origin)', 'purgeCapturedTextPlayback()', 'clearExploreSnapshot()']) {
    const at = route.indexOf(cleanup, parser);
    assert.ok(at > parser && at < allowed, cleanup);
  }
  assert.doesNotMatch(route, /cancelDescription\(|setGoal\(|cancelRoute\(|stopReturn\(/);
});
test('PDF native lease release is actual-return only and acquisition cannot renew original read time', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  const clear = section(s, 'private func clearSelectedDocument()', 'private func routeSelectedDocumentCommand(');
  assert.doesNotMatch(clear, /selectedDocumentNativeLease = nil/);
  assert.ok(clear.indexOf('selectedDocument.clear()') < clear.indexOf('feedback.stopRequestedSpeech('));
  const page = section(s, 'private func beginSelectedDocumentPage(', 'private func failSelectedDocument(');
  assert.ok(page.indexOf('Task.detached') < page.indexOf('selectedDocumentNativeLease = nil'));
  assert.match(page, /scheduleSelectedDocumentAcquisitionExpiry\(ownerID: request\.id, issuedAt: request\.issuedAt\)/);
  assert.match(page, /for: request,[\s\S]*now: ProcessInfo\.processInfo\.systemUptime/);
  const wake = section(s, 'private func scheduleSelectedDocumentBudgetWake(', 'private func speakNextSelectedDocumentPhrase(');
  assert.match(wake, /selectedDocument\.request\?\.id == ownerID/);
  assert.doesNotMatch(wake, /\.finish\(|while /);
});
test('PDF attention is acquisition/playback only and independent hazards retain their gate', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(s, /selectedDocumentImportOwner != nil \|\| selectedDocument\.ownsAttention/);
  assert.match(s, /if ambientDescriptions, !documentAttentionOwned/);
  assert.match(s, /if automatic, documentAttentionOwned \{ return \}/);
  assert.match(s, /focusedTaskActive: [^\n,]+ \|\| documentAttentionOwned,/);
  const dispatch = section(s, 'private func deliverCandidate(', 'private func dispatchText(');
  assert.match(dispatch, /let independentAlert = alert != nil && \(candidate\.kind == \.hazard \|\| candidate\.kind == \.mobility\)/);
  assert.match(dispatch, /if candidate\.kind == \.hazard \{\s*clearSelectedDocument\(\)/);
});
test('session changes clear PDF ownership and invalid pages retire only valid page ownership', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  const session = section(s, '@Published private(set) var assistantSession =', '@Published var backgroundConversation');
  assert.match(session, /if oldValue\.generation != assistantSession\.generation \{ clearSelectedDocument\(\) \}/);
  const document = s.slice(s.indexOf('// MARK: - Explicit, local selected-PDF page quotation'));
  assert.match(document, /case \.invalidPage:\s*if retireSelectedDocumentPage\(\), let count = selectedDocument\.selection\?\.pageCount/);
  assert.match(document, /guard \(1\.\.\.selection\.pageCount\)\.contains\(number\) else \{[\s\S]*?retireSelectedDocumentPage\(\)[\s\S]*?selectedDocumentNotice/);
});
test('document display clearing is revision-owned and page retirement retains only a valid selection', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(s, /var currentReply = "" \{ didSet \{ currentReplyRevision = UUID\(\) \} \}/);
  assert.match(s, /var sceneAnswer = "" \{ didSet \{ sceneAnswerRevision = UUID\(\) \} \}/);
  const clear = section(s, 'private func clearSelectedDocumentDisplay()', 'private func retireSelectedDocumentPage()');
  assert.match(clear, /currentReplyRevision == revisions\.reply, currentReply == display/);
  assert.match(clear, /sceneAnswerRevision == revisions\.scene, sceneAnswer == display/);
  const retire = section(s, 'private func retireSelectedDocumentPage()', 'private func routeSelectedDocumentCommand(');
  assert.match(retire, /guard selectedDocumentAllowed, let selection = selectedDocument\.selection/);
  assert.match(retire, /selection\.generation == assistantSession\.generation, selectedPDF != nil/);
  assert.ok(retire.indexOf('selectedDocument.retirePage(') < retire.indexOf('feedback.stopRequestedSpeech('));
  assert.doesNotMatch(retire, /selectedPDF = nil|selectedDocumentNativeLease = nil/);
  const notice = section(s, 'private func selectedDocumentNotice(', 'private func clearSelectedDocument()');
  assert.match(notice, /dispatchText\(text, kind: \.answer, requested: true, replace: false, speechID: UUID\(\)\)/);
  assert.doesNotMatch(notice, /speakRequested\(|selectedDocumentSpeechIDs\.insert/);
});
test('timer, idle and validation expire page acquisition before generic withdrawal can clear a valid source', async () => {
  const s = await read('ios/BlindAssist/NavigationModel.swift');
  for (const [a, b] of [
    ['private func revalidateSelectedDocumentOwnership()', 'private func expireSelectedDocumentAcquisition('],
    ['private func speakNextSelectedDocumentPhrase()', 'private func selectedDocumentSpeechPermission(']
  ]) {
    const body = section(s, a, b);
    assert.match(body, /selectedDocument\.awaitingAcquisition/);
    assert.match(body, /request\.issuedAt >= SelectedDocumentReference\.acquisitionLifetime/);
    assert.ok(body.indexOf('expireSelectedDocumentAcquisition(') < body.indexOf('selectedDocument.revalidate('));
  }
  const expiry = section(s, 'private func expireSelectedDocumentAcquisition(', 'private func scheduleSelectedDocumentAcquisitionExpiry(');
  assert.match(expiry, /selectedDocumentImportOwner\?\.id == ownerID/);
  assert.match(expiry, /request\.id == ownerID, selectedDocument\.awaitingAcquisition/);
  assert.match(expiry, /if retireSelectedDocumentPage\(\)/);
});
test('existing helper controls expose explicit one-page PDF actions with delegate-owned picker dismissal', async () => {
  const s = await read('ios/BlindAssist/DashboardView.swift');
  const controls = section(s, 'private struct CompanionControlsView:', 'private struct HomeAction:');
  for (const hook of ['action: model.chooseSelectedDocument', 'model.readSelectedDocumentPage(pdfPage)', 'action: model.forgetSelectedDocument']) {
    assert.ok(controls.includes(hook), hook);
  }
  assert.match(controls, /value: \$pdfPage, in: 1\.\.\.count/);
  assert.match(controls, /onChange\(of: model\.selectedDocumentPageCount\) \{ _, _ in pdfPage = 1 \}/);
  const picker = section(s, '.sheet(item: $model.selectedDocumentPickerRequest)', '.onAppear { relayToken');
  assert.match(picker, /SelectedDocumentPicker\(ownerID: owner\.id/);
  assert.match(picker, /onPicked: \{ id, url in model\.selectedDocumentPickerPicked\(id, url: url\) \}/);
  assert.match(picker, /onCancelled: model\.selectedDocumentPickerCancelled/);
  assert.match(picker, /\.interactiveDismissDisabled\(\)/);
  assert.doesNotMatch(picker, /onDismiss|onDisappear|Task\.sleep|NavigationStack|fileImporter/);
  assert.doesNotMatch(s, /struct (?:SelectedDocument|PDF)(?:Page|Reader|Screen)View/);
});
test('typed submission consumes pending input once after writing dismissal and validates session before opening PDF picker', async () => {
  const s = await read('ios/BlindAssist/DashboardView.swift');
  const dismiss = section(s, '.sheet(isPresented: $writing, onDismiss:', 'NavigationStack {');
  assert.ok(dismiss.indexOf('pendingTypedSubmission = nil') < dismiss.indexOf('model.receiveCompanionUtterance(pending.text)'));
  assert.match(dismiss, /guard model\.assistantSession\.foregroundActive,/);
  assert.match(dismiss, /model\.assistantSession\.generation == pending\.generation else \{ return \}/);
  const send = section(s, 'Button(t("Send",', '.disabled(typedMessage');
  assert.match(send, /guard case nil = pendingTypedSubmission else \{ return \}/);
  assert.match(send, /pendingTypedSubmission = \(typedMessage, model\.assistantSession\.generation\)/);
  assert.match(send, /writing = false/);
  assert.doesNotMatch(send, /receiveCompanionUtterance|Task\.sleep|asyncAfter/);
});
test('generator and checked project retain actual native adapter picker and PDF byte tests', async () => {
  const generator = await read('tools/generate-xcode-project.mjs');
  const project = await read('ios/BlindAssist.xcodeproj/project.pbxproj');
  assert.ok(generator.includes('SelectedDocumentPDFTests.swift'));
  for (const name of ['SelectedDocumentPDFAdapter.swift', 'SelectedDocumentPicker.swift', 'SelectedDocumentPDFTests.swift']) {
    assert.ok(project.includes(name), name);
  }
});
