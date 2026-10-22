import Foundation

/// Image-description grounding (2026-10-22). Small vision-language models name objects that are
/// not there. A model sentence naming an everyday object is spoken as fact only when the phone's
/// own detectors (Vision classification, an optional detector, people detection) agreed on that
/// object in at least two recent frames; otherwise the sentence must be hedged or it is dropped.
/// Hazards stay sensor-only under SpatialClaimGuard. Text read by OCR is rendered by code.
/// Mirrors server/src/companion-guards.mjs; both run Tests/BlindCoreTests/Fixtures/companion-evidence.json.
public enum VisualGrounding {
    /// Detector evidence from one camera frame.
    public struct Frame: Codable, Equatable, Sendable {
        public var labels: [String]
        public var people: Int
        public init(labels: [String], people: Int) { self.labels = labels; self.people = people }
    }

    public static let objectGroups: [[String]] = [
        ["cup", "cups", "mug", "mugs", "glass", "glasses", "tumbler"],
        ["table", "tables", "desk", "desks"],
        ["chair", "chairs", "stool", "stools", "armchair", "armchairs"],
        ["sofa", "sofas", "couch", "couches"],
        ["bed", "beds"],
        ["door", "doors", "doorway"],
        ["window", "windows"],
        ["lamp", "lamps"],
        ["television", "televisions", "tv", "tvs"],
        ["monitor", "monitors", "screen", "screens"],
        ["laptop", "laptops", "computer", "computers", "keyboard", "keyboards"],
        ["phone", "phones", "smartphone", "smartphones"],
        ["book", "books", "notebook", "notebooks"],
        ["bag", "bags", "backpack", "backpacks", "handbag", "handbags"],
        ["bottle", "bottles"],
        ["plate", "plates", "bowl", "bowls", "dish", "dishes"],
        ["refrigerator", "refrigerators", "fridge", "fridges"],
        ["oven", "ovens", "stove", "stoves", "microwave", "microwaves"],
        ["sink", "sinks"],
        ["toilet", "toilets"],
        ["shelf", "shelves", "bookshelf", "bookshelves", "bookcase", "bookcases"],
        ["cabinet", "cabinets", "cupboard", "cupboards", "wardrobe", "wardrobes", "drawer", "drawers"],
        ["painting", "paintings", "picture", "pictures", "poster", "posters", "frame", "frames"],
        ["plant", "plants", "flower", "flowers", "vase", "vases"],
        ["rug", "rugs", "carpet", "carpets", "mat", "mats"],
        ["pillow", "pillows", "cushion", "cushions"],
        ["blanket", "blankets"],
        ["clock", "clocks"],
        ["mirror", "mirrors"],
        ["box", "boxes", "carton", "cartons"],
        ["toy", "toys", "teddy", "doll", "dolls"],
        ["ball", "balls"],
        ["shoe", "shoes", "sneaker", "sneakers", "boot", "boots"],
        ["car", "cars"],
        ["bicycle", "bicycles", "bike", "bikes"],
        ["dog", "dogs", "puppy"],
        ["cat", "cats", "kitten"],
        ["person", "people", "man", "men", "woman", "women", "child", "children", "kid", "kids", "boy", "boys", "girl", "girls"],
        ["remote", "remotes"],
        ["fan", "fans"],
        ["curtain", "curtains", "blind", "blinds"],
        ["bin", "bins", "trash", "basket", "baskets"]
    ]
    private static let peopleGroup = "person"
    private static let groupByWord: [String: String] = {
        var map: [String: String] = [:]
        for group in objectGroups { for word in group where map[word] == nil { map[word] = group[0] } }
        return map
    }()
    // Patterns are constants covered by the shared fixture tests.
    private static let hedge = try! NSRegularExpression(pattern: #"\b(?:maybe|perhaps|possibly|probably|might|may be|could be|looks like|appears|seems|i think|not sure|unclear)\b"#, options: [.caseInsensitive])

    private static func words(_ text: String) -> [String] {
        text.lowercased().replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { !(($0.isASCII && $0.isLetter) || $0 == "'") }).map(String.init)
    }

    /// Object groups named in a text.
    public static func mentionedObjects(_ text: String) -> Set<String> {
        Set(words(text).compactMap { groupByWord[$0] })
    }

    /// Groups seen in at least `minimum` of the frames (all frames when fewer are supplied).
    public static func agreedObjects(_ frames: [Frame], minimum: Int = 2) -> Set<String> {
        var counts: [String: Int] = [:]
        for frame in frames {
            var seen = Set(frame.labels.flatMap { mentionedObjects($0) })
            if frame.people > 0 { seen.insert(peopleGroup) }
            for group in seen { counts[group, default: 0] += 1 }
        }
        let needed = min(minimum, frames.count)
        return Set(counts.filter { $0.value >= needed }.map(\.key))
    }

    /// Hedged sentences and sentences whose named objects were all confirmed; empty when none remain.
    public static func groundedDescription(_ text: String, confirmed: Set<String>) -> String {
        SpatialClaimGuard.sentences(text).filter { sentence in
            if hedge.firstMatch(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)) != nil { return true }
            return mentionedObjects(sentence).isSubset(of: confirmed)
        }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
