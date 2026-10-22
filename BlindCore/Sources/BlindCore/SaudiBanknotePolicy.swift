import Foundation

/// Output filtering only. This is not a banknote recognition model or an accuracy guarantee.
public enum SaudiBanknotePolicy {
    /// Conservative lexical boundary to suppress common generic VLM/OCR cash claims.
    /// This can also hold back quoted prices; a dedicated verified price-reading path is
    /// preferable to letting a scene model bypass the banknote workflow.
    public static func containsUnverifiedMoneyValue(_ text: String) -> Bool {
        let money = #"(?i)\b(banknotes?|bank notes?|cash|currency|riyals?|sar|dollars?|usd|euros?|pounds?|bills?)\b|ريال|ريالات|نقود|عملة|دولار|فلوس|ورقة نقدية|[﷼$€£]"#
        let authenticity = #"(?i)\b(real|genuine|authentic|counterfeit|fake)\b|مزيفة|مزورة|أصلية"#
        let amount = #"(?i)[0-9٠-٩۰-۹]|\b(one|two|five|ten|twenty|fifty|hundred|thousand)\b|واحد|اثنان|خمسة|عشرة|عشرون|عشرين|خمسون|خمسين|مئة|مائة|مئتان|مائتان|ألف"#
        let bareValue = #"(?i)^\s*(?:(?:it is|it's|it’s|this is|the value is|worth)\s+)?(?:[0-9٠-٩۰-۹.,]+|(?:(?:one|two|five|ten|twenty|fifty|a|hundred|thousand)\s*)+)[.!؟?]?\s*$"#
        return (text.range(of: money, options: .regularExpression) != nil && (text.range(of: amount, options: .regularExpression) != nil || text.range(of: authenticity, options: .regularExpression) != nil))
            || text.range(of: bareValue, options: .regularExpression) != nil
    }
    public static func fresh(capturedAt: Double, now: Double) -> Bool {
        capturedAt.isFinite && now.isFinite && now >= capturedAt && now - capturedAt <= 2
    }
    public static let denominations: Set<Int> = [1, 5, 10, 20, 50, 100, 200, 500]
    public struct Detection: Sendable {
        public let scores: [Int: Double]
        public let unknownScore: Double
        public let x, y, width, height: Double
        public init(scores: [Int: Double], unknownScore: Double = 0, x: Double, y: Double, width: Double, height: Double) {
            self.scores = scores; self.unknownScore = unknownScore; self.x = x; self.y = y; self.width = width; self.height = height
        }
    }
    /// Must be calibrated on held-out physical notes for the exact model/export/device.
    /// No default confidence threshold is presented as safe for money.
    public struct Thresholds: Sendable {
        public let confidence, margin, minimumArea: Double
        public init(confidence: Double, margin: Double, minimumArea: Double) {
            self.confidence = confidence; self.margin = margin; self.minimumArea = minimumArea
        }
        var valid: Bool {
            [confidence, margin, minimumArea].allSatisfy { $0.isFinite && $0 > 0 && $0 <= 1 }
        }
    }
    public enum Result: Equatable, Sendable {
        case unknown, multiple, clipped, tooSmall, denomination(Int)
        public func speech(arabic: Bool) -> String {
            switch self {
            case .unknown: return arabic ? "لم أتعرف على قيمة الورقة. أظهر ورقة واحدة كاملة وحاول مرة أخرى." : "I couldn't identify the value. Show one whole banknote and try again."
            case .multiple: return arabic ? "أرى أكثر من ورقة محتملة. أظهر ورقة واحدة فقط." : "I detected more than one possible note. Show just one banknote."
            case .clipped: return arabic ? "الورقة قريبة من حافة الصورة. أظهر الورقة كاملة." : "The detected note touches the image boundary. Show the whole note."
            case .tooSmall: return arabic ? "الورقة صغيرة في الصورة. قرّبها من الكاميرا وحاول مرة أخرى." : "The detected note is small in the image. Bring it closer and try again."
            case .denomination(let value): return arabic ? "في هذه الصورة: \(value) ريال سعودي. هذا ليس فحصاً لأصالة الورقة." : "In this image: \(value) Saudi riyals. This is not an authenticity check."
            }
        }
    }
    public static func decide(_ detections: [Detection], thresholds: Thresholds) -> Result {
        guard thresholds.valid, detections.count <= 32 else { return .unknown }
        // The adapter must pass every candidate, not select the highest-confidence note.
        guard !detections.isEmpty else { return .unknown }
        for d in detections {
            guard [d.x, d.y, d.width, d.height].allSatisfy(\.isFinite),
                  d.x >= 0, d.y >= 0, d.width > 0, d.height > 0,
                  d.x + d.width <= 1.000001, d.y + d.height <= 1.000001,
                  d.unknownScore.isFinite, (0...1).contains(d.unknownScore),
                  !d.scores.isEmpty, Set(d.scores.keys).isSubset(of: denominations),
                  d.scores.values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return .unknown }
        }
        guard detections.count == 1 else { return .multiple }
        let d = detections[0]
        guard d.x > 0.02, d.y > 0.02, d.x + d.width < 0.98, d.y + d.height < 0.98 else { return .clipped }
        guard d.width * d.height >= thresholds.minimumArea else { return .tooSmall }
        // Full class scores are mandatory; a truncated top-label list cannot establish margin.
        guard Set(d.scores.keys) == denominations else { return .unknown }
        let ranked = d.scores.sorted { $0.value > $1.value }
        guard ranked[0].value >= thresholds.confidence,
              ranked[0].value >= max(ranked[1].value, d.unknownScore) + thresholds.margin else { return .unknown }
        return .denomination(ranked[0].key)
    }
}

/// Explicit request routing, never auto-announces cash or sums a scene.
public enum SaudiBanknoteCommand {
    public static func matches(_ text: String) -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".?!؟"))
        if ["identify money", "read money", "identify this banknote", "read this banknote",
                "what banknote is this", "what note is this", "identify saudi money", "read saudi money",
                "how much is this banknote", "اقرأ النقود", "اقرأ العملة", "ما قيمة هذه الورقة",
                "كم قيمة هذه الورقة", "تعرف على العملة", "اقرأ الفلوس"].contains(normalized) { return true }
        if normalized.range(of: #"(?i)\bdenomination\b|فئة العملة|فئة الورقة"#, options: .regularExpression) != nil { return true }
        if ["how much is this", "what is this worth", "what's this worth"].contains(normalized) { return true }
        let cash = #"(?i)\b(banknotes?|bank notes?|currency notes?|cash|money|bills?|notes?)\b|ورقة نقدية|العملة|النقود|الفلوس"#
        let request = #"(?i)\b(identify|read|count|sum|total|value|worth|denomination|what|which|how much|real|genuine|authentic|counterfeit|fake)\b|اقرأ|قيمة|كم|ما هي|تعرف"#
        return normalized.range(of: cash, options: .regularExpression) != nil && normalized.range(of: request, options: .regularExpression) != nil
    }
}
