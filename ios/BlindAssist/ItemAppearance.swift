import Foundation
import Vision
import CoreVideo
import BlindCore
import BlindMemory

/// How the person's own things look (cup, braille device, favourite outfit), kept on this phone only.
/// Each item keeps several views of the object cut out of the frame (Apple Vision foreground instance
/// masks + feature prints) and any readable marks on it (a name sticker, letters, a logo).
/// Whether a seen object IS the item is decided by ItemAppearanceMatch from image distances — never
/// by a language model, whose description is used only for speaking.
final class ItemAppearance {
    static let maxViews = 6
    /// Two prints closer than this are the same side; a new view must differ by more.
    static let newViewDistance: Float = 0.12

    private struct Stored: Codable { var views: [Data] = []; var marks: [String] = []; var revision = Int(RoomRecall.printRevision) }
    private let memory: MemoryStore?
    private var cache: [String: [VNFeaturePrintObservation]] = [:]
    private var marks: [String: [String]] = [:]
    private var workRevision = WorkRevision()
    func cancelPendingWork() { workRevision.invalidateAll() }
    private let queue = DispatchQueue(label: "org.blindassist.item-appearance", qos: .userInitiated)

    init(memory: MemoryStore?) { self.memory = memory }

    /// One cut-out object in the current view: its print, centre in the upright image (0...1, y from
    /// the top) and readable text on it.
    struct SeenObject { let print: VNFeaturePrintObservation; let x: Double; let y: Double; let text: [String] }

    /// Cuts each foreground object out of the frame and fingerprints it separately.
    static func objects(in image: CVPixelBuffer) -> [SeenObject] {
        let handler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .right)
        let masks = VNGenerateForegroundInstanceMaskRequest(), text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        guard (try? handler.perform([masks, text])) != nil, let observation = masks.results?.first else { return [] }
        let words = (text.results ?? []).compactMap { box in box.topCandidates(1).first.map { ($0.string, box.boundingBox) } }
        var seen: [SeenObject] = []
        for instance in observation.allInstances {
            guard let cutout = try? observation.generateMaskedImage(ofInstances: IndexSet(integer: instance), from: handler,
                                                                     croppedToInstancesExtent: true) else { continue }
            let request = RoomRecall.printRequest()
            guard (try? VNImageRequestHandler(cvPixelBuffer: cutout, orientation: .up).perform([request])) != nil,
                  let print = request.results?.first as? VNFeaturePrintObservation,
                  let box = boundingBox(of: instance, in: observation.instanceMask) else { continue }
            // Text whose centre lies on this object counts as a mark on it.
            let onObject = words.filter { box.contains(CGPoint(x: $0.1.midX, y: 1 - $0.1.midY)) }.map(\.0)
            seen.append(SeenObject(print: print, x: Double(box.midX), y: Double(box.midY), text: onObject))
        }
        return seen
    }

    /// Normalised box (origin top-left) of one instance in the instance-label mask.
    private static func boundingBox(of instance: Int, in mask: CVPixelBuffer) -> CGRect? {
        guard CVPixelBufferLockBaseAddress(mask, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask), stride = CVPixelBufferGetBytesPerRow(mask)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for row in 0..<height {
            let line = base.advanced(by: row * stride).assumingMemoryBound(to: UInt8.self)
            for column in 0..<width where Int(line[column]) == instance {
                minX = min(minX, column); maxX = max(maxX, column); minY = min(minY, row); maxY = max(maxY, row)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: Double(minX) / Double(width), y: Double(minY) / Double(height),
                      width: Double(maxX - minX + 1) / Double(width), height: Double(maxY - minY + 1) / Double(height))
    }

    private func load(_ key: String) -> [VNFeaturePrintObservation] {
        if let cached = cache[key] { return cached }
        let stored = (try? memory?.value(namespace: "item-appearance", id: key)).flatMap { $0 }
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        let valid = stored?.revision == Int(RoomRecall.printRevision) ? stored : nil
        let prints = (valid?.views ?? []).compactMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: $0) }
        cache[key] = prints; marks[key] = valid?.marks ?? []
        return prints
    }

    func viewCount(_ key: String) -> Int { load(key).count }

    /// Adds the held object (nearest the image centre) as a view when it shows a new side.
    /// Calls back with the new total, or nil when no new view was added.
    func addView(_ key: String, image: CVPixelBuffer, completion: @escaping (Int?) -> Void) {
        let existing = load(key), revision = workRevision.token(for: key)
        queue.async {
            let held = Self.objects(in: image).min { hypot($0.x - 0.5, $0.y - 0.5) < hypot($1.x - 0.5, $1.y - 0.5) }
            let isNew = held.map { candidate in
                existing.allSatisfy { print in
                    var distance: Float = .infinity; _ = try? candidate.print.computeDistance(&distance, to: print)
                    return distance > Self.newViewDistance
                }
            } ?? false
            DispatchQueue.main.async {
                guard self.workRevision.accepts(revision), let held, isNew else { completion(nil); return }
                let prints = Array((self.load(key) + [held.print]).suffix(Self.maxViews))
                var stored = Stored()
                stored.views = prints.compactMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
                stored.marks = Array(Set((self.marks[key] ?? []) + held.text.filter { $0.count >= 2 })).sorted()
                do {
                    guard let memory = self.memory else { completion(nil); return }
                    try memory.saveValue(namespace: "item-appearance", id: key, payload: JSONEncoder().encode(stored))
                    self.cache[key] = prints; self.marks[key] = stored.marks
                    completion(prints.count)
                } catch { completion(nil) }

            }
        }
    }

    /// Looks for saved items in the current view. Returns the decision and where the object is in the
    /// upright image, for a LiDAR measurement. Readable marks never override an ambiguous image match.
    func find(_ key: String, among keys: [String], image: CVPixelBuffer,
              completion: @escaping (ItemAppearanceMatch.Result, Double, Double) -> Void) {
        let saved = Dictionary(uniqueKeysWithValues: keys.map { ($0, load($0)) }).filter { !$0.value.isEmpty }
        queue.async {
            var best: (ItemAppearanceMatch.Result, Double, Double, Float) = (.none, 0.5, 0.5, .infinity)
            for object in Self.objects(in: image) {
                var distances: [String: Float] = [:]
                for (name, prints) in saved {
                    distances[name] = prints.map { print -> Float in
                        var distance: Float = .infinity; _ = try? object.print.computeDistance(&distance, to: print); return distance
                    }.min()
                }
                // Shared logos/text are not independent proof of ownership. Keep the image margin.
                let result = ItemAppearanceMatch.decide(distances)
                guard let distance = distances[key] else { continue }
                let relevant: Bool
                switch result { case .same(let name), .similar(let name): relevant = name == key; case .none: relevant = false }
                if relevant, distance < best.3 { best = (result, object.x, object.y, distance) }
            }
            DispatchQueue.main.async { completion(best.0, best.1, best.2) }
        }
    }

    /// Passive matching of a bounded gallery against the already-visible foreground objects.
    /// These are appearance candidates, not validated personal identity or pickup authority.
    struct Candidate { let key: String; let x: Double; let y: Double }
    func candidates(among keys: [String], image: CVPixelBuffer, completion: @escaping ([Candidate]) -> Void) {
        let saved = Dictionary(uniqueKeysWithValues: keys.prefix(64).map { ($0, load($0)) }).filter { !$0.value.isEmpty }
        guard !saved.isEmpty else { completion([]); return }
        queue.async {
            var candidates: [Candidate] = []
            for object in Self.objects(in: image).prefix(12) {
                var distances: [String: Float] = [:]
                for (key, prints) in saved {
                    distances[key] = prints.map { print -> Float in
                        var distance: Float = .infinity
                        _ = try? object.print.computeDistance(&distance, to: print)
                        return distance
                    }.min()
                }
                if case .same(let key) = ItemAppearanceMatch.decide(distances) {
                    candidates.append(Candidate(key: key, x: object.x, y: object.y))
                }
            }
            DispatchQueue.main.async { completion(candidates) }
        }
    }

    @discardableResult func forget(_ key: String) -> Bool {
        workRevision.invalidate(key)
        do {
            guard let memory else { return false }
            try memory.deleteValue(namespace: "item-appearance", id: key)
            cache[key] = nil; marks[key] = nil
            return true
        } catch { return false }
    }
}
