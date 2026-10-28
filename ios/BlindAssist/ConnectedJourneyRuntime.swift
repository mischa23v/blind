import Foundation
import BlindCore

public enum JourneyRuntimeError: Error, Equatable {
    case loading, noRegisteredMap, storageUnavailable, superseded, tooLarge, invalidEnvelope
}

/// Existing installation envelopes plus typed journey history in one local atomic
/// record. Exact geometry bytes are reused, never reconstructed from old poses.
public struct JourneyEraseReceipt: Equatable, Sendable {
    public enum State: Sendable { case pending, succeeded, failed }
    public let id: UUID
    public let state: State
}

public struct JourneyRuntimeEnvelope: Codable, Sendable {
    public static let maximumBytes = 8_000_000
    public let schemaVersion: Int
    public let journey: ConnectedJourneySnapshot
    public let installations: [Data]
    public let portals: [JourneyPortal]
    /// Geometry-free deletion tombstones. Deleted exact revisions cannot be
    /// reactivated after restart with forgotten conservative restrictions.
    public let retiredBindings: [SpatialMapBinding]
    public init(journey: ConnectedJourneySnapshot, installations: [Data], portals: [JourneyPortal], retiredBindings: [SpatialMapBinding] = []) {
        schemaVersion = 1; self.journey = journey; self.installations = installations; self.portals = portals; self.retiredBindings = retiredBindings
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, journey, installations, portals, retiredBindings }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        journey = try values.decode(ConnectedJourneySnapshot.self, forKey: .journey)
        installations = try values.decode([Data].self, forKey: .installations)
        portals = try values.decode([JourneyPortal].self, forKey: .portals)
        retiredBindings = try values.decodeIfPresent([SpatialMapBinding].self, forKey: .retiredBindings) ?? []
    }
    public func encoded() throws -> Data {
        _ = try journey.encoded() // Independent 512 KB history bound, checked off-main by IO/restore.
        guard schemaVersion == 1, installations.count <= 32, portals.count <= 128,
              retiredBindings.count <= 256, Set(retiredBindings).count == retiredBindings.count,
              retiredBindings.allSatisfy({ [$0.mapID,$0.frameID,$0.revision].allSatisfy { !$0.isEmpty && $0.utf8.count <= 200 } }),
              installations.reduce(0, { $0 + $1.count }) <= Self.maximumBytes else { throw JourneyRuntimeError.tooLarge }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw JourneyRuntimeError.tooLarge }
        return data
    }
    public init(data: Data) throws {
        guard data.count <= Self.maximumBytes else { throw JourneyRuntimeError.tooLarge }
        self = try JSONDecoder().decode(Self.self, from: data)
        _ = try encoded()
    }
}

/// Immutable values are captured cheaply on the main owner. Geometry encoding is
/// deferred to the IO executor, never performed on a goal/cancel/hazard turn.
public struct JourneyRuntimeWrite: Sendable {
    public let journey: ConnectedJourneySnapshot
    public let installations: [SpatialMapInstallation]
    public let portals: [JourneyPortal]
    public let retiredBindings: [SpatialMapBinding]
    public func envelope() throws -> JourneyRuntimeEnvelope {
        .init(journey: journey, installations: try installations.map { try $0.encoded() }, portals: portals, retiredBindings: retiredBindings)
    }
}

public protocol ConnectedJourneyRuntimeIO: Sendable {
    func read() async throws -> Data?
    func write(_ payload: JourneyRuntimeWrite) async throws
}

/// File work is isolated from the synchronous native owner. The owner admits at
/// most one active write and one latest pending snapshot, so actor IO does not
/// acquire an unbounded mailbox from frame/goal updates.
public actor FoundationJourneyRuntimeIO: ConnectedJourneyRuntimeIO {
    private let url: URL
    public init(url: URL) { self.url = url }
    public func read() throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
        return try file.read(upToCount: JourneyRuntimeEnvelope.maximumBytes + 1)
    }
    public func write(_ payload: JourneyRuntimeWrite) throws {
        let data = try payload.envelope().encoded()
        var directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
        #endif
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

/// Main-owner lifecycle bridge. It retires executable output BEFORE asynchronous
/// IO, restores only durable knowledge, and never manufactures localization limits
/// or measurements. Without explicit calibrated-adapter configuration it still
/// saves destinations/history but cannot issue a physical route ticket.
@MainActor public final class ConnectedJourneyRuntime {
#if DEBUG
    // Opt-in hosted-test instrumentation only. Nil for ordinary app instances;
    // no global logging, user payloads, scheduling changes or release-build API.
    var diagnosticPhaseRecorder: (@Sendable (String, UUID, TimeInterval) -> Void)?
    // Test observability only: retain the actual outer tasks, including main-owner
    // publication. Never substitute a test executor or change production priority.
    private var diagnosticRestoreCompletion: (UUID, Task<Void, Never>)?
    private var diagnosticCatalogCompletion: (UUID, Task<Void, Never>)?
    private var diagnosticWriteCompletion: (UUID, Task<Void, Never>)?
    enum DiagnosticCompletionError: Error { case missingOperation, unfinishedOperation }

    /// Functional fixture fence, not a latency claim. Tests must release held IO
    /// before calling. Successor catalog/write operations are part of the fence.
    /// A completed task that leaves its own operation active is an error, not a retry.
    func waitForPendingOperationsForTesting() async throws {
        while loadID != nil || mapWorkID != nil || writing != nil {
            if let id = loadID {
                guard let operation = diagnosticRestoreCompletion, operation.0 == id else {
                    throw DiagnosticCompletionError.missingOperation
                }
                await operation.1.value
                guard loadID != id else { throw DiagnosticCompletionError.unfinishedOperation }
            } else if let id = mapWorkID {
                guard let operation = diagnosticCatalogCompletion, operation.0 == id else {
                    throw DiagnosticCompletionError.missingOperation
                }
                await operation.1.value
                guard mapWorkID != id else { throw DiagnosticCompletionError.unfinishedOperation }
            } else if let id = writing {
                guard let operation = diagnosticWriteCompletion, operation.0 == id else {
                    throw DiagnosticCompletionError.missingOperation
                }
                await operation.1.value
                guard writing != id else { throw DiagnosticCompletionError.unfinishedOperation }
            }
        }
    }
#endif
    public private(set) var snapshot = ConnectedJourneySnapshot()
    public private(set) var loading = false
    public private(set) var durable = false
    public private(set) var status = "Journey history is opening. Live location is unknown."
    public private(set) var storageError = false
    public private(set) var eraseReceipt: JourneyEraseReceipt?
    private var eraseSnapshotID: UUID?
    private var retiredBindings = Set<SpatialMapBinding>()
    public var onOutputRetired: (() -> Void)?
    public var onClarificationRetired: ((UUID) -> Void)?
    public var onChange: (() -> Void)?
    public var goal: JourneyGoal? { snapshot.goal }
    public var question: JourneyReturnQuestion? { coordinator?.currentQuestion }
    public var expectedSessionID: UUID? { coordinator?.expectedSessionID }
    /// Read-only diagnostic snapshot; unlike next(now:), never changes held output.
    public var diagnosticOwnedRoute: NavigationTestRecording.OwnedRoute? {
        guard !loading, !externalMapPending, !mapValidationBlocked, mapWorkID == nil,
              !commandBlocked else { return nil }
        return coordinator?.diagnosticOwnedRoute
    }
    public var nativeLocalizationContext: NativeLocalizationRouteContext? {
        guard !loading, !externalMapPending, !mapValidationBlocked, mapWorkID == nil, !commandBlocked else { return nil }
        return coordinator?.nativeLocalizationContext
    }
    /// Compare session, exact geometry digest and goal BEFORE changing any state.
    /// Repeated absent-evidence frames do not generate retirement/change storms.
    @discardableResult public func withholdNativeEvidence(session: UUID,
        artifact: SpatialMapArtifactIdentity, goalRevision: UUID) -> Bool {
        guard let context = nativeLocalizationContext, context.sessionID == session,
              context.artifact == artifact, context.goalRevision == goalRevision,
              var owner = coordinator else { return false }
        let changed = owner.withholdNativeEvidence(session: session, artifact: artifact, goalRevision: goalRevision)
        guard changed || held != nil || lastEndpoint != nil else { return false }
        coordinator = owner; lastEndpoint = nil
        retireOutput(); onChange?(); return true
    }
    public var pendingWriteCount: Int { (writing == nil ? 0 : 1) + (pending == nil ? 0 : 1) }
    private let io: any ConnectedJourneyRuntimeIO
    private let sha256: SpatialMapSHA256
    private var coordinator: ConnectedJourneyCoordinator?
    private var catalog: ConnectedJourneyCatalog?
    private var body: BodyEnvelope?
    private var limits: SpatialLocalizationLimits?
    private var version = UUID()
    private var writing: UUID?
    private var pending: (UUID, JourneyRuntimeWrite)?
    private var latestWrite: JourneyRuntimeWrite?
    private var loadID: UUID?
    private var pendingInstallation: (SpatialMapInstallation, [JourneyPortal])?
    private var pendingRemovals = Set<SpatialMapBinding>()
    private var commandBlocked = false
    private var externalMapPending = false
    private var mapValidationBlocked = false
    private var eraseAfterRestore = false
    private var mapWorkID: UUID?
    private var mapRevision = UUID()
    private var pendingMapWork: (UUID, SpatialFrameRegistry, [SpatialMapBinding: SpatialMapInstallation], [JourneyPortal])?
    private var requestedMaps: [SpatialMapBinding: SpatialMapInstallation] = [:]
    private var requestedRegistry: SpatialFrameRegistry?
    private var requestedPortals: [JourneyPortal] = []
    public var pendingMapWorkCount: Int { (mapWorkID == nil ? 0 : 1) + (pendingMapWork == nil ? 0 : 1) }
    private var cancelAfterRestore = false
    private var destinationAfterRestore: (SpatialMapBinding, String)?
    private var holdAfterRestore: Bool?
    private var held: ConnectedJourneyRouteTicket?
    private var lastEndpoint: JourneyEndpoint?
    private var pendingStartOrigin: CompanionCommandOrigin?
    private var clarificationLedger = SpeechDeliveryLedger()
    private var clarificationToken: UUID?
    private var clarificationReceipt: JourneyClarificationReceipt?

    public init(io: any ConnectedJourneyRuntimeIO, sha256: @escaping SpatialMapSHA256) {
        self.io = io; self.sha256 = sha256
    }
    public func restore() {
        guard loadID == nil, latestWrite == nil, coordinator == nil else { return }
        retire(); loading = true; let id = UUID(); loadID = id
#if DEBUG
        let trace = diagnosticPhaseRecorder
        trace?("restore-task-queued", id, ProcessInfo.processInfo.systemUptime)
#endif
        let completion = Task { [weak self, io, sha256] in
#if DEBUG
            trace?("restore-task-entered", id, ProcessInfo.processInfo.systemUptime)
#endif
            do {
                let data = try await io.read()
#if DEBUG
                trace?("restore-read-resumed", id, ProcessInfo.processInfo.systemUptime)
                trace?("restore-detached-queued", id, ProcessInfo.processInfo.systemUptime)
#endif
                
                // Decoding/verifying installations is executed away from the main
                // owner. Only immutable validated values cross back for publication.
                let restored = try await Task.detached(priority: .utility) { () -> (JourneyRuntimeEnvelope?, ConnectedJourneyCatalog?) in
#if DEBUG
                    trace?("restore-detached-begin", id, ProcessInfo.processInfo.systemUptime)
                    defer { trace?("restore-detached-end", id, ProcessInfo.processInfo.systemUptime) }
#endif
                    guard let data else { return (nil, nil) }
                    let envelope = try JourneyRuntimeEnvelope(data: data)
                    let maps = try envelope.installations.map { try SpatialMapInstallation(data: $0, sha256: sha256) }
                    guard Set(maps.map(\.binding)).isDisjoint(with: envelope.retiredBindings) else { throw JourneyRuntimeError.invalidEnvelope }
                    guard let first = maps.first else {
                        guard envelope.portals.isEmpty else { throw JourneyRuntimeError.invalidEnvelope }
                        return (envelope, nil)
                    }
                    return (envelope, try ConnectedJourneyCatalog(registry: first.registry, installations: maps, portals: envelope.portals))
                }.value
#if DEBUG
                trace?("restore-main-resumed", id, ProcessInfo.processInfo.systemUptime)
#endif
                guard let self, self.loadID == id else { return }
                self.loading = false; self.storageError = false
                if let envelope = restored.0 { self.snapshot = envelope.journey; self.retiredBindings = Set(envelope.retiredBindings) }
                self.catalog = restored.1
                self.requestedMaps = restored.1?.installations ?? [:]
                self.requestedRegistry = restored.1?.registry
                self.requestedPortals = restored.1?.portals ?? []
                try self.rebuildCoordinator()
                self.latestWrite = self.writePayload()
                self.durable = true; self.status = "Journey intent restored. Live location is unknown."
                for binding in self.pendingRemovals { try self.withdrawMap(binding) }
                self.pendingRemovals.removeAll()
                if let installation = self.pendingInstallation {
                    self.pendingInstallation = nil
                    do { try self.install(installation.0, portals: installation.1) }
                    catch { self.mapValidationBlocked = true; self.status = "Map revision is unavailable or retired. Guidance remains paused." }
                }
                if self.eraseAfterRestore {
                    self.eraseAfterRestore = false; self.cancelAfterRestore = false
                    try self.applyErase(id: self.eraseReceipt?.id ?? UUID())
                } else if self.cancelAfterRestore {
                    self.cancelAfterRestore = false; try self.cancel(origin: .trustedInterface)
                }
                if let target = self.destinationAfterRestore {
                    self.destinationAfterRestore = nil
                    do { try self.setDestination(binding: target.0, nodeID: target.1, origin: .trustedInterface) }
                    catch { self.status = "Requested destination is unavailable. The previous journey remains cancelled." }
                }
                if let hold = self.holdAfterRestore {
                    self.holdAfterRestore = nil
                    do {
                        if hold { try self.hold(origin: .trustedInterface) }
                        else { try self.resume(origin: .trustedInterface) }
                    } catch { self.status = "No matching journey is available for that task control." }
                }
                self.loadID = nil; self.onChange?()
            } catch {
#if DEBUG
                trace?("restore-main-error-resumed", id, ProcessInfo.processInfo.systemUptime)
#endif
                guard let self, self.loadID == id else { return }
                self.loading = false; self.loadID = nil; self.storageError = true; self.durable = false
                self.status = "Journey history could not be opened. No guidance is available."
                if self.eraseAfterRestore {
                    // Explicit privacy erasure does not need to read corrupt/old
                    // private data successfully before writing an empty tombstone.
                    self.eraseAfterRestore = false; self.cancelAfterRestore = false
                    try? self.applyErase(id: self.eraseReceipt?.id ?? UUID())
                }
                self.onChange?()
            }
        }
#if DEBUG
        diagnosticRestoreCompletion = (id, completion)
#endif
    }
    /// Installs source-known artifacts after the existing native atomic map import
    /// succeeds. A queued initial installation is one latest value, not a FIFO.
    public func install(_ installation: SpatialMapInstallation, portals: [JourneyPortal] = []) throws {
        retire(); coordinator?.loseTracking()
        if loading { pendingInstallation = (installation, portals); return }
        guard !storageError else { throw JourneyRuntimeError.storageUnavailable }
        guard !retiredBindings.contains(installation.binding),
              Set(requestedMaps.keys).union(retiredBindings).union([installation.binding]).count <= 256 else {
            mapValidationBlocked = true; throw SpatialInstallationError.historyRewrite
        }
        guard portals.count <= 128,
              requestedMaps[installation.binding] != nil || requestedMaps.count < 32 else {
            mapValidationBlocked = true; throw JourneyRuntimeError.tooLarge
        }
        requestedMaps[installation.binding] = installation
        requestedRegistry = installation.registry
        if !portals.isEmpty { requestedPortals = portals }
        scheduleCatalog()
    }
    public func withdrawMap(_ binding: SpatialMapBinding) throws {
        retire(); coordinator?.loseTracking()
        guard let registry = requestedRegistry ?? catalog?.registry else { return }
        let old = registry.snapshot
        if requestedMaps[binding] != nil || catalog?.installations[binding] != nil {
            guard retiredBindings.contains(binding) || retiredBindings.count < 256 else { throw JourneyRuntimeError.tooLarge }
            retiredBindings.insert(binding)
            try enqueueSave() // Persist only a tombstone, not deleted geometry.
        }
        requestedRegistry = try SpatialFrameRegistry(snapshot: .init(nodes: old.nodes, maps: old.maps,
            activeBindings: old.activeBindings.filter { $0 != binding }, links: old.links, transitions: old.transitions))
        requestedMaps.removeValue(forKey: binding)
        requestedPortals.removeAll { $0.from.binding == binding || $0.to.binding == binding }
        scheduleCatalog()
    }
    private func scheduleCatalog() {
        guard let registry = requestedRegistry else { return }
        let id = UUID(); mapRevision = id
        let input = (id, registry, requestedMaps, requestedPortals)
        if mapWorkID != nil { pendingMapWork = input } else { startCatalog(input) }
        status = "Registered map update is pending. Guidance is paused."; onChange?()
    }
    private func startCatalog(_ input: (UUID, SpatialFrameRegistry, [SpatialMapBinding: SpatialMapInstallation], [JourneyPortal])) {
        mapWorkID = input.0
        let previous = catalog?.registry
#if DEBUG
        let trace = diagnosticPhaseRecorder
        trace?("catalog-task-queued", input.0, ProcessInfo.processInfo.systemUptime)
#endif
        let completion = Task { [weak self] in
#if DEBUG
            trace?("catalog-task-entered", input.0, ProcessInfo.processInfo.systemUptime)
            trace?("catalog-detached-queued", input.0, ProcessInfo.processInfo.systemUptime)
#endif
            let result = await Task.detached(priority: .utility) { () -> Result<ConnectedJourneyCatalog, Error> in
#if DEBUG
                trace?("catalog-detached-begin", input.0, ProcessInfo.processInfo.systemUptime)
                defer { trace?("catalog-detached-end", input.0, ProcessInfo.processInfo.systemUptime) }
#endif
                return Result {
                    if var previous { try previous.update(snapshot: input.1.snapshot) }
                    let maps = try input.2.values.filter { input.1.snapshot.activeBindings.contains($0.binding) }.map { map in
                        try SpatialMapInstallation(envelope: .init(snapshot: input.1.snapshot, binding: map.binding,
                            mapBytes: map.envelope.mapBytes, artifactHistory: map.envelope.artifactHistory,
                            restrictions: map.envelope.restrictions), sha256: { bytes in
                                guard bytes == map.envelope.mapBytes else { throw SpatialInstallationError.artifactMismatch }
                                return map.artifact.sha256
                            })
                    }
                    let available = Set(maps.map(\.binding))
                    return try ConnectedJourneyCatalog(registry: input.1, installations: maps,
                        portals: input.3.filter { available.contains($0.from.binding) && available.contains($0.to.binding) })
                }
            }.value
#if DEBUG
            trace?("catalog-main-resumed", input.0, ProcessInfo.processInfo.systemUptime)
#endif
            guard let self, self.mapWorkID == input.0 else { return }
            self.mapWorkID = nil
            if let next = self.pendingMapWork { self.pendingMapWork = nil; self.startCatalog(next); return }
            guard self.mapRevision == input.0 else { return }
            do {
                let next = try result.get()
                // Publication uses the LATEST intent, not a snapshot captured before
                // asynchronous map preparation. It cannot resurrect a cancelled goal.
                if var owner = self.coordinator { try owner.replaceCatalog(next); self.coordinator = owner }
                self.catalog = next
                if self.coordinator == nil { try self.rebuildCoordinator() }
                self.requestedMaps = next.installations; self.requestedRegistry = next.registry
                self.requestedPortals = next.portals
                self.externalMapPending = false; self.mapValidationBlocked = false
                try self.enqueueSave()
                self.status = "Registered maps retained. Fresh location is required."
            } catch {
                self.requestedMaps = self.catalog?.installations ?? [:]
                self.requestedRegistry = self.catalog?.registry; self.requestedPortals = self.catalog?.portals ?? []
                self.mapValidationBlocked = true; self.status = "Map update could not be accepted. Guidance is paused."
            }
            self.onChange?()
        }
#if DEBUG
        diagnosticCatalogCompletion = (input.0, completion)
#endif
    }
    public func configure(body: BodyEnvelope, limits: SpatialLocalizationLimits) throws {
        retire(); coordinator?.loseTracking()
        guard body.valid, limits.valid else {
            self.body = nil; self.limits = nil; try rebuildCoordinator()
            throw ConnectedJourneyError.invalidCatalog
        }
        self.body = body; self.limits = limits; try rebuildCoordinator()
    }
    public func setDestination(binding: SpatialMapBinding, nodeID: String, origin: CompanionCommandOrigin) throws {
        guard CommandAuthority.permits(.changeGoal, from: origin) else { throw ConnectedJourneyError.unauthorized }
        retire(); commandBlocked = true
        if loading {
            cancelAfterRestore = true
            guard !nodeID.isEmpty, nodeID.utf8.count <= 200,
                  [binding.mapID, binding.frameID, binding.revision].allSatisfy({ !$0.isEmpty && $0.utf8.count <= 200 }) else { destinationAfterRestore = nil; throw JourneyRuntimeError.noRegisteredMap }
            destinationAfterRestore = (binding, nodeID)
            status = "Destination change is queued while history opens. Guidance is unavailable."; onChange?(); return
        }
        let endpoint: JourneyEndpoint
        do { endpoint = try self.endpoint(binding: binding, nodeID: nodeID) }
        catch {
            // Persist a cancellation tombstone when a new explicit target is
            // unavailable; a later restart must not silently restore its predecessor.
            try? cancel(origin: origin)
            throw error
        }
        try mutate { try $0.setDestination(endpoint, origin: origin, recordedAt: Date(), persist: { _ in }) }
        pendingStartOrigin = origin; commandBlocked = false
        status = "Destination retained while saving. Current location is required before guidance."; onChange?()
    }
    public func hold(origin: CompanionCommandOrigin) throws {
        guard CommandAuthority.permits(.changeGoal, from: origin) else { throw ConnectedJourneyError.unauthorized }
        if loading { retire(); holdAfterRestore = true; return }
        if coordinator == nil {
            retire(); guard snapshot.goal?.status == .active else { throw ConnectedJourneyError.noGoal }
            snapshot.goal?.status = .paused; try enqueueSave()
        } else { try mutate { try $0.hold(origin: origin, persist: { _ in }) } }
        status = "Journey paused. Its destination is retained."; onChange?()
    }
    public func resume(origin: CompanionCommandOrigin) throws {
        guard CommandAuthority.permits(.changeGoal, from: origin) else { throw ConnectedJourneyError.unauthorized }
        if loading { retire(); holdAfterRestore = false; return }
        if coordinator == nil {
            retire(); guard snapshot.goal?.status == .paused else { throw ConnectedJourneyError.noGoal }
            snapshot.goal?.status = .active; try enqueueSave()
        } else { try mutate { try $0.resume(origin: origin, persist: { _ in }) } }
        coordinator?.loseTracking() // Retain intent, discard the held executable plan.
        status = "Journey resumed. Fresh location is required before guidance."; onChange?()
    }
    public func cancel(origin: CompanionCommandOrigin) throws {
        guard CommandAuthority.permits(.cancelTaskOrNavigation, from: origin) else { throw ConnectedJourneyError.unauthorized }
        retire(); pendingStartOrigin = nil
        if loading { cancelAfterRestore = true; destinationAfterRestore = nil; holdAfterRestore = nil; return }
        if coordinator != nil { try mutate { try $0.cancel(origin: origin, recordedAt: Date(), persist: { _ in }) } }
        else {
            snapshot.goal?.status = .cancelled; snapshot.returnClarificationPending = false
            try enqueueSave()
        }
        status = "Journey cancelled."; onChange?()
    }
    @discardableResult public func eraseHistory(origin: CompanionCommandOrigin) throws -> UUID {
        guard origin == .trustedInterface else { throw ConnectedJourneyError.unauthorized }
        retire(); pendingStartOrigin = nil; commandBlocked = true
        let id = UUID(); eraseReceipt = .init(id: id, state: .pending)
        if loading {
            eraseAfterRestore = true; cancelAfterRestore = false; destinationAfterRestore = nil; holdAfterRestore = nil
            onChange?(); return id
        }
        try applyErase(id: id); return id
    }
    private func applyErase(id: UUID) throws {
        snapshot = ConnectedJourneySnapshot(); eraseSnapshotID = snapshot.id
        eraseReceipt = .init(id: id, state: .pending)
        try rebuildCoordinator(); try enqueueSave()
        status = "Erasing journey history. Deletion is not complete yet."; onChange?()
    }
    public func retryErase(_ id: UUID) throws {
        guard eraseReceipt?.id == id, eraseReceipt?.state == .failed,
              let latestWrite, latestWrite.journey.id == eraseSnapshotID else { throw JourneyRuntimeError.superseded }
        eraseReceipt = .init(id: id, state: .pending); queue(latestWrite)
        status = "Retrying journey history erasure. Deletion is not complete yet."; onChange?()
    }
    public func mapOwnershipWithdrawn() { externalMapPending = true; cameraRestarted() }
    public func mapPreviewPublished() {
        externalMapPending = true; cameraRestarted()
        status = "Preview map has no registered frame. Journey history is retained, but guidance is unavailable."; onChange?()
    }
    public func mapRemovalSettled(_ binding: SpatialMapBinding?) throws {
        retire(); coordinator?.loseTracking()
        if loading {
            if let binding {
                guard pendingRemovals.count < 32 || pendingRemovals.contains(binding) else { throw JourneyRuntimeError.tooLarge }
                pendingRemovals.insert(binding)
                if pendingInstallation?.0.binding == binding { pendingInstallation = nil }
            }
            return
        }
        if let binding { try withdrawMap(binding) }
        else { externalMapPending = false; cameraRestarted() }
    }
    public func cameraRestarted() { retire(); lastEndpoint = nil; coordinator?.loseTracking(); status = "Destination retained. Live location is unknown."; onChange?() }
    public func beginLocalization(in binding: SpatialMapBinding) throws -> UUID {
        retireOutput(); lastEndpoint = nil
        guard !loading, !externalMapPending, !mapValidationBlocked, mapWorkID == nil else { throw JourneyRuntimeError.loading }
        guard var owner = coordinator else { throw JourneyRuntimeError.noRegisteredMap }
        defer { coordinator = owner }
        return try owner.beginLocalization(in: binding)
    }
    /// No caller in current ARKit code can manufacture this contract. This entry is
    /// for a calibrated issuer and executable synthetic tests, never a room label.
    public func accept(_ capture: SpatialLocalizationCapture, support: SpatialFloorSupport, now: Double) throws {
        retireOutput()
        guard !loading, !externalMapPending, !mapValidationBlocked, mapWorkID == nil else { throw JourneyRuntimeError.loading }
        guard var owner = coordinator else { throw JourneyRuntimeError.noRegisteredMap }
        do { try owner.accept(capture, support: support, now: now) }
        catch {
            // Retire the old question/output before replacing its owner, and never
            // retain a convenience endpoint from a rejected localization capture.
            retire(); lastEndpoint = nil; coordinator = owner; onChange?()
            throw error
        }
        coordinator = owner
        if let endpoint = currentEndpoint(capture: capture, support: support) {
            lastEndpoint = endpoint
            if snapshot.start == nil, let origin = pendingStartOrigin {
                try mutate(retireClarification: false) { try $0.markStart(at: endpoint, origin: origin, now: now, recordedAt: Date(), persist: { _ in }) }
                pendingStartOrigin = nil
            }
            if canOutput, snapshot.goal?.status == .active, !snapshot.returnClarificationPending {
                if coordinator?.currentLeg == nil, let target = snapshot.goal?.target.endpoint, sameLocation(endpoint, target) {
                    try mutate(retireClarification: false) { try $0.completeAtGoal(now: now, recordedAt: Date(), persist: { _ in }) }
                } else if case .local(_, let to)? = coordinator?.currentLeg, sameLocation(endpoint, to) {
                    try mutate(retireClarification: false) { try $0.completeLocalLeg(now: now, recordedAt: Date(), persist: { _ in }) }
                    if case .portal? = coordinator?.currentLeg { try coordinator?.armPortal(now: now, recordedAt: Date()) }
                } else if case .portal(_, let from, _)? = coordinator?.currentLeg, sameLocation(endpoint, from) {
                    // Evidence withdrawal discards the old departure receipt but
                    // retains intent. Only this fresh measured source endpoint
                    // can rearm it; the old departure is never restored.
                    try coordinator?.armPortal(now: now, recordedAt: Date())
                } else if case .portal(_, _, let to)? = coordinator?.currentLeg, sameLocation(endpoint, to) {
                    try mutate(retireClarification: false) { try $0.completePortal(now: now, recordedAt: Date(), persist: { _ in }) }
                    try coordinator?.prepareLocalLeg(now: now)
                } else if coordinator?.currentLeg == nil {
                    try coordinator?.plan(from: endpoint, now: now)
                    // An itinerary can begin directly at an authored portal
                    // source. Associate the fresh source, never crossing guidance.
                    if case .portal? = coordinator?.currentLeg { try coordinator?.armPortal(now: now, recordedAt: Date()) }
                } else {
                    // The existing owner verifies proximity before advancing. A
                    // non-waypoint sample is not arrival and leaves the plan alone.
                    try? coordinator?.advanceWaypoint(now: now)
                }
            }
        }
        onChange?()
    }
    private var canOutput: Bool { !loading && !externalMapPending && !mapValidationBlocked && mapWorkID == nil && durable && !storageError && !commandBlocked }
    public func next(now: Double) throws -> ConnectedJourneyRouteTicket {
        guard canOutput, let coordinator else { throw JourneyRuntimeError.storageUnavailable }
        let ticket = try coordinator.next(now: now); held = ticket; return ticket
    }
    public func permits(_ ticket: SpatialRouteTicket, now: Double) -> Bool {
        guard canOutput, let held,
              held.route.routeID == ticket.routeID, held.route.goalRevision == ticket.goalRevision,
              held.route.spatial == ticket.spatial else { return false }
        return coordinator?.permits(held, now: now) == true
    }
    public func revalidate(now: Double) { if let held, !permits(held.route, now: now) { retireOutput() } }
    public func saveReference(origin: CompanionCommandOrigin, now: Double) throws {
        guard CommandAuthority.permits(.changeGoal, from: origin) else { throw ConnectedJourneyError.unauthorized }
        guard let lastEndpoint else { throw ConnectedJourneyError.awaitingLocalization }
        try mutate { try $0.saveReference(at: lastEndpoint, origin: origin, now: now, recordedAt: Date(), persist: { _ in }) }
    }
    public func requestReturn(origin: CompanionCommandOrigin, arabic: Bool) throws -> JourneyReturnRequest {
        guard CommandAuthority.permits(.startReturn, from: origin) else { throw ConnectedJourneyError.unauthorized }
        if loading {
            retire(); cancelAfterRestore = true; destinationAfterRestore = nil; holdAfterRestore = nil
            throw JourneyRuntimeError.loading
        }
        var request: JourneyReturnRequest?
        try mutate { request = try $0.requestReturn(origin: origin, arabic: arabic, recordedAt: Date(), persist: { _ in }) }
        commandBlocked = false
        return request!
    }
    public func beginClarificationSpeech(_ question: JourneyReturnQuestion) -> Bool {
        guard self.question?.id == question.id else { return false }
        clarificationToken = clarificationLedger.begin(text: question.text, priority: .information,
            destination: .requested(question.id), transport: .synthesized)?.token
        return clarificationToken != nil
    }
    public func clarificationSpeechFinished(id: UUID, text: String, outcome: NarrationDelivery, now: Double) -> Bool {
        guard question?.id == id, question?.text == text, let token = clarificationToken,
              let completion = clarificationLedger.finish(token: token, outcome: outcome, now: now) else { return false }
        clarificationToken = nil
        clarificationReceipt = try? coordinator?.recordClarificationDelivery(completion, now: now)
        return true
    }
    public func resolveReturn(_ choice: JourneyReturnQuestion.Choice, origin: CompanionCommandOrigin, now: Double) throws {
        guard CommandAuthority.permits(.startReturn, from: origin) else { throw ConnectedJourneyError.unauthorized }
        guard let receipt = clarificationReceipt else { throw ConnectedJourneyError.clarificationNotDelivered }
        clarificationReceipt = nil
        try mutate { try $0.resolveReturn(choice, receipt: receipt, origin: origin, now: now, recordedAt: Date(), persist: { _ in }) }
        commandBlocked = false
    }
    public func retryPersistence() throws {
        guard let latestWrite else { restore(); return }
        queue(latestWrite)
    }
    private func endpoint(binding: SpatialMapBinding, nodeID: String) throws -> JourneyEndpoint {
        guard let catalog, let installed = catalog.installations[binding],
              let node = installed.map.nodes.first(where: { $0.id == nodeID }),
              let record = try? catalog.registry.map(for: binding), let floor = record.floorLevels[node.level] else { throw JourneyRuntimeError.noRegisteredMap }
        let root = catalog.registry.snapshot.nodes.first { $0.id == record.nodeID }
        return .init(binding: binding, floorID: floor, nodeID: nodeID, roomID: root?.kind == .room ? root?.id : nil)
    }
    private func sameLocation(_ observed: JourneyEndpoint, _ target: JourneyEndpoint) -> Bool {
        observed.binding == target.binding && observed.floorID == target.floorID && observed.nodeID == target.nodeID &&
            (target.roomID == nil || observed.roomID == target.roomID)
    }
    private func currentEndpoint(capture: SpatialLocalizationCapture, support: SpatialFloorSupport) -> JourneyEndpoint? {
        guard let catalog, let map = catalog.installations[capture.binding]?.map,
              let record = try? catalog.registry.map(for: capture.binding) else { return nil }
        let candidates = map.nodes.filter { record.floorLevels[$0.level] == capture.floorID &&
            hypot($0.position.x - capture.position.x, $0.position.z - capture.position.z) + capture.positionUncertainty <= 0.35 &&
            abs($0.position.y - support.height) <= 0.09 }
        guard candidates.count == 1 else { return nil }
        return .init(binding: capture.binding, floorID: capture.floorID, nodeID: candidates[0].id, roomID: capture.roomID)
    }
    private func rebuildCoordinator() throws {
        guard let catalog else { coordinator = nil; return }
        coordinator = try .init(catalog: catalog, body: body, limits: limits, snapshot: snapshot)
    }
    private func mutate(retireClarification: Bool = true, _ operation: (inout ConnectedJourneyCoordinator) throws -> Void) throws {
        if retireClarification { retire() } else { retireOutput() }
        guard !loading, var owner = coordinator else { throw JourneyRuntimeError.noRegisteredMap }
        do { try operation(&owner); coordinator = owner; snapshot = owner.snapshot; try enqueueSave() }
        catch { coordinator = owner; snapshot = owner.snapshot; durable = false; onChange?(); throw error }
    }
    private func writePayload() -> JourneyRuntimeWrite {
        .init(journey: snapshot,
            installations: catalog?.installations.values.filter { !retiredBindings.contains($0.binding) }.sorted { $0.binding.mapID < $1.binding.mapID } ?? [],
            portals: catalog?.portals.filter { !retiredBindings.contains($0.from.binding) && !retiredBindings.contains($0.to.binding) } ?? [],
            retiredBindings: retiredBindings.sorted { "\($0.mapID)/\($0.frameID)/\($0.revision)" < "\($1.mapID)/\($1.frameID)/\($1.revision)" })
    }
    private func enqueueSave() throws {
        let payload = writePayload(); latestWrite = payload; queue(payload)
    }
    private func queue(_ payload: JourneyRuntimeWrite) {
        retireOutput(); durable = false; storageError = false
        let ticket = UUID(); version = ticket
        if writing != nil { pending = (ticket, payload); onChange?(); return }
        startWrite(ticket, payload)
    }
    private func startWrite(_ ticket: UUID, _ payload: JourneyRuntimeWrite) {
        writing = ticket
        let completion = Task { [weak self, io] in
            var error: Error?
            do { try await io.write(payload) } catch let failure { error = failure }
            guard let self, self.writing == ticket else { return }
            self.writing = nil
            if let pending = self.pending { self.pending = nil; self.startWrite(pending.0, pending.1) }
            else if error == nil, ticket == self.version {
                self.durable = true; self.storageError = false
                if let receipt = self.eraseReceipt, receipt.state != .succeeded, self.eraseSnapshotID == payload.journey.id {
                    self.eraseReceipt = .init(id: receipt.id, state: .succeeded)
                    self.status = "Journey history erased on this phone."
                }
            } else {
                self.durable = false; self.storageError = true; self.status = "Journey changes are not saved. Guidance is paused."
                if let receipt = self.eraseReceipt, receipt.state != .succeeded, self.eraseSnapshotID == payload.journey.id {
                    self.eraseReceipt = .init(id: receipt.id, state: .failed)
                    self.status = "Journey history could not be erased. Old data remains on this phone. Retry erasure."
                }
            }
            self.onChange?()
        }
#if DEBUG
        diagnosticWriteCompletion = (ticket, completion)
#endif
    }
    private func retireOutput() { held = nil; onOutputRetired?() }
    private func retire() {
        retireOutput()
        if let question { onClarificationRetired?(question.id) }
        if let token = clarificationToken { _ = clarificationLedger.finish(token: token, outcome: .interrupted, now: 0) }
        clarificationToken = nil; clarificationReceipt = nil
    }
}
