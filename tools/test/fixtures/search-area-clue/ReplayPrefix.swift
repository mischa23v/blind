import Foundation
import BlindCore

// Platform collaborators only. Production ingress, response selection, source
// recording and clue adapters are appended verbatim by the test generator.
final class SearchAreaReplay {
    struct Feedback { func stopInformation(announceCancellation: Bool) -> Bool { true }
        func interruptAmbient() {} }
    struct Photo { var selection: Int? = nil }
    struct Detection { var hazard: Hazard = .stopped }
    struct Indoor { var alignmentRevision = UUID()
        func cancelRoute() {}
        func invalidatePosition() {} }
    struct Journey { func cancel(origin: CompanionCommandOrigin) throws {}
        func hold(origin: CompanionCommandOrigin) throws {}
        func resume(origin: CompanionCommandOrigin) throws {}
        func eraseHistory(origin: CompanionCommandOrigin) throws {} }
    struct Journeys { func withConnectedJourney(_ action: (Journey) throws -> Void) rethrows { try action(Journey()) } }
    struct Room { var name: String? }
    struct CompanionMemory { var rooms: [String: Room] = [:] }
    struct Companion { var pendingOffer: Int? = nil; var currentRoom: String?; var memory = CompanionMemory() }
    enum MemoryError: Error { case missing }
    final class Memory {
        var saves: [Data] = []
        func saveValue(namespace: String, id: String, payload: Data) throws { saves.append(payload) }
    }
    struct Places { var memory: Memory? = Memory() }
    final class NativeObservations {
        var pending: ((Bool) -> Void)?
        func clearHistory(memory: Memory?, completion: @escaping (Bool) -> Void) { pending = completion }
        func finish(_ success: Bool) { let callback = pending; pending = nil; callback?(success) }
    }
    final class Appearance {
        var forgotten: [String] = []
        func forget(_ key: String) -> Bool { forgotten.append(key); return true }
    }
    struct Changes { func send() {} }
    struct Voice { func endManualTurn() {} }
    struct Tracked { var query: String }
    enum Detail { case minimal, balanced, detailed }
    struct Interrupted {
        mutating func capture(search: ObjectSearch?, goalRevision: String, generation: UInt64, now: Double) {}
        mutating func cancel() {}
    }
    struct Speech {
        let text: String, request: UUID, generation: UInt64, questionID: UUID?
    }
    var companionWorkingState = CompanionWorkingState()
    var assistantDialogue = AssistantDialogue()
    var assistantSession = AssistantSession()
    var everydayTasks = EverydayTaskCoordinator()
    var everydayTicket: EverydayTaskCoordinator.Ticket?
    var everydayUtterance = ""
    var currencyRetake = CurrencyRetakeSession()
    var interruptedSearch = InterruptedObjectSearch(), heldSearchIntent = HeldSearchIntent()
    var journeyConversationGoal = ""
    var journeyConversationSourceID: String?
    var assistantAudience = AssistantAudience.general
    var objectSearch: ObjectSearch?
    var trackedTarget: Tracked?
    var searchInFlight = false, trackLookInFlight = false
    var itemMemoryRevision = UUID()
    var items = ItemMemory()
    var learningItem: RememberedItem?
    var places = Places(), nativeObservations = NativeObservations(), itemAppearance = Appearance()
    var objectWillChange = Changes(), voice = Voice()
    var pendingScopedReview: Int?, completedScopedReview: Int?
    var scopedReviewError = "", message = ""
    var detail: Detail = .balanced
    var wordsPerMinute = 90
    var removedObservationCategories: [String] = []
    var recordingCompanionTurn = false
    var recordedCompanionSourceID: String?
    var selectedPhoto = Photo(), feedback = Feedback(), detection = Detection(), indoor = Indoor(), journeys = Journeys(), companion = Companion()
    var arabic = false, ambientDescriptions = true, textOnly = true, running = false
    var sceneAnswer = "", currentReply = "", assistantQuestion = "", objectiveDraft = ""
    var requestID = UUID()
    var modelInputs: [String] = [], anonymousInputs: [String] = [], controlInputs: [String] = [], toolInputs: [String] = []
    var pendingSpeech: Speech?
    // Linux replay substitutes word segmentation, not Apple NLTokenizer.
    // Override proves adapter budget rejection before state installation.
    static var wordCountOverride: Int?
    static func wordCount(_ text: String) -> Int {
        wordCountOverride ?? text.split(whereSeparator: { $0.isWhitespace }).count
    }
    var sensorAnswers = false
    init() { assistantSession.start() }
    func clearExploreSnapshot() { selectedPhoto.selection = nil }
    func routeClockInquiry(_ text: String, origin: CompanionCommandOrigin) -> Bool {
        if text.lowercased() == "what time is it" { controlInputs.append(text); return true }; return false
    }
    func receiveUnverifiedConversation(_ text: String, origin: CompanionCommandOrigin) { anonymousInputs.append(text) }
    func routeHistoricalLocationInquiry(_ text: String, origin: CompanionCommandOrigin) -> Bool { false }
    func routeSelectedPhotoInquiry(_ text: String, origin: CompanionCommandOrigin) -> Bool { false }
    func routeConnectedJourneyCommand(_ text: String, origin: CompanionCommandOrigin) -> Bool { false }
    func routeVoiceRoomScan(_ text: String) -> Bool { false }
    func calibrate() {}
    func retryCurrencyCapture(_ pending: CurrencyRetakeSession) { toolInputs.append("currency retry") }
    func muteConversation() { assistantSession.mute() }
    func startConversation() { assistantSession.start() }
    func endConversation() { assistantSession.end() }
    func routeUnavailableTemperature(_ text: String) -> Bool { false }
    func routeShoppingList(_ text: String) -> Bool { false }
    func stopReturn() {}
    func speakRequested(_ text: String) -> Bool { true }
    func persistWorkingState() {}
    func persistItems() {}
    func say(_ text: String) { currentReply = text; sceneAnswer = text }
    func speakOperation(_ text: String) -> Bool { true }
    func repeatDescription() {}
    func resumeHeldSearchIfPossible() {}
    func verifyHeldItem(_ name: String) -> Bool { toolInputs.append("verify " + name); return true }
    func learnItem(_ name: String) { toolInputs.append("learn " + name) }
    func locate(_ target: String, question: String) -> Bool { false }
    func invalidatePerceptionWork() {}
    func removeObservedHistory(category: String) throws { removedObservationCategories.append(category) }
    func persistDialogue() {}
    func routeEverydayTask(_ text: String) -> Bool {
        guard let request = EverydayTaskRequest.route(text) else { return false }
        if request.capability == .findItem {
            if everydayTasks.goal == nil { everydayTasks.setGoal(companionWorkingState.goal) }
            _ = everydayTasks.begin(request); everydayUtterance = text; return false
        }
        toolInputs.append(text); return true
    }
    func answerCompanionOffer(_ answer: OfferAnswer) {}
    func routeSaudiBanknoteCommand(_ text: String) -> Bool { false }
    func routeClothingColorCommand(_ text: String) -> Bool { false }
    func routeReadingToolCommand(_ text: String) -> Bool { false }
    func readScene(cloud: Bool, question: String) { toolInputs.append(question) }
    // Deliberately no invented model reply. This witnesses a boundary invocation,
    // not model-enabled failure or an Apple Foundation Models result.
    func answerConversation(_ text: String) { modelInputs.append(text) }
    func findWithSensors(_ target: String, question: String) -> Bool { sensorAnswers }
    func queueConversationSpeech(_ text: String, request: UUID, generation: UInt64, codeOwned: Bool, searchAreaQuestionID: UUID? = nil) {
        pendingSpeech = Speech(text: text, request: request, generation: generation, questionID: searchAreaQuestionID)
    }
