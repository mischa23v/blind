import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
import BlindCore

/// Main-owner route adapter with bounded serial validation/persistence.
/// Disk/JSON/hash work never runs on this owner. Every publication is generation
/// and installation-revision checked; pending/failed IO has no route authority.
/// Confine to the same main-thread owner as IndoorNavigator. There is deliberately
/// NO native capture issuer: ARKit normal tracking and heuristic heading confidence
/// do not supply the measured uncertainty required by SpatialLocalizationLease.
final class RegisteredIndoorNavigation {
    private let io: SpatialMapIO<Loaded>
    private let sha256: SpatialMapSHA256
    private var dormantInstallation: SpatialMapInstallation?
    private var dormantRestrictionsDurable = true
    private var owner: SpatialRouteOwner?
    private var support: SpatialFloorSupport?
    private var heldTicket: SpatialRouteTicket?
    /// Wire to route-specific speech/beacon retirement, not the independent hazard sink.
    var onOutputRetired: (() -> Void)?
    var installation: SpatialMapInstallation? { owner?.installation ?? dormantInstallation }
    var configured: Bool { owner != nil }
    var route: [MapNode] { owner?.route ?? [] }
    var waypointIndex: Int { owner?.waypointIndex ?? 0 }
    var sessionID: UUID? { owner?.sessionID }
    static let platformSHA256: SpatialMapSHA256 = { data in
        #if canImport(CryptoKit)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #else
        // Linux test targets must inject an established implementation explicitly.
        // There is no noncryptographic fallback in the production adapter.
        throw SpatialInstallationError.invalidDigest
        #endif
    }
    init(storage: URL, sha256: @escaping SpatialMapSHA256 = platformSHA256,
         storageIO: (any SpatialMapStorageIO)? = nil) {
        self.io = SpatialMapIO(storage: storageIO ?? SpatialMapFileStorage(url: storage)); self.sha256 = sha256
    }
    struct Loaded: Sendable {
        let installation: SpatialMapInstallation?
        let map: IndoorMap
        let package: PlacePackage?
        let owner: SpatialRouteOwner?
    }
    typealias Completion = (Result<Loaded?, Error>) -> Void
    private struct Configuration: Sendable { let body: BodyEnvelope; let limits: SpatialLocalizationLimits }
    private var configuration: Configuration?
    private var routeOperation = UUID()
    private var storageRevision = UUID()
    private var pendingRestrictions: (blocked: Set<MapConnection>, zones: [KeepOutZone]) = ([], [])
    private(set) var ioPending = false
    private(set) var ioBlocked = false
    private var context: SpatialMapIOContext { .init(revision: storageRevision, artifact: installation?.artifact) }
    private func beginIO() {
        precondition(Thread.isMainThread)
        io.invalidate()
        retireOutput(); owner?.loseTracking(); support = nil
        ioPending = true; ioBlocked = true
    }
    private static func prepared(_ installation: SpatialMapInstallation, configuration: Configuration?) throws -> Loaded {
        guard installation.map.permitsRoutePlanning else { throw SpatialInstallationError.invalidEnvelope }
        var owner: SpatialRouteOwner?
        if let configuration {
            var next = try SpatialRouteOwner(body: configuration.body, limits: configuration.limits)
            try next.restoreValidated(installation); owner = next
        }
        return Loaded(installation: installation, map: installation.map, package: nil, owner: owner)
    }
    private func submit(prepare: @escaping @Sendable (any SpatialMapStorageIO) throws -> SpatialMapPrepared<Loaded>,
                        completion: @escaping Completion) {
        let expected = context
        beginIO()
        io.submit(expected: expected, prepare: prepare) { [weak self] token, result in
            guard let self else { completion(.failure(SpatialMapIOError.superseded)); return }
            guard self.io.isCurrent(token), self.context == token.expected else {
                completion(.failure(SpatialMapIOError.superseded)); return
            }
            self.ioPending = false
            switch result {
            case .success(let loaded):
                guard let loaded else { completion(.failure(SpatialMapIOError.unavailable)); return }
                self.storageRevision = UUID()
                self.owner = loaded.owner; self.dormantInstallation = loaded.owner == nil ? loaded.installation : nil
                self.dormantRestrictionsDurable = true; self.pendingRestrictions = ([], [])
                self.support = nil; self.ioBlocked = false
                completion(.success(loaded))
            case .failure(let error):
                // Existing map metadata remains, but pose/output stay unknown. A
                // failed save may not silently restore route authority.
                completion(.failure(error))
            }
        }
    }
    func restore(completion: @escaping Completion) {
        guard installation == nil else { completion(.failure(SpatialInstallationError.historyRewrite)); return }
        let sha256 = self.sha256
        submit(prepare: { storage in
            let data = try storage.read(maximumBytes: SpatialMapInstallation.maximumEnvelopeBytes)
            return try Self.decode(data, previous: nil, restrictions: ([], []), configuration: nil,
                                   sha256: sha256, persist: false)
        }, completion: completion)
    }
    /// Policy is explicitly supplied. Adoption reuses the already validated value;
    /// no main-thread JSON encoding, hash, validation pass or filesystem operation.
    func configure(body: BodyEnvelope, limits: SpatialLocalizationLimits) throws {
        guard !ioPending, !ioBlocked else { throw SpatialMapIOError.busy }
        guard owner == nil else { throw SpatialInstallationError.historyRewrite }
        guard let installation else { throw SpatialInstallationError.noInstalledMap }
        guard dormantRestrictionsDurable else { throw SpatialRouteError.unpersistedRestrictions }
        var next = try SpatialRouteOwner(body: body, limits: limits)
        try next.restoreValidated(installation)
        retireOutput(); owner = next; dormantInstallation = nil; support = nil
        configuration = Configuration(body: body, limits: limits)
    }
    func install(_ data: Data, completion: @escaping Completion) {
        guard !data.isEmpty, data.count <= SpatialMapInstallation.maximumEnvelopeBytes else {
            beginIO(); ioPending = false; completion(.failure(SpatialMapIOError.oversized)); return
        }
        let previous = installation, restrictions = pendingRestrictions, config = configuration, sha256 = self.sha256
        submit(prepare: { storage in
            try Self.decode(data, previous: previous ?? Self.priorFromDisk(storage, sha256: sha256), restrictions: restrictions, configuration: config,
                            sha256: sha256, persist: true)
        }, completion: completion)
    }
    func importFile(_ url: URL, completion: @escaping Completion) {
        let previous = installation, restrictions = pendingRestrictions, config = configuration, sha256 = self.sha256
        submit(prepare: { storage in
            #if os(iOS) || os(macOS)
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            #endif
            let data = try SpatialMapFileStorage.readBounded(url, maximumBytes: SpatialMapInstallation.maximumEnvelopeBytes)
            return try Self.decode(data, previous: previous ?? Self.priorFromDisk(storage, sha256: sha256), restrictions: restrictions, configuration: config,
                                   sha256: sha256, persist: true)
        }, completion: completion)
    }
    func installCommunity(_ package: PlacePackage, completion: @escaping Completion) {
        submit(prepare: { _ in
            try package.validate()
            guard package.localization == "manual-landmarks", var map = package.routeMap, map.permitsRoutePlanning else { throw MapError.invalid }
            map.packageID = package.id; map.packageRevision = package.revision
            let bytes = try SpatialMapInstallation.canonicalMapBytes(map)
            return SpatialMapPrepared(value: Loaded(installation: nil, map: map, package: package, owner: nil), bytesToPersist: bytes)
        }, completion: completion)
    }
    func installPreviewEdit(_ map: IndoorMap, package: PlacePackage?, completion: @escaping Completion) {
        submit(prepare: { _ in
            guard map.permitsRoutePlanning else { throw SpatialInstallationError.invalidEnvelope }
            let bytes = try SpatialMapInstallation.canonicalMapBytes(map)
            return SpatialMapPrepared(value: Loaded(installation: nil, map: map, package: package, owner: nil), bytesToPersist: bytes)
        }, completion: completion)
    }
    /// Fence delayed map work immediately, before a separate asynchronous privacy
    /// purge. The subsequent delete is still an ordered worker barrier, not a main
    /// filesystem call. A newer request may supersede this unfinished intent.
    func suspendForExternalPreparation() { beginIO(); routeOperation = UUID() }
    func externalPreparationFailed() { precondition(Thread.isMainThread); ioPending = false }
    func invalidateForDeletion() {
        beginIO(); owner = nil; dormantInstallation = nil; configuration = nil
        pendingRestrictions = ([], []); storageRevision = UUID()
    }
    private static func decode(_ data: Data, previous: SpatialMapInstallation?,
        restrictions: (blocked: Set<MapConnection>, zones: [KeepOutZone]), configuration: Configuration?,
        sha256: SpatialMapSHA256, persist: Bool) throws -> SpatialMapPrepared<Loaded> {
        guard !data.isEmpty, data.count <= SpatialMapInstallation.maximumEnvelopeBytes,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw MapError.invalid }
        if object["mapBytes"] != nil || object["snapshot"] != nil || object["artifactHistory"] != nil {
            let candidate = try SpatialMapInstallation(data: data, sha256: sha256)
            if let previous {
                // Pending positive restrictions are part of replacement history,
                // even when their first asynchronous persistence was superseded.
                let required = restrictions.blocked.isEmpty && restrictions.zones.isEmpty ? previous :
                    try previous.addingRestrictions(blocked: restrictions.blocked, zones: restrictions.zones)
                try candidate.validateReplacement(of: required)
            }
            return try SpatialMapPrepared(value: prepared(candidate, configuration: configuration), bytesToPersist: persist ? candidate.encoded() : nil)
        }
        guard data.count <= SpatialMapInstallation.maximumMapBytes else { throw SpatialMapIOError.oversized }
        let map = try JSONDecoder().decode(IndoorMap.self, from: data); try map.validate()
        guard map.permitsRoutePlanning else { throw SpatialInstallationError.invalidEnvelope }
        return SpatialMapPrepared(value: Loaded(installation: nil, map: map, package: nil, owner: nil), bytesToPersist: persist ? data : nil)
    }
    private static func priorFromDisk(_ storage: any SpatialMapStorageIO, sha256: SpatialMapSHA256) throws -> SpatialMapInstallation? {
        let data: Data
        do { data = try storage.read(maximumBytes: SpatialMapInstallation.maximumEnvelopeBytes) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return nil }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw MapError.invalid }
        if object["mapBytes"] != nil || object["snapshot"] != nil || object["artifactHistory"] != nil {
            return try SpatialMapInstallation(data: data, sha256: sha256)
        }
        return nil // Legacy preview carries no registered history or authority.
    }
    func delete(completion: @escaping Completion) {
        beginIO()
        owner = nil; dormantInstallation = nil; configuration = nil; pendingRestrictions = ([], [])
        storageRevision = UUID()
        io.submit(expected: context, delete: true) { [weak self] token, result in
            guard let self, self.io.isCurrent(token), self.context == token.expected else {
                completion(.failure(SpatialMapIOError.superseded)); return
            }
            self.ioPending = false
            if case .success = result { self.ioBlocked = false; self.storageRevision = UUID() }
            completion(result)
        }
    }
    func currentPose(now: Double) -> SpatialLocalizationCapture? { ioPending || ioBlocked ? nil : owner?.currentPose(now: now) }
    func accept(_ capture: SpatialLocalizationCapture, floorSupport: SpatialFloorSupport, now: Double) throws {
        guard !ioPending, !ioBlocked, var next = owner else { throw SpatialRegistryError.noCurrentPose }
        do {
            try next.accept(capture, now: now)
            owner = next; support = floorSupport
            revalidate(now: now)
        } catch {
            owner = next; support = nil; retireOutput(); throw error
        }
    }
    func plan(from: String, to: String, goal: UUID) throws {
        routeOperation = UUID()
        guard !ioPending, !ioBlocked, var next = owner else { throw SpatialRegistryError.noCurrentPose }
        next.setGoal(revision: goal)
        retireOutput()
        do { try next.plan(from: from, to: to, goal: goal); owner = next }
        catch { owner = next; throw error }
    }
    func blockNextLegAndReplan(completion: @escaping Completion) {
        guard !ioPending, !ioBlocked, let owner, let installation, let goal = owner.goalRevision,
              owner.waypointIndex > 0, owner.waypointIndex < owner.route.count,
              let destination = owner.route.last?.id else { completion(.failure(SpatialRouteError.noRoute)); return }
        let from = owner.route[owner.waypointIndex - 1].id, to = owner.route[owner.waypointIndex].id
        let expectedRoute = routeOperation
        addRestrictions(binding: installation.binding, blocked: [MapConnection(from, to)], zones: []) { [weak self] result in
            guard let self else { completion(.failure(SpatialMapIOError.superseded)); return }
            do {
                _ = try result.get()
                guard self.routeOperation == expectedRoute else { completion(result); return }
                try self.plan(from: from, to: destination, goal: goal); completion(result)
            }
            catch { completion(.failure(error)) }
        }
    }
    func cancelRoute() { routeOperation = UUID(); retireOutput(); owner?.cancelRoute() }
    /// Compare before mutation: a delayed candidate from A cannot retire newer B.
    /// Preserve session and replay ledger so withdrawing output does not stale the
    /// candidate being measured. True lifecycle loss still uses loseTracking.
    func withholdNativeEvidence(session: UUID, artifact: SpatialMapArtifactIdentity) {
        guard sessionID == session, installation?.artifact == artifact else { return }
        retireOutput(); owner?.withholdLocalizationEvidence(); support = nil
    }
    func loseTracking() { routeOperation = UUID(); retireOutput(); owner?.loseTracking(); support = nil }
    func setBody(_ body: BodyEnvelope) throws {
        routeOperation = UUID()
        guard !ioPending, !ioBlocked, var next = owner else { throw SpatialRegistryError.noCurrentPose }
        try next.setBody(body); owner = next; retireOutput()
        if let configuration { self.configuration = Configuration(body: body, limits: configuration.limits) }
    }
    func addRestrictions(binding: SpatialMapBinding, blocked: Set<MapConnection>, zones: [KeepOutZone],
                         completion: @escaping Completion) {
        beginIO() // Positive restriction request immediately retires current output.
        guard let installation, binding == installation.binding else {
            ioPending = false; completion(.failure(SpatialRegistryError.invalidMap)); return
        }
        let combinedEdges = pendingRestrictions.blocked.union(blocked)
        var combinedZones = pendingRestrictions.zones
        for zone in zones {
            if let old = combinedZones.first(where: { $0.id == zone.id }) {
                guard old == zone else { ioPending = false; completion(.failure(SpatialInstallationError.historyRewrite)); return }
            } else { combinedZones.append(zone) }
        }
        guard combinedEdges.count <= 10_000, combinedZones.count <= 500 else {
            ioPending = false; completion(.failure(SpatialMapIOError.oversized)); return
        }
        pendingRestrictions = (combinedEdges, combinedZones)
        dormantRestrictionsDurable = false
        let restrictions = pendingRestrictions, config = configuration
        submit(prepare: { _ in
            let candidate = try installation.addingRestrictions(blocked: restrictions.blocked, zones: restrictions.zones)
            return try SpatialMapPrepared(value: Self.prepared(candidate, configuration: config), bytesToPersist: candidate.encoded())
        }, completion: completion)
    }
    func confirmWaypoint() { routeOperation = UUID(); retireOutput(); owner?.confirmWaypoint() }
    func next(now: Double) throws -> SpatialRouteTicket {
        do {
            guard !ioPending, !ioBlocked, let owner, let support else { throw SpatialRegistryError.noCurrentPose }
            let ticket = try owner.next(support: support, now: now)
            heldTicket = ticket; return ticket
        } catch { retireOutput(); throw error }
    }
    func permits(_ ticket: SpatialRouteTicket, now: Double) -> Bool { !ioPending && !ioBlocked && owner?.permits(ticket, now: now) == true }
    /// Must run before dispatch and from the parent watchdog while output is held.
    /// Expiry is not dependent on a new sensor frame arriving.
    func revalidate(now: Double) {
        if let heldTicket, !permits(heldTicket, now: now) { retireOutput() }
    }
    private func retireOutput() {
        guard heldTicket != nil else { return }
        heldTicket = nil; onOutputRetired?()
    }
}
