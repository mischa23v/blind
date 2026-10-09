import SwiftUI
import ARKit
import AVFoundation
import CoreImage
import ImageIO
import Combine
import BlindCore
import BlindMemory
import NaturalLanguage
import os

enum AssistantPerformance {
    // Timing only: never attach scene text, names, map contents or credentials.
    static let signposter = OSSignposter(subsystem: "org.blindassist.mobility", category: "AssistantPerformance")
}

final class NavigationModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published private(set) var running = false
    @Published private(set) var simulation = false
    @Published private(set) var detection = Detection(.stopped)
    @Published private(set) var calibrationProgress = 0.0
    @Published private(set) var message = ""
    @Published private(set) var wearableStatus = "Disconnected"
    @Published private(set) var sceneAnswer = ""
    @Published private(set) var busy = false
    @Published private(set) var attentionMode: AttentionMode = .moving
    @Published private(set) var returnStatus = ""
    @Published private(set) var returning = false
    @Published var assistantQuestion = ""
    @Published var objectiveDraft = ""
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
        didSet { if oldValue != fixedBodyMount { cancelDescription(); feedback.interruptAmbient() } }
    }
    @Published private(set) var serviceStatus = ""
    @Published private(set) var localImageStatus = ""
    @Published var ambientDescriptions = UserDefaults.standard.bool(forKey: "ambient-descriptions") {
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
    @Published var arabic = UserDefaults.standard.bool(forKey: "arabic") { didSet { feedback.arabic = arabic; indoor.arabic = arabic; places.arabic = arabic; UserDefaults.standard.set(arabic, forKey: "arabic") } }
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
    private var questionIsAutomatic = false
    private var pendingQuestion: PendingQuestion?
    private var awaitingPlace: SavedPlace?
    private var placeRecovery = PlaceRecovery()
    private let imageContext = CIContext()
    private var demonstrationTime = 0.0
    private var demonstrationHazard: Hazard = .observing
    override init() {
        super.init(); session.delegate = self; session.delegateQueue = .main
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
        feedback.onIdle = { [weak self] in self?.resumePendingQuestion() }
        for publisher in [places.objectWillChange, indoor.objectWillChange, outdoor.objectWillChange, mapping.objectWillChange, journeys.objectWillChange, voice.objectWillChange, survey.objectWillChange, visualStairs.objectWillChange, peopleTracking.objectWillChange] {
            publisher.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        }
        wearables.onUpdate = { [weak self] in
            guard let self else { return }
            self.wearableStatus = self.wearables.status
            // A received danger packet must not wait for the 100 ms watchdog tick.
            if self.running { self.publish() }
        }
        voice.onFinished = { [weak self] text in
            guard let self else { return }
            // A whole-utterance yes/no answers the current offer; anything longer is a question.
            if self.companion.pendingOffer != nil, let answer = AssistantControl.offerAnswer(text) {
                self.answerCompanionOffer(answer); return
            }
            self.assistantQuestion = text
            // Starting a voice question authorizes answering it locally after recognition.
            // No new cloud permission or continuous microphone access is inferred.
            self.readScene(cloud: false, question: text)
        }
        visualStairs.onUpdate = { [weak self] in
            guard let self, self.running, !self.simulation, !self.places.scanning else { return }
            self.publish()
            self.resumePendingQuestion()
        }
        places.onMessage = { [weak self] text in self?.feedback.speak(text) }
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
        guard supported else { message = "This device does not support LiDAR scene depth. You can try simulation."; return }
        let id = UUID(); requestID = id
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: launch()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.requestID == id else { return }
                    if granted { self.launch() } else { self.message = "Camera permission denied. Enable it in iPhone Settings." }
                }
            }
        default: message = "Camera permission denied. Enable it in iPhone Settings."
        }
    }
    private func launch(map: ARWorldMap? = nil) {
        peopleTracking.reset()
        fixedBodyMount = false
        recognizedPlace = nil
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
        startWatchdog(); message = "Mount the rear camera facing ahead and slightly down. Calibrate on a known level floor."
    }
    func stop() {
        peopleTracking.reset()
        fixedBodyMount = false
        visualStairs.reset()
        survey.invalidate()
        voice.cancel(); stopReturn()
        mapping.stop(); journeys.finish()
        attention.resetMotion()
        requestID = UUID(); questionTask?.cancel(); questionTask = nil; busy = false
        places.cancelScan(); session.pause(); watchdog?.invalidate(); watchdog = nil
        detector.reset(); continuity = MonitoringContinuity(); lastObservation = nil; recognizedPlace = nil; awaitingPlace = nil
        placeRecovery.reset(); placeRecoveryQuestion = ""
        indoor.invalidatePosition(); outdoor.stop(); wearables.disconnect(); feedback.stop(includingAlerts: true)
        running = false; simulation = false; phoneDetection = Detection(.stopped); detection = phoneDetection
        UIApplication.shared.isIdleTimerDisabled = false
    }
    func calibrate() {
        guard running, !places.scanning, awaitingPlace == nil else { return }
        detector.beginCalibration(); calibrationProgress = 0; phoneDetection = Detection(.calibrating)
        message = "Stand still on known level ground. Keep nearby floor in view."
        feedback.speak(arabic ? "اثبت على أرض مستوية معروفة." : "Hold still on known level ground.")
    }
    func connectWearables() { wearables.connect() }
    func repeatMonitoringStatus() {
        feedback.speak(GuidanceText.detection(detection, arabic: arabic), urgent: true)
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
                self.feedback.speak(self.placeRecoveryQuestion)
            }
            if self.simulation { self.demoFrame() }
            else if ProcessInfo.processInfo.systemUptime - self.lastFrameWallTime > 0.5 {
                // Invalidate calibration and held evidence when callbacks stop.
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
                    feedback.speak(message)
            }
            phoneDetection = Detection(.uncertain, reason: .localizing); publish(); return
        }
        guard let observation = DepthSampler.observation(from: frame) else {
            survey.invalidate()
            journeys.breakTracking(); attention.resetMotion()
            invalidateReturn()
            detector.invalidateRecentEvidence()
            phoneDetection = Detection(.uncertain, reason: DepthSampler.unavailableReason(from: frame)); lastObservation = nil; publish(); return
        }
        if !observation.trackingNormal {
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
        updateReturn(observation)
        if !returning, fixedBodyMount, indoor.isAligned, detection.hazard == .observing,
           lastFrameWallTime - lastIndoorAnnouncement >= 8 { indoorBeacon(automatic: true) }
        updateCompanionRoom(observation)
        if ambientDescriptions, !returning, !voice.listening, lastFrameWallTime - lastAmbientAttempt >= 4,
           attention.permitsAmbient(detail: detail, urgent: detection.hazard != .observing, now: lastFrameWallTime) {
            lastAmbientAttempt = lastFrameWallTime
            readScene(cloud: false, automatic: true)
        }
    }
    private func cancelDescription() {
        pendingQuestion = nil
        requestID = UUID(); questionTask?.cancel(); questionTask = nil; busy = false; questionIsAutomatic = false
    }
    private func publish() {
        let now = ProcessInfo.processInfo.systemUptime
        let previousHazard = detection.hazard
        let visual = !simulation ? visualStairs.detection(at: now).map { [$0] } ?? [] : []
        detection = continuity.process(AlertPolicy.highest(visual + [phoneDetection] + (simulation ? [] : wearables.detections(at: now))), at: now)
        if previousHazard == .uncertain && detection.hazard == .observing {
            // A status update, never an instruction to start walking.
            feedback.speak(GuidanceText.hazard(.observing, arabic: arabic), urgent: true)
        }
        if detection.hazard != .observing { feedback.interruptAmbient() }
        if detection.hazard.requiresImmediateAttention { cancelDescription(); if voice.listening { voice.cancel() } }
        if policy.shouldAnnounce(detection, at: now) {
            if detection.hazard.isUrgent {
                questionTask?.cancel(); questionTask = nil; busy = false
                if detection.reason != .visualStairs {
                    wearables.send(WearableCommand.haptic(sector: detection.sector, intensity: 220, durationMS: 300))
                }
            }
            feedback.alert(detection)
        }
    }
    func session(_ session: ARSession, didFailWithError error: Error) {
        peopleTracking.reset()
        fixedBodyMount = false
        awaitingPlace = nil; placeRecovery.reset()
        visualStairs.reset()
        invalidateReturn()
        mapping.stop(); journeys.breakTracking(); cancelDescription()
        detector.reset(); phoneDetection = Detection(.uncertain, reason: .frameUnavailable); recognizedPlace = nil
        indoor.invalidatePosition(); message = "Camera session failed: \(error.localizedDescription)"; publish()
    }
    func sessionWasInterrupted(_ session: ARSession) {
        peopleTracking.reset()
        fixedBodyMount = false
        awaitingPlace = nil; placeRecovery.reset()
        visualStairs.reset()
        invalidateReturn()
        mapping.stop(); journeys.breakTracking(); cancelDescription()
        detector.reset(); phoneDetection = Detection(.uncertain, reason: .frameUnavailable); recognizedPlace = nil
        indoor.invalidatePosition(); message = "Camera session interrupted."; publish()
    }
    func sessionInterruptionEnded(_ session: ARSession) {
        guard running else { return }
        awaitingPlace = nil; launch(); message = "Session resumed. Recalibrate the floor."
    }
    func scanPlace(name: String, compare: Bool = false) {
        guard running, !simulation, !places.scanning else { message = "Start the live camera first."; return }
        guard !compare || recognizedPlace != nil else { message = "Recognize a saved place before comparing."; return }
        mapping.stop(); journeys.breakTracking(); fixedBodyMount = false; indoor.invalidatePosition(); peopleTracking.reset()
        visualStairs.reset()
        invalidateReturn(); cancelDescription(); voice.cancel(); detector.reset(); feedback.stop()
        phoneDetection = Detection(.uncertain); detection = phoneDetection
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
        } catch { message = "Saved place could not be loaded." }
    }
    func continueWithoutPlaceMatch() {
        guard running, !simulation, supported, !places.scanning,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        launch(); placeRecoveryQuestion = ""
        message = arabic ? "المكان غير معروف. لن أستخدم الغرفة السابقة لإعطاء اتجاهات. أعد معايرة الأرضية." : "Place is unknown. I will not use the previous room for directions. Recalibrate the floor."
        feedback.speak(message)
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
            _ = feedback.speak(indoor.message, priority: .mobility)
            lastIndoorAnnouncement = ProcessInfo.processInfo.systemUptime; return
        }
        let key = "\(indoor.alignmentRevision):\(indoor.waypointIndex):\(cue.sector):\(cue.distance <= 1)"
        if automatic, key == lastIndoorCueKey { return }
        if feedback.speak(indoor.message, priority: .mobility) {
            if fixedBodyMount { feedback.beacon(sector: cue.sector, distance: min(10, cue.distance)) }
            lastIndoorAnnouncement = ProcessInfo.processInfo.systemUptime
            lastIndoorCueKey = key
        }
    }
    func readScene(cloud: Bool, question: String = "Describe what is in front of me.", automatic: Bool = false, focus: String = "surroundings") {
        if !automatic, handleAssistantControl(question) { return }
        if !automatic, let goal = AssistantControl.explicitGoal(question) {
            objectiveDraft = goal; setAssistantObjective(); assistantQuestion = goal
            if indoor.map != nil { findMapDestination() }
            else {
                message = arabic ? "حُفظ الهدف. لم تُحدد خريطة للوصول إليه بعد." : "Goal saved. A map for reaching it has not been selected yet."
                _ = feedback.speak(message)
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
            message = "A current camera view is required; urgent alerts take priority."; return
        }
        if !automatic, !feedback.canSpeakAmbient {
            queueQuestion(question, cloud: cloud, focus: focus, camera: origin, forward: originForward)
            return
        }
        voice.cancel()
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
            tracking: lastObservation?.trackingNormal == true, fixedBodyMount: fixedBodyMount)
        var initialSituation = AssistantSituation.snapshot(dialogue: dialogue, preview: preview, layout: roomLayout,
            preferences: assistantPreferences, narration: history, navigation: navigation, arabic: arabic)
        let visualTracks = peopleTracking.snapshot(at: ProcessInfo.processInfo.systemUptime)
        initialSituation["visualTracks"] = visualTracks
        let situationCreatedAt = ProcessInfo.processInfo.systemUptime
        let image = frame.capturedImage, capturedAt = lastFrameWallTime
        busy = true; questionIsAutomatic = automatic
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
                    answer = try await SceneQuestionClient(endpoint: self.serviceURL, token: TokenStore.read())
                        .ask(question: question, jpeg: jpeg, context: context, focus: focus, situation: situation, wordAllowance: allowance)
                    fromModel = true
                } else {
                    if focus == "path" {
                        answer = arabic ? "استخدم تبويب المسارات لتحديد وجهة. لا يكفي وصف الصورة لتحديد مسار قابل للمشي." : "Use Routes to select a destination. A scene description does not establish a walkable route."
                    } else {
                        let local = await LocalImageAssistant.describe(image: image, question: question, context: context,
                                                                       situation: situation, wordAllowance: allowance)
                        try Task.checkCancellation()
                        guard self.requestID == currentRequest else { return }
                        self.localImageStatus = local.status
                        if let description = local.text { answer = description; fromModel = true }
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
                // Spatial safety rule (AGENTS.md, E13): hazard geometry, step counts, clear-path
                // statements and unhedged distances from a model are never spoken.
                if fromModel && SpatialClaimGuard.containsSpatialClaim(answer) {
                    if !automatic {
                        self.message = arabic ? "حذفتُ إجابة فيها مسافة أو موقع خطر لم تقسه الحساسات. تنبيهات الحساسات مستمرة." : "I held back an answer that gave a hazard position or distance the sensors had not measured. Sensor alerts continue."
                        _ = self.feedback.speak(self.message)
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
                var ambientKey: String?
                if automatic {
                    let revision = Set(context.observations.map { "\($0.kind.rawValue):\($0.text)" }).sorted().joined(separator: "|")
                    let candidate = InformationCandidate(key: "view:\(self.companion.currentRoom ?? "unknown")", kind: .discovery,
                        text: answer, words: words, revision: revision.isEmpty ? answer : revision,
                        createdAt: capturedAt, expiresAt: capturedAt + 6)
                    guard case .say = self.companion.decide([candidate], moment: self.companionMoment(now), settings: self.companionSettings).first else { return }
                    ambientKey = candidate.key
                }
                // All scene narration yields to necessary mobility/status cues.
                let spoken = self.feedback.speakAmbient(answer, id: currentRequest)
                guard spoken else {
                    if let ambientKey { self.companion.release(ambientKey) }
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
    private var companionSettings: CompanionSettings {
        CompanionSettings(firstVisitRooms: firstVisitRooms, minimumGap: Double(narrationInterval), wordsPerMinute: wordsPerMinute,
                          preferences: assistantPreferences, quiet: !ambientDescriptions)
    }
    private func companionMoment(_ now: Double) -> CompanionMoment {
        CompanionMoment(now: now, goalActive: !assistantDialogue.goal.isEmpty,
                        activity: attention.stationary ? .stationary : lastObservation?.trackingNormal == true ? .moving : .unknown,
                        speaking: feedback.canSpeakAmbient ? nil : .information)
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
            frameAge: 0, tracking: observation.trackingNormal, fixedBodyMount: fixedBodyMount) : nil
        let roomID = situation?.roomID ?? recognizedPlace.map { "place:\($0.id.uuidString)" }
        let roomName = situation?.roomName ?? recognizedPlace?.name
        if let entry = companion.observeRoom(roomID, established: roomID != nil && observation.trackingNormal, now: now) {
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
        guard let candidate = roomOfferCandidate, detection.hazard == .observing, !voice.listening else { return }
        for decision in companion.decide([candidate], moment: companionMoment(now), settings: companionSettings) {
            switch decision {
            case .offer(let offer, _):
                roomOfferCandidate = nil
                if firstVisitRooms == .describe, offer.kind == .describeRoom {
                    // Same timing gates as an offer, without asking first.
                    companion.answerOffer(.yes)
                    readScene(cloud: false, question: arabic ? "صف هذه الغرفة." : "Describe this room.", focus: "room")
                } else if feedback.canSpeakAmbient, feedback.speak(offer.prompt, priority: .information) { companionOffer = offer }
                else { companion.withdrawOffer() }
            case .drop: roomOfferCandidate = nil
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
        case .suggestion, .itemDirections:
            readScene(cloud: false, question: offer.prompt)
        }
    }
    func setAssistantObjective() {
        cancelDescription(); feedback.stop(); stopReturn(); indoor.invalidatePosition()
        assistantDialogue.setGoal(objectiveDraft); objectiveDraft = assistantDialogue.goal; persistDialogue()
    }
    func clearAssistantConversation() {
        cancelDescription(); feedback.stop(); stopReturn(); indoor.invalidatePosition()
        assistantDialogue = AssistantDialogue(); objectiveDraft = ""; persistDialogue()
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
    func startVoiceQuestion() {
        guard !running || detection.hazard == .observing else { message = "Current monitoring alerts take priority."; return }
        cancelDescription(); feedback.stop(); voice.start(arabic: arabic)
    }
    func findMapDestination() {
        guard !busy, let map = indoor.map else { message = "Import a map in Routes first."; return }
        voice.cancel()
        let question = assistantQuestion, revision = indoor.revision
        let matches = MapContext.matchingDestinations(question: question, in: map)
        if !matches.isEmpty {
            indoor.suggestDestination(id: matches.count == 1 ? matches[0].id : nil)
            sceneAnswer = indoor.message
            if !running || detection.hazard == .observing { feedback.speak(sceneAnswer, priority: .mobility) }
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
            if !self.running || self.detection.hazard == .observing { self.feedback.speak(self.sceneAnswer, priority: .mobility) }
        }
    }
    func stopDescriptions() { cancelDescription(); voice.cancel(); feedback.interruptAmbient(); ambientDescriptions = false }
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
        _ = feedback.speak(message)
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
        guard feedback.speakAmbient(text, id: id) else { return }
        narrationBudget.charge(words: count, limit: wordsPerMinute, now: now)
        // Do not recursively prepend older repeat labels to later requests.
        enqueueNarration { try await $0.start(id: id, sessionID: session, goalRevision: revision,
            snapshotID: record.snapshotID, sourceIDs: record.sourceIDs, text: text, at: at) }
    }
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
            feedback.speak(returnStatus, priority: .mobility)
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
        if feedback.speak(returnStatus, priority: .mobility) {
            feedback.beacon(sector: cue.sector, distance: max(0.5, min(10, cue.distance)))
            lastReturnAnnouncement = ProcessInfo.processInfo.systemUptime
        }
    }
    func startSimulation() {
        stop(); simulation = true; running = true; detector.beginCalibration()
        demonstrationTime = 0; demonstrationHazard = .observing; policy = AlertPolicy(); continuity = MonitoringContinuity()
        for _ in 0..<15 { demoFrame() }
        startWatchdog(); message = "Simulation uses generated depth. No live sensing is active."
        feedback.speak(arabic ? "وضع المحاكاة. لا توجد قراءات حقيقية." : "Simulation. No live sensors.")
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
