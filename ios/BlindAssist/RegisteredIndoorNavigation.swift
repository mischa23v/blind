import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
import BlindCore

/// Native persistence/output adapter for one atomically installed artifact.
/// Confine to the same main-thread owner as IndoorNavigator. There is deliberately
/// NO native capture issuer: ARKit normal tracking and heuristic heading confidence
/// do not supply the measured uncertainty required by SpatialLocalizationLease.
final class RegisteredIndoorNavigation {
    private let storage: URL
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
    init(storage: URL, sha256: @escaping SpatialMapSHA256 = platformSHA256) {
        self.storage = storage; self.sha256 = sha256
    }
    func restore() throws {
        guard installation == nil else { throw SpatialInstallationError.historyRewrite }
        let data = try Data(contentsOf: storage)
        let installation = try SpatialMapInstallation(data: data, sha256: sha256)
        retireOutput(); owner = nil; support = nil; dormantInstallation = installation
    }
    /// Policy must be explicitly supplied by the integration owner. No preset error
    /// bars or guessed pose/heading measurement are used to manufacture admission.
    func configure(body: BodyEnvelope, limits: SpatialLocalizationLimits) throws {
        guard owner == nil else { throw SpatialInstallationError.historyRewrite }
        guard let installation else { throw SpatialInstallationError.noInstalledMap }
        guard dormantRestrictionsDurable else { throw SpatialRouteError.unpersistedRestrictions }
        var next = try SpatialRouteOwner(body: body, limits: limits)
        try next.restore(installation.encoded(), sha256: sha256)
        retireOutput(); owner = next; dormantInstallation = nil; support = nil
    }
    func install(_ data: Data) throws {
        let candidate = try SpatialMapInstallation(data: data, sha256: sha256)
        if var next = owner {
            try next.install(candidate, persist: persist)
            retireOutput(); owner = next; dormantInstallation = nil
        } else {
            if let installation { try candidate.validateReplacement(of: installation) }
            try persist(candidate.encoded())
            retireOutput(); dormantInstallation = candidate
        }
        dormantRestrictionsDurable = true; support = nil
    }
    private func persist(_ data: Data) throws {
        var directory = storage.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try data.write(to: storage, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    /// Called only after a legacy raw-map write succeeds. Such geometry is preview
    /// content and must never inherit an older registered map's authority.
    func clearForLegacyImport() {
        retireOutput(); owner = nil; dormantInstallation = nil; support = nil; dormantRestrictionsDurable = true
    }
    func currentPose(now: Double) -> SpatialLocalizationCapture? { owner?.currentPose(now: now) }
    func accept(_ capture: SpatialLocalizationCapture, floorSupport: SpatialFloorSupport, now: Double) throws {
        guard var next = owner else { throw SpatialRegistryError.noCurrentPose }
        do {
            try next.accept(capture, now: now)
            owner = next; support = floorSupport
            revalidate(now: now)
        } catch {
            owner = next; support = nil; retireOutput(); throw error
        }
    }
    func plan(from: String, to: String, goal: UUID) throws {
        guard var next = owner else { throw SpatialRegistryError.noCurrentPose }
        next.setGoal(revision: goal)
        retireOutput()
        do { try next.plan(from: from, to: to, goal: goal); owner = next }
        catch { owner = next; throw error }
    }
    func blockNextLegAndReplan() throws {
        guard let owner, let installation, let goal = owner.goalRevision,
              owner.waypointIndex > 0, owner.waypointIndex < owner.route.count,
              let destination = owner.route.last?.id else { throw SpatialRouteError.noRoute }
        let from = owner.route[owner.waypointIndex - 1].id, to = owner.route[owner.waypointIndex].id
        try addRestrictions(binding: installation.binding, blocked: [MapConnection(from, to)], zones: [])
        try plan(from: from, to: destination, goal: goal)
    }
    func cancelRoute() { retireOutput(); owner?.cancelRoute() }
    func loseTracking() { retireOutput(); owner?.loseTracking(); support = nil }
    func setBody(_ body: BodyEnvelope) throws {
        guard var next = owner else { throw SpatialRegistryError.noCurrentPose }
        try next.setBody(body); owner = next; retireOutput()
    }
    func addRestrictions(binding: SpatialMapBinding, blocked: Set<MapConnection>, zones: [KeepOutZone]) throws {
        guard var next = owner else {
            guard let installation, binding == installation.binding else { throw SpatialRegistryError.invalidMap }
            let candidate = try installation.addingRestrictions(blocked: blocked, zones: zones)
            let bytes = try candidate.encoded()
            dormantInstallation = candidate; dormantRestrictionsDurable = false; retireOutput()
            try persist(bytes)
            dormantRestrictionsDurable = true; return
        }
        do { try next.addRestrictions(binding: binding, blocked: blocked, zones: zones, persist: persist) }
        catch { owner = next; retireOutput(); throw error }
        owner = next; retireOutput()
    }
    func confirmWaypoint() { retireOutput(); owner?.confirmWaypoint() }
    func next(now: Double) throws -> SpatialRouteTicket {
        do {
            guard let owner, let support else { throw SpatialRegistryError.noCurrentPose }
            let ticket = try owner.next(support: support, now: now)
            heldTicket = ticket; return ticket
        } catch { retireOutput(); throw error }
    }
    func permits(_ ticket: SpatialRouteTicket, now: Double) -> Bool { owner?.permits(ticket, now: now) == true }
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
