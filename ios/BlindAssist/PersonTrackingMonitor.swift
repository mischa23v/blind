import ARKit
import Vision
import Combine
import BlindCore

struct TrackedPersonSample: Sendable {
    let id: String
    let sourceID: String
    let x: Double, y: Double, width: Double, height: Double
    let confidence: Double
    let capturedAt: Double
    let movedInView: Bool
}

/// Uses Vision's sequence tracker, not a custom detector/association algorithm.
/// IDs last only within a short, stable-camera tracking sequence. Never family IDs.
private actor PersonTrackingWorker {
    private var generation = UUID()
    private var sequence = VNSequenceRequestHandler()
    private var tracks: [(String, VNTrackObjectRequest, CGRect)] = []
    private var started = -Double.infinity
    private var previousCamera: Point3?
    private var previousForward: Point3?
    private var previousTime = -Double.infinity
    private var originCamera: Point3?
    private var originForward: Point3?
    func inspect(image: CVPixelBuffer, camera: Point3, forward: Point3, at time: Double, generation: UUID) throws -> [TrackedPersonSample] {
        let stable = previousCamera.map { $0.distance(to: camera) < 0.10 } == true &&
            previousForward.map { $0.x * forward.x + $0.z * forward.z > cos(.pi / 36) } == true &&
            originCamera.map { $0.distance(to: camera) < 0.10 } == true &&
            originForward.map { $0.x * forward.x + $0.z * forward.z > cos(.pi / 36) } == true &&
            time > previousTime && time - previousTime <= 1.5
        defer { previousCamera = camera; previousForward = forward; previousTime = time }
        // Camera motion, gaps, crossing rectangles, low confidence and six-second
        // windows end identity continuity rather than guessing a reassociation.
        if self.generation != generation || !stable || time - started >= 6 || tracks.isEmpty {
            self.generation = generation; sequence = VNSequenceRequestHandler(); started = time
            originCamera = camera; originForward = forward
            let request = VNDetectHumanRectanglesRequest()
            try VNImageRequestHandler(cvPixelBuffer: image, orientation: .right).perform([request])
            tracks = (request.results as? [VNHumanObservation] ?? []).filter { $0.confidence >= 0.6 && valid($0.boundingBox) }.prefix(8).map {
                let tracking = VNTrackObjectRequest(detectedObjectObservation: $0)
                tracking.trackingLevel = .accurate
                return (UUID().uuidString, tracking, $0.boundingBox)
            }
            return tracks.map { sample(id: $0.0, box: $0.2, confidence: Double($0.1.inputObservation.confidence), time: time, moved: false) }
        }
        try sequence.perform(tracks.map { $0.1 }, on: image, orientation: .right)
        var next: [(String, VNTrackObjectRequest, CGRect)] = []
        var samples: [TrackedPersonSample] = []
        for (id, request, original) in tracks {
            guard let result = request.results?.first as? VNDetectedObjectObservation, result.confidence >= 0.6, valid(result.boundingBox) else { continue }
            request.inputObservation = result
            next.append((id, request, original))
            let box = result.boundingBox
            let moved = hypot(box.midX - original.midX, box.midY - original.midY) > 0.12
            samples.append(sample(id: id, box: box, confidence: Double(result.confidence), time: time, moved: moved))
        }
        for first in samples.indices {
            for second in samples.indices where second > first {
                let a = samples[first], b = samples[second]
                if CGRect(x: a.x, y: a.y, width: a.width, height: a.height).intersects(CGRect(x: b.x, y: b.y, width: b.width, height: b.height)) {
                    tracks = []; return [] // Ambiguous crossing: do not carry IDs through it.
                }
            }
        }
        tracks = next; return samples
    }
    private func sample(id: String, box: CGRect, confidence: Double, time: Double, moved: Bool) -> TrackedPersonSample {
        TrackedPersonSample(id: id, sourceID: generation.uuidString, x: Double(box.minX), y: Double(box.minY),
            width: Double(box.width), height: Double(box.height), confidence: confidence, capturedAt: time, movedInView: moved)
    }
    private func valid(_ box: CGRect) -> Bool {
        !box.isNull && !box.isInfinite && box.width > 0 && box.height > 0 &&
            box.minX >= 0 && box.minY >= 0 && box.maxX <= 1 && box.maxY <= 1
    }
}

final class PersonTrackingMonitor: ObservableObject {
    @Published private(set) var status = ""
    private let worker = PersonTrackingWorker()
    private var generation = UUID()
    private var task: Task<Void, Never>?
    private var lastAttempt = -Double.infinity
    private var samples: [TrackedPersonSample] = []
    private var camera: Point3?
    private var forward: Point3?
    private var frameAt = -Double.infinity
    private var sampleCamera: Point3?
    private var sampleForward: Point3?
    func reset() {
        generation = UUID(); task?.cancel(); task = nil; samples = []
        camera = nil; forward = nil; frameAt = -.infinity; lastAttempt = -.infinity; status = ""
        sampleCamera = nil; sampleForward = nil
    }
    func consume(_ frame: ARFrame, observation: Observation, at now: Double) {
        guard observation.trackingNormal else { reset(); return }
        camera = observation.camera; forward = observation.forward; frameAt = now
        guard task == nil, now - lastAttempt >= 0.5 else { return }
        lastAttempt = now
        let id = generation, image = frame.capturedImage, origin = observation.camera, direction = observation.forward
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let values = try await self.worker.inspect(image: image, camera: origin, forward: direction, at: now, generation: id)
                guard self.generation == id, !Task.isCancelled else { return }
                self.task = nil
                guard self.camera.map({ $0.distance(to: origin) < 0.10 }) == true,
                      self.forward.map({ $0.x * direction.x + $0.z * direction.z > cos(.pi / 36) }) == true else {
                    self.samples = []; return
                }
                self.samples = values; self.sampleCamera = origin; self.sampleForward = direction; self.status = ""
            } catch {
                guard self.generation == id else { return }
                self.task = nil; self.samples = []; self.status = "Visual tracking unavailable."
            }
        }
    }
    func snapshot(at now: Double) -> [[String: Any]] {
        guard now.isFinite, now >= frameAt, now - frameAt <= 0.5,
              let camera, let forward, sampleCamera.map({ $0.distance(to: camera) < 0.10 }) == true,
              sampleForward.map({ $0.x * forward.x + $0.z * forward.z > cos(.pi / 36) }) == true else { return [] }
        return samples.filter { now >= $0.capturedAt && now - $0.capturedAt <= 1.5 }.map {
            ["id": $0.id, "sourceID": $0.sourceID, "category": "person", "ageMS": (now - $0.capturedAt) * 1000,
             "confidence": $0.confidence, "bounds": ["x": $0.x, "y": $0.y, "width": $0.width, "height": $0.height],
             "change": $0.movedInView ? "movedInCameraView" : "notEstablished"]
        }
    }
    func stillMatches(_ captured: [[String: Any]], at now: Double) -> Bool {
        let current = snapshot(at: now)
        return captured.allSatisfy { old in
            guard let id = old["id"] as? String, let fresh = current.first(where: { $0["id"] as? String == id }),
                  let a = old["bounds"] as? [String: Double], let b = fresh["bounds"] as? [String: Double] else { return false }
            return ["x", "y", "width", "height"].allSatisfy { abs((a[$0] ?? -10) - (b[$0] ?? 10)) < 0.10 }
        }
    }
}
