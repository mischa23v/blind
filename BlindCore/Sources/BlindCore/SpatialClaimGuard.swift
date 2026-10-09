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
    private static let hazard = regex(#"\b(stairs?|staircase|stairway|steps|drop|drop-off|ledge|(platform|stair|step|curb|kerb|balcony|pool) edge|edge of (the |a )?(platform|stairs?|steps?|landing|balcony|pool|curb|kerb|drop)|curb|kerb|hole|obstacles?|obstruction|slope|ramp|escalator|platform|gap|threshold|hazard)\b"#)
    private static let spatial = regex(#"(\d|\b(left|right|ahead|behind|in front|forward|backwards?|o'?clock|away|close to you|near you|within|metres?|meters?|feet|foot|inches|yards|up|down|turn|walk|go|head|step|move|climb|descend|clear)\b)"#)
    private static let clearance = regex(#"\b((path|way|route|floor|hallway|corridor|stairs?)\s+(is|are|looks|seems)\s+(clear|free|safe|open)|safe to (walk|cross|go|move|step|climb)|nothing (is )?in (your|the) way|no obstacles?|clear (path|way|route))\b"#)
    private static let stepCount = regex(#"\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|a few|few|several|a couple of|couple of|a dozen)\s+(steps?|stairs?|paces?|strides?)\b"#)
    private static let distance = regex(#"(\b\d+([.,]\d+)?[\s-]*(m|cm|metres?|meters?|centimet(er|re)s?|feet|foot|ft|yards?)\b|\b(a|one|two|three|four|five|six|seven|eight|nine|ten|half a)[\s-]+(metres?|meters?|centimet(er|re)s?|feet|foot|yards?)\b)"#)
    private static let hedge = regex(#"\b(about|roughly|around|approximately|maybe|perhaps|possibly|probably|i think|seems?|looks|estimate[ds]?|or so)\b"#)
    private static let arHazard = regex("(درج|سلم|سلالم|حافه|عائق|عوائق|حفره|منحدر|عتبه|رصيف)")
    private static let arSpatial = regex("([0-9٠-٩]|يمين|يسار|امام|خلف|متر|خطو|بعد|اصعد|انزل|امش|تقدم)")
    private static let arClearance = regex("(الطريق خال|الممر خال|امن للمشي|لا توجد عوائق|لا يوجد عائق|الطريق امن)")
    private static let arStepCount = regex("(خطوه|خطوات|خطوتين)")
    private static let arDistance = regex(#"([0-9٠-٩]+\s*م(\s|$)|متر|امتار)"#)
    private static let arHedge = regex("(تقريبا|حوالي|ربما|اظن|يبدو|نحو)")

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
        for character in text {
            current.append(character)
            if ".!?؟;،\n".contains(character) { result.append(current); current = "" }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    public static func containsSpatialClaim(_ text: String) -> Bool {
        let arabic = normalizeArabic(text)
        if found(clearance, text) || found(stepCount, text) || found(arClearance, arabic) || found(arStepCount, arabic) { return true }
        return sentences(arabic).contains { sentence in
            (found(hazard, sentence) && found(spatial, sentence)) || (found(arHazard, sentence) && found(arSpatial, sentence)) ||
            (found(distance, sentence) && !found(hedge, sentence)) || (found(arDistance, sentence) && !found(arHedge, sentence))
        }
    }
}
