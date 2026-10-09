import Foundation
import Vision
import CoreVideo
import CoreImage
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
    private let queue = DispatchQueue(label: "org.blindassist.room-recall", qos: .utility)
    private static let imageContext = CIContext()

    init(memory: MemoryStore?) { self.memory = memory }

    private func load(_ room: String) -> Stored {
        if let cached = rooms[room] { return cached }
        let stored = (try? memory?.value(namespace: "room-recall", id: room)).flatMap { $0 }
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) } ?? Stored()
        rooms[room] = stored
        printCache[room] = stored.prints.compactMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: $0)
        }
        objectCache[room] = stored.objectPrints.compactMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: $0)
        }
        return stored
    }

    private func save(_ room: String, _ stored: Stored) {
        rooms[room] = stored
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? memory?.saveValue(namespace: "room-recall", id: room, payload: data)
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

    /// While a room is established, keep pictures from each facing direction and its scene labels.
    func learn(room: String, image: CVPixelBuffer, now: Double, sector: Int) {
        let key = "\(room)#\(sector)"
        guard !room.isEmpty, (0..<Self.sectors).contains(sector),
              now - (lastLearned[key] ?? -.infinity) >= Self.learnInterval else { return }
        lastLearned[key] = now
        queue.async { [weak self] in
            let view = Self.analyze(image)
            guard let self, let print = view.print,
                  let data = try? NSKeyedArchiver.archivedData(withRootObject: print, requiringSecureCoding: true) else { return }
            let thumbnail = Self.thumbnail(image).flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.6) }
            let objectData = view.objectPrint.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
            DispatchQueue.main.async {
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
                if let objectData, let objectPrint = view.objectPrint {
                    stored.objectPrints = Array((stored.objectPrints + [objectData]).suffix(Self.maxObjectPrints))
                    self.objectCache[room] = Array(((self.objectCache[room] ?? []) + [objectPrint]).suffix(Self.maxObjectPrints))
                }
                self.printCache[room] = cache
                self.save(room, stored)
            }
        }
    }

    /// Clues for the candidate rooms from the current view, plus the view's sign text for change
    /// detection. Calls back on the main queue.
    func evidence(image: CVPixelBuffer, candidates: [String],
                  completion: @escaping ([RoomEvidence], [String]) -> Void) {
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
                            if let currentThumbnail, Self.registers(currentThumbnail, with: savedImage) { score = max(score, Self.verifiedScore) }
                        }
                        // His bed, not just a bed: the cut-out objects' own appearance can lift the score.
                        if let currentObject = view.objectPrint, let savedObjects = objectPrints[room], !savedObjects.isEmpty {
                            let objectBest = savedObjects.map { print -> Float in
                                var distance: Float = .infinity
                                _ = try? currentObject.computeDistance(&distance, to: print)
                                return distance
                            }.min() ?? .infinity
                            if objectBest.isFinite { score = max(score, Double(max(0, 1 - objectBest / Self.maxDistance))) }
                        }
                        result.append(.imageSimilarity(roomID: room, score: score))
                    }
                }
                let signature = Set((snapshot[room]?.labels ?? [:]).filter { $0.value >= Self.signatureSightings }.keys)
                if !signature.isEmpty {
                    result.append(.furnitureSignature(roomID: room, overlap: Double(signature.intersection(seen).count) / Double(signature.count)))
                }
            }
            DispatchQueue.main.async { completion(result, view.texts) }
        }
    }

    /// Removes a room's saved pictures and labels.
    func forget(room: String) {
        rooms[room] = nil; printCache[room] = nil; objectCache[room] = nil
        lastLearned = lastLearned.filter { !$0.key.hasPrefix("\(room)#") }
        try? memory?.saveValue(namespace: "room-recall", id: room, payload: JSONEncoder().encode(Stored()))
    }
}
