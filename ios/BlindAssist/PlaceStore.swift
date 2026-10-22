import ARKit
import RoomPlan
import BlindCore
import BlindMemory
import Combine
import os

struct SavedPlace: Codable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var objects: [MappedObject]
    /// Coarse phone location when saved. Only narrows which saved maps to try; never proves a place.
    var latitude: Double? = nil
    var longitude: Double? = nil
}

final class PlaceStore: NSObject, RoomCaptureSessionDelegate, ObservableObject {
    @Published private(set) var places: [SavedPlace] = []
    @Published private(set) var message = ""
    @Published private(set) var scanning = false
    @Published private(set) var finishing = false
    @Published private(set) var needsDeletionCleanup = false
    private var directory: URL
    private(set) var memory: MemoryStore?
    private var capture: RoomCaptureSession?
    private var name = ""
    private var comparison: SavedPlace?
    private var comparisonLocalized = false
    private var scanID = UUID()
    private var processing: Task<Void, Never>?
    var arabic = false
    private func t(_ english: String, _ arabic: String) -> String { self.arabic ? arabic : english }
    private var lastInstruction = ""
    private var lastInstructionTime = -Double.infinity
    var onScanFinished: (() -> Void)?
    /// Supplied by the app from on-device location; nil when location is off or unavailable.
    var currentCoordinate: (() -> (latitude: Double, longitude: Double)?)?
    var onMessage: ((String) -> Void)?
    override init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Places", isDirectory: true)
        super.init()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var storage = URLResourceValues(); storage.isExcludedFromBackup = true
            try directory.setResourceValues(storage)
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
    func startScan(session: ARSession, name: String, compare: SavedPlace? = nil, relocalized: Bool = false) {
        guard !scanning else { return }
        finishing = false
        guard compare == nil || relocalized else { message = t("Recognize the saved place before comparing.", "تعرّف على المكان المحفوظ قبل المقارنة."); return }
        self.name = name.isEmpty ? "My place" : name
        scanID = UUID()
        lastInstruction = ""; lastInstructionTime = -.infinity
        comparison = compare; comparisonLocalized = relocalized
        let capture = RoomCaptureSession(arSession: session)
        capture.delegate = self; self.capture = capture; scanning = true
        message = arabic ? "حرّك الكاميرا ببطء لمسح الغرفة. رصد المخاطر بالهاتف متوقف أثناء المسح؛ ابدأ مع شخص يساعدك." : "Slowly scan the room, then finish. Phone hazard monitoring is paused during scanning; begin with a helper."
        onMessage?(message)
        capture.run(configuration: RoomCaptureSession.Configuration())
    }
    func finishScan() {
        guard scanning, !finishing else { return }
        finishing = true
        message = arabic ? "جارٍ حفظ المسح. انتظر قليلاً." : "Processing the scan. Please wait."
        capture?.stop(pauseARSession: false)
    }
    func cancelScan() {
        scanID = UUID(); processing?.cancel(); processing = nil
        capture?.delegate = nil; capture?.stop(pauseARSession: false)
        capture = nil; scanning = false; finishing = false; message = arabic ? "أُلغي المسح." : "Scan cancelled."
    }
    func worldMap(for place: SavedPlace) throws -> ARWorldMap {
        guard let memory, try !memory.isDeleted(room: place.id.uuidString) else { throw MemoryError.missing }
        let data = try Data(contentsOf: directory.appendingPathComponent("\(place.id).worldmap"))
        guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return map
    }
    func delete(_ place: SavedPlace) {
        do {
            guard let memory else { throw MemoryError.missing }
            try memory.deleteRoom(place.id.uuidString)
            places.removeAll { $0.id == place.id }
            retryDeletionCleanup()
        } catch { message = t("Deleting the place did not finish. Some private files may remain; try again.", "لم يكتمل حذف المكان. قد تبقى بعض الملفات الخاصة؛ أعد المحاولة.") }
    }
    func retryDeletionCleanup() {
        do {
            guard let memory else { throw MemoryError.missing }
            for id in try memory.deletedRooms() {
                guard let uuid = UUID(uuidString: id) else { throw MemoryError.invalid }
                for ext in ["worldmap", "room.json", "usdz", "layout.json", "svg", "photo.jpg", "json"] {
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
        processing = Task { @MainActor in
            defer { if scanID == id { scanning = false; finishing = false; capture = nil; processing = nil; onScanFinished?() } }
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
                    let changes = PlaceComparison.changes(baseline: baseline.objects, current: objects,
                                                         relocalized: localized)
                    message = changes.isEmpty ? "No confidently matched changes found." : changes.map { change in
                        switch change {
                        case let .moved(category, distance): return "\(category) may have moved \(String(format: "%.1f", distance)) meters."
                        case let .added(category): return "Newly observed \(category)."
                        case let .notObserved(category): return "Previously mapped \(category) was not observed in this scan."
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
                let place = SavedPlace(id: UUID(), name: savedName, createdAt: Date(), objects: objects,
                                       latitude: coordinate?.latitude, longitude: coordinate?.longitude)
                let prefix = directory.appendingPathComponent(place.id.uuidString)
                let mapData = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                try mapData.write(to: prefix.appendingPathExtension("worldmap"), options: .atomic)
                try JSONEncoder().encode(room).write(to: prefix.appendingPathExtension("room.json"), options: .atomic)
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
    func savePhoto(_ jpeg: Data, for place: SavedPlace) throws {
        guard jpeg.count <= 2_000_000, places.contains(where: { $0.id == place.id }) else { throw CocoaError(.fileWriteUnknown) }
        try jpeg.write(to: directory.appendingPathComponent("\(place.id).photo.jpg"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        objectWillChange.send()
    }
}
