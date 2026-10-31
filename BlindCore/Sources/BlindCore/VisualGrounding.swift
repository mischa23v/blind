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

    /// Same list as OBJECT_GROUPS in server/src/companion-guards.mjs. Arabic words are normalized
    /// (أ→ا, ة→ه, ى→ي). Words not on the list cannot be checked (known gap). The last group holds
    /// things never stated from a model guess.
    public static let objectGroups: [[String]] = [
        ["cup", "cups", "mug", "mugs", "tumbler", "كوب", "اكواب", "فنجان", "كاس"],
        ["table", "tables", "desk", "desks", "طاوله", "طاولات", "مكتب"],
        ["chair", "chairs", "stool", "stools", "armchair", "armchairs", "كرسي", "كراسي"],
        ["sofa", "sofas", "couch", "couches", "كنبه", "اريكه", "كنب"],
        ["bed", "beds", "سرير", "اسره"],
        ["door", "doors", "doorway", "باب", "ابواب"],
        ["window", "windows", "نافذه", "شباك", "نوافذ"],
        ["lamp", "lamps", "مصباح", "لمبه", "اباجوره"],
        ["television", "televisions", "tv", "tvs", "تلفزيون", "تلفاز"],
        ["monitor", "monitors", "screen", "screens", "شاشه"],
        ["laptop", "laptops", "computer", "computers", "keyboard", "keyboards", "حاسوب", "كمبيوتر", "لابتوب"],
        ["phone", "phones", "smartphone", "smartphones", "هاتف", "جوال", "تلفون"],
        ["book", "books", "notebook", "notebooks", "كتاب", "كتب", "دفتر"],
        ["bag", "bags", "backpack", "backpacks", "handbag", "handbags", "حقيبه", "شنطه"],
        ["bottle", "bottles", "زجاجه", "قاروره"],
        ["plate", "plates", "bowl", "bowls", "dish", "dishes", "صحن", "طبق", "صحون"],
        ["refrigerator", "refrigerators", "fridge", "fridges", "ثلاجه"],
        ["oven", "ovens", "stove", "stoves", "microwave", "microwaves", "فرن", "موقد"],
        ["sink", "sinks", "مغسله"],
        ["toilet", "toilets", "مرحاض"],
        ["shelf", "shelves", "bookshelf", "bookshelves", "bookcase", "bookcases", "رف", "رفوف"],
        ["cabinet", "cabinets", "cupboard", "cupboards", "wardrobe", "wardrobes", "drawer", "drawers", "خزانه", "دولاب"],
        ["painting", "paintings", "picture", "pictures", "poster", "posters", "frame", "frames", "لوحه", "صوره"],
        ["plant", "plants", "flower", "flowers", "vase", "vases", "نبته", "نبات", "زهره", "ورد"],
        ["rug", "rugs", "carpet", "carpets", "mat", "mats", "سجاده", "زوليه"],
        ["pillow", "pillows", "cushion", "cushions", "مخده", "وساده"],
        ["blanket", "blankets", "بطانيه", "لحاف"],
        ["clock", "clocks", "ساعه"],
        ["mirror", "mirrors", "مرايه", "مراه"],
        ["box", "boxes", "carton", "cartons", "صندوق", "كرتون"],
        ["toy", "toys", "teddy", "doll", "dolls", "لعبه", "العاب", "دميه"],
        ["ball", "balls", "كره"],
        ["shoe", "shoes", "sneaker", "sneakers", "boot", "boots", "حذاء", "جزمه", "نعال"],
        ["car", "cars", "سياره"],
        ["bicycle", "bicycles", "bike", "bikes", "دراجه"],
        ["dog", "dogs", "puppy", "كلب"],
        ["cat", "cats", "kitten", "قطه", "قط"],
        ["person", "people", "man", "men", "woman", "women", "child", "children", "kid", "kids", "boy", "boys", "girl", "girls", "mom", "mum", "mother", "dad", "father", "brother", "sister", "baby", "grandma", "grandpa", "grandmother", "grandfather", "someone", "somebody", "teacher", "friend", "شخص", "اشخاص", "رجل", "امراه", "طفل", "ولد", "بنت", "ام", "اب", "اخ", "اخت", "احد", "ماما", "بابا"],
        ["remote", "remotes", "ريموت"],
        ["fan", "fans", "مروحه"],
        ["curtain", "curtains", "blind", "blinds", "ستاره", "ستائر"],
        ["bin", "bins", "trash", "basket", "baskets", "سله", "زباله"],
        ["knife", "knives", "scissors", "blade", "blades", "pill", "pills", "medicine", "medicines", "medication", "lighter", "matches", "needle", "needles", "fire", "flame", "flames", "سكين", "مقص", "دواء", "حبوب", "ولاعه", "كبريت", "ابره", "نار"]
    ]
    private static let peopleGroup = "person"
    private static let groupByWord: [String: String] = {
        var map: [String: String] = [:]
        for group in objectGroups { for word in group where map[word] == nil { map[word] = group[0] } }
        return map
    }()
    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Patterns are constants covered by the shared fixture tests.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
    private static let hedge = regex(#"\b(?:maybe|perhaps|possibly|probably|might|may be|could be|looks like|appears|seems|i think|not sure|unclear)\b"#)
    private static let arabicHedge = regex(#"(ربما|يبدو|قد يكون|اظن|لست متاكد|يشبه|غالبا)"#)
    /// Model directions to everyday objects must sound uncertain (spatial rule 3).
    private static let direction = regex(#"\b(?:to your (?:left|right)|on your (?:left|right)|in front of you|ahead of you|straight ahead|behind you|o'?clock)\b"#)
    private static let arabicDirection = regex(#"(يمينك|يسارك|امامك|خلفك|قدامك|علي اليمين|علي اليسار)"#)
    // A model missing an object is not evidence of absence (small models miss visible stairs), and a
    // generic sighting is not the person's own item (identity needs image comparison with saved views).
    private static let absence = regex(#"\b(?:there(?:'s|’s|\s+is|\s+are)\s+no|there\s+(?:isn't|aren't|is not|are not)|(?:is|are)\s*(?:not|n't)\s+(?:here|there|visible|in (?:the |this )?(?:view|picture|photo|image|room))|(?:isn't|aren't)\s+(?:here|there|visible|any)|no\s+[a-z]+\s+(?:here|in view|visible|in (?:the |this )?(?:picture|photo|image))|no\s+[a-z]+\s+(?:is|are)\s+visible|see\s+no|i\s+(?:don't|do not|can't|cannot|couldn't|could not)\s+see\s+(?:a|an|any|the|your)|nothing\s+(?:here|in view|visible)|not\s+found|is missing|are missing)\b"#)
    private static let arabicAbsence = regex(#"(لا يوجد|لا توجد|ليس هناك|ليست هناك|لا اري|غير موجود|مفقود|ما في|مافي|مو موجود|ما اشوف)"#)
    // Partial camera coverage and category detections cannot establish an empty
    // room/container or that people have departed, even when a model hedges it.
    private static let emptyView = regex(#"\b(?:empty|unoccupied|vacant|nobody|no[\s-]?one)\b|\b(?:is|are|seems?|appears?)\s+(?:to be\s+)?(?:absent|gone|missing)\b|\b(?:everyone|everybody|all\s+people)\s+(?:has|have)\s+(?:left|gone)\b"#)
    private static let arabicEmptyView = regex(#"(فارغ|فاضي|خاليه|خالي من|لا احد|ما احد)"#)

    private static func found(_ pattern: NSRegularExpression, _ text: String) -> Bool {
        pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
    private static func folded(_ text: String) -> String {
        SpatialClaimGuard.normalizeArabic(text).replacingOccurrences(of: "ى", with: "ي")
    }

    /// English words with possessive 's removed.
    private static func words(_ text: String) -> [String] {
        text.lowercased().replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
            .split(whereSeparator: { !(($0.isASCII && $0.isLetter) || $0 == "'") })
            .map { word -> String in
                var value = String(word)
                if value.hasSuffix("'s") { value.removeLast(2) }
                return value.replacingOccurrences(of: "'", with: "")
            }
            .filter { !$0.isEmpty }
    }

    private static func arabicWords(_ text: String) -> [String] {
        folded(text).unicodeScalars.split(whereSeparator: { !(0x0621...0x064A).contains($0.value) })
            .map { String(String.UnicodeScalarView($0)) }
    }

    /// Arabic word to (group, owned): exact, then without a joined و/ب/ل/ف, then without ال, then
    /// without a possessive suffix (ك/كم means "your", which is an identity claim).
    private static func arabicGroup(_ word: String) -> (group: String, owned: Bool)? {
        var forms = [word]
        if let first = word.first, "وبلف".contains(first), word.count > 3 { forms.append(String(word.dropFirst())) }
        for form in forms where form.hasPrefix("ال") && form.count >= 4 { forms.append(String(form.dropFirst(2))) }
        for form in forms { if let group = groupByWord[form] { return (group, false) } }
        for form in forms {
            for suffix in ["كم", "ك", "ها", "هم", "ه", "ي"] where form.hasSuffix(suffix) && form.count - suffix.count >= 2 {
                if let group = groupByWord[String(form.dropLast(suffix.count))] { return (group, suffix == "ك" || suffix == "كم") }
            }
        }
        return nil
    }

    /// Object groups named in a text (English and Arabic).
    public static func mentionedObjects(_ text: String) -> Set<String> {
        Set(words(text).compactMap { groupByWord[$0] } + arabicWords(text).compactMap { arabicGroup($0)?.group })
    }

    /// Groups seen in at least `minimum` frames. Fewer frames confirm nothing.
    public static func agreedObjects(_ frames: [Frame], minimum: Int = 2) -> Set<String> {
        var counts: [String: Int] = [:]
        for frame in frames {
            var seen = Set(frame.labels.flatMap { mentionedObjects($0) })
            if frame.people > 0 { seen.insert(peopleGroup) }
            for group in seen { counts[group, default: 0] += 1 }
        }
        return Set(counts.filter { $0.value >= minimum }.map(\.key))
    }

    static func isAbsenceClaim(_ sentence: String) -> Bool {
        let plain = sentence.replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
        return found(absence, plain) || found(emptyView, plain)
            || found(arabicAbsence, folded(sentence)) || found(arabicEmptyView, folded(sentence))
    }

    /// "your" followed by an object within three words, "yours" with an object, or an Arabic object
    /// with the "your" suffix (كوبك).
    static func isIdentityClaim(_ sentence: String) -> Bool {
        let list = words(sentence)
        for (index, word) in list.enumerated() {
            if word == "your", list[(index + 1)..<min(list.count, index + 4)].contains(where: { groupByWord[$0] != nil }) { return true }
            if word == "yours", list.contains(where: { groupByWord[$0] != nil }) { return true }
        }
        return arabicWords(sentence).contains { arabicGroup($0)?.owned == true }
    }

    private static func isHedged(_ sentence: String) -> Bool {
        found(hedge, sentence) || found(arabicHedge, folded(sentence))
    }

    /// Hedged sentences and sentences whose named objects were all confirmed; empty when none remain.
    /// Absence and "your <object>" identity claims are always dropped, and so are unhedged directions.
    public static func groundedDescription(_ text: String, confirmed: Set<String>) -> String {
        SpatialClaimGuard.sentences(text).filter { sentence in
            if isAbsenceClaim(sentence) || isIdentityClaim(sentence) { return false }
            if isHedged(sentence) { return true }
            if found(direction, sentence) || found(arabicDirection, folded(sentence)) { return false }
            return mentionedObjects(sentence).isSubset(of: confirmed)
        }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
