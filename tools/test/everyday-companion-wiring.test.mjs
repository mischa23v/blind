// Source contracts only. Swift fixtures test coordinator behavior; these checks
// do not prove an Apple build, native callback timing or physical sensor accuracy.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const model = read('ios/BlindAssist/NavigationModel.swift');
function section(source, start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `${start} -> ${end}`);
  return source.slice(a, b);
}

test('explicit everyday requests route before generic visual conversation', () => {
  const receive = section(model, 'func receiveCompanionUtterance(', 'private func routeEverydayTask(');
  assert.match(receive, /if routeEverydayTask\(text\) \{ return \}/);
  assert.ok(receive.indexOf('routeEverydayTask(text)') < receive.indexOf('answerConversation(text)'));
  assert.ok(receive.indexOf('routeShoppingList(text)') < receive.indexOf('routeEverydayTask(text)'));
  assert.match(receive, /case \.visualRequest = ConversationIntent\.classify\(text\)[\s\S]*readScene\(cloud: false, question: text\)[\s\S]*else \{\s*answerConversation\(text\)/);
});

test('ordinary chat does not dispatch an everyday adapter or require a camera', () => {
  const route = section(model, 'private func routeEverydayTask(', 'private func finishEverydayTask(');
  assert.ok(route.indexOf('guard let request = EverydayTaskRequest.route(text) else { return false }') < route.indexOf('everydayTasks.begin(request)'));
  assert.doesNotMatch(route, /LocalImageAssistant|LanguageModelSession|readScene\(|startCameraMonitoring\(/);
  const core = read('BlindCore/Sources/BlindCore/EverydayTaskCoordinator.swift');
  assert.match(core, /public static func route\(_ text: String\)/);
  assert.match(core, /ReadingToolCommand\.parse\(text\)/);
  assert.match(core, /ClothingColorCommand\.matches\(text\)/);
  assert.match(core, /ConversationDomainPolicy\.requiredInspection\(for: text\) == \.banknote/);
  assert.doesNotMatch(core, /SaudiBanknoteCommand\.matches\(text\)/);
});

test('domain selection reuses identity money and reading adapters rather than generated claims', () => {
  const route = section(model, 'private func routeEverydayTask(', 'private func finishEverydayTask(');
  for (const call of ['startReadingTool(.liveText)', 'startReadingTool(.document)', 'startReadingTool(.barcode)', 'startReadingTool(.light)', 'routeSaudiBanknoteCommand(text)', 'routeClothingColorCommand(text)', 'routeFamiliarPeopleCommand(text)', 'CompanionClock.read(']) {
    assert.ok(route.includes(call), call);
  }
  assert.match(route, /#if BLIND_FAMILIAR_PEOPLE/);
  assert.doesNotMatch(route, /\.enroll\(|\.remember\(|navigate\(|answer\.action|worldPoint\(/);
});

test('item tasks consult attributed memory before continuing existing live handlers', () => {
  const route = section(model, 'private func routeEverydayTask(', 'private func finishEverydayTask(');
  assert.match(route, /ticket\.request\.capability == \.savedMemory/);
  assert.match(route, /readSavedCompanionMemory\(query: ticket\.request\.query\)/);
  assert.match(route, /memory\.evidence\.isEmpty \? \.unavailable : \.historicalClue/);
  assert.match(route, /case \.findItem:[\s\S]*return false/);
  const core = read('BlindCore/Sources/BlindCore/EverydayTaskCoordinator.swift');
  assert.match(core, /next\.capability == \.findItem[\s\S]*capability: \.savedMemory, query: next\.query/);
});

test('saved evidence includes observations gallery places and attributed checklist without mutations', () => {
  const saved = section(model, 'private func readSavedCompanionMemory(', '@MainActor private func readCompanionTool(');
  for (const fragment of ['assistantDialogue.relevantUserReports', 'observed: observedObjects', 'savedItems: items.items', 'places: savedPlaces', 'preferences: preferences', 'taskContext: taskNotes', 'shoppingList.entries', '$0.element.sourceQuote', '$0.element.recordedAt']) assert.ok(saved.includes(fragment), fragment);
  assert.match(saved, /user-requested task, not completed action/);
  assert.match(saved, /explicit shopping-list request, not a purchase/);
  assert.doesNotMatch(saved, /saveValue\(|startReadingTool\(|\.enroll\(|changeGoal\(|navigate\(/);
});

test('model evidence tool remains read only with no shopping or task mutation capability', () => {
  const local = read('ios/BlindAssist/LocalImageAssistant.swift');
  assert.match(local, /CompanionToolKind\(rawValue: arguments\.capability\)/);
  assert.match(local, /runtime\.run\(CompanionToolRequest/);
  assert.doesNotMatch(local, /EverydayShoppingList|routeShoppingList|shoppingList\.apply|everydayTasks\.begin/);
  const core = read('BlindCore/Sources/BlindCore/CompanionEvidence.swift');
  const kinds = section(core, 'public enum CompanionToolKind', 'public struct CompanionToolRequest');
  assert.doesNotMatch(kinds, /shopping|purchase|enroll|writeMemory/);
});

test('shopping mutations persist validated explicit quotes before reporting success', () => {
  const shopping = section(model, 'private func routeShoppingList(', 'private func handleConversationTaskControl(');
  assert.match(shopping, /EverydayShoppingCommand\.parse\(text\)/);
  assert.match(shopping, /updated\.apply\(command, userQuote: text, now: Date\(\)\.timeIntervalSince1970\)/);
  assert.ok(shopping.indexOf('try memory.saveValue') < shopping.indexOf('shoppingList = updated'));
  assert.match(shopping, /namespace: "companion", id: "shopping-list"/);
  assert.match(model, /JSONDecoder\(\)\.decode\(EverydayShoppingList\.self, from: data\)/);
  assert.doesNotMatch(shopping, /LocalImageAssistant|LanguageModelSession/);
});

test('coordinator admission checks exact in-flight ticket and generation before accepting results', () => {
  const core = read('BlindCore/Sources/BlindCore/EverydayTaskCoordinator.swift');
  const receive = section(core, 'public mutating func receive(', 'public mutating func admitPrompt(');
  assert.match(receive, /inFlight == ticket, ticket\.generation == generation/);
  assert.match(receive, /now - ticket\.issuedAt < Self\.attemptLifetime/);
  const completion = section(model, 'private func finishEverydayTask(', 'private func routeShoppingList(');
  assert.match(completion, /ticket\.id == ticketID, ticket\.request\.capability == capability/);
  assert.match(completion, /everydayTasks\.receive\(ticket, outcome: outcome/);
  const controls = section(model, 'private func handleConversationTaskControl(', 'private func queueConversationSpeech(');
  assert.match(controls, /everydayTasks\.cancelAll\(\); everydayTicket = nil/);
  assert.match(controls, /everydayTasks\.pause\(\); everydayTicket = nil/);
});

test('clock and list replies update text-only conversation surface', () => {
  const route = section(model, 'private func routeEverydayTask(', 'private func finishEverydayTask(');
  assert.match(route, /deliverConversationReply\(value\.text\)/);
  const shopping = section(model, 'private func routeShoppingList(', 'private func handleConversationTaskControl(');
  assert.match(shopping, /deliverConversationReply\(names\.isEmpty/);
});

test('single shot retries require the same task and request and fresh idle capture', () => {
  const finish = section(model, 'private func finishEverydayTask(', 'private func routeShoppingList(');
  assert.match(finish, /ticket\.id == ticketID/);
  assert.match(finish, /everydayTasks\.attempts < EverydayTaskCoordinator\.maximumAttemptsPerAdapter/);
  assert.match(finish, /capability == \.currency \|\| capability == \.clothingColor/);
  assert.match(finish, /everydayRetryRequestID == requestID/);
  assert.match(finish, /!voice\.awaitingUtterance && feedback\.canSpeakAmbient/);
  assert.match(finish, /takeIfReady\(ticketID: everydayRetryTicketID/);
  assert.match(finish, /else if !everydayRetry\.isPending/);
  const cancel = section(model, 'private func cancelDescription()', 'private func publish()');
  assert.match(cancel, /everydayRetry\.cancel\(\); everydayRetryTicketID = nil/);
  assert.match(model, /self\.tickEverydayRetry\(now: ProcessInfo\.processInfo\.systemUptime\)/);
});

test('physical finds retain the original authority gate and completion is only a user report', () => {
  const physical = section(model, 'private func routeUnverifiedPhysicalRequest(', 'private func routeUnavailableTemperature(');
  assert.match(physical, /EverydayTaskRequest\.route\(question\)\?\.capability == \.findItem, routeEverydayTask\(question\)/);
  assert.match(physical, /findWithSensors\(target, question: question\)/);
  const receive = section(model, 'func receiveCompanionUtterance(', 'private func routeEverydayTask(');
  assert.match(receive, /CompanionEvidenceGuard\.explicitCompletionReport\(text, latest: text\)/);
  assert.match(receive, /everydayTasks\.confirmSubtaskComplete\(\)/);
  assert.match(receive, /you said that step is done/);
});
