import ARKit
import Vision
import Combine
import BlindCore

/// Supplemental on-device RGB classifier. No cloud calls; never a clearance source.
// Like NavigationModel, entry points run on the AR session's main delegate queue.
final class VisualStairMonitor: ObservableObject {
    @Published private(set) var state: State = .idle
    enum State { case idle, checking, active, unsupported, failed }
    private var generation = UUID()
    private var task: Task<Void, Never>?
    private var lastAttempt = -Double.infinity
    private var current: (camera: Point3, forward: Point3, pitch: Double, time: Double)?
    private var candidate: (label: String, confidence: Double, camera: Point3, forward: Point3, pitch: Double, time: Double)?
    var onUpdate: (() -> Void)?

    func reset() {
        generation = UUID(); task?.cancel(); task = nil
        candidate = nil; current = nil; lastAttempt = -.infinity; state = .idle
    }
    func consume(_ frame: ARFrame, at now: Double) {
        guard case .normal = frame.camera.trackingState else {
            current = nil; candidate = nil; return
        }
        let transform = frame.camera.transform, f = -frame.camera.transform.columns.2
        let length = hypot(f.x, f.z)
        guard length > 0.25 else { current = nil; candidate = nil; return }
        let camera = Point3(Double(transform.columns.3.x), Double(transform.columns.3.y), Double(transform.columns.3.z))
        let forward = Point3(Double(f.x / length), 0, Double(f.z / length))
        let pitch = Double(atan2(f.y, length))
        current = (camera, forward, pitch, now)
        guard task == nil, now - lastAttempt >= 1, state != .unsupported else { return }
        lastAttempt = now
        let id = generation, image = frame.capturedImage
        state = .checking
        task = Task { @MainActor [weak self] in
            do {
                let result = try await Task.detached(priority: .utility) { () -> (Bool, String?, Double) in
                    let request = VNClassifyImageRequest()
                    let identifiers = try request.supportedIdentifiers()
                    guard identifiers.contains(where: VisualHazard.isStairIdentifier) else { return (false, nil, 0) }
                    try VNImageRequestHandler(cvPixelBuffer: image, orientation: .right).perform([request])
                    let match = request.results?.filter { VisualHazard.isStairIdentifier($0.identifier) }
                        .max { $0.confidence < $1.confidence }
                    return (true, match?.identifier, Double(match?.confidence ?? 0))
                }.value
                guard let self, self.generation == id, !Task.isCancelled else { return }
                self.task = nil; self.state = result.0 ? .active : .unsupported
                if let label = result.1, result.2 >= 0.75 {
                    self.candidate = (label, result.2, camera, forward, pitch, now)
                }
                // A negative classification does not clear a prior positive early.
                self.onUpdate?()
            } catch {
                guard let self, self.generation == id, !Task.isCancelled else { return }
                self.task = nil; self.state = .failed; self.onUpdate?()
            }
        }
    }
    func detection(at now: Double) -> Detection? {
        guard let candidate, let current else { return nil }
        return VisualHazard.warning(identifier: candidate.label, confidence: candidate.confidence,
            capturedAt: candidate.time, now: now, origin: candidate.camera, current: current.camera,
            originForward: candidate.forward, currentForward: current.forward, tracking: true, currentFrameAt: current.time,
            originPitch: candidate.pitch, currentPitch: current.pitch)
    }
    func status(arabic: Bool) -> String {
        switch state {
        case .idle: return arabic ? "فحص الدرج بالصورة متوقف." : "Image stair check is stopped."
        case .checking, .active: return arabic ? "فحص تجريبي للدرج بالصورة. لا يثبت خلو الطريق." : "Experimental image stair check. It cannot establish a clear path."
        case .unsupported: return arabic ? "مصنف الصور في هذا الجهاز لا يوفر تصنيف الدرج المطلوب." : "This device's image classifier does not provide the required stair labels."
        case .failed: return arabic ? "فحص الدرج بالصورة غير متاح حالياً." : "Image stair checking is currently unavailable."
        }
    }
}
