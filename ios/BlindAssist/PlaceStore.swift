import ARKit
import RoomPlan
import BlindCore
import BlindMemory
import Combine
import os
import CryptoKit
import simd

struct SavedPlace: Codable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var objects: [MappedObject]
    /// Coarse phone location when saved. Only narrows which saved maps to try; never proves a place.
    var latitude: Double? = nil
    var longitude: Double? = nil
    /// Nil for legacy scans. A place name/UUID alone never restores spatial coordinates.
    var worldFrame: SavedWorldFrame? = nil
}

final class PlaceStore: NSObject, RoomCaptureSessionDelegate, ObservableObject {
    @Published private(set) var places: [SavedPlace] = []
    @Published private(set) var message = ""
    @Published private(set) var scanning = false
    @Published private(set) var finishing = false
    /// Ephemeral RoomPlan observations for the sighted helper, never saved as a finished room.
    @Published private(set) var liveScanLayout: RoomLayout?
    @Published private(set) var needsDeletionCleanup = false
    // Independent room-import lane: one app-owned transfer/decode across view recreation.
    @MainActor private var referencePhotoImportLease: UUID?
    private var directory: URL
    private(set) var memory: MemoryStore?
    private var capture: RoomCaptureSession?
    private var name = ""
    private var comparison: SavedPlace?
    private var comparisonLocalized = false
    private var scanID = UUID()
    private var processing: Task<Void, Never>?
    private var worldFrameRecovery = SavedWorldFrameRecovery()
    private var diagnosticGeometryDeletionGeneration = UUID()
    private var diagnosticGeometryBlockedPlaces = Set<UUID>()
    @Published private(set) var registration: RoomRegistrationAcquisition?
    @Published private(set) var registrationStatus = ""
    @Published private(set) var registrationSaving = false
    @Published private(set) var registrationLoading = false
    @Published private(set) var registrationLoadNeedsRetry = false
    private var registrationCapture = RoomRegistrationCapture()
    private struct RegistrationBaseline: Sendable {
        let identifier: UUID
        let story: Int
        let features: [RoomRegistrationAcquisition.Feature]
    }
    private struct RegistrationBytes: Sendable {
        let frame: SavedWorldFrame
        let owner: UUID
        let data: Data
    }
    private static let maximumRegistrationRoomBytes = 8 * 1024 * 1024
    private var registrationBytes: RegistrationBytes?
    // A cancelled selection retires publication, not the physical utility task.
    // Keep this lease until completion so rapid rescan cannot fan out decoders.
    private var registrationPreparation: UUID?
    private var registrationBaseline: RegistrationBaseline?
    private var registrationSessionID: UUID?
    private var registrationRequestID = UUID()
    private var registrationSelectionPlaceID: UUID?
    private var registrationStoreOwner: UUID?

    var arabic = false
    private func t(_ english: String, _ arabic: String) -> String { self.arabic ? arabic : english }
    private var lastInstruction = ""
    private var lastInstructionTime = -Double.infinity
    var onScanFinished: (() -> Void)?
    /// Supplied by the app from on-device location; nil when location is off or unavailable.
    var currentCoordinate: (() -> (latitude: Double, longitude: Double)?)?
    var onMessage: ((String) -> Void)?
    override convenience init() {
        self.init(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Places", isDirectory: true))
    }
    /// The default app destination is unchanged; tests can exercise the actual
    /// source/deletion owner against an isolated protected local directory.
    init(directory: URL) {
        self.directory = directory
        super.init()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var storage = URLResourceValues(); storage.isExcludedFromBackup = true
            var protectedDirectory = directory
            try protectedDirectory.setResourceValues(storage)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
            do {
            let memoryDirectory = directory.deletingLastPathComponent().appendingPathComponent("AssistantMemory", isDirectory: true)
            try FileManager.default.createDirectory(at: memoryDirectory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: memoryDirectory.path)
            var memoryProtection = URLResourceValues(); memoryProtection.isExcludedFromBackup = true
            var protectedDirectory = memoryDirectory; try protectedDirectory.setResourceValues(memoryProtection)
            memory = try MemoryStore(path: memoryDirectory.appendingPathComponent("memory.sqlite").path)
            retryDeletionCleanup()
            } catch { message = t("Room memory is unavailable. Saved files are read-only.", "ذاكرة الغرف غير متاحة. الملفات المحفوظة للقراءة فقط.") }
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            places = files.filter { $0.pathExtension == "json" }.compactMap {
                guard let data = try? Data(contentsOf: $0) else { return nil }
                guard let place = try? JSONDecoder().decode(SavedPlace.self, from: data) else { return nil }
                if let memory, (try? memory.isDeleted(room: place.id.uuidString)) != false { return nil }
                return place
            }.sorted { $0.createdAt > $1.createdAt }
        } catch { message = t("Could not load saved places.", "تعذر تحميل الأماكن المحفوظة.") }
    }
    func startScan(session: ARSession, name: String, compare: SavedPlace? = nil, relocalized: Bool = false, registrationSessionID: UUID? = nil) {
        guard !scanning else { return }
        finishing = false
        liveScanLayout = nil
        guard compare == nil || relocalized else { message = t("Recognize the saved place before comparing.", "تعرّف على المكان المحفوظ قبل المقارنة."); return }
        self.name = name.isEmpty ? "My place" : name
        scanID = UUID()
        lastInstruction = ""; lastInstructionTime = -.infinity
        comparison = compare; comparisonLocalized = relocalized
        registrationCapture.invalidate(); registrationBaseline = nil
        self.registrationSessionID = registrationSessionID
        registrationRequestID = UUID(); registrationSelectionPlaceID = compare?.id
        registration = nil; registrationStoreOwner = memory?.writeOwner
        if let compare, let registrationSessionID,
           let descriptor = currentWorldFrame(sessionID: registrationSessionID), descriptor == compare.worldFrame {
            registrationCapture.begin(frame: descriptor, sessionID: registrationSessionID, scanID: scanID,
                                      now: ProcessInfo.processInfo.systemUptime)
            prepareRegistrationBaseline(frame: descriptor, sessionID: registrationSessionID)
        }

        let capture = RoomCaptureSession(arSession: session)
        capture.delegate = self; self.capture = capture; scanning = true
        message = arabic ? "حرّك الكاميرا ببطء لمسح الغرفة. رصد المخاطر بالهاتف متوقف أثناء المسح؛ ابدأ مع شخص يساعدك." : "Slowly scan the room, then finish. Phone hazard monitoring is paused during scanning; begin with a helper."
        onMessage?(message)
        capture.run(configuration: RoomCaptureSession.Configuration())
    }
    /// Preparation reuses bytes already hash-verified by saved-world recovery.
    /// No new disk read/unarchive/decode is performed on the scan owner.
    private func prepareRegistrationBaseline(frame: SavedWorldFrame, sessionID: UUID) {
        guard registrationPreparation == nil else {
            registrationStatus = t("Previous scan preparation is finishing. Cancel and retry this comparison shortly.", "جارٍ إنهاء تجهيز المسح السابق. ألغِ المقارنة وأعد المحاولة بعد قليل."); return
        }
        guard let bytes = registrationBytes, bytes.frame == frame,
              bytes.owner == memory?.writeOwner, !bytes.data.isEmpty,
              bytes.data.count <= Self.maximumRegistrationRoomBytes else {
            registrationStatus = t("Verified saved scan measurements are unavailable. Recognize this saved place again before comparing.", "قياسات المسح المحفوظ المتحقق منها غير متاحة. تعرّف على المكان المحفوظ مجددًا قبل المقارنة."); return
        }
        let lease = UUID(), request = registrationRequestID, scan = scanID, owner = bytes.owner
        registrationPreparation = lease
        registrationStatus = t("Preparing original scan measurements for helper review.", "جارٍ تجهيز قياسات المسح الأصلي لمراجعتها مع المساعد.")
        Task { @MainActor [weak self] in
            let baseline = await Task.detached(priority: .utility) { () -> RegistrationBaseline? in
                guard let room = try? JSONDecoder().decode(CapturedRoom.self, from: bytes.data),
                      let features = RoomLayoutAdapter.registrationFeatures(room) else { return nil }
                return RegistrationBaseline(identifier: room.identifier, story: room.story, features: features)
            }.value
            guard let self, self.registrationPreparation == lease else { return }
            self.registrationPreparation = nil
            guard self.registrationRequestID == request, self.scanID == scan,
                  self.scanning, !self.finishing, self.registrationSessionID == sessionID,
                  self.memory?.writeOwner == owner, self.registrationBytes?.frame == frame,
                  self.registrationBytes?.owner == owner, self.comparison?.worldFrame == frame,
                  self.places.contains(where: { $0.id.uuidString == frame.placeID && $0.worldFrame == frame }) else { return }
            self.registrationBaseline = baseline
            self.registrationStatus = baseline == nil
                ? self.t("Saved scan measurements could not be decoded within the supported bounds.", "تعذر قراءة قياسات المسح المحفوظ ضمن الحدود المدعومة.")
                : self.t("Collecting comparison measurements for helper review, not verifying location.", "جمع قياسات المقارنة لمراجعتها مع المساعد، وليس للتحقق من الموقع.")
        }
    }
    func finishScan() {
        guard scanning, !finishing else { return }
        finishing = true
        message = arabic ? "جارٍ حفظ المسح. انتظر قليلاً." : "Processing the scan. Please wait."
        capture?.stop(pauseARSession: false)
    }
    func cancelScan() {
        scanID = UUID(); processing?.cancel(); processing = nil
        registrationCapture.invalidate(); registrationBaseline = nil; registrationSessionID = nil
        capture?.delegate = nil; capture?.stop(pauseARSession: false)
        liveScanLayout = nil
        capture = nil; scanning = false; finishing = false; message = arabic ? "أُلغي المسح." : "Scan cancelled."
    }
    /// User-facing cancellation restores monitoring through the same completion callback.
    /// Background/shutdown cancellation deliberately does not restart camera work.
    func cancelScanAndResume() {
        guard scanning else { return }
        cancelScan()
        onScanFinished?()
    }
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.captureSession(session, didUpdate: room) }
            return
        }
        guard capture === session, scanning, !finishing else { return }
        let layout = RoomLayoutAdapter.layout(room, name: name)
        // Empty/invalid observations are not fabricated geometry or a saved-room replacement.
        guard (try? layout.validate()) != nil else { return }
        liveScanLayout = layout
    }
    /// Raw scanning frame hook. It copies bounded metadata only; no disk/model work.
    func observeRegistrationFrame(_ frame: ARFrame, sessionID: UUID, now: Double) {
        guard scanning, comparison != nil, registrationCapture.frame != nil else { return }
        let normal: Bool
        if case .normal = frame.camera.trackingState { normal = true } else { normal = false }
        let m = frame.camera.transform
        registrationCapture.observe(sessionID: sessionID, scanID: scanID, capturedAt: frame.timestamp,
            cameraToWorld: (0..<4).flatMap { c in (0..<4).map { r in Double(m[c][r]) } },
            trackingNormal: normal, now: now)
    }
    func selectRegistrationPairs(_ pairs: [RoomRegistrationAcquisition.Correspondence], acquisitionID: UUID) -> Bool {
        guard !registrationSaving, registrationStoreOwner == memory?.writeOwner, var current = registration,
              current.select(pairs, acquisitionID: acquisitionID) else {
            registrationStatus = t("The selection changed or the correspondence is invalid. Reopen the measurement record.", "تغير الاختيار أو المطابقة غير صالحة. أعد فتح سجل القياسات."); return false
        }
        registration = current; return true
    }
    /// One bounded explicit helper write. No implicit success and no automatic retry.
    @MainActor func saveRegistration(acquisitionID: UUID) async -> Bool {
        guard !registrationSaving, !registrationLoading else { return false }
        guard let value = registration, value.id == acquisitionID, value.valid,
              let memory, registrationStoreOwner == memory.writeOwner,
              places.contains(where: { $0.id.uuidString == value.frame.placeID && $0.worldFrame == value.frame }) else {
            registrationStatus = t("The measurement or memory context changed. Reopen the record before saving.", "تغير سجل القياسات أو مخزن الذاكرة. أعد فتح السجل قبل الحفظ."); return false
        }
        let owner = memory.writeOwner, request = registrationRequestID
        registrationSaving = true
        defer { registrationSaving = false }
        do {
            try await Task.detached(priority: .utility) {
                let data = try JSONEncoder().encode(value)
                try memory.saveRoomRegistration(room: value.frame.placeID, payload: data)
            }.value
            guard self.memory?.writeOwner == owner, registrationRequestID == request,
                  registration?.id == acquisitionID,
                  places.contains(where: { $0.id.uuidString == value.frame.placeID && $0.worldFrame == value.frame }) else {
                return false
            }
            registrationStatus = t("Measurement record saved locally. It does not verify current location or object identity.", "حُفظ سجل القياسات على الهاتف. لا يتحقق من الموقع الحالي أو هوية الغرض.")
            return true
        } catch {
            guard self.memory?.writeOwner == owner, registrationRequestID == request,
                  registration?.id == acquisitionID,
                  places.contains(where: { $0.id.uuidString == value.frame.placeID && $0.worldFrame == value.frame }) else { return false }
            registrationStatus = t("Measurements were not saved. Keep this screen open and try again.", "لم تُحفظ القياسات. أبقِ هذه الشاشة مفتوحة وحاول مجدداً.")
            return false
        }
    }
    @MainActor func loadRegistration(for place: SavedPlace) async {
        // Selecting B retires publication from a held A read/write immediately.
        let request = UUID(); registrationRequestID = request
        registrationSelectionPlaceID = place.id
        guard !registrationSaving, !registrationLoading, let memory else {
            registrationLoadNeedsRetry = true
            registrationStatus = t("Measurements for this selection are not loaded. Retry when the current operation finishes.", "لم تُحمّل قياسات هذا الاختيار. أعد المحاولة بعد انتهاء العملية الحالية.")
            return
        }
        registrationLoadNeedsRetry = false; registrationLoading = true
        registrationStatus = t("Loading measurements for this selection.", "تحميل قياسات هذا الاختيار.")
        defer { registrationLoading = false }
        let owner = memory.writeOwner
        let targetID = place.id.uuidString, targetFrame = place.worldFrame
        let value = await Task.detached(priority: .utility) { () -> RoomRegistrationAcquisition? in
            guard let data = try? memory.value(namespace: "places", id: "registration:" + targetID),
                  let decoded = try? JSONDecoder().decode(RoomRegistrationAcquisition.self, from: data), decoded.valid,
                  decoded.frame == targetFrame else { return nil }
            return decoded
        }.value
        guard registrationRequestID == request, self.memory?.writeOwner == owner,
              places.contains(where: { $0.id == place.id && $0.worldFrame == place.worldFrame }) else { return }
        // Prefer an unsaved newly acquired record over old saved measurements.
        if registration?.frame != place.worldFrame || registrationStoreOwner != owner {
            registration = value; registrationStoreOwner = owner
        }
        registrationStatus = registration == nil
            ? t("No saved measurement record for this selection.", "لا يوجد سجل قياسات محفوظ لهذا الاختيار.")
            : t("Measurement record available for this selection. It does not verify current location.", "سجل القياسات متاح لهذا الاختيار. لا يتحقق من الموقع الحالي.")
    }

    func worldMap(for place: SavedPlace) throws -> ARWorldMap {
        try worldMapArtifacts(for: place).map
    }
    private func worldMapArtifacts(for place: SavedPlace) throws -> (map: ARWorldMap, room: Data, descriptor: SavedWorldFrame?) {
        guard let memory, try !memory.isDeleted(room: place.id.uuidString) else { throw MemoryError.missing }
        let data = try Data(contentsOf: directory.appendingPathComponent("\(place.id).worldmap"))
        guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        // Legacy scans remain available for preview/semantic recognition. They do not
        // acquire a coordinate binding retroactively from matching names or filenames.
        guard let descriptor = place.worldFrame else { return (map, Data(), nil) }
        let room = try Data(contentsOf: directory.appendingPathComponent("\(place.id).room.json"))
        guard descriptor.placeID == place.id.uuidString,
              descriptor.matches(worldMapSHA256: Self.sha256(data), roomCaptureSHA256: Self.sha256(room)),
              map.anchors.contains(where: { Self.matchesOrigin($0, descriptor: descriptor) }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return (map, room, descriptor)
    }
    /// Call for the exact new session whose configuration receives the returned map.
    /// The caller must invalidate this state on camera stop/restart, tracking loss,
    /// backgrounding or map replacement. Legacy maps return without a usable binding.
    func beginWorldMapRecovery(for place: SavedPlace, sessionID: UUID,
                               now: Double = ProcessInfo.processInfo.systemUptime) throws -> ARWorldMap {
        invalidateWorldMapRecovery()
        let artifacts = try worldMapArtifacts(for: place)
        if let descriptor = artifacts.descriptor {
            if let owner = memory?.writeOwner, !artifacts.room.isEmpty,
               artifacts.room.count <= Self.maximumRegistrationRoomBytes {
                registrationBytes = RegistrationBytes(frame: descriptor, owner: owner, data: artifacts.room)
            }
            worldFrameRecovery.begin(frame: descriptor, sessionID: sessionID, now: now)
        }
        return artifacts.map
    }
    func invalidateWorldMapRecovery() {
        worldFrameRecovery.reset()
        registrationBytes = nil
        registrationBaseline = nil
        registrationRequestID = UUID()
        registrationCapture.invalidate()
    }
    /// Observes ARKit's own relocalizing -> normal transition and the restored named
    /// anchor. No appearance match, user room-name answer or imported map can call this
    /// a restored coordinate frame. A returned frame does not authorize physical speech.
    @discardableResult func observeWorldMapRecovery(for place: SavedPlace, frame: ARFrame,
        sessionID: UUID, now: Double = ProcessInfo.processInfo.systemUptime) -> SavedWorldFrame? {
        guard let descriptor = place.worldFrame else { return nil }
        let tracking: SavedWorldFrameRecovery.Tracking
        switch frame.camera.trackingState {
        case .normal: tracking = .normal
        case .limited(.relocalizing): tracking = .relocalizing
        default: tracking = .unavailable
        }
        let recovered = worldFrameRecovery.observe(sessionID: sessionID, tracking: tracking,
            mappingAvailable: frame.worldMappingStatus == .mapped || frame.worldMappingStatus == .extending,
            originAnchorMatches: frame.anchors.contains { Self.matchesOrigin($0, descriptor: descriptor) },
            frameTime: frame.timestamp, now: now)
        return recovered == descriptor ? recovered : nil
    }
    func currentWorldFrame(sessionID: UUID, now: Double = ProcessInfo.processInfo.systemUptime) -> SavedWorldFrame? {
        worldFrameRecovery.current(sessionID: sessionID, now: now)
    }
    /// Constant-work native loss observation before the normal camera throttle.
    /// Never inspect anchors or authorize a new association on this path.
    func observeWorldMapTrackingInterruption(frame: ARFrame, sessionID: UUID,
        now: Double = ProcessInfo.processInfo.systemUptime) {
        let tracking: SavedWorldFrameRecovery.Tracking
        switch frame.camera.trackingState {
        case .normal: return
        case .limited(.relocalizing): tracking = .relocalizing
        default: tracking = .unavailable
        }
        worldFrameRecovery.observeTrackingInterruption(sessionID: sessionID, tracking: tracking,
            frameTime: frame.timestamp, now: now)
    }
    /// Diagnostic seam only: SAME saved-frame camera coordinates, uncertainty
    /// unmeasured. No imported-map transform, body/support evidence or guidance.
    func cameraWorldFrameAssociation(sessionID: UUID, capturedAt: Double,
        now: Double = ProcessInfo.processInfo.systemUptime) -> SavedWorldFrameCameraAssociation? {
        worldFrameRecovery.cameraAssociation(sessionID: sessionID, capturedAt: capturedAt, now: now)
    }
    /// Read-only request preparation; byte reads, hashes and CapturedRoom decoding
    /// belong to the diagnostic provider's bounded utility worker, never a frame.
    @MainActor func diagnosticGeometrySource(for frame: SavedWorldFrame) -> SavedRoomDiagnosticGeometrySource? {
        guard frame.valid, let memory, let id = UUID(uuidString: frame.placeID),
              !diagnosticGeometryBlockedPlaces.contains(id),
              places.contains(where: { $0.id == id && $0.worldFrame == frame }) else { return nil }
        return .init(frame: frame, url: directory.appendingPathComponent("\(id).room.json"), memory: memory,
            memoryOwner: memory.writeOwner, deletionGeneration: diagnosticGeometryDeletionGeneration)
    }
    @MainActor func ownsDiagnosticGeometrySource(_ source: SavedRoomDiagnosticGeometrySource) -> Bool {
        guard let memory, memory === source.memory, memory.writeOwner == source.memoryOwner,
              diagnosticGeometryDeletionGeneration == source.deletionGeneration,
              let id = UUID(uuidString: source.frame.placeID), !diagnosticGeometryBlockedPlaces.contains(id)
        else { return false }
        return places.contains { $0.id == id && $0.worldFrame == source.frame }
    }
    /// User deletion admission can precede asynchronous history erasure. Block new
    /// geometry reads immediately and keep them blocked if that erasure fails.
    func retireDiagnosticGeometry(for place: SavedPlace) {
        if diagnosticGeometryBlockedPlaces.insert(place.id).inserted { diagnosticGeometryDeletionGeneration = UUID() }
    }
    /// Original, hash-bound scan measurements only. They are dated map history, not
    /// live detections and never ownership/personal-item identity. Do not recompute
    /// this disk read on every camera frame; callers may cache by descriptor.revision.
    func measuredFurnitureHistory(for place: SavedPlace) throws -> [SavedFurnitureObservation] {
        let artifacts = try worldMapArtifacts(for: place)
        guard let descriptor = artifacts.descriptor else { return [] }
        let room = try JSONDecoder().decode(CapturedRoom.self, from: artifacts.room)
        return room.objects.compactMap { object in
            let p = object.transform.columns.3
            return SavedFurnitureObservation(id: object.identifier.uuidString,
                category: String(describing: object.category),
                position: Point3(Double(p.x), Double(p.y), Double(p.z)), frame: descriptor)
        }
    }
    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private static func matchesOrigin(_ anchor: ARAnchor, descriptor: SavedWorldFrame) -> Bool {
        guard anchor.identifier.uuidString == descriptor.originAnchorID,
              anchor.name == descriptor.originAnchorName else { return false }
        // The marker was created at identity in the saved world. If setWorldOrigin
        // changes the basis, do not apply old coordinates as if nothing changed.
        for column in 0..<4 {
            for row in 0..<4 {
                let value = anchor.transform[column][row]
                guard value.isFinite, abs(value - (column == row ? 1 : 0)) <= 0.0001 else { return false }
            }
        }
        return true
    }
    func retireRegistration(for place: SavedPlace) {
        // Retire helper publication at admission even if durable erasure fails.
        // Failure can leave private disk bytes, never an eligible late measurement.
        let selected = registrationSelectionPlaceID ?? comparison?.id
            ?? registration.flatMap { UUID(uuidString: $0.frame.placeID) }
        if selected == place.id {
            registrationRequestID = UUID(); registrationSelectionPlaceID = nil
            registration = nil; registrationStoreOwner = nil
        }
        // Loaded A may remain while a newly selected B is loading. Erase A's
        // bytes without touching B's independent request, owner or status.
        if registration?.frame.placeID == place.id.uuidString { registration = nil }
        if registrationBytes?.frame.placeID == place.id.uuidString || comparison?.id == place.id {
            registrationBaseline = nil; registrationBytes = nil; registrationCapture.invalidate()
        }
    }
    func delete(_ place: SavedPlace) {
        // Retire geometry at deletion admission, even if durable erasure fails.
        retireDiagnosticGeometry(for: place)
        retireRegistration(for: place)
        do {
            guard let memory else { throw MemoryError.missing }
            try memory.deleteRoom(place.id.uuidString)
            // Physical recovery is invalidated, but an unrelated helper selection B
            // retains its own request receipt and may finish loading normally.
            worldFrameRecovery.reset()
            if registration?.frame.placeID == place.id.uuidString { registration = nil; registrationStoreOwner = nil }
            places.removeAll { $0.id == place.id }
            diagnosticGeometryBlockedPlaces.remove(place.id)
            retryDeletionCleanup()
        } catch { message = t("Deleting the place did not finish. Some private files may remain; try again.", "لم يكتمل حذف المكان. قد تبقى بعض الملفات الخاصة؛ أعد المحاولة.") }
    }
    func retryDeletionCleanup() {
        do {
            guard let memory else { throw MemoryError.missing }
            for id in try memory.deletedRooms() {
                guard let uuid = UUID(uuidString: id) else { throw MemoryError.invalid }
                for ext in ["worldmap", "room.json", "usdz", "layout.json", "svg", "photo.jpg", "photo-trash.jpg", "json"] {
                    let url = directory.appendingPathComponent("\(uuid).\(ext)")
                    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                }
            }
            needsDeletionCleanup = false
        } catch {
            needsDeletionCleanup = true
            message = t("Deleted rooms are blocked, but some private files remain. Try cleanup again later.", "الغرف المحذوفة محجوبة، لكن بعض الملفات الخاصة باقية. أعد التنظيف لاحقاً.")
        }
    }
    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        // Scan state is owned by the main thread; the delegate may call from elsewhere.
        guard Thread.isMainThread else { DispatchQueue.main.async { self.captureSession(session, didEndWith: data, error: error) }; return }
        guard capture === session, scanning else { return }
        let id = scanID, savedName = name, baseline = comparison, localized = comparisonLocalized
        // Capture immutable original evidence before asynchronous RoomBuilder work.
        let measurementSession = registrationSessionID
        let measurementFrame = registrationCapture.frame
        let measurementStart = registrationCapture.startedAt
        let measurement = measurementSession.flatMap { registrationCapture.sample(sessionID: $0, scanID: scanID, now: ProcessInfo.processInfo.systemUptime) }
        let measurementDate = Date(), baselineRoom = registrationBaseline
        let measurementRequest = registrationRequestID

        processing = Task { @MainActor in
            defer { if scanID == id { scanning = false; finishing = false; liveScanLayout = nil; capture = nil; processing = nil; onScanFinished?() } }
            do {
                if let error { throw error }
                let room = try await RoomBuilder(options: [.beautifyObjects]).capturedRoom(from: data)
                try Task.checkCancellation(); guard scanID == id else { return }
                let objects = room.objects.map { object in
                    let center = object.transform.columns.3
                    return MappedObject(id: object.identifier.uuidString, category: String(describing: object.category),
                                        center: Point3(Double(center.x), Double(center.y), Double(center.z)))
                }
                if let baseline {
                    if registrationRequestID == measurementRequest, memory?.writeOwner == registrationStoreOwner,
                       places.contains(where: { $0.id == baseline.id && $0.worldFrame == baseline.worldFrame }),
                       let measurementSession, let measurementFrame, let measurementStart, let measurement,
                       let baselineRoom, measurementFrame == baseline.worldFrame,
                       let newFeatures = RoomLayoutAdapter.registrationFeatures(room),
                       let acquired = RoomRegistrationAcquisition(frame: measurementFrame,
                          sessionID: measurementSession, scanID: id,
                          baselineRoomID: baselineRoom.identifier, measuredRoomID: room.identifier,
                          startedAt: measurementStart, capturedAt: measurement.capturedAt,
                          recordedAt: measurementDate, cameraToWorld: measurement.cameraToWorld,
                          baseline: baselineRoom.features, measured: newFeatures,
                          baselineStory: baselineRoom.story, measuredStory: room.story) {
                        registration = acquired
                        registrationStatus = t("Measurements collected. A helper must select corresponding physical features; no room or object identity is established.", "جُمعت القياسات. يجب أن يختار المساعد المعالم المادية المتقابلة؛ لم يتم التحقق من هوية الغرفة أو الغرض.")
                    } else if registrationRequestID == measurementRequest {
                        registrationStatus = t("No registration record: tracking, source ownership, timing or bounded measurements were unavailable.", "لا يوجد سجل مطابقة: التتبع أو مصدر القياسات أو توقيتها غير متاح.")
                    }
                    let changes = PlaceComparison.changes(baseline: baseline.objects, current: objects,
                                                         relocalized: localized)
                    let arabic = self.arabic
                    let name = { (category: String) in
                        RoomFeature(id: "", kind: "object", category: category, confidence: "", corners: []).name(arabic: arabic)
                    }
                    message = changes.isEmpty ? (arabic ? "لم أجد تغييرات مؤكدة." : "No confidently matched changes found.") : changes.map { change in
                        switch change {
                        case let .moved(category, distance):
                            let metres = String(format: "%.1f", distance)
                            return arabic ? "ربما تحرّك \(name(category)) بمقدار \(metres) متر." : "\(category) may have moved \(metres) meters."
                        case let .added(category): return arabic ? "رُصد \(name(category)) جديد." : "Newly observed \(category)."
                        case let .notObserved(category):
                            return arabic ? "لم يُرصد \(name(category)) المحفوظ سابقاً في هذا المسح." : "Previously mapped \(category) was not observed in this scan."
                        }
                    }.joined(separator: " ")
                    onMessage?(message); return
                }
                let map: ARWorldMap = try await withCheckedThrowingContinuation { continuation in
                    session.arSession.getCurrentWorldMap { map, error in
                        if let error { continuation.resume(throwing: error) }
                        else if let map { continuation.resume(returning: map) }
                        else { continuation.resume(throwing: CocoaError(.fileReadUnknown)) }
                    }
                }
                try Task.checkCancellation(); guard scanID == id else { return }
                let coordinate = self.currentCoordinate?()
                var place = SavedPlace(id: UUID(), name: savedName, createdAt: Date(), objects: objects,
                                       latitude: coordinate?.latitude, longitude: coordinate?.longitude)
                let prefix = directory.appendingPathComponent(place.id.uuidString)
                // RoomCaptureSession uses this exact ARSession, and stop(false)
                // preserves its origin. Apple's RoomPlan MultiRoom documentation
                // establishes the shared coordinate basis; no fitted SLAM transform.
                // ARWorldMap.anchors is explicitly mutable before archiving:
                // https://developer.apple.com/documentation/arkit/arworldmap/anchors
                let revision = UUID().uuidString
                let anchor = ARAnchor(name: "blind-assist-world-origin:\(revision)", transform: matrix_identity_float4x4)
                map.anchors.append(anchor)
                let roomData = try JSONEncoder().encode(room)
                let mapData = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                place.worldFrame = SavedWorldFrame(placeID: place.id.uuidString, revision: revision,
                    worldMapSHA256: Self.sha256(mapData), roomCaptureSHA256: Self.sha256(roomData),
                    originAnchorID: anchor.identifier.uuidString, capturedAt: place.createdAt)
                try mapData.write(to: prefix.appendingPathExtension("worldmap"), options: .atomic)
                try roomData.write(to: prefix.appendingPathExtension("room.json"), options: .atomic)
                try room.export(to: prefix.appendingPathExtension("usdz"), exportOptions: .parametric)
                let layout = RoomLayoutAdapter.layout(room, name: place.name)
                try saveLayout(layout, for: place)
                // Commit metadata last so incomplete scans never appear as saved places.
                try JSONEncoder().encode(place).write(to: prefix.appendingPathExtension("json"), options: .atomic)
                places.insert(place, at: 0)
                message = arabic ? "حُفظت \(place.name). راجع الأبواب والأثاث في مخطط الغرفة." : "Saved \(place.name). Review the doors and furniture in the room map."
                onMessage?(message)
            } catch is CancellationError {} catch {
                if scanID == id { message = t("The room scan failed. Try again with a helper.", "فشل مسح الغرفة. أعد المحاولة مع مساعد."); onMessage?(message) }
            }
        }
    }
    func captureSession(_ session: RoomCaptureSession, didProvide instruction: RoomCaptureSession.Instruction) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.capture === session, self.scanning else { return }
            let english: String, translated: String
            switch instruction {
            case .slowDown: english = "Move the camera more slowly."; translated = "حرّك الكاميرا ببطء أكثر."
            case .turnOnLight: english = "The room needs more light."; translated = "تحتاج الغرفة إلى إضاءة أكثر."
            case .lowTexture: english = "Point the camera toward a door frame or furniture for more detail."; translated = "وجّه الكاميرا نحو إطار باب أو قطعة أثاث لالتقاط تفاصيل أوضح."
            case .moveCloseToWall: english = "The wall is too far from the camera. Ask your helper to adjust the scanning position."; translated = "الجدار بعيد عن الكاميرا. اطلب من مساعدك ضبط مكان المسح."
            case .moveAwayFromWall: english = "The camera is too close to the wall. Ask your helper to adjust its position."; translated = "الكاميرا قريبة جداً من الجدار. اطلب من مساعدك ضبط موضعها."
            case .normal: return
            @unknown default: return
            }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastInstructionTime >= 6, english != self.lastInstruction || now - self.lastInstructionTime >= 15 else { return }
            self.lastInstruction = english; self.lastInstructionTime = now
            self.message = self.arabic ? translated : english; self.onMessage?(self.message)
        }
    }
    func fileURL(for place: SavedPlace, extension ext: String) -> URL? {
        if ext == "layout.json" || ext == "svg", let memory {
            do {
                guard let current = try memory.current(room: place.id.uuidString) else { return nil }
                let layout = try decoded(current)
                let data = ext == "svg" ? try Data(layout.svg().utf8) : try JSONEncoder().encode(layout)
                let url = directory.appendingPathComponent("\(place.id).\(ext)")
                if (try? Data(contentsOf: url)) != data {
                    try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                }
                return url
            } catch { return nil } // Never offer a stale export after a committed revision.
        }
        let url = directory.appendingPathComponent("\(place.id).\(ext)")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    func layout(for place: SavedPlace) -> RoomLayout? {
        let timing = AssistantPerformance.signposter.beginInterval("RoomMemoryRead", id: AssistantPerformance.signposter.makeSignpostID())
        defer { AssistantPerformance.signposter.endInterval("RoomMemoryRead", timing) }
        if let memory {
            do {
                guard try !memory.isDeleted(room: place.id.uuidString) else { return nil }
                if let revision = try memory.current(room: place.id.uuidString) { return try decoded(revision) }
            } catch { message = t("Room memory could not be read.", "تعذرت قراءة ذاكرة الغرفة."); return nil }
        }
        let legacyURL = directory.appendingPathComponent("\(place.id).layout.json")
        if let data = try? Data(contentsOf: legacyURL),
           let layout = try? JSONDecoder().decode(RoomLayout.self, from: data), (try? layout.validate()) != nil {
            guard let memory else { return layout } // Read-only legacy access when memory is unavailable.
            do { return try decoded(memory.importRoom(room: place.id.uuidString, payload: data)) }
            catch { message = t("Room import failed. The original files were kept.", "فشل استيراد الغرفة. بقيت الملفات الأصلية."); return nil }
        }
        if let url = fileURL(for: place, extension: "room.json"), let data = try? Data(contentsOf: url),
           let room = try? JSONDecoder().decode(CapturedRoom.self, from: data) {
            let layout = RoomLayoutAdapter.layout(room, name: place.name)
            return try? saveLayout(layout, for: place)
        }
        return nil
    }
    private func decoded(_ revision: RoomRevision) throws -> RoomLayout {
        var layout = try JSONDecoder().decode(RoomLayout.self, from: revision.payload)
        try layout.validate(); layout.revisionID = revision.id; return layout
    }
    func proposeLayout(_ layout: RoomLayout, for place: SavedPlace, source: String) throws -> RoomProposal {
        try layout.validate()
        guard let memory, let base = layout.revisionID else { throw MemoryError.missing }
        guard let stored = try memory.current(room: place.id.uuidString), stored.id == base else { throw MemoryError.conflict }
        let original = try decoded(stored)
        guard original.name == layout.name, original.features.count == layout.features.count,
              zip(original.features, layout.features).allSatisfy({ a, b in
                  a.id == b.id && a.kind == b.kind && a.category == b.category && a.confidence == b.confidence && a.corners == b.corners
              }) else { throw MemoryError.invalid }
        return try memory.propose(room: place.id.uuidString, baseRevision: base, payload: JSONEncoder().encode(layout), source: source)
    }
    func approveLayout(_ proposal: RoomProposal, for place: SavedPlace) throws -> RoomLayout {
        let timing = AssistantPerformance.signposter.beginInterval("RoomApproval", id: AssistantPerformance.signposter.makeSignpostID())
        defer { AssistantPerformance.signposter.endInterval("RoomApproval", timing) }
        guard let memory, proposal.room == place.id.uuidString else { throw MemoryError.invalid }
        let layout = try decoded(memory.approve(room: place.id.uuidString, proposalID: proposal.id))
        refreshExports(layout, for: place); objectWillChange.send(); return layout
    }
    func rejectLayout(_ proposal: RoomProposal, for place: SavedPlace) throws {
        guard let memory, proposal.room == place.id.uuidString else { throw MemoryError.invalid }
        try memory.reject(room: place.id.uuidString, proposalID: proposal.id)
    }
    func layoutHistory(for place: SavedPlace) throws -> [RoomLayout] {
        guard let memory else { throw MemoryError.missing }
        return try memory.history(room: place.id.uuidString).map(decoded)
    }
    @discardableResult func saveLayout(_ layout: RoomLayout, for place: SavedPlace) throws -> RoomLayout {
        try layout.validate()
        guard let memory else { throw MemoryError.missing }
        if layout.revisionID == nil {
            guard try memory.current(room: place.id.uuidString) == nil else { throw MemoryError.conflict }
            let imported = try decoded(memory.importRoom(room: place.id.uuidString, payload: JSONEncoder().encode(layout), source: "scan"))
            refreshExports(imported, for: place); objectWillChange.send(); return imported
        }
        // Called only by an explicit manual Save action. AI edits use review below.
        return try approveLayout(proposeLayout(layout, for: place, source: "user"), for: place)
    }
    private func refreshExports(_ layout: RoomLayout, for place: SavedPlace) {
        // SQLite is authoritative. Export-cache failure must not undo or conceal a committed approval.
        let prefix = directory.appendingPathComponent(place.id.uuidString)
        do {
            try JSONEncoder().encode(layout).write(to: prefix.appendingPathExtension("layout.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try Data(layout.svg().utf8).write(to: prefix.appendingPathExtension("svg"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { message = t("The room was saved; its export could not be refreshed.", "حُفظت الغرفة؛ تعذر تحديث ملف التصدير.") }
    }
    /// Claim synchronously on MainActor before starting any transfer. Cancellation
    /// retires publication, not native work: release only when that worker returns.
    @MainActor func beginReferencePhotoImport() -> UUID? {
        guard referencePhotoImportLease == nil else { return nil }
        let lease = UUID(); referencePhotoImportLease = lease
        return lease
    }
    @MainActor func finishReferencePhotoImport(_ lease: UUID) {
        if referencePhotoImportLease == lease { referencePhotoImportLease = nil }
    }
    /// One recoverable reference-photo slot per room, in the existing protected,
    /// backup-excluded directory. Moves never overwrite an occupied destination.
    /// These operations do not alter room geometry, recall fingerprints or Photos.
    @MainActor func trashPhoto(for place: SavedPlace) throws {
        try moveReferencePhoto(for: place, source: "photo.jpg", destination: "photo-trash.jpg")
    }
    @MainActor func restorePhoto(for place: SavedPlace) throws {
        try moveReferencePhoto(for: place, source: "photo-trash.jpg", destination: "photo.jpg")
    }
    @MainActor private func moveReferencePhoto(for place: SavedPlace, source: String, destination: String) throws {
        guard places.contains(where: { $0.id == place.id }) else { throw CocoaError(.fileNoSuchFile) }
        let from = directory.appendingPathComponent("\(place.id).\(source)")
        let to = directory.appendingPathComponent("\(place.id).\(destination)")
        guard !FileManager.default.fileExists(atPath: to.path) else { throw CocoaError(.fileWriteFileExists) }
        // Same-directory rename keeps file protection and avoids duplicate image copies.
        try FileManager.default.moveItem(at: from, to: to)
        objectWillChange.send()
    }
    /// Call only after the explicit permanent-delete confirmation in RoomDetailView.
    @MainActor func deleteTrashedPhoto(for place: SavedPlace) throws {
        guard places.contains(where: { $0.id == place.id }) else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.removeItem(at: directory.appendingPathComponent("\(place.id).photo-trash.jpg"))
        objectWillChange.send()
    }
    func savePhoto(_ jpeg: Data, for place: SavedPlace) throws {
        guard jpeg.count <= 2_000_000, places.contains(where: { $0.id == place.id }) else { throw CocoaError(.fileWriteUnknown) }
        try jpeg.write(to: directory.appendingPathComponent("\(place.id).photo.jpg"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        objectWillChange.send()
    }
}
