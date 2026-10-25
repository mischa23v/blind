import Foundation
import Combine
import BlindCore

final class IndoorNavigator: ObservableObject {
    var arabic = false
    private func t(_ english: String, _ arabic: String) -> String { self.arabic ? arabic : english }
    private func text(_ english: String, _ translated: String) -> String { arabic ? translated : english }
    @Published private(set) var map: IndoorMap?
    @Published private(set) var route: [MapNode] = []
    @Published private(set) var message = "Import an authored indoor route map."
    @Published private(set) var waypointIndex = 0
    @Published private(set) var suggestedDestination: MapNode?
    private(set) var revision = UUID()
    private(set) var alignmentRevision = UUID()
    private(set) var activePackage: PlacePackage?
    private var alignedLevel: String?
    private var anchorWorld: Point3?
    private var anchorMap: Point3?
    private var mapForward: Point3?
    private var worldForward: Point3?
    private var blocked = Set<MapConnection>()
    private var registered: RegisteredIndoorNavigation?
    var onSpatialOutputRetired: (() -> Void)?
    var clearObservationHistory: ((@escaping (Bool) -> Void) -> Void)?
    /// Selected storage target only, never coordinate alignment or current-location evidence.
    var registeredObservationMapTarget: SpatialMapBinding? { registered?.installation?.binding }
    private var registeredCueCaption: String?
    private func bindRegisteredOutputRetirement() {
        registered?.onOutputRetired = { [weak self] in
            guard let self else { return }
            // The visible/accessibility caption must not outlive its route cue.
            if let caption = self.registeredCueCaption, self.message == caption {
                self.message = self.t("Previous route cue withdrawn. Request fresh guidance.",
                                      "سُحب إرشاد المسار السابق. اطلب إرشاداً حديثاً.")
            }
            self.registeredCueCaption = nil
            self.onSpatialOutputRetired?()
        }
    }
    private let storageOverride: URL?
    private var storage: URL {
        if let storageOverride { return storageOverride }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("IndoorRoutes/map.json")
    }
    init(storage: URL? = nil) {
        storageOverride = storage
        let registered = RegisteredIndoorNavigation(storage: self.storage)
        self.registered = registered
        bindRegisteredOutputRetirement()
        if (try? registered.restore()) != nil, let installed = registered.installation {
            self.map = installed.map
            message = t("Registered map loaded. Live position is unknown.", "حُمّلت الخريطة المسجلة. الموقع الحالي غير معروف.")
            return
        }
        if let data = try? Data(contentsOf: self.storage), let map = try? JSONDecoder().decode(IndoorMap.self, from: data), (try? map.validate()) != nil {
            self.map = map; message = t("Loaded \(map.name) for preview. Live position is unknown.", "حُمّلت \(map.name) للمعاينة. الموقع الحالي غير معروف.")
        }
    }
    var exportURL: URL? { map == nil ? nil : storage }
    var isAligned: Bool { registered?.currentPose(now: ProcessInfo.processInfo.systemUptime) != nil }
    /// Alignment can outlive a task; it does not authorize route announcements.
    var hasActiveRoute: Bool { waypointIndex >= 0 && waypointIndex < route.count }
    #if DEBUG
    private var debugPurgePending = false
    private var debugLastPurgeSucceeded: Bool?
    private func purgeDebugSessionDiagnostics() {
        guard !debugPurgePending else { return }
        debugPurgePending = true
        DebugSessionLog.purgeForPrivacyClear { [weak self] success in
            DispatchQueue.main.async { [weak self] in
                self?.debugPurgePending = false
                self?.debugLastPurgeSucceeded = success
                DebugNativeSessionTrace.reportPurgeResult(success)
            }
        }
    }
    #endif
    func deleteMap() {
        #if DEBUG
        purgeDebugSessionDiagnostics()
        #endif
        invalidatePosition()
        let expectedRevision = revision
        if let clearObservationHistory {
            clearObservationHistory { [weak self] success in
                guard let self else { return }
                guard self.revision == expectedRevision else { return }
                guard success else { self.message = self.t("Observed geometry history could not be deleted. Please retry.", "لم يكتمل حذف سجل هندسة المشاهدات. أعد المحاولة."); return }
                self.deleteMapFiles()
            }
        } else { deleteMapFiles() }
    }
    private func deleteMapFiles() {
        do {
            if FileManager.default.fileExists(atPath: storage.path) { try FileManager.default.removeItem(at: storage) }
            registered?.clearForLegacyImport()
            map = nil; activePackage = nil; revision = UUID(); suggestedDestination = nil; blocked = []; invalidatePosition(); message = t("Route map deleted.", "حُذفت خريطة المسار.")
        } catch { message = t("Could not delete the route map.", "تعذر حذف خريطة المسار.") }
    }
    /// The existing JSON import UI accepts a registered atomic envelope or a
    /// legacy preview graph. A malformed envelope is never downgraded to a graph.
    func loadImportedMap(_ data: Data) throws {
        guard !data.isEmpty, data.count <= SpatialMapInstallation.maximumEnvelopeBytes,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw MapError.invalid }
        if object["mapBytes"] != nil || object["snapshot"] != nil || object["artifactHistory"] != nil {
            try loadRegisteredInstallation(data)
        } else { try load(data) }
    }
    func load(_ data: Data) throws {
        guard data.count <= 2_000_000 else { throw MapError.invalid }
        let map = try JSONDecoder().decode(IndoorMap.self, from: data)
        try map.validate()
        var directory = storage.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true; try directory.setResourceValues(values)
        try data.write(to: storage, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        registered?.clearForLegacyImport()
        self.map = map; activePackage = nil; revision = UUID(); suggestedDestination = nil; blocked = []; invalidatePosition()
        message = t("Loaded \(map.name) for preview only. Live guidance is unavailable.", "حُمّلت \(map.name) للمعاينة فقط. الإرشاد الحالي غير متاح.")
    }
    func loadCommunity(_ package: PlacePackage) throws {
        try package.validate()
        guard package.localization == "manual-landmarks", var map = package.routeMap else { throw MapError.invalid }
        map.packageID = package.id; map.packageRevision = package.revision
        try load(JSONEncoder().encode(map))
        activePackage = package
        message = text("Loaded \(package.name), revision \(package.revision). Preview only; current location and facing direction are unknown.", "تم تحميل \(package.name)، المراجعة \(package.revision). للمعاينة فقط؛ الموقع الحالي والاتجاه غير معروفين.")
    }
    /// Restore metadata only from an immutable installed package matching the loaded graph.
    /// No route or pose is restored by this operation, and no network request is made.
    @MainActor func restoreCommunityContext(storage: CommunityPackageStorage = CommunityPackageStorage()) async {
        guard let map, let packageID = map.packageID, let packageRevision = map.packageRevision else { return }
        let expected = revision
        do {
            let inventory = try await storage.list()
            guard revision == expected,
                  let package = inventory.installed.first(where: { $0.package.id == packageID && $0.package.revision == packageRevision })?.package,
                  Self.matches(map: map, package: package) else { return }
            activePackage = package; revision = UUID(); invalidatePosition()
        } catch { message = text("Route metadata could not be restored. Location remains unconfirmed.", "تعذر استعادة معلومات المسار. يبقى الموقع غير مؤكد.") }
    }
    static func matches(map: IndoorMap, package: PlacePackage) -> Bool {
        guard map.packageID == package.id, map.packageRevision == package.revision,
              (try? package.validate()) != nil, var source = package.routeMap else { return false }
        var loaded = map
        // Keep-out additions do not change the original room geometry. They keep their
        // own private-copy marker and invalidate routes independently.
        stripCopyMetadata(&loaded); stripCopyMetadata(&source)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let a = try? encoder.encode(loaded), let b = try? encoder.encode(source) else { return false }
        return a == b
    }
    private static func stripCopyMetadata(_ map: inout IndoorMap) {
        map.packageID = nil; map.packageRevision = nil; map.packageModified = nil; map.keepOutZones = nil
    }
    func plan(from: String, to: String, goalRevision: UUID = UUID()) throws {
        guard let map else { throw MapError.invalid }
        if let registered, registered.configured {
            do { try registered.plan(from: from, to: to, goal: goalRevision) }
            catch {
                route = registered.route; waypointIndex = registered.waypointIndex
                message = GuidanceText.noRoute(arabic: arabic); throw error
            }
            route = registered.route; waypointIndex = registered.waypointIndex
            message = t("Route planned. Current measured localization is still required.", "خُطط المسار. يلزم تحديد الموقع بقياسات حالية.")
            return
        }
        invalidatePosition()
        route = try map.route(from: from, to: to, blocked: blocked); waypointIndex = min(1, route.count)
        anchorWorld = nil; message = text("Route preview only. Current location and direction are unverified.", "معاينة المسار فقط. الموقع الحالي والاتجاه غير متحقق منهما.")
        if from == to { message = text("Preview start and destination are the same.", "بداية المعاينة والوجهة هما النقطة نفسها.") }
    }
    func addKeepOutZone(landmarkID: String, halfSize: Double) throws {
        guard var updated = map, let node = updated.nodes.first(where: { $0.id == landmarkID }),
              halfSize.isFinite, halfSize >= 0.5, halfSize <= 10 else { throw MapError.invalid }
        let zone = KeepOutZone(id: UUID().uuidString, name: node.name, level: node.level,
                               minX: node.position.x - halfSize, maxX: node.position.x + halfSize,
                               minZ: node.position.z - halfSize, maxZ: node.position.z + halfSize,
                               nameArabic: node.nameArabic)
        if let registered, let installation = registered.installation {
            do { try registered.addRestrictions(binding: installation.binding, blocked: [], zones: [zone]) }
            catch {
                route = registered.route; waypointIndex = registered.waypointIndex
                message = t("Restriction could not be saved. Registered guidance is unavailable until it is saved.",
                            "تعذر حفظ المنطقة المحظورة. الإرشاد المسجل غير متاح حتى تُحفظ.")
                throw error
            }
            route = registered.route; waypointIndex = registered.waypointIndex
            message = t("Conservative restriction saved. Current physical clearance remains unknown.",
                        "حُفظت المنطقة المحظورة احتياطياً. خلو الطريق الفعلي الحالي غير معروف.")
            return
        }
        updated.keepOutZones = (updated.keepOutZones ?? []) + [zone]
        updated.markLocalEdit()
        let package = activePackage
        try load(JSONEncoder().encode(updated))
        if let package, Self.matches(map: updated, package: package) { activePackage = package }
        message = text("Keep-out area saved in the preview. Live guidance is unavailable.", "حُفظت المنطقة المحظورة في المعاينة. الإرشاد الحالي غير متاح.")
    }
    var canRemoveStoredKeepOutZones: Bool { registered?.installation == nil }
    var storedKeepOutZones: [KeepOutZone] {
        (map?.keepOutZones ?? []) + (registered?.installation?.currentRestrictions.zones ?? [])
    }
    func removeKeepOutZone(id: String) throws {
        // Reopening requires a fresh source-owned observed-clearance protocol.
        // Never erase the registered envelope or downgrade it to a legacy graph.
        guard registered?.installation == nil else { throw SpatialInstallationError.historyRewrite }
        guard var updated = map else { throw MapError.invalid }
        updated.keepOutZones = updated.keepOutZones?.filter { $0.id != id }
        updated.markLocalEdit()
        let package = activePackage
        try load(JSONEncoder().encode(updated))
        if let package, Self.matches(map: updated, package: package) { activePackage = package }
        message = text("Keep-out area removed from the preview. This does not prove current clearance.", "حُذفت المنطقة المحظورة من المعاينة. هذا لا يثبت خلو الطريق الحالي.")
    }
    func blockNextLeg() {
        if let registered, registered.configured {
            do { try registered.blockNextLegAndReplan() }
            catch { message = GuidanceText.noRoute(arabic: arabic) }
            route = registered.route; waypointIndex = registered.waypointIndex
            return
        }
        guard waypointIndex > 0, waypointIndex < route.count, let destination = route.last?.id else { return }
        let from = route[waypointIndex - 1].id, to = route[waypointIndex].id
        blocked.insert(MapConnection(from, to))
        do { try plan(from: from, to: destination); message = text("Alternative route preview loaded. Live position remains unknown.", "حُمّلت معاينة مسار بديل. يبقى الموقع الحالي غير معروف.") }
        catch { message = GuidanceText.noRoute(arabic: arabic) }
    }
    /// Manual two-point alignment: a known start and a known facing direction.
    /// It cannot infer venue position from imported geometry.
    func align(camera: Point3, forward: Point3) {
        anchorWorld = nil; anchorMap = nil; alignedLevel = nil; alignmentRevision = UUID()
        guard waypointIndex > 0, waypointIndex < route.count, camera.isFinite, forward.isFinite,
              abs(hypot(forward.x, forward.z) - 1) < 0.05 else { message = t("Choose a route preview and a tracked camera input first. This does not establish location.", "اختر معاينة مسار وبيانات كاميرا متتبعة أولاً. هذا لا يثبت الموقع."); return }
        let previous = waypointIndex - 1, a = route[previous].position, b = route[waypointIndex].position
        let length = hypot(b.x - a.x, b.z - a.z)
        guard length > 0.01, route[previous].level == route[waypointIndex].level else {
            message = t("Preview alignment requires two authored landmarks on the same floor.", "تحتاج محاذاة المعاينة إلى معلمين موصوفين على الطابق نفسه."); return
        }
        anchorWorld = camera; anchorMap = a; worldForward = forward
        alignedLevel = route[previous].level; alignmentRevision = UUID()
        mapForward = Point3((b.x - a.x) / length, 0, (b.z - a.z) / length)
        message = text("Preview alignment set. Live location remains unverified.", "ضُبطت محاذاة المعاينة. الموقع الحالي غير متحقق منه.")
    }
    /// A conversation/task change retires the route, not the measured map frame.
    /// Callers cancel pending route speech first. Existing capture/pose freshness
    /// checks still govern every use of the retained alignment; this is not arrival.
    func cancelRoute() {
        registered?.cancelRoute()
        route = []; waypointIndex = 0; suggestedDestination = nil
        message = text("No active route.", "لا يوجد مسار نشط.")
    }
    /// Tracking loss, camera restart or a changed map invalidate geometry as well.
    func invalidatePosition() {
        registered?.loseTracking()
        if anchorWorld != nil || !route.isEmpty { alignmentRevision = UUID() }
        anchorWorld = nil; anchorMap = nil; worldForward = nil; mapForward = nil; alignedLevel = nil
        cancelRoute()
    }
    /// `bodyForward` is a separately established body heading in world coordinates (walking
    /// direction or a declared mount with its learned offset); otherwise a declared fixed mount
    /// uses the camera heading, and without either the body heading stays unknown.
    func situation(camera: Point3?, forward: Point3?, frameAge: Double, tracking: Bool, fixedBodyMount: Bool,
                   bodyForward: Point3? = nil) -> IndoorSituation? {
        guard let map else { return nil }
        // This legacy snapshot API has no exact capture/map association for its raw
        // world-space arguments. Keep semantics/layout, never publish manual pose.
        // Registered consumers must use the typed capture below; camera orientation
        // cannot be guessed from body heading or a saved map.
        return IndoorSituation(map: map, package: activePackage, revision: revision.uuidString,
            alignment: alignmentRevision.uuidString, level: nil, position: nil, cameraForward: nil,
            bodyForward: nil, age: frameAge)
    }
    /// A native issuer must capture this session before beginning asynchronous work.
    var registeredSessionID: UUID? { registered?.sessionID }
    func currentRegisteredPose(now: Double) -> SpatialLocalizationCapture? { registered?.currentPose(now: now) }
    /// Raw world-space arguments cannot be re-labelled into the registered map.
    func mapDirection(_ forward: Point3) -> Point3? { nil }
    func mapPosition(camera: Point3) -> Point3? { nil }
    /// A horizontal world direction expressed in the aligned map frame; nil without alignment.
    private func previewMapDirection(_ forward: Point3) -> Point3? {
        guard forward.isFinite, let wf = worldForward, let mf = mapForward else { return nil }
        let along = forward.x * wf.x + forward.z * wf.z, side = -forward.x * wf.z + forward.z * wf.x
        return Point3(along * mf.x - side * mf.z, 0, along * mf.z + side * mf.x)
    }
    private func previewMapPosition(camera: Point3) -> Point3? {
        guard camera.isFinite, let aw = anchorWorld, let am = anchorMap,
              let wf = worldForward, let mf = mapForward else { return nil }
        let dx = camera.x - aw.x, dz = camera.z - aw.z
        let along = dx * wf.x + dz * wf.z, side = -dx * wf.z + dz * wf.x
        return Point3(am.x + along * mf.x - side * mf.z, am.y, am.z + along * mf.z + side * mf.x)
    }
    func suggestDestination(id: String?) {
        suggestedDestination = map?.nodes.first { $0.id == id }
        if let node = suggestedDestination { message = text("Destination suggestion: \(node.name), level \(node.level). Select a preview start and destination; this does not establish current location.", "الوجهة المقترحة: \(node.localizedName(arabic: true))، الطابق \(node.level). اختر بداية المعاينة والوجهة؛ هذا لا يثبت الموقع الحالي.") }
        else { message = GuidanceText.noDestination(arabic: arabic) }
    }
    /// Legacy manual alignment remains a preview. It cannot bypass measured-pose,
    /// support-height and current-leg collision checks to produce physical output.
    func next(camera: Point3, forward: Point3) -> (sector: Int, distance: Double, name: String, ticket: SpatialRouteTicket)? {
        guard hasActiveRoute, let registered else { return nil }
        do {
            let ticket = try registered.next(now: ProcessInfo.processInfo.systemUptime)
            guard let cue = ticket.directionalCue() else { throw SpatialRouteError.ambiguousDirection }
            let sector = cue.sector, distance = cue.distance
            message = text("\(ticket.target.name), approximately \(String(format: "%.1f", distance)) meters.",
                           "\(ticket.target.localizedName(arabic: true))، على بعد نحو \(String(format: "%.1f", distance)) متر.")
            registeredCueCaption = message
            return (sector, distance, ticket.target.localizedName(arabic: arabic), ticket)
        } catch {
            message = t("Map guidance is unavailable without current measured position, body heading and floor support.",
                        "إرشاد الخريطة غير متاح دون قياسات حالية للموقع واتجاه الجسم ودعم الأرضية.")
            return nil
        }
    }
    func permitsSpatialOutput(_ ticket: SpatialRouteTicket, now: Double) -> Bool {
        registered?.permits(ticket, now: now) == true
    }
    func revalidateSpatialOutput(now: Double) { registered?.revalidate(now: now) }
    func loadRegisteredInstallation(_ data: Data) throws {
        guard let registered else { throw SpatialInstallationError.noInstalledMap }
        try registered.install(data)
        activePackage = nil; revision = UUID(); suggestedDestination = nil; blocked = []
        invalidatePosition()
        map = registered.installation?.map
        message = t("Registered map installed. Live position is unknown.", "ثُبتت الخريطة المسجلة. الموقع الحالي غير معروف.")
    }
    func configureRegisteredNavigation(body: BodyEnvelope, limits: SpatialLocalizationLimits) throws {
        guard let registered else { throw SpatialInstallationError.noInstalledMap }
        try registered.configure(body: body, limits: limits)
    }
    /// No production caller is supplied yet: do not synthesize uncertainty values
    /// from tracking == normal, a room label, or BodyHeading.confidence.
    func acceptRegisteredCapture(_ capture: SpatialLocalizationCapture, support: SpatialFloorSupport, now: Double) throws {
        guard let registered else { throw SpatialRegistryError.noCurrentPose }
        try registered.accept(capture, floorSupport: support, now: now)
    }
    func confirmArrival() {
        if let registered, registered.configured {
            registered.confirmWaypoint(); route = registered.route; waypointIndex = registered.waypointIndex
            message = t("Route progress updated. Physical arrival is not inferred; current measured position is still required.",
                        "حُدّث تقدم المسار. لا يُستنتج الوصول الفعلي؛ ما زالت قياسات الموقع الحالية مطلوبة.")
            return
        }
        guard waypointIndex < route.count else { return }
        waypointIndex += 1
        alignmentRevision = UUID(); alignedLevel = nil; worldForward = nil; mapForward = nil
        anchorWorld = nil; anchorMap = nil
        if waypointIndex >= route.count { message = text("Preview destination marked. Physical arrival is unverified.", "عُلّمت وجهة المعاينة. الوصول الفعلي غير متحقق منه.") }
        else { message = text("Next preview landmark: \(route[waypointIndex].name). No live direction is established.", "معلم المعاينة التالي: \(route[waypointIndex].localizedName(arabic: true)). لم يُثبت اتجاه حالي.") }
    }
}
