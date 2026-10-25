// Authored platform/storage stubs only; production review and persistence bodies are extracted at execution.
import Foundation
import BlindCore
// Saved-place metadata seam for the adjacent extracted historicalReports method.
struct SavedPlace { let id: UUID }
final class MemoryStore: @unchecked Sendable {
 let writeOwner = UUID()
 private let lock = NSLock()
 let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
 private var block = false
 func configureBlock() { lock.lock(); block = true; lock.unlock() }
 private var fail = false
 private var count = 0
 private var savedDialogue: Data?, savedState: Data?
 func configureFailure(_ value: Bool) { lock.lock(); fail = value; lock.unlock() }
 var writeCount: Int { lock.lock(); defer { lock.unlock() }; return count }
 func snapshots() -> (Data?, Data?) { lock.lock(); defer { lock.unlock() }; return (savedDialogue, savedState) }
 func saveConversationReview(dialogue: Data, workingState: Data) throws {
  lock.lock(); let blocked = block; block = false; let failing = fail; lock.unlock()
  if blocked { started.signal(); guard release.wait(timeout: .now() + 5) == .success else { throw CocoaError(.fileWriteUnknown) } }
  if failing { throw CocoaError(.fileWriteUnknown) }
  lock.lock(); savedDialogue = dialogue; savedState = workingState; count += 1; lock.unlock()
 }
}
final class ExtractedScopedReviewController: NSObject {
 struct Places { var memory: MemoryStore? = MemoryStore() }; var places = Places()
 var arabic = false
 var companionWorkingState = CompanionWorkingState()
 var assistantDialogue = AssistantDialogue()
 var unverifiedConversationID = UUID()
 var unverifiedConversationTask: Task<Void, Never>?
 var unverifiedConversationTimeout: Task<Void, Never>?
 var questionTask: Task<Void, Never>?
 var questionTimeoutTask: Task<Void, Never>?
 var questionIsChat = false
 var busy = false
 var streamedConversationText = ""
 struct Speech { let id = UUID() }
 var conversationSpeech: [Speech] = []
 var activeConversationSpeech: Speech?
 final class Feedback { var stopped: [UUID] = []; func stopRequestedSpeech(_ id: UUID) { stopped.append(id) }; func stopInformation(announceCancellation: Bool) -> Bool { true } }
 let feedback = Feedback()
 var sceneAnswer = "", currentReply = "", assistantQuestion = "", objectiveDraft = ""
 var privacyPurges = 0, searchRetirements = 0, journeyRetirements = 0
 var persisted: Int { places.memory?.writeCount ?? 0 }
 var requestID = UUID()
 var testMemoryRevision: UUID { conversationMemoryRevision }
 var unverifiedDialogue = AssistantDialogue()
 var unverifiedDialogueGeneration: UInt64?
 struct Tasks { func cancelAll() {}; func setGoal(_ text: String) {} }; let everydayTasks = Tasks()
 var everydayTicket: String?, everydayUtterance = ""
 struct Journey { func eraseHistory(origin: CompanionCommandOrigin) throws {}; func cancel(origin: CompanionCommandOrigin) throws {} }
 struct Journeys { func withConnectedJourney(_ body: (Journey) throws -> Void) rethrows { try body(Journey()) } }; let journeys = Journeys()
 struct Indoor { func cancelRoute() {} }; let indoor = Indoor()
 struct Output { func revalidate() {} }; let spatialRouteOutput = Output()
 var journeyConversationGoal = "", journeyConversationSourceID: String?, plannedIndoorGoalRevision: String?
 func appendCurrentReport(_ text: String) { recordCompanionMessage(text) }
 func clearExploreSnapshot() {}
 func clearBoardingReading() {} // No boarding source in this scoped-memory platform fixture.
 func stopReturn() {}
 func cancelDescription() { interruptOrdinaryConversation(origin: .trustedInterface); requestID = UUID(); questionTask?.cancel(); questionTask = nil; busy = false }
 func purgeDebugSessionDiagnostics() { privacyPurges += 1 }
 func retireHeldSearchForPrivacyDeletion() { searchRetirements += 1 }
 func establishedJourneyContextChanged() { journeyRetirements += 1 }
 @MainActor func waitForAllMemorySaves() async -> Bool {
  guard let memory = places.memory, let receipt = companionMemoryWriter.retryLatest(owner: memory.writeOwner) else { return false }
  return await companionMemoryWriter.waitForCommit(receipt)
 }
