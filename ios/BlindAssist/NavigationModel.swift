import SwiftUI
import ARKit
import AVFoundation
import CoreImage
import ImageIO
import Combine
import BlindCore
import BlindMemory
import NaturalLanguage
import CoreLocation
import os

/// Only this file can mint a speech admission after the companion gate.
struct AdmittedSpeech {
    let text: String
    let priority: SpeechPriority
    let urgent: Bool
    fileprivate init(_ candidate: InformationCandidate) {
        text = candidate.text; priority = candidate.priority; urgent = candidate.kind == .hazard
    }
}

enum AssistantPerformance {
    // Timing only: never attach scene text, names, map contents or credentials.
    static let signposter = OSSignposter(subsystem: "org.blindassist.mobility", category: "AssistantPerformance")
}

final class NavigationModel: NSObject, ObservableObject, ARSessionDelegate {
    /// Developer chat validation does not start microphones, speech or live sensors.
    let textOnly = ProcessInfo.processInfo.arguments.contains("--text-only") ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private var automaticStartupAllowed = true
    @Published private(set) var assistantSession = AssistantSession()
    @Published var backgroundConversation = UserDefaults.standard.bool(forKey: "background-conversation") {
        didSet {
            UserDefaults.standard.set(backgroundConversation, forKey: "background-conversation")
            assistantSession.setBackgroundAllowed(backgroundConversation)
            voice.setBackgroundAllowed(backgroundConversation)
            if !assistantSession.shouldListen { voice.cancel() }
            cancelDescription()
        }
    }
    // Active assistance uses permitted foreground sensing by default. An explicit saved-off
    // choice remains off; this preference never bypasses camera permission or background limits.
    @Published var cameraAwareness = UserDefaults.standard.object(forKey: "camera-awareness") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(cameraAwareness, forKey: "camera-awareness")
            if cameraAwareness && assistantSession.foregroundActive && !textOnly { start() }
            else if !cameraAwareness { stopCameraMonitoring() }
        }
    }
    private struct ConversationSpeech {
        let id: UUID
        let text: String
        let request: UUID
        let generation: UInt64
        let createdAt: Double
        let reports: [String]
        let evidence: [CompanionEvidence]
        let captures: [ConversationCapture]
        var codeOwned = false
    }
    private struct ConversationCapture {
        let perception: UUID
        let observation: Observation
        let capturedAt: Double
    }
    private var conversationEvidenceCaptures: [String: ConversationCapture] = [:]
    private var conversationSpeech: [ConversationSpeech] = []
    private var activeConversationSpeech: ConversationSpeech?
    private var requestedVisualDialogue: (id: UUID, generation: UInt64)?
    private var streamedConversationText = ""
    // This release is child-first. A stored explicit preference remains supported for
    // future adult use; the default never asserts verified age or guardian presence.
    @Published var assistantAudience = AssistantAudience(persistedValue:
        UserDefaults.standard.string(forKey: "assistant-audience") ?? AssistantAudience.childWithGuardian.rawValue) {
        didSet {
            guard oldValue != assistantAudience else { return }
            UserDefaults.standard.set(assistantAudience.rawValue, forKey: "assistant-audience")
            assistantSession.invalidate(); cancelDescription()
            _ = feedback.stopInformation(announceCancellation: false)
        }
    }

    private var practiceTimer: Timer?
    private var cameraInterrupted = false
    private var lastCameraRestart = -Double.infinity
    private var lastLiveActivityUpdate = -Double.infinity
    @Published private(set) var running = false
    @Published private(set) var simulation = false
    @Published private(set) var detection = Detection(.stopped)
    @Published private(set) var calibrationProgress = 0.0
    @Published private(set) var message = ""
    @Published private(set) var wearableStatus = "Disconnected"
    @Published private(set) var sceneAnswer = ""
    /// What the assistant last said or wrote: the only content of the main screen, so VoiceOver
    /// reads the reply and nothing else.
    // Child Home shows settled assistant replies only, never status, hazards or stream fragments.
    @Published private(set) var currentReply = ""
    @Published private(set) var busy = false
    @Published private(set) var attentionMode: AttentionMode = .moving
    @Published private(set) var returnStatus = ""
    @Published private(set) var returning = false
    @Published var assistantQuestion = ""
    @Published var objectiveDraft = ""
    @Published private(set) var preferredName = ""
    @Published private(set) var profileStatus = ""
    private var companionWorkingState = CompanionWorkingState()
    @Published private(set) var assistantDialogue = AssistantDialogue()
    @Published private(set) var assistantPreferences = AssistantPreferences()
    private var preferencesRevision = UUID()
    @Published private(set) var preferenceError = ""
    @Published private(set) var narrationHistory: [NarrationRecord] = []
    @Published private(set) var narrationHistoryError = ""
    private let narrationSession = UUID()
    private var narrationJournal: NarrationJournal?
    private var journalTask: Task<Void, Never>?
    @Published var wordsPerMinute = max(30, min(1800, UserDefaults.standard.object(forKey: "narration-words-per-minute") as? Int ?? 180)) {
        didSet { UserDefaults.standard.set(wordsPerMinute, forKey: "narration-words-per-minute"); cancelDescription() }
    }
    @Published var narrationInterval = max(5, min(60, UserDefaults.standard.object(forKey: "narration-interval") as? Int ?? 15)) {
        didSet { UserDefaults.standard.set(narrationInterval, forKey: "narration-interval") }
    }
    private var narrationBudget = NarrationBudget()
    // Session-only declaration. A handheld camera's heading is not body heading.
    @Published var fixedBodyMount = false {
        didSet {
            if oldValue != fixedBodyMount { cancelDescription(); feedback.interruptAmbient() }
            if fixedBodyMount && !oldValue { mountSlipAnnounced = false; bodyHeadingEstimator.reset() }
        }
    }
    @Published private(set) var serviceStatus = ""
    @Published private(set) var localImageStatus = ""
    @Published var ambientDescriptions = UserDefaults.standard.object(forKey: "ambient-descriptions") as? Bool ?? true {
        didSet { UserDefaults.standard.set(ambientDescriptions, forKey: "ambient-descriptions"); if !ambientDescriptions { if questionIsAutomatic { cancelDescription() }; feedback.interruptAmbient() } }
    }
    @Published var buildPrivateMap = UserDefaults.standard.bool(forKey: "private-mapping") {
        didSet { UserDefaults.standard.set(buildPrivateMap, forKey: "private-mapping") }
    }
    @Published var offlineOnly = UserDefaults.standard.object(forKey: "offline-only") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(offlineOnly, forKey: "offline-only")
            outdoor.networkAllowed = !offlineOnly
            if offlineOnly { cancelDescription() }
        }
    }
    @Published private(set) var recognizedPlace: SavedPlace?
    @Published private(set) var placeRecoveryQuestion = ""
    @Published var arabic = UserDefaults.standard.bool(forKey: "arabic") {
        didSet {
            feedback.arabic = arabic; indoor.arabic = arabic; places.arabic = arabic
            UserDefaults.standard.set(arabic, forKey: "arabic")
            guard oldValue != arabic else { return }
            assistantSession.invalidate(); cancelDescription()
            _ = feedback.stopInformation(announceCancellation: false)
            voice.cancel()
            if !textOnly && assistantSession.shouldListen { voice.startContinuous(arabic: arabic) }
        }
    }
    @Published var detail = DetailLevel(rawValue: UserDefaults.standard.string(forKey: "detail") ?? "minimal") ?? .minimal {
        didSet {
            UserDefaults.standard.set(detail.rawValue, forKey: "detail")
            feedback.detail = detail; attentionMode = attention.mode(detail: detail)
            if oldValue != detail { cancelDescription(); feedback.interruptAmbient() }
        }
    }
    @Published var serviceURL = UserDefaults.standard.string(forKey: "scene-service") ?? "" {
        didSet { UserDefaults.standard.set(serviceURL, forKey: "scene-service") }
    }
    let session = ARSession()
    let places = PlaceStore()
    let indoor = IndoorNavigator()
    let outdoor = OutdoorNavigator()
    let feedback = Feedback()
    let wearables = BeltLink()
    let mapping = NativeMapping()
    let journeys = JourneyStore()
    let voice = VoiceInput()
    let survey = SurveyProgress()
    let visualStairs = VisualStairMonitor()
    let peopleTracking = PersonTrackingMonitor()
    #if BLIND_FAMILIAR_PEOPLE
    let familiarPeople = FamiliarFaceExperiment()
    @Published var showFamiliarPeople = false
    #endif
    private var returnTrail = ReturnTrail()
    private var returnCue: TrailCue?
    private var lastReturnAnnouncement = -Double.infinity
    private var lastIndoorAnnouncement = -Double.infinity
    private var lastIndoorCueKey = ""
    private var lastSceneContent = ""
    private var lastSceneSpoken = -Double.infinity
    private var detector = HazardDetector()
    private var policy = AlertPolicy()
    private var continuity = MonitoringContinuity()
    private var attention = AttentionPolicy()
    private var lastAmbientAttempt = -Double.infinity
    // Goal-led attention (E02/E12/M12): room familiarity, offers and automatic-description gating.
    private var companion = CompanionAttention()
    private var roomOfferCandidate: InformationCandidate?
    private var lastCompanionTick = -Double.infinity
    // Room recognition from combined clues, body heading, change detection and remembered items.
    private var roomRecognizer = RoomRecognizer()
    private lazy var roomRecall = RoomRecall(memory: places.memory)
    private let conversationFrameProbe = ConversationFrameProbe()
    private var lastRecallCheck = -Double.infinity
    private var recallInFlight = false
    private var perceptionGeneration = UUID()
    private var recognizedRoomID: String?
    private var alignedRoomID: String?
    private var userConfirmedRoomID: String?
    private var establishedRoomHistory: [String] = []
    private var leftRoomID: String?
    /// Basis of the current recognised room; pictures are learned only from trusted clues.
    private var recognizedBasis: [String] = []
    private var roomQuestionCandidate: InformationCandidate?
    private var bodyHeadingEstimator = BodyHeadingEstimator()
    private var mountSlipAnnounced = false
    private var changeDetector = SceneChangeDetector()
    private var latestViewTexts: [String] = []
    private var latestViewTextCapturedAt = -Double.infinity
    private var latestViewTextObservation: Observation?
    private var items = ItemMemory()
    private lazy var itemAppearance = ItemAppearance(memory: places.memory)
    /// Guided saving of how an item looks: "this is my cup", then turning it slowly.
    private var itemMemoryRevision = UUID()
    private var learningItem: (name: String, key: String, started: Double, lastTick: Double)?
    private var listenedOfferKey = ""
    private var experienceActive = false
    @Published private(set) var companionGreeting = ""
    private var objectSearch: ObjectSearch?
    private var searchInFlight = false
    /// Seeing AI-style reading tools: one at a time, decided by Vision and code only.
    @Published private(set) var readingTool: ReadingTool?
    private var readingInFlight = false
    private var readingWork = ReadingWorkSession()
    private var readingTask: Task<Void, Never>?
    private var documentStability = DocumentStability()
    private var documentOrigin: (point: Point3, forward: Point3)?
    private var documentChunks: [String] = []
    private var documentSpeechID: UUID?
    private var exploreTask: Task<Void, Never>?
    private var exploreRequest = UUID()
    private var lastReadingLook = -Double.infinity
    private var readingStarted = -Double.infinity
    private var lastReadingBeep = -Double.infinity
    private var liveTextReader = LiveTextReader()
    private var lastDocumentGuidance: DocumentGuidance?
    private var lastLightLevel: LightLevel?
    private var products = ProductMemory()
    private var lastScannedCode: String?
    /// A picture kept in memory (never saved or sent) with the regions Vision found, to explore by touch.
    @Published private(set) var exploreSnapshot: ExploreSnapshot?
    /// A found object kept as one 3D target while the child approaches it (sensor-only guidance).
    private var trackedTarget: TrackedTarget?
    // No validated target-instance-to-depth association exists in this build. A category
    // box or appearance similarity is not proof of the exact safe-to-handle item.
    // Keep nonspatial search useful, but do not turn these prototypes into reach guidance.
    private static let objectInteractionGuidanceValidated = false
    private var trackLookInFlight = false
    private var lastTrackLook = -Double.infinity
    /// The running question is a conversation reply, which does not depend on the camera view.
    private var questionIsChat = false
    /// "Is this my cup?" / "where is my cup" image comparison in progress.
    private var lookupInFlight = false
    @Published var listenAfterQuestions = UserDefaults.standard.object(forKey: "listen-after-questions") as? Bool ?? false {
        didSet { UserDefaults.standard.set(listenAfterQuestions, forKey: "listen-after-questions") }
    }
    @Published private(set) var companionOffer: CompanionOffer?
    @Published var firstVisitRooms = FirstVisitMode(rawValue: UserDefaults.standard.string(forKey: "first-visit-rooms") ?? "") ?? .offer {
        didSet { UserDefaults.standard.set(firstVisitRooms.rawValue, forKey: "first-visit-rooms") }
    }
    private var subscriptions = Set<AnyCancellable>()
    private var watchdog: Timer?
    private var lastObservation: Observation?
    private var lastFrameWallTime = 0.0
    private var lastProcessed = -Double.infinity
    private var phoneDetection = Detection(.stopped)
    private var cameraStartupID = UUID()
    private var requestID = UUID()
    private var questionTask: Task<Void, Never>?
    private var questionTimeoutTask: Task<Void, Never>?
    private let saudiBanknotes = SaudiBanknoteReferenceRecognition()
    private var currencyActive = false
    private var currencyRetake = CurrencyRetakeSession()
    private let clothingColors = ClothingColorReader()
    private var colorActive = false
    private var questionIsAutomatic = false
    private var pendingQuestion: PendingQuestion?
    private var awaitingPlace: SavedPlace?
    private var placeRecovery = PlaceRecovery()
    private let imageContext = CIContext()
    private var demonstrationTime = 0.0
    private var demonstrationHazard: Hazard = .observing
    override init() {
        super.init(); session.delegate = self; session.delegateQueue = .main
        if let data = try? places.memory?.value(namespace: "preferences", id: "preferred-name"),
           let name = try? JSONDecoder().decode(String.self, from: data) {
            preferredName = name
        }
        if let data = try? places.memory?.value(namespace: "products", id: "names"),
           let saved = try? JSONDecoder().decode(ProductMemory.self, from: data) {
            products = saved
        }
        if let data = try? places.memory?.value(namespace: "companion", id: "working-state"),
           let saved = try? JSONDecoder().decode(CompanionWorkingState.self, from: data) {
            companionWorkingState = saved
        }
        if let data = try? places.memory?.value(namespace: "dialogue", id: "active"),
           let saved = try? JSONDecoder().decode(AssistantDialogue.self, from: data), saved.valid {
            assistantDialogue = saved; objectiveDraft = saved.goal
        }
        if let data = try? places.memory?.value(namespace: "preferences", id: "interests"),
           let saved = try? JSONDecoder().decode(AssistantPreferences.self, from: data), saved.valid {
            assistantPreferences = saved
        }
        if let data = try? places.memory?.value(namespace: "companion", id: "memory"),
           let saved = try? JSONDecoder().decode(CompanionMemory.self, from: data) {
            companion = CompanionAttention(memory: saved)
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            arabic = false; offlineOnly = true; ambientDescriptions = false; buildPrivateMap = false; detail = .minimal
        }
        Task { @MainActor [weak self] in await self?.indoor.restoreCommunityContext() }
        feedback.arabic = arabic; indoor.arabic = arabic; places.arabic = arabic; feedback.detail = detail; outdoor.networkAllowed = !offlineOnly
        if let memory = places.memory {
            narrationJournal = NarrationJournal(memory: memory)
            enqueueNarration { try await $0.recover() }
        }
        feedback.onNarrationFinished = { [weak self] id, text, outcome in
            guard let self else { return }
            if outcome != .completed && self.lastSceneContent == text { self.lastSceneContent = "" }
            if let pending = self.requestedVisualDialogue, pending.id == id {
                self.requestedVisualDialogue = nil
                if outcome == .completed, self.requestID == id,
                   self.assistantSession.generation == pending.generation {
                    self.assistantDialogue.record(role: "assistant", text: text)
                    self.persistDialogue()
                }
            }
            let at = Date()
            self.enqueueNarration { try await $0.finish(id: id, outcome: outcome, at: at) }
        }
        feedback.onRequestedSpeechFinished = { [weak self] id, text, outcome in
            guard let self else { return }
            #if BLIND_FAMILIAR_PEOPLE
            self.familiarPeople.arrivalSpeechFinished(id)
            #endif
            if self.documentSpeechID == id {
                self.documentSpeechID = nil
                guard outcome == .completed, self.readingTool == .document else {
                    self.stopReadingTool(announce: false); return
                }
                if !self.documentChunks.isEmpty { self.documentChunks.removeFirst() }
                if self.documentChunks.isEmpty { self.stopReadingTool(announce: false) }
                return
            }
            guard let pending = self.activeConversationSpeech, pending.id == id else { return }
            self.activeConversationSpeech = nil
            if outcome == .completed, pending.request == self.requestID,
               self.assistantSession.accepts(generation: pending.generation) {
                // Only complete delivered phrases enter spoken conversational history.
                self.assistantDialogue.record(role: "assistant", text: text)
                self.persistDialogue()
            }
            self.drainConversationSpeech()
        }
        feedback.onIdle = { [weak self] in
            self?.drainConversationSpeech()
            self?.resumePendingQuestion()
            self?.listenForOfferAnswer()
        }
        if let data = try? places.memory?.value(namespace: "items", id: "all"),
           let saved = try? JSONDecoder().decode(ItemMemory.self, from: data), saved.valid {
            items = saved
        }
        places.currentCoordinate = { [weak self] in
            (self?.outdoor.coarseLocation ?? self?.outdoor.location).map { (latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
        }
        for publisher in [places.objectWillChange, indoor.objectWillChange, outdoor.objectWillChange, mapping.objectWillChange, journeys.objectWillChange, voice.objectWillChange, survey.objectWillChange, visualStairs.objectWillChange, peopleTracking.objectWillChange] {
            publisher.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        }
        #if BLIND_FAMILIAR_PEOPLE
        familiarPeople.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        familiarPeople.onStatus = { [weak self] text in
            guard let self, self.showFamiliarPeople || self.familiarPeople.presentationActive || self.familiarPeople.enabled,
                  !self.running || self.detection.hazard == .observing else { return }
            _ = self.speakOperation(text, revision: self.familiarPeople.operationRevision.uuidString)
        }
        familiarPeople.onSearchStarted = { [weak self] in
            guard let self else { return }
            self.cancelDescription(); self.companion.withdrawOffer(); self.companionOffer = nil
            self.roomOfferCandidate = nil; self.roomQuestionCandidate = nil
        }
        familiarPeople.onSnapshotHint = { [weak self] text in _ = self?.speakRequested(text) }
        familiarPeople.onCancelSpeech = { [weak self] in _ = self?.feedback.stopInformation() }
        familiarPeople.onCancelArrivalHint = { [weak self] id in self?.feedback.stopRequestedSpeech(id) }
        familiarPeople.onArrivalHint = { [weak self] hint in
            guard let self, self.assistantSession.foregroundActive, self.running,
                  self.detection.hazard == .observing, self.familiarCaptureIsCurrent(hint.capture) else { return false }
            let text = self.arabic ? "قد أرى \(hint.label)." : "I might see \(hint.label)."
            // A newly recognized saved person matters during an ongoing goal too.
            // This does not bypass quiet/muted social settings, budget, active speech or hazards.
            let candidate = InformationCandidate(key: "familiar-arrival:" + hint.personID.uuidString,
                kind: .social, text: text, words: Self.wordCount(text), revision: hint.encounterID.uuidString,
                createdAt: hint.capture.capturedAt, expiresAt: hint.capture.capturedAt + 1.5,
                category: "social", requested: false, goalRelevant: true)
            return self.deliverCandidate(candidate, speechID: hint.encounterID)
        }
        #endif
        wearables.onUpdate = { [weak self] in
            guard let self else { return }
            self.wearableStatus = self.wearables.status
            // A received danger packet must not wait for the 100 ms watchdog tick.
            if self.running { self.publish() }
        }
        voice.onUnavailable = { [weak self] text in
            guard let self else { return }
            // Losing the ability to hear the child is a safety problem, not a routine status.
            self.message = text
            self.speakMobility(text)
        }
        voice.shouldIgnore = { [weak self] text in self?.feedback.isLikelyOwnSpeech(text) == true }
        voice.onPrivateRouteLost = { [weak self] in
            guard let self else { return }
            // Headphone removal must not move a private reply onto the speaker.
            // Explicit Start/Unmute is required; do not announce this transition.
            if self.assistantSession.state == .active { self.assistantSession.mute() }
            self.cancelDescription()
            _ = self.feedback.stopInformation(announceCancellation: false)
            self.message = self.arabic ? "انقطع جهاز الصوت. استأنف المحادثة عندما تكون مستعداً." : "Audio device disconnected. Resume conversation when you are ready."
        }
        voice.onSpeechBegan = { [weak self] in
            guard let self, self.assistantSession.shouldListen else { return }
            // Acoustic-energy onset or transcript fallback: retire stale work
            // before the utterance finishes. Neither signal proves speaker identity.
            let pendingRetake = self.currencyRetake
            self.cancelDescription()
            if pendingRetake.isPending { self.currencyRetake = pendingRetake }
            _ = self.feedback.stopInformation(announceCancellation: false)
        }
        voice.onReadyForReply = { [weak self] in
            guard let self, self.assistantSession.shouldListen else { return }
            self.drainConversationSpeech()
        }
        voice.onFinished = { [weak self] text in self?.receiveCompanionUtterance(text, fromVoice: true) }
        visualStairs.onUpdate = { [weak self] in
            guard let self, self.running, !self.simulation, !self.places.scanning else { return }
            self.publish()
            self.resumePendingQuestion()
        }
        feedback.onControlAnnouncement = { [weak self] text in _ = self?.speakOperation(text, replace: false) }
        places.onMessage = { [weak self] text in _ = self?.speakOperation(text) }
        places.onScanFinished = { [weak self] in
            guard let self else { return }
            self.session.delegate = self; self.detector.reset(); self.phoneDetection = Detection(.needsCalibration)
            if self.running {
                let configuration = ARWorldTrackingConfiguration()
                configuration.worldAlignment = .gravity; configuration.frameSemantics = .sceneDepth
                configuration.planeDetection = [.horizontal]
                self.session.run(configuration)
                if self.buildPrivateMap { self.mapping.start() }
            }
            self.message = self.arabic ? "انتهى مسح الغرفة. لتعود تنبيهات الكاميرا، قف على أرض مستوية وقل: أنا واقف على أرض مستوية."
                : "Room scan finished. To bring camera alerts back, stand on a level floor and say: I'm standing on a level floor."
            _ = self.speakMobility(self.message)
        }
    }
    var supported: Bool { ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) }
    func start() {
        defer { updateLiveActivity() }
        guard !running, !places.scanning, assistantSession.foregroundActive, cameraAwareness, !textOnly else { return }
        guard supported else {
            message = arabic ? "لا يستطيع هذا الهاتف فحص المسار. التدريب موجود في الإعدادات." : "This phone cannot check the path. Practice is in Settings."
            speakOperation(message)
            return
        }
        let id = UUID(); cameraStartupID = id
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: outdoor.requestCoarseLocation(); launchWithNearbyPlace()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.cameraStartupID == id, self.assistantSession.foregroundActive, self.cameraAwareness else { return }
                    if granted { self.launch() } else { self.cameraPermissionNeeded() }
                }
            }
        default: cameraPermissionNeeded()
        }
    }
    private func cameraPermissionNeeded() {
        message = arabic ? "أحتاج إذن الكاميرا. اطلب المساعدة في إعدادات الهاتف." : "I need camera permission. Ask for help in the phone's Settings."
        speakOperation(message)
    }
    private func launch(map: ARWorldMap? = nil) {
        defer { updateLiveActivity() }
        invalidatePerceptionWork()
        peopleTracking.reset()
        fixedBodyMount = false
        recognizedPlace = nil
        // After any (re)start the room is unknown until freshly established.
        recognizedRoomID = nil; alignedRoomID = nil; userConfirmedRoomID = nil; leftRoomID = nil
        roomQuestionCandidate = nil; roomRecognizer.reset(); bodyHeadingEstimator.reset(); recognizedBasis = []
        // World yaw restarts with each session, so view-direction baselines start fresh too.
        changeDetector = SceneChangeDetector()
        if map == nil { awaitingPlace = nil; placeRecovery.reset() }
        visualStairs.reset()
        survey.reset()
        stopReturn(); indoor.invalidatePosition()
        mapping.stop(); journeys.begin()
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.frameSemantics = .sceneDepth
        configuration.planeDetection = [.horizontal]
        configuration.initialWorldMap = map
        cancelDescription(); attention = AttentionPolicy()
        detector.reset(); policy = AlertPolicy(); continuity = MonitoringContinuity(); lastProcessed = -.infinity
        lastObservation = nil; lastFrameWallTime = ProcessInfo.processInfo.systemUptime
        phoneDetection = Detection(.needsCalibration); simulation = false; running = true
        session.delegate = self; session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        if buildPrivateMap { mapping.start() }
        UIApplication.shared.isIdleTimerDisabled = true
        startWatchdog()
        message = arabic ? "قف على أرض مستوية. وجّه الكاميرا نحو الأرض أمامك، ثم اضغط أنا واقف على أرض مستوية." : "Stand on a level floor. Point the camera at the ground ahead, then choose I'm standing on a level floor."
        speakMobility(message)
    }
    func stop() {
        voice.cancel()
        cancelDescription()
        stopCameraMonitoring()
        feedback.stop(includingAlerts: true)
    }
    /// Camera/sensor lifecycle is independent of an opted-in audio conversation.
    private func stopCameraMonitoring() {
        defer { updateLiveActivity() }
        cameraStartupID = UUID()
        cancelDescription()
        invalidatePerceptionWork()
        peopleTracking.reset()
        fixedBodyMount = false
        visualStairs.reset()
        survey.invalidate()
        stopReturn()
        mapping.stop(); journeys.finish()
        attention.resetMotion()
        requestID = UUID(); questionTask?.cancel(); questionTask = nil; busy = false
        places.cancelScan(); session.pause(); watchdog?.invalidate(); watchdog = nil
        detector.reset(); continuity = MonitoringContinuity(); lastObservation = nil; recognizedPlace = nil; awaitingPlace = nil
        placeRecovery.reset(); placeRecoveryQuestion = ""
        indoor.invalidatePosition(); outdoor.stop(); wearables.disconnect()
        practiceTimer?.invalidate(); practiceTimer = nil
        UIApplication.shared.isIdleTimerDisabled = false
        running = false; simulation = false; phoneDetection = Detection(.stopped); detection = phoneDetection
    }
    func calibrate() {
        guard running, !places.scanning, awaitingPlace == nil else { return }
        detector.beginCalibration(); calibrationProgress = 0; phoneDetection = Detection(.calibrating)
        // Publish first so the instruction is not held back by the earlier "needs calibration" state.
        publish()
        message = arabic ? "اثبت على أرض مستوية معروفة، وأبقِ الأرض القريبة أمام الكاميرا." : "Stand still on known level ground. Keep nearby floor in view."
        speakOperation(arabic ? "اثبت على أرض مستوية معروفة." : "Hold still on known level ground.")
    }
    func connectWearables() { wearables.connect() }
    func repeatMonitoringStatus() {
        announceDetection(detection, requested: true)
    }
    func calibrateBelt() { wearables.send(WearableCommand.calibrate) }
    func identifyBelt() { wearables.send(WearableCommand.identify) }
    private func startWatchdog() {
        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.running, !self.places.scanning else { return }
            if self.placeRecovery.expire(now: ProcessInfo.processInfo.systemUptime) || self.placeRecovery.state == .needsHelp {
                self.awaitingPlace = nil; self.launch()
                self.placeRecoveryQuestion = self.arabic ? "لم أتأكد من المكان. هل أنت في مكان محفوظ أم في مكان آخر؟ اختر المكان للمحاولة مجدداً. يمكنك البقاء ثابتاً وتحريك الكاميرا ببطء إن كان ذلك مريحاً." : "I could not confirm this place. Are you in a saved place or somewhere else? Select a place to retry. You can stay still and slowly turn the camera if comfortable."
                self.message = self.placeRecoveryQuestion
                self.speakMobility(self.placeRecoveryQuestion)
            }
            let now = ProcessInfo.processInfo.systemUptime
            if now - self.lastLiveActivityUpdate > 10 { self.updateLiveActivity() }
            if self.simulation { self.demoFrame() }
            else if now - self.lastFrameWallTime > 3, now - self.lastCameraRestart > 10,
                    UIApplication.shared.applicationState == .active, !self.cameraInterrupted {
                // Frames stopped while the app is open: restart the camera instead of waiting.
                self.lastCameraRestart = now
                _ = self.speakMobility(self.arabic ? "توقفت الكاميرا. أعيد تشغيلها." : "The camera stopped. Restarting it.")
                self.launch()
            }
            else if now - self.lastFrameWallTime > 0.5 {
                // Invalidate calibration and held evidence when callbacks stop.
                self.invalidatePerceptionWork()
                self.invalidateRecognizedRoom()
                self.detector.reset(); self.phoneDetection = Detection(.uncertain, reason: .frameUnavailable)
                self.visualStairs.reset()
                self.peopleTracking.reset()
                self.recognizedPlace = nil; self.indoor.invalidatePosition(); self.fixedBodyMount = false
                _ = self.placeRecovery.observe(normal: false, mapped: false, now: ProcessInfo.processInfo.systemUptime)
                self.attention.resetMotion(); self.cancelDescription()
                self.journeys.breakTracking()
                self.survey.invalidate()
                self.invalidateReturn()
            }
            self.publish()
            self.resumePendingQuestion()
        }
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard running, !simulation, !places.scanning, frame.timestamp - lastProcessed >= 1.0 / 15 else { return }
        let timing = AssistantPerformance.signposter.beginInterval("SensorFrame", id: AssistantPerformance.signposter.makeSignpostID())
        defer { AssistantPerformance.signposter.endInterval("SensorFrame", timing) }
        lastProcessed = frame.timestamp; lastFrameWallTime = ProcessInfo.processInfo.systemUptime
        // RGB classification runs separately; its task never blocks depth processing.
        visualStairs.consume(frame, at: lastFrameWallTime)
        if let place = awaitingPlace {
            let normal: Bool
            if case .normal = frame.camera.trackingState { normal = true } else { normal = false }
            if placeRecovery.observe(normal: normal,
                mapped: frame.worldMappingStatus == .mapped || frame.worldMappingStatus == .extending,
                now: lastFrameWallTime) == place.id.uuidString {
                    recognizedPlace = place; awaitingPlace = nil
                    placeRecoveryQuestion = ""
                    message = "Saved map matched: \(place.name). Recalibrate the floor."
                    speakOperation(message)
            }
            phoneDetection = Detection(.uncertain, reason: .localizing); publish(); return
        }
        guard let observation = DepthSampler.observation(from: frame) else {
            invalidatePerceptionWork(); invalidateRecognizedRoom()
            survey.invalidate()
            journeys.breakTracking(); attention.resetMotion()
            invalidateReturn()
            detector.invalidateRecentEvidence()
            phoneDetection = Detection(.uncertain, reason: DepthSampler.unavailableReason(from: frame)); lastObservation = nil; publish(); return
        }
        if !observation.trackingNormal {
            invalidatePerceptionWork(); invalidateRecognizedRoom()
            detector.reset(); recognizedPlace = nil; indoor.invalidatePosition(); fixedBodyMount = false
            invalidateReturn()
        }
        lastObservation = observation
        peopleTracking.consume(frame, observation: observation, at: lastFrameWallTime)
        journeys.observe(observation)
        if buildPrivateMap { mapping.consume(frame) }
        attention.observe(camera: observation.camera, at: lastFrameWallTime, tracking: observation.trackingNormal)
        attentionMode = attention.mode(detail: detail)
        // An unanswered retry prompt expires without starting another capture or blocking ambience.
        if let deadline = currencyRetake.expiresAt, lastFrameWallTime >= deadline { currencyRetake.clear() }
        if !attention.stationary, currencyActive || currencyRetake.isPending { cancelDescription() }
        phoneDetection = detector.process(observation)
        survey.observe(observation, floor: detector.floorHeight)
        calibrationProgress = detector.calibrationProgress; publish()
        #if BLIND_FAMILIAR_PEOPLE
        familiarPeople.revalidate(model: self)
        familiarPeople.consume(model: self)
        #endif
        updateReturn(observation)
        if !returning, fixedBodyMount, indoor.isAligned, detection.hazard == .observing,
           lastFrameWallTime - lastIndoorAnnouncement >= 8 { indoorBeacon(automatic: true) }
        bodyHeadingEstimator.observe(camera: observation.camera, cameraForward: observation.forward,
                                     at: lastFrameWallTime, tracking: observation.trackingNormal)
        checkMountSlip()
        updateCompanionRoom(observation)
        updateRoomRecognition(frame: frame, observation: observation)
        updateItemLearning(frame: frame)
        continueSearch()
        updateTrackedTarget()
        updateReadingTool(frame: frame)
        if ambientDescriptions, !returning, objectSearch == nil, trackedTarget == nil, readingTool == nil, !lookupInFlight, !voice.awaitingUtterance, lastFrameWallTime - lastAmbientAttempt >= 4,
           attention.permitsAmbient(detail: detail, urgent: detection.hazard != .observing, now: lastFrameWallTime) {
            lastAmbientAttempt = lastFrameWallTime
            readScene(cloud: false, automatic: true)
        }
    }
    #if BLIND_FAMILIAR_PEOPLE
    @discardableResult func routeFamiliarPeopleCommand(_ text: String) -> Bool {
        guard let command = FamiliarPeopleCommand.parse(text) else { return false }
        if currencyActive || colorActive || readingTool != nil || currencyRetake.isPending { cancelDescription() }
        guard command == .cancel || command == .stop || !running || detection.hazard == .observing else { message = "Current monitoring alerts take priority."; return true }
        if !showFamiliarPeople && !familiarPeople.enabled {
            showFamiliarPeople = true
            familiarPeople.reload()
        }
        familiarPeople.handle(command, model: self)
        return true
    }
    /// Short-lived rear-camera input for consent-enabled foreground recognition.
    func captureFamiliarFace() -> FamiliarCapture? {
        guard running, !simulation, !places.scanning, awaitingPlace == nil,
              detection.hazard == .observing, attention.stationary,
              UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).contains(where: { $0.interfaceOrientation == .portrait }),
              let observation = lastObservation, observation.trackingNormal,
              let frame = session.currentFrame,
              FamiliarFacePolicy.fresh(capturedAt: lastFrameWallTime, now: ProcessInfo.processInfo.systemUptime, frameAt: lastFrameWallTime)
        else { return nil }
        return FamiliarCapture(image: frame.capturedImage, capturedAt: lastFrameWallTime, generation: perceptionGeneration,
            camera: observation.camera, forward: observation.forward)
    }
    func familiarCaptureIsCurrent(_ capture: FamiliarCapture) -> Bool {
        familiarContextIsCurrent(capture, snapshotSpeech: false)
    }
    /// Only authorizes finishing a past-snapshot utterance, never a live name/position.
    func familiarSnapshotContextIsCurrent(_ capture: FamiliarCapture) -> Bool {
        familiarContextIsCurrent(capture, snapshotSpeech: true)
    }
    private func familiarContextIsCurrent(_ capture: FamiliarCapture, snapshotSpeech: Bool) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let ageOK = snapshotSpeech
            ? FamiliarFacePolicy.snapshotSpeechFresh(capturedAt: capture.capturedAt, now: now, frameAt: lastFrameWallTime)
            : FamiliarFacePolicy.fresh(capturedAt: capture.capturedAt, now: now, frameAt: lastFrameWallTime)
        guard running, !simulation, !places.scanning, awaitingPlace == nil,
              detection.hazard == .observing, attention.stationary,
              perceptionGeneration == capture.generation, let observation = lastObservation, observation.trackingNormal,
              UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).contains(where: { $0.interfaceOrientation == .portrait }),
              ageOK,
              observation.camera.distance(to: capture.camera) < 0.10 else { return false }
        let dot = observation.forward.x * capture.forward.x + observation.forward.y * capture.forward.y + observation.forward.z * capture.forward.z
        return dot > cos(.pi / 36)
    }
    #endif
    private func invalidatePerceptionWork() {
        #if BLIND_FAMILIAR_PEOPLE
        if familiarPeople.enabled && familiarPeople.hasActiveWork { familiarPeople.cancel() }
        #endif
        if currencyActive || colorActive || readingTool != nil || currencyRetake.isPending { cancelDescription() }
        perceptionGeneration = UUID(); recallInFlight = false; learningItem = nil
        latestViewTexts = []; latestViewTextCapturedAt = -.infinity; latestViewTextObservation = nil
        roomRecall.cancelPendingWork(); itemAppearance.cancelPendingWork()
    }
    private func invalidateRecognizedRoom() {
        if let previous = recognizedRoomID { leftRoomID = previous }
        recognizedRoomID = nil; recognizedBasis = []
        roomRecall.cancelPendingWork()
    }
    private func perceptionResultAllowed(request: UUID, generation: UUID, capturedAt: Double, observation: Observation, mapRevision: UUID, alignmentRevision: UUID) -> Bool {
        running && !simulation && !places.scanning && requestID == request && perceptionGeneration == generation &&
        indoor.revision == mapRevision && indoor.alignmentRevision == alignmentRevision &&
        SceneDelivery.allowed(capturedAt: capturedAt, now: ProcessInfo.processInfo.systemUptime,
            origin: observation.camera, current: lastObservation?.camera, currentFrameAt: lastFrameWallTime,
            hazard: detection.hazard, tracking: lastObservation?.trackingNormal == true,
            originForward: observation.forward, currentForward: lastObservation?.forward)
    }
    private func cancelDescription() {
        currencyRetake.clear()
        stopReadingTool(announce: false)
        exploreRequest = UUID(); exploreTask?.cancel(); exploreTask = nil
        searchInFlight = false; trackLookInFlight = false; lookupInFlight = false
        conversationSpeech.removeAll()
        conversationEvidenceCaptures.removeAll()
        requestedVisualDialogue = nil
        if activeConversationSpeech != nil {
            activeConversationSpeech = nil
            _ = feedback.stopInformation(announceCancellation: false)
        }
        streamedConversationText = ""
        questionTimeoutTask?.cancel(); questionTimeoutTask = nil
        objectSearch?.cancel(); objectSearch = nil; trackedTarget = nil
        currencyActive = false
        colorActive = false
        pendingQuestion = nil
        requestID = UUID(); questionTask?.cancel(); questionTask = nil; busy = false; questionIsAutomatic = false
        questionIsChat = false
    }
    private func publish() {
        let now = ProcessInfo.processInfo.systemUptime
        let previousHazard = detection.hazard
        let visual = !simulation ? visualStairs.detection(at: now).map { [$0] } ?? [] : []
        detection = continuity.process(AlertPolicy.highest(visual + [phoneDetection] + (simulation ? [] : wearables.detections(at: now))), at: now)
        if [.uncertain, .calibrating, .needsCalibration].contains(previousHazard) && detection.hazard == .observing {
            // A status update, never an instruction to start walking.
            speakMobility(GuidanceText.hazard(.observing, arabic: arabic))
        }
        if detection.hazard != .observing { feedback.interruptAmbient() }
        if detection.hazard.isUrgent ||
            (detection.hazard.requiresImmediateAttention && !previousHazard.requiresImmediateAttention) {
            cancelDescription()
            companion.withdrawOffer(); companionOffer = nil
            roomOfferCandidate = nil; roomQuestionCandidate = nil
            #if BLIND_FAMILIAR_PEOPLE
            if familiarPeople.enabled && familiarPeople.hasActiveWork { familiarPeople.cancel() }
            #endif
            if voice.listening { voice.endManualTurn() }
        }
        if policy.shouldAnnounce(detection, at: now) {
            if detection.hazard.isUrgent {
                questionTask?.cancel(); questionTask = nil; busy = false
                if detection.reason != .visualStairs {
                    wearables.send(WearableCommand.haptic(sector: detection.sector, intensity: 220, durationMS: 300))
                }
            }
            announceDetection(detection)
        }
    }
    func session(_ session: ARSession, didFailWithError error: Error) {
        invalidatePerceptionWork()
        peopleTracking.reset()
        fixedBodyMount = false
        awaitingPlace = nil; placeRecovery.reset()
        visualStairs.reset()
        invalidateReturn()
        mapping.stop(); journeys.breakTracking(); cancelDescription()
        detector.reset(); phoneDetection = Detection(.uncertain, reason: .frameUnavailable); recognizedPlace = nil
        indoor.invalidatePosition()
        message = arabic ? "تعطلت الكاميرا. أعيد تشغيلها." : "The camera failed. Restarting it."
        publish(); _ = speakMobility(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.running, !self.simulation, !self.places.scanning,
                  self.assistantSession.foregroundActive, self.cameraAwareness else { return }
            self.lastCameraRestart = ProcessInfo.processInfo.systemUptime
            self.launch()
        }
    }
    func sessionWasInterrupted(_ session: ARSession) {
        invalidatePerceptionWork()
        peopleTracking.reset()
        fixedBodyMount = false
        awaitingPlace = nil; placeRecovery.reset()
        visualStairs.reset()
        invalidateReturn()
        mapping.stop(); journeys.breakTracking(); cancelDescription()
        detector.reset(); phoneDetection = Detection(.uncertain, reason: .frameUnavailable); recognizedPlace = nil
        cameraInterrupted = true
        indoor.invalidatePosition()
        message = arabic ? "الكاميرا متوقفة مؤقتاً. تنبيهات الكاميرا لا تعمل الآن." : "The camera is paused. Camera alerts are not working right now."
        publish()
        // In the background the background warning speaks instead (one message, not two).
        if UIApplication.shared.applicationState == .active { _ = speakMobility(message) }
    }
    func sessionInterruptionEnded(_ session: ARSession) {
        cameraInterrupted = false
        guard running else { return }
        awaitingPlace = nil; launch()
        message = arabic ? "عادت الكاميرا. أعد معايرة الأرض." : "The camera is back. Recalibrate the floor."
    }
    func scanPlace(name: String, compare: Bool = false) {
        guard running, !simulation, !places.scanning else { message = "Start the live camera first."; return }
        guard !compare || recognizedPlace != nil else { message = "Recognize a saved place before comparing."; return }
        outdoor.requestCoarseLocation()
        mapping.stop(); journeys.breakTracking(); fixedBodyMount = false; indoor.invalidatePosition(); peopleTracking.reset()
        visualStairs.reset()
        invalidateReturn(); cancelDescription(); voice.endManualTurn(); detector.reset(); feedback.stop()
        phoneDetection = Detection(.uncertain); detection = phoneDetection
        // The room scanner needs the camera, so path alerts from the camera pause; say so plainly.
        _ = speakMobility(arabic ? "مسح الغرفة يعمل. تنبيهات الكاميرا متوقفة حتى ينتهي المسح. ابقَ مع مساعد مبصر." : "Room scan running. Camera path alerts are off until the scan ends. Stay with a sighted helper.")
        places.startScan(session: session, name: name, compare: compare ? recognizedPlace : nil, relocalized: recognizedPlace != nil)
    }
    func recognize(_ place: SavedPlace) {
        guard supported, AVCaptureDevice.authorizationStatus(for: .video) == .authorized, !places.scanning else {
            message = "Start the live camera before recognizing a place."; return
        }
        do {
            let map = try places.worldMap(for: place)
            recognizedPlace = nil; awaitingPlace = place
            placeRecovery.begin(candidate: place.id.uuidString, now: ProcessInfo.processInfo.systemUptime)
            placeRecoveryQuestion = ""
            indoor.invalidatePosition(); launch(map: map)
            message = arabic ? "جارٍ التحقق من \(place.name). ابق ثابتاً ووجّه الكاميرا ببطء إلى معالم قريبة إن كان ذلك مريحاً." : "Checking \(place.name). Stay still and slowly point the camera at nearby landmarks if comfortable."
        } catch {
            message = "Saved place could not be loaded."
            if !running { launch() }
        }
    }
    func continueWithoutPlaceMatch() {
        guard running, !simulation, supported, !places.scanning,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        launch(); placeRecoveryQuestion = ""
        message = arabic ? "المكان غير معروف. لن أستخدم الغرفة السابقة لإعطاء اتجاهات. أعد معايرة الأرضية." : "Place is unknown. I will not use the previous room for directions. Recalibrate the floor."
        speakOperation(message)
    }
    func alignIndoor() {
        guard let observation = lastObservation, observation.trackingNormal, !simulation,
              ProcessInfo.processInfo.systemUptime - lastFrameWallTime < 0.5 else { message = "A live tracked camera is required."; return }
        indoor.align(camera: observation.camera, forward: observation.forward)
        lastIndoorCueKey = ""; lastIndoorAnnouncement = -.infinity
    }
    func indoorBeacon(automatic: Bool = false) {
        guard let observation = lastObservation, observation.trackingNormal,
              ProcessInfo.processInfo.systemUptime - lastFrameWallTime < 0.5,
              detection.hazard == .observing else { return }
        guard let cue = indoor.next(camera: observation.camera, forward: observation.forward) else {
            _ = speakMobility(indoor.message)
            lastIndoorAnnouncement = ProcessInfo.processInfo.systemUptime; return
        }
        let key = "\(indoor.alignmentRevision):\(indoor.waypointIndex):\(cue.sector):\(cue.distance <= 1)"
        if automatic, key == lastIndoorCueKey { return }
        if speakMobility(indoor.message) {
            if fixedBodyMount { feedback.beacon(sector: cue.sector, distance: min(10, cue.distance)) }
            lastIndoorAnnouncement = ProcessInfo.processInfo.systemUptime
            lastIndoorCueKey = key
        }
    }
    /// Explicit single-photo money request. Unknown/unavailable never falls through to an LLM.
    @discardableResult func routeSaudiBanknoteCommand(_ text: String, retake: CurrencyRetakeSession? = nil) -> Bool {
        guard retake != nil || ConversationDomainPolicy.requiredInspection(for: text) == .banknote else { return false }
        cancelDescription()
        if let retake { currencyRetake = retake }
        #if BLIND_FAMILIAR_PEOPLE
        familiarPeople.cancelSearchForNewGoal()
        #endif
        guard SaudiBanknoteReferenceRecognition.isAvailable else {
            currencyRetake.clear()
            message = arabic ? "التعرف على الأوراق النقدية السعودية غير متاح في هذا الإصدار. لن أخمّن القيمة." : "Saudi banknote recognition is not available in this build. I won't guess the value."
            _ = speakOperation(message)
            return true
        }
        guard running, !simulation, !places.scanning, awaitingPlace == nil,
              attention.stationary, detection.hazard == .observing,
              UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).contains(where: { $0.interfaceOrientation == .portrait }),
              let observation = lastObservation, observation.trackingNormal,
              let frame = session.currentFrame else {
            message = arabic ? "توقف وثبّت الهاتف عمودياً وأظهر ورقة واحدة كاملة للكاميرا، ثم اطلب قراءة النقود." : "Hold still with the phone upright and show one whole banknote to the camera, then ask to read money."
            _ = speakOperation(message)
            return true
        }
        let capturedAt = lastFrameWallTime, generation = perceptionGeneration, request = requestID
        let mapRevision = indoor.revision, alignmentRevision = indoor.alignmentRevision
        guard SaudiBanknotePolicy.fresh(capturedAt: capturedAt, now: ProcessInfo.processInfo.systemUptime),
              perceptionResultAllowed(request: request, generation: generation, capturedAt: capturedAt,
                                      observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else {
            currencyNeedsFreshView(request: request, generation: generation); return true
        }
        let image = frame.capturedImage
        let transform = frame.camera.transform
        let currencyOrigin = Point3(Double(transform.columns.3.x), Double(transform.columns.3.y), Double(transform.columns.3.z))
        let currencyForward = Point3(-Double(transform.columns.2.x), -Double(transform.columns.2.y), -Double(transform.columns.2.z))
        busy = true; currencyActive = true; questionIsAutomatic = false
        questionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.requestID == request { self.busy = false; self.currencyActive = false; self.questionTask = nil } }
            do {
                let result = try await self.saudiBanknotes.inspect(image: image, orientation: .right)
                try Task.checkCancellation()
                guard self.currencyActive, self.attention.stationary,
                      self.visualCapturePoseAllowed(origin: currencyOrigin, forward: currencyForward),
                      SaudiBanknotePolicy.fresh(capturedAt: capturedAt, now: ProcessInfo.processInfo.systemUptime),
                      UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).contains(where: { $0.interfaceOrientation == .portrait }),
                      self.perceptionResultAllowed(request: request, generation: generation, capturedAt: capturedAt,
                          observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else {
                    self.currencyNeedsFreshView(request: request, generation: generation); return
                }
                self.message = result.speech(arabic: self.arabic)
                if case .denomination = result {
                    self.currencyRetake.clear()
                    // Only accepted amounts use ordinary answer speech, never a guess.
                    _ = self.speakRequested(self.message, narrationID: request)
                } else {
                    let reason: CurrencyRetakeSession.Reason
                    switch result {
                    case .tooSmall: reason = .tooSmall
                    case .clipped: reason = .clipped
                    case .multiple: reason = .multiple
                    default: reason = .unknown
                    }
                    let armed = self.currencyRetake.arm(reason: reason, rejectedFrameAt: capturedAt,
                        now: ProcessInfo.processInfo.systemUptime)
                    self.message += armed
                        ? (self.arabic ? " قل حاول مجدداً عندما تكون جاهزاً." : " Say try again when ready.")
                        : (self.arabic ? " انتهت محاولات هذه الصورة. ابدأ طلب قراءة نقود جديداً لاحقاً." : " This attempt window has ended. Start a new money-reading request later.")
                    _ = self.speakOperation(self.message)
                }
            } catch is CancellationError {
                return
            } catch {
                guard self.requestID == request, self.currencyActive, self.attention.stationary,
                      self.visualCapturePoseAllowed(origin: currencyOrigin, forward: currencyForward),
                      SaudiBanknotePolicy.fresh(capturedAt: capturedAt, now: ProcessInfo.processInfo.systemUptime),
                      self.perceptionResultAllowed(request: request, generation: generation, capturedAt: capturedAt,
                          observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else {
                    self.currencyNeedsFreshView(request: request, generation: generation); return
                }
                if error is SaudiBanknoteReferenceRecognition.Failure {
                    self.currencyRetake.clear()
                    self.message = self.arabic ? "التعرف على النقود غير متاح في هذا الإصدار. لن أخمّن." : "Banknote recognition is unavailable in this build. I won't guess."
                } else {
                    let armed = self.currencyRetake.arm(reason: .processingFailure, rejectedFrameAt: capturedAt,
                        now: ProcessInfo.processInfo.systemUptime)
                    self.message = armed
                        ? (self.arabic ? "تعذر فحص الصورة. أظهر ورقة واحدة كاملة وقل حاول مجدداً." : "I couldn't inspect that image. Show one whole note and say try again.")
                        : (self.arabic ? "تعذر فحص الورقة. انتهت نافذة المحاولات، ولن أخمّن." : "I couldn't inspect the note. The retry window has ended; I won't guess.")
                }
                _ = self.speakOperation(self.message)
            }
        }
        return true
    }

    /// A stale result is never spoken. Only its still-current, safe request may ask once
    /// for a new capture, without inferring blur, denomination or a direction to move.
    private func currencyNeedsFreshView(request: UUID, generation: UUID) {
        guard !Task.isCancelled, requestID == request, perceptionGeneration == generation,
              assistantSession.foregroundActive, running, !simulation, attention.stationary,
              detection.hazard == .observing else { return }
        currencyRetake.clear()
        message = arabic ? "أحتاج صورة حديثة. أظهر ورقة كاملة واطلب قراءة النقود مجدداً." : "I need a fresh view. Show one whole note and ask to read money again."
        _ = speakOperation(message)
    }

    /// Explicit continuation only: never a timer loop and never a rerun of stored pixels.
    private func retryCurrencyCapture(_ pending: CurrencyRetakeSession) {
        guard SaudiBanknoteReferenceRecognition.isAvailable else {
            _ = routeSaudiBanknoteCommand("read money"); return
        }
        var retake = pending
        let now = ProcessInfo.processInfo.systemUptime
        guard assistantSession.foregroundActive, running, !simulation, attention.stationary,
              detection.hazard == .observing, session.currentFrame != nil,
              SaudiBanknotePolicy.fresh(capturedAt: lastFrameWallTime, now: now) else {
            speakOperation(arabic ? "أحتاج صورة حديثة وأنت ثابت. اطلب قراءة النقود عندما تكون جاهزاً." : "I need a fresh view while you hold still. Ask to read money when ready.")
            return
        }
        guard retake.takeRetry(frameAt: lastFrameWallTime, now: now) else {
            // A same-frame refusal consumes no attempt. Expired/exhausted state cannot rearm.
            if retake.isPending { currencyRetake = retake }
            speakOperation(retake.isPending
                ? (arabic ? "انتظر صورة جديدة ثم قل حاول مجدداً." : "Wait for a fresh camera view, then say try again.")
                : (arabic ? "انتهت نافذة المحاولات. اطلب قراءة النقود من جديد." : "The retry window has ended. Ask to read money again."))
            return
        }
        _ = routeSaudiBanknoteCommand("read money", retake: retake)
    }

    /// Explicit, one-frame colour request. Never falls back to a language-model colour guess.
    @discardableResult func routeClothingColorCommand(_ text: String) -> Bool {
        guard ClothingColorCommand.matches(text) else { return false }
        cancelDescription()
        #if BLIND_FAMILIAR_PEOPLE
        familiarPeople.cancelSearchForNewGoal()
        #endif
        guard running, !simulation, !places.scanning, awaitingPlace == nil,
              attention.stationary, detection.hazard == .observing,
              UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).contains(where: { $0.interfaceOrientation == .portrait }),
              let observation = lastObservation, observation.trackingNormal,
              let frame = session.currentFrame else {
            message = arabic ? "ثبّت الهاتف عمودياً وأمسك غرضاً واحداً مسطحاً في وسط الكاميرا بإضاءة متجانسة، ثم اطلب فحص اللون." : "Hold still with the phone upright. Hold one separate item flat in the centre under even lighting, then ask to check its colour."
            _ = speakOperation(message)
            return true
        }
        let capturedAt = lastFrameWallTime, generation = perceptionGeneration, request = requestID
        let mapRevision = indoor.revision, alignmentRevision = indoor.alignmentRevision
        guard ClothingColorCapturePolicy.fresh(capturedAt: capturedAt, now: ProcessInfo.processInfo.systemUptime),
              perceptionResultAllowed(request: request, generation: generation, capturedAt: capturedAt,
                  observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else { return true }
        let image = frame.capturedImage
        let transform = frame.camera.transform
        let colorOrigin = Point3(Double(transform.columns.3.x), Double(transform.columns.3.y), Double(transform.columns.3.z))
        let colorForward = Point3(-Double(transform.columns.2.x), -Double(transform.columns.2.y), -Double(transform.columns.2.z))
        let preciseNeutral = ClothingColorCommand.requiresNeutralVerification(text)
        busy = true; colorActive = true; questionIsAutomatic = false
        questionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.requestID == request { self.busy = false; self.colorActive = false; self.questionTask = nil } }
            do {
                let result = try await self.clothingColors.read(image: image, orientation: .right)
                try Task.checkCancellation()
                guard self.colorActive, self.attention.stationary,
                      self.visualCapturePoseAllowed(origin: colorOrigin, forward: colorForward),
                      ClothingColorCapturePolicy.fresh(capturedAt: capturedAt, now: ProcessInfo.processInfo.systemUptime),
                      UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).contains(where: { $0.interfaceOrientation == .portrait }),
                      self.perceptionResultAllowed(request: request, generation: generation, capturedAt: capturedAt,
                          observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else { return }
                // Coloured illumination can make white fabric appear saturated. Precise neutral
                // verification always abstains, even when an appearance candidate was available.
                self.message = (preciseNeutral ? ClothingColor.Result.nearNeutral : result).speech(arabic: self.arabic)
                _ = self.speakRequested(self.message, narrationID: request)
            } catch is CancellationError {
                return
            } catch {
                guard self.requestID == request, self.colorActive, self.attention.stationary,
                      self.visualCapturePoseAllowed(origin: colorOrigin, forward: colorForward),
                      ClothingColorCapturePolicy.fresh(capturedAt: capturedAt, now: ProcessInfo.processInfo.systemUptime),
                      self.perceptionResultAllowed(request: request, generation: generation, capturedAt: capturedAt,
                          observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else { return }
                self.message = self.arabic ? "لم أستطع عزل منطقة القماش. أمسك غرضاً واحداً منفصلاً ومسطحاً في وسط الكاميرا، بعيداً عن الجلد والشعر والظلال واللمعان، ثم حاول مجدداً." : "I couldn't isolate the fabric area. Hold one separate item flat in the centre, away from skin, hair, shadows and glare, then try again."
                _ = self.speakOperation(self.message)
            }
        }
        return true
    }

    private func visualCapturePoseAllowed(origin: Point3, forward: Point3) -> Bool {
        guard let frame = session.currentFrame else { return false }
        let transform = frame.camera.transform
        let current = Point3(Double(transform.columns.3.x), Double(transform.columns.3.y), Double(transform.columns.3.z))
        let direction = Point3(-Double(transform.columns.2.x), -Double(transform.columns.2.y), -Double(transform.columns.2.z))
        return RequestedVisualCapturePose.poseStable(origin: origin, current: current, originForward: forward, currentForward: direction)
    }

    func readScene(cloud: Bool, question: String = "Describe what is in front of me.", automatic: Bool = false, focus: String = "surroundings") {
        #if !BLIND_DEVELOPER_CLOUD
        // Privacy rule (AGENTS.md): camera pictures never leave the phone in the app build.
        let cloud = false
        #endif
        if !automatic { stopReadingTool(announce: false) }
        if !automatic, routeUnavailableTemperature(question) { return }
        if !automatic, routeUnverifiedPhysicalRequest(question) { return }
        if !automatic, routeSaudiBanknoteCommand(question) { return }
        if !automatic, routeClothingColorCommand(question) { return }
        if !automatic, routeReadingToolCommand(question) { return }
        // Anything else the child says ends a running reading tool, so two things never talk at once.
        if !automatic, readingTool != nil { stopReadingTool(announce: false) }
        if automatic, currencyActive || colorActive || readingTool != nil || currencyRetake.isPending { return }
        #if BLIND_FAMILIAR_PEOPLE
        if !automatic, routeFamiliarPeopleCommand(question) { return }
        if !automatic { familiarPeople.cancelSearchForNewGoal() }
        #endif
        if !automatic, handleAssistantControl(question) { return }
        if !automatic { cancelDescription() }
        // Saved items and live "where is it" answers come from sensors first (E13/E14).
        if !automatic, let utterance = CompanionUtterance.parse(question) {
            answerCompanionUtterance(utterance, question: question); return
        }
        if !automatic, handleItemOrLocate(question) { return }
        // A precise neutral/uniform question not understood by the command grammar must still
        // never reach a model that could answer "yes" without repeating a colour word.
        if !automatic, ClothingColorCommand.requiresNeutralVerification(question) {
            message = ClothingColor.Result.nearNeutral.speech(arabic: arabic)
            _ = speakRequested(message)
            return
        }
        if !automatic, let goal = AssistantControl.explicitGoal(question) {
            objectiveDraft = goal; setAssistantObjective(); assistantQuestion = goal
            if indoor.map != nil { findMapDestination() }
            else {
                message = arabic ? "حُفظ الهدف. لم تُحدد خريطة للوصول إليه بعد." : "Goal saved. A map for reaching it has not been selected yet."
                _ = speakOperation(message)
            }
            return
        }
        if !automatic { pendingQuestion = nil; if busy { cancelDescription() } }
        if automatic, pendingQuestion != nil { return }
        if automatic, assistantPreferences.automaticCategories.isEmpty { return }
        guard !automatic || feedback.canSpeakAmbient else { return }
        // Goal-led attention (E02/E12): skip generating an automatic description that would not be
        // spoken — quiet, too soon, an offer awaiting an answer, or walking toward a goal.
        if automatic {
            let now = ProcessInfo.processInfo.systemUptime
            let probe = InformationCandidate(key: "view:probe", kind: .discovery, text: "", words: 1,
                                             revision: UUID().uuidString, createdAt: now, expiresAt: now + 6)
            guard case .say = companion.check(probe, moment: companionMoment(now), settings: companionSettings) else { return }
        }
        guard !cloud || !offlineOnly else { message = "Offline mode is enabled."; return }
        guard running, !simulation, !places.scanning, !busy, detection.hazard == .observing,
              let origin = lastObservation?.camera,
              let originForward = lastObservation?.forward,
              let frame = session.currentFrame, ProcessInfo.processInfo.systemUptime - lastFrameWallTime < 0.5 else {
            if !automatic {
                answerConversation(question)
            }
            return
        }
        if !automatic, !feedback.canSpeakAmbient {
            queueQuestion(question, cloud: cloud, focus: focus, camera: origin, forward: originForward)
            return
        }
        voice.endManualTurn()
        // Moving toward a goal: fewest words needed, fewer the faster they walk (user, 2026-10-09);
        // full detail when still, in a room description, or asked.
        let standard = detail == .minimal ? 25 : detail == .balanced ? 55 : 110
        let maximum = focus == "room" || attention.stationary ? standard
            : AttentionPolicy.guidanceWords(speed: attention.speed, goalActive: !assistantDialogue.goal.isEmpty, standardLimit: standard)
        let allowance = min(maximum, narrationBudget.allowance(limit: wordsPerMinute, now: ProcessInfo.processInfo.systemUptime))
        guard allowance > 0 else { if !automatic { message = arabic ? "وصل الوصف إلى حد الكلمات الذي اخترته. انتظر قليلاً أو عدّله في الإعدادات." : "Your narration word allowance is used. Wait briefly or adjust it in Settings." }; return }
        if !automatic { assistantDialogue.record(role: "user", text: question); persistDialogue() }
        let dialogue = assistantDialogue
        let sessionGeneration = assistantSession.generation
        let preview = recognizedPlace
        let roomLayout = preview.flatMap { places.layout(for: $0) }
        let interestRevision = preferencesRevision
        let interests = assistantPreferences
        let history = narrationHistory.filter { $0.sessionID == narrationSession.uuidString && $0.goalRevision == dialogue.goalRevision }
        let mapRevision = indoor.revision, alignmentRevision = indoor.alignmentRevision
        let navigation = indoor.situation(camera: origin, forward: originForward,
            frameAge: ProcessInfo.processInfo.systemUptime - lastFrameWallTime,
            tracking: lastObservation?.trackingNormal == true, fixedBodyMount: fixedBodyMount, bodyForward: currentBodyForward())
        var initialSituation = AssistantSituation.snapshot(dialogue: dialogue, preview: preview, layout: roomLayout,
            preferences: assistantPreferences, narration: history, navigation: navigation, arabic: arabic)
        let visualTracks = peopleTracking.snapshot(at: ProcessInfo.processInfo.systemUptime)
        initialSituation["visualTracks"] = visualTracks
        let situationCreatedAt = ProcessInfo.processInfo.systemUptime
        let image = frame.capturedImage, capturedAt = lastFrameWallTime
        busy = true; questionIsAutomatic = automatic; questionIsChat = false
        let currentRequest = UUID(); requestID = currentRequest
        questionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let timing = AssistantPerformance.signposter.beginInterval("SceneResponse", id: AssistantPerformance.signposter.makeSignpostID())
            defer { AssistantPerformance.signposter.endInterval("SceneResponse", timing) }
            defer { if self.requestID == currentRequest { self.busy = false; self.questionIsAutomatic = false } }
            do {
                let answer: String
                // Model-written text passes the spatial safety check; code-rendered sensor text does not need it.
                var fromModel = false
                let arabic = self.arabic
                let result = try await Task.detached(priority: .userInitiated) {
                    try VisionService.inspect(image: image, orientation: .right, arabic: arabic, capturedAt: capturedAt)
                }.value
                try Task.checkCancellation()
                // Grounding (2026-10-22): a model may name an object as fact only when the phone's
                // detectors agreed on it in at least two of three frames a moment apart.
                var groundingFrames = [result.grounding]
                var groundingTimestamps: Set<TimeInterval> = [frame.timestamp]
                for _ in 0..<2 {
                    try await Task.sleep(for: .milliseconds(150))
                    guard self.requestID == currentRequest, let laterFrame = self.session.currentFrame,
                          laterFrame.timestamp > frame.timestamp,
                          !groundingTimestamps.contains(laterFrame.timestamp),
                          ProcessInfo.processInfo.systemUptime - self.lastFrameWallTime < 0.5 else { break }
                    groundingTimestamps.insert(laterFrame.timestamp)
                    let later = laterFrame.capturedImage
                    if let extra = try? await Task.detached(priority: .userInitiated, operation: {
                        try VisionService.groundingFrame(image: later, orientation: .right)
                    }).value { groundingFrames.append(extra) }
                }
                try Task.checkCancellation()
                let confirmedObjects = VisualGrounding.agreedObjects(groundingFrames)
                let situation = AssistantSituation.aged(initialSituation, milliseconds: (ProcessInfo.processInfo.systemUptime - situationCreatedAt) * 1000)
                var evidence = result.observations.filter {
                    focus == "people" ? $0.kind == .people : focus == "text" ? $0.kind == .text : true
                }
                if automatic {
                    evidence = evidence.filter { item in
                        let category = item.kind == .people ? "social" : item.kind == .text ? "signs" : "objects"
                        return interests.mode(for: category) == "automatic"
                    }
                }
                if focus == "surroundings" || focus == "object" {
                    evidence += self.wearables.rangeEvidence(at: ProcessInfo.processInfo.systemUptime, arabic: arabic)
                }
                let context = SceneContext(observations: evidence, at: ProcessInfo.processInfo.systemUptime,
                    arabic: arabic, detail: self.detail, stationary: self.attentionMode == .stationary,
                    hazard: self.detection.hazard, requested: !automatic)
                if cloud {
                    let ci = CIImage(cvPixelBuffer: image).oriented(.right)
                    let scale = min(1, 1024 / max(ci.extent.width, ci.extent.height))
                    let resized = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    guard let cg = self.imageContext.createCGImage(resized, from: resized.extent),
                          let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.7) else { throw SceneClientError.invalidReply }
                    #if BLIND_DEVELOPER_CLOUD
                    answer = try await SceneQuestionClient(endpoint: self.serviceURL, token: TokenStore.read())
                        .ask(question: question, jpeg: jpeg, context: context, focus: focus, situation: situation, wordAllowance: allowance)
                    fromModel = true
                    #else
                    _ = jpeg
                    throw SceneClientError.invalidReply
                    #endif
                } else {
                    if focus == "path" {
                        answer = arabic ? "استخدم تبويب المسارات لتحديد وجهة. لا يكفي وصف الصورة لتحديد مسار قابل للمشي." : "Use Routes to select a destination. A scene description does not establish a walkable route."
                    } else {
                        let local = await LocalImageAssistant.describe(image: image, question: question, context: context,
                                                                       situation: situation, wordAllowance: allowance,
                                                                       confirmedObjects: Array(confirmedObjects))
                        try Task.checkCancellation()
                        guard self.requestID == currentRequest else { return }
                        self.localImageStatus = local.status
                        // Unhedged sentences naming objects the detectors did not confirm are dropped.
                        let grounded = local.text.map { VisualGrounding.groundedDescription($0, confirmed: confirmedObjects) } ?? ""
                        if !grounded.isEmpty { answer = grounded; fromModel = true }
                        else if context.observations.isEmpty {
                            if automatic { return }
                            answer = arabic ? "لم أتعرف على تفاصيل مؤكدة في هذه الصورة." : "I could not identify confident details in this view."
                        } else { answer = await OfflineSummary.summarize(context, question: question, dialogue: dialogue, preferences: interests) }
                    }
                }
                try Task.checkCancellation()
                guard self.requestID == currentRequest, self.assistantDialogue.goalRevision == dialogue.goalRevision,
                      self.preferencesRevision == interestRevision,
                      self.indoor.revision == mapRevision, self.indoor.alignmentRevision == alignmentRevision else { return }
                guard self.recognizedPlace?.id == preview?.id else { return }
                if let preview, self.places.layout(for: preview)?.revisionID != roomLayout?.revisionID { return }
                guard self.peopleTracking.stillMatches(visualTracks, at: ProcessInfo.processInfo.systemUptime) else {
                    self.message = arabic ? "تغير الأشخاص في مجال الكاميرا. اطلب وصفاً حديثاً." : "People in the camera view changed. Request an updated description."
                    return
                }
                guard WearableEvidence.stillMatches(context.observations,
                    current: self.wearables.rangeEvidence(at: ProcessInfo.processInfo.systemUptime, arabic: arabic)) else {
                    self.message = arabic ? "تغيرت قراءات الحساسات أو انقطع وصولها. اطلب وصفاً جديداً." : "Sensor readings changed or became unavailable. Request a new description."
                    return
                }
                guard SceneDelivery.allowed(capturedAt: capturedAt, now: ProcessInfo.processInfo.systemUptime,
                    origin: origin, current: self.lastObservation?.camera, currentFrameAt: self.lastFrameWallTime,
                    hazard: self.detection.hazard, tracking: self.lastObservation?.trackingNormal == true,
                    originForward: originForward, currentForward: self.lastObservation?.forward) else {
                    self.message = "The view changed before the answer was ready. Request a new description."; return
                }
                // Generic VLM and OCR summaries cannot bypass dedicated money recognition.
                if SaudiBanknotePolicy.containsUnverifiedMoneyValue(answer) {
                    if !automatic {
                        self.message = arabic ? "لن أخمّن قيمة النقود من وصف عام. اطلب قراءة ورقة نقدية واحدة." : "I won't identify money from a general scene description. Ask me to read one banknote."
                        _ = self.speakOperation(self.message)
                    }
                    return
                }
                // A model cannot certify clothing colour or overwrite a qualified camera reading.
                // Code-produced OCR remains readable verbatim; this veto applies to model claims.
                if fromModel && ClothingColorCommand.containsUnverifiedColorClaim(answer) {
                    if !automatic {
                        self.message = arabic ? "لن أخمّن لون القماش من وصف عام. أمسك الغرض في الوسط واطلب فحص اللون." : "I won't guess fabric colour from a general description. Hold the item in the centre and ask me to check its colour."
                        _ = self.speakOperation(self.message)
                    }
                    return
                }
                // Spatial safety rule (AGENTS.md, E13): hazard geometry, step counts, clear-path
                // statements and unhedged distances from a model are never spoken.
                if fromModel && SpatialClaimGuard.containsSpatialClaim(answer) {
                    // The rule allows saying a hazard is visible: keep that warning even though the
                    // model's position or distance for it is not spoken (also for automatic answers).
                    let hazardSeen = SpatialClaimGuard.mentionsHazard(answer)
                    if !automatic || hazardSeen {
                        self.message = hazardSeen
                            ? (arabic ? "قد تُظهر الكاميرا درجاً أو عائقاً. هذا لا يحدد موقع الخطر أو سلامة الطريق." : "The camera may show stairs, a step or an obstacle. This does not establish its position or a safe path.")
                            : (arabic ? "حذفتُ إجابة فيها مسافة لم تقسها الحساسات." : "I held back an answer with a distance the sensors had not measured.")
                        _ = self.speakOperation(self.message)
                    }
                    return
                }
                if automatic && !self.ambientDescriptions { return }
                let words = Self.wordCount(answer)
                let now = ProcessInfo.processInfo.systemUptime
                guard words > 0, words <= allowance,
                      words <= self.narrationBudget.allowance(limit: self.wordsPerMinute, now: now) else {
                    if !automatic { self.message = "The answer exceeded your word allowance. Request a shorter answer or increase the allowance." }; return
                }
                // Automatic descriptions go through the companion engine: what is in view must have
                // changed (evidence revision), and goal, quiet, offers and frequency all apply.
                let revision = Set(context.observations.map { "\($0.kind.rawValue):\($0.text)" }).sorted().joined(separator: "|")
                let candidate = InformationCandidate(key: automatic ? "view:\(self.companion.currentRoom ?? "unknown")" : "answer:\(currentRequest)",
                    kind: automatic ? .discovery : .answer, text: answer, words: words,
                    revision: automatic ? (revision.isEmpty ? answer : revision) : currentRequest.uuidString,
                    createdAt: capturedAt, expiresAt: capturedAt + 6, requested: !automatic)
                let spoken = self.deliverCandidate(candidate, narrationID: currentRequest)
                guard spoken else {
                    if !automatic { self.queueQuestion(question, cloud: cloud, focus: focus, camera: origin, forward: originForward) }
                    return
                }
                let sessionID = self.narrationSession, at = Date()
                let snapshotID = situation["snapshotID"] as? String ?? currentRequest.uuidString
                let sourceIDs = context.observations.map(\.id) + (roomLayout?.revisionID.map { [$0] } ?? []) + (navigation.map { [$0.revision] } ?? [])
                self.enqueueNarration { try await $0.start(id: currentRequest, sessionID: sessionID,
                    goalRevision: dialogue.goalRevision, snapshotID: snapshotID, sourceIDs: sourceIDs, text: answer, at: at) }
                self.narrationBudget.charge(words: words, limit: self.wordsPerMinute, now: now)
                self.sceneAnswer = answer; self.currentReply = answer
                self.lastSceneContent = answer; self.lastSceneSpoken = ProcessInfo.processInfo.systemUptime
                if !automatic {
                    self.requestedVisualDialogue = (currentRequest, self.assistantSession.generation)
                }
            } catch is CancellationError {} catch {
                if self.requestID == currentRequest { self.sceneAnswer = error.localizedDescription }
            }
        }
    }
    private static func wordCount(_ text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word); tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).count
    }
    /// One admission point for new candidates; approved producers use the private
    /// already-admitted path so the same words are never charged twice here.
    @discardableResult private func deliverCandidate(_ candidate: InformationCandidate,
        alreadyAdmitted: Bool = false, narrationID: UUID? = nil, speechID: UUID? = nil, alert: Detection? = nil) -> Bool {
        guard !textOnly else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        guard candidate.createdAt <= now, now <= candidate.expiresAt else { return false }
        if candidate.kind == .hazard {
            cancelDescription(); companion.withdrawOffer(); companionOffer = nil
            roomOfferCandidate = nil; roomQuestionCandidate = nil
            #if BLIND_FAMILIAR_PEOPLE
            if familiarPeople.enabled && familiarPeople.hasActiveWork { familiarPeople.cancel() }
            #endif
        } else if candidate.kind != .mobility {
            // Lost monitoring (uncertain / needs calibration) silences ambient descriptions, but the
            // child's own answers and short operation replies are still spoken; urgent hazards block all.
            let direct = candidate.kind == .operation || (candidate.kind == .answer && candidate.requested)
            let blocked = direct ? detection.hazard.isUrgent : detection.hazard.requiresImmediateAttention
            guard !voice.awaitingUtterance, !running || !blocked else { return false }
        }
        if !alreadyAdmitted {
            guard case .say = companion.decide([candidate], moment: companionMoment(now), settings: companionSettings).first else { return false }
        }
        let admitted = AdmittedSpeech(candidate)
        let spoken = feedback.deliver(admitted, narrationID: narrationID, speechID: speechID, alert: alert)
        if !spoken { companion.release(candidate.key) }
        if spoken, candidate.kind == .answer, candidate.requested, speechID == nil, narrationID == nil {
            currentReply = candidate.text
        }
        return spoken
    }
    @discardableResult private func dispatchText(_ text: String, kind: InformationCandidate.Kind,
        requested: Bool = false, replace: Bool = false, revision: String = UUID().uuidString,
        narrationID: UUID? = nil, speechID: UUID? = nil, alert: Detection? = nil) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let candidate = InformationCandidate(key: "speech:" + revision, kind: kind, text: text,
            words: Self.wordCount(text), revision: revision, createdAt: now, expiresAt: now + 2,
            requested: requested)
        if replace { _ = feedback.stopInformation(announceCancellation: false) }
        let delivered = deliverCandidate(candidate, narrationID: narrationID, speechID: speechID, alert: alert)
        if replace && !delivered { feedback.requestCancellationAnnouncement() }
        return delivered
    }
    /// Descriptive answers and repeats retain normal information budgets.
    @discardableResult func speakRequested(_ text: String, replace: Bool = true, narrationID: UUID? = nil, speechID: UUID? = nil) -> Bool {
        dispatchText(text, kind: .answer, requested: true, replace: replace, narrationID: narrationID, speechID: speechID)
    }
    /// Only short current-action consent/progress/confirmation/error, never scene descriptions.
    @discardableResult func speakOperation(_ text: String, replace: Bool = true, revision: String = UUID().uuidString) -> Bool {
        if textOnly { sceneAnswer = text; return false }
        return dispatchText(text, kind: .operation, requested: true, replace: replace, revision: revision)
    }
    @discardableResult private func speakMobility(_ text: String) -> Bool { dispatchText(text, kind: .mobility) }
    private func announceDetection(_ value: Detection, requested: Bool = false) {
        let kind: InformationCandidate.Kind = value.hazard.requiresImmediateAttention ? .hazard : requested ? .answer : .mobility
        _ = dispatchText(GuidanceText.detection(value, arabic: arabic), kind: kind, requested: requested,
            replace: requested && !value.hazard.requiresImmediateAttention, alert: value)
    }
    func testFeedback() {
        _ = dispatchText(arabic ? "اختبار التنبيه. ليس خطراً مقاساً." : "Alert test. This is not a measured hazard.", kind: .operation,
            requested: true, replace: true, alert: Detection(.obstacle))
    }
    private var focusedFaceSearch: Bool {
        #if BLIND_FAMILIAR_PEOPLE
        return familiarPeople.isSearching
        #else
        return false
        #endif
    }
    private var companionSettings: CompanionSettings {
        CompanionSettings(firstVisitRooms: firstVisitRooms, minimumGap: Double(narrationInterval), wordsPerMinute: wordsPerMinute,
                          preferences: assistantPreferences, quiet: !ambientDescriptions, offerWindow: 14)
    }
    private func companionMoment(_ now: Double) -> CompanionMoment {
        CompanionMoment(now: now, goalActive: !assistantDialogue.goal.isEmpty, focusedTaskActive: focusedFaceSearch || currencyActive || currencyRetake.isPending || colorActive || objectSearch != nil || busy || pendingQuestion != nil || lookupInFlight || readingTool != nil,
                        activity: attention.stationary ? .stationary : lastObservation?.trackingNormal == true ? .moving : .unknown,
                        speaking: feedback.speechPriority)
    }
    private func persistCompanion() {
        guard let memory = places.memory, let data = try? JSONEncoder().encode(companion.memory) else { return }
        try? memory.saveValue(namespace: "companion", id: "memory", payload: data)
    }
    /// Room familiarity and first-visit offers. Manual alignment or a recognised saved place
    /// establishes the room for familiarity only; geometry and clearance stay with the sensors.
    private func updateCompanionRoom(_ observation: Observation) {
        let now = lastFrameWallTime
        guard now - lastCompanionTick >= 0.5 else { return }
        lastCompanionTick = now
        let situation = indoor.isAligned ? indoor.situation(camera: observation.camera, forward: observation.forward,
            frameAge: 0, tracking: observation.trackingNormal, fixedBodyMount: fixedBodyMount, bodyForward: currentBodyForward()) : nil
        alignedRoomID = situation?.roomID
        let roomID = situation?.roomID ?? recognizedPlace.map { "place:\($0.id.uuidString)" } ?? recognizedRoomID
        let roomName = situation?.roomName ?? recognizedPlace?.name ?? roomID.flatMap { companion.memory.rooms[$0]?.name }
        if let entry = companion.observeRoom(roomID, established: roomID != nil && observation.trackingNormal, now: now) {
            if let roomID, let roomName { companion.memory.rooms[roomID, default: RoomRecord()].name = roomName }
            if let previous = establishedRoomHistory.last, previous != roomID { leftRoomID = previous }
            if let roomID { establishedRoomHistory = Array((establishedRoomHistory + [roomID]).suffix(4)) }
            persistCompanion()
            roomOfferCandidate = nil
            if entry == .firstVisit, let roomID, let roomName {
                let text = arabic ? "غرفة جديدة: \(roomName). هل تريد وصفها؟" : "New room, \(roomName). Want a description?"
                roomOfferCandidate = InformationCandidate(key: "room:\(roomID):offer", kind: .offer, text: text,
                    words: Self.wordCount(text), createdAt: now, expiresAt: now + 120, room: roomID, offerKind: .describeRoom)
            }
        }
        if roomID == nil { roomOfferCandidate = nil }
        if companion.pendingOffer == nil { companionOffer = nil }
        let candidates = [roomOfferCandidate, roomQuestionCandidate].compactMap { $0 }
        guard !candidates.isEmpty, detection.hazard == .observing, !voice.awaitingUtterance else { return }
        for decision in companion.decide(candidates, moment: companionMoment(now), settings: companionSettings) {
            switch decision {
            case .offer(let offer, _):
                if offer.kind == .confirmRoom { roomQuestionCandidate = nil } else { roomOfferCandidate = nil }
                if firstVisitRooms == .describe, offer.kind == .describeRoom {
                    // Same timing gates as an offer, without asking first.
                    companion.answerOffer(.yes)
                    readScene(cloud: false, question: arabic ? "صف هذه الغرفة." : "Describe this room.", focus: "room")
                } else if feedback.canSpeakAmbient, deliverCandidate(InformationCandidate(key: "offer:" + offer.subject,
                    kind: .offer, text: offer.prompt, words: Self.wordCount(offer.prompt), createdAt: now,
                    expiresAt: offer.expiresAt), alreadyAdmitted: true) { companionOffer = offer }
                else { companion.withdrawOffer() }
            case .drop(let key, _):
                if key == roomQuestionCandidate?.key { roomQuestionCandidate = nil } else if key == roomOfferCandidate?.key { roomOfferCandidate = nil }
            case .say, .wait: break
            }
        }
    }
    /// Spoken yes/no, or the on-screen buttons. A yes runs the offer as the person's own request.
    func answerCompanionOffer(_ answer: OfferAnswer) {
        let accepted = companion.answerOffer(answer)
        companionOffer = nil; persistCompanion()
        guard let offer = accepted else { return }
        switch offer.kind {
        case .describeRoom:
            readScene(cloud: false, question: arabic ? "صف هذه الغرفة." : "Describe this room.", focus: "room")
        case .confirmRoom:
            companion.userConfirmedRoom(offer.subject); persistCompanion()
            userConfirmedRoomID = offer.subject
        case .suggestion, .itemDirections:
            readScene(cloud: false, question: offer.prompt)
        }
    }
    func setAssistantObjective() {
        #if BLIND_FAMILIAR_PEOPLE
        familiarPeople.cancelSearchForNewGoal()
        #endif
        cancelDescription(); feedback.stop(); stopReturn(); indoor.invalidatePosition()
        assistantDialogue.setGoal(objectiveDraft); objectiveDraft = assistantDialogue.goal; persistDialogue()
        companionWorkingState.changeGoal(assistantDialogue.goal); persistWorkingState()
    }
    func clearAssistantConversation() {
        #if BLIND_FAMILIAR_PEOPLE
        familiarPeople.cancelSearchForNewGoal()
        #endif
        cancelDescription(); feedback.stop(); stopReturn(); indoor.invalidatePosition()
        assistantDialogue = AssistantDialogue(); objectiveDraft = ""; persistDialogue()
        companionWorkingState = CompanionWorkingState(); persistWorkingState()
        sceneAnswer = ""; currentReply = ""; assistantQuestion = ""
    }
    @discardableResult func correctConversationRecord(id: String, replacement: String) -> Bool {
        guard let original = assistantDialogue.userRecords.first(where: { $0.id == id }),
              assistantDialogue.correctUserRecord(id: id, replacement: replacement) else { return false }
        cancelDescription(); _ = feedback.stopInformation(announceCancellation: false)
        companionWorkingState.removeReport(original.text)
        companionWorkingState.record(replacement)
        companionWorkingState.changeGoal(assistantDialogue.goal)
        objectiveDraft = assistantDialogue.goal
        stopReturn(); indoor.invalidatePosition()
        persistDialogue(); persistWorkingState()
        return true
    }

    func forgetConversationRecord(id: String) {
        guard let original = assistantDialogue.userRecords.first(where: { $0.id == id }),
              assistantDialogue.forgetUserRecord(id: id) else { return }
        cancelDescription(); _ = feedback.stopInformation(announceCancellation: false)
        companionWorkingState.removeReport(original.text)
        companionWorkingState.changeGoal(assistantDialogue.goal)
        objectiveDraft = assistantDialogue.goal
        stopReturn(); indoor.invalidatePosition()
        persistDialogue(); persistWorkingState()
    }

    func savePreferredName(_ draft: String) {
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count <= 80, !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            profileStatus = arabic ? "استخدم اسماً لا يتجاوز ٨٠ حرفاً." : "Use a name of at most 80 characters."
            return
        }
        do {
            guard let memory = places.memory else { throw CocoaError(.fileWriteUnknown) }
            try memory.saveValue(namespace: "preferences", id: "preferred-name", payload: JSONEncoder().encode(name))
            cancelDescription()
            preferredName = name
            profileStatus = name.isEmpty ? (arabic ? "حُذف الاسم المحفوظ." : "Saved name removed.") : (arabic ? "حُفظ الاسم على هذا الهاتف." : "Name saved on this phone.")
        } catch {
            profileStatus = arabic ? "تعذر حفظ الاسم." : "Could not save the name."
        }
    }

    private func persistWorkingState() {
        do {
            guard let memory = places.memory else { throw CocoaError(.fileWriteUnknown) }
            try memory.saveValue(namespace: "companion", id: "working-state", payload: JSONEncoder().encode(companionWorkingState))
        } catch { message = "Task context could not be saved on this phone." }
    }

    private func persistDialogue() {
        do {
            guard let memory = places.memory else { throw CocoaError(.fileWriteUnknown) }
            try memory.saveValue(namespace: "dialogue", id: "active", payload: JSONEncoder().encode(assistantDialogue))
        } catch { message = "Conversation could not be saved. Current location will still be re-established after restart." }
    }
    @discardableResult func addAssistantInterest(category: String, value: String) -> Bool {
        var updated = assistantPreferences
        guard updated.add(category: category, value: value) else {
            preferenceError = arabic ? "اكتب تفضيلاً غير مكرر وغير فارغ بحد أقصى ٣٠٠ حرف. يمكنك حفظ ١٦ تفضيلاً." : "Use a unique, nonempty preference of at most 300 characters. Up to 16 can be saved."
            return false
        }
        return saveAssistantPreferences(updated)
    }
    func removeAssistantInterest(id: String) {
        var updated = assistantPreferences; updated.remove(id: id); _ = saveAssistantPreferences(updated)
    }
    func setAssistantCategory(_ category: String, mode: String) {
        var updated = assistantPreferences
        guard updated.setMode(mode, for: category) else { return }
        _ = saveAssistantPreferences(updated)
    }
    private func saveAssistantPreferences(_ value: AssistantPreferences) -> Bool {
        do {
            guard value.valid, let memory = places.memory else { throw CocoaError(.fileWriteUnknown) }
            try memory.saveValue(namespace: "preferences", id: "interests", payload: JSONEncoder().encode(value))
            cancelDescription(); feedback.interruptAmbient(); preferencesRevision = UUID(); assistantPreferences = value; preferenceError = ""; return true
        } catch {
            preferenceError = arabic ? "تعذر حفظ التفضيلات. بقيت التفضيلات السابقة دون تغيير." : "Preferences could not be saved. Previous preferences remain unchanged."
            message = preferenceError; return false
        }
    }
    private func enqueueNarration(_ operation: @escaping @Sendable (NarrationJournal) async throws -> [NarrationRecord]) {
        guard let journal = narrationJournal else {
            narrationHistoryError = arabic ? "سجل الأوصاف غير متاح." : "Description history is unavailable."; return
        }
        let previous = journalTask
        journalTask = Task { @MainActor [weak self] in
            // Preserve start/finish/delete order while database work runs on its own actor.
            await previous?.value
            do {
                let result = try await operation(journal)
                self?.narrationHistory = result; self?.narrationHistoryError = ""
            } catch {
                self?.narrationHistoryError = self?.arabic == true ? "تعذر حفظ سجل الأوصاف." : "Description history could not be saved."
            }
        }
    }
    func clearNarrationHistory() {
        cancelDescription(); feedback.interruptAmbient()
        enqueueNarration { try await $0.clear() }
    }
    func receiveCompanionUtterance(_ text: String, fromVoice: Bool = false) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars,
              !fromVoice || assistantSession.shouldListen else { return }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
        if ["i'm standing on a level floor", "i am standing on a level floor", "أنا واقف على أرض مستوية"].contains(normalized),
           running && detection.hazard == .needsCalibration { calibrate(); return }
        let pendingRetake = currencyRetake
        cancelDescription()
        _ = feedback.stopInformation(announceCancellation: false)
        if pendingRetake.isPending, CurrencyRetakeSession.isRetryCommand(text) {
            retryCurrencyCapture(pendingRetake); return
        }
        switch ConversationIntent.classify(text) {
        case .sessionControl(let control):
            switch control {
            case .mute: muteConversation()
            case .unmute, .start: startConversation()
            case .end: endConversation()
            }
            return
        case .taskControl(let control):
            handleConversationTaskControl(control)
            return
        case .conversation, .visualRequest: break
        }
        if routeUnavailableTemperature(text) { return }
        if routeUnverifiedPhysicalRequest(text) { return }
        #if BLIND_FAMILIAR_PEOPLE
        if routeFamiliarPeopleCommand(text) { return }
        familiarPeople.cancelSearchForNewGoal()
        #endif
        if companion.pendingOffer != nil, let answer = AssistantControl.offerAnswer(text) {
            answerCompanionOffer(answer); return
        }
        assistantQuestion = text
        // Existing domain commands keep their code-owned gates. Ordinary conversation
        // no longer becomes image generation merely because the camera is running.
        if routeSaudiBanknoteCommand(text) || routeClothingColorCommand(text) || routeReadingToolCommand(text) { return }
        if let utterance = CompanionUtterance.parse(text) {
            answerCompanionUtterance(utterance, question: text); return
        }
        if handleAssistantControl(text) { return }
        if let goal = ConversationIntent.explicitTaskGoal(text) {
            // Commit only a whole explicit request, before any model/extraction.
            // A change of task preserves the conversation and does not start sensors.
            companionWorkingState.changeGoal(goal)
            assistantDialogue.setGoal(goal); objectiveDraft = assistantDialogue.goal
            stopReturn(); indoor.invalidatePosition()
            persistWorkingState(); persistDialogue()
        }
        if handleItemOrLocate(text) { return }
        if AssistantControl.explicitGoal(text) != nil {
            readScene(cloud: false, question: text); return
        }
        if case .visualRequest = ConversationIntent.classify(text) {
            readScene(cloud: false, question: text)
        } else {
            answerConversation(text)
        }
    }

    private func handleConversationTaskControl(_ control: AssistantTaskControl) {
        switch control {
        case .pause:
            let suspended = companionWorkingState.suspendGoal()
            sceneAnswer = suspended ? (arabic ? "أوقفت المهمة مؤقتاً. يمكننا التحدث عن شيء آخر." : "I've paused that task. We can talk about something else.") : (arabic ? "لا توجد مهمة جارية لإيقافها." : "There is no active task to pause.")
        case .resume:
            let resumed = companionWorkingState.resumeGoal()
            sceneAnswer = resumed ? (arabic ? "استعدت هدفك السابق. سأتحقق من المعلومات الحالية قبل المتابعة." : "I've restored your previous goal. Current conditions still need checking.") : (arabic ? "لا توجد مهمة موقوفة يمكن استعادتها الآن." : "There is no paused task I can resume right now.")
        case .cancel:
            companionWorkingState.changeGoal("")
            sceneAnswer = arabic ? "ألغيت المهمة الحالية." : "I've cancelled the current task."
        }
        assistantDialogue.setGoal(companionWorkingState.goal)
        objectiveDraft = companionWorkingState.goal
        stopReturn(); indoor.invalidatePosition()
        persistWorkingState(); persistDialogue()
        currentReply = sceneAnswer
        if assistantSession.state == .active { _ = speakRequested(sceneAnswer) }
    }

    private func queueConversationSpeech(_ text: String, request: UUID, generation: UInt64, reports: [String] = [], evidence: [CompanionEvidence] = [], codeOwned: Bool = false) {
        guard !textOnly, assistantSession.state == .active,
              assistantSession.accepts(generation: generation), requestID == request,
              (codeOwned || !SpatialClaimGuard.containsSpatialClaim(text)), conversationSpeech.count < 4 else { return }
        let current = evidence.filter { $0.kind == .currentObservation || ($0.kind == .measuredState && !CompanionClock.isClockEvidence($0)) }
        let captures = current.compactMap { conversationEvidenceCaptures[$0.id] }
        guard captures.count == current.count else { return }
        conversationSpeech.append(ConversationSpeech(id: UUID(), text: text, request: request,
            generation: generation, createdAt: ProcessInfo.processInfo.systemUptime,
            reports: reports, evidence: evidence, captures: captures, codeOwned: codeOwned))
        drainConversationSpeech()
    }

    private func drainConversationSpeech() {
        guard activeConversationSpeech == nil, feedback.speechPriority == nil, !voice.awaitingUtterance else { return }
        while !conversationSpeech.isEmpty {
            let next = conversationSpeech.removeFirst()
            guard requestID == next.request, assistantSession.state == .active,
                  assistantSession.accepts(generation: next.generation),
                  ProcessInfo.processInfo.systemUptime - next.createdAt < 30,
                  (next.codeOwned || CompanionEvidenceGuard.allows(next.text, reports: next.reports, evidence: next.evidence, now: Date())) else { continue }
            guard next.captures.allSatisfy({ capture in
                capture.perception == perceptionGeneration && assistantSession.foregroundActive && running && !simulation &&
                SceneDelivery.allowed(capturedAt: capture.capturedAt, now: ProcessInfo.processInfo.systemUptime,
                    origin: capture.observation.camera, current: lastObservation?.camera, currentFrameAt: lastFrameWallTime,
                    hazard: detection.hazard, tracking: lastObservation?.trackingNormal == true,
                    originForward: capture.observation.forward, currentForward: lastObservation?.forward)
            }) else { continue }
            activeConversationSpeech = next
            if speakRequested(next.text, replace: false, speechID: next.id) { return }
            activeConversationSpeech = nil
            // A rejected/budgeted phrase is not delivered history and is not retried forever.
        }
    }

    /// Executable, read-only tools. Every result is bounded and identifies its source;
    /// none starts a camera, navigates, enrolls a face or changes a user's records.
    @MainActor private func readCompanionToolForTurn(_ request: CompanionToolRequest, id: UUID, generation: UInt64) async -> CompanionToolResult {
        guard !Task.isCancelled, requestID == id, assistantSession.generation == generation else {
            return CompanionToolResult(status: .cancelled, source: "session controller")
        }
        let result = await readCompanionTool(request)
        guard !Task.isCancelled, requestID == id, assistantSession.generation == generation else {
            return CompanionToolResult(status: .cancelled, source: "session controller")
        }
        return result
    }

    @MainActor private func readCompanionTool(_ request: CompanionToolRequest) async -> CompanionToolResult {
        switch request.kind {
        case .deviceClock:
            return CompanionClock.read(now: Date(), timeZone: .current, arabic: arabic)
        case .savedMemory:
            var evidence = assistantDialogue.relevantUserReports(for: request.query, maxScalars: 1200).map {
                CompanionEvidence(kind: .userReport, text: $0.text, source: "user conversation record")
            }
            if !preferredName.isEmpty {
                evidence.append(CompanionEvidence(kind: .historicalMemory,
                    text: "The user saved their preferred name as \(preferredName).", source: "user-edited profile"))
            }
            for interest in assistantPreferences.interests.prefix(4) {
                evidence.append(CompanionEvidence(kind: .historicalMemory,
                    text: "\(interest.category): \(interest.value)", source: "user-edited preferences"))
            }
            return CompanionToolResult(status: .success, source: "private on-device memory",
                summary: "Original user reports and saved preferences, not current observations. An empty result means no matching record, not that an object is absent.", evidence: evidence)
        case .navigationState:
            let summary = indoor.route.isEmpty
                ? "No active route. Current position and arrival are unverified."
                : "A saved route has \(indoor.route.count) checkpoints. This record alone does not establish current position, arrival, or path clearance."
            return CompanionToolResult(status: .success, source: "app navigation state",
                summary: summary)
        case .currentObservation:
            // Capture on tool invocation, never manufacture a current result from
            // remembered labels or a cached frame. No camera permission/start here.
            let id = requestID, generation = assistantSession.generation
            let perception = perceptionGeneration
            let capturedAt = lastFrameWallTime
            let mapRevision = indoor.revision, alignmentRevision = indoor.alignmentRevision
            guard !Task.isCancelled, assistantSession.foregroundActive, running, !simulation, !places.scanning,
                  attention.stationary, detection.hazard == .observing,
                  UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).contains(where: { $0.interfaceOrientation == .portrait }),
                  let origin = lastObservation, origin.trackingNormal, let frame = session.currentFrame,
                  perceptionResultAllowed(request: id, generation: perception, capturedAt: capturedAt,
                    observation: origin, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else {
                return CompanionToolResult(status: .unavailable, source: "camera and sensor freshness gate",
                    summary: "No fresh gated observation is available. This is not a search and does not establish that any item is present or absent.")
            }
            let captured = Date().addingTimeInterval(-(ProcessInfo.processInfo.systemUptime - capturedAt))
            guard let result = await conversationFrameProbe.inspect(image: frame.capturedImage, orientation: .right) else {
                return CompanionToolResult(status: Task.isCancelled ? .cancelled : .unavailable,
                    source: "bounded on-device Vision reader", summary: "No observation obtained. The reader was busy, unavailable or cancelled.")
            }
            guard !Task.isCancelled, requestID == id, assistantSession.generation == generation,
                  assistantSession.foregroundActive, attention.stationary,
                  perceptionResultAllowed(request: id, generation: perception, capturedAt: capturedAt,
                    observation: origin, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else {
                return CompanionToolResult(status: .stale, source: "camera and sensor freshness gate",
                    summary: "The capture is no longer current. No current claim or absence may be inferred.")
            }
            // Uncertain candidates only, never identity, garment certainty or a
            // banknote denomination. Keep whole strings rather than cutting a caveat.
            var candidates = result.texts.prefix(2).map { "Visible text candidate (OCR may be mistaken): \($0)." }
            candidates += result.labels.filter { !ClothingColorCommand.containsUnverifiedColorClaim($0) && !SaudiBanknotePolicy.containsUnverifiedMoneyValue($0) }
                .prefix(2).map { "Current observation candidate (image classification may be mistaken): \($0)." }
            let evidence = candidates.prefix(4).map { text in
                CompanionEvidence(kind: .currentObservation, text: text, source: "fresh on-device Vision capture",
                    observedAt: captured, expiresAt: captured.addingTimeInterval(0.5))
            }
            for item in evidence {
                conversationEvidenceCaptures[item.id] = ConversationCapture(perception: perception, observation: origin, capturedAt: capturedAt)
            }
            // Three bounded calls with four records each are the turn maximum.
            if conversationEvidenceCaptures.count > 12 { conversationEvidenceCaptures.removeAll(); return CompanionToolResult(status: .callLimit, source: "capture ledger") }
            return CompanionToolResult(status: .success, source: "fresh on-device observation",
                summary: "Partial camera coverage and uncertain OCR/image-category candidates only. Empty results never prove absence. No identity, distance, direction, route or clearance is established.", evidence: evidence)
        }
    }

    private func recordCompanionMessage(_ question: String) {
        if companionWorkingState.reports.isEmpty {
            for turn in assistantDialogue.turns where turn.role == "user" {
                companionWorkingState.record(turn.text)
            }
        }
        companionWorkingState.record(question)
        persistWorkingState()
        assistantDialogue.record(role: "user", text: question)
        persistDialogue()
    }

    /// Conversation evidence rule (2026-10-22): find requests and location reports are answered
    /// by code from the child's own reports, saved items and live sensors, never by the model.
    private func answerCompanionUtterance(_ utterance: CompanionUtterance, question: String) {
        recordCompanionMessage(question)
        applyCompanion(utterance, question: question)
    }

    private func applyCompanion(_ utterance: CompanionUtterance, question: String) {
        let oldGoal = companionWorkingState.goal
        let text = companionWorkingState.respond(to: utterance, message: question, arabic: arabic)
        let findObject: String?
        if case .find(let object) = utterance { findObject = object } else { findObject = nil }
        if oldGoal != companionWorkingState.goal {
            // A conversational goal ("find my cup") keeps the measured map alignment and return trail:
            // the person has not moved. Only an explicit new objective resets position.
            assistantDialogue.setGoal(companionWorkingState.goal); objectiveDraft = assistantDialogue.goal; persistDialogue()
        }
        persistWorkingState()
        // Saved items and live sensors answer a find request before "I don't know".
        if let findObject, findWithSensors(findObject, question: question) { return }
        if !text.isEmpty { deliverConversationReply(text) }
    }

    private func deliverConversationReply(_ text: String) {
        sceneAnswer = text; currentReply = text
        if textOnly || assistantSession.state != .active {
            assistantDialogue.record(role: "assistant", text: text)
            persistDialogue()
            return
        }
        // Code-owned receipts use the same bounded queue and delivery completion ledger.
        // Only this controller can set codeOwned; model callbacks always use the guarded default.
        queueConversationSpeech(text, request: requestID, generation: assistantSession.generation, codeOwned: true)
    }

    /// A recognized physical-action request cannot fall through to a plausible model
    /// instruction, a bare yes/no, or a model's own assertion that it verified the target.
    @discardableResult private func routeUnverifiedPhysicalRequest(_ question: String) -> Bool {
        guard ConversationDomainPolicy.requiresPhysicalVerification(for: question) else { return false }
        cancelDescription(); stopReturn()
        // Typed find tools may gather fresh evidence, but their current output cannot
        // authorize a direction, distance, approach or pickup. No model fallback.
        let utterance = CompanionUtterance.parse(question)
        var target = LocateCommand.target(question)
        if case .find(let object) = utterance { target = object }
        #if BLIND_FAMILIAR_PEOPLE
        if routeFamiliarPeopleCommand(question) { return true }
        let localQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if target == nil {
            for prefix in ["where is ", "where's ", "where are "] where localQuestion.lowercased().hasPrefix(prefix) {
                target = String(localQuestion.dropFirst(prefix.count))
            }
        }
        if let target, let person = familiarPeople.people.first(where: {
            $0.label.caseInsensitiveCompare(target) == .orderedSame
        }) {
            recordCompanionMessage(question)
            familiarPeople.handle(.find(person.label), model: self)
            return true
        }
        #endif
        if let utterance, case .find = utterance {
            answerCompanionUtterance(utterance, question: question)
            return true
        }
        recordCompanionMessage(question)
        if let target, findWithSensors(target, question: question) { return true }
        indoor.invalidatePosition()
        deliverConversationReply(arabic
            ? "لا أملك موقعاً متحققاً منه لهذا الغرض بعينه، لذلك لا أستطيع توجيه حركتك أو مد يدك إليه."
            : "I don't have a verified position for that exact target, so I can't guide your movement or reach.")
        return true
    }

    /// Weather and physical temperature require an actual configured source, not
    /// camera pixels or a language model's recollection of a city's climate.
    @discardableResult private func routeUnavailableTemperature(_ question: String) -> Bool {
        guard ConversationDomainPolicy.requiresLiveTemperature(for: question) else { return false }
        cancelDescription(); recordCompanionMessage(question)
        deliverConversationReply(arabic
            ? "لا تتوفر لدي قراءة مباشرة للطقس أو مقياس حرارة. الكاميرا لا تقيس درجة الحرارة."
            : "I don't have a live weather or thermometer reading. The camera cannot measure temperature.")
        return true
    }

    private func answerConversation(_ question: String) {
        // Inspection requests cannot become free-form answers, even a bare colour,
        // number or yes/no, when the dedicated camera workflow is unavailable.
        guard ConversationDomainPolicy.allowsModelResponse(to: question) else {
            if routeUnavailableTemperature(question) { return }
            if routeUnverifiedPhysicalRequest(question) { return }
            _ = routeSaudiBanknoteCommand(question) || routeClothingColorCommand(question)
            return
        }
        if let utterance = CompanionUtterance.parse(question) {
            answerCompanionUtterance(utterance, question: question); return
        }
        recordCompanionMessage(question)
        let dialogue = assistantDialogue
        let sessionGeneration = assistantSession.generation
        let preview = recognizedPlace
        var situation = AssistantSituation.snapshot(dialogue: dialogue, preview: preview,
            layout: preview.flatMap { places.layout(for: $0) }, preferences: assistantPreferences, arabic: arabic)
        situation["taskProgress"] = [
            "source": "app navigation state",
            "state": indoor.route.isEmpty ? "no route selected" : "saved route; current position unverified",
            "routeCheckpointIndex": indoor.waypointIndex,
            "routeCheckpointCount": indoor.route.count,
            "arrivalConfirmedThisTurn": false
        ]
        let id = UUID()
        requestID = id; busy = true; sceneAnswer = ""; questionIsChat = true
        questionTimeoutTask?.cancel()
        questionTimeoutTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, self.requestID == id, self.busy else { return }
            self.cancelDescription()
            if self.sceneAnswer.isEmpty {
                self.sceneAnswer = self.arabic ? "استغرق الرد وقتاً طويلاً. حاول مرة أخرى." : "That reply took too long. Please try again."
                self.currentReply = self.sceneAnswer
            }
        }
        // A reply that has not started within a second gets a short spoken acknowledgement, so the
        // child is never left in silence; code answers (find, where, reports) are already instant.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, self.requestID == id, self.busy, self.sceneAnswer.isEmpty else { return }
            _ = self.speakOperation(self.arabic ? "لحظة." : "One moment.", replace: false)
        }
        questionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let revision = self.companionWorkingState.goalRevision
            let answer = await LocalImageAssistant.converse(dialogue: dialogue, arabic: self.arabic,
                preferredName: self.preferredName, audience: self.assistantAudience, situation: situation, workingState: self.companionWorkingState,
                availableTools: Set(CompanionToolKind.allCases),
                toolExecutor: { @Sendable [weak self] request in
                    guard let self else { return CompanionToolResult(status: .cancelled, source: "session controller") }
                    return await self.readCompanionToolForTurn(request, id: id, generation: sessionGeneration)
                }, onSpeechCandidate: { @MainActor [weak self] phrase, reports, evidence in
                    guard let self, ConversationDomainPolicy.allowsModelResponse(to: question), self.requestID == id, !Task.isCancelled,
                          self.assistantSession.generation == sessionGeneration else { return }
                    self.queueConversationSpeech(phrase, request: id, generation: sessionGeneration,
                                                 reports: reports, evidence: evidence)
                }) { @MainActor [weak self] phrase in
                    guard let self, ConversationDomainPolicy.allowsModelResponse(to: question), self.requestID == id, !Task.isCancelled,
                          self.assistantSession.generation == sessionGeneration else { return }
                    self.streamedConversationText += (self.streamedConversationText.isEmpty ? "" : " ") + phrase
                    self.sceneAnswer = self.streamedConversationText
                }
            // Re-evaluate the action prerequisites after inference; a new request or
            // changed objective invalidates the old decision before it can act.
            let admission = CompanionReactiveSequence.tick([
                .init(tick: { Task.isCancelled ? .failure : .success }),
                .init(tick: { self.requestID == id && self.assistantSession.generation == sessionGeneration ? .success : .failure }),
                .init(tick: { self.companionWorkingState.goalRevision == revision ? .success : .failure })
            ])
            guard admission == .success else { return }
            self.questionTimeoutTask?.cancel(); self.questionTimeoutTask = nil
            self.busy = false; self.questionIsChat = false
            guard let text = answer.text else {
                self.sceneAnswer = answer.status; self.currentReply = answer.status
                if self.assistantSession.state == .active { self.speakOperation(answer.status) }
                return
            }
            if let update = answer.taskUpdate {
                let oldGoal = self.companionWorkingState.goal
                self.companionWorkingState.apply(update, latest: question)
                if oldGoal != self.companionWorkingState.goal {
                    self.objectiveDraft = self.companionWorkingState.goal
                    self.assistantDialogue.setGoal(self.companionWorkingState.goal)
                    self.stopReturn(); self.indoor.invalidatePosition()
                    self.persistDialogue()
                }
                self.persistWorkingState()
            }
            self.sceneAnswer = text; self.currentReply = text
            if self.textOnly || self.assistantSession.state != .active {
                // Visible typed answers are available to the reader, never marked as spoken.
                self.assistantDialogue.record(role: "assistant", text: text)
                self.persistDialogue()
            } else if self.streamedConversationText.isEmpty {
                self.queueConversationSpeech(text, request: id, generation: sessionGeneration)
            }
        }
    }

    func startVoiceQuestion() {
        guard !textOnly else { return }
        guard !running || detection.hazard == .observing else {
            repeatMonitoringStatus()
            return
        }
        cancelDescription(); _ = feedback.stopInformation(announceCancellation: false)
        startConversation()
    }
    func findMapDestination() {
        guard !busy, let map = indoor.map else { message = "Import a map in Routes first."; return }
        voice.endManualTurn()
        let question = assistantQuestion, revision = indoor.revision
        let matches = MapContext.matchingDestinations(question: question, in: map)
        if !matches.isEmpty {
            indoor.suggestDestination(id: matches.count == 1 ? matches[0].id : nil)
            sceneAnswer = indoor.message
            if !running || detection.hazard == .observing { speakRequested(sceneAnswer) }
            return
        }
        let position = lastObservation.flatMap {
            $0.trackingNormal && running && !simulation && ProcessInfo.processInfo.systemUptime - lastFrameWallTime <= 0.5 ? indoor.mapPosition(camera: $0.camera) : nil
        }
        let context = MapContext(map: map, position: position, route: indoor.route)
        busy = true; let request = UUID(); requestID = request
        questionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.requestID == request { self.busy = false } }
            let id = await OfflineSummary.destination(context, question: question, arabic: self.arabic)
            guard !Task.isCancelled, self.requestID == request, self.indoor.revision == revision else { return }
            self.indoor.suggestDestination(id: id); self.sceneAnswer = self.indoor.message
            if !self.running || self.detection.hazard == .observing { self.speakRequested(self.sceneAnswer) }
        }
    }
    func stopDescriptions() { cancelDescription(); voice.endManualTurn(); feedback.interruptAmbient(); ambientDescriptions = false }
    private func queueQuestion(_ question: String, cloud: Bool, focus: String, camera: Point3, forward: Point3) {
        pendingQuestion = PendingQuestion(question: question, cloud: cloud, focus: focus,
            goalRevision: assistantDialogue.goalRevision, mapRevision: indoor.revision.uuidString,
            alignmentRevision: indoor.alignmentRevision.uuidString, created: ProcessInfo.processInfo.systemUptime,
            camera: camera, forward: forward)
        message = arabic ? "سينتظر سؤالك انتهاء الكلام الحالي. سأتحقق من المشهد مجدداً قبل الإجابة." : "Your question is waiting for the current speech. I will check the view again before answering."
    }
    private func resumePendingQuestion() {
        guard let pending = pendingQuestion, !busy, feedback.canSpeakAmbient else { return }
        pendingQuestion = nil
        guard running, !simulation, !places.scanning, (!pending.cloud || !offlineOnly),
              pending.isCurrent(goalRevision: assistantDialogue.goalRevision, mapRevision: indoor.revision.uuidString,
                alignmentRevision: indoor.alignmentRevision.uuidString, now: ProcessInfo.processInfo.systemUptime,
                camera: lastObservation?.camera, forward: lastObservation?.forward, frameAt: lastFrameWallTime,
                tracking: lastObservation?.trackingNormal == true, hazard: detection.hazard) else {
            message = arabic ? "تغير المشهد أثناء الانتظار. اطرح السؤال مجدداً عند الاستعداد." : "The view changed while waiting. Ask again when ready."
            return
        }
        readScene(cloud: pending.cloud, question: pending.question, focus: pending.focus)
    }
    @discardableResult private func handleAssistantControl(_ text: String) -> Bool {
        guard let control = AssistantControl.parse(text) else { return false }
        switch control {
        case .quiet: stopDescriptions()
        case .resume: ambientDescriptions = true
        case .moreDetail: detail = detail == .minimal ? .balanced : .detailed
        case .lessDetail: detail = detail == .detailed ? .balanced : .minimal
        case .moreInformation: wordsPerMinute = min(1800, wordsPerMinute + 60)
        case .lessInformation: wordsPerMinute = max(30, wordsPerMinute - 60)
        case .repeatDescription: repeatDescription(); return true
        }
        message = arabic ? "تم تحديث إعدادات الوصف." : "Description settings updated."
        _ = speakOperation(message)
        return true
    }
    func repeatDescription() {
        guard let record = narrationHistory.first else {
            message = arabic ? "لا يوجد وصف سابق محفوظ." : "There is no saved description to repeat."; return
        }
        guard !running || detection.hazard == .observing else { return }
        let englishPrefix = "Earlier description; the scene may have changed: ", arabicPrefix = "وصف سابق وقد تغير المشهد: "
        var original = record.text
        for prefix in [englishPrefix, arabicPrefix] where original.hasPrefix(prefix) { original = String(original.dropFirst(prefix.count)) }
        let text = (arabic ? arabicPrefix : englishPrefix) + original
        let tokenizer = NLTokenizer(unit: .word); tokenizer.string = text
        let count = tokenizer.tokens(for: text.startIndex..<text.endIndex).count
        let now = ProcessInfo.processInfo.systemUptime
        guard text.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars,
              count <= narrationBudget.allowance(limit: wordsPerMinute, now: now) else {
            message = arabic ? "انتظر قليلاً أو زد حد الكلمات لإعادة الوصف كاملاً." : "Wait briefly or increase the word allowance to repeat the whole description."; return
        }
        cancelDescription()
        let id = UUID(), session = narrationSession, revision = assistantDialogue.goalRevision, at = Date()
        guard speakRequested(text, narrationID: id) else { return }
        narrationBudget.charge(words: count, limit: wordsPerMinute, now: now)
        // Do not recursively prepend older repeat labels to later requests.
        enqueueNarration { try await $0.start(id: id, sessionID: session, goalRevision: revision,
            snapshotID: record.snapshotID, sourceIDs: record.sourceIDs, text: text, at: at) }
    }
    // Developer comparison builds only; the app build has no connection to a scene service.
    #if BLIND_DEVELOPER_CLOUD
    func checkSceneConnection() {
        guard !offlineOnly else { serviceStatus = "Enable internet access to check the optional service."; return }
        serviceStatus = "Checking connection…"
        let endpoint = serviceURL
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let configured = try await SceneQuestionClient(endpoint: endpoint, token: TokenStore.read()).checkConnection()
                guard !self.offlineOnly, self.serviceURL == endpoint else { return }
                self.serviceStatus = configured ? "Connected. Scene provider configured; no photo was sent." : "Connected, but the server needs a provider key and model."
            } catch { if !self.offlineOnly { self.serviceStatus = "Connection failed. Check the HTTPS address and access token." } }
        }
    }
    #else
    func checkSceneConnection() { serviceStatus = "Descriptions run on this phone." }
    #endif
    func startReturn() {
        guard running, !simulation, detection.hazard == .observing,
              let current = journeys.current, let observation = lastObservation, observation.trackingNormal,
              ProcessInfo.processInfo.systemUptime - lastFrameWallTime < 0.5 else {
            returnStatus = "Start and calibrate live monitoring before returning."; return
        }
        returning = returnTrail.begin(journey: current, camera: observation.camera, at: observation.timestamp)
        returnStatus = returning ? "Retracing this session. Recorded positions do not establish clearance." : returnTrail.reason
        lastReturnAnnouncement = -.infinity; cancelDescription()
    }
    func stopReturn() { returning = false; returnTrail = ReturnTrail(); returnCue = nil; returnStatus = "" }
    private func invalidateReturn() {
        guard returning else { return }
        returnTrail.invalidate(); returning = false; returnCue = nil
        returnStatus = "Return guidance stopped because tracking changed."
    }
    private func updateReturn(_ observation: Observation) {
        guard returning else { return }
        returnCue = returnTrail.update(camera: observation.camera, forward: observation.forward, at: observation.timestamp,
                                      tracking: observation.trackingNormal, hazard: detection.hazard)
        switch returnTrail.state {
        case .arrived:
            returning = false; returnStatus = arabic ? "أنت قرب نقطة بداية المسار المسجل. تأكد من المعلم." : "Near the recorded start. Confirm your starting landmark."
            speakMobility(returnStatus)
        case .invalidated: returning = false; returnStatus = returnTrail.reason
        case .paused: returnStatus = "Return guidance paused while monitoring is unavailable or a hazard is present."
        default:
            if ProcessInfo.processInfo.systemUptime - lastReturnAnnouncement >= 8 { speakReturnCue() }
        }
    }
    func speakReturnCue() {
        guard returning, detection.hazard == .observing, let cue = returnCue else { return }
        guard fixedBodyMount else {
            returnStatus = arabic ? "اتجاه الجسم غير مؤكد. ثبت الهاتف باتجاه الجسم وأكد التثبيت قبل الإرشاد الاتجاهي." : "Body direction is unconfirmed. Secure the phone facing with your body and confirm the mount before directional guidance."
            return
        }
        let directions = arabic ? ["أمامك", "أمامك يميناً", "يمينك", "خلفك يميناً", "خلفك", "خلفك يساراً", "يسارك", "أمامك يساراً"] :
            ["ahead", "ahead to your right", "to your right", "behind to your right", "behind you", "behind to your left", "to your left", "ahead to your left"]
        returnStatus = arabic ? "نقطة المسار المسجل \(directions[cue.sector])، نحو \(String(format: "%.1f", cue.distance)) متر." :
            "Recorded trail point \(directions[cue.sector]), about \(String(format: "%.1f", cue.distance)) meters."
        if speakMobility(returnStatus) {
            feedback.beacon(sector: cue.sector, distance: max(0.5, min(10, cue.distance)))
            lastReturnAnnouncement = ProcessInfo.processInfo.systemUptime
        }
    }
    func startSimulation() {
        stopCameraMonitoring(); feedback.stop(includingAlerts: true)
        simulation = true; running = true; detector.beginCalibration()
        demonstrationTime = 0; demonstrationHazard = .observing; policy = AlertPolicy(); continuity = MonitoringContinuity()
        for _ in 0..<15 { demoFrame() }
        startWatchdog(); message = arabic ? "المحاكاة تستخدم عمقاً مولداً. لا يوجد استشعار حقيقي." : "Simulation uses generated depth. No live sensing is active."
        _ = speakMobility(arabic ? "تدريب. الحساسات الحقيقية متوقفة لمدة دقيقتين." : "Practice. Live sensors are paused for two minutes.")
        // Practice ends automatically; this does not promise calibrated live sensing.
        practiceTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in self?.endPractice() }
    }
    /// Ends practice and returns to live camera and sensors.
    func endPractice() {
        guard simulation else { return }
        stopCameraMonitoring(); feedback.stop(includingAlerts: true)
        if cameraAwareness && assistantSession.foregroundActive && !textOnly { start() }
        _ = speakMobility(arabic ? "انتهى التدريب. تحتاج تنبيهات الكاميرا إلى تشغيلها وإعادة المعايرة." : "Practice ended. Camera alerts require the camera to be on and the floor recalibrated.")
    }
    func simulate(_ hazard: Hazard) { demonstrationHazard = hazard }
    private func demoFrame() {
        demonstrationTime += 0.1
        var samples: [DepthSample] = []
        if demonstrationHazard != .uncertain {
            for ahead in stride(from: 0.32, through: 2.15, by: 0.08) {
                for side in stride(from: -0.3, through: 0.3, by: 0.1) {
                    let y = demonstrationHazard == .drop && ahead > 1 ? -0.4 : 0
                    samples.append(DepthSample(Point3(side, y, -ahead)))
                    if ahead < 1.2 && (demonstrationHazard == .obstacle || demonstrationHazard == .overhead) {
                        samples.append(DepthSample(Point3(side, demonstrationHazard == .obstacle ? 0.7 : 1.6, -ahead)))
                    }
                }
            }
        }
        phoneDetection = detector.process(Observation(timestamp: demonstrationTime, camera: Point3(0, 1.3, 0),
                                                      forward: Point3(0, 0, -1), samples: samples))
        calibrationProgress = detector.calibrationProgress
    }
}

// MARK: - Everyday controls
extension NavigationModel {
    var homePrompt: String {
        if textOnly { return busy ? "Thinking…" : "Text chat · voice is off" }
        if running && detection.hazard.requiresImmediateAttention {
            if detection.hazard == .needsCalibration {
                return arabic ? "قف على أرض مستوية ووجّه الكاميرا نحو الأرض أمامك." : "Stand on a level floor. Point the camera at the ground ahead."
            }
            return GuidanceText.detection(detection, arabic: arabic)
        }
        if assistantSession.state == .muted { return arabic ? "الميكروفون مكتوم. يمكنك الكتابة." : "Microphone muted. You can still type." }
        if assistantSession.state == .ended { return arabic ? "انتهت المحادثة الصوتية. يمكنك الكتابة أو البدء من جديد." : "Voice conversation ended. Write a message or start again." }
        if busy { return arabic ? "أفكر، ويمكنك مقاطعتي." : "Thinking. You can interrupt me." }
        if voice.state != .idle && voice.state != .listening && !voice.message.isEmpty { return voice.message }
        if voice.listening { return arabic ? "أنا أستمع." : "I'm listening." }
        if busy { return arabic ? "لحظة واحدة." : "One moment." }
        if !running {
            return message.isEmpty ? (arabic ? "ماذا تريد أن نفعل؟" : "What would you like to do?") : message
        }
        if detection.hazard == .calibrating { return arabic ? "اثبت لحظة." : "Hold still a moment." }
        return arabic ? "أنا معك." : "I'm here."
    }

    func resumeExperienceIfNeeded() {
        if !assistantSession.foregroundActive {
            cancelDescription()
            _ = feedback.stopInformation(announceCancellation: false)
        }
        assistantSession.enterForeground()
        voice.setBackgroundAllowed(backgroundConversation)
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
        if assistantSession.state == .idle {
            assistantSession.setBackgroundAllowed(backgroundConversation)
            assistantSession.start()
        }
        guard automaticStartupAllowed, !experienceActive else { return }
        experienceActive = true
        if cameraAwareness && assistantSession.foregroundActive && !textOnly { start() }
        if companionGreeting.isEmpty {
            companionGreeting = arabic ? "مرحباً، أنا مساعدك. تحدث معي أو اكتب رسالة. يمكنك كتم الميكروفون أو إنهاء المحادثة في أي وقت." : "Hello, I'm your assistant. Talk to me or write a message. You can mute the microphone or end the conversation anytime."
            if !textOnly && assistantSession.state == .active { speakOperation(companionGreeting) }
        }
        if !textOnly && assistantSession.shouldListen { voice.startContinuous(arabic: arabic) }
    }

    /// Camera work always stops in the background; listening follows explicit opt-in.
    func suspendExperience() {
        defer { updateLiveActivity() }
        experienceActive = false
        assistantSession.enterBackground()
        cancelDescription()
        stopCameraMonitoring()
        _ = feedback.stopInformation(announceCancellation: false)
        if !assistantSession.shouldListen { voice.cancel() }
        message = assistantSession.shouldListen
            ? (arabic ? "تستمر المحادثة الصوتية. الكاميرا وتنبيهات المسار متوقفة خارج التطبيق." : "Voice conversation remains active. Camera and path monitoring are off outside the app.")
            : (arabic ? "الميكروفون والكاميرا متوقفان خارج التطبيق." : "Microphone and camera are off outside the app.")
    }

    func startConversation() {
        defer { updateLiveActivity() }
        assistantSession.setBackgroundAllowed(backgroundConversation)
        assistantSession.start()
        cancelDescription()
        voice.setBackgroundAllowed(backgroundConversation)
        if cameraAwareness && assistantSession.foregroundActive && !textOnly && !running { start() }
        if !textOnly && assistantSession.shouldListen { voice.startContinuous(arabic: arabic) }
        message = arabic ? "المحادثة الصوتية مفعلة." : "Voice conversation is on."
    }

    func muteConversation() {
        defer { updateLiveActivity() }
        assistantSession.mute()
        cancelDescription(); voice.cancel()
        _ = feedback.stopInformation(announceCancellation: false)
        message = arabic ? "الميكروفون مكتوم. الكتابة متاحة وتنبيهات الخطر لا تتوقف." : "Microphone muted. You can still type; hazard alerts are not disabled."
    }

    func endConversation() {
        defer { updateLiveActivity() }
        assistantSession.end()
        cancelDescription(); voice.cancel()
        _ = feedback.stopInformation(announceCancellation: false)
        message = arabic ? "انتهت المحادثة الصوتية. الكاميرا وتنبيهاتها منفصلة." : "Voice conversation ended. Camera monitoring has its own control."
    }

    func reconnectListening() { startConversation() }

    func startExperience() {
        automaticStartupAllowed = true
        cameraAwareness = true
        startConversation()
        if !textOnly { start() }
    }

    func stopExperience() {
        automaticStartupAllowed = false
        endConversation()
        stop()
        experienceActive = false
        message = arabic ? "توقفت المحادثة والكاميرا. اضغط ابدأ للمتابعة." : "Conversation and camera stopped. Tap Start to continue."
    }

    func toggleHomeDescriptions() {
        if ambientDescriptions {
            stopDescriptions()
            speakOperation(arabic ? "سأتوقف عن الوصف. تبقى تنبيهات المسار مفعلة." : "I'll be quiet. Path alerts stay on.")
        } else {
            ambientDescriptions = true
            speakOperation(arabic ? "سأصف ما يتغير حولك." : "I'll describe changes around you.")
        }
    }

    func repeatHomeInformation() {
        if running && detection.hazard != .observing { repeatMonitoringStatus() }
        else if !narrationHistory.isEmpty { repeatDescription() }
        else { speakOperation(homePrompt) }
    }

    private func updateLiveActivity() {
        #if BLIND_LIVE_ACTIVITY
        guard !textOnly else { return }
        lastLiveActivityUpdate = ProcessInfo.processInfo.systemUptime
        let cameraOn = running && !simulation && !places.scanning && assistantSession.foregroundActive &&
            lastObservation?.trackingNormal == true && lastLiveActivityUpdate - lastFrameWallTime < 0.5
        let listening = assistantSession.shouldListen && voice.listening, arabic = self.arabic
        Task { @MainActor in
            CompanionLiveActivity.shared.show(cameraOn: cameraOn, listening: listening, arabic: arabic)
        }
        #endif
    }

    func speakHomeHelp() {
        speakOperation(arabic
            ? "تحدث معي في أي وقت. على الرد، اسحب للأعلى أو الأسفل لخيارات مثل كرر وأوقف. الأماكن والمسارات والإعدادات في الأزرار السفلية."
            : "Talk to me any time. On the reply, swipe up or down for options like Repeat and Stop. Places, Routes and Settings are the buttons at the bottom.")
    }
}

// MARK: - Room recognition, orientation, changes and remembered items (2026-10-09)
// Rooms are recognised from agreeing clues (map match, saved pictures, furniture, movement,
// the person's answer); when unsure the app asks. Positions and distances are measured by code.
extension NavigationModel {
    /// Body heading in world coordinates when established by walking or a declared mount; nil otherwise.
    private func currentBodyForward() -> Point3? {
        let heading = bodyHeadingEstimator.heading(at: lastFrameWallTime, declaredFixedMount: fixedBodyMount)
        return heading.isKnown ? heading.forward : nil
    }

    private func checkMountSlip() {
        guard fixedBodyMount, bodyHeadingEstimator.mountSlipSuspected, !mountSlipAnnounced else { return }
        mountSlipAnnounced = true
        fixedBodyMount = false
        message = arabic ? "ربما تحرّك الهاتف على الحامل. تحقق منه ثم فعّل التثبيت مجدداً." : "The phone may have shifted on its mount. Check it, then turn the fixed mount on again."
        _ = speakMobility(message)
    }

    /// Start by trying the saved place nearest to the phone's coarse location (it only narrows which
    /// map to try). A failed match stays unresolved.
    private func launchWithNearbyPlace() {
        let here = outdoor.coarseLocation ?? outdoor.location
        let candidates = places.places.map { place -> PlaceCandidate in
            var distance: Double?
            if let here, let latitude = place.latitude, let longitude = place.longitude {
                distance = here.distance(from: CLLocation(latitude: latitude, longitude: longitude))
            }
            return PlaceCandidate(placeID: place.id.uuidString, name: place.name, distanceMetres: distance)
        }
        let nearby = RoomRecognizer.nearbyPlaces(candidates)
        // Only a measured nearby place is tried; without a location the room is established by clues instead.
        let choice = nearby.first(where: { $0.distanceMetres != nil })
        if let choice, let place = places.places.first(where: { $0.id.uuidString == choice.placeID }) { recognize(place) }
        else { launch() }
    }

    /// After a yes/no question finishes speaking, listen briefly only when explicitly enabled.
    private func listenForOfferAnswer() {
        guard !textOnly, assistantSession.shouldListen, !voice.continuous, listenAfterQuestions, let offer = companionOffer, companion.pendingOffer != nil, !voice.awaitingUtterance,
              !running || detection.hazard == .observing else { return }
        let key = "\(offer.kind.rawValue):\(offer.subject):\(offer.expiresAt)"
        guard key != listenedOfferKey else { return }
        listenedOfferKey = key
        voice.start(arabic: arabic, timeout: 5)
    }

    private static func viewSector(_ forward: Point3) -> Int {
        let angle = atan2(forward.x, -forward.z)
        guard angle.isFinite else { return 0 }
        return min(7, max(0, Int(((angle + .pi) / (2 * .pi) * 8).rounded(.down))))
    }

    /// Rooms connected to `room` by a mapped door in the active package.
    private func connectedRooms(from room: String) -> [String] {
        guard let package = indoor.activePackage else { return [] }
        let prefix = "\(package.id):"
        guard room.hasPrefix(prefix) else { return [] }
        let id = String(room.dropFirst(prefix.count))
        return package.connections.compactMap { edge in
            edge.fromRoomID == id ? prefix + edge.toRoomID : edge.toRoomID == id ? prefix + edge.fromRoomID : nil
        }
    }

    /// Every ~2 s: learn what the established room looks like, gather clues for which room this is,
    /// decide with RoomRecognizer, and notice relevant changes in a familiar room.
    private func updateRoomRecognition(frame: ARFrame, observation: Observation) {
        let now = lastFrameWallTime
        guard observation.trackingNormal, detection.hazard == .observing, !places.scanning,
              now - lastRecallCheck >= 2, !recallInFlight else { return }
        lastRecallCheck = now
        let image = frame.capturedImage
        let sector = Self.viewSector(currentBodyForward() ?? observation.forward)
        let established = alignedRoomID ?? recognizedPlace.map { "place:\($0.id.uuidString)" } ?? recognizedRoomID
        // Learn pictures only when the room came from a map match or the person's answer, so a wrong
        // guess from appearance never teaches itself.
        let trusted = alignedRoomID != nil || recognizedPlace != nil || recognizedBasis.contains { $0.hasPrefix("worldMap") || $0.hasPrefix("user") }
        var candidates = Array(companion.memory.rooms.keys.sorted().prefix(12))
        if let established, !candidates.contains(established) { candidates.append(established) }
        let generation = perceptionGeneration
        recallInFlight = true
        roomRecall.evidence(image: image, candidates: candidates) { [weak self] evidence, view in
            guard let self, self.perceptionGeneration == generation else { return }
            self.recallInFlight = false
            guard self.running, SceneDelivery.allowed(capturedAt: now, now: ProcessInfo.processInfo.systemUptime,
                origin: observation.camera, current: self.lastObservation?.camera, currentFrameAt: self.lastFrameWallTime,
                hazard: self.detection.hazard, tracking: self.lastObservation?.trackingNormal == true,
                originForward: observation.forward, currentForward: self.lastObservation?.forward) else { return }
            let texts = view.texts
            self.latestViewTexts = Array(texts.prefix(5))
            self.latestViewTextCapturedAt = now
            self.latestViewTextObservation = observation
            var clues = evidence
            if let room = self.alignedRoomID { clues.append(.worldMapMatched(roomID: room)) }
            else if let place = self.recognizedPlace { clues.append(.worldMapMatched(roomID: "place:\(place.id.uuidString)")) }
            if let confirmed = self.userConfirmedRoomID { clues.append(.userConfirmed(roomID: confirmed)); self.userConfirmedRoomID = nil }
            switch self.roomRecognizer.decide(clues, at: now) {
            case .established(let room, let basis):
                if basis.contains("user") || (room == established && trusted) {
                    self.roomRecall.learn(room: room, view: view, image: image, now: now, sector: sector)
                }
                if self.alignedRoomID == nil && self.recognizedPlace == nil {
                    if let previous = self.recognizedRoomID, previous != room { self.leftRoomID = previous }
                    self.recognizedRoomID = room; self.recognizedBasis = basis
                }
                if self.leftRoomID == room { self.leftRoomID = nil }
                self.roomQuestionCandidate = nil
            case .ask(let room):
                self.invalidateRecognizedRoom()
                self.askRoom([room], now: now)
            case .askWhich(let rooms):
                self.invalidateRecognizedRoom()
                self.askRoom(rooms, now: now)
            case .unknown:
                self.invalidateRecognizedRoom()
            }
            // Relevant changes in an established room: newcomers, people no longer in view, new signs.
            let current = self.alignedRoomID ?? self.recognizedPlace.map { "place:\($0.id.uuidString)" } ?? self.recognizedRoomID
            guard let current else { return }
            let snapshot = SceneSnapshot(room: current, viewSector: sector,
                                         peopleCount: self.peopleTracking.snapshot(at: now).count, texts: texts, at: now)
            let changes = self.changeDetector.observe(snapshot)
            self.speakCompanionCandidates(self.changeDetector.candidates(for: changes, room: current, at: now, arabic: self.arabic), now: now)
        }
    }

    /// "Is this your bedroom?" — or, for look-alike rooms, "Is this your bedroom or your brother's room?"
    private func askRoom(_ rooms: [String], now: Double) {
        guard roomQuestionCandidate == nil else { return }
        let named = rooms.prefix(2).compactMap { id in companion.memory.rooms[id]?.name.map { (id: id, name: $0) } }
        guard let first = named.first?.id, let firstName = named.first?.name, first != recognizedRoomID else { return }
        let names = named.map(\.name)
        let text: String
        if names.count == 2 {
            text = arabic ? "هل هذه \(names[0]) أم \(names[1])؟ قل نعم إن كانت \(names[0])." : "Is this your \(names[0]) or your \(names[1])? Say yes if it is your \(names[0])."
        } else {
            text = arabic ? "هل هذه \(firstName)؟" : "Is this your \(firstName)?"
        }
        roomQuestionCandidate = InformationCandidate(key: "identity:\(first)", kind: .offer, text: text,
            words: Self.wordCount(text), createdAt: now, expiresAt: now + 30, room: first, offerKind: .confirmRoom)
    }

    private func speakCompanionCandidates(_ candidates: [InformationCandidate], now: Double) {
        guard !candidates.isEmpty, !voice.awaitingUtterance else { return }
        for decision in companion.decide(candidates, moment: companionMoment(now), settings: companionSettings) {
            guard case .say(let item, _) = decision else { continue }
            if !(feedback.canSpeakAmbient && deliverCandidate(item, alreadyAdmitted: true)) { companion.release(item.key) }
        }
    }

    private func say(_ text: String) {
        message = text
        _ = speakRequested(text)
    }

    private func persistItems() {
        guard let memory = places.memory, let data = try? JSONEncoder().encode(items) else { return }
        try? memory.saveValue(namespace: "items", id: "all", payload: data)
    }

    /// "Remember my braille book here", "where is my braille book", "where is the exit sign".
    private func handleItemOrLocate(_ question: String) -> Bool {
        // "Is this my cup?" — checked by image comparison, never by the model.
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        for prefix in ["is this my ", "is that my ", "هل هذا ", "هل هذه "] where asked.lowercased().hasPrefix(prefix) {
            let name = String(asked.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return verifyHeldItem(name) }
        }
        if let command = ItemCommand.parse(question) {
            switch command {
            case .remember(let name):
                let room = companion.currentRoom
                let position = lastObservation.flatMap { indoor.isAligned ? indoor.mapPosition(camera: $0.camera) : nil }
                let saved = items.remember(name: name, roomID: room, roomName: room.flatMap { companion.memory.rooms[$0]?.name },
                                           position: position, frameID: position == nil ? nil : indoor.alignmentRevision.uuidString)
                if saved != nil { persistItems() }
                say(saved != nil ? (arabic ? "حفظت مكان \(name)." : "Saved where your \(name) is.")
                                 : (arabic ? "تعذر الحفظ. يمكن حفظ ٦٤ غرضاً." : "That could not be saved. Up to 64 items can be saved."))
            case .learn(let name):
                learnItem(name)
            case .find(let name):
                if !findWithSensors(name, question: question) {
                    if let fact = companionWorkingState.factBook.latest(for: name) { say(fact.recall(now: Date(), arabic: arabic)) }
                    else { say(ItemMemory.answer(for: nil, asked: name, now: Date(), sameFrame: false, measuredRelation: nil, arabic: arabic)) }
                }
            case .forget(let name):
                let saved = items.find(name)
                if let saved, !forgetItem(saved) { return true }
                let removed = saved != nil
                say(removed ? (arabic ? "نسيت \(name)." : "Forgot your \(name).") : (arabic ? "لا يوجد \(name) محفوظ." : "No saved \(name) to forget."))
            }
            return true
        }
        if let target = LocateCommand.target(question) { return locate(target, question: question) }
        return false
    }

    /// Saved item (by look, or its saved place) newer than the child's last report, then a live
    /// search of the current view. False when neither applies; the caller speaks the report or "unknown".
    private func findWithSensors(_ name: String, question: String) -> Bool {
        let fact = companionWorkingState.factBook.latest(for: name)
        if let item = items.find(name), fact.map({ item.savedAt > $0.at }) ?? true {
            if itemAppearance.viewCount(item.key) > 0, running, !simulation, detection.hazard == .observing,
               let frame = session.currentFrame {
                findItemByLook(item, name: name, frame: frame)
                return true
            }
            let sameFrame = indoor.isAligned && item.frameID == indoor.alignmentRevision.uuidString
            var relation: String?
            if Self.objectInteractionGuidanceValidated, sameFrame, let target = item.position, let observation = lastObservation,
               let here = indoor.mapPosition(camera: observation.camera),
               let facing = currentBodyForward().flatMap({ indoor.mapDirection($0) }),
               let measured = SpatialFacts.relation(from: here, facing: facing, to: target) {
                relation = SpatialFacts.phrase(label: item.name, relation: measured, arabic: arabic, inView: nil)
            }
            say(ItemMemory.answer(for: item, asked: name, now: Date(), sameFrame: sameFrame, measuredRelation: relation, arabic: arabic))
            return true
        }
        return locate(LocateCommand.target(question) ?? name, question: question)
    }

    /// Live search (2026-10-22): the sensors look at fresh frames for up to ObjectSearch.duration
    /// seconds. The current release reports only a possible nonspatial match, not
    /// exact identity, distance or pickup authority. Time up means not located, never absent.
    private func locate(_ target: String, question: String) -> Bool {
        guard running, !simulation, detection.hazard == .observing, lastObservation?.trackingNormal == true else { return false }
        objectSearch = ObjectSearch(target: target, now: ProcessInfo.processInfo.systemUptime)
        searchInFlight = false
        say(ObjectSearch.started(target: target, arabic: arabic))
        continueSearch()
        return true
    }

    private func recordSearch(_ target: String, located: Bool) {
        companionWorkingState.lastSearch = SearchRecord(target: target, located: located)
        persistWorkingState()
    }

    private func continueSearch() {
        let now = ProcessInfo.processInfo.systemUptime
        guard let search = objectSearch, search.due(now: now), !searchInFlight else { return }
        guard running, !simulation, detection.hazard == .observing, let frame = session.currentFrame,
              let origin = lastObservation, origin.trackingNormal else { return }
        searchInFlight = true
        let image = frame.capturedImage, arabic = self.arabic, target = search.target
        // "the exit sign" is spoken as said; the detector matches the words without "the".
        let visionTarget = target.lowercased().hasPrefix("the ") ? String(target.dropFirst(4)) : target
        let request = requestID, generation = perceptionGeneration, capturedAt = lastFrameWallTime
        let mapRevision = indoor.revision, alignmentRevision = indoor.alignmentRevision
        Task.detached(priority: .userInitiated) { [weak self] in
            let found = try? VisionService.locate(target: visionTarget, image: image, orientation: .right, arabic: arabic)
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.requestID == request, self.perceptionGeneration == generation,
                      var current = self.objectSearch, current.active, current.target == target,
                      current.startedAt == search.startedAt else { return }
                self.searchInFlight = false
                // The depth point is fixed in the world, so direction and distance are measured from
                // where the person is now. Old frames, lost tracking or a new request discard the result.
                let now = ProcessInfo.processInfo.systemUptime
                var phrase: String?
                var located: Point3?
                let captureCurrent = self.running && self.requestID == request && self.perceptionGeneration == generation &&
                    self.assistantSession.foregroundActive && self.detection.hazard == .observing &&
                    self.visualCapturePoseAllowed(origin: origin.camera, forward: origin.forward) &&
                    self.indoor.revision == mapRevision && self.indoor.alignmentRevision == alignmentRevision &&
                    now >= capturedAt && now - capturedAt < 0.5 && self.lastObservation?.trackingNormal == true
                if let found, captureCurrent, let here = self.lastObservation {
                    if !Self.objectInteractionGuidanceValidated {
                        phrase = ObjectSearch.unconfirmed(label: found.label, arabic: arabic)
                    } else if let point = DepthSampler.worldPoint(from: frame, uprightX: found.x, uprightY: found.y),
                       let measured = SpatialFacts.relation(from: here.camera, facing: self.currentBodyForward() ?? here.forward, to: point) {
                        located = point
                        let text = SpatialFacts.phrase(label: found.label, relation: measured, arabic: arabic, inView: nil)
                        // Without an established body heading, directions are from the camera.
                        phrase = self.currentBodyForward() == nil ? (arabic ? "من الكاميرا: " : "From the camera: ") + text : text
                    } else {
                        // Seen but not measurable (too far, glass, black): say so; never invent a distance.
                        phrase = ObjectSearch.seenWithoutDepth(label: found.label, arabic: arabic)
                    }
                }
                switch current.attempted(now: now, found: phrase == nil ? nil : found?.label) {
                case .found:
                    self.objectSearch = nil
                    self.recordSearch(target, located: Self.objectInteractionGuidanceValidated && located != nil)
                    if let phrase { self.say(phrase) }
                    // Keep guiding to the measured point as the child walks, from sensors only.
                    if Self.objectInteractionGuidanceValidated, let located, let label = found?.label {
                        self.trackedTarget = TrackedTarget(label: label, query: visionTarget, point: located, now: capturedAt)
                        self.lastTrackLook = now
                    }
                case .notLocated:
                    self.objectSearch = nil
                    self.recordSearch(target, located: false)
                    self.say(ObjectSearch.notLocated(target: target, arabic: arabic))
                default:
                    if !current.hintTried && current.attempts >= 2 {
                        current.hintTried = true
                        self.offerSearchHint(target: target, startedAt: current.startedAt)
                    }
                    self.objectSearch = current
                }
            }
        }
    }

    /// Re-measures the tracked target from the current pose every frame (instant, sensor-only),
    /// refreshes its point with a new detection about every 1.5 s, and ends at reach or lost sight.
    private func updateTrackedTarget() {
        guard Self.objectInteractionGuidanceValidated else { trackedTarget = nil; return }
        guard var target = trackedTarget, running, !simulation, detection.hazard == .observing,
              let here = lastObservation, here.trackingNormal else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let facing = currentBodyForward()
        switch target.update(from: here.camera, facing: facing ?? here.forward, now: now, arabic: arabic, fromCamera: facing == nil) {
        case .guidance(let text): trackedTarget = target; _ = speakMobility(text)
        case .reached(let text): trackedTarget = nil; _ = speakMobility(text)
        case .lost(let text): trackedTarget = nil; _ = speakMobility(text)
        case .none: trackedTarget = target
        }
        guard let tracked = trackedTarget, !trackLookInFlight, now - lastTrackLook >= 1.5, let frame = session.currentFrame else { return }
        trackLookInFlight = true; lastTrackLook = now
        let image = frame.capturedImage, arabic = self.arabic, generation = perceptionGeneration, capturedAt = lastFrameWallTime
        let request = requestID, trackedID = tracked.id
        Task.detached(priority: .userInitiated) { [weak self] in
            let found = try? VisionService.locate(target: tracked.query, image: image, orientation: .right, arabic: arabic)
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.requestID == request, self.perceptionGeneration == generation,
                      var current = self.trackedTarget, current.id == trackedID else { return }
                self.trackLookInFlight = false
                let now = ProcessInfo.processInfo.systemUptime
                guard self.running, self.assistantSession.foregroundActive, self.detection.hazard == .observing,
                      self.lastObservation?.trackingNormal == true, let found,
                      now >= capturedAt, now - capturedAt < 0.5,
                      let point = DepthSampler.worldPoint(from: frame, uprightX: found.x, uprightY: found.y),
                      point.distance(to: current.point) <= 0.3 else { return }
                current.seen(at: point, now: capturedAt)
                self.trackedTarget = current
            }
        }
    }

    /// One uncertain hint from the on-device image model, as a constrained yes/no and side, worded
    /// by code. The sensor search keeps running; a sensor result replaces the hint.
    private func offerSearchHint(target: String, startedAt: Double) {
        guard let frame = session.currentFrame, let origin = lastObservation else { return }
        let image = frame.capturedImage, arabic = self.arabic
        let request = requestID, generation = perceptionGeneration, capturedAt = lastFrameWallTime
        Task { @MainActor [weak self] in
            guard let side = await LocalImageAssistant.spot(target: target, image: image, arabic: arabic) else { return }
            guard let self, let search = self.objectSearch, search.active, search.startedAt == startedAt,
                  self.requestID == request, self.perceptionGeneration == generation,
                  self.assistantSession.foregroundActive, self.running, self.detection.hazard == .observing,
                  ProcessInfo.processInfo.systemUptime - capturedAt < 0.5,
                  let here = self.lastObservation, here.trackingNormal else { return }
            // "On the left of the camera view" is only true if the camera has not turned since.
            let moved = hypot(here.camera.x - origin.camera.x, here.camera.z - origin.camera.z)
            let turned = acos(max(-1, min(1, (here.forward.x * origin.forward.x + here.forward.z * origin.forward.z) /
                max(1e-6, hypot(here.forward.x, here.forward.z) * hypot(origin.forward.x, origin.forward.z))))) * 180 / .pi
            guard moved < 0.3, turned < 10 else { return }
            let hint = ObjectSearch.hint(target: target, side: side, arabic: arabic)
            guard !SpatialClaimGuard.containsSpatialClaim(hint) else { return }
            self.say(hint)
        }
    }
}

// MARK: - The person's own things: guided saving and finding by look (2026-10-09)
// "This is my cup" saves several views of the held object (turning it slowly) plus any readable
// marks, and a short spoken description written on this phone. "Where is my cup" looks for that
// exact object by image comparison; LiDAR measures where it is. Nothing leaves the phone.
extension NavigationModel {
    static let learningViews = 4
    static let learningTimeout = 25.0

    private func learnItem(_ name: String) {
        itemMemoryRevision = UUID(); itemAppearance.cancelPendingWork()
        guard running, !simulation, detection.hazard == .observing else {
            say(arabic ? "ابدأ الكاميرا أولاً ثم أعد المحاولة." : "Start the camera first, then try again."); return
        }
        let room = companion.currentRoom
        let position = lastObservation.flatMap { indoor.isAligned ? indoor.mapPosition(camera: $0.camera) : nil }
        guard let saved = items.remember(name: name, roomID: room, roomName: room.flatMap { companion.memory.rooms[$0]?.name },
                                         position: position, frameID: position == nil ? nil : indoor.alignmentRevision.uuidString) else {
            say(arabic ? "تعذر الحفظ. يمكن حفظ ٦٤ غرضاً." : "That could not be saved. Up to 64 items can be saved."); return
        }
        persistItems()
        learningItem = (name, saved.key, ProcessInfo.processInfo.systemUptime, -Double.infinity)
        say(arabic ? "أمسك \(name) أمام الكاميرا وأدره ببطء." : "Hold your \(name) in front of the camera and turn it slowly.")
    }

    /// Once a second while saving: keep the held object when it shows a new side; count out loud.
    private func updateItemLearning(frame: ARFrame) {
        guard var learning = learningItem else { return }
        let now = lastFrameWallTime
        guard now - learning.lastTick >= 1 else { return }
        learning.lastTick = now; learningItem = learning
        if now - learning.started > Self.learningTimeout { finishLearning(frame: frame); return }
        guard detection.hazard == .observing else { return }
        let key = learning.key, revision = itemMemoryRevision
        itemAppearance.addView(key, image: frame.capturedImage) { [weak self] count in
            guard let self, let count, self.itemMemoryRevision == revision, self.learningItem?.key == key else { return }
            if count >= Self.learningViews { self.finishLearning(frame: frame) }
            else { _ = self.speakOperation(self.arabic ? "\(count) من \(Self.learningViews)" : "\(count) of \(Self.learningViews)") }
        }
    }

    private func finishLearning(frame: ARFrame) {
        guard let learning = learningItem else { return }
        learningItem = nil
        let count = itemAppearance.viewCount(learning.key)
        guard count > 0 else {
            say(arabic ? "لم أر الغرض بوضوح. حاول مرة أخرى بإضاءة أفضل." : "I could not see it clearly. Try again with more light."); return
        }
        say(arabic ? "حفظت \(count) صور لـ\(learning.name)." : "Saved \(count) views of your \(learning.name).")
        // A short description for speaking only, written by the free model on this phone.
        let image = frame.capturedImage, arabic = self.arabic
        let generation = perceptionGeneration, revision = itemMemoryRevision
        let context = SceneContext(observations: [], at: ProcessInfo.processInfo.systemUptime, arabic: arabic, detail: .balanced,
                                   stationary: true, hazard: detection.hazard, requested: true)
        let question = arabic ? "صف هذا الغرض باختصار: الشكل والمادة وأي علامات. لا تخمّن اللون." : "Describe this object briefly: shape, material and any markings. Do not guess colour."
        Task { @MainActor [weak self] in
            let answer = await LocalImageAssistant.describe(image: image, question: question, context: context, situation: [:], wordAllowance: 20)
            // Only the held object (named by the child) may be named; no other objects, no "your".
            let grounded = answer.text.map { VisualGrounding.groundedDescription($0, confirmed: VisualGrounding.mentionedObjects(learning.name)) } ?? ""
            guard let self, self.perceptionGeneration == generation, self.itemMemoryRevision == revision,
                  self.items.find(learning.name)?.key == learning.key,
                  !grounded.isEmpty, case let text = grounded, !SpatialClaimGuard.containsSpatialClaim(text),
                  !SaudiBanknotePolicy.containsUnverifiedMoneyValue(text),
                  !ClothingColorCommand.containsUnverifiedColorClaim(text) else { return }
            if self.items.describe(learning.name, as: text) { self.persistItems() }
        }
    }

    private func spokenDescription(_ item: RememberedItem) -> String {
        guard let text = item.description, !SpatialClaimGuard.containsSpatialClaim(text),
              !SaudiBanknotePolicy.containsUnverifiedMoneyValue(text),
              !ClothingColorCommand.containsUnverifiedColorClaim(text) else { return "" }
        return arabic ? " وصفه: \(text)" : " It looks like this: \(text)"
    }

    /// Finds the saved item by its look. Same → measured position; similar → honest doubt and a request
    /// to turn it; not seen → last-seen memory and its description.
    private func findItemByLook(_ item: RememberedItem, name: String, frame: ARFrame) {
        guard let observation = lastObservation else { return }
        let keys = items.items.map(\.key), facing = currentBodyForward(), arabic = self.arabic
        let request = requestID, generation = perceptionGeneration, capturedAt = lastFrameWallTime
        let mapRevision = indoor.revision, alignmentRevision = indoor.alignmentRevision
        lookupInFlight = true
        itemAppearance.find(item.key, among: keys, image: frame.capturedImage) { [weak self] result, x, y in
            guard let self, self.requestID == request, self.perceptionGeneration == generation else { return }
            self.lookupInFlight = false
            guard self.items.find(name)?.key == item.key,
                  ProcessInfo.processInfo.systemUptime >= capturedAt,
                  ProcessInfo.processInfo.systemUptime - capturedAt < 0.5,
                  self.perceptionResultAllowed(request: request, generation: generation,
                    capturedAt: capturedAt, observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else { return }
            if !Self.objectInteractionGuidanceValidated {
                switch result {
                case .same, .similar: self.say(ObjectSearch.unconfirmed(label: item.name, arabic: arabic))
                case .none: self.say(ItemMemory.answer(for: item, asked: name, now: Date(), sameFrame: false,
                    measuredRelation: nil, arabic: arabic) + self.spokenDescription(item))
                }
                return
            }
            let measured = { (label: String) -> String? in
                guard let point = DepthSampler.worldPoint(from: frame, uprightX: x, uprightY: y),
                      let relation = SpatialFacts.relation(from: observation.camera, facing: facing ?? observation.forward, to: point) else { return nil }
                let phrase = SpatialFacts.phrase(label: label, relation: relation, arabic: arabic, inView: true)
                return facing == nil ? (arabic ? "من الكاميرا: " : "From the camera: ") + phrase : phrase
            }
            switch result {
            case .same:
                self.say(measured(arabic ? item.name : "Your \(item.name)") ?? (arabic ? "\(item.name) في مجال الكاميرا." : "Your \(item.name) is in the camera view."))
            case .similar:
                let position = measured(arabic ? "الغرض المشابه" : "The similar one").map { " " + $0 } ?? ""
                self.say((arabic ? "أرى شيئاً يشبه \(item.name) لكنني لست متأكداً أنه لك." : "I see something like your \(item.name), but I can't be sure it's yours.")
                         + position + (arabic ? " أحتاج صورة أخرى واضحة قبل تحديده." : " I need another clear view before identifying it."))
            case .none:
                self.say(ItemMemory.answer(for: item, asked: name, now: Date(), sameFrame: false, measuredRelation: nil, arabic: arabic)
                         + self.spokenDescription(item))
            }
        }
    }

    /// "Is this my cup?" while holding something up: checked by image comparison only.
    private func verifyHeldItem(_ name: String) -> Bool {
        guard let item = items.find(name) else {
            say(ItemMemory.answer(for: nil, asked: name, now: Date(), sameFrame: false, measuredRelation: nil, arabic: arabic)); return true
        }
        guard itemAppearance.viewCount(item.key) > 0, running, !simulation, detection.hazard == .observing,
              let frame = session.currentFrame else {
            say(arabic ? "لم أحفظ شكل \(item.name) بعد. قل: هذا \(item.name)، وأنت تمسكه." : "I haven't saved how your \(item.name) looks yet. Say: this is my \(item.name), while holding it."); return true
        }
        guard let observation = lastObservation else { return true }
        let request = requestID, generation = perceptionGeneration, capturedAt = lastFrameWallTime
        let mapRevision = indoor.revision, alignmentRevision = indoor.alignmentRevision
        lookupInFlight = true
        itemAppearance.find(item.key, among: items.items.map(\.key), image: frame.capturedImage) { [weak self] result, _, _ in
            guard let self, self.requestID == request, self.perceptionGeneration == generation else { return }
            self.lookupInFlight = false
            guard self.items.find(name)?.key == item.key,
                  ProcessInfo.processInfo.systemUptime >= capturedAt,
                  ProcessInfo.processInfo.systemUptime - capturedAt < 0.5,
                  self.perceptionResultAllowed(request: request, generation: generation,
                    capturedAt: capturedAt, observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else { return }
            guard Self.objectInteractionGuidanceValidated else {
                self.say(self.arabic ? "لا أستطيع تأكيد أن هذا هو غرضك المحدد من هذه المقارنة." : "I cannot confirm this is your exact item from this comparison.")
                return
            }
            switch result {
            case .same: self.say(self.arabic ? "نعم، هذا \(item.name)." : "Yes, this is your \(item.name).")
            case .similar: self.say(self.arabic ? "يشبه \(item.name) لكنني لست متأكداً. أدره ببطء." : "It looks like your \(item.name), but I can't be sure. Turn it slowly.")
            case .none: self.say(self.arabic ? "لا يبدو أنه \(item.name)." : "This doesn't look like your \(item.name).")
            }
        }
        return true
    }
}

// MARK: - Saved memory review (privacy: see and delete everything the phone remembers)
extension NavigationModel {
    var savedItems: [RememberedItem] { items.items }
    func itemViewCount(_ item: RememberedItem) -> Int { itemAppearance.viewCount(item.key) }
    @discardableResult func forgetItem(_ item: RememberedItem) -> Bool {
        itemMemoryRevision = UUID()
        cancelDescription()
        if learningItem?.key == item.key { learningItem = nil }
        do {
            guard let memory = places.memory, itemAppearance.forget(item.key) else { throw MemoryError.missing }
            var updated = items; updated.forget(item.name)
            try memory.saveValue(namespace: "items", id: "all", payload: JSONEncoder().encode(updated))
            items = updated; objectWillChange.send(); return true
        } catch {
            say(arabic ? "لم يكتمل الحذف. أعد المحاولة عند توفر التخزين." : "Deletion could not finish. Retry when storage is available.")
            return false
        }
    }
    var savedRooms: [(id: String, name: String, visits: Int)] {
        companion.memory.rooms.map { (id: $0.key, name: $0.value.name ?? (arabic ? "غرفة دون اسم" : "Unnamed room"), visits: $0.value.visits) }
            .sorted { $0.name < $1.name }
    }
    /// Removes the room's saved pictures, fingerprints and furniture labels; the room stays known.
    func forgetRoomPictures(_ id: String) {
        invalidatePerceptionWork()
        guard roomRecall.forget(room: id) else {
            say(arabic ? "تعذر حذف صور الغرفة. أعد المحاولة." : "Room pictures could not be deleted. Please retry."); return
        }
        objectWillChange.send()
    }
    /// Deletes a saved place and everything derived from it: scans, room pictures, the companion's
    /// room record, and the current-place state if it was this place.
    func deletePlace(_ place: SavedPlace) {
        let roomID = "place:\(place.id.uuidString)"
        if recognizedPlace?.id == place.id { recognizedPlace = nil; invalidateRecognizedRoom() }
        if awaitingPlace?.id == place.id { awaitingPlace = nil; placeRecovery.reset(); placeRecoveryQuestion = "" }
        invalidatePerceptionWork()
        if companion.memory.rooms[roomID] != nil { forgetRoom(roomID) } else { _ = roomRecall.forget(room: roomID) }
        places.delete(place)
        objectWillChange.send()
    }

    /// Removes everything about the room: pictures, visits and its name.
    func forgetRoom(_ id: String) {
        invalidatePerceptionWork()
        do {
            guard let memory = places.memory, roomRecall.forget(room: id) else { throw MemoryError.missing }
            var updated = companion.memory; updated.forgetRoom(id)
            try memory.saveValue(namespace: "companion", id: "memory", payload: JSONEncoder().encode(updated))
            companion.memory = updated; changeDetector.forgetRoom(id)
        } catch {
            say(arabic ? "لم يكتمل حذف الغرفة. أعد المحاولة." : "Room deletion could not finish. Please retry."); return
        }
        if recognizedRoomID == id { invalidateRecognizedRoom() }
        objectWillChange.send()
    }
    var learnedHints: [LearnedHint] { companion.memory.hints }
    func removeHint(_ id: String) { companion.memory.removeHint(id: id); persistCompanion(); objectWillChange.send() }
}

// MARK: - Reading tools: live text, a page, codes, light, explore by touch (Seeing AI-style, 2026-10-22)
// Everything spoken here comes from on-device Vision, ARKit light estimates and code. No model.
struct ExploreSnapshot {
    let image: UIImage
    /// Upright, top-left normalised rectangles with code-written labels.
    let regions: [(label: String, rect: CGRect)]
}

extension NavigationModel {
    @discardableResult func routeReadingToolCommand(_ text: String) -> Bool {
        guard let command = ReadingToolCommand.parse(text) else { return false }
        switch command {
        case .start(let tool): startReadingTool(tool)
        case .stop: stopReadingTool(announce: true)
        case .nameProduct(let name):
            var updated = products
            guard let code = lastScannedCode, updated.save(name, for: code) else {
                speakRequested(arabic ? "امسح رمز المنتج أولاً، ثم قل: سمّه، والاسم." : "Scan the product's code first, then say: call this, and its name.")
                return true
            }
            do {
                guard let memory = places.memory else { throw CocoaError(.fileWriteUnknown) }
                try memory.saveValue(namespace: "products", id: "names", payload: JSONEncoder().encode(updated))
                products = updated
                speakOperation(arabic ? "حفظت هذا المنتج باسم \(name)." : "Saved this product as \(name).")
            } catch {
                speakOperation(arabic ? "تعذر حفظ الاسم. حاول مجدداً." : "The name could not be saved. Please try again.")
            }
        }
        return true
    }

    func startReadingTool(_ tool: ReadingTool) {
        // Switching tools invalidates model, currency, colour, face and earlier reader work first.
        cancelDescription()
        _ = feedback.stopInformation(announceCancellation: false)
        #if BLIND_FAMILIAR_PEOPLE
        familiarPeople.cancelSearchForNewGoal()
        #endif
        guard running, !simulation, !places.scanning, assistantSession.foregroundActive,
              detection.hazard == .observing else {
            speakOperation(arabic ? "أحتاج كاميرا جاهزة وتنبيهات مستقرة لهذا. شغّل الكاميرا أولاً." : "I need a ready camera and stable monitoring for that. Turn the camera on first.")
            return
        }
        readingWork.begin()
        readingTool = tool; readingInFlight = false; lastReadingLook = -.infinity
        readingStarted = ProcessInfo.processInfo.systemUptime
        liveTextReader = LiveTextReader(); lastDocumentGuidance = nil; documentStability.reset(); lastLightLevel = nil
        let intro: String
        switch tool {
        case .liveText: intro = arabic ? "أقرأ النص الذي أراه. قل: أوقف القراءة، للتوقف." : "Reading text as I see it. Say stop reading to stop."
        case .document: intro = arabic ? "وجّه الهاتف نحو الصفحة. سأساعدك على وضعها كاملة." : "Point the phone at the page. I'll help you fit all of it in."
        case .barcode: intro = arabic ? "أبحث عن رمز. أدر المنتج ببطء؛ الرموز غالباً في الخلف أو الأسفل." : "Looking for a code. Turn the product slowly; codes are often on the back or bottom."
        case .light: intro = arabic ? "كاشف الضوء يعمل. الصفير أسرع كلما زاد الضوء." : "Light detector on. Faster beeps mean more light."
        }
        speakOperation(intro)
    }

    func stopReadingTool(announce: Bool) {
        let hadDocumentSpeech = documentSpeechID != nil
        readingWork.cancel(); readingTask?.cancel(); readingTask = nil
        readingTool = nil; readingInFlight = false; documentStability.reset(); documentOrigin = nil
        documentChunks = []; documentSpeechID = nil
        // Invalidate ownership before synchronous interruption callbacks can run.
        if hadDocumentSpeech { _ = feedback.stopInformation(announceCancellation: false) }
        if announce {
            _ = feedback.stopInformation(announceCancellation: false)
            // Speech onset or command dispatch may already have cancelled the reader.
            speakOperation(arabic ? "توقفت القراءة." : "Stopped reading.")
        }
    }

    private struct ReadingCapture {
        let token: UUID
        let request: UUID
        let generation: UUID
        let sessionGeneration: UInt64
        let capturedAt: Double
        let observation: Observation
        let mapRevision: UUID
        let alignmentRevision: UUID
        let origin: Point3
        let forward: Point3
    }

    private func readingCapture(frame: ARFrame) -> ReadingCapture? {
        guard assistantSession.foregroundActive, running, !simulation, !places.scanning,
              detection.hazard == .observing, let observation = lastObservation, observation.trackingNormal,
              UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).contains(where: { $0.interfaceOrientation == .portrait }) else { return nil }
        let transform = frame.camera.transform
        return ReadingCapture(token: readingWork.token, request: requestID, generation: perceptionGeneration,
            sessionGeneration: assistantSession.generation, capturedAt: lastFrameWallTime, observation: observation,
            mapRevision: indoor.revision, alignmentRevision: indoor.alignmentRevision,
            origin: Point3(Double(transform.columns.3.x), Double(transform.columns.3.y), Double(transform.columns.3.z)),
            forward: Point3(-Double(transform.columns.2.x), -Double(transform.columns.2.y), -Double(transform.columns.2.z)))
    }

    private func readingCaptureAllowed(_ capture: ReadingCapture) -> Bool {
        assistantSession.foregroundActive && assistantSession.generation == capture.sessionGeneration &&
        readingWork.accepts(capture.token, capturedAt: capture.capturedAt, now: ProcessInfo.processInfo.systemUptime) &&
        visualCapturePoseAllowed(origin: capture.origin, forward: capture.forward) &&
        UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).contains(where: { $0.interfaceOrientation == .portrait }) &&
        perceptionResultAllowed(request: capture.request, generation: capture.generation,
            capturedAt: capture.capturedAt, observation: capture.observation,
            mapRevision: capture.mapRevision, alignmentRevision: capture.alignmentRevision)
    }

    private func updateReadingTool(frame: ARFrame) {
        if readingTool == .document, !documentChunks.isEmpty {
            speakNextDocumentChunk(); return
        }
        guard let tool = readingTool, !readingInFlight,
              let capture = readingCapture(frame: frame), readingCaptureAllowed(capture) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let interval: Double = tool == .liveText ? 0.7 : tool == .barcode ? 0.3 : 0.5
        guard now - lastReadingLook >= interval else { return }
        lastReadingLook = now
        let arabic = self.arabic
        if tool == .light {
            guard let lumens = frame.lightEstimate.map({ Double($0.ambientIntensity) }), let level = LightLevel.from(lumens: lumens) else { return }
            if level != lastLightLevel, speakRequested(level.speech(arabic: arabic)) { lastLightLevel = level }
            if !voice.awaitingUtterance, now - lastReadingBeep >= level.beepInterval {
                lastReadingBeep = now; feedback.beacon(sector: 0, distance: 1)
            }
            return
        }
        if tool == .barcode, now - readingStarted > 30 {
            stopReadingTool(announce: false)
            speakRequested(arabic ? "لم أجد رمزاً بعد. أدر المنتج ببطء وحاول مجدداً." : "No code found yet. Turn the product slowly and try again.")
            return
        }
        if tool == .barcode, !voice.awaitingUtterance, now - lastReadingBeep >= 0.8 {
            lastReadingBeep = now; feedback.beacon(sector: 0, distance: 1)
        }
        readingInFlight = true
        let image = frame.capturedImage
        readingTask = Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                let lines = tool == .liveText ? ((try? VisionService.textLines(image: image, orientation: .right, arabic: arabic, accurate: false)) ?? []) : []
                let corners = tool == .document ? ((try? VisionService.documentCorners(image: image, orientation: .right)) ?? nil) : nil
                let code = tool == .barcode ? ((try? VisionService.code(image: image, orientation: .right)) ?? nil) : nil
                return (lines, corners, code)
            }.value
            guard let self, self.readingWork.owns(capture.token) else { return }
            // A previous session must never clear the new session's in-flight state.
            self.readingInFlight = false; self.readingTask = nil
            guard !Task.isCancelled, self.readingTool == tool, self.readingCaptureAllowed(capture) else {
                self.documentStability.reset(); return
            }
            switch tool {
            case .liveText:
                var reader = self.liveTextReader
                let fresh = reader.newLines(result.0, now: ProcessInfo.processInfo.systemUptime)
                if !fresh.isEmpty, self.speakRequested(fresh.joined(separator: ". "), replace: false) { self.liveTextReader = reader }
            case .document:
                let guidance = DocumentGuidance.evaluate(result.1)
                if let origin = self.documentOrigin,
                   !self.visualCapturePoseAllowed(origin: origin.point, forward: origin.forward) {
                    self.documentStability.reset(); self.documentOrigin = nil
                }
                if self.documentOrigin == nil { self.documentOrigin = (capture.origin, capture.forward) }
                let ready = self.documentStability.observe(result.1)
                if guidance != self.lastDocumentGuidance, self.speakOperation(guidance.speech(arabic: arabic)) {
                    self.lastDocumentGuidance = guidance
                }
                if ready { self.readWholePage(image: image, capture: capture) }
            case .barcode:
                guard let code = result.2 else { return }
                self.lastScannedCode = code.payload
                self.stopReadingTool(announce: false)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.speakRequested(CodeReading.speech(payload: code.payload, isQR: code.isQR,
                    savedName: self.products.name(for: code.payload), arabic: arabic))
            case .light: break
            }
        }
    }

    /// The page request remains active while OCR runs, so Stop/new goal/background can cancel it.
    private func readWholePage(image: CVPixelBuffer, capture: ReadingCapture) {
        guard readingCaptureAllowed(capture) else { return }
        readingInFlight = true
        let arabic = self.arabic
        readingTask = Task { @MainActor [weak self] in
            let lines = await Task.detached(priority: .userInitiated) {
                (try? VisionService.textLines(image: image, orientation: .right, arabic: arabic, accurate: true)) ?? []
            }.value
            guard let self, self.readingWork.owns(capture.token) else { return }
            self.readingInFlight = false; self.readingTask = nil
            guard !Task.isCancelled, self.readingTool == .document, self.readingCaptureAllowed(capture) else {
                self.documentStability.reset(); return
            }
            let text = lines.filter { $0.confidence >= 0.5 }.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }.map(\.text).joined(separator: " ")
            self.sceneAnswer = text
            self.currentReply = (arabic ? "من الصفحة الملتقطة: " : "From the captured page: ") + text
            if text.isEmpty {
                self.stopReadingTool(announce: false)
                self.speakOperation(arabic ? "لم أستطع قراءة نص في الصفحة." : "I couldn't read any text on the page.")
                return
            }
            // Once admitted, this is frozen OCR text, not a current spatial observation.
            // Read it in bounded phrases; completion removes each phrase, Stop cancels all.
            self.documentChunks = Self.documentReadingChunks(text, arabic: arabic)
            self.speakNextDocumentChunk()
        }
    }

    /// Uses the same tokenizer as admission, including room for the snapshot prefix at the
    /// minimum 30-word setting. Whitespace splitting miscounts hyphenated/OCR text.
    private static func documentReadingChunks(_ text: String, arabic: Bool) -> [String] {
        let tokenizer = NLTokenizer(unit: .word); tokenizer.string = text
        let tokens = tokenizer.tokens(for: text.startIndex..<text.endIndex)
        guard !tokens.isEmpty else { return [] }
        var chunks = stride(from: 0, to: tokens.count, by: 24).map { index in
            let end = index + 24 < tokens.count ? tokens[index + 24].lowerBound : text.endIndex
            return String(text[tokens[index].lowerBound..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        chunks[0] = (arabic ? "من الصفحة الملتقطة: " : "From the captured page: ") + chunks[0]
        return chunks
    }

    private func speakNextDocumentChunk() {
        guard readingTool == .document, documentSpeechID == nil, let chunk = documentChunks.first,
              readingWork.active, assistantSession.foregroundActive, running, !simulation,
              detection.hazard == .observing, !voice.awaitingUtterance, feedback.speechPriority == nil else { return }
        let id = UUID(); documentSpeechID = id
        if !speakRequested(chunk, replace: false, speechID: id) { documentSpeechID = nil }
    }

    /// Captured pictures are explicitly snapshots, never evidence of the current room or path.
    func captureExploreSnapshot() {
        cancelDescription()
        guard running, !simulation, !places.scanning, assistantSession.foregroundActive,
              detection.hazard == .observing, let frame = session.currentFrame,
              ProcessInfo.processInfo.systemUptime - lastFrameWallTime < 0.5 else {
            speakOperation(arabic ? "أحتاج كاميرا جاهزة لالتقاط صورة." : "I need a ready camera to take a picture."); return
        }
        let pixels = frame.capturedImage, arabic = self.arabic
        let oriented = CIImage(cvPixelBuffer: pixels).oriented(.right)
        guard let cg = CIContext().createCGImage(oriented, from: oriented.extent) else { return }
        let image = UIImage(cgImage: cg), token = exploreRequest, generation = assistantSession.generation
        exploreTask = Task { @MainActor [weak self] in
            let regions = await Task.detached(priority: .userInitiated) {
                (try? VisionService.exploreRegions(image: pixels, orientation: .right, arabic: arabic)) ?? []
            }.value
            guard let self, !Task.isCancelled, self.exploreRequest == token,
                  self.assistantSession.generation == generation, self.assistantSession.foregroundActive else { return }
            self.exploreTask = nil
            self.exploreSnapshot = ExploreSnapshot(image: image, regions: regions)
            self.speakOperation(regions.isEmpty
                ? (arabic ? "الصورة الملتقطة جاهزة. لم أتعرف على مناطق فيها." : "Captured picture ready. I didn't recognize any regions in it.")
                : (arabic ? "الصورة الملتقطة جاهزة. استكشف المناطق باللمس. هذه صورة سابقة وليست وصفاً حياً." : "Captured picture ready. Explore the regions by touch. This is a snapshot, not a live view."))
        }
    }
    func clearExploreSnapshot() {
        exploreRequest = UUID(); exploreTask?.cancel(); exploreTask = nil; exploreSnapshot = nil
    }

    /// User-selected library photo; processed only on device, kept in memory until dismissed.
    func explorePhoto(_ image: UIImage) {
        cancelDescription()
        guard assistantSession.foregroundActive, let cg = image.cgImage else {
            speakOperation(arabic ? "تعذر فتح الصورة." : "I couldn't open that photo."); return
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation), arabic = self.arabic
        let token = exploreRequest, generation = assistantSession.generation
        exploreTask = Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                let regions = (try? VisionService.exploreRegions(photo: cg, orientation: orientation, arabic: arabic)) ?? []
                let categories = (try? VisionService.photoCategories(photo: cg, orientation: orientation)) ?? []
                return (regions, categories)
            }.value
            guard let self, !Task.isCancelled, self.exploreRequest == token,
                  self.assistantSession.generation == generation, self.assistantSession.foregroundActive else { return }
            self.exploreTask = nil
            let regions = result.0, categories = result.1
            self.exploreSnapshot = ExploreSnapshot(image: image, regions: regions)
            var parts: [String] = []
            if !categories.isEmpty {
                parts.append((arabic ? "قد تُظهر الصورة: " : "The photo may show: ") + categories.joined(separator: ", ") + ".")
            }
            let texts = regions.filter { $0.label.hasPrefix(arabic ? "نص: " : "Text: ") }.prefix(3).map(\.label)
            if !texts.isEmpty { parts.append(texts.joined(separator: ". ") + ".") }
            let people = regions.filter { $0.label == (arabic ? "شخص" : "Person") }.count
            if people > 0 { parts.append(arabic ? "أشخاص: \(people)." : "People: \(people).") }
            parts.append(arabic ? "هذه صورة وليست وصفاً حياً. استكشفها باللمس." : "This is a photo, not a live view. Explore it by touch.")
            self.sceneAnswer = parts.joined(separator: " "); self.currentReply = self.sceneAnswer
            self.speakRequested(self.sceneAnswer)
        }
    }
}

extension CGImagePropertyOrientation {
    /// Maps UIKit photo orientation to the Vision orientation.
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
