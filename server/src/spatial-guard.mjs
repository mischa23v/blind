// Model-authored physical geometry and physical-action guidance is withheld, including
// everyday objects and hedged estimates. Fresh typed measurements are rendered by code.
// No model confidence, quotation or self-claimed sensor confirmation authorizes guidance.
// This conservative lexical defense is NOT a semantic safety certificate; child physical
// requests must fail closed independently of model prose. Keep the Swift mirror and shared
// BlindCore/Tests/BlindCoreTests/Fixtures/spatial-claims.json cases in agreement.

// "edge" alone is everyday description (the edge of a screen); only drop edges count as hazards.
const HAZARD = /\b(stairs?|staircases?|stairways?|steps?|doorsteps?|drops?|drop[\s-]?offs?|ledges?|potholes?|manholes?|poles?|bollards?|branch(?:es)?|head height|low ceilings?|(platform|stair|step|curb|kerb|balcony|pool) edge|edge of (the |a )?(platform|stairs?|steps?|landing|balcony|pool|curb|kerb|drop)|curbs?|kerbs?|holes?|obstacles?|obstructions?|slopes?|ramps?|escalators?|platforms?|gaps?|thresholds?|hazards?)\b/i;
const SPATIAL = /(\d|\b(left|right|ahead|behind|in front|forward|backwards?|o'?clock|away|close to you|near you|within|metres?|meters?|feet|foot|inches|yards|up|down|turn|walk|go|head|step|move|climb|descend|clear|above|below|high|height|tall|deep|depth|steep|shallow|ascending|descending|upward|downward|uphill|downhill|upstairs|downstairs|elevated|lower|higher|long|wide|narrow)\b)/i;
// Conservative vocabulary check, not a semantic verifier. Negated safety claims may
// also be rejected; novel paraphrases still require sensor-only rendering and review.
const CLEARANCE = /\b((path|way|route|floor|hallway|corridor|walkway|passage|stairs?|street|road|crossing|crosswalk|intersection)\s+(?:(?:ahead|in front of you|to the door)\s+)?(?:(?:is|are|looks?|seems?|appears?|remains?)\s+)?(?:(?:completely|entirely|perfectly|totally|apparently|probably|now|all)\s+)*(clear|free|safe|open|unobstructed|passable|traversable|navigable)|(?:safe|safely)\s+(?:to\s+)?(?:walk|cross|go|move|step|climb|proceed|continue)|(?:walk|cross|go|move|step|climb|proceed|continue)\s+(?:(?:ahead|forward|onward)\s+)?safely|nothing(?:'s|\s+is)?\s+(?:in (?:your|the) way|block\w*|in front of you|ahead|on the floor)|no (?:obstacles?|obstructions?|hazards?|stairs?|steps?|drops?|curbs?|kerbs?|holes?|cars?|traffic|vehicles?)|(?:don't|do not|can't|cannot) see any (?:obstacles?|obstructions?|hazards?|stairs?|steps?|drops?|curbs?|kerbs?|holes?|cars?)|clear to (?:cross|walk|go)|cross now|cars? (?:are |is )?(?:not )?coming|it(?:'s|\s+is) (?:all )?clear|(?:clear|unobstructed|safe|passable) (?:path|way|route|passage|corridor)|free (?:of|from) (?:obstacles?|obstructions?|hazards?)|(?:all clear|clear ahead)|without (?:any )?(?:obstacles?|obstructions?|risk|danger))\b/i;
const STEP_COUNT = /\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|a few|few|several|a couple of|couple of|a dozen|a|an|a single|single)\s+(?:(?:small|little|big|short|tall|low|high)\s+)?(steps?|stairs?|paces?|strides?)\b/i;

// A hedge never authorizes a model distance. Even quoted distances remain untrusted prose.
const DISTANCE = /(\b\d+([.,]\d+)?[\s-]*(m|cm|metres?|meters?|centimet(er|re)s?|feet|foot|ft|yards?)\b|\b(a|one|two|three|four|five|six|seven|eight|nine|ten|half a)[\s-]+(metres?|meters?|centimet(er|re)s?|feet|foot|yards?)\b|\b(one|two|three|four|five|six|seven|eight|nine|ten)\s+and\s+a\s+half\s+(metres?|meters?|feet|foot|yards?)\b)/i;
const AR_DISTANCE = /([0-9٠-٩]+\s*م(\s|$)|متر|امتار)/;

const AR_HAZARD =/(درج|سلم|سلالم|حافه|حواف|عائق|عوائق|حفره|حفر|منحدر|عتبه|رصيف|ارصفه|عقبه|عقبات|هاويه|سقوط|فجوه)/;
const AR_SPATIAL = /([0-9٠-٩]|يمين|يسار|امام|خلف|اسفل|اعلي|متر|خطو|بعد|اصعد|انزل|امش|تقدم|فوق|تحت|عال|مرتفع|ارتفاع|عمق|عميق|ضحل|حاد|صاعد|هابط|قريب|بعيد|طويل|عرض|عريض|ضيق)/;
const AR_CLEARANCE = /((الطريق|الممر|المسار|الارضيه)\s+(?:(?:يبدو|يظهر|هو|تماما)\s+)*(خال|خالي|امن|مفتوح|سالك)|امن\s+(للمشي|للعبور|للتقدم)|بامان|لا\s+(توجد|يوجد)\s+(اي\s+)?(عوائق|عائق|عقبات|خطر)|دون\s+(عوائق|عائق|خطر)|خالي\s+من\s+(العوائق|العقبات)|لا\s+(?:شيء|شي)\s+(?:امامك|قدامك)|ما\s+في\s+(?:شيء|شي)\s+(?:امامك|قدامك))/;
const AR_STEP_COUNT = /(خطوه|خطوات|خطوتين|درجتين|[0-9٠-٩]+\s*درج|(?:ثلاث|اربع|خمس|ست|سبع|ثماني|تسع|عشر|عده|بضع)\s+درج)/;

// Quotations and negations are not stripped: untrusted physical words remain blocked.
const DIRECTION = /\b((?:top|bottom|upper|lower) (?:corner|edge)|ahead|behind|above|below|underneath|beside|next to|in front of|nearby|overhead|north|south|east|west|northwest|northeast|southwest|southeast|clockwise|counterclockwise|anticlockwise|forward|backwards?|towards?|upstairs|downstairs)\b|\b(?:to|on|at|from|toward|towards)\s+(?:(?:your|my|the|its|their)\s+)?(?:far\s+)?(?:left|right)\b|\b(?:left|right)[ -](?:hand|side|edge|corner)\b|\b(?:is|seems|appears|looks)\s+(?:(?:roughly|probably|slightly|just)\s+)*(?:left|right)\b|^\s*(?:(?:roughly|maybe|probably|slightly|just|go|turn)\s+)*(?:left|right)\s*[.!?,;]*\s*$|\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|[0-9]+)\s*o['’]?clock\b/i;
const OBJECT_RELATION = /\b(?:on|in|under|over|near|by|against|inside|outside|between|across|past|along)\s+(?:(?:the|a|an|your|my|this|that|its|their)\s+)?(?:(?:small|large|wooden|white|black|red|blue|green|open|closed|nearest|farther|left|right)\s+){0,3}(?:desk|table|sofa|couch|bed|chair|door|window|wall|floor|shelf|cabinet|cupboard|drawer|counter|nightstand|lamp|screen|television|tv|socket|outlet|bench|stove|oven|sink|knife|cup|mug|bottle|plate|bag|box|handle|hand|arm|foot|feet|body|person|people|car|road|street|stairs?|step|curb|kerb|hole|obstacle)\b|\b(?:near|close to|far from|away from|next to|within reach of)\s+(?:you|me|your|my)\b|\b(?:within|in|out of|beyond)\s+(?:(?:your|easy|safe|arm['’]?s)\s+)*(?:reach|fingertips?|hands?)\b|\b(?:reachable|graspable|nearest|closest|closer|nearer|farther|close enough|easy to reach|safe to (?:touch|hold|grab|pick up|reach))\b/i;
const PHYSICAL_ACTION = /\b(?:walk|go|approach|follow|reach|grab|grasp|touch|climb|descend|crawl|crouch|bend|lean|stretch(?:ing)?|extend(?:ing)?|lift|pull|push|press|squeez(?:e|ing)|swing|jump|run|cross|proceed|advance|retreat|rotate|tilt|turn(?:ing)?|move|step|pick|pick[ -]?up|pick\s+(?:it|that|this|them)\s+up)\b|\b(?:take|hold|handle|cut|open|close|eat|drink|taste|smell|put|place|set|bring|carry|light|heat)\s+(?:(?:the|a|an|your|this|that|it|them|one|both)\b|[a-z]+\s+(?:knife|cup|mug|bottle|door|drawer|medicine|food)\b)|\b(?:keep|start|begin|continue)\s+(?:walking|moving|reaching|climbing|running|touching|holding|turning)\b/i;
const AR_DIRECTION = /(يمين|يسار|شمال|جنوب|شرق|غرب|امام|قدام|خلف|وراء|ورا[يكه]|فوق|تحت|اسفل|اعلي|بجانب|بجوار|جنب|قرب|قريب|اقرب|بعيد|بينك|بين يديك|في متناول|متناول يد|في اتجاه|باتجاه)/i;
const AR_OBJECT_RELATION = /(?:علي|على|داخل|خارج|عند|بين|حول)\s+(?:ال|هذا |هذه |تلك |ذلك )?(?:مكتب|طاول|سرير|اريك|كنب|كرسي|باب|نافذ|حائط|جدار|ارض|رف|خزان|درج|مصباح|شاش|تلفاز|مقبض|يد|ذراع|قدم|جسم|شخص|سيار|طريق|سكين|كوب|زجاج|حقيب)|(?:يمكنك|تقدر|تستطيع)\s+(?:الوصول|الامساك|التقاط|اخذ|اخذه|اخذها|لمس)/i;
const AR_PHYSICAL_ACTION = /(?:^|[\s،؛.!؟:«»"'()])(?:و|ف)?(?:امش(?:ي)?|روح|سر|اقترب|اقربي|اتبع|اتبعي|تبع|الحق|امسك(?:ه|ها|يه|يها)?|التقط(?:ه|ها)?|التقطي|خذ(?:ه|ها|يه|يها)?|خدي|المس(?:ه|ها)?|المسي|تسلق|اصعد|انزل|اقفز|ازحف|انحن|ميل|مل|مد(?:ي)?|مدد|ارفع(?:ه|ها)?|ارفعى|اسحب(?:ه|ها)?|ادفع(?:ه|ها)?|اضغط|اضغطي|لف|لفي|ادر|دور|دوري|حرك(?:ه|ها)?|تقدم|تراجع|اعبر|اقطع|افتح(?:ه|ها)?|اغلق(?:ه|ها)?|ضع(?:ه|ها)?|حط(?:ه|ها)?|كل|اشرب|ذق|شم)(?:[\s،؛.!؟:«»"'()]|$)|(?:يمكنك|يمكن|تقدر|تستطيع|حاول|جرب)\s+(?:ان\s+)?(?:تمشي|تقترب|تتبع|توصل|تطول(?:ه|ها)?|تلف|تدور|تمسك(?:ه|ها)?|تاخذ(?:ه|ها)?|تلمس(?:ه|ها)?|تتسلق|تصعد|تنزل|تمد|تحرك|تفتح|تغلق|تاكل|تشرب)/i;

export function normalizeArabic(text) {
  return text.replace(/[ً-ْـ]/g, '').replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه');
}

// Do not forget the hazard at punctuation. A later (or earlier) pronoun or
// subjectless location can refer to it. Ambiguous hazard referents fail closed too.
const REFERENCE = /(?:\b(it|its|they|them|their|this|that|these|those|there)\b|^\s*(?:roughly|about|approximately|around|ahead|behind|to (?:your|the) (?:left|right))\b)/i;
const AR_REFERENCE = /(هو|هي|انه|انها|انهم|هذا|هذه|ذلك|تلك|هناك|يبعد|تبعد|تقع|يقع|ارتفاعه|عمقها|^\s*(تقريبا|حوالي|امام|خلف|يمين|يسار))/;

/** Whether the text names a hazard at all, so "a hazard is visible" survives when its geometry is dropped. */
export function mentionsHazard(text) {
  const normalized = normalizeArabic(text);
  return HAZARD.test(normalized) || AR_HAZARD.test(normalized);
}

export function containsSpatialClaim(text, context = text) {
  // Normalize spoken-equivalent separators before checking physical phrases.
  const canonical = text.replace(/[-‐‑‒–—−]+/gu, ' ');
  // A scientific subject AND bounded complement disambiguate only this verb.
  // No sentence/quotation is exempt; all other physical claims remain checked.
  const science = canonical.replace(/\b((?:(?:different|visible)\s+)?(?:wavelengths|light rays|rays of light)\s+)bend(\s+(?:(?:by|at)\s+different\s+(?:amounts|angles)|when\s+they\s+pass\s+through\s+(?:water|glass|a prism)))(?=\s*(?:[.!?;,]|$)|\s+(?:in|through)\s+(?:water droplets|a prism)\s*(?:[.!?;,]|$))/gi, '$1refract$2');
  // Fixed conversational idioms only; no quotation/whole-sentence exemption.
  const prose = science.replace(/\b(?:take your time|move on to (?:another|the next) (?:topic|question|subject))\b|(?:^|\s)خذ وقتك(?=[\s.!؟،]|$)/gi, '');
  const arabic = normalizeArabic(prose);
  if (DIRECTION.test(prose) || OBJECT_RELATION.test(prose) || PHYSICAL_ACTION.test(prose) ||
      AR_DIRECTION.test(arabic) || AR_OBJECT_RELATION.test(arabic) || AR_PHYSICAL_ACTION.test(arabic) ||
      CLEARANCE.test(canonical) || STEP_COUNT.test(canonical) || AR_CLEARANCE.test(arabic) || AR_STEP_COUNT.test(arabic)) return true;
  const normalizedContext = normalizeArabic(context.replace(/[-‐‑‒–—−]+/gu, ' '));
  const hasHazard = HAZARD.test(normalizedContext) || AR_HAZARD.test(normalizedContext);
  return arabic.split(/(?<=[!?؟;؛،\n])\s*|(?<!\d)\.\s*|\.(?!\d)\s*/).some(sentence =>
    (HAZARD.test(sentence) && SPATIAL.test(sentence)) || (AR_HAZARD.test(sentence) && AR_SPATIAL.test(sentence)) ||
    (hasHazard && ((REFERENCE.test(sentence) && SPATIAL.test(sentence)) || (AR_REFERENCE.test(sentence) && AR_SPATIAL.test(sentence)))) ||
    DISTANCE.test(sentence) || AR_DISTANCE.test(sentence));
}
