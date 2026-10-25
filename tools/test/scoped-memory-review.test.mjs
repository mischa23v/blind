// Authored ownership/review scenarios. Executes actual production state, controller
// and UI action bodies, not SwiftUI rendering, real recognition or device accuracy.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync} from 'node:fs';
import {dirname,join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {tmpdir} from 'node:os';
import {spawnSync} from 'node:child_process';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const read=p=>readFileSync(join(root,p),'utf8');
function section(text,start,end){const a=text.indexOf(start);assert.ok(a>=0,start);const b=text.indexOf(end,a);assert.ok(b>a,end);return text.slice(a,b);}
function before(text,first,second){const a=text.indexOf(first),b=text.indexOf(second);assert.ok(a>=0 && b>a,`${first} must precede ${second}`);}
function editorSource(){const editor=read('ios/BlindAssist/DashboardView.swift').split('private struct ScopedConversationRecordEditor: View {')[1];assert.ok(editor);return editor;}
function editorAction(editor,replacement){
 const block=replacement
  ? section(editor,'            Button(t("Save correction",','            if failed')
  : section(editor,'            Button(t("Forget report",','\n        }');
 const task='                Task { @MainActor in\n';
 // Strip only the SwiftUI Task wrapper. The duplicate guard, saving transitions,
 // awaited call, failure handling and dismissal all come from the native action.
 const admission=section(block,'                guard !saving else { return }',task);
 assert.match(admission,/saving = true/);
 const a=block.indexOf(task)+task.length;
 const end='                    saving = false';
 const b=block.indexOf(end,a);assert.ok(b>=a,end);
 const body=block.slice(a,b+end.length);
 assert.ok(body.includes(`if await model.reviseScopedConversationRecord(selection, replacement: ${replacement?'replacement':'nil'}) { dismiss() }`));
 return admission+body;
}

test('scoped review captures an immutable receipt and fences late conversation publication',()=>{
 const nav=read('ios/BlindAssist/NavigationModel.swift'),editor=editorSource();
 assert.match(editor,/@State private var selection: CompanionWorkingState.ReviewSelection/);
 assert.match(editor,/_selection = State\(initialValue: selection\)/);
 assert.doesNotMatch(editor,/onAppear|\bselection\s*=(?!=)/);
 assert.equal((editor.match(/_selection\s*=/g)||[]).length,1);
 assert.equal((nav.match(/self\.conversationMemoryRevision == memoryRevision/g)||[]).length,4);
 const answer=section(nav,'    private func answerConversation(','    func startVoiceQuestion()');
 assert.ok(answer.indexOf('let memoryRevision = conversationMemoryRevision') < answer.indexOf('questionTask = Task'));
 assert.ok(answer.indexOf('self.conversationMemoryRevision == memoryRevision') < answer.indexOf('await LocalImageAssistant.converse'));
 const record=section(nav,'    @discardableResult private func recordCompanionMessage(', '    /// Conversation evidence rule');
 assert.match(record,/let source = companionWorkingState\.reports\.last/);
 assert.match(record,/assistantDialogue\.record\(role: "user", text: question, sourceID: source\?\.sourceID\)/);
 assert.match(record,/if recordingCompanionTurn, let id = recordedCompanionSourceID,/);
 assert.match(record,/\$0\.sourceID == id && \$0\.text == question/);
 const review=section(nav,'    @discardableResult func reviseScopedConversationRecord(','    /// Loss-only ingress.');
 assert.match(review,/async -> Bool/);
 before(review,'revised.reviseReviewedSource(selection, replacement: replacement)','conversationMemoryRevision = UUID()');
 before(review,'interruptOrdinaryConversation(origin: .trustedInterface)','await companionMemoryWriter.waitForCommit(receipt)');
 before(review,'assistantDialogue.forgetBoundSource(selection.sourceID)','await companionMemoryWriter.waitForCommit(receipt)');
});

test('native editor awaits durable success and guards both actions against duplicate submission',()=>{
 const editor=editorSource();
 assert.match(editor,/@State private var saving = false/);
 assert.equal((editor.match(/Task \{ @MainActor in/g)||[]).length,2);
 assert.equal((editor.match(/guard !saving else \{ return \}/g)||[]).length,2);
 assert.equal((editor.match(/\.disabled\(saving\)/g)||[]).length,2);
 for(const replacement of [true,false]){
  const action=editorAction(editor,replacement);
  before(action,'guard !saving else { return }','saving = true');
  before(action,'saving = true','if await model.reviseScopedConversationRecord(');
  before(action,'else { failed = true }','saving = false');
 }
});

test('ordinary and reviewed persistence share a bounded paired writer with store owner fences',()=>{
 const nav=read('ios/BlindAssist/NavigationModel.swift');
 const properties=section(nav,'    @Published var scopedReviewError','    private var conversationSpeech:');
 assert.equal((nav.match(/CompanionMemoryWriteQueue\(\)/g)||[]).length,1);
 assert.match(properties,/receipt\.owner == self\.places\.memory\?\.writeOwner/);
 assert.match(properties,/receipt\.owner == self\.companionMemoryStoreOwner/);
 const persist=section(nav,'    private func admittedCompanionMemoryStore()','    @discardableResult func addAssistantInterest');
 assert.match(persist,/companionMemoryWriter\.bindOwner\(memory\.writeOwner\)/);
 assert.match(persist,/if let owner = companionMemoryStoreOwner, owner != memory\.writeOwner/);
 assert.match(persist,/let state = companionWorkingState, dialogue = assistantDialogue/);
 assert.match(persist,/companionMemoryWriter\.submit\(owner: memory\.writeOwner, encode:/);
 assert.match(persist,/\.init\(dialogue: try JSONEncoder\(\)\.encode\(dialogue\), workingState: try JSONEncoder\(\)\.encode\(state\)\)/);
 assert.match(persist,/try memory\.saveConversationReview\(dialogue: snapshot\.dialogue, workingState: snapshot\.workingState\)/);
 assert.match(persist,/func retryCompanionMemorySave\(\) \{ enqueueCompanionMemorySnapshot\(\) \}/);
 assert.match(persist,/private func persistWorkingState\(\) \{\s*reconcileWorkingStateOwners\(\)\s*enqueueCompanionMemorySnapshot\(\)\s*\}/);
 assert.match(persist,/private func persistDialogue\(\) \{ enqueueCompanionMemorySnapshot\(\) \}/);
 assert.doesNotMatch(persist,/try\?|saveValue\(/);
 const review=section(nav,'    @discardableResult func reviseScopedConversationRecord(','    /// Loss-only ingress.');
 assert.match(review,/pending\.owner == memory\.writeOwner, pending\.selection == selection, pending\.replacement == replacement/);
 assert.match(review,/let receipt = enqueueCompanionMemorySnapshot\(\)/);
 assert.match(review,/guard places\.memory\?\.writeOwner == operation\.owner else \{\s*scopedReviewError = memorySaveError/);
 assert.match(review,/guard pendingScopedReview\?\.id == operation\.id else \{ return false \}/);
 const writer=read('BlindCore/Sources/BlindCore/CompanionMemoryWriteQueue.swift');
 assert.match(writer,/@MainActor public final class CompanionMemoryWriteQueue/);
 assert.match(writer,/private var pending: Job\?/);
 assert.match(writer,/public var pendingCount: Int \{ pending == nil \? 0 : 1 \}/);
 assert.match(writer,/guard !isWriting, pending != nil else/);
 assert.match(writer,/Task\.detached\(priority: \.utility\)/);
 before(writer,'let snapshot = try job.encode()','try job.write(snapshot)');
 assert.match(writer,/maximumDialogueBytes\)\.contains\(snapshot\.dialogue\.count\)/);
 assert.match(writer,/maximumWorkingStateBytes\)\.contains\(snapshot\.workingState\.count\)/);
 assert.match(writer,/guard job\.owner == self\.owner else \{ self\.drain\(\); return \}/);
 assert.match(writer,/guard receipt\.owner == owner else \{ return false \}/);
 const store=read('BlindMemory/Sources/BlindMemory/MemoryStore.swift');
 assert.match(store,/public let writeOwner = UUID\(\)/);
 const pair=section(store,'    public func saveConversationReview(','    public func value(namespace:');
 assert.match(pair,/try database\.write \{ db in/);
 assert.match(pair,/\[\("dialogue", "active", dialogue\), \("companion", "working-state", workingState\)\]/);
 assert.doesNotMatch(pair,/try\?/);
});

test('existing bulk-clear and saved-memory routes expose pending failure and bounded retry status',()=>{
 const dashboard=read('ios/BlindAssist/DashboardView.swift'),saved=read('ios/BlindAssist/SavedMemoryView.swift');
 const status=section(dashboard,'struct ConversationMemoryPersistenceView: View {','struct ConversationMemoryView: View {');
 assert.match(status,/if model\.memorySavePending \{/);
 assert.match(status,/Keep the app open for now\./);
 assert.match(status,/accessibilityIdentifier\("conversation-memory-save-pending"\)/);
 assert.match(status,/if !model\.memorySaveError\.isEmpty \{/);
 assert.match(status,/Text\(model\.memorySaveError\)\.accessibilityIdentifier\("conversation-memory-save-failed"\)/);
 assert.match(status,/Button\([^\n]+\{ model\.retryCompanionMemorySave\(\) \}\s*\.disabled\(model\.memorySavePending\)/);
 for(const route of [section(dashboard,'    private var monitor: some View {','    private var assistant: some View {'),
  section(dashboard,'    private var assistant: some View {','    private var places: some View {'),
  section(dashboard,'struct ConversationMemoryView: View {','private struct ConversationRecordEditor: View {')]){
  assert.match(route,/ConversationMemoryPersistenceView\(model: model\)/);
 }
 const conversation=section(dashboard,'struct ConversationMemoryView: View {','private struct ConversationRecordEditor: View {');
 assert.match(conversation,/model\.clearAssistantConversation\(\)/);
 assert.match(saved,/case \.conversation: model\.clearAssistantConversation\(\)/);
 assert.match(saved,/Section \{ ConversationMemoryPersistenceView\(model: model\) \}/);
});

test('saved-item deletion validates the exact displayed record before retiring work and deletes by stable ID',()=>{
 const nav=read('ios/BlindAssist/NavigationModel.swift');
 const outer=section(nav,'    func forgetItem(_ item: RememberedItem,','    private func forgetItemAfterNativePurge(');
 before(outer,'guard items.items.contains(item) else { completion(false); return }','retireHeldSearchForPrivacyDeletion()');
 before(outer,'guard items.items.contains(item) else { completion(false); return }','nativeObservations.clearHistory(');
 const deletion=section(nav,'    private func forgetItemAfterNativePurge(','    var savedRooms:');
 before(deletion,'guard items.items.contains(item) else { return false }','purgeDebugSessionDiagnostics()');
 before(deletion,'guard items.items.contains(item) else { return false }','invalidatePerceptionWork()');
 before(deletion,'guard updated.forget(id: item.id) else { return false }','try memory.saveValue(');
 assert.doesNotMatch(deletion,/updated\.forget\(item\.name\)/);
});

test('selected-item helper discloses shared legacy derivative purge and shows original identity',()=>{
 const view=read('ios/BlindAssist/SavedMemoryView.swift'),nav=read('ios/BlindAssist/NavigationModel.swift');
 const question=section(view,'    private func question(','    private func itemContext(');
 assert.match(question,/unbound same-name pictures and sightings, and all observed-geometry history/);
 assert.match(question,/Other saved item records stay/);
 assert.match(view,/Text\(itemContext\(item\)\)/);assert.match(view,/scope\.placeID/);assert.match(view,/scope\.floorID/);assert.match(view,/scope\.roomID/);assert.match(view,/scope\.objectInstanceID/);assert.match(view,/scope\.map\.revision/);
 assert.match(view,/case \.item\(let item\): model\.forgetItem\(item\)/);
 assert.match(view,/Button\(t\("Delete", "حذف"\), role: \.destructive\) \{ perform\(value\); pending = nil \}/);
 const handle=section(nav,'    private func handleItemOrLocate(','    /// Saved item (by look');
 assert.match(handle,/case \.forget\(let name\):\s*guard let saved = items\.find\(name\)/);
});

test('actual scoped review state controller and async UI actions preserve source ownership',{
 skip:!process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC for actual extracted Swift replay.',timeout:180_000,
},()=>{
 const work=mkdtempSync(join(process.env.BLIND_TEST_SCRATCH||tmpdir(),'blind-scoped-review-'));
 const sourceDir=join(work,'Sources/NativeReviewReplay'),tests=join(work,'Tests/NativeReviewReplayTests');
 mkdirSync(sourceDir,{recursive:true});mkdirSync(tests,{recursive:true});
 const local=read('ios/BlindAssist/LocalImageAssistant.swift');
 writeFileSync(join(sourceDir,'WorkingState.swift'),'import Foundation\nimport BlindCore\n'+section(local,'struct CompanionTaskUpdate:','\n#if canImport(FoundationModels)'));
 const nav=read('ios/BlindAssist/NavigationModel.swift'),fixture='tools/test/fixtures/scoped-memory-review/';
 // Property declarations and every reviewed/persisted method are native source,
 // including the shared Core writer. Fixtures supply only absent platform seams.
 const properties=section(nav,'    @Published var scopedReviewError','    private var conversationSpeech:').replaceAll('@Published ','');
 const turn=section(nav,'        recordingCompanionTurn = true; recordedCompanionSourceID = nil','        let text = text.trimmingCharacters');
 const explicitGoal=section(nav,'        if let goal = ConversationIntent.explicitTaskGoal(text) {','        if handleItemOrLocate(text)');
 writeFileSync(join(sourceDir,'Controller.swift'),read(fixture+'ControllerPrefix.swift')+properties+
  section(nav,'    var scopedConversationReviews:','    @discardableResult func correctConversationRecord')+
  section(nav,'    private func interruptOrdinaryConversation(','\n    private func unverifiedConversationReply')+
  section(nav,'    func clearAssistantConversation()','    var scopedConversationReviews:')+
  section(nav,'    private func reconcileWorkingStateOwners()','    @discardableResult func addAssistantInterest')+
  section(nav,'    @discardableResult private func recordCompanionMessage(','    /// Conversation evidence rule')+
  '    func commitExplicitGoal(_ text: String) {\n'+turn+explicitGoal+'        recordCompanionMessage(text)\n    }\n}\n');
 const editor=editorSource();
 writeFileSync(join(sourceDir,'UIActions.swift'),read(fixture+'UIActionsPrefix.swift')+' func save() async {\n'+
  editorAction(editor,true)+'\n }\n func delete() async {\n'+editorAction(editor,false)+'\n }\n}\n');
 // Release-branch native saved-item deletion. Only DEBUG diagnostics are
 // excluded; no action implementation is supplied by the authored wrapper.
 const deletion=section(nav,'    func forgetItem(_ item: RememberedItem,','    var savedRooms:')
  .replace(/^[ \t]*#if DEBUG\n[\s\S]*?^[ \t]*#endif\n/gm,'');
 assert.doesNotMatch(deletion,/#if|#endif/,'Unexpected native conditional requires explicit extraction review.');
 writeFileSync(join(sourceDir,'SavedItemDeletion.swift'),read(fixture+'SavedItemDeletionPrefix.swift')+deletion+'\n}\n');
 const itemCases=read(fixture+'SavedItemDeletionTests.swift');
 assert.equal((itemCases.match(/func testSI\d{3}/g)||[]).length,3,'Keep all three separate saved-item deletion regressions.');
 writeFileSync(join(tests,'SavedItemDeletionTests.swift'),itemCases);
 const cases=read(fixture+'ScopedReviewTests.swift');
 assert.equal((cases.match(/func testSR\d{3}/g)||[]).length,23,'Keep all 23 current authored scenarios.');
 writeFileSync(join(tests,'ScopedReviewTests.swift'),cases);
 const bounds=read(fixture+'ScopedRetentionBoundsTests.swift');assert.equal((bounds.match(/func testSR\d{3}/g)||[]).length,4);writeFileSync(join(tests,'ScopedRetentionBoundsTests.swift'),bounds);
 writeFileSync(join(work,'Package.swift'),`// swift-tools-version: 5.9\nimport PackageDescription\nlet package = Package(name: "NativeReviewReplay", dependencies: [.package(path: ${JSON.stringify(join(root,'BlindCore'))})], targets: [.target(name: "NativeReviewReplay", dependencies: [.product(name: "BlindCore", package: "BlindCore")]), .testTarget(name: "NativeReviewReplayTests", dependencies: ["NativeReviewReplay", .product(name: "BlindCore", package: "BlindCore")])])\n`);
 const result=spawnSync(join(dirname(process.env.BLIND_SWIFTC),'swift'),['test','--package-path',work,'--jobs','2'],{encoding:'utf8',timeout:175_000,maxBuffer:8*1024*1024});
 const output=(result.stdout||'')+'\n'+(result.stderr||'');writeFileSync(join(work,'execution.log'),output);
 assert.equal(result.status,0,`Replay failed; retained at ${work}\n${result.error||''}\n${output.slice(-12000)}`);
 assert.match(output,/Executed 30 tests, with 0 failures/);
});
