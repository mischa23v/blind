import Foundation

public struct JourneyReturnQuestion: Sendable {
    public enum Choice: String, Sendable { case savedReference, journeyStart }
    public let id: UUID
    public let text: String
    public let referenceID: UUID
    public let startID: UUID
    fileprivate let epoch: UUID
}

/// Only exact code-owned speech completion mints this one-use, volatile receipt.
/// It proves a delivery callback, not that the user heard/understood the question.
public struct JourneyClarificationReceipt: Equatable, Sendable {
    fileprivate let id: UUID
    fileprivate let questionID: UUID
    fileprivate let epoch: UUID
    fileprivate let deliveredAt: Double
}

public struct ConnectedJourneyRouteTicket: Sendable {
    public let route: SpatialRouteTicket
    fileprivate let epoch: UUID
    fileprivate let itineraryID: UUID
}

public enum JourneyReturnRequest: Sendable {
    case selected(JourneyGoal)
    case clarify(JourneyReturnQuestion)
}

/// Single-owner value adapter, to be isolated off the hazard/main loop by the native
/// store. All route legs use the existing SpatialRouteOwner. No native pose issuer,
/// SLAM, database, new route search or synthesized transition guidance lives here.
public struct ConnectedJourneyCoordinator: Sendable {
    public private(set) var snapshot: ConnectedJourneySnapshot
    public private(set) var catalog: ConnectedJourneyCatalog
    public private(set) var activeBinding: SpatialMapBinding?
    public private(set) var itinerary: [JourneyLeg] = []
    public private(set) var legIndex = 0
    public private(set) var persistenceBlocked = false
    public private(set) var ordinarySpeechMuted = false
    public var currentLeg: JourneyLeg? { itinerary.indices.contains(legIndex) ? itinerary[legIndex] : nil }
    /// Pure diagnostic projection of the route already owned here. No next(),
    /// replanning, acceptance, output lease or source-frame conversion occurs.
    public var diagnosticOwnedRoute: NavigationTestRecording.OwnedRoute? {
        guard snapshot.goal?.status == .active, !snapshot.returnClarificationPending,
              case .local? = currentLeg, let owner, let installation = owner.installation,
              let goal = owner.goalRevision, owner.route.count >= 2 else { return nil }
        return .init(map: installation.binding, routeRevision: owner.routeID, goalRevision: goal,
            bodyRevision: owner.bodyRevision, obstacleRevision: owner.obstacleRevision,
            artifactSHA256: installation.artifact.sha256, points: owner.route.map(\.position))
    }
    public var currentQuestion: JourneyReturnQuestion? { question }
    private let body: BodyEnvelope?
    private let limits: SpatialLocalizationLimits?
    private var owner: SpatialRouteOwner?
    private var support: SpatialFloorSupport?
    private var epoch = UUID()
    private var questionEpoch = UUID()
    private var invalidPendingCommand = false
    private var undurableMaps = Set<SpatialMapBinding>()
    private var knownArtifacts: [SpatialMapBinding: String] = [:]
    private var knownRestrictions: [SpatialMapBinding: SpatialMapRestrictions] = [:]
    private var itineraryID = UUID()
    private var question: JourneyReturnQuestion?
    private var receipt: JourneyClarificationReceipt?
    private var armedPortal: (id: String, from: JourneyEndpoint, to: JourneyEndpoint, goal: UUID, armedAt: Double, sourceCaptureID: UUID, sourceRecordedAt: Date)?

    public init(catalog: ConnectedJourneyCatalog, body: BodyEnvelope? = nil, limits: SpatialLocalizationLimits? = nil,
                snapshot: ConnectedJourneySnapshot = .init()) throws {
        try snapshot.validate()
        guard (body == nil && limits == nil) || (body?.valid == true && limits?.valid == true) else { throw ConnectedJourneyError.invalidCatalog }
        self.catalog = catalog; self.body = body; self.limits = limits; self.snapshot = snapshot
        knownArtifacts = catalog.installations.mapValues { $0.artifact.sha256 }
        knownRestrictions = catalog.installations.mapValues { $0.currentRestrictions }
        // Restoration intentionally creates no owner, pose, itinerary or receipt.
    }
    /// Every registry replacement/deletion invalidates output and live location.
    /// History/goal are retained verbatim; old anchors never silently bind to r2.
    public mutating func replaceCatalog(_ next: ConnectedJourneyCatalog) throws {
        guard undurableMaps.isEmpty else { throw ConnectedJourneyError.persistenceRequired }
        retirePlan(); owner = nil; activeBinding = nil; support = nil
        var registry = catalog.registry
        try registry.update(snapshot: next.registry.snapshot)
        var artifacts = knownArtifacts, restrictions = knownRestrictions
        for (binding, installation) in next.installations {
            guard artifacts[binding].map({ $0 == installation.artifact.sha256 }) ?? true,
                  restrictions[binding].map({ installation.currentRestrictions.contains($0) }) ?? true else {
                throw SpatialInstallationError.historyRewrite
            }
            artifacts[binding] = installation.artifact.sha256; restrictions[binding] = installation.currentRestrictions
        }
        guard artifacts.count <= 256 else { throw ConnectedJourneyError.invalidCatalog }
        knownArtifacts = artifacts; knownRestrictions = restrictions; catalog = next
    }
    /// This is a request to localize, never a claim that localization succeeded.
    /// The native issuer must obtain fresh evidence for returned session identity.
    @discardableResult
    public mutating func beginLocalization(in binding: SpatialMapBinding) throws -> UUID {
        // Keep the current restrictive owner reachable for its bounded retry.
        // Switching even to another map cannot strand an unsaved restriction.
        guard undurableMaps.isEmpty else { throw ConnectedJourneyError.persistenceRequired }
        guard let installation = catalog.installations[binding] else {
            loseTracking(); throw ConnectedJourneyError.unavailableMap
        }
        guard let body, let limits else { throw ConnectedJourneyError.awaitingLocalization }
        rotateOutput(); owner = nil; support = nil; activeBinding = nil
        var next = try SpatialRouteOwner(body: body, limits: limits)
        try next.restoreValidated(installation)
        if let goal = snapshot.goal { next.setGoal(revision: goal.revision) }
        owner = next; activeBinding = binding
        if let armedPortal, armedPortal.to.binding != binding { retirePlan() }
        return next.sessionID
    }
    /// Context comes from this journey's active owner, not IndoorNavigator's preview.
    public var nativeLocalizationContext: NativeLocalizationRouteContext? {
        guard let owner, let installation = owner.installation,
              activeBinding == installation.binding, let goal = snapshot.goal, goal.status == .active,
              let revision = try? installation.registry.map(for: installation.binding) else { return nil }
        return .init(sessionID: owner.sessionID, artifact: installation.artifact,
            revision: revision, goalRevision: goal.revision)
    }
    /// Exact-owner evidence withdrawal: preserve route intent, itinerary, restrictions,
    /// localization session and replay ledger. Actual tracking loss is separate.
    @discardableResult public mutating func withholdNativeEvidence(session: UUID,
        artifact: SpatialMapArtifactIdentity, goalRevision: UUID) -> Bool {
        guard let context = nativeLocalizationContext, context.sessionID == session,
              context.artifact == artifact, context.goalRevision == goalRevision else { return false }
        guard owner?.hasLocalizationEvidence == true || support != nil || armedPortal != nil else { return false }
        owner?.withholdLocalizationEvidence(); support = nil; armedPortal = nil
        rotateOutput(); return true
    }
    public var expectedSessionID: UUID? { owner?.sessionID }
    public func currentPose(now: Double) -> SpatialLocalizationCapture? { owner?.currentPose(now: now) }
    public mutating func accept(_ capture: SpatialLocalizationCapture, support: SpatialFloorSupport, now: Double) throws {
        rotateOutput()
        guard var next = owner else { throw ConnectedJourneyError.awaitingLocalization }
        do {
            try next.accept(capture, now: now)
            guard support.binding == capture.binding, support.floorID == capture.floorID,
                  support.captureID == capture.id, support.sessionID == capture.sessionID,
                  support.capturedAt == capture.capturedAt, support.height.isFinite else { throw SpatialRouteError.missingSupport }
            owner = next; self.support = support
        } catch {
            next.loseTracking(); owner = next; self.support = nil
            // The inner owner discarded its executable route. Retaining the old
            // itinerary would prevent the runtime from planning from fresh evidence.
            // Goal/history and conservative restrictions remain unchanged.
            retirePlan()
            throw error
        }
    }
    public mutating func loseTracking() {
        retirePlan(); owner?.loseTracking(); support = nil
        // Goal, start, references and history remain. Camera restart is not a new journey.
    }
    public mutating func markStart(at endpoint: JourneyEndpoint, origin: CompanionCommandOrigin,
                                   now: Double, recordedAt: Date, persist: (Data) throws -> Void) throws {
        try authorize(.changeGoal, origin)
        guard snapshot.start == nil else { throw ConnectedJourneyError.invalidHistory }
        let capture = try requireEndpoint(endpoint, now: now)
        var next = snapshot
        next.start = try catalog.reference(endpoint: endpoint, kind: .journeyStart, at: recordedAt, captureID: capture.id)
        try next.append(.started, at: recordedAt, endpoint: endpoint, captureID: capture.id)
        try commit(next, persist: persist)
    }
    public mutating func saveReference(at endpoint: JourneyEndpoint, origin: CompanionCommandOrigin,
                                       now: Double, recordedAt: Date, persist: (Data) throws -> Void) throws {
        try authorize(.changeGoal, origin)
        guard snapshot.references.count < ConnectedJourneySnapshot.maximumReferences else { throw ConnectedJourneyError.historyFull }
        let capture = try requireEndpoint(endpoint, now: now)
        let reference = try catalog.reference(endpoint: endpoint, kind: .savedReference, at: recordedAt, captureID: capture.id)
        var next = snapshot; next.references.append(reference); next.preferredReferenceID = reference.id
        try next.append(.referenceSaved, at: recordedAt, endpoint: endpoint, captureID: capture.id)
        try commit(next, persist: persist)
    }
    public mutating func setDestination(_ endpoint: JourneyEndpoint, origin: CompanionCommandOrigin,
                                        recordedAt: Date, persist: (Data) throws -> Void) throws {
        try authorize(.changeGoal, origin)
        retirePlan(); invalidPendingCommand = true
        let target = try catalog.reference(endpoint: endpoint, kind: .mappedDestination, at: recordedAt)
        try setGoal(target, purpose: .destination, recordedAt: recordedAt, persist: persist)
    }
    /// Ordinary narration quiet does not revoke navigation or independent alerts.
    /// No evidence is retained for later ordinary playback by this coordinator.
    public mutating func setOrdinarySpeechMuted(_ muted: Bool, origin: CompanionCommandOrigin) throws {
        try authorize(.interruptOrdinarySpeech, origin); ordinarySpeechMuted = muted
    }
    /// Explicit task hold retains the destination and itinerary description but
    /// retires all executable output and live evidence. Independent hazards are
    /// owned elsewhere and never receive a stop operation from this adapter.
    public mutating func hold(origin: CompanionCommandOrigin, persist: (Data) throws -> Void) throws {
        try authorize(.changeGoal, origin)
        guard snapshot.goal?.status == .active else { throw ConnectedJourneyError.noGoal }
        rotateOutput(); owner?.loseTracking(); support = nil; armedPortal = nil
        var next = snapshot; next.goal?.status = .paused
        try commit(next, resolvesCommand: true, persist: persist)
    }
    /// Resume is intent only. The integration must obtain a NEW capture and call
    /// plan from its known node; an old route/capture cannot be replayed.
    public mutating func resume(origin: CompanionCommandOrigin, persist: (Data) throws -> Void) throws {
        try authorize(.changeGoal, origin)
        guard snapshot.goal?.status == .paused else { throw ConnectedJourneyError.noGoal }
        rotateOutput(); owner?.loseTracking(); support = nil; armedPortal = nil
        var next = snapshot; next.goal?.status = .active
        try commit(next, resolvesCommand: true, persist: persist)
    }
    public mutating func completeAtGoal(now: Double, recordedAt: Date, persist: (Data) throws -> Void) throws {
        guard !persistenceBlocked, !invalidPendingCommand, undurableMaps.isEmpty else { throw ConnectedJourneyError.persistenceRequired }
        guard let goal = snapshot.goal, goal.status == .active, !snapshot.returnClarificationPending else {
            throw ConnectedJourneyError.noGoal
        }
        try catalog.validate(goal.target)
        let capture = try requireEndpoint(goal.target.endpoint, now: now)
        var next = snapshot; next.goal?.status = .arrived
        try next.append(.arrived, at: recordedAt, endpoint: goal.target.endpoint, captureID: capture.id)
        retirePlan(); try commit(next, persist: persist)
    }
    public mutating func cancel(origin: CompanionCommandOrigin, recordedAt: Date, persist: (Data) throws -> Void) throws {
        try authorize(.cancelTaskOrNavigation, origin)
        retirePlan(); invalidPendingCommand = true
        var next = snapshot; next.goal?.status = .cancelled; next.returnClarificationPending = false
        try next.append(.cancelled, at: recordedAt)
        try commit(next, resolvesCommand: true, persist: persist)
    }
    /// Returning replans from fresh current evidence. Old traversed segments are
    /// never substituted for current map collision evidence or clearance.
    public mutating func requestReturn(origin: CompanionCommandOrigin, arabic: Bool = false,
                                       recordedAt: Date, persist: (Data) throws -> Void) throws -> JourneyReturnRequest {
        try authorize(.startReturn, origin)
        retirePlan(); invalidPendingCommand = true
        let saved = snapshot.references.first { $0.id == snapshot.preferredReferenceID }, start = snapshot.start
        guard saved != nil || start != nil else { throw ConnectedJourneyError.noReference }
        if let saved, let start, saved.endpoint != start.endpoint {
            var next = snapshot; next.returnClarificationPending = true
            try commit(next, resolvesCommand: true, persist: persist)
            let prompt = JourneyReturnQuestion(id: UUID(),
                text: arabic ? "هل تريد العودة إلى النقطة المحفوظة أم إلى بداية الرحلة؟" : "Return to the saved reference or the journey start?",
                referenceID: saved.id, startID: start.id, epoch: questionEpoch)
            question = prompt
            return .clarify(prompt)
        }
        let target = saved ?? start!
        try setGoal(target, purpose: target.kind == .journeyStart ? .returnToStart : .returnToReference,
                    recordedAt: recordedAt, persist: persist)
        return .selected(snapshot.goal!)
    }
    /// Only a matching terminal ledger completion, not screen display, elapsed time,
    /// model output, interrupted text or a generic "yes", can produce this receipt.
    public mutating func recordClarificationDelivery(_ completion: SpeechDeliveryLedger.Completion,
                                                     now: Double) throws -> JourneyClarificationReceipt {
        guard let question, question.epoch == questionEpoch, receipt == nil,
              snapshot.returnClarificationPending, completion.outcome == .completed,
              completion.attempt.destination == .requested(question.id), completion.attempt.text == question.text,
              !completion.attempt.completionIsAmbiguous, now.isFinite, now >= 0 else {
            throw ConnectedJourneyError.clarificationNotDelivered
        }
        let issued = JourneyClarificationReceipt(id: UUID(), questionID: question.id, epoch: questionEpoch, deliveredAt: now)
        receipt = issued; return issued
    }
    public mutating func resolveReturn(_ choice: JourneyReturnQuestion.Choice, receipt supplied: JourneyClarificationReceipt,
                                      origin: CompanionCommandOrigin, now: Double, recordedAt: Date,
                                      persist: (Data) throws -> Void) throws {
        try authorize(.startReturn, origin)
        guard let question, receipt == supplied, supplied.questionID == question.id,
              supplied.epoch == questionEpoch, now.isFinite, now >= supplied.deliveredAt,
              now - supplied.deliveredAt <= 30, snapshot.returnClarificationPending else {
            throw ConnectedJourneyError.staleClarification
        }
        // Consume before any fallible validation/write. Retrying requires a newly
        // delivered question, never a replay of this selection or its speech token.
        receipt = nil; self.question = nil
        let target: JourneyReference?
        switch choice {
        case .savedReference: target = snapshot.references.first { $0.id == question.referenceID }
        case .journeyStart: target = snapshot.start?.id == question.startID ? snapshot.start : nil
        }
        guard let target else { throw ConnectedJourneyError.noReference }
        try setGoal(target, purpose: choice == .savedReference ? .returnToReference : .returnToStart,
                    recordedAt: recordedAt, persist: persist)
    }
    public mutating func plan(from endpoint: JourneyEndpoint, now: Double) throws {
        retirePlan()
        guard !persistenceBlocked, !invalidPendingCommand, undurableMaps.isEmpty else { throw ConnectedJourneyError.persistenceRequired }
        guard !snapshot.returnClarificationPending, let goal = snapshot.goal, goal.status == .active else {
            throw ConnectedJourneyError.noGoal
        }
        try catalog.validate(goal.target)
        _ = try requireEndpoint(endpoint, now: now)
        guard let body else { throw ConnectedJourneyError.awaitingLocalization }
        itinerary = try catalog.plan(from: endpoint, to: goal.target.endpoint, body: body)
        itineraryID = UUID(); legIndex = 0
        if currentLeg != nil { try prepareLocalLeg(now: now) }
    }
    /// Invoke after fresh localization at the local leg's source. A portal leg is
    /// deliberately only a waiting state, with no stairs/lift movement command.
    public mutating func prepareLocalLeg(now: Double) throws {
        guard !persistenceBlocked, !invalidPendingCommand, undurableMaps.isEmpty else { throw ConnectedJourneyError.persistenceRequired }
        guard let goal = snapshot.goal, goal.status == .active, let leg = currentLeg else { throw ConnectedJourneyError.noPlan }
        guard case .local(let from, let to) = leg else { return }
        _ = try requireEndpoint(from, now: now)
        guard var owner else { throw ConnectedJourneyError.awaitingLocalization }
        owner.setGoal(revision: goal.revision)
        do { try owner.plan(from: from.nodeID, to: to.nodeID, goal: goal.revision); self.owner = owner }
        catch { self.owner = owner; rotateOutput(); throw error }
    }
    public func next(now: Double) throws -> ConnectedJourneyRouteTicket {
        guard !persistenceBlocked, !invalidPendingCommand, undurableMaps.isEmpty else { throw ConnectedJourneyError.persistenceRequired }
        guard snapshot.goal?.status == .active, !snapshot.returnClarificationPending,
              case .local? = currentLeg, let owner, let support else { throw ConnectedJourneyError.noPlan }
        return try .init(route: owner.next(support: support, now: now), epoch: epoch, itineraryID: itineraryID)
    }
    public func permits(_ ticket: ConnectedJourneyRouteTicket, now: Double) -> Bool {
        !persistenceBlocked && !invalidPendingCommand && undurableMaps.isEmpty && ticket.epoch == epoch && ticket.itineraryID == itineraryID &&
        snapshot.goal?.status == .active && !snapshot.returnClarificationPending &&
        owner?.permits(ticket.route, now: now) == true
    }
    /// Intermediate waypoints are associated with fresh map pose, not a spoken
    /// "arrived" report. Reuses the controller's existing advancement afterward.
    public mutating func advanceWaypoint(now: Double) throws {
        guard !persistenceBlocked, !invalidPendingCommand, undurableMaps.isEmpty else { throw ConnectedJourneyError.persistenceRequired }
        guard let owner, owner.waypointIndex < owner.route.count, let binding = activeBinding,
              let pose = owner.currentPose(now: now) else { throw ConnectedJourneyError.awaitingLocalization }
        let node = owner.route[owner.waypointIndex]
        let endpoint = JourneyEndpoint(binding: binding, floorID: pose.floorID, nodeID: node.id, roomID: pose.roomID)
        _ = try requireEndpoint(endpoint, now: now)
        self.owner?.confirmWaypoint(); rotateOutput()
    }
    public mutating func completeLocalLeg(now: Double, recordedAt: Date, persist: (Data) throws -> Void) throws {
        guard !persistenceBlocked, !invalidPendingCommand, undurableMaps.isEmpty else { throw ConnectedJourneyError.persistenceRequired }
        guard case .local(_, let to)? = currentLeg else { throw ConnectedJourneyError.wrongLeg }
        let capture = try requireEndpoint(to, now: now)
        var next = snapshot; try next.append(.reachedNode, at: recordedAt, endpoint: to, captureID: capture.id)
        let finishing = legIndex + 1 == itinerary.count
        if finishing { next.goal?.status = .arrived; try next.append(.arrived, at: recordedAt, endpoint: to, captureID: capture.id) }
        rotateOutput(); owner?.cancelRoute()
        try commit(next, persist: persist)
        legIndex += 1
    }
    /// Records endpoint association only. Crossing guidance remains unavailable.
    public mutating func armPortal(now: Double, recordedAt: Date) throws {
        guard !persistenceBlocked, !invalidPendingCommand, undurableMaps.isEmpty else { throw ConnectedJourneyError.persistenceRequired }
        guard case .portal(let id, let from, let to)? = currentLeg,
              let goal = snapshot.goal, goal.status == .active,
              let portal = catalog.portals.first(where: { $0.transitionID == id }) else { throw ConnectedJourneyError.wrongLeg }
        try catalog.validate(portal)
        guard recordedAt.timeIntervalSince1970.isFinite else { throw ConnectedJourneyError.invalidHistory }
        let capture = try requireEndpoint(from, now: now)
        rotateOutput(); owner?.cancelRoute()
        armedPortal = (id, from, to, goal.revision, now, capture.id, recordedAt)
    }
    public mutating func completePortal(now: Double, recordedAt: Date, persist: (Data) throws -> Void) throws {
        guard !persistenceBlocked, !invalidPendingCommand, undurableMaps.isEmpty else { throw ConnectedJourneyError.persistenceRequired }
        guard case .portal(let id, let from, let to)? = currentLeg, let armedPortal,
              armedPortal.id == id, armedPortal.from == from, armedPortal.to == to,
              armedPortal.goal == snapshot.goal?.revision, now.isFinite, now >= armedPortal.armedAt,
              now - armedPortal.armedAt <= 120 else { throw ConnectedJourneyError.wrongLeg }
        let capture = try requireEndpoint(to, now: now)
        var next = snapshot
        // Endpoints associated with the intended portal; NOT proof of the path actually traversed.
        try next.append(.portalEndpointsAssociated, at: recordedAt, endpoint: to, portalID: id, captureID: capture.id,
                        portalDepartureCaptureID: armedPortal.sourceCaptureID, portalDepartureRecordedAt: armedPortal.sourceRecordedAt)
        if legIndex + 1 == itinerary.count { next.goal?.status = .arrived; try next.append(.arrived, at: recordedAt, endpoint: to, captureID: capture.id) }
        rotateOutput(); try commit(next, persist: persist)
        self.armedPortal = nil; legIndex += 1
        if currentLeg != nil { try prepareLocalLeg(now: now) }
    }
    /// Persist a conservative map restriction using its existing atomic map owner.
    /// The catalog supplied afterward must include the updated installed artifact.
    public mutating func addRestrictions(blocked: Set<MapConnection>, zones: [KeepOutZone],
                                          persistMap: (Data) throws -> Void) throws {
        guard var owner, let binding = activeBinding else { throw ConnectedJourneyError.awaitingLocalization }
        rotateOutput()
        do {
            try owner.addRestrictions(binding: binding, blocked: blocked, zones: zones, persist: persistMap)
            self.owner = owner; try retainRestrictionArtifact(owner); undurableMaps.remove(binding); retirePlan()
        } catch {
            self.owner = owner
            if !owner.restrictionsDurable { undurableMaps.insert(binding); try retainRestrictionArtifact(owner) }
            retirePlan(); throw error
        }
    }
    public mutating func retryRestrictionPersistence(persistMap: (Data) throws -> Void) throws {
        guard var owner, let binding = activeBinding, undurableMaps.contains(binding) else {
            throw ConnectedJourneyError.persistenceRequired
        }
        try owner.addRestrictions(binding: binding, blocked: [], zones: [], persist: persistMap)
        self.owner = owner; try retainRestrictionArtifact(owner); undurableMaps.remove(binding); retirePlan()
    }
    private mutating func retainRestrictionArtifact(_ owner: SpatialRouteOwner) throws {
        guard let installation = owner.installation else { throw ConnectedJourneyError.unavailableMap }
        let replacements = catalog.installations.values.filter { $0.binding != installation.binding } + [installation]
        catalog = try ConnectedJourneyCatalog(registry: catalog.registry, installations: replacements, portals: catalog.portals)
        knownArtifacts[installation.binding] = installation.artifact.sha256
        knownRestrictions[installation.binding] = installation.currentRestrictions
    }
    /// After a failed journey write, retry the validated LATEST intent, never the
    /// superseded goal. A malformed latest command cannot be cleared by flush.
    public mutating func flush(persist: (Data) throws -> Void) throws {
        guard !invalidPendingCommand else { throw ConnectedJourneyError.persistenceRequired }
        try persist(snapshot.encoded()); persistenceBlocked = false
    }
    private mutating func setGoal(_ target: JourneyReference, purpose: JourneyGoal.Purpose,
                                  recordedAt: Date, persist: (Data) throws -> Void) throws {
        retirePlan(); invalidPendingCommand = true; try catalog.validate(target)
        var next = snapshot
        next.goal = .init(revision: UUID(), target: target, purpose: purpose, status: .active)
        next.returnClarificationPending = false
        try next.append(.goalChanged, at: recordedAt, endpoint: target.endpoint)
        try commit(next, resolvesCommand: true, persist: persist)
        owner?.setGoal(revision: next.goal!.revision)
    }
    private func requireEndpoint(_ endpoint: JourneyEndpoint, now: Double) throws -> SpatialLocalizationCapture {
        let node = try catalog.node(endpoint)
        guard let pose = owner?.currentPose(now: now), let support,
              pose.binding == endpoint.binding, pose.floorID == endpoint.floorID,
              endpoint.roomID.map({ pose.roomID == $0 }) ?? true,
              support.captureID == pose.id, support.sessionID == pose.sessionID,
              support.binding == pose.binding, support.floorID == pose.floorID,
              support.capturedAt == pose.capturedAt, support.height.isFinite else { throw ConnectedJourneyError.awaitingLocalization }
        // Small arrival policy radius, not a measurement claim. Entire uncertainty
        // ball must fit; camera height never substitutes for measured floor support.
        guard hypot(pose.position.x - node.position.x, pose.position.z - node.position.z) + pose.positionUncertainty <= 0.35,
              abs(support.height - node.position.y) <= 0.09 else { throw ConnectedJourneyError.notAtEndpoint }
        return pose
    }
    private func authorize(_ effect: CompanionCommandEffect, _ origin: CompanionCommandOrigin) throws {
        guard CommandAuthority.permits(effect, from: origin) else { throw ConnectedJourneyError.unauthorized }
    }
    private mutating func commit(_ candidate: ConnectedJourneySnapshot, resolvesCommand: Bool = false, persist: (Data) throws -> Void) throws {
        let data: Data
        do { data = try candidate.encoded() }
        catch { invalidPendingCommand = true; persistenceBlocked = true; rotateOutput(); owner?.cancelRoute(); throw error }
        // Publish latest intent as unsaved if writing fails. Previous durable bytes
        // remain atomic, but later retry must never resurrect superseded authority.
        snapshot = candidate
        if resolvesCommand { invalidPendingCommand = false }
        persistenceBlocked = true
        do { try persist(data); persistenceBlocked = false }
        catch { rotateOutput(); owner?.cancelRoute(); throw error }
    }
    private mutating func rotateOutput() { epoch = UUID() }
    private mutating func retirePlan() {
        rotateOutput(); questionEpoch = UUID(); question = nil; receipt = nil
        owner?.cancelRoute(); itinerary = []; legIndex = 0; itineraryID = UUID(); armedPortal = nil
    }
}
