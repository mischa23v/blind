import Foundation

/// One item location the person explicitly saved ("remember my braille book here").
/// `position` is in the map frame named by `frameID`. Answers always present it as
/// last-seen information with time and place, never as where the item is now.
public struct RememberedItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    /// The person's own words, trimmed, at most `ItemMemory.nameLimit` characters.
    public let name: String
    /// Normalized form of `name` used for matching (see `ItemMemory.key(for:)`).
    public let key: String
    public let roomID: String?
    public let roomName: String?
    /// Map-frame position at save time; only meaningful together with `frameID`.
    public let position: Point3?
    /// Map/alignment revision that `position` belongs to.
    public let frameID: String?
    public let savedAt: Date
    public let source: String
    /// Spoken description of the item's look (colour, shape, markings), drafted on the phone.
    /// Used only for speaking; whether a seen object IS this item is decided by image comparison.
    public var description: String? = nil
    public init(id: String = UUID().uuidString, name: String, roomID: String? = nil, roomName: String? = nil,
                position: Point3? = nil, frameID: String? = nil, savedAt: Date, source: String = "user") {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        key = ItemMemory.key(for: name)
        self.roomID = roomID; self.roomName = roomName
        self.position = position; self.frameID = frameID
        self.savedAt = savedAt; self.source = source
    }
}

/// Small local list of explicitly saved item locations. Nothing here computes or
/// guesses geometry; a measured direction/distance is supplied by the caller.
public struct ItemMemory: Codable, Equatable, Sendable {
    public static let limit = 64
    public static let nameLimit = 80
    static let fieldLimit = 128
    public private(set) var items: [RememberedItem] = []
    private enum CodingKeys: String, CodingKey { case items }
    public init() {}
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        items = try values.decodeIfPresent([RememberedItem].self, forKey: .items) ?? []
    }

    /// Saves an item. The same normalized name replaces the earlier record (keeping its id).
    /// Returns nil when the name is empty or too long, a position has no frame, or the list is full.
    @discardableResult
    public mutating func remember(name: String, roomID: String? = nil, roomName: String? = nil,
                                  position: Point3? = nil, frameID: String? = nil,
                                  at savedAt: Date = Date()) -> RememberedItem? {
        let key = Self.key(for: name)
        guard !key.isEmpty else { return nil }
        let existing = items.firstIndex { $0.key == key }
        guard existing != nil || items.count < Self.limit else { return nil }
        let id = existing.map { items[$0].id } ?? UUID().uuidString
        var item = RememberedItem(id: id, name: name, roomID: Self.clean(roomID), roomName: Self.clean(roomName),
                                  position: position, frameID: Self.clean(frameID), savedAt: savedAt)
        // Saving a new place keeps the item's spoken description.
        if let existing { item.description = items[existing].description }
        guard Self.isValid(item) else { return nil }
        if let existing { items[existing] = item } else { items.append(item) }
        return item
    }

    /// Sets the spoken description of a saved item (at most 300 characters). False when not saved.
    @discardableResult
    public mutating func describe(_ name: String, as description: String) -> Bool {
        let key = Self.key(for: name)
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = items.firstIndex(where: { $0.key == key }), !text.isEmpty, text.count <= 300 else { return false }
        items[index].description = text
        return true
    }

    /// Exact normalized match first; otherwise a whole-word "contains" match in either
    /// direction, preferring the most recently saved. Answers name the saved item, so
    /// the person hears which record matched.
    public func find(_ name: String) -> RememberedItem? {
        let key = Self.key(for: name)
        guard !key.isEmpty else { return nil }
        if let exact = items.first(where: { $0.key == key }) { return exact }
        let words = key.split(separator: " ").map(String.init)
        let matches = items.filter { item in
            let itemWords = item.key.split(separator: " ").map(String.init)
            return Self.containsRun(itemWords, words) || Self.containsRun(words, itemWords)
        }
        return matches.max { $0.savedAt < $1.savedAt }
    }

    /// Removes only an exact normalized match, so a loose phrase never deletes another item.
    @discardableResult
    public mutating func forget(_ name: String) -> Bool {
        let key = Self.key(for: name)
        guard !key.isEmpty, let index = items.firstIndex(where: { $0.key == key }) else { return false }
        items.remove(at: index)
        return true
    }

    public var valid: Bool {
        guard items.count <= Self.limit,
              Set(items.map { $0.id }).count == items.count,
              Set(items.map { $0.key }).count == items.count else { return false }
        return items.allSatisfy { Self.isValid($0) }
    }

    /// Spoken answer. Found items are described as saved at a time and place; a measured
    /// relation is added only when the caller confirms the same aligned map frame.
    public static func answer(for item: RememberedItem?, asked name: String, now: Date, sameFrame: Bool,
                              measuredRelation: String?, arabic: Bool) -> String {
        guard let item else {
            let asked = displayName(name, arabic: arabic)
            return arabic ? "لم أحفظ مكان \(asked). قل: تذكر \(asked) هنا، عندما تضعه."
                : "I don't have your \(asked) saved. Say: remember my \(asked) here, when you put it down."
        }
        let itemName = displayName(item.name, arabic: arabic)
        let elapsed = relativeTime(from: item.savedAt, to: now, arabic: arabic)
        let relation = measuredRelation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let measured = sameFrame && !relation.isEmpty && item.position != nil && item.frameID != nil
        var text: String
        if arabic {
            text = "تم حفظ \(itemName)"
            if let room = item.roomName { text += " في \(room)" }
            text += " \(elapsed)."
            text += measured ? " القياس من هنا: \(sentence(relation))" : " موقعه الحالي غير مؤكد."
        } else {
            text = "Your \(itemName) was saved"
            if let room = item.roomName { text += " in \(roomPhrase(room))" }
            text += " \(elapsed)."
            text += measured ? " Measured from here: \(sentence(relation))" : " Its current position is not confirmed."
        }
        return text
    }

    // MARK: - Normalization

    /// Case- and diacritic-insensitive folding with Arabic alef, taa marbuta and alef
    /// maqsura unified, tashkeel and tatweel removed, and curly apostrophes made plain.
    static func fold(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                  locale: Locale(identifier: "en_US_POSIX"))
        var scalars = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars {
            switch scalar.value {
            case 0x064B...0x065F, 0x0670, 0x0640: continue
            case 0x0622, 0x0623, 0x0625, 0x0671: scalars.append("\u{0627}")
            case 0x0629: scalars.append("\u{0647}")
            case 0x0649: scalars.append("\u{064A}")
            case 0x2019: scalars.append("'")
            default: scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    static func foldedWords(_ text: String) -> [String] {
        fold(text).split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    /// Matching key: folded words, leading "my"/"the" dropped, and the Arabic definite
    /// article dropped from each word (so "كتاب البرايل" matches "كتاب برايل").
    public static func key(for name: String) -> String {
        var words = foldedWords(name)
        while let first = words.first, first == "my" || first == "the" { words.removeFirst() }
        return words.map(stripArticle).filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func stripArticle(_ word: String) -> String {
        word.hasPrefix("ال") && word.count >= 4 ? String(word.dropFirst(2)) : word
    }

    static func containsRun(_ haystack: [String], _ needle: [String]) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count)
        where Array(haystack[start..<(start + needle.count)]) == needle { return true }
        return false
    }

    // MARK: - Validation helpers

    static func clean(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    static func fieldValid(_ value: String?) -> Bool {
        value.map { !$0.isEmpty && $0.unicodeScalars.count <= fieldLimit } ?? true
    }

    static func isValid(_ item: RememberedItem) -> Bool {
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.id.isEmpty, item.id.count <= 64, item.source == "user" else { return false }
        guard !trimmed.isEmpty, trimmed == item.name, item.name.count <= nameLimit else { return false }
        guard !item.key.isEmpty, item.key == key(for: item.name) else { return false }
        guard item.savedAt.timeIntervalSince1970.isFinite else { return false }
        guard fieldValid(item.roomID), fieldValid(item.roomName), fieldValid(item.frameID) else { return false }
        // A position is only usable together with the map frame it was measured in.
        if let position = item.position { return position.isFinite && item.frameID != nil }
        return true
    }

    // MARK: - Wording helpers

    static func displayName(_ name: String, arabic: Bool) -> String {
        var value = name.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if let range = value.range(of: "my ", options: [.anchored, .caseInsensitive]) {
            value = String(value[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if value.isEmpty { return arabic ? "الغرض" : "item" }
        return value
    }

    static func roomPhrase(_ room: String) -> String {
        let lower = room.lowercased()
        if ["the ", "my ", "a ", "an "].contains(where: { lower.hasPrefix($0) }) ||
            lower.contains("'s") || lower.contains("\u{2019}s") { return room }
        return "the " + room
    }

    static func sentence(_ text: String) -> String {
        guard let last = text.last else { return text }
        return ".!?؟".contains(last) ? text : text + "."
    }

    /// Under 2 minutes "just now", then whole minutes, hours, days. A save time slightly
    /// ahead of `now` (clock adjustment) is read as "just now".
    static func relativeTime(from saved: Date, to now: Date, arabic: Bool) -> String {
        let seconds = max(0, now.timeIntervalSince(saved))
        guard seconds.isFinite else { return arabic ? "في وقت غير معروف" : "at an unknown time" }
        if seconds < 120 { return arabic ? "قبل لحظات" : "just now" }
        if seconds < 3600 {
            let n = Int(seconds / 60)
            return arabic ? arabicCount(n, one: "دقيقة", two: "دقيقتين", few: "دقائق", many: "دقيقة")
                : "\(n) minutes ago"
        }
        if seconds < 86400 {
            let n = Int(seconds / 3600)
            return arabic ? arabicCount(n, one: "ساعة", two: "ساعتين", few: "ساعات", many: "ساعة")
                : "\(n) \(n == 1 ? "hour" : "hours") ago"
        }
        let n = Int(seconds / 86400)
        return arabic ? arabicCount(n, one: "يوم", two: "يومين", few: "أيام", many: "يوما")
            : "\(n) \(n == 1 ? "day" : "days") ago"
    }

    static func arabicCount(_ n: Int, one: String, two: String, few: String, many: String) -> String {
        switch n {
        case 1: return "قبل \(one)"
        case 2: return "قبل \(two)"
        case 3...10: return "قبل \(n) \(few)"
        default: return "قبل \(n) \(many)"
        }
    }
}

/// Whole-utterance item commands. English find/forget require "my" so ordinary
/// questions ("where is the bathroom?") stay with the assistant.
public enum ItemCommand: Equatable, Sendable {
    case remember(String), find(String), forget(String)
    /// "This is my cup" while showing it: save how the item looks (several views make it reliable).
    case learn(String)

    static let rememberPatterns: [([String], [String])] = [
        (["remember", "where", "my"], ["is"]), (["remember", "where", "my"], ["are"]),
        (["remember", "my"], ["is", "here"]), (["remember", "my"], ["are", "here"]),
        (["remember", "my"], ["here"]),
        (["تذكر"], ["هنا"])
    ]
    static let findPatterns: [([String], [String])] = [
        (["where", "is", "my"], []), (["where", "are", "my"], []),
        (["where's", "my"], []), (["wheres", "my"], []),
        (["where", "did", "i", "leave", "my"], []), (["where", "did", "i", "put", "my"], []),
        (["اين"], []), (["وين"], [])
    ]
    static let learnPatterns: [([String], [String])] = [
        (["this", "is", "my"], []), (["these", "are", "my"], []), (["learn", "my"], []),
        (["هذا"], []), (["هذه"], [])
    ]
    static let forgetPatterns: [([String], [String])] = [
        (["forget", "my"], []),
        (["انس"], []), (["انسي"], [])
    ]

    public static func parse(_ text: String) -> ItemCommand? {
        let pairs = text.split(whereSeparator: { $0.isWhitespace }).map { word -> (String, String) in
            let original = String(word)
            return (original, ItemMemory.fold(original).trimmingCharacters(in: .punctuationCharacters))
        }.filter { !$0.1.isEmpty }
        let words = pairs.map { $0.0 }
        let folded = pairs.map { $0.1 }

        func payload(_ prefix: [String], _ suffix: [String]) -> String? {
            guard folded.count > prefix.count + suffix.count,
                  Array(folded.prefix(prefix.count)) == prefix,
                  Array(folded.suffix(suffix.count)) == suffix else { return nil }
            let value = words[prefix.count..<(words.count - suffix.count)].joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard !value.isEmpty, value.count <= ItemMemory.nameLimit,
                  !ItemMemory.key(for: value).isEmpty else { return nil }
            return value
        }

        for (prefix, suffix) in rememberPatterns { if let value = payload(prefix, suffix) { return .remember(value) } }
        for (prefix, suffix) in findPatterns { if let value = payload(prefix, suffix) { return .find(value) } }
        for (prefix, suffix) in forgetPatterns { if let value = payload(prefix, suffix) { return .forget(value) } }
        for (prefix, suffix) in learnPatterns {
            guard let value = payload(prefix, suffix) else { continue }
            // Arabic "هذا كوبي" needs the possessive ending, so "هذا ماذا؟" stays a question.
            if prefix.count == 1, !(value.hasSuffix("ي") || value.hasSuffix("ى")) { continue }
            return .learn(value)
        }
        return nil
    }
}
