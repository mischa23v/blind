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
    private let storageOverride: URL?
    private var storage: URL {
        if let storageOverride { return storageOverride }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("IndoorRoutes/map.json")
    }
    init(storage: URL? = nil) {
        storageOverride = storage
        if let data = try? Data(contentsOf: self.storage), let map = try? JSONDecoder().decode(IndoorMap.self, from: data), (try? map.validate()) != nil {
            self.map = map; message = t("Loaded \(map.name). Choose your starting landmark.", "حُمّلت \(map.name). اختر نقطة البداية.")
        }
    }
    var exportURL: URL? { map == nil ? nil : storage }
    var isAligned: Bool { anchorWorld != nil && anchorMap != nil && alignedLevel != nil }
    func deleteMap() {
        do {
            if FileManager.default.fileExists(atPath: storage.path) { try FileManager.default.removeItem(at: storage) }
            map = nil; activePackage = nil; revision = UUID(); suggestedDestination = nil; blocked = []; invalidatePosition(); message = t("Route map deleted.", "حُذفت خريطة المسار.")
        } catch { message = t("Could not delete the route map.", "تعذر حذف خريطة المسار.") }
    }
    func load(_ data: Data) throws {
        guard data.count <= 2_000_000 else { throw MapError.invalid }
        let map = try JSONDecoder().decode(IndoorMap.self, from: data)
        try map.validate()
        var directory = storage.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true; try directory.setResourceValues(values)
        try data.write(to: storage, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        self.map = map; activePackage = nil; revision = UUID(); suggestedDestination = nil; blocked = []; invalidatePosition()
        message = t("Loaded \(map.name). Choose where you are and face the next landmark.", "حُمّلت \(map.name). اختر مكانك وتوجّه نحو المعلم التالي.")
    }
    func loadCommunity(_ package: PlacePackage) throws {
        try package.validate()
        guard package.localization == "manual-landmarks", var map = package.routeMap else { throw MapError.invalid }
        map.packageID = package.id; map.packageRevision = package.revision
        try load(JSONEncoder().encode(map))
        activePackage = package
        message = text("Loaded \(package.name), revision \(package.revision). Location is unknown; confirm the starting landmark and facing direction.", "تم تحميل \(package.name)، المراجعة \(package.revision). الموقع غير معروف؛ أكد معلم البداية واتجاهك.")
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
    func plan(from: String, to: String) throws {
        guard let map else { throw MapError.invalid }
        invalidatePosition()
        route = try map.route(from: from, to: to, blocked: blocked); waypointIndex = min(1, route.count)
        anchorWorld = nil; message = text("Confirm your starting landmark and face the next waypoint.", "أكد نقطة البداية واتجه نحو المعلم التالي.")
        if from == to { message = text("Starting landmark and destination are the same.", "نقطة البداية هي الوجهة نفسها.") }
    }
    func addKeepOutZone(landmarkID: String, halfSize: Double) throws {
        guard var updated = map, let node = updated.nodes.first(where: { $0.id == landmarkID }),
              halfSize.isFinite, halfSize >= 0.5, halfSize <= 10 else { throw MapError.invalid }
        let zone = KeepOutZone(id: UUID().uuidString, name: node.name, level: node.level,
                               minX: node.position.x - halfSize, maxX: node.position.x + halfSize,
                               minZ: node.position.z - halfSize, maxZ: node.position.z + halfSize,
                               nameArabic: node.nameArabic)
        updated.keepOutZones = (updated.keepOutZones ?? []) + [zone]
        updated.markLocalEdit()
        let package = activePackage
        try load(JSONEncoder().encode(updated))
        if let package, Self.matches(map: updated, package: package) { activePackage = package }
        message = text("Keep-out area saved. Plan and align again.", "حُفظت المنطقة المحظورة. أعد التخطيط والمحاذاة.")
    }
    func removeKeepOutZone(id: String) throws {
        guard var updated = map else { throw MapError.invalid }
        updated.keepOutZones = updated.keepOutZones?.filter { $0.id != id }
        updated.markLocalEdit()
        let package = activePackage
        try load(JSONEncoder().encode(updated))
        if let package, Self.matches(map: updated, package: package) { activePackage = package }
        message = text("Keep-out area removed. Plan and align again.", "حُذفت المنطقة المحظورة. أعد التخطيط والمحاذاة.")
    }
    func blockNextLeg() {
        guard waypointIndex > 0, waypointIndex < route.count, let destination = route.last?.id else { return }
        let from = route[waypointIndex - 1].id, to = route[waypointIndex].id
        blocked.insert(MapConnection(from, to))
        do { try plan(from: from, to: destination); message = text("Alternative route loaded. Confirm your position at the last known landmark before alignment.", "تم تحميل مسار بديل. أكد موقعك عند آخر معلم معروف قبل المحاذاة.") }
        catch { message = GuidanceText.noRoute(arabic: arabic) }
    }
    /// Manual two-point alignment: a known start and a known facing direction.
    /// It cannot infer venue position from imported geometry.
    func align(camera: Point3, forward: Point3) {
        anchorWorld = nil; anchorMap = nil; alignedLevel = nil; alignmentRevision = UUID()
        guard waypointIndex > 0, waypointIndex < route.count, camera.isFinite, forward.isFinite,
              abs(hypot(forward.x, forward.z) - 1) < 0.05 else { message = t("Choose a route, and start the camera, first.", "اختر مساراً وشغّل الكاميرا أولاً."); return }
        let previous = waypointIndex - 1, a = route[previous].position, b = route[waypointIndex].position
        let length = hypot(b.x - a.x, b.z - a.z)
        guard length > 0.01, route[previous].level == route[waypointIndex].level else {
            message = t("Start with two landmarks on the same floor.", "ابدأ بمعلمين على الطابق نفسه."); return
        }
        anchorWorld = camera; anchorMap = a; worldForward = forward
        alignedLevel = route[previous].level; alignmentRevision = UUID()
        mapForward = Point3((b.x - a.x) / length, 0, (b.z - a.z) / length)
        message = text("Position aligned manually. Reconfirm at each landmark.", "تم ضبط الموقع يدوياً. أكده عند كل معلم.")
    }
    func invalidatePosition() {
        if anchorWorld != nil || !route.isEmpty { alignmentRevision = UUID() }
        anchorWorld = nil; anchorMap = nil; worldForward = nil; mapForward = nil; alignedLevel = nil
        route = []; waypointIndex = 0
    }
    /// `bodyForward` is a separately established body heading in world coordinates (walking
    /// direction or a declared mount with its learned offset); otherwise a declared fixed mount
    /// uses the camera heading, and without either the body heading stays unknown.
    func situation(camera: Point3?, forward: Point3?, frameAge: Double, tracking: Bool, fixedBodyMount: Bool,
                   bodyForward: Point3? = nil) -> IndoorSituation? {
        guard let map else { return nil }
        var position: Point3?, direction: Point3?, bodyDirection: Point3?
        if tracking, frameAge.isFinite, (0...0.5).contains(frameAge),
           let camera, let forward, forward.isFinite, abs(hypot(forward.x, forward.z) - 1) < 0.01,
           worldForward != nil, mapForward != nil, anchorWorld != nil {
            position = mapPosition(camera: camera)
            direction = mapDirection(forward)
            if let bodyForward, bodyForward.isFinite, abs(hypot(bodyForward.x, bodyForward.z) - 1) < 0.01 {
                bodyDirection = mapDirection(bodyForward)
            }
        }
        return IndoorSituation(map: map, package: activePackage, revision: revision.uuidString,
            alignment: alignmentRevision.uuidString, level: alignedLevel, position: position, cameraForward: direction,
            bodyForward: bodyDirection ?? (fixedBodyMount ? direction : nil), age: frameAge)
    }
    /// A horizontal world direction expressed in the aligned map frame; nil without alignment.
    func mapDirection(_ forward: Point3) -> Point3? {
        guard forward.isFinite, let wf = worldForward, let mf = mapForward else { return nil }
        let along = forward.x * wf.x + forward.z * wf.z, side = -forward.x * wf.z + forward.z * wf.x
        return Point3(along * mf.x - side * mf.z, 0, along * mf.z + side * mf.x)
    }
    func mapPosition(camera: Point3) -> Point3? {
        guard camera.isFinite, let aw = anchorWorld, let am = anchorMap,
              let wf = worldForward, let mf = mapForward else { return nil }
        let dx = camera.x - aw.x, dz = camera.z - aw.z
        let along = dx * wf.x + dz * wf.z, side = -dx * wf.z + dz * wf.x
        return Point3(am.x + along * mf.x - side * mf.z, am.y, am.z + along * mf.z + side * mf.x)
    }
    func suggestDestination(id: String?) {
        suggestedDestination = map?.nodes.first { $0.id == id }
        if let node = suggestedDestination { message = text("Destination suggestion: \(node.name), level \(node.level). Confirm your start and destination before planning.", "الوجهة المقترحة: \(node.localizedName(arabic: true))، الطابق \(node.level). أكد البداية والوجهة قبل التخطيط.") }
        else { message = GuidanceText.noDestination(arabic: arabic) }
    }
    func next(camera: Point3, forward: Point3) -> (sector: Int, distance: Double, name: String)? {
        guard waypointIndex < route.count, let aw = anchorWorld, let am = anchorMap,
              let wf = worldForward, let mf = mapForward else { return nil }
        let target = route[waypointIndex]
        // Level changes require human confirmation; no automatic floor guessing.
        guard target.level == route[max(0, waypointIndex - 1)].level else {
            message = text("Level transition. Confirm the next landmark manually.", "انتقال بين الطوابق. أكد المعلم التالي يدوياً."); return nil
        }
        guard let current = mapPosition(camera: camera) else { return nil }
        if let zone = map?.restriction(from: current, to: target.position, level: target.level) {
            message = text("Direction paused: the line to the next landmark meets the marked keep-out area \(zone.name). Ask your helper to check your position and route.",
                           "تم إيقاف الاتجاه: الخط إلى المعلم التالي يمر بالمنطقة المحظورة \(zone.localizedName(arabic: true)). اطلب من المرافق التحقق من موقعك ومسارك.")
            return nil
        }
        let dx = target.position.x - am.x, dz = target.position.z - am.z
        let along = dx * mf.x + dz * mf.z, side = -dx * mf.z + dz * mf.x
        let targetWorld = Point3(aw.x + along * wf.x - side * wf.z, camera.y,
                                 aw.z + along * wf.z + side * wf.x)
        let vx = targetWorld.x - camera.x, vz = targetWorld.z - camera.z
        let distance = hypot(vx, vz)
        let ahead = vx * forward.x + vz * forward.z, right = -vx * forward.z + vz * forward.x
        let angle = atan2(right, ahead)
        let sector = (Int((angle / (.pi / 4)).rounded()) + 8) % 8
        message = text("\(target.name), approximately \(String(format: "%.1f", distance)) meters.", "\(target.localizedName(arabic: true))، على بعد نحو \(String(format: "%.1f", distance)) متر.")
        return (sector, distance, target.localizedName(arabic: arabic))
    }
    func confirmArrival() {
        guard waypointIndex < route.count else { return }
        waypointIndex += 1
        alignmentRevision = UUID(); alignedLevel = nil; worldForward = nil; mapForward = nil
        anchorWorld = nil; anchorMap = nil
        if waypointIndex >= route.count { message = text("Destination landmark confirmed.", "تم تأكيد الوصول إلى الوجهة.") }
        else { message = text("Next: \(route[waypointIndex].name). Face that landmark and align again.", "التالي: \(route[waypointIndex].localizedName(arabic: true)). اتجه نحو المعلم واضبط المحاذاة.") }
    }
}
