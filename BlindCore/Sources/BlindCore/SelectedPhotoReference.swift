import Foundation

/// A read-only selected-image intent, resolved before movement or camera routing.
/// This never identifies a current object or supplies a navigation destination.
public enum SelectedPhotoIntent {
    public static func matches(_ text: String) -> Bool {
        let value = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 800 else { return false }
        let photo = ["photo", "picture", "image", "snapshot", "صورة", "الصورة"].contains { value.contains($0) }
        let reference = ["selected", "library", "this photo", "this picture", "this image", "in the photo", "in the picture", "in this photo", "from my photos", "المحددة", "مكتبتي", "في الصورة", "هذه الصورة"].contains { value.contains($0) }
        return photo && reference
    }
}

/// Pure ownership/delivery controller for the existing PhotosPicker. The native
/// adapter owns actual Vision work and Feedback owns actual speech callbacks.
/// No image, OCR or source identifier is persisted by this controller.
public struct SelectedPhotoReference: Sendable {
    public static let maximumEncodedBytes = 20 * 1024 * 1024
    public static let maximumSourcePixels = 48_000_000
    public static let maximumDecodedSide = 2048
    public struct Selection: Equatable, Sendable {
        public let id: UUID
        public let viewID: UUID
        public let generation: UInt64
        public let question: String
        public let issuedAt: Double
    }
    public struct Context: Sendable {
        public let selection: Selection
        public let source: CompanionReferenceIdentity?
        public let viewID: UUID?
        public let generation: UInt64
        public let question: String
        public let now: Double
        public var foreground: Bool = true
        public var quiet: Bool = false
        public var hazard: Bool = false
        public var privateAudioHeld: Bool = false
        public init(selection: Selection, source: CompanionReferenceIdentity?, viewID: UUID?, generation: UInt64,
                    question: String, now: Double, foreground: Bool = true, quiet: Bool = false,
                    hazard: Bool = false, privateAudioHeld: Bool = false) {
            self.selection = selection; self.source = source; self.viewID = viewID
            self.generation = generation; self.question = question; self.now = now
            self.foreground = foreground; self.quiet = quiet; self.hazard = hazard
            self.privateAudioHeld = privateAudioHeld
        }
    }
    public struct Phrase: Equatable, Sendable {
        public let id: UUID
        public let text: String
        public let originalSlice: String
    }
    public private(set) var selection: Selection?
    public private(set) var source: CompanionReferenceSource?
    public private(set) var phrases: [Phrase] = []
    public private(set) var pending: Phrase?
    public private(set) var completed = 0
    public private(set) var withdrawn = false
    private var lastNow = 0.0
    public init() {}

    /// Call synchronously BEFORE awaiting any picker transfer. Replacing even a
    /// still-loading selection revokes all older ownership immediately.
    @discardableResult public mutating func select(viewID: UUID, generation: UInt64,
                                                   question: String, now: Double) -> Selection? {
        clear()
        guard now.isFinite, now >= 0, !question.isEmpty, question.count <= 800 else { return nil }
        let value = Selection(id: UUID(), viewID: viewID, generation: generation, question: question, issuedAt: now)
        selection = value; lastNow = now
        return value
    }
    public func owns(_ value: Selection, viewID: UUID?, generation: UInt64, now: Double) -> Bool {
        selection == value && !withdrawn && viewID == value.viewID && generation == value.generation &&
            now.isFinite && now >= lastNow && now >= value.issuedAt && now - value.issuedAt < CompanionReferenceReading.lifetime
    }
    public mutating func install(_ source: CompanionReferenceSource, for value: Selection, now: Double, arabic: Bool = false) -> Bool {
        guard owns(value, viewID: value.viewID, generation: value.generation, now: now),
              source.identity.media == .selectedPhoto, source.identity.sourceID == value.id,
              // The explicit picker action reads the WHOLE selected source. The
              // phrase below selects all blocks, not a model-selected answer.
              let first = source.blocks.first?.evidence.text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).first,
              let reader = try? CompanionReferenceReading.prepare(request: .init(kind: .readText, query: String(first)),
                  binding: .init(requestID: value.id, generation: value.generation), selectedSource: source.identity,
                  source: source, issuedAt: value.issuedAt, monotonicNow: now, arabic: arabic) else { return false }
        let prefix = arabic ? "مرجع صورة (محتمل): «" : "Photo reference (uncertain): «"
        let phrases = reader.chunks.map { Phrase(id: $0.id, text: prefix + $0.originalSlice + "»", originalSlice: $0.originalSlice) }
        guard phrases.allSatisfy({ CompanionReferenceReading.wordCount($0.text) <= CompanionReferenceReading.maximumWords }) else { return false }
        self.source = source; self.phrases = phrases; lastNow = now
        return true
    }
    @discardableResult public mutating func revalidate(_ context: Context) -> Bool {
        guard owns(context.selection, viewID: context.viewID, generation: context.generation, now: context.now),
              context.question == context.selection.question, context.source == source?.identity,
              context.foreground, !context.quiet, !context.hazard, !context.privateAudioHeld else {
            withdrawn = true; return false
        }
        lastNow = context.now
        return true
    }
    public mutating func next(_ context: Context) -> Phrase? {
        guard revalidate(context), source != nil, pending == nil, completed < phrases.count else { return nil }
        return phrases[completed]
    }
    /// Reserve before native dispatch (callbacks may be synchronous in tests).
    public mutating func begin(_ phrase: Phrase, context: Context) -> Bool {
        guard next(context) == phrase else { return false }
        pending = phrase; return true
    }
    public mutating func admissionRejected(_ id: UUID) { if pending?.id == id { pending = nil } }
    @discardableResult public mutating func finish(id: UUID, text: String, outcome: NarrationDelivery, context: Context) -> Bool {
        guard revalidate(context), let pending, pending.id == id,
              pending.text.utf8.elementsEqual(text.utf8) else { return false }
        guard outcome == .completed else { withdrawn = true; self.pending = nil; return false }
        self.pending = nil; completed += 1; return true
    }
    public mutating func clear() { self = Self() }

    /// Vision classifications are suggestions, never heat, ownership, currency,
    /// face identity, room presence, geometry or commands. Unknown labels are omitted.
    public static func neutralCategories(_ labels: [String]) -> [String] {
        let allowed: Set<String> = ["animal", "cat", "dog", "bird", "flower", "tree", "book", "cup", "chair", "table", "building", "car", "bicycle", "food", "toy", "clothing"]
        var seen = Set<String>()
        return labels.filter { allowed.contains($0) && seen.insert($0).inserted }
    }
}
