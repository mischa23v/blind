import Foundation
import ARKit
import Combine
#if DEBUG
import BlindCore
#endif
#if BLIND_RTABMAP
import GLKit
#endif

/// Native integration uses RTAB-Map's existing iOS frame/coordinate adapter.
/// A mapped database is NOT treated as proof of current indoor localization.
final class NativeMapping: ObservableObject {
    @Published private(set) var status = "Native RTAB-Map build required for growing 3D maps."
    @Published private(set) var active = false
    @Published private(set) var exportURL: URL?
    var available: Bool {
        #if BLIND_RTABMAP
        return true
        #else
        return false
        #endif
    }
    private var storage: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MobilityMaps", isDirectory: true)
    }
    init() { refreshExport() }
    private func refreshExport() {
        let url = storage.appendingPathComponent("personal.db")
        exportURL = !active && FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
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
        guard !active else { return }
        let expectedRevision = mapLifecycleRevision
        if let clearObservationHistory {
            clearObservationHistory { [weak self] success in
                guard let self else { return }
                // Check ownership before success OR failure can affect a newer map/UI.
                guard !self.active, self.mapLifecycleRevision == expectedRevision else { return }
                guard success else { self.status = "Observed geometry history could not be deleted. Please retry."; return }
                self.deleteMapFiles()
            }
        } else { deleteMapFiles() }
    }
    private func deleteMapFiles() {
        do {
            for name in ["personal.db", "personal.db-wal", "personal.db-shm"] {
                let url = storage.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            }
            refreshExport(); status = "Private 3D map deleted."
        } catch { status = "Could not delete the private map." }
    }
    var clearObservationHistory: ((@escaping (Bool) -> Void) -> Void)?
    private var mapLifecycleRevision = UUID()
    private var lastFrame = -Double.infinity
    #if BLIND_RTABMAP
    private var engine: RTABMap?
    private var context: EAGLContext?
    private var renderer: GLKView?
    private var database: URL?
    #endif
    func start() {
        mapLifecycleRevision = UUID()
        #if BLIND_RTABMAP
        guard !active else { return }
        do {
            var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("MobilityMaps", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
            let database = directory.appendingPathComponent("personal.db")
            guard let context = EAGLContext(api: .openGLES2) else { throw CocoaError(.featureUnsupported) }
            let renderer = GLKView(frame: CGRect(x: 0, y: 0, width: 16, height: 16), context: context)
            EAGLContext.setCurrent(context); renderer.bindDrawable()
            let engine = RTABMap()
            engine.setupCallbacksWithCPP(); engine.initGlContent()
            engine.setupGraphic(size: CGSize(width: 16, height: 16), orientation: .portrait)
            engine.setMappingParameter(key: "Rtabmap/DetectionRate", value: "2")
            engine.setAppendMode(enabled: true)
            guard engine.openDatabase(databasePath: database.path, databaseInMemory: false, optimize: false, clearDatabase: false) >= 0,
                  engine.startCamera() else { throw CocoaError(.fileReadUnknown) }
            engine.setPausedMapping(paused: false)
            self.context = context; self.renderer = renderer; self.engine = engine; self.database = database
            active = true; exportURL = nil; lastFrame = -.infinity
            status = "Building your private 3D map on this phone."
        } catch { status = "Local mapping could not start: \(error.localizedDescription)" }
        #endif
    }
    func consume(_ frame: ARFrame) {
        #if BLIND_RTABMAP
        guard active, let engine, case .normal = frame.camera.trackingState,
              frame.timestamp - lastFrame >= 0.5 else { return }
        lastFrame = frame.timestamp
        EAGLContext.setCurrent(context); renderer?.bindDrawable()
        engine.postOdometryEvent(frame: frame, orientation: .portrait, viewport: CGSize(width: 16, height: 16))
        // The upstream renderer also drains mapping/statistics event queues.
        _ = engine.render()
        #endif
    }
    func stop() {
        mapLifecycleRevision = UUID()
        #if BLIND_RTABMAP
        guard let engine else { return }
        EAGLContext.setCurrent(context)
        engine.stopCamera(); engine.setPausedMapping(paused: true)
        // Upstream destructor closes with save=false; explicitly flush first.
        if let database { engine.save(databasePath: database.path) }
        self.engine = nil; renderer = nil; context = nil
        active = false; status = "Private 3D map saved on this phone."
        refreshExport()
        #endif
    }
}
