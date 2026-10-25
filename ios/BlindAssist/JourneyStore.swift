import Foundation
import Combine
import BlindCore

final class JourneyStore: ObservableObject {
    @Published private(set) var saved: [Journey] = []
    @Published private(set) var distance = 0.0
    @Published private(set) var message = ""
    private let connectedIO: (any ConnectedJourneyRuntimeIO)?
    private let journeySHA256: SpatialMapSHA256
    private lazy var connected = MainActor.assumeIsolated {
        ConnectedJourneyRuntime(io: connectedIO ?? FoundationJourneyRuntimeIO(url: directory.appendingPathComponent("connected-state.json")),
            sha256: journeySHA256)
    }
    func withConnectedJourney<T>(_ operation: @MainActor (ConnectedJourneyRuntime) throws -> T) rethrows -> T {
        try MainActor.assumeIsolated { try operation(connected) }
    }
    private var recorder: JourneyRecorder?
    private var directory: URL
    var current: Journey? { recorder?.journey }
    init(connectedIO: (any ConnectedJourneyRuntimeIO)? = nil, journeySHA256: @escaping SpatialMapSHA256 = RegisteredIndoorNavigation.platformSHA256) {
        self.connectedIO = connectedIO; self.journeySHA256 = journeySHA256
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Journeys", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
            saved = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" && $0.lastPathComponent != "connected-state.json" }.compactMap {
                    guard let data = try? Data(contentsOf: $0) else { return nil }
                    return try? JSONDecoder().decode(Journey.self, from: data)
                }.sorted { $0.createdAt > $1.createdAt }
        } catch { message = "Journey storage unavailable." }
        withConnectedJourney { runtime in
            runtime.onChange = { [weak self] in self?.objectWillChange.send() }
            runtime.restore()
        }
    }
    var connectedEraseReceipt: JourneyEraseReceipt? { withConnectedJourney { $0.eraseReceipt } }
    var connectedSaveFailed: Bool { withConnectedJourney { $0.storageError } }
    func connectedPersistenceMessage(arabic: Bool) -> String {
        withConnectedJourney { runtime in
            if runtime.storageError, runtime.eraseReceipt?.state == .succeeded {
                return arabic ? "لم تُحفظ تغييرات الرحلة الجديدة. الحذف السابق مكتمل." : "New journey changes were not saved. The earlier erasure is complete."
            }
            if let receipt = runtime.eraseReceipt {
                switch receipt.state {
                case .pending: return arabic ? "جارٍ مسح سجل الرحلة. لم يكتمل الحذف بعد." : "Erasing journey history. Deletion is not complete yet."
                case .failed: return arabic ? "تعذر مسح سجل الرحلة. ما زالت البيانات القديمة على الهاتف. أعد محاولة الحذف." : "Journey history could not be erased. Old data remains on this phone. Retry erasure."
                case .succeeded: return arabic ? "مُسح سجل الرحلة من هذا الهاتف." : "Journey history erased on this phone."
                }
            }
            if runtime.storageError { return arabic ? "لم تُحفظ تغييرات الرحلة. الإرشاد متوقف حتى إعادة الحفظ." : "Journey changes were not saved. Guidance is paused until saving succeeds." }
            if runtime.loading { return arabic ? "جارٍ فتح سجل الرحلة. الموقع الحالي غير معروف." : "Opening journey history. Current location is unknown." }
            if !runtime.durable { return arabic ? "جارٍ حفظ تغييرات الرحلة." : "Saving journey changes." }
            return arabic ? "سجل الرحلة محفوظ على الهاتف. يلزم تحديد الموقع الحالي من جديد للإرشاد." : "Journey history is retained on this phone. Guidance requires fresh current location."
        }
    }
    func retryConnectedErase(_ id: UUID) {
        do { try withConnectedJourney { try $0.retryErase(id) } }
        catch { message = "That erasure request is no longer current. Check journey status." }
    }
    func retryConnectedSave() {
        do { try withConnectedJourney { try $0.retryPersistence() } }
        catch { message = "Journey changes could not be saved. Please retry." }
    }

    func begin() { withConnectedJourney { $0.cameraRestarted() }; finish(); recorder = JourneyRecorder(); distance = 0 }
    func observe(_ observation: Observation) {
        recorder?.observe(camera: observation.camera, time: observation.timestamp, tracking: observation.trackingNormal)
        if let recorder { distance = recorder.distance }
    }
    func breakTracking() { withConnectedJourney { $0.cameraRestarted() }; recorder?.breakTracking() }
    func finish() {
        withConnectedJourney { $0.cameraRestarted() }
        guard let recorder else { return }
        self.recorder = nil
        guard !recorder.journey.points.isEmpty else { return }
        do {
            try JSONEncoder().encode(recorder.journey).write(to: url(for: recorder.journey), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            saved.insert(recorder.journey, at: 0); message = "Journey saved on this phone."
        } catch { message = "Journey could not be saved." }
    }
    func url(for journey: Journey) -> URL { directory.appendingPathComponent("\(journey.id).json") }
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
    func delete(_ journey: Journey) {
        #if DEBUG
        purgeDebugSessionDiagnostics()
        #endif
        do { try FileManager.default.removeItem(at: url(for: journey)); saved.removeAll { $0.id == journey.id } }
        catch { message = "Journey could not be deleted." }
    }
}
