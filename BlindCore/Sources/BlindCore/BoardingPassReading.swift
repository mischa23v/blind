import Foundation

// Mandatory field sequence adapted from BoardingPassKit, MIT, Justin Ackermann (2024).
// Pin ef3b329e71605a9582ee674bd5ed9c1c71f3904d; see research/BOARDING_PASS_REUSE.md.
// Deliberately not a full BCBP validator: private/optional fields are skipped, never retained.
public struct BoardingPassLegReading: Equatable, Sendable {
    public let index: Int
    public let origin: String
    public let destination: String
    public let carrier: String
    public let flightNumber: String
    public let dayOfYear: Int?
    public let seat: String?
    public var flight: String { carrier + flightNumber }
    // No gate or inferred year: neither is supplied by this mandatory layout.
}

public enum BoardingPassParseError: Error, Equatable { case malformed, unsupported, oversized }
public enum BoardingPassParser {
    public static let maximumBytes = 4096
    public static func parse(_ payload: String) throws -> [BoardingPassLegReading] {
        guard payload.utf8.count <= maximumBytes else { throw BoardingPassParseError.oversized }
        let bytes = Array(payload.utf8)
        guard bytes.allSatisfy({ (32...126).contains($0) }), bytes.count >= 60 else {
            throw BoardingPassParseError.malformed
        }
        var cursor = 0
        func take(_ length: Int) throws -> String {
            guard length >= 0, cursor <= bytes.count - length else { throw BoardingPassParseError.malformed }
            defer { cursor += length }
            return String(decoding: bytes[cursor..<(cursor + length)], as: UTF8.self)
        }
        func trim(_ value: String) -> String { value.trimmingCharacters(in: .whitespaces) }
        func hex(_ value: String) throws -> Int {
            guard value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) }),
                  let result = Int(value, radix: 16) else { throw BoardingPassParseError.malformed }
            return result
        }
        guard try take(1) == "M", let count = Int(try take(1)), (1...4).contains(count) else {
            throw BoardingPassParseError.unsupported
        }
        _ = try take(20) // passenger name: not retained
        _ = try take(1) // electronic ticket indicator
        var legs: [BoardingPassLegReading] = []
        for index in 0..<count {
            _ = try take(7) // reservation reference: not retained
            let origin = trim(try take(3)), destination = trim(try take(3))
            let carrier = trim(try take(3)), number = trim(try take(5))
            let dayText = trim(try take(3))
            _ = try take(1) // compartment
            let seat = trim(try take(4))
            _ = try take(5) // check-in sequence: not retained
            _ = try take(1) // passenger status
            let optionalLength = try hex(take(2))
            _ = try take(optionalLength) // exact bounded skip; no conditional repair/padding
            guard BoardingField.matches(origin, "[A-Z]{3}"), BoardingField.matches(destination, "[A-Z]{3}"),
                  BoardingField.matches(carrier, "[A-Z0-9]{2,3}"),
                  BoardingField.matches(number, "(?:[0-9]{1,5}|[0-9]{1,4}[A-Z])"),
                  BoardingField.positiveNumericPrefix(number),
                  dayText.isEmpty || (BoardingField.matches(dayText, "[0-9]{3}") && (1...366).contains(Int(dayText) ?? 0)),
                  seat.isEmpty || (BoardingField.matches(seat, "[0-9]{1,3}[A-Z]?") && BoardingField.positiveNumericPrefix(seat)) else {
                throw BoardingPassParseError.malformed
            }
            legs.append(.init(index: index, origin: origin, destination: destination, carrier: carrier,
                              flightNumber: BoardingField.removeZeros(number), dayOfYear: Int(dayText),
                              seat: seat.isEmpty ? nil : BoardingField.removeZeros(seat)))
        }
        if cursor < bytes.count {
            guard try take(1) == "^" else { throw BoardingPassParseError.unsupported }
            _ = try take(1) // security type, not validated
            let length = try hex(take(2))
            _ = try take(length) // signature is NOT verified or retained
        }
        guard cursor == bytes.count else { throw BoardingPassParseError.malformed }
        return legs
    }
}

private enum BoardingField {
    static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: "\\A(?:" + pattern + ")\\z", options: .regularExpression) != nil
    }
    // Unknown all-zero placeholders and zero-with-suffix values are unsupported.
    // Never strip the complete numeric component and turn 000A into seat A.
    static func positiveNumericPrefix(_ value: String) -> Bool {
        (Int(String(value.prefix(while: { $0 >= "0" && $0 <= "9" }))) ?? 0) > 0
    }
    static func removeZeros(_ value: String) -> String {
        let trimmed = String(value.drop(while: { $0 == "0" }))
        return trimmed.isEmpty ? "0" : trimmed
    }
    static func digits(_ value: String) -> String {
        String(value.unicodeScalars.map { scalar -> Character in
            if (0x660...0x669).contains(scalar.value), let digit = UnicodeScalar(48 + scalar.value - 0x660) { return Character(digit) }
            if (0x6F0...0x6F9).contains(scalar.value), let digit = UnicodeScalar(48 + scalar.value - 0x6F0) { return Character(digit) }
            return Character(scalar)
        })
    }
}

/// Capture authority is supplied by code, never by the model or text being read.
/// UUIDs are opaque IDs, not passenger data. Revision changes invalidate queued output.
public struct BoardingReadingOwner: Equatable, Sendable {
    public let session: UUID
    public let request: UUID
    public let perception: UUID
    public let source: UUID
    public let revision: UUID
    public init(session: UUID, request: UUID, perception: UUID, source: UUID, revision: UUID) {
        self.session = session; self.request = request; self.perception = perception
        self.source = source; self.revision = revision
    }
}
public enum BoardingTextKind: Equatable, Sendable { case printedPass, airportSign }
public struct BoardingTextReading: Equatable, Sendable {
    public let kind: BoardingTextKind
    public let flight: String
    public let gate: String?
    public let seat: String?
    public let observedAt: Date
    public let observedMonotonic: Double
    public let owner: BoardingReadingOwner

    /// Intentionally narrow label/value grammar. Each line belongs to ONE trusted cropped
    /// pass or sign row. Whole departure boards and independent text boxes must not be merged.
    /// Failure is uncertainty, never a reason to ask a model to guess an association.
    public static func read(lines: [String], confidence: Double, kind: BoardingTextKind,
                            observedAt: Date, observedMonotonic: Double, owner: BoardingReadingOwner) -> Self? {
        guard lines.count <= 8, !lines.isEmpty, lines.allSatisfy({ $0.utf8.count <= 160 }),
              confidence.isFinite, (0.95...1).contains(confidence), observedAt.timeIntervalSince1970.isFinite, observedMonotonic.isFinite, observedMonotonic >= 0 else { return nil }
        var fields: [String: String] = [:]
        for line in lines {
            let normalized = BoardingField.digits(line).uppercased().trimmingCharacters(in: .whitespaces)
            let pieces = normalized.split(separator: ":", omittingEmptySubsequences: false)
            guard pieces.count == 2 else { return nil }
            let label = pieces[0].trimmingCharacters(in: .whitespaces)
            let value = pieces[1].trimmingCharacters(in: .whitespaces)
            let key: String
            switch label {
            case "FLIGHT", "الرحلة", "رحلة": key = "flight"
            case "GATE", "البوابة", "بوابة": key = "gate"
            case "SEAT", "المقعد", "مقعد": key = "seat"
            default: return nil
            }
            guard fields[key] == nil else { return nil } // duplicates/alternatives are ambiguous
            if key == "flight" {
                guard BoardingField.matches(value, "[A-Z0-9]{2,3} ?[0-9]{1,4}[A-Z]?") else { return nil }
            } else {
                guard BoardingField.matches(value, key == "gate" ? "[A-Z]?[0-9]{1,3}[A-Z]?" : "[0-9]{1,3}[A-Z]?") else { return nil }
            }
            fields[key] = value.replacingOccurrences(of: " ", with: "")
        }
        guard let flight = fields["flight"], fields["gate"] != nil || fields["seat"] != nil,
              kind != .airportSign || fields["seat"] == nil else { return nil }
        return .init(kind: kind, flight: flight, gate: fields["gate"], seat: fields["seat"], observedAt: observedAt, observedMonotonic: observedMonotonic, owner: owner)
    }
}

public struct BoardingReadingReceipt: Equatable, Sendable {
    public let owner: BoardingReadingOwner
    public let legIndex: Int?
    public let capturedAt: Date
    public let capturedMonotonic: Double
    public let outputID: UUID
    public let textSource: BoardingReadingOwner?
    public let textObservedAt: Date?
    public let textObservedMonotonic: Double?
}
public struct BoardingReadingOutput: Equatable, Sendable {
    public let receipt: BoardingReadingReceipt
    public let speech: String
}

/// Ephemeral local controller: neither Codable nor persistent. Interrupt/delete retires output.
/// The native adapter must also use its existing private-output, camera and speech-lease gates.
public struct BoardingReadingController: Sendable {
    private var owner: BoardingReadingOwner?
    private var legs: [BoardingPassLegReading] = []
    private var capturedAt: Date?
    private var capturedMonotonic: Double?
    private var latestMonotonic: Double = 0
    private var selectedTextSource: BoardingReadingOwner?
    private var pending: BoardingReadingOutput?
    public init() {}
    public mutating func clear() { owner = nil; legs = []; capturedAt = nil; capturedMonotonic = nil; selectedTextSource = nil; pending = nil }
    /// Only the native selected-source owner may call this; never a capture callback.
    public mutating func select(_ selected: BoardingReadingOwner) { clear(); owner = selected }
    /// Native selected-row authority only, never a late OCR callback. The primary pass
    /// owner must still match; selecting another secondary source retires its old output.
    @discardableResult public mutating func selectTextSource(_ selected: BoardingReadingOwner?,
                                                             primaryOwner: BoardingReadingOwner) -> Bool {
        guard owner == primaryOwner else { return false }
        if let selected {
            guard selected.session == primaryOwner.session, selected.request == primaryOwner.request,
                  selected.perception == primaryOwner.perception else { return false }
        }
        if selectedTextSource != selected { pending = nil; selectedTextSource = selected }
        return true
    }
    public mutating func interrupt() { pending = nil }

    /// Bounded multi-result selection: do not take the first camera barcode. More than one
    /// pass candidate is ambiguous, including a malformed candidate beside a valid one.
    @discardableResult public mutating func ingest(payloads: [String], owner: BoardingReadingOwner,
                                                   capturedAt: Date, capturedMonotonic: Double, now: Date, monotonicNow: Double) -> Bool {
        guard self.owner == owner, admit(monotonicNow) else { return false }
        legs = []; self.capturedAt = nil; self.capturedMonotonic = nil; pending = nil
        guard Self.elapsed(capturedMonotonic, monotonicNow, limit: 2), payloads.count <= 8, Self.age(capturedAt, now, limit: 2),
              payloads.allSatisfy({ $0.utf8.count <= BoardingPassParser.maximumBytes }) else { return false }
        let candidates = payloads.filter { $0.hasPrefix("M") }
        guard candidates.count == 1, let payload = candidates.first,
              let parsed = try? BoardingPassParser.parse(payload) else { return false }
        self.owner = owner; self.legs = parsed; self.capturedAt = capturedAt; self.capturedMonotonic = capturedMonotonic
        return true
    }

    /// For multiple legs the caller MUST supply an explicit selected index AND matching
    /// expected flight. There is no current-leg inference from the day-of-year or seat.
    public mutating func prepare(legIndex: Int?, expectedFlight: String?, text: BoardingTextReading? = nil,
                                 currentOwner: BoardingReadingOwner, now: Date, monotonicNow: Double, privateOutputAllowed: Bool,
                                 arabic: Bool = false) -> BoardingReadingOutput? {
        guard currentOwner == owner, text?.owner == selectedTextSource,
              text.map({ $0.kind != .printedPass || $0.owner == currentOwner }) ?? true,
              admit(monotonicNow) else { return nil }
        pending = nil
        guard privateOutputAllowed, let capturedAt, let capturedMonotonic,
              Self.elapsed(capturedMonotonic, monotonicNow, limit: 120),
              Self.age(capturedAt, now, limit: 120),
              let index = legIndex ?? (legs.count == 1 ? 0 : nil), legs.indices.contains(index),
              legs.count == 1 || expectedFlight != nil else { return nil }
        let leg = legs[index]
        guard expectedFlight == nil || expectedFlight == leg.flight else { return nil }
        if let text {
            guard text.owner.session == currentOwner.session, text.owner.request == currentOwner.request,
                  text.owner.perception == currentOwner.perception,
                  text.kind != .printedPass || text.owner == currentOwner,
                  Self.elapsed(text.observedMonotonic, monotonicNow, limit: 30), text.flight == leg.flight, Self.age(text.observedAt, now, limit: 30) else { return nil }
        }
        let capturedStamp = ISO8601DateFormatter().string(from: capturedAt)
        let seat = leg.seat ?? (arabic ? "غير معروف" : "unknown")
        var speech = arabic
            ? "رمز بطاقة الصعود المقروء في \(capturedStamp) يذكر الرحلة \(leg.flight) من \(leg.origin) إلى \(leg.destination)، المقعد \(seat). السنة غير معروفة."
            : "The boarding-pass barcode observed at \(capturedStamp) lists flight \(leg.flight), \(leg.origin) to \(leg.destination), seat \(seat). The year is unknown."
        if let day = leg.dayOfYear {
            speech += arabic ? " يوم السنة \(day)." : " Day of year \(day)."
        }
        if let text, let gate = text.gate {
            let stamp = ISO8601DateFormatter().string(from: text.observedAt)
            if text.kind == .airportSign {
                speech += arabic ? " اللافتة المقروءة في \(stamp) تذكر البوابة \(gate) لهذه الرحلة." : " The sign observed at \(stamp) lists gate \(gate) for this flight number."
            } else {
                speech += arabic ? " النص المطبوع المقروء في \(stamp) يذكر البوابة \(gate)، وقد تتغير." : " The printed text observed at \(stamp) lists gate \(gate); it may have changed."
            }
        } else {
            speech += arabic ? " البوابة غير معروفة." : " The gate is unknown."
        }
        if let textSeat = text?.seat, textSeat != leg.seat {
            speech += arabic ? " النص يذكر مقعدا مختلفا: \(textSeat)." : " The printed seat differs: \(textSeat)."
        }
        speech += arabic ? " لم أتحقق من صلاحية الرحلة أو البوابة الحالية." : " I have not verified the flight's validity or current gate."
        let result = BoardingReadingOutput(receipt: .init(owner: currentOwner, legIndex: index, capturedAt: capturedAt, capturedMonotonic: capturedMonotonic,
            outputID: UUID(), textSource: text?.owner, textObservedAt: text?.observedAt, textObservedMonotonic: text?.observedMonotonic), speech: speech)
        pending = result
        return result
    }

    /// Observation-only reading does not imply a boarding pass, date, chosen itinerary,
    /// or present flight validity. Native adapter must supply an associated single row.
    public mutating func prepareObservation(_ text: BoardingTextReading,
                                           currentOwner: BoardingReadingOwner, now: Date, monotonicNow: Double,
                                           privateOutputAllowed: Bool, arabic: Bool = false) -> BoardingReadingOutput? {
        guard owner == currentOwner, text.owner == currentOwner, text.owner == selectedTextSource, admit(monotonicNow) else { return nil }
        pending = nil
        guard privateOutputAllowed, Self.elapsed(text.observedMonotonic, monotonicNow, limit: 2),
              Self.age(text.observedAt, now, limit: 2) else { return nil }
        let stamp = ISO8601DateFormatter().string(from: text.observedAt)
        let subject = text.kind == .airportSign ? (arabic ? "اللافتة" : "The sign") : (arabic ? "النص المطبوع" : "The printed text")
        var speech = arabic ? "\(subject) المقروء في \(stamp) يذكر الرحلة \(text.flight)." : "\(subject) observed at \(stamp) lists flight number \(text.flight)."
        if let gate = text.gate { speech += arabic ? " البوابة المذكورة \(gate)." : " Listed gate \(gate)." }
        else { speech += arabic ? " البوابة غير معروفة." : " The gate is unknown." }
        if let seat = text.seat { speech += arabic ? " المقعد المذكور \(seat)." : " Listed seat \(seat)." }
        speech += arabic ? " التاريخ والسنة غير معروفين. لم أتحقق من صلاحية الرحلة أو البوابة الحالية." : " The date and year are unknown. I have not verified the flight's validity or current gate."
        owner = currentOwner; capturedAt = text.observedAt; capturedMonotonic = text.observedMonotonic; legs = []
        let result = BoardingReadingOutput(receipt: .init(owner: currentOwner, legIndex: nil, capturedAt: text.observedAt, capturedMonotonic: text.observedMonotonic,
            outputID: UUID(), textSource: text.owner, textObservedAt: text.observedAt, textObservedMonotonic: text.observedMonotonic), speech: speech)
        pending = result
        return result
    }

    /// Call immediately before speech dispatch, not just when generation begins. Exact OCR
    /// source/revision must still be live too; a changed sign invalidates the whole answer.
    public mutating func deliver(_ output: BoardingReadingOutput, currentOwner: BoardingReadingOwner,
                                 currentTextSource: BoardingReadingOwner?, now: Date, monotonicNow: Double,
                                 privateOutputAllowed: Bool) -> String? {
        guard owner == currentOwner, pending == output, output.receipt.owner == currentOwner,
              output.receipt.textSource == selectedTextSource, currentTextSource == selectedTextSource else { return nil }
        guard admit(monotonicNow) else { return nil }
        guard privateOutputAllowed, output.receipt.textSource == currentTextSource,
              Self.elapsed(output.receipt.capturedMonotonic, monotonicNow, limit: 120),
              output.receipt.textObservedMonotonic.map({ Self.elapsed($0, monotonicNow, limit: 30) }) ?? true,
              Self.age(output.receipt.capturedAt, now, limit: 120),
              output.receipt.textObservedAt.map({ Self.age($0, now, limit: 30) }) ?? true else { pending = nil; return nil }
        pending = nil
        return output.speech
    }
    private mutating func admit(_ now: Double) -> Bool {
        guard now.isFinite, now >= latestMonotonic else { return false }
        latestMonotonic = now
        return true
    }
    private static func elapsed(_ captured: Double, _ now: Double, limit: Double) -> Bool {
        captured.isFinite && now.isFinite && captured >= 0 && now >= captured && now - captured < limit
    }
    private static func age(_ date: Date, _ now: Date, limit: Double) -> Bool {
        let age = now.timeIntervalSince(date)
        return date.timeIntervalSince1970.isFinite && now.timeIntervalSince1970.isFinite && age >= 0 && age < limit
    }
}
