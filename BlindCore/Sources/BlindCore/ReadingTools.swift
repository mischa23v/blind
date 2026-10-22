import Foundation

/// Seeing AI-style reading tools (2026-10-22): live text, page reading with framing guidance,
/// barcode/QR scanning, and a light detector. Everything here is decided by on-device Vision,
/// ARKit light estimates and code, never by a language model. These are pure, testable rules;
/// the app runs the Vision requests and speaks the results.
public enum ReadingTool: String, Codable, Sendable {
    case liveText, document, barcode, light
}

public enum ReadingToolCommand: Equatable, Sendable {
    case start(ReadingTool)
    case stop
    /// "Call this apple juice" after a product scan.
    case nameProduct(String)

    private static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .replacingOccurrences(of: "please ", with: "").replacingOccurrences(of: "can you ", with: "")
    }

    public static func parse(_ raw: String) -> ReadingToolCommand? {
        let text = normalized(raw)
        let arabic = SpatialClaimGuard.normalizeArabic(text).replacingOccurrences(of: "ى", with: "ي")
        let stops = ["stop reading", "stop scanning", "stop the light detector", "stop light detector", "stop the reading tool",
                     "اوقف القراءه", "اوقف المسح", "اوقف كاشف الضوء"]
        if stops.contains(text) || stops.contains(arabic) { return .stop }
        for prefix in ["call this ", "name this ", "this product is ", "سمه ", "سمي هذا "] where text.hasPrefix(prefix) || arabic.hasPrefix(prefix) {
            let source = text.hasPrefix(prefix) ? text : arabic
            let name = String(source.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            return name.isEmpty || name.count > 60 ? nil : .nameProduct(name)
        }
        let commands: [(ReadingTool, [String])] = [
            (.document, ["read the page", "read this page", "read a page", "read the document", "read this document", "read a document",
                         "read this letter", "read the letter", "read my homework", "read this book", "read the book",
                         "اقرا الصفحه", "اقرا هذه الصفحه", "اقرا المستند", "اقرا الورقه", "اقرا الكتاب"]),
            (.liveText, ["read text", "read the text", "read text live", "read signs", "read the signs", "start reading", "read what you see",
                         "اقرا النص", "اقرا اللافتات", "ابدا القراءه"]),
            (.barcode, ["scan barcode", "scan the barcode", "scan a barcode", "scan product", "scan the product", "scan this product",
                        "what product is this", "read the barcode", "scan qr code", "scan the qr code", "read the qr code", "scan code",
                        "امسح الباركود", "ما هذا المنتج", "اقرا الباركود", "امسح الرمز"]),
            (.light, ["light detector", "check the light", "is the light on", "are the lights on", "how bright is it", "how bright is the room",
                      "كاشف الضوء", "هل النور مضاء", "هل الضوء مضاء", "كم الاضاءه"])
        ]
        for (tool, phrases) in commands where phrases.contains(text) || phrases.contains(arabic) { return .start(tool) }
        return nil
    }
}

/// One recognised text line in upright image coordinates (0...1, origin top-left).
public struct TextLine: Equatable, Sendable {
    public var text: String
    public var confidence: Double
    public var x: Double
    public var y: Double
    public init(text: String, confidence: Double, x: Double, y: Double) {
        self.text = text; self.confidence = confidence; self.x = x; self.y = y
    }
}

/// Live text: speak lines once, as they come into view, top to bottom; repeat a line only after it
/// has been out of view for a while.
public struct LiveTextReader: Sendable {
    public static let minimumConfidence = 0.5
    public static let forgetAfter = 10.0
    public static let maximumLines = 3
    private var lastSeen: [String: Double] = [:]
    public init() {}

    static func key(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    public mutating func newLines(_ lines: [TextLine], now: Double) -> [String] {
        guard now.isFinite else { return [] }
        lastSeen = lastSeen.filter { now - $0.value <= Self.forgetAfter }
        var result: [String] = []
        for line in lines.sorted(by: { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }) {
            let key = Self.key(line.text)
            guard line.confidence >= Self.minimumConfidence, key.count >= 2 else { continue }
            if lastSeen[key] == nil, result.count < Self.maximumLines { result.append(line.text.trimmingCharacters(in: .whitespaces)) }
            lastSeen[key] = now
        }
        return result
    }
}

/// Framing guidance for reading a whole page (Seeing AI Document style).
public enum DocumentGuidance: Equatable, Sendable {
    case noPage, moveLeft, moveRight, moveUp, moveDown, moveCloser, moveBack, holdStill

    public static let edgeMargin = 0.02
    public static let minimumArea = 0.2
    public static let maximumArea = 0.95

    /// `corners`: the detected page's four corners in upright image coordinates (0...1, origin top-left).
    public static func evaluate(_ corners: [(x: Double, y: Double)]?) -> DocumentGuidance {
        guard let corners, corners.count == 4, corners.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return .noPage }
        let xs = corners.map { $0.x }, ys = corners.map { $0.y }
        let minX = xs.min()!, maxX = xs.max()!, minY = ys.min()!, maxY = ys.max()!
        // Shoelace area of the page quadrilateral.
        var twiceArea = 0.0
        for index in 0..<4 {
            let a = corners[index], b = corners[(index + 1) % 4]
            twiceArea += a.x * b.y - b.x * a.y
        }
        let area = abs(twiceArea) / 2
        let left = minX <= edgeMargin, right = maxX >= 1 - edgeMargin, top = minY <= edgeMargin, bottom = maxY >= 1 - edgeMargin
        if area > maximumArea || (left && right) || (top && bottom) { return .moveBack }
        // A cut edge means the page continues beyond the view on that side: move the phone that way.
        if left { return .moveLeft }
        if right { return .moveRight }
        if top { return .moveUp }
        if bottom { return .moveDown }
        if area < minimumArea { return .moveCloser }
        return .holdStill
    }

    public func speech(arabic: Bool) -> String {
        switch self {
        case .noPage: return arabic ? "لا أرى صفحة بعد. وجّه الهاتف نحو الورقة." : "I don't see a page yet. Point the phone at the paper."
        case .moveLeft: return arabic ? "حرّك الهاتف قليلاً إلى اليسار." : "Move the phone a little left."
        case .moveRight: return arabic ? "حرّك الهاتف قليلاً إلى اليمين." : "Move the phone a little right."
        case .moveUp: return arabic ? "حرّك الهاتف قليلاً إلى الأعلى." : "Move the phone a little up."
        case .moveDown: return arabic ? "حرّك الهاتف قليلاً إلى الأسفل." : "Move the phone a little down."
        case .moveCloser: return arabic ? "قرّب الهاتف من الصفحة." : "Move the phone closer to the page."
        case .moveBack: return arabic ? "أبعد الهاتف قليلاً عن الصفحة." : "Move the phone a little further from the page."
        case .holdStill: return arabic ? "اثبت. أقرأ الصفحة." : "Hold still. Reading the page."
        }
    }
}

/// Spoken result of a barcode or QR code, rendered by code from the decoded payload.
public enum CodeReading {
    public static func speech(payload: String, isQR: Bool, savedName: String?, arabic: Bool) -> String {
        let value = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if let savedName { return arabic ? "هذا \(savedName)." : "This is \(savedName)." }
        if isQR {
            if let url = URL(string: value), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()), let host = url.host {
                return arabic ? "رمز QR فيه رابط إلى \(host). لن أفتحه تلقائياً." : "A QR code with a link to \(host). I won't open it by myself."
            }
            return (arabic ? "رمز QR يقول: " : "The QR code says: ") + String(value.prefix(300))
        }
        let digits = value.map(String.init).joined(separator: " ")
        return arabic ? "رمز منتج: \(digits). لا أعرف اسمه بعد. قل: سمّه، ثم الاسم."
            : "Product code: \(digits). I don't know its name yet. Say: call this, and then its name."
    }
}

/// Products the child named after scanning ("call this apple juice"), kept on the phone.
public struct ProductMemory: Codable, Equatable, Sendable {
    public static let limit = 200
    public private(set) var names: [String: String] = [:]
    public init() {}
    public func name(for payload: String) -> String? { names[payload] }
    @discardableResult
    public mutating func save(_ name: String, for payload: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty, payload.count <= 300, !name.isEmpty, name.count <= 60,
              names[payload] != nil || names.count < Self.limit else { return false }
        names[payload] = name
        return true
    }
    public mutating func forget(_ payload: String) { names[payload] = nil }
}

/// Light detector from ARKit's ambient light estimate (lumens; about 1000 is a normally lit room).
public enum LightLevel: Int, Comparable, Sendable {
    case dark, dim, medium, bright, veryBright

    public static func from(lumens: Double) -> LightLevel? {
        guard lumens.isFinite, lumens >= 0 else { return nil }
        switch lumens {
        case ..<100: return .dark
        case ..<400: return .dim
        case ..<1200: return .medium
        case ..<2000: return .bright
        default: return .veryBright
        }
    }
    public static func < (lhs: LightLevel, rhs: LightLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    public func speech(arabic: Bool) -> String {
        switch self {
        case .dark: return arabic ? "مظلم." : "Dark."
        case .dim: return arabic ? "إضاءة خافتة." : "Dim."
        case .medium: return arabic ? "إضاءة عادية." : "Normal light."
        case .bright: return arabic ? "ساطع." : "Bright."
        case .veryBright: return arabic ? "ساطع جداً." : "Very bright."
        }
    }
    /// Seconds between beeps: brighter is faster, like a light probe.
    public var beepInterval: Double { [1.6, 1.1, 0.7, 0.45, 0.3][rawValue] }
}
