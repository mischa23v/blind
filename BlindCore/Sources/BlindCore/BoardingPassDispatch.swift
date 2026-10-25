import Foundation

/// Pure bridge for existing OCR/barcode producers. Never executes a URL, stores a
/// raw payload, or supplies text to a model. The native speech sink still owns
/// permission, ordinary budgets, playback and cancellation.
public enum BoardingPassDispatch {
    public struct Answer: Equatable, Sendable {
        public let receipt: BoardingReadingReceipt
        public let text: String
    }
    public enum Result: Equatable, Sendable { case unrelated, withheld, answer(Answer) }

    public static func codes(_ payloads: [String], owner: BoardingReadingOwner,
                             capturedAt: Date, capturedMonotonic: Double, now: Date, monotonicNow: Double,
                             selectedFlight: String? = nil, arabic: Bool = false) -> Result {
        guard payloads.count <= 8, payloads.allSatisfy({ $0.utf8.count <= BoardingPassParser.maximumBytes }) else { return .withheld }
        let candidates = payloads.filter { isBoardingPayload($0) }
        guard !candidates.isEmpty else { return .unrelated }
        guard candidates.count == 1, let payload = candidates.first,
              let legs = try? BoardingPassParser.parse(payload) else { return .withheld }
        let selected = selectedFlight.map { flight in legs.filter { $0.flight == flight } } ?? (legs.count == 1 ? legs : [])
        guard selected.count == 1, let leg = selected.first else { return .withheld }
        var controller = BoardingReadingController(); controller.select(owner)
        guard controller.ingest(payloads: payloads, owner: owner, capturedAt: capturedAt,
                                capturedMonotonic: capturedMonotonic, now: now, monotonicNow: monotonicNow),
              let output = controller.prepare(legIndex: leg.index, expectedFlight: leg.flight,
                  currentOwner: owner, now: now, monotonicNow: monotonicNow, privateOutputAllowed: true),
              controller.deliver(output, currentOwner: owner, currentTextSource: nil,
                  now: now, monotonicNow: monotonicNow, privateOutputAllowed: true) != nil else { return .withheld }
        let seat = leg.seat ?? (arabic ? "غير معروف" : "unknown")
        let text = arabic ? "رمز بطاقة الصعود يذكر الرحلة \(leg.flight)، والمقعد \(seat). البوابة والسنة غير معروفتين؛ صلاحية الرحلة غير متحققة."
            : "Boarding-pass barcode lists flight \(leg.flight), seat \(seat). Gate and year unknown; flight validity unverified."
        return .answer(.init(receipt: output.receipt, text: text))
    }

    /// ONE complete Vision observation must contain explicit labels separated by
    /// semicolons. Never concatenate independent OCR boxes or departure-board rows.
    /// We cannot establish paper/pass/sign identity, so speak only "captured text".
    public static func textRows(_ rows: [(text: String, confidence: Double)], owner: BoardingReadingOwner,
                                capturedAt: Date, capturedMonotonic: Double, now: Date, monotonicNow: Double,
                                selectedFlight: String? = nil, arabic: Bool = false) -> Result {
        guard rows.count <= 64, rows.allSatisfy({ $0.text.utf8.count <= 480 }) else { return .withheld }
        let candidates = rows.filter { isTravelText($0.text) }
        guard !candidates.isEmpty else { return .unrelated }
        guard candidates.count == 1, let row = candidates.first, row.text.utf8.count <= 480 else { return .withheld }
        let fields = row.text.replacingOccurrences(of: "؛", with: ";").components(separatedBy: ";")
        // printedPass here enables the explicit seat grammar, NOT a physical
        // classification. No pass OCR is merged with a barcode or another row.
        guard let reading = BoardingTextReading.read(lines: fields, confidence: row.confidence, kind: .printedPass,
            observedAt: capturedAt, observedMonotonic: capturedMonotonic, owner: owner),
              selectedFlight == nil || reading.flight == selectedFlight else { return .withheld }
        var controller = BoardingReadingController(); controller.select(owner); controller.selectTextSource(owner, primaryOwner: owner)
        guard let output = controller.prepareObservation(reading, currentOwner: owner, now: now,
              monotonicNow: monotonicNow, privateOutputAllowed: true),
              controller.deliver(output, currentOwner: owner, currentTextSource: owner, now: now,
                  monotonicNow: monotonicNow, privateOutputAllowed: true) != nil else { return .withheld }
        let details = [reading.gate.map { arabic ? "البوابة \($0)" : "gate \($0)" },
                       reading.seat.map { arabic ? "المقعد \($0)" : "seat \($0)" }].compactMap { $0 }.joined(separator: ", ")
        let text = arabic ? "النص الملتقط يذكر الرحلة \(reading.flight)، \(details). التاريخ والبوابة الحالية غير متحققين."
            : "Captured text lists flight \(reading.flight), \(details). Date and current gate unverified."
        return .answer(.init(receipt: output.receipt, text: text))
    }
    /// Quarantine only: normalization MUST NOT repair input for the strict parser.
    public static func isBoardingPayload(_ value: String) -> Bool {
        guard value.utf8.count <= BoardingPassParser.maximumBytes else { return true }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().hasPrefix("M")
    }
    public static func isTravelText(_ value: String) -> Bool {
        guard value.utf8.count <= 480 else { return true }
        return value.uppercased().range(of: "(?:FLIGHT|GATE|SEAT|الرحلة|رحلة|البوابة|بوابة|المقعد|مقعد)\\s*:", options: .regularExpression) != nil
    }
    /// Select a leg only from an explicit bounded flight designator, not time,
    /// destination, passenger identity, or an inferred current leg.
    public static func selectedFlight(in query: String) -> String? {
        guard query.utf8.count <= 600 else { return nil }
        let upper = query.uppercased()
        let pattern = "(?:FLIGHT|رحلة|الرحلة)\\s+([A-Z]{2}[0-9]{1,4}[A-Z]?)\\b"
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: upper, range: NSRange(upper.startIndex..., in: upper)),
              let range = Range(match.range(at: 1), in: upper) else { return nil }
        let all = expression.matches(in: upper, range: NSRange(upper.startIndex..., in: upper))
        guard all.count == 1 else { return nil }
        return String(upper[range])
    }
}
