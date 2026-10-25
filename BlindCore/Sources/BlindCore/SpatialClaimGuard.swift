import Foundation

/// Model-authored physical geometry and physical-action guidance is withheld, including
/// everyday objects and hedged estimates. Fresh typed measurements are rendered by code,
/// never authorized by a model's confidence, quotation, or claim that a sensor confirmed it.
/// This lexical defense is deliberately conservative, NOT a semantic safety certificate.
/// The child physical-guidance route must fail closed independently of model prose.
/// Mirrors server/src/spatial-guard.mjs and the shared spatial-claims.json fixture.
public enum SpatialClaimGuard {
    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Patterns are constants covered by the shared fixture tests.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
    // "edge" alone is everyday description (the edge of a screen); only drop edges count as hazards.
    private static let hazard = regex(#"\b(stairs?|staircases?|stairways?|steps?|doorsteps?|drops?|drop[\s-]?offs?|ledges?|potholes?|manholes?|poles?|bollards?|branch(?:es)?|head height|low ceilings?|(platform|stair|step|curb|kerb|balcony|pool) edge|edge of (the |a )?(platform|stairs?|steps?|landing|balcony|pool|curb|kerb|drop)|curbs?|kerbs?|holes?|obstacles?|obstructions?|slopes?|ramps?|escalators?|platforms?|gaps?|thresholds?|hazards?)\b"#)
    private static let spatial = regex(#"(\d|\b(left|right|ahead|behind|in front|forward|backwards?|o'?clock|away|close to you|near you|within|metres?|meters?|feet|foot|inches|yards|up|down|turn|walk|go|head|step|move|climb|descend|clear|above|below|high|height|tall|deep|depth|steep|shallow|ascending|descending|upward|downward|uphill|downhill|upstairs|downstairs|elevated|lower|higher|long|wide|narrow)\b)"#)
    private static let clearance = regex(#"\b((path|way|route|floor|hallway|corridor|walkway|passage|stairs?|street|road|crossing|crosswalk|intersection)\s+(?:(?:ahead|in front of you|to the door)\s+)?(?:(?:is|are|looks?|seems?|appears?|remains?)\s+)?(?:(?:completely|entirely|perfectly|totally|apparently|probably|now|all)\s+)*(clear|free|safe|open|unobstructed|passable|traversable|navigable)|(?:safe|safely)\s+(?:to\s+)?(?:walk|cross|go|move|step|climb|proceed|continue)|(?:walk|cross|go|move|step|climb|proceed|continue)\s+(?:(?:ahead|forward|onward)\s+)?safely|nothing(?:'s|\s+is)?\s+(?:in (?:your|the) way|block\w*|in front of you|ahead|on the floor)|no (?:obstacles?|obstructions?|hazards?|stairs?|steps?|drops?|curbs?|kerbs?|holes?|cars?|traffic|vehicles?)|(?:don't|do not|can't|cannot) see any (?:obstacles?|obstructions?|hazards?|stairs?|steps?|drops?|curbs?|kerbs?|holes?|cars?)|clear to (?:cross|walk|go)|cross now|cars? (?:are |is )?(?:not )?coming|it(?:'s|\s+is) (?:all )?clear|(?:clear|unobstructed|safe|passable) (?:path|way|route|passage|corridor)|free (?:of|from) (?:obstacles?|obstructions?|hazards?)|(?:all clear|clear ahead)|without (?:any )?(?:obstacles?|obstructions?|risk|danger))\b"#)
    private static let stepCount = regex(#"\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|a few|few|several|a couple of|couple of|a dozen|a|an|a single|single)\s+(?:(?:small|little|big|short|tall|low|high)\s+)?(steps?|stairs?|paces?|strides?)\b"#)
    private static let distance = regex(#"(\b\d+([.,]\d+)?[\s-]*(m|cm|metres?|meters?|centimet(er|re)s?|feet|foot|ft|yards?)\b|\b(a|one|two|three|four|five|six|seven|eight|nine|ten|half a)[\s-]+(metres?|meters?|centimet(er|re)s?|feet|foot|yards?)\b|\b(one|two|three|four|five|six|seven|eight|nine|ten)\s+and\s+a\s+half\s+(metres?|meters?|feet|foot|yards?)\b)"#)
    private static let arHazard = regex(#"(درج|سلم|سلالم|حافه|حواف|عائق|عوائق|حفره|حفر|منحدر|عتبه|رصيف|ارصفه|عقبه|عقبات|هاويه|سقوط|فجوه)"#)
    private static let arSpatial = regex(#"([0-9٠-٩]|يمين|يسار|امام|خلف|اسفل|اعلي|متر|خطو|بعد|اصعد|انزل|امش|تقدم|فوق|تحت|عال|مرتفع|ارتفاع|عمق|عميق|ضحل|حاد|صاعد|هابط|قريب|بعيد|طويل|عرض|عريض|ضيق)"#)
    private static let arClearance = regex(#"((الطريق|الممر|المسار|الارضيه)\s+(?:(?:يبدو|يظهر|هو|تماما)\s+)*(خال|خالي|امن|مفتوح|سالك)|امن\s+(للمشي|للعبور|للتقدم)|بامان|لا\s+(توجد|يوجد)\s+(اي\s+)?(عوائق|عائق|عقبات|خطر)|دون\s+(عوائق|عائق|خطر)|خالي\s+من\s+(العوائق|العقبات)|لا\s+(?:شيء|شي)\s+(?:امامك|قدامك)|ما\s+في\s+(?:شيء|شي)\s+(?:امامك|قدامك))"#)
    private static let arStepCount = regex(#"(خطوه|خطوات|خطوتين|درجتين|[0-9٠-٩]+\s*درج|(?:ثلاث|اربع|خمس|ست|سبع|ثماني|تسع|عشر|عده|بضع)\s+درج)"#)
    private static let arDistance = regex(#"([0-9٠-٩]+\s*م(\s|$)|متر|امتار)"#)

    // Quotations and negations are not stripped: untrusted physical words remain blocked.
    private static let direction = regex(#"\b((?:top|bottom|upper|lower) (?:corner|edge)|ahead|behind|above|below|underneath|beside|next to|in front of|nearby|overhead|north|south|east|west|northwest|northeast|southwest|southeast|clockwise|counterclockwise|anticlockwise|forward|backwards?|towards?|upstairs|downstairs)\b|\b(?:to|on|at|from|toward|towards)\s+(?:(?:your|my|the|its|their)\s+)?(?:far\s+)?(?:left|right)\b|\b(?:left|right)[ -](?:hand|side|edge|corner)\b|\b(?:is|seems|appears|looks)\s+(?:(?:roughly|probably|slightly|just)\s+)*(?:left|right)\b|^\s*(?:(?:roughly|maybe|probably|slightly|just|go|turn)\s+)*(?:left|right)\s*[.!?,;]*\s*$|\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|[0-9]+)\s*o['’]?clock\b"#)
    private static let objectRelation = regex(#"\b(?:on|in|under|over|near|by|against|inside|outside|between|across|past|along)\s+(?:(?:the|a|an|your|my|this|that|its|their)\s+)?(?:(?:small|large|wooden|white|black|red|blue|green|open|closed|nearest|farther|left|right)\s+){0,3}(?:desk|table|sofa|couch|bed|chair|door|window|wall|floor|shelf|cabinet|cupboard|drawer|counter|nightstand|lamp|screen|television|tv|socket|outlet|bench|stove|oven|sink|knife|cup|mug|bottle|plate|bag|box|handle|hand|arm|foot|feet|body|person|people|car|road|street|stairs?|step|curb|kerb|hole|obstacle)\b|\b(?:near|close to|far from|away from|next to|within reach of)\s+(?:you|me|your|my)\b|\b(?:within|in|out of|beyond)\s+(?:(?:your|easy|safe|arm['’]?s)\s+)*(?:reach|fingertips?|hands?)\b|\b(?:reachable|graspable|nearest|closest|closer|nearer|farther|close enough|easy to reach|safe to (?:touch|hold|grab|pick up|reach))\b"#)
    private static let physicalAction = regex(#"\b(?:walk|go|approach|follow|reach|grab|grasp|touch|climb|descend|crawl|crouch|bend|lean|stretch(?:ing)?|extend(?:ing)?|lift|pull|push|press|squeez(?:e|ing)|swing|jump|run|cross|proceed|advance|retreat|rotate|tilt|turn(?:ing)?|move|step|pick|pick[ -]?up|pick\s+(?:it|that|this|them)\s+up)\b|\b(?:take|hold|handle|cut|open|close|eat|drink|taste|smell|put|place|set|bring|carry|light|heat)\s+(?:(?:the|a|an|your|this|that|it|them|one|both)\b|[a-z]+\s+(?:knife|cup|mug|bottle|door|drawer|medicine|food)\b)|\b(?:keep|start|begin|continue)\s+(?:walking|moving|reaching|climbing|running|touching|holding|turning)\b"#)
    private static let arDirection = regex(#"(يمين|يسار|شمال|جنوب|شرق|غرب|امام|قدام|خلف|وراء|ورا[يكه]|فوق|تحت|اسفل|اعلي|بجانب|بجوار|جنب|قرب|قريب|اقرب|بعيد|بينك|بين يديك|في متناول|متناول يد|في اتجاه|باتجاه)"#)
    private static let arObjectRelation = regex(#"(?:علي|على|داخل|خارج|عند|بين|حول)\s+(?:ال|هذا |هذه |تلك |ذلك )?(?:مكتب|طاول|سرير|اريك|كنب|كرسي|باب|نافذ|حائط|جدار|ارض|رف|خزان|درج|مصباح|شاش|تلفاز|مقبض|يد|ذراع|قدم|جسم|شخص|سيار|طريق|سكين|كوب|زجاج|حقيب)|(?:يمكنك|تقدر|تستطيع)\s+(?:الوصول|الامساك|التقاط|اخذ|اخذه|اخذها|لمس)"#)
    private static let arPhysicalAction = regex(#"(?:^|[\s،؛.!؟:«»"'()])(?:و|ف)?(?:امش(?:ي)?|روح|سر|اقترب|اقربي|اتبع|اتبعي|تبع|الحق|امسك(?:ه|ها|يه|يها)?|التقط(?:ه|ها)?|التقطي|خذ(?:ه|ها|يه|يها)?|خدي|المس(?:ه|ها)?|المسي|تسلق|اصعد|انزل|اقفز|ازحف|انحن|ميل|مل|مد(?:ي)?|مدد|ارفع(?:ه|ها)?|ارفعى|اسحب(?:ه|ها)?|ادفع(?:ه|ها)?|اضغط|اضغطي|لف|لفي|ادر|دور|دوري|حرك(?:ه|ها)?|تقدم|تراجع|اعبر|اقطع|افتح(?:ه|ها)?|اغلق(?:ه|ها)?|ضع(?:ه|ها)?|حط(?:ه|ها)?|كل|اشرب|ذق|شم)(?:[\s،؛.!؟:«»"'()]|$)|(?:يمكنك|يمكن|تقدر|تستطيع|حاول|جرب)\s+(?:ان\s+)?(?:تمشي|تقترب|تتبع|توصل|تطول(?:ه|ها)?|تلف|تدور|تمسك(?:ه|ها)?|تاخذ(?:ه|ها)?|تلمس(?:ه|ها)?|تتسلق|تصعد|تنزل|تمد|تحرك|تفتح|تغلق|تاكل|تشرب)"#)

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
        // "\r\n" is one Character in Swift; normalise it so splitting matches the Node mirror.
        let characters = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))
        let ascii = { (c: Character) in c.isASCII && c.isNumber }
        for (index, character) in characters.enumerated() {
            current.append(character)
            let decimalPoint = character == "." && index > 0 && index + 1 < characters.count
                && ascii(characters[index - 1]) && ascii(characters[index + 1])
            if ".!?؟;؛،\n".contains(character) && !decimalPoint { result.append(current); current = "" }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Whether the text names a hazard at all (used to keep "a hazard is visible" when the
    /// model's geometry for it is withheld).
    public static func mentionsHazard(_ text: String) -> Bool {
        let arabic = normalizeArabic(text)
        return found(hazard, arabic) || found(arHazard, arabic)
    }

    public static func containsSpatialClaim(_ text: String) -> Bool {
        // Treat hyphenated phrases like their spoken equivalents so separators
        // cannot hide a relation (e.g. "in-front-of" is still physical geometry).
        let canonical = text.replacingOccurrences(of: #"[-‐‑‒–—−]+"#, with: " ", options: .regularExpression)
        // Only a scientific subject AND bounded scientific complement disambiguate
        // "bend". Replace that verb, not the sentence or quotations: every other
        // movement, location, distance and current-world claim remains inspected.
        let science = regex(#"\b((?:(?:different|visible)\s+)?(?:wavelengths|light rays|rays of light)\s+)bend(\s+(?:(?:by|at)\s+different\s+(?:amounts|angles)|when\s+they\s+pass\s+through\s+(?:water|glass|a prism)))(?=\s*(?:[.!?;,]|$)|\s+(?:in|through)\s+(?:water droplets|a prism)\s*(?:[.!?;,]|$))"#)
            .stringByReplacingMatches(in: canonical, range: NSRange(canonical.startIndex..., in: canonical), withTemplate: "$1refract$2")
        // Remove only fixed conversational idioms, never quoted regions or whole clauses.
        // Any later physical claim in the same response is still checked.
        let prose = regex(#"\b(?:take your time|move on to (?:another|the next) (?:topic|question|subject))\b|(?:^|\s)خذ وقتك(?=[\s.!؟،]|$)"#)
            .stringByReplacingMatches(in: science, range: NSRange(science.startIndex..., in: science), withTemplate: "")
        let arabic = normalizeArabic(prose)
        if found(direction, prose) || found(objectRelation, prose) || found(physicalAction, prose) ||
            found(arDirection, arabic) || found(arObjectRelation, arabic) || found(arPhysicalAction, arabic) ||
            found(clearance, canonical) || found(stepCount, canonical) || found(arClearance, arabic) || found(arStepCount, arabic) { return true }
        // Conservative lexical defense, not a semantic safety proof. Preserve hazard
        // context across punctuation; ambiguous pronoun locations fail closed.
        let hasHazard = found(hazard, arabic) || found(arHazard, arabic)
        return sentences(arabic).contains { sentence in
            (found(hazard, sentence) && found(spatial, sentence)) || (found(arHazard, sentence) && found(arSpatial, sentence)) ||
            (hasHazard && ((found(reference, sentence) && found(spatial, sentence)) || (found(arReference, sentence) && found(arSpatial, sentence)))) ||
            found(distance, sentence) || found(arDistance, sentence)
        }
    }
}
