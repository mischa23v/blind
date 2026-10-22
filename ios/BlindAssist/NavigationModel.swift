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
    // Always on (user, 2026-10-22): like an always-listening agent, the companion never switches
    // itself off. Listening, speech and the belt continue in the background (UIBackgroundModes
    // audio and bluetooth-central); iOS pauses the camera in the background, so that is announced
    // and repeated until the app is open again, and the camera restarts by itself.
    private var backgroundReminder: Timer?
    private var practiceTimer: Timer?
    private var cameraInterrupted = false
    private var lastCameraRestart = -Double.infinity
    @Published private(set) var running = false
    @Published private(set) var simulation = false
    @Published private(set) var detection = Detection(.stopped)
    @Published private(set) var calibrationProgress = 0.0
    @Published private(set) var message = ""
    @Published private(set) var wearableStatus = "Disconnected"
    @Published private(set) var sceneAnswer = "" {
        didSet { if !sceneAnswer.isEmpty { currentReply = sceneAnswer } }
    }
    /// What the assistant last said or wrote: the only content of the main screen, so VoiceOver
    /// reads the reply and nothing else.
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
            feedback.arabic = arabic; indoor.arabic = arabic; places.arabic = arabic; UserDefaults.standard.set(arabic, forKey: "arabic")
            // Keep hearing the child in the language they just chose.
            if oldValue != arabic, voice.wantsContinuous { reconnectListening() }
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
    private var requestID = UUID()
    private var questionTask: Task<Void, Never>?
    private var questionTimeoutTask: Task<Void, Never>?
    private let saudiBanknotes = SaudiBanknoteReferenceRecognition()
    private var currencyActive = false
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
            let at = Date()
            self.enqueueNarration { try await $0.finish(id: id, outcome: outcome, at: at) }
        }
        feedback.onIdle = { [weak self] in self?.resumePendingQuestion(); self?.listenForOfferAnswer() }
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
        voice.onFinished = { [weak self] text in self?.receiveCompanionUtterance(text) }
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
            self.message = "Room scan finished. Recalibrate the floor to resume monitoring."
        }
    }
    var supported: Bool { ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) }
    func start() {
        guard !running, !places.scanning else { return }
        guard supported else {
            message = arabic ? "لا يستطيع هذا الهاتف فحص المسار. يمكنك تجربة التدريب من المزيد." : "This phone cannot check the path. You can try practice in More."
            speakOperation(message)
            return
        }
        let id = UUID(); requestID = id
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: outdoor.requestCoarseLocation(); launchWithNearbyPlace()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.requestID == id else { return }
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
        // Pauses the camera session for a restart or practice only. Listening, speech, the belt and
        // the awake screen stay on: nothing here turns the companion off.
        indoor.invalidatePosition(); outdoor.stop(); feedback.stop(includingAlerts: true)
        practiceTimer?.invalidate(); practiceTimer = nil
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
        phoneDetection = detector.process(observation)
        survey.observe(observation, floor: detector.floorHeight)
        calibrationProgress = detector.calibrationProgress; publish()
        #if BLIND_FAMILIAR_PEOPLE
        familiarPeople.revalidate(model: self)
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
        if ambientDescriptions, !returning, objectSearch == nil, !lookupInFlight, !voice.awaitingUtterance, lastFrameWallTime - lastAmbientAttempt >= 4,
           attention.permitsAmbient(detail: detail, urgent: detection.hazard != .observing, now: lastFrameWallTime) {
            lastAmbientAttempt = lastFrameWallTime
            readScene(cloud: false, automatic: true)
        }
    }
    #if BLIND_FAMILIAR_PEOPLE
    @discardableResult func routeFamiliarPeopleCommand(_ text: String) -> Bool {
        guard let command = FamiliarPeopleCommand.parse(text) else { return false }
        if currencyActive || colorActive { cancelDescription() }
        guard command == .cancel || command == .stop || !running || detection.hazard == .observing else { message = "Current monitoring alerts take priority."; return true }
        if !showFamiliarPeople && !familiarPeople.enabled {
            showFamiliarPeople = true
            familiarPeople.reload()
        }
        familiarPeople.handle(command, model: self)
        return true
    }
    /// Short-lived rear-camera input for the explicit experimental screen only.
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
        if currencyActive || colorActive { cancelDescription() }
        perceptionGeneration = UUID(); recallInFlight = false; learningItem = nil
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
        questionTimeoutTask?.cancel(); questionTimeoutTask = nil
        objectSearch?.cancel(); objectSearch = nil
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
        // Act once when monitoring is lost or a hazard appears, not on every 100 ms tick. A
        // conversation reply does not depend on the camera view, so it is not cancelled for lost
        // monitoring; camera work (searches, scene answers) is.
        if detection.hazard.requiresImmediateAttention && !previousHazard.requiresImmediateAttention {
            if questionIsChat {
                objectSearch?.cancel(); objectSearch = nil; currencyActive = false; colorActive = false; pendingQuestion = nil
            } else {
                cancelDescription()
            }
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
            guard let self, self.running, !self.simulation, !self.places.scanning else { return }
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
    @discardableResult func routeSaudiBanknoteCommand(_ text: String) -> Bool {
        guard SaudiBanknoteCommand.matches(text) else { return false }
        cancelDescription()
        #if BLIND_FAMILIAR_PEOPLE
        familiarPeople.cancelSearchForNewGoal()
        #endif
        guard SaudiBanknoteReferenceRecognition.isAvailable else {
            message = arabic ? "التعرف على الأوراق النقدية السعودية غير متاح في هذا الإصدار. لن أخمّن القيمة." : "Saudi banknote recognition is not available in this build. I won't guess the value."
            _ = speakOperation(message)
            return true
        }
        guard running, !simulation, !places.scanning, awaitingPlace == nil,
              attention.stationary, detection.hazard == .observing,
              UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).contains(where: { $0.interfaceOrientation == .portrait }),
              let observation = lastObservation, observation.trackingNormal,
              let frame = session.currentFrame else {
            message = arabic ? "توقف وثبّت الهاتف عمودياً وأظهر ورقة واحدة كاملة للكاميرا، ثم حاول مرة أخرى." : "Hold still with the phone upright and show one whole banknote to the camera, then try again."
            _ = speakOperation(message)
            return true
        }
        let capturedAt = lastFrameWallTime, generation = perceptionGeneration, request = requestID
        let mapRevision = indoor.revision, alignmentRevision = indoor.alignmentRevision
        guard SaudiBanknotePolicy.fresh(capturedAt: capturedAt, now: ProcessInfo.processInfo.systemUptime),
              perceptionResultAllowed(request: request, generation: generation, capturedAt: capturedAt,
                                      observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else { return true }
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
                          observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else { return }
                self.message = result.speech(arabic: self.arabic)
                // Value answers retain the ordinary attention/budget gate. Never queue stale money.
                _ = self.speakRequested(self.message, narrationID: request)
            } catch is CancellationError {
                return
            } catch {
                guard self.requestID == request, self.currencyActive, self.attention.stationary,
                      self.visualCapturePoseAllowed(origin: currencyOrigin, forward: currencyForward),
                      SaudiBanknotePolicy.fresh(capturedAt: capturedAt, now: ProcessInfo.processInfo.systemUptime),
                      self.perceptionResultAllowed(request: request, generation: generation, capturedAt: capturedAt,
                          observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else { return }
                self.message = self.arabic ? "تعذر التعرف على قيمة الورقة. لن أخمّن." : "I couldn't identify the banknote. I won't guess."
                _ = self.speakOperation(self.message)
            }
        }
        return true
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
        if !automatic, routeSaudiBanknoteCommand(question) { return }
        if !automatic, routeClothingColorCommand(question) { return }
        if automatic, currencyActive || colorActive { return }
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
                for _ in 0..<2 {
                    try await Task.sleep(for: .milliseconds(150))
                    guard let later = self.session.currentFrame?.capturedImage else { break }
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
                            ? (arabic ? "قد تُظهر الكاميرا درجاً أو عائقاً. الحساسات وحدها تحدد موقعه، وتنبيهاتها مستمرة." : "The camera may show stairs, a step or an obstacle. Only the sensors give its position, and their alerts continue.")
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
                self.sceneAnswer = answer
                self.lastSceneContent = answer; self.lastSceneSpoken = ProcessInfo.processInfo.systemUptime
                if !automatic { self.assistantDialogue.record(role: "assistant", text: answer); self.persistDialogue() }
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
        alreadyAdmitted: Bool = false, narrationID: UUID? = nil, alert: Detection? = nil) -> Bool {
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
        let spoken = feedback.deliver(admitted, narrationID: narrationID, alert: alert)
        if spoken { currentReply = candidate.text } else { companion.release(candidate.key) }
        return spoken
    }
    @discardableResult private func dispatchText(_ text: String, kind: InformationCandidate.Kind,
        requested: Bool = false, replace: Bool = false, revision: String = UUID().uuidString,
        narrationID: UUID? = nil, alert: Detection? = nil) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let candidate = InformationCandidate(key: "speech:" + revision, kind: kind, text: text,
            words: Self.wordCount(text), revision: revision, createdAt: now, expiresAt: now + 2,
            requested: requested)
        if replace { _ = feedback.stopInformation(announceCancellation: false) }
        let delivered = deliverCandidate(candidate, narrationID: narrationID, alert: alert)
        if replace && !delivered { feedback.requestCancellationAnnouncement() }
        return delivered
    }
    /// Descriptive answers and repeats retain normal information budgets.
    @discardableResult func speakRequested(_ text: String, replace: Bool = true, narrationID: UUID? = nil) -> Bool {
        dispatchText(text, kind: .answer, requested: true, replace: replace, narrationID: narrationID)
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
        CompanionMoment(now: now, goalActive: !assistantDialogue.goal.isEmpty, focusedTaskActive: focusedFaceSearch || currencyActive || colorActive || objectSearch != nil || busy || pendingQuestion != nil || lookupInFlight,
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
    func receiveCompanionUtterance(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
        if ["i'm standing on a level floor", "i am standing on a level floor", "أنا واقف على أرض مستوية"].contains(normalized),
           running && detection.hazard == .needsCalibration { calibrate(); return }
        // The person can interrupt ordinary information, never suppress urgent alerts.
        _ = feedback.stopInformation()
        #if BLIND_FAMILIAR_PEOPLE
        if routeFamiliarPeopleCommand(text) { return }
        familiarPeople.cancelSearchForNewGoal()
        #endif
        // A whole-utterance yes/no answers the current offer; anything longer is a question.
        if companion.pendingOffer != nil, let answer = AssistantControl.offerAnswer(text) {
            answerCompanionOffer(answer); return
        }
        assistantQuestion = text
        // Starting a voice question authorizes answering it locally after recognition.
        // No cloud permission is inferred; the ongoing microphone was enabled by the companion session.
        readScene(cloud: false, question: text)
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
        applyCompanion(.utterance(utterance), question: question, reply: nil)
    }

    private func applyCompanion(_ action: CompanionAction, question: String, reply: String?) {
        let oldGoal = companionWorkingState.goal
        var text = reply ?? ""
        var findObject: String?
        switch action {
        case .utterance(let utterance):
            text = companionWorkingState.respond(to: utterance, message: question, arabic: arabic)
            if case .find(let object) = utterance { findObject = object }
        case .cancelTask:
            text = companionWorkingState.cancelTask(arabic: arabic)
        case .newTask(let task):
            companionWorkingState.changeGoal(task)
        }
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
        sceneAnswer = text
        if textOnly || speakRequested(text) {
            assistantDialogue.record(role: "assistant", text: text)
            persistDialogue()
        }
    }

    private func answerConversation(_ question: String) {
        recordCompanionMessage(question)
        let dialogue = assistantDialogue
        let situation = AssistantSituation.snapshot(dialogue: dialogue, preview: nil, layout: nil,
            preferences: assistantPreferences, arabic: arabic)
        let id = UUID()
        requestID = id; busy = true; sceneAnswer = ""; questionIsChat = true
        questionTimeoutTask?.cancel()
        questionTimeoutTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, self.requestID == id, self.busy else { return }
            self.cancelDescription()
            if self.sceneAnswer.isEmpty {
                self.sceneAnswer = self.arabic ? "استغرق الرد وقتاً طويلاً. حاول مرة أخرى." : "That reply took too long. Please try again."
            }
        }
        questionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let revision = self.companionWorkingState.goalRevision
            let answer = await LocalImageAssistant.converse(dialogue: dialogue, arabic: self.arabic, preferredName: self.preferredName, situation: situation, workingState: self.companionWorkingState) { @MainActor [weak self] partial in
                guard let self, self.requestID == id, !Task.isCancelled else { return }
                self.sceneAnswer = partial
            }
            // A new request or changed task while the model ran makes this answer obsolete.
            guard !Task.isCancelled, self.requestID == id, self.companionWorkingState.goalRevision == revision else { return }
            self.questionTimeoutTask?.cancel(); self.questionTimeoutTask = nil
            self.busy = false; self.questionIsChat = false
            if let action = answer.action {
                self.applyCompanion(action, question: question, reply: answer.text)
                return
            }
            guard let text = answer.text else {
                self.sceneAnswer = answer.status
                self.speakOperation(answer.status)
                return
            }
            self.deliverConversationReply(text)
        }
    }

    func startVoiceQuestion() {
        guard !textOnly else { return }
        guard !running || detection.hazard == .observing else {
            repeatMonitoringStatus()
            return
        }
        cancelDescription(); feedback.stop(); voice.start(arabic: arabic)
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
        stop(); simulation = true; running = true; detector.beginCalibration()
        demonstrationTime = 0; demonstrationHazard = .observing; policy = AlertPolicy(); continuity = MonitoringContinuity()
        for _ in 0..<15 { demoFrame() }
        startWatchdog(); message = arabic ? "المحاكاة تستخدم عمقاً مولداً. لا يوجد استشعار حقيقي." : "Simulation uses generated depth. No live sensing is active."
        _ = speakMobility(arabic ? "تدريب. الحساسات الحقيقية متوقفة لمدة دقيقتين." : "Practice. Live sensors are paused for two minutes.")
        reconnectListening()
        // Practice can never leave the child without live sensing: it ends by itself.
        practiceTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in self?.endPractice() }
    }
    /// Ends practice and returns to live camera and sensors.
    func endPractice() {
        guard simulation else { return }
        stop(); start()
        _ = speakMobility(arabic ? "انتهى التدريب. الحساسات الحقيقية تعمل." : "Practice ended. Live sensors are back on.")
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
        if voice.listening { return arabic ? "أنا أستمع." : "I'm listening." }
        if busy { return arabic ? "لحظة واحدة." : "One moment." }
        if !running {
            return message.isEmpty ? (arabic ? "ماذا تريد أن نفعل؟" : "What would you like to do?") : message
        }
        if detection.hazard == .calibrating { return arabic ? "اثبت لحظة." : "Hold still a moment." }
        return arabic ? "أنا معك." : "I'm here."
    }

    func resumeExperienceIfNeeded() {
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
        backgroundReminder?.invalidate(); backgroundReminder = nil
        UIApplication.shared.isIdleTimerDisabled = true
        // Every return to the foreground brings everything back on by itself.
        if experienceActive {
            if !textOnly { if !running { start() }; reconnectListening() }
            return
        }
        experienceActive = true
        // Load the on-device model before the first message so the first reply is not delayed.
        LocalImageAssistant.prewarm(arabic: arabic)
        let firstVisit = !UserDefaults.standard.bool(forKey: "companion-introduced")
        companionGreeting = firstVisit
            ? (arabic ? "مرحباً، أنا مساعدك. تحدث معي في أي وقت. ماذا تريد أن نفعل؟" : "Hello, I'm your assistant. You can talk to me any time. What would you like to do?")
            : (arabic ? "مرحباً. ماذا سنفعل اليوم؟" : "Hi. What are we doing today?")
        let capability = supported
            ? (arabic ? "قف على أرض مستوية وقل أنا واقف على أرض مستوية لإعداد قياس الأرض." : "To set up ground measurements, stand on a level floor and say I'm standing on a level floor.")
            : (arabic ? "هذا الهاتف لا يستطيع قياس المسار. يمكننا التحدث عن هدفك." : "This phone cannot measure the path. We can still talk about your goal.")
        // Greet before the camera starts so the greeting is not crowded out by start-up status;
        // the first-visit introduction is marked heard only when it was actually delivered.
        if speakOperation(companionGreeting + " " + capability) || textOnly {
            UserDefaults.standard.set(true, forKey: "companion-introduced")
        }
        if !textOnly { start(); voice.startContinuous(arabic: arabic) }
    }

    /// iOS pauses the camera when the app is in the background or the screen locks. Listening,
    /// speech and the belt keep running; the camera loss is announced and repeated until reopened.
    func suspendExperience() {
        guard !textOnly, experienceActive else { return }
        message = arabic ? "توقفت الكاميرا لأن التطبيق في الخلفية. افتح المساعد لأرى مجدداً. ما زلت أستمع، والحزام يعمل."
            : "The camera stopped because the app is in the background. Open Blind Assist so I can see again. I'm still listening, and the belt still works."
        _ = speakMobility(message)
        backgroundReminder?.invalidate()
        backgroundReminder = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            _ = self.speakMobility(self.arabic ? "الكاميرا ما زالت متوقفة. افتح المساعد." : "The camera is still off. Please open Blind Assist.")
        }
    }

    func reconnectListening() { if !textOnly { voice.startContinuous(arabic: arabic) } }

    func startExperience() {
        start()
        reconnectListening()
    }

    /// There is no off switch: "restart" pauses the camera and sensors for a moment and starts
    /// them again, keeping listening and the belt on throughout.
    func restartSensors() {
        _ = speakMobility(arabic ? "أعيد تشغيل الكاميرا والحساسات." : "Restarting the camera and sensors.")
        if running { stop() }
        start()
        reconnectListening()
        wearables.connect()
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
        guard !textOnly, !voice.continuous, listenAfterQuestions, let offer = companionOffer, companion.pendingOffer != nil, !voice.awaitingUtterance,
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
            if sameFrame, let target = item.position, let observation = lastObservation,
               let here = indoor.mapPosition(camera: observation.camera),
               let facing = currentBodyForward().flatMap({ indoor.mapDirection($0) }),
               let measured = SpatialFacts.relation(from: here, facing: facing, to: target) {
                relation = SpatialFacts.phrase(label: item.name, relation: measured, arabic: arabic, inView: nil)
            }
            say(ItemMemory.answer(for: item, asked: name, now: Date(), sameFrame: sameFrame, measuredRelation: relation, arabic: arabic))
            return true
        }
        if fact != nil { return false }
        return locate(LocateCommand.target(question) ?? name, question: question)
    }

    /// Live search (2026-10-22): the sensors look at fresh frames for up to ObjectSearch.duration
    /// seconds. Found: LiDAR measures it and code speaks it plainly ("a cup", not "your cup").
    /// Time up: "not located", never "not here". The image model may add one uncertain hint.
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
              lastObservation?.trackingNormal == true else { return }
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
                self.searchInFlight = false
                guard var current = self.objectSearch, current.active, current.target == target, current.startedAt == search.startedAt else { return }
                // The depth point is fixed in the world, so direction and distance are measured from
                // where the person is now. Old frames, lost tracking or a new request discard the result.
                let now = ProcessInfo.processInfo.systemUptime
                var phrase: String?
                let current = self.running && self.requestID == request && self.perceptionGeneration == generation &&
                    self.indoor.revision == mapRevision && self.indoor.alignmentRevision == alignmentRevision &&
                    now - capturedAt < 2.0 && self.lastObservation?.trackingNormal == true
                if let found, current, let here = self.lastObservation {
                    if let point = DepthSampler.worldPoint(from: frame, uprightX: found.x, uprightY: found.y),
                       let measured = SpatialFacts.relation(from: here.camera, facing: self.currentBodyForward() ?? here.forward, to: point) {
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
                    self.recordSearch(target, located: true)
                    if let phrase { self.say(phrase) }
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
                  ProcessInfo.processInfo.systemUptime - capturedAt < 1.5,
                  let here = self.lastObservation, here.trackingNormal else { return }
            // "On the left of the camera view" is only true if the camera has not turned since.
            let moved = hypot(here.camera.x - origin.camera.x, here.camera.z - origin.camera.z)
            let turned = acos(max(-1, min(1, (here.forward.x * origin.forward.x + here.forward.z * origin.forward.z) /
                max(1e-6, hypot(here.forward.x, here.forward.z) * hypot(origin.forward.x, origin.forward.z))))) * 180 / .pi
            guard moved < 0.3, turned < 10 else { return }
            self.say(ObjectSearch.hint(target: target, side: side, arabic: arabic))
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
            self?.lookupInFlight = false
            guard let self, self.items.find(name)?.key == item.key,
                  self.perceptionResultAllowed(request: request, generation: generation,
                    capturedAt: capturedAt, observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else { return }
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
                         + position + (arabic ? " إن استطعت الوصول إليه، ارفعه وأدره لأتحقق." : " If you can reach it, hold it up and turn it so I can check."))
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
            self?.lookupInFlight = false
            guard let self, self.items.find(name)?.key == item.key,
                  self.perceptionResultAllowed(request: request, generation: generation,
                    capturedAt: capturedAt, observation: observation, mapRevision: mapRevision, alignmentRevision: alignmentRevision) else { return }
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

