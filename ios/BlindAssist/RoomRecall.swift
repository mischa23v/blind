import Foundation
import Vision
import CoreVideo
import CoreImage
import ImageIO
import UIKit
import BlindCore
import BlindMemory

/// Remembers what each established room looks like, so the room can be recognised again the way
/// a sighted person does — including telling look-alike rooms apart by the specific appearance of
/// their things (this duvet, this poster, this lamp next to it). Clues only: saved pictures from
/// every facing direction (Apple Vision feature prints), a part-by-part check of borderline matches
/// (Apple Vision homographic registration), and the room's usual furniture/scene labels.
/// RoomRecognizer combines them with other clues; one clue never decides. Everything stays on this phone.
final class RoomRecall {
    /// Two pictures for each of 8 facing directions.
    static let sectors = 8, maxPerSector = 2
    static let learnInterval = 15.0
    /// Feature-print distance at which similarity reaches 0. Calibrate on the iPhone (Q09 device run).
    static let maxDistance: Float = 1.0
    /// Borderline whole-picture scores get the part-by-part check; a successful check counts as strong.
    static let borderline: ClosedRange<Double> = 0.5...0.8, verifiedScore = 0.8
    /// A label counts as part of a room's furniture signature once seen in this many learning snapshots.
    static let signatureSightings = 3
    static let thumbnailSide: CGFloat = 320

    private struct Stored: Codable {
        var prints: [Data] = []; var sectors: [Int] = []; var thumbnails: [Data] = []; var labels: [String: Int] = [:]
        var objectPrints: [Data] = []; var revision = Int(RoomRecall.printRevision)
        init() {}
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            prints = try values.decodeIfPresent([Data].self, forKey: .prints) ?? []
            sectors = try values.decodeIfPresent([Int].self, forKey: .sectors) ?? Array(repeating: 0, count: prints.count)
            thumbnails = try values.decodeIfPresent([Data].self, forKey: .thumbnails) ?? []
            labels = try values.decodeIfPresent([String: Int].self, forKey: .labels) ?? [:]
            objectPrints = try values.decodeIfPresent([Data].self, forKey: .objectPrints) ?? []
            revision = try values.decodeIfPresent(Int.self, forKey: .revision) ?? 0
            // Pictures saved by a different Vision revision cannot be compared; relearn them.
            if revision != Int(RoomRecall.printRevision) { prints = []; sectors = []; thumbnails = []; objectPrints = []; revision = Int(RoomRecall.printRevision) }
        }
    }
    private let memory: MemoryStore?
    private var rooms: [String: Stored] = [:]
    private var printCache: [String: [VNFeaturePrintObservation]] = [:]
    private var objectCache: [String: [VNFeaturePrintObservation]] = [:]
    static let maxObjectPrints = 16
    private var lastLearned: [String: Double] = [:]
    private var workRevision = WorkRevision()
    func cancelPendingWork() { workRevision.invalidateAll() }
    private let queue = DispatchQueue(label: "org.blindassist.room-recall", qos: .utility)
    private static let imageContext = CIContext()

    init(memory: MemoryStore?) { self.memory = memory }

    private func load(_ room: String) -> Stored {
        if let cached = rooms[room] { return cached }
        var stored = (try? memory?.value(namespace: "room-recall", id: room)).flatMap { $0 }
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) } ?? Stored()
        // Keep prints, directions and thumbnails index-aligned: drop any entry whose print cannot be
        // decoded instead of shifting the cache against the stored arrays.
        let decoded = stored.prints.map { try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: $0) }
        if decoded.contains(where: { $0 == nil }) {
            let keep = decoded.indices.filter { decoded[$0] != nil }
            stored.prints = keep.map { stored.prints[$0] }
            stored.sectors = keep.compactMap { $0 < stored.sectors.count ? stored.sectors[$0] : nil }
            stored.thumbnails = keep.compactMap { $0 < stored.thumbnails.count ? stored.thumbnails[$0] : nil }
        }
        rooms[room] = stored
        printCache[room] = decoded.compactMap { $0 }
        objectCache[room] = stored.objectPrints.compactMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: $0)
        }
        return stored
    }

    private func save(_ room: String, _ stored: Stored) -> Bool {
        do {
            guard let memory else { return false }
            try memory.saveValue(namespace: "room-recall", id: room, payload: JSONEncoder().encode(stored))
            rooms[room] = stored
            return true
        } catch { return false }
    }

    /// Prints from different Vision revisions cannot be compared, so the revision is pinned and saved.
    static let printRevision = VNGenerateImageFeaturePrintRequestRevision2

    static func printRequest() -> VNGenerateImageFeaturePrintRequest {
        let request = VNGenerateImageFeaturePrintRequest(); request.revision = printRevision; return request
    }

    /// One Vision pass: whole-picture fingerprint, a fingerprint of the main foreground objects cut out
    /// on the phone (the bed itself, not just the room), scene/furniture labels and readable sign text.
    struct View { let print: VNFeaturePrintObservation?; let objectPrint: VNFeaturePrintObservation?; let labels: [String]; let texts: [String] }
    static func analyze(_ image: CVPixelBuffer) -> View {
        let whole = printRequest()
        let classify = VNClassifyImageRequest()
        let text = VNRecognizeTextRequest(); text.recognitionLevel = .fast
        let objects = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .right)
        _ = try? handler.perform([whole, classify, text, objects])
        var objectPrint: VNFeaturePrintObservation?
        if let mask = objects.results?.first,
           let cutout = try? mask.generateMaskedImage(ofInstances: mask.allInstances, from: handler, croppedToInstancesExtent: true) {
            let objectRequest = printRequest()
            if (try? VNImageRequestHandler(cvPixelBuffer: cutout, orientation: .up).perform([objectRequest])) != nil {
                objectPrint = objectRequest.results?.first as? VNFeaturePrintObservation
            }
        }
        let labels = (classify.results ?? []).filter { $0.confidence >= 0.3 }.prefix(8).map { $0.identifier.lowercased() }
        let texts = (text.results ?? []).compactMap { $0.topCandidates(1).first }.filter { $0.confidence >= 0.5 }.map(\.string)
        return View(print: whole.results?.first as? VNFeaturePrintObservation, objectPrint: objectPrint,
                    labels: Array(labels), texts: Array(texts.prefix(16)))
    }

    /// Small upright picture for the part-by-part check.
    static func thumbnail(_ image: CVPixelBuffer) -> CGImage? {
        let upright = CIImage(cvPixelBuffer: image).oriented(.right)
        let scale = thumbnailSide / max(upright.extent.width, upright.extent.height)
        let small = upright.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return imageContext.createCGImage(small, from: small.extent)
    }

    /// Whether the current view aligns with a saved picture as the same scene seen from a nearby
    /// angle. A plausible warp (no flip, moderate scale and shift) counts as a match.
    static func registers(_ current: CGImage, with saved: CGImage) -> Bool {
        let request = VNHomographicImageRegistrationRequest(targetedCGImage: saved, options: [:])
        guard (try? VNImageRequestHandler(cgImage: current, options: [:]).perform([request])) != nil,
              let alignment = request.results?.first as? VNImageHomographicAlignmentObservation else { return false }
        let m = alignment.warpTransform
        let determinant = Double(m.columns.0.x * m.columns.1.y - m.columns.1.x * m.columns.0.y)
        let shift = hypot(Double(m.columns.2.x), Double(m.columns.2.y))
        // Calibrate these limits on the iPhone with real room pictures.
        return (0.5...2.0).contains(determinant) && shift < Double(thumbnailSide) * 0.5 &&
            abs(Double(m.columns.0.z)) < 0.003 && abs(Double(m.columns.1.z)) < 0.003
    }

    /// While a room is established by a trusted clue, keep pictures from each facing direction and its
    /// scene labels. Reuses the Vision pass already made for `evidence`.
    func learn(room: String, view: View, image: CVPixelBuffer, now: Double, sector: Int) {
        let key = "\(room)#\(sector)"
        guard !room.isEmpty, (0..<Self.sectors).contains(sector),
              now - (lastLearned[key] ?? -.infinity) >= Self.learnInterval else { return }
        lastLearned[key] = now
        let revision = workRevision.token(for: room)
        queue.async { [weak self] in
            guard let self, let print = view.print,
                  let data = try? NSKeyedArchiver.archivedData(withRootObject: print, requiringSecureCoding: true) else { return }
            let thumbnail = Self.thumbnail(image).flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.6) }
            let objectData = view.objectPrint.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
            DispatchQueue.main.async {
                guard self.workRevision.accepts(revision) else { return }
                var stored = self.load(room)
                var cache = self.printCache[room] ?? []
                // Replace the oldest picture of this direction once it has two.
                if stored.sectors.filter({ $0 == sector }).count >= Self.maxPerSector, let oldest = stored.sectors.firstIndex(of: sector) {
                    stored.prints.remove(at: oldest); stored.sectors.remove(at: oldest)
                    if oldest < stored.thumbnails.count { stored.thumbnails.remove(at: oldest) }
                    if oldest < cache.count { cache.remove(at: oldest) }
                }
                stored.prints.append(data); stored.sectors.append(sector); cache.append(print)
                // Thumbnails stay index-aligned with prints; an empty entry means none was made.
                while stored.thumbnails.count < stored.prints.count - 1 { stored.thumbnails.append(Data()) }
                stored.thumbnails.append(thumbnail ?? Data())
                for label in Set(view.labels) { stored.labels[label, default: 0] += 1 }
                var objects = self.objectCache[room] ?? []
                if let objectData, let objectPrint = view.objectPrint {
                    stored.objectPrints = Array((stored.objectPrints + [objectData]).suffix(Self.maxObjectPrints))
                    objects = Array((objects + [objectPrint]).suffix(Self.maxObjectPrints))
                }
                guard self.save(room, stored) else { self.lastLearned[key] = nil; return }
                self.printCache[room] = cache; self.objectCache[room] = objects
            }
        }
    }

    /// Clues for the candidate rooms from the current view, plus the view's sign text for change
    /// detection. Calls back on the main queue.
    func evidence(image: CVPixelBuffer, candidates: [String],
                  completion: @escaping ([RoomEvidence], View) -> Void) {
        let snapshot = Dictionary(uniqueKeysWithValues: candidates.map { ($0, load($0)) })
        let prints = Dictionary(uniqueKeysWithValues: candidates.map { ($0, printCache[$0] ?? []) })
        let objectPrints = Dictionary(uniqueKeysWithValues: candidates.map { ($0, objectCache[$0] ?? []) })
        queue.async {
            var result: [RoomEvidence] = []
            let view = Self.analyze(image)
            let current = view.print, seen = Set(view.labels)
            var currentThumbnail: CGImage?
            for room in candidates {
                if let current, let saved = prints[room], !saved.isEmpty {
                    let distances = saved.map { print -> Float in
                        var distance: Float = .infinity
                        _ = try? current.computeDistance(&distance, to: print)
                        return distance
                    }
                    if let best = distances.min(), best.isFinite, let index = distances.firstIndex(of: best) {
                        var score = Double(max(0, 1 - best / Self.maxDistance))
                        // Borderline: check part by part against the closest saved picture.
                        if Self.borderline.contains(score), let thumbnails = snapshot[room]?.thumbnails, index < thumbnails.count,
                           let savedImage = UIImage(data: thumbnails[index])?.cgImage {
                            if currentThumbnail == nil { currentThumbnail = Self.thumbnail(image) }
                            // Registration can return a plausible warp even for unrelated pictures, so it only
                            // lifts a borderline score a little until calibrated on the iPhone.
                            if let currentThumbnail, Self.registers(currentThumbnail, with: savedImage) { score = min(Self.verifiedScore, score + 0.1) }
                        }
                        // His bed, not just a bed: the cut-out objects' own appearance can lift the score.
                        if let currentObject = view.objectPrint, let savedObjects = objectPrints[room], !savedObjects.isEmpty {
                            let objectBest = savedObjects.map { print -> Float in
                                var distance: Float = .infinity
                                _ = try? currentObject.computeDistance(&distance, to: print)
                                return distance
                            }.min() ?? .infinity
                            // An object can move between rooms (a held cup, a sibling's identical toy), so its
                            // match only lifts an already borderline whole-room score, by at most 0.1.
                            if objectBest.isFinite, Self.borderline.contains(score) {
                                score = min(score + 0.1, max(score, Double(max(0, 1 - objectBest / Self.maxDistance))))
                            }
                        }
                        result.append(.imageSimilarity(roomID: room, score: score))
                    }
                }
                let signature = Set((snapshot[room]?.labels ?? [:]).filter { $0.value >= Self.signatureSightings }.keys)
                if !signature.isEmpty {
                    result.append(.furnitureSignature(roomID: room, overlap: Double(signature.intersection(seen).count) / Double(signature.count)))
                }
            }
            DispatchQueue.main.async { completion(result, view) }
        }
    }

    /// Removes a room's saved pictures and labels.
    @discardableResult func forget(room: String) -> Bool {
        workRevision.invalidate(room)
        do {
            guard let memory else { return false }
            try memory.deleteValue(namespace: "room-recall", id: room)
            rooms[room] = nil; printCache[room] = nil; objectCache[room] = nil
            lastLearned = lastLearned.filter { !$0.key.hasPrefix("\(room)#") }
            return true
        } catch { return false }
    }
}

/// A requested, transient Vision read, deliberately separate from room learning.
/// Reuses Apple's VNRecognizeTextRequest / VNClassifyImageRequest APIs, not an LLM:
/// See Apple's Vision VNRecognizeTextRequest / VNClassifyImageRequest documentation.
/// These are candidates, not proof of identity, denomination, colour, location,
/// clearance or absence. Caller owns permission, request/session, capture age,
/// pose and speech gates before AND after this read. No frame or result is saved.
///
/// Sendability proof: the queue is immutable; the only mutable probe state,
/// `busy`, is accessed under `lock`. A permit covers queued AND running work,
/// including work whose awaiting task has already cancelled or timed out.
final class ConversationFrameProbe: @unchecked Sendable {
    struct Result: Sendable {
        let texts: [String]
        let labels: [String]
    }

    private let queue = DispatchQueue(label: "org.blindassist.conversation-frame-probe", qos: .userInitiated)
    private let lock = NSLock()
    private var busy = false

    /// The supplied captured frame must remain read-only. At most one frame is
    /// retained for Vision; a concurrent request is rejected rather than queued.
    /// The tool runtime owns its two-second deadline; synchronous Vision may
    /// finish later, but cancellation releases the waiter and discards that result.
    func inspect(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) async -> Result? {
        guard !Task.isCancelled, claim() else { return nil }
        let read = Read(image: image, orientation: orientation)
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                read.install(continuation)
                queue.async { [self, read] in
                    let result: Result? = autoreleasepool {
                        guard !read.isCancelled else { return nil }
                        return Self.analyze(read)
                    }
                    // Cancellation never releases this permit early: otherwise
                    // repeated timed-out requests could build a frame backlog.
                    release()
                    read.finish(result)
                }
            }
        } onCancel: {
            read.cancel()
        }
        return Task.isCancelled ? nil : result
    }

    private func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !busy else { return false }
        busy = true
        return true
    }
    private func release() {
        lock.lock(); busy = false; lock.unlock()
    }

    /// All Vision objects and image access stay on the dedicated serial queue.
    private static func analyze(_ read: Read) -> Result? {
        guard !read.isCancelled else { return nil }
        let width = CVPixelBufferGetWidth(read.image), height = CVPixelBufferGetHeight(read.image)
        guard width > 0, height > 0, width <= 4096, height <= 4096,
              width * height <= 12_000_000 else { return nil }
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .fast
        text.usesLanguageCorrection = false
        let classify = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: read.image, orientation: read.orientation)
        guard !read.isCancelled else { return nil }
        do { try handler.perform([text, classify]) } catch { return nil }
        guard !read.isCancelled else { return nil }

        var texts: [String] = [], labels: [String] = []
        for observation in (text.results ?? []).prefix(32) {
            guard texts.count < 8, let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= 0.65,
                  let value = boundedWholeString(candidate.string, maximumScalars: 160),
                  !texts.contains(value) else { continue }
            texts.append(value)
        }
        for observation in (classify.results ?? []).prefix(32) {
            guard labels.count < 6, observation.confidence >= 0.55,
                  let value = boundedWholeString(observation.identifier.lowercased(), maximumScalars: 64),
                  genericLabels.contains(value), !labels.contains(value) else { continue }
            labels.append(value)
        }
        guard !read.isCancelled else { return nil }
        // An empty successful read means no usable candidates, never "not there".
        return Result(texts: texts, labels: labels)
    }

    /// Reject oversized records intact; truncation could remove a qualification
    /// or negation and manufacture a different observation.
    private static func boundedWholeString(_ text: String, maximumScalars: Int) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.unicodeScalars.count <= maximumScalars,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return value
    }

    // Narrow, anonymous object/scene vocabulary only. In particular, Vision
    // classifications never supply people/face names, money values or colours.
    private static let genericLabels: Set<String> = [
        "chair", "table", "desk", "door", "window", "sofa", "couch", "bed",
        "shelf", "bookcase", "lamp", "cup", "mug", "bottle", "book", "backpack",
        "bag", "refrigerator", "sink", "cabinet", "stove", "oven", "plant", "tree",
        "flower", "car", "bicycle", "bus", "cat", "dog", "bird", "fish",
        "television", "computer", "keyboard", "phone", "remote control",
        "stairs", "staircase", "escalator"
    ]

    /// Sendability proof: image/orientation are immutable; only the serial queue
    /// reads image pixels, and neither this helper nor its caller may mutate this
    /// retained captured frame. The lock protects EVERY access to continuation,
    /// completed and cancelled. Resumption happens once, outside the lock.
    private final class Read: @unchecked Sendable {
        let image: CVPixelBuffer
        let orientation: CGImagePropertyOrientation
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Result?, Never>?
        private var completed = false
        private var cancelled = false

        init(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
            self.image = image; self.orientation = orientation
        }
        var isCancelled: Bool {
            lock.lock(); defer { lock.unlock() }
            return cancelled
        }
        func install(_ continuation: CheckedContinuation<Result?, Never>) {
            lock.lock()
            if completed { lock.unlock(); continuation.resume(returning: nil); return }
            self.continuation = continuation
            lock.unlock()
        }
        func cancel() {
            lock.lock()
            cancelled = true
            let continuation = self.continuation
            self.continuation = nil; completed = true
            lock.unlock()
            continuation?.resume(returning: nil)
        }
        func finish(_ result: Result?) {
            lock.lock()
            guard !completed else { lock.unlock(); return }
            completed = true
            let continuation = self.continuation
            self.continuation = nil
            lock.unlock()
            continuation?.resume(returning: result)
        }
    }
}

