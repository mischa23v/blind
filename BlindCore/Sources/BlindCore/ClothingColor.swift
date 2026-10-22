import Foundation

/// Camera appearance only. These policies are deliberately NOT a fabric reflectance measurement,
/// a school-uniform certificate, or calibrated probabilities. No model chooses the spoken colour.
public enum ClothingColor {
    public struct RGB: Equatable, Sendable {
        public var r: Double, g: Double, b: Double
        public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
        public var isValid: Bool { [r, g, b].allSatisfy { $0.isFinite && (0...1).contains($0) } }
    }
    public struct Lab: Equatable, Sendable {
        public let l: Double, a: Double, b: Double
        public init(_ l: Double, _ a: Double, _ b: Double) { self.l = l; self.a = a; self.b = b }
        public var chroma: Double { hypot(a, b) }
    }
    public enum Name: String, CaseIterable, Sendable {
        case red, orange, yellow, green, blue, purple, pink, brown, turquoise
        public func localized(arabic: Bool) -> String {
            if !arabic { return rawValue }
            switch self {
            case .red: return "أحمر"; case .orange: return "برتقالي"; case .yellow: return "أصفر"
            case .green: return "أخضر"; case .blue: return "أزرق"; case .purple: return "بنفسجي"
            case .pink: return "وردي"; case .brown: return "بني"; case .turquoise: return "فيروزي"
            }
        }
    }
    public enum Result: Equatable, Sendable {
        case appearance(Name)
        case nearNeutral, darkNeutral, mixedOrUncertain, insufficientPixels
        public func speech(arabic: Bool) -> String {
            switch self {
            case .appearance(let name):
                return arabic ? "في اللقطة السابقة، بدت المنطقة المختارة بلون \(name.localized(arabic: true)) في هذه الإضاءة. هذا تقدير وليس تأكيداً للون القماش." : "In the captured view, the sampled area looked mostly \(name.rawValue) in this lighting. This is an estimate, not a confirmed fabric colour."
            case .nearNeutral:
                return arabic ? "لا أستطيع تأكيد الأبيض أو تمييزه عن الرمادي أو الكريمي في هذه الإضاءة. جرّب ضوء نهار متجانس. لا تعتمد على هذه القراءة لاختيار زي أبيض." : "I can't confirm white or reliably distinguish it from gray or cream in this lighting. Try even daylight. Don't rely on this reading to choose a white uniform."
            case .darkNeutral:
                return arabic ? "المنطقة تبدو داكنة ومحايدة في هذه الإضاءة، لكن الظل قد يخفي قماشاً أفتح. لا أستطيع تأكيد الأسود أو الرمادي. جرّب ضوءاً متجانساً." : "In the captured view, the area looked dark and neutral, but shadow can hide lighter fabric. I can’t confirm black or gray. Try even lighting."
            case .mixedOrUncertain:
                return arabic ? "اللون غير واضح أو مختلط. قرّب منطقة واحدة مسطحة من القماش إلى وسط الكاميرا بإضاءة متجانسة وأعد المحاولة." : "The colour is uncertain or mixed. Hold one flat area of fabric in the centre under even lighting and try again."
            case .insufficientPixels:
                return arabic ? "لا أرى منطقة واضحة كافية. ضع غرضاً واحداً في وسط الكاميرا وتجنب الظل واللمعان ثم أعد المحاولة." : "I don't have a clear enough area. Hold one item in the centre, avoid shadows and glare, then try again."
            }
        }
    }

    /// Standard IEC sRGB transfer and D65 XYZ → CIELAB, following the published colour-science
    /// reference operations. Not an illumination estimator. See research/CLOTHING_COLOR.md.
    public static func lab(_ rgb: RGB) -> Lab? {
        guard rgb.isValid else { return nil }
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let r = linear(rgb.r), g = linear(rgb.g), b = linear(rgb.b)
        let x = (0.4124564*r + 0.3575761*g + 0.1804375*b) / 0.95047
        let y = 0.2126729*r + 0.7151522*g + 0.0721750*b
        let z = (0.0193339*r + 0.1191920*g + 0.9503041*b) / 1.08883
        func f(_ v: Double) -> Double { v > 216.0/24389 ? pow(v, 1.0/3) : (24389.0/27*v + 16)/116 }
        return Lab(116*f(y)-16, 500*(f(x)-f(y)), 200*(f(y)-f(z)))
    }
    /// CIE76, not CIEDE2000. Euclidean Lab difference is only used for broad appearance candidates.
    public static func deltaE76(_ lhs: Lab, _ rhs: Lab) -> Double {
        sqrt(pow(lhs.l-rhs.l, 2) + pow(lhs.a-rhs.a, 2) + pow(lhs.b-rhs.b, 2))
    }
    private static let prototypes: [(Name, RGB)] = [
        (.red, RGB(0.83,0.18,0.18)), (.orange, RGB(0.93,0.42,0.01)),
        (.yellow, RGB(0.88,0.81,0.15)), (.green, RGB(0.22,0.56,0.24)),
        (.blue, RGB(0.10,0.46,0.82)), (.purple, RGB(0.48,0.12,0.64)),
        (.pink, RGB(0.85,0.42,0.62)), (.brown, RGB(0.55,0.28,0.12)),
        (.turquoise, RGB(0,0.59,0.65))
    ]
    private static let palette = prototypes.map { ($0.0, lab($0.1)!) }

    /// Input: ONLY interior selected-object sRGB pixels. Never give this an entire frame.
    /// Thresholds are conservative prototype policies, not validated accuracy claims.
    public static func evaluate(_ samples: [RGB]) -> Result {
        guard samples.count >= 64, samples.count <= 65_536, samples.allSatisfy(\.isValid) else { return .insufficientPixels }
        let valid = samples.filter { min($0.r,$0.g,$0.b) < 0.98 && max($0.r,$0.g,$0.b) > 0.025 }
        guard valid.count >= 64, Double(valid.count)/Double(samples.count) >= 0.90 else { return .insufficientPixels }
        let values = valid.compactMap(lab)
        // No amount of repeatability certifies neutral fabric under unknown illumination.
        let nearNeutralCount = values.filter { $0.chroma < 20 || ($0.l > 75 && $0.chroma < 38) }.count
        let lightness = values.map(\.l).sorted()
        let neutralFraction = Double(nearNeutralCount)/Double(values.count)
        if neutralFraction >= 0.20 {
            guard neutralFraction >= 0.85 else { return .mixedOrUncertain }
            return lightness[lightness.count/2] < 55 ? .darkNeutral : .nearNeutral
        }
        guard lightness[lightness.count*3/4] - lightness[lightness.count/4] < 25 else { return .mixedOrUncertain }
        var counts: [Name:Int] = [:]
        for value in values {
            let ranks = palette.map { ($0.0, deltaE76(value,$0.1)) }.sorted { $0.1 < $1.1 }
            // Wide-gamut/extreme colours and naming boundaries stay uncertain.
            if ranks[0].1 < 30, ranks[1].1-ranks[0].1 >= 5 { counts[ranks[0].0, default:0] += 1 }
        }
        guard let best = counts.max(by: { $0.value < $1.value }), Double(best.value)/Double(samples.count) >= 0.85 else { return .mixedOrUncertain }
        return .appearance(best.key)
    }
}

/// Explicit requests only. Naming an item "white shirt" is not a request to measure it.
public enum ClothingColorCommand {
    private static func normalizedWords(_ text: String) -> [String] {
        let folded = text.lowercased().folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).decomposedStringWithCanonicalMapping
        let clean = String(String.UnicodeScalarView(folded.unicodeScalars.filter { !CharacterSet.nonBaseCharacters.contains($0) }))
        return clean.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
    public static func matches(_ text: String) -> Bool {
        let words = normalizedWords(text)
        let tokens = Set(words)
        guard tokens.isDisjoint(with: ["not", "don", "dont", "never", "stop", "cancel", "لا", "توقف", "الغ", "إلغاء"]) else { return false }
        var phrase = words.joined(separator: " ")
        let prefixes = ["please ", "can you ", "could you ", "من فضلك ", "لو سمحت "]
        for _ in 0..<4 { if let prefix = prefixes.first(where: { phrase.hasPrefix($0) }) { phrase.removeFirst(prefix.count) } else { break } }
        guard tokens.isDisjoint(with: ["المفضل", "مفضل", "المفضلة", "مفضلة"]) else { return false }
        let colourWords = ["color", "colour", "colors", "colours"]
        if !tokens.isDisjoint(with: colourWords) {
            guard tokens.isDisjoint(with: ["settings", "setting", "word", "words", "favorite", "favourite", "name"]) else { return false }
            if ["what color is ", "what colour is ", "what is the color of ", "what is the colour of ", "what s the color of ", "what s the colour of "].contains(where: { phrase.hasPrefix($0) }) { return true }
            for verb in ["check", "identify", "read", "tell me"] {
                for colour in colourWords {
                    for article in ["", "the "] {
                        let command = verb + " " + article + colour
                        if phrase == command || phrase.hasPrefix(command + " of ") { return true }
                    }
                }
            }
        }
        if requiresNeutralVerification(phrase),
           ["is this ", "is it ", "does this ", "does it ", "can i use this ", "can i wear this ", "would this ", "will this ", "check ", "confirm "]
            .contains(where: { phrase.hasPrefix($0) }) { return true }
        let neutralWords = ["white", "gray", "grey", "cream", "ivory", "offwhite"]
        if ["is this ", "is it ", "does this look ", "does it look ", "check if this is ", "confirm if this is "].contains(where: { phrase.hasPrefix($0) }),
           neutralWords.contains(where: { phrase.hasSuffix(" " + $0) }) { return true }
        return ["ما لون ", "ما هو لون ", "ما هو اللون", "ما اللون", "ما لونه", "ما لونها", "وش لونه", "وش لونها", "افحص اللون", "حدد اللون", "اقرا اللون", "اقرأ اللون", "هل هذا ابيض", "هل هذا أبيض", "هل هذه بيضاء", "هل القميص ابيض", "هل القميص أبيض"]
            .contains { let base = $0.trimmingCharacters(in: .whitespaces); return phrase == base || phrase.hasPrefix(base + " ") }
    }
    /// Even white cloth can look saturated under coloured light. A precise neutral/white request
    /// always gets an abstention, regardless of which appearance candidate the camera produced.
    public static func requiresNeutralVerification(_ text: String) -> Bool {
        let precise = Set(["white", "gray", "grey", "cream", "ivory", "offwhite", "uniform", "ابيض", "بيضاء", "بيضا", "رمادي", "رمادية", "كريمي", "كريمية", "زي", "مدرسة", "مدرسي", "مدرسية"])
        return normalizedWords(text).contains { word in
            precise.contains(word) || (word.hasPrefix("ال") && precise.contains(String(word.dropFirst(2))))
        }

    }
    /// Veto for common colour claims in model-written descriptions. Does not alter quoted OCR text.
    public static func containsUnverifiedColorClaim(_ text: String) -> Bool {
        let colours = Set(["white", "black", "gray", "grey", "cream", "ivory", "offwhite", "red", "orange", "yellow", "green", "blue", "purple", "pink", "brown", "turquoise", "beige", "navy", "teal", "cyan", "magenta", "silver", "gold", "ابيض", "بيضاء", "بيضا", "اسود", "سوداء", "رمادي", "رمادية", "كريمي", "كريمية", "احمر", "حمراء", "برتقالي", "برتقالية", "اصفر", "صفراء", "اخضر", "خضراء", "ازرق", "زرقاء", "بنفسجي", "بنفسجية", "وردي", "وردية", "بني", "بنية", "فيروزي", "فيروزية", "بيج", "كحلي", "كحلية"])
        return normalizedWords(text).contains { word in
            if colours.contains(word) { return true }
            for prefix in ["ال", "وال", "و", "بال"] where word.hasPrefix(prefix) {
                if colours.contains(String(word.dropFirst(prefix.count))) { return true }
            }
            return false
        }
    }

}

public enum ClothingColorCapturePolicy {
    public static let maximumAge: Double = 4
    public static func fresh(capturedAt: Double, now: Double) -> Bool {
        capturedAt.isFinite && now.isFinite && capturedAt >= 0 && now >= capturedAt && now-capturedAt <= maximumAge
    }
    public static func poseStable(origin: Point3, current: Point3, originForward: Point3, currentForward: Point3) -> Bool {
        RequestedVisualCapturePose.poseStable(origin: origin, current: current, originForward: originForward, currentForward: currentForward)
    }

}
