import Foundation

/// A request-scoped boundary between ordinary chat and dedicated physical
/// inspection. A model cannot satisfy an inspection by emitting a bare colour,
/// number, or yes/no answer. This gate does not ban these words in ordinary chat.
/// Lexical recognition is deliberately bounded; it is not a semantic classifier
/// or evidence that a camera, banknote model, or colour measurement is available.
public enum ConversationDomainPolicy {
    public enum Inspection: String, Equatable, Sendable {
        case clothingColor, banknote
    }

    public static func requiredInspection(for question: String) -> Inspection? {
        // Cash takes priority when an inspection mentions a banknote's colour.
        if requiresBanknoteInspection(question) { return .banknote }
        if ClothingColorCommand.matches(question) { return .clothingColor }
        return nil
    }

    /// Apply before inference and again before any streamed/displayed/spoken
    /// model answer. A recognized request has no model-answer exception, even
    /// if the dedicated tool is unavailable, fails, or asks for another capture.
    public static func allowsModelResponse(to question: String) -> Bool {
        requiredInspection(for: question) == nil && !requiresPhysicalVerification(for: question)
            && !requiresLiveTemperature(for: question)
    }

    /// No weather service or thermometer is implied by a camera or language
    /// model. These bounded current-temperature requests require a real source.
    public static func requiresLiveTemperature(for question: String) -> Bool {
        let text = normalizedPhysicalRequest(question)
        func has(_ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
        let current = has(#"\b(?:current|currently|now|today|here|outside|indoors|outdoors)\b|\bmy (?:body )?(?:temperature|temp)\b|\btemperature (?:of|in) (?:this|that|my)\b|(?:^| )(?:الان|الحين|اليوم|هنا|برا|بره|الخارج|الغرفه|الجو|جسمي|حرارتي)(?: |$)|(?:^| )حراره (?:هذا|هذه)(?: |$)"#)
        let temperature = has(#"\b(?:temperature|temp|temprature|temperture|tempreture|tempature|degrees)\b|(?:^| )(?:الحراره|حراره|حرارتي|درجه|درجات)(?: |$)"#)
        if current && temperature { return true }
        // A named-place lookup (including common speech/spelling variants) needs
        // an actual weather/thermometer source, not camera or model inference.
        // Exclude bounded scientific complements, not entire mixed requests.
        let temperatureWord = #"(?:temperature|temp|temprature|temperture|tempreture|tempature)"#
        let scientificPlace = #"(?!(?:(?:a|an|the) )?(?:ideal gas|gas law|vacuum|experiment|equation|physics|science|thermodynamics|kelvin|celsius|fahrenheit|math|homework|boiling|freezing)\b)"#
        if has(#"^(?:(?:what is|what s|whats|tell me|check) (?:the )?)?(?:the )?"# + temperatureWord
            + #" (?:in|at|for) "# + scientificPlace + #"[a-z]+(?: [a-z]+){0,4}$"#)
            || has(#"^(?:(?:كم|ما|وش|ايش) )?(?:درجه )?(?:الحراره|حراره) (?:في|ب) (?!(?:الفيزياء|العلوم|الديناميكا|الغاز المثالي|الفراغ|التجربه|المعادله|واجب)\b)\p{L}+(?: \p{L}+){0,4}$"#)
            || has(#"^(?:(?:كم|ما|وش|ايش) )?(?:درجه )?(?:الحراره|حراره) بالخبر$"#) { return true }
        if has(#"\b(?:how hot|how cold) is it\b|\b(?:is|are) (?:(?:this|that|my)(?: [a-z]+){0,4}|it) (?:too )?(?:hot|cold|warm|freezing)\b|(?:^| )هل (?:(?:هذا|هذه)(?: \p{L}+){0,3}|هو|هي) (?:حار|حاره|بارد|بارده|ساخن|ساخنه)(?: |$)"#) { return true }
        return ["what is the temperature", "what s the temperature", "whats the temperature", "what is the temp", "what s the temp",
                "what temperature is it", "tell me the temperature", "كم الحراره", "كم درجه الحراره", "ما درجه الحراره", "وش درجه الحراره"].contains(text)
    }

    private static func normalizedPhysicalRequest(_ question: String) -> String {
        let normalized = SpatialClaimGuard.normalizeArabic(question.lowercased())
            .replacingOccurrences(of: "ى", with: "ي").replacingOccurrences(of: "’", with: "'")
        return normalized.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Explicit current-world reach/movement questions cannot be answered by a
    /// model, even with "maybe" or a warning. They require a separately validated
    /// identity AND position for that specific target. This bounded lexical gate
    /// does not establish either prerequisite or claim semantic completeness.
    public static func requiresPhysicalVerification(for question: String) -> Bool {
        // An exact language-analysis frame quotes text to discuss, not execute.
        // This is request-only: model outputs still pass all physical/evidence
        // guards. Mixed clauses and instructions outside the quote do not qualify.
        if isQuotedLanguageQuestion(question) { return false }
        if RoadCrossingPolicy.requiresCodeOwnedReply(question) { return true }
        let text = normalizedPhysicalRequest(question)
        guard !text.isEmpty else { return false }
        func has(_ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
        // Local object/person presence also needs evidence. Keep these concrete
        // forms bounded; history and general facts about these subjects remain chat.
        if has(#"^(?:please |can you tell me |tell me )?(?:where (?:is|are)|where s|wheres|wher is) (?:my |the |this |that )?(?:cane|cup|shoes|shose|mom|mum|mother|apples?|milk|it|they|them)(?: now| right now)?$"#)
            || has(#"^(?:اين|وين|فين) (?:عصاي|العصا|كوبي|الكوب|حذائي|الحذاء|امي|ماما|التفاح|تفاح|الحليب|حليب|اللبن|هو|هي|هم)(?: الان| الحين)?$|^(?:وينه|وينها|فينه|فينها)(?: الان| الحين)?$"#) { return true }
        let fridge = has(#"\b(?:fridge|refrigerator)\b|(?:^| )(?:الثلاجه|التلاجه|ثلاجتي)(?: |$)"#)
        let food = has(#"\b(?:apples?|milk)\b|(?:^| )(?:تفاح|التفاح|حليب|الحليب|لبن|اللبن)(?: |$)"#)
        let presence = has(#"\b(?:is there|are there|there s|do i have|do we have|is the|are the|where is|where are|where s|wheres|wher is)\b|^(?:هل|في|فيه|يوجد|توجد|عندي|اين|وين|فين)(?: |$)"#)
        if fridge && food && presence { return true }
        // Exclusions are attached to the particular verb/complement, not a whole
        // message containing "homework". A later local movement request still wins.
        let reach = #"reach(?! (?:my |our |your |a |the )?(?:goals?|conclusion|agreement|audience|potential|decision)\b)"#
        let follow = #"follow(?! (?:my |our |your |a |the |these |those |this )?(?:reasoning|logic|argument|instructions?|recipe|steps? in|story|lesson|accounts?|channel)\b)"#
        let pickup = #"(?:pick up(?! (?:a |the |some )?(?:language|french|english|arabic|spanish|skill|habit|signal)\b)|pick (?:(?:this|that|the|my) )?[a-z]+ up)"#
        let action = #"(?:"# + reach + "|" + follow + "|" + pickup + #"|touch(?! on)|grab|lift|approach(?! (?:the |this |a )?(?:problem|equation|topic)\b)|climb(?! (?:the |a )?career ladder)|cross(?! multiply)|step(?! through)|turn(?! (?:this |that |it )?into)|walk(?! me through)|go(?! on\b| over\b)|get (?:to|near|closer|across|up|down)|put (?:my|the) (?:hand|foot)|move(?! (?:the |this |a )?(?:point|decimal|variable|term|number)\b)|proceed)"#
        let hedge = #"(?:(?:maybe|perhaps|possibly|roughly|approximately|just|safely|carefully|now|try to|try and|start to) )*"#
        if has(#"\b(?:can|could|may|should|shall|must|would|do) (?:i|we) "# + hedge + action + #"\b"#)
            || has(#"\b(?:maybe|perhaps|think) (?:i|we) (?:can|could|should|might) "# + hedge + action + #"\b"#)
            || has(#"\b(?:tell me if|tell me whether|is it okay if|would it be safe if) (?:i|we) (?:can |could |should |may |might )?"# + hedge + action + #"\b"#)
            || has(#"\b(?:how|where|which way) (?:do|can|could|should|would) (?:i|we) "# + hedge + action + #"\b"#)
            || has(#"\b(?:is it safe|is this safe|am i close enough|are we close enough) to "# + action + #"\b"#)
            || has(#"\b(?:help me|help us|show me how to|tell me how to|tell me where to) "# + hedge + action + #"\b"#)
            || has(#"\b(?:guide|lead|direct|walk) (?:me|us) (?:to|toward|towards|across|past|around)\b"#)
            || has(#"\b(?:show|tell) me (?:the way|which way|where to go)\b"#) { return true }

        // Bare imperatives and politely/uncertainly framed imperatives. Negated
        // commands such as "don't guide me" do not ask for physical guidance.
        var command = text
        for _ in 0..<6 {
            if let prefix = ["please ", "maybe ", "perhaps ", "can you ", "could you ", "would you ", "i think ", "i guess ",
                             "من فضلك ", "لو سمحت ", "ربما ", "يمكن ", "اظن ", "هل يمكنك "].first(where: { command.hasPrefix($0) }) {
                command.removeFirst(prefix.count)
            } else { break }
        }
        if command.range(of: #"^"# + action + #"\b"#, options: .regularExpression) != nil { return true }

        let arAction = #"(?:امشي|امش|نمشي|اذهب|اروح|نروح|اتحرك|احرك|اقترب|اقرب|المس|امسك|التقط|ارفع|اخذ|اشيل|شيل|اتبع|اصعد|اتسلق|انزل|اعبر|اخطو|اتقدم|اصل(?! (?:الي )?(?:هدفي|اهدافي|نتيجه|استنتاج))|اوصل|الوصول|المشي|الاقتراب|التقاط|لمس|صعود)(?:ه|ها|هم)?"#
        if has(#"(?:^| )(?:هل|اقدر|نقدر|استطيع|نستطيع|يمكنني|ممكن|ينفع|كيف|وين|اين|هل علي ان|يجب ان) (?:ان )?"# + arAction + #"(?: |$)"#)
            || has(#"(?:^| )ساعدني (?:في |علي |ان )?"# + arAction + #"(?: |$)"#)
            || has(#"(?:^| )(?:وجهني|ارشدني|دلني|خذني|وصلني) (?:الي |علي |نحو |ل)?"#)
            || command.range(of: #"^"# + arAction + #"(?: |$)"#, options: .regularExpression) != nil { return true }

        let local = has(#"\b(?:this|that|these|those|here|me|my|us|our|it|them)\b|(?:^| )(?:هذا|هذه|هذي|ذلك|تلك|هنا|مني|عني|قدامي|امامي|يميني|يساري|يدي|عندي)(?: |$)"#)
        let target = has(#"\b(?:door|doorway|exit|entrance|kitchen|bathroom|chair|table|cup|glass|bottle|bed|sofa|shelf|wall|stairs?|curb|road|path|dog|person|hand|object|item)\b|(?:^| )(?:ال|لل|ل|بال|ب)?(?:باب|مخرج|كرسي|طاوله|كوب|كاس|زجاجه|سرير|كنبه|رف|جدار|درج|سلم|رصيف|طريق|مسار|كلب|شخص|غرض|شيء)(?: |$)"#)
        let distance = has(#"\b(?:how far|how close|how many steps|distance|within reach|close enough|near enough|too far|which direction|which way)\b|(?:^| )(?:كم يبعد|كم تبعد|كم خطوه|كم خطوات|المسافه|مسافه|قريب|قريبه|بعيد|بعيده|اقدر اوصل|متناول)(?: |$)"#)
        // Geometry on paper is not a measurement of the user's surroundings.
        // This exemption applies only to distance wording, never action matches above.
        let paperGeometry = has(#"\b(?:math|mathematics|equation|triangle|coordinates?|vertices|points? [a-z]|diagram|graph|word problem|solve)\b|(?:^| )(?:رياضيات|الرياضيات|معادله|المعادله|مثلث|المثلث|نقطتين|النقطتين|نقطه|احداثيات|الرسم|المساله)(?: |$)"#)
        if !paperGeometry && has(#"\bhow many steps (?:to|from|until|before)\b"#) { return true }
        if distance && (local || target) && !(paperGeometry && !target) { return true }
        // A bare "yes" to a position/direction question would otherwise evade an
        // output-only geometry guard. Keep these requests in the verified route.
        let directionQuestion = has(#"\b(?:is|are|where|which)\b.*\b(?:left|right|ahead|behind|in front|beside|under|above|below|closer|farther)\b|(?:^| )(?:هل|وين|اين) .*?(?:ال)?(?:يمين|يسار|امام|خلف|تحت|فوق|جنب)(?: |$)"#)
        if directionQuestion && (local || target) && !(paperGeometry && !target) { return true }
        if has(#"\b(?:am i|are we) (?:already |now )?(?:at|beside|near|there|here)\b|(?:^| )هل (?:انا|احنا|نحن) (?:عند|جنب|بجانب|وصلنا)(?: |$)"#) { return true }
        return ["left or right", "should i go this way", "this way", "يمين ولا يسار", "يمين او يسار", "من هنا"].contains(command)
    }

    private static func isQuotedLanguageQuestion(_ question: String) -> Bool {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        // Matched delimiters only. Do not erase all quoted regions or use the
        // presence of "story"/"meaning" as a whole-message bypass.
        for (open, close) in [("“", "”"), ("‘", "’"), ("\"", "\""), ("'", "'"), ("«", "»")] {
            let quoted = NSRegularExpression.escapedPattern(for: open) + #"[^\r\n"“”‘’«»']{1,160}"# + NSRegularExpression.escapedPattern(for: close)
            let patterns = [
                #"^what does (?:the (?:word|phrase|sentence) )?"# + quoted + #" mean\s*[?]?$"#,
                #"^what is the meaning of (?:the (?:word|phrase|sentence) )?"# + quoted + #"\s*[?]?$"#,
                #"^explain the (?:word|phrase|sentence) "# + quoted + #"\s*[.!?]?$"#,
                #"^in the story,? why does the character (?:ask|say) "# + quoted + #"\s*[?]?$"#
            ]
            if patterns.contains(where: { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }) { return true }
        }
        return false
    }

    private static func requiresBanknoteInspection(_ text: String) -> Bool {
        let folded = text.lowercased().folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).decomposedStringWithCanonicalMapping
        let unmarked = String(String.UnicodeScalarView(folded.unicodeScalars.filter {
            !CharacterSet.nonBaseCharacters.contains($0) && $0.value != 0x0640
        }))
        let words = unmarked.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let tokens = Set(words)
        var phrase = words.joined(separator: " ")
        for _ in 0..<4 {
            if let prefix = ["please ", "can you ", "could you ", "would you ", "من فضلك ", "لو سمحت ", "هل يمكنك "].first(where: { phrase.hasPrefix($0) }) {
                phrase.removeFirst(prefix.count)
            } else { break }
        }
        if ["do not ", "don t ", "dont ", "never ", "stop ", "cancel ", "لا ", "توقف ", "الغ ", "الغاء "].contains(where: { phrase.hasPrefix($0) }) { return false }
        let discussion: Set<String> = ["history", "historical", "theory", "definition", "meaning", "mean", "means", "explain", "remember", "favorite", "favourite", "prefer", "budget", "budgeting", "salary", "salaries", "exchange", "price", "prices", "cost", "costs", "spent", "تاريخ", "معنى", "تعريف", "اشرح", "اتذكر", "تتذكر", "ميزانية", "راتب", "صرف", "سعر", "اسعار"]
        guard tokens.isDisjoint(with: discussion) else { return false }
        let cash: Set<String> = ["banknote", "banknotes", "cash", "money", "currency", "bill", "bills", "note", "notes", "نقود", "النقود", "فلوس", "الفلوس", "فلوسي", "عملة", "العملة", "عملتي", "الورقة", "ورقتي", "ورقة", "اوراق", "الاوراق"]
        var hasCash = !tokens.isDisjoint(with: cash)
        let nonCashNotes: Set<String> = ["meeting", "lecture", "lectures", "musical", "music", "piano", "class", "study", "notebook", "agenda", "الاجتماع", "ملاحظات", "موسيقية"]
        if !tokens.isDisjoint(with: nonCashNotes), tokens.isDisjoint(with: ["banknote", "banknotes", "cash", "money", "currency", "نقود", "النقود", "فلوس", "الفلوس"]) { hasCash = false }
        let physical: Set<String> = ["this", "that", "these", "those", "my", "it", "here", "holding", "hand", "hands", "هذا", "هذه", "هذي", "هاذي", "هذول", "ذلك", "تلك", "يدي", "بيدي", "معي", "فلوسي", "عملتي", "ورقتي"]
        let hasPhysical = !tokens.isDisjoint(with: physical)
            || ["the banknote", "the bank note", "the note", "the bill", "الورقة النقدية"].contains(where: { phrase.contains($0) })
        let amounts: Set<String> = ["one", "two", "five", "ten", "twenty", "fifty", "hundred", "thousand", "واحد", "اثنان", "خمسة", "عشرة", "عشرين", "عشرون", "خمسين", "خمسون", "مية", "مئة", "مائة", "ميتين", "مئتان", "مائتان", "الف"]
        let hasAmount = !tokens.isDisjoint(with: amounts) || words.contains { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
        let authenticity: Set<String> = ["real", "genuine", "authentic", "counterfeit", "fake", "مزيفة", "مزيف", "مزورة", "مزور", "اصلية", "اصلي", "حقيقية", "حقيقي"]
        let questionStart = ["what ", "which ", "how much ", "how many ", "is ", "are ", "does ", "do ", "tell me if ", "tell me whether ", "هل ", "ما ", "كم ", "وش ", "ايش "]
            .contains(where: { phrase.hasPrefix($0) })
        let commandStart = ["identify ", "read ", "check ", "confirm ", "count ", "sum ", "total ", "tell me the value ", "tell me the denomination ", "اقرا ", "افحص ", "تاكد ", "حدد ", "عد ", "احسب ", "تعرف على "]
            .contains(where: { phrase.hasPrefix($0) })
        let valueWords: Set<String> = ["value", "worth", "denomination", "amount", "total", "قيمة", "قيمه", "فئة", "فئه"]
        let valueQuestion = hasAmount || !tokens.isDisjoint(with: valueWords) || !tokens.isDisjoint(with: authenticity)
            || phrase.hasPrefix("how much ") || phrase.hasPrefix("كم ")
        let identityQuestion = ["what banknote ", "what note ", "what bill ", "what currency ", "which banknote ", "which note ", "which bill ", "ما هي العملة ", "ما هذه العملة"].contains(where: { phrase.hasPrefix($0) })
        if hasCash, commandStart, !phrase.hasPrefix("read me ") { return true }
        if hasCash, hasPhysical, questionStart, valueQuestion || identityQuestion || ClothingColorCommand.matches(text) { return true }
        if hasCash, !tokens.isDisjoint(with: authenticity), questionStart { return true }
        // Bare "denomination" does not divert discussions of the concept.
        if tokens.contains("denomination"), hasPhysical, questionStart { return true }
        if phrase == "how much is this" || phrase == "what is this worth" || phrase == "what s this worth" { return true }
        // The user can hold a note and omit "banknote": "Is this fifty or a
        // hundred?". Do not mistake a quantified object ("these fifty shirts")
        // or an ordinary price comparison for a denomination inspection.
        let comparison = #"^(?:is (?:this|that|it)|are (?:these|those)|هل (?:هذا|هذه|هذي)) (?:a )?(?:[0-9٠-٩۰-۹]+|one|two|five|ten|twenty|fifty|hundred|thousand|خمسة|عشرة|عشرين|عشرون|خمسين|خمسون|مية|مئة|مائة|مئتان|مائتان)(?: (?:or|a|and|one|two|five|ten|twenty|fifty|hundred|thousand|riyals?|dollars?|euros?|pounds?|sar|usd|ام|او|ولا|خمسة|عشرة|عشرين|عشرون|خمسين|خمسون|مية|مئة|مائة|ريال|ريالات|دولار|[0-9٠-٩۰-۹]+))*$"#
        if hasAmount, phrase.range(of: comparison, options: .regularExpression) != nil { return true }
        // Arabic often omits هل in a spoken choice question.
        return hasCash && hasPhysical && hasAmount && (text.contains("؟") || !tokens.isDisjoint(with: ["ام", "او", "ولا"]))
    }
}
