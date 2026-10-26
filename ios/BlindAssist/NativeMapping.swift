import Foundation
import ARKit
import Combine
import BlindCore
#if BLIND_RTABMAP
import GLKit
#endif

/// Native integration uses RTAB-Map's existing iOS frame/coordinate adapter.
/// A mapped database is NOT treated as proof of current indoor localization.
final class NativeMapping: ObservableObject {
    @Published private(set) var status = "Native RTAB-Map build required for growing 3D maps."
    @Published private(set) var active = false
    @Published private(set) var exportURL: URL?
    @Published private(set) var localGridSnapshot: NativeLocalGridSnapshot?
    private var localGridConsumer = NativeLocalGridConsumer()
    private var localGridGeneration: UInt64 = 0
    private var gridTrackingLost = false
    private var minimumGridCapture = -Double.infinity
    private var gridWatchdog: Timer?
    private func clearLocalGrid() {
        gridWatchdog?.invalidate(); gridWatchdog = nil
        localGridConsumer.invalidate(); localGridSnapshot = nil
    }
    private func publishLocalGrid(_ value: NativeLocalGridSnapshot) {
        guard localGridSnapshot != value else { return }
        localGridSnapshot = value
        if active {
            status = "Private 3D map: \(value.groundCellCount) ground, \(value.obstacleCellCount) obstacle, \(value.emptyCellCount) empty-ray cells. \(value.status.rawValue). Not walking guidance."
        }
    }
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
        clearLocalGrid()
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
            // This owner uses only the lifetime-managed local-grid mailbox.
            // Do not register unused legacy raw-self renderer/UI callbacks.
            engine.initGlContent()
            engine.setupGraphic(size: CGSize(width: 16, height: 16), orientation: .portrait)
            engine.setMappingParameter(key: "Rtabmap/DetectionRate", value: "2")
            // Reuse upstream node-local 3D classification/rays. No local raycaster.
            // Empty rays are unavailable unless that upstream build has OctoMap.
            for (key, value) in ["RGBD/CreateOccupancyGrid": "true", "Rtabmap/PublishStats": "true",
                "Grid/Sensor": "1", "Grid/3D": "true", "Grid/CellSize": "0.1",
                "Grid/RangeMin": "0.2", "Grid/RangeMax": "6.0", "Grid/DepthDecimation": "4",
                "Grid/MapFrameProjection": "false", "Grid/Scan2dUnknownSpaceFilled": "false",
                "Grid/RayTracing": engine.supportsLocalGridRayTracing ? "true" : "false"] {
                engine.setMappingParameter(key: key, value: value)
            }
            guard localGridGeneration < UInt64.max else { throw CocoaError(.featureUnsupported) }
            localGridGeneration += 1; localGridConsumer.begin(generation: localGridGeneration)
            gridTrackingLost = false; minimumGridCapture = ProcessInfo.processInfo.systemUptime
            engine.localGridReceived = { [weak self, weak engine] packet in
                guard let self, let engine, self.engine === engine, self.active else { return }
                let value = self.localGridConsumer.consume(packet, now: ProcessInfo.processInfo.systemUptime)
                self.publishLocalGrid(value)
            }
            engine.enableLocalGrid(generation: localGridGeneration)
            engine.setAppendMode(enabled: true)
            guard engine.openDatabase(databasePath: database.path, databaseInMemory: false, optimize: false, clearDatabase: false) >= 0,
                  engine.startCamera() else { throw CocoaError(.fileReadUnknown) }
            engine.setPausedMapping(paused: false)
            self.context = context; self.renderer = renderer; self.engine = engine; self.database = database
            active = true; exportURL = nil; lastFrame = -.infinity
            status = "Building your private 3D map on this phone. Waiting for upstream local grids."
            gridWatchdog?.invalidate()
            gridWatchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self, self.active else { return }
                self.publishLocalGrid(self.localGridConsumer.snapshot(now: ProcessInfo.processInfo.systemUptime))
            }
            if let gridWatchdog { RunLoop.main.add(gridWatchdog, forMode: .common) }
        } catch { clearLocalGrid(); status = "Local mapping could not start: \(error.localizedDescription)" }
        #endif
    }
    /// Lightweight ownership retirement, called before the app frame throttle
    /// and independently of the upright-heading DepthSampler admission.
    func trackingLost(at capturedAt: Double? = nil) {
        #if BLIND_RTABMAP
        guard active, let engine else { return }
        let now = ProcessInfo.processInfo.systemUptime
        // This hook runs before app freshness admission. Invalid/future loss
        // stamps may withdraw ownership but must not poison the recovery fence.
        let loss = capturedAt.flatMap { FrameTimestampPolicy.isFresh(capturedAt: $0, receivedAt: now) ? $0 : nil } ?? now
        guard loss.isFinite, loss >= minimumGridCapture else { return }
        minimumGridCapture = max(minimumGridCapture, loss, lastFrame)
        guard !gridTrackingLost else { return }
        gridTrackingLost = true
        guard localGridGeneration < UInt64.max else { clearLocalGrid(); engine.disableLocalGrid(); return }
        localGridGeneration += 1; localGridConsumer.begin(generation: localGridGeneration)
        engine.resetLocalGrid(generation: localGridGeneration, resetCameraOrigin: true)
        publishLocalGrid(localGridConsumer.snapshot())
        #endif
    }
    func consume(_ frame: ARFrame) {
        #if BLIND_RTABMAP
        guard active, let engine else { return }
        // Retire coordinate ownership BEFORE cadence. The old normal-only guard
        // otherwise hid upstream resetOrigin from every lost-tracking frame.
        guard case .normal = frame.camera.trackingState else {
            trackingLost(at: frame.timestamp); return
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard frame.timestamp.isFinite, frame.timestamp >= 0, now >= frame.timestamp,
              now - frame.timestamp <= 0.5, frame.timestamp > minimumGridCapture, frame.timestamp - lastFrame >= 0.5 else { return }
        gridTrackingLost = false; lastFrame = frame.timestamp
        EAGLContext.setCurrent(context); renderer?.bindDrawable()
        engine.postOdometryEvent(frame: frame, orientation: .portrait, viewport: CGSize(width: 16, height: 16))
        // The upstream renderer also drains mapping/statistics event queues.
        _ = engine.render()
        #endif
    }
    func stop() {
        mapLifecycleRevision = UUID()
        clearLocalGrid()
        #if BLIND_RTABMAP
        guard let engine else { return }
        engine.disableLocalGrid()
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
