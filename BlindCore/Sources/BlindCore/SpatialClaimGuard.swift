import Foundation

/// Spatial safety rule (AGENTS.md, task E13). Hazard geometry — stairs, steps, drops, edges,
/// curbs, holes, obstacles: distance, direction, step count, height, clear-path — comes only
/// from sensors. Step counts come only from code calibrated to the person. Model distances for
/// everyday objects must be worded as estimates; sensor facts rendered by code are spoken
/// confidently and are not passed through this check.
/// Mirrors server/src/spatial-guard.mjs; both run Tests/BlindCoreTests/Fixtures/spatial-claims.json.
public enum SpatialClaimGuard {
    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Patterns are constants covered by the shared fixture tests.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
    // "edge" alone is everyday description (the edge of a screen); only drop edges count as hazards.
    private static let hazard = regex(#"\b(stairs?|staircases?|stairways?|steps|drop|drop-off|ledges?|(platform|stair|step|curb|kerb|balcony|pool) edge|edge of (the |a )?(platform|stairs?|steps?|landing|balcony|pool|curb|kerb|drop)|curbs?|kerbs?|holes?|obstacles?|obstructions?|slopes?|ramps?|escalators?|platforms?|gaps?|thresholds?|hazards?)\b"#)
    private static let spatial = regex(#"(\d|\b(left|right|ahead|behind|in front|forward|backwards?|o'?clock|away|close to you|near you|within|metres?|meters?|feet|foot|inches|yards|up|down|turn|walk|go|head|step|move|climb|descend|clear|above|below|high|height|tall|deep|depth|steep|shallow|ascending|descending|upward|downward|uphill|downhill|upstairs|downstairs|elevated|lower|higher|long|wide|narrow)\b)"#)
    private static let clearance = regex(#"\b((path|way|route|floor|hallway|corridor|walkway|passage|stairs?)\s+(?:(?:ahead|in front of you|to the door)\s+)?(?:(?:is|are|looks?|seems?|appears?|remains?)\s+)?(?:(?:completely|entirely|perfectly|totally|apparently|probably|now|all)\s+)*(clear|free|safe|open|unobstructed|passable|traversable|navigable)|(?:safe|safely)\s+(?:to\s+)?(?:walk|cross|go|move|step|climb|proceed|continue)|(?:walk|cross|go|move|step|climb|proceed|continue)\s+(?:(?:ahead|forward|onward)\s+)?safely|nothing (?:is )?(?:in (?:your|the) way|blocking)|no (?:obstacles?|obstructions?|hazards?)|(?:clear|unobstructed|safe|passable) (?:path|way|route|passage|corridor)|free (?:of|from) (?:obstacles?|obstructions?|hazards?)|(?:all clear|clear ahead)|without (?:any )?(?:obstacles?|obstructions?|risk|danger))\b"#)
    private static let stepCount = regex(#"\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|a few|few|several|a couple of|couple of|a dozen)\s+(steps?|stairs?|paces?|strides?)\b"#)
    private static let distance = regex(#"(\b\d+([.,]\d+)?[\s-]*(m|cm|metres?|meters?|centimet(er|re)s?|feet|foot|ft|yards?)\b|\b(a|one|two|three|four|five|six|seven|eight|nine|ten|half a)[\s-]+(metres?|meters?|centimet(er|re)s?|feet|foot|yards?)\b)"#)
    private static let hedge = regex(#"\b(about|roughly|around|approximately|maybe|perhaps|possibly|probably|i think|seems?|looks|estimate[ds]?|or so)\b"#)
    private static let arHazard = regex(#"(درج|سلم|سلالم|حافه|حواف|عائق|عوائق|حفره|حفر|منحدر|عتبه|رصيف|ارصفه|عقبه|عقبات|هاويه|سقوط|فجوه)"#)
    private static let arSpatial = regex(#"([0-9٠-٩]|يمين|يسار|امام|خلف|متر|خطو|بعد|اصعد|انزل|امش|تقدم|فوق|تحت|عال|مرتفع|ارتفاع|عمق|عميق|ضحل|حاد|صاعد|هابط|قريب|بعيد|طويل|عرض|عريض|ضيق)"#)
    private static let arClearance = regex(#"((الطريق|الممر|المسار|الارضيه)\s+(?:(?:يبدو|يظهر|هو|تماما)\s+)*(خال|خالي|امن|مفتوح|سالك)|امن\s+(للمشي|للعبور|للتقدم)|بامان|لا\s+(توجد|يوجد)\s+(اي\s+)?(عوائق|عائق|عقبات|خطر)|دون\s+(عوائق|عائق|خطر)|خالي\s+من\s+(العوائق|العقبات))"#)
    private static let arStepCount = regex(#"(خطوه|خطوات|خطوتين)"#)
    private static let arDistance = regex(#"([0-9٠-٩]+\s*م(\s|$)|متر|امتار)"#)
    private static let arHedge = regex(#"(تقريبا|حوالي|ربما|اظن|يبدو|نحو)"#)

    private static let reference = regex(#"(?:\b(it|its|they|them|their|this|that|these|those|there)\b|^\s*(?:roughly|about|approximately|around|ahead|behind|to (?:your|the) (?:left|right))\b)"#)

    private static let arReference = regex(#"(هو|هي|انه|انها|انهم|هذا|هذه|ذلك|تلك|هناك|يبعد|تبعد|تقع|يقع|ارتفاعه|عمقها|^\s*(تقريبا|حوالي|امام|خلف|يمين|يسار))"#)

    private static func found(_ pattern: NSRegularExpression, _ text: String) -> Bool {
        pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    public static func normalizeArabic(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x064B...0x0652, 0x0640: continue
            case 0x0622, 0x0623, 0x0625: scalars.append(Unicode.Scalar(0x0627)!)
            case 0x0629: scalars.append(Unicode.Scalar(0x0647)!)
            default: scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    static func sentences(_ text: String) -> [String] {
        var result: [String] = [], current = ""
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            current.append(character)
            let decimalPoint = character == "." && index > 0 && index + 1 < characters.count
                && characters[index - 1].isNumber && characters[index + 1].isNumber
            if ".!?؟;؛،\n".contains(character) && !decimalPoint { result.append(current); current = "" }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    public static func containsSpatialClaim(_ text: String) -> Bool {
        let arabic = normalizeArabic(text)
        if found(clearance, text) || found(stepCount, text) || found(arClearance, arabic) || found(arStepCount, arabic) { return true }
        // Conservative lexical defense, not a semantic safety proof. Preserve hazard
        // context across punctuation; ambiguous pronoun locations fail closed.
        let hasHazard = found(hazard, arabic) || found(arHazard, arabic)
        return sentences(arabic).contains { sentence in
            (found(hazard, sentence) && found(spatial, sentence)) || (found(arHazard, sentence) && found(arSpatial, sentence)) ||
            (hasHazard && ((found(reference, sentence) && found(spatial, sentence)) || (found(arReference, sentence) && found(arSpatial, sentence)))) ||
            (found(distance, sentence) && !found(hedge, sentence)) || (found(arDistance, sentence) && !found(arHedge, sentence))
        }
    }
}
