// Spatial safety rule (AGENTS.md, task E13). Hazard geometry — stairs, steps, drops,
// edges, curbs, holes, obstacles: their distance, direction, step count, height and
// whether a path is clear — comes only from sensors computed by code. Step counts come
// only from code calibrated to the person. Approximate model directions for everyday
// objects the person asks about are allowed; later frames and sensor measurements correct them.
// Keep in step with BlindCore/Sources/BlindCore/SpatialClaimGuard.swift; both run the
// shared fixture BlindCore/Tests/BlindCoreTests/Fixtures/spatial-claims.json.

// "edge" alone is everyday description (the edge of a screen); only drop edges count as hazards.
const HAZARD = /\b(stairs?|staircases?|stairways?|steps?|doorsteps?|drops?|drop[\s-]?offs?|ledges?|potholes?|manholes?|poles?|bollards?|branch(?:es)?|head height|low ceilings?|(platform|stair|step|curb|kerb|balcony|pool) edge|edge of (the |a )?(platform|stairs?|steps?|landing|balcony|pool|curb|kerb|drop)|curbs?|kerbs?|holes?|obstacles?|obstructions?|slopes?|ramps?|escalators?|platforms?|gaps?|thresholds?|hazards?)\b/i;
const SPATIAL = /(\d|\b(left|right|ahead|behind|in front|forward|backwards?|o'?clock|away|close to you|near you|within|metres?|meters?|feet|foot|inches|yards|up|down|turn|walk|go|head|step|move|climb|descend|clear|above|below|high|height|tall|deep|depth|steep|shallow|ascending|descending|upward|downward|uphill|downhill|upstairs|downstairs|elevated|lower|higher|long|wide|narrow)\b)/i;
// Conservative vocabulary check, not a semantic verifier. Negated safety claims may
// also be rejected; novel paraphrases still require sensor-only rendering and review.
const CLEARANCE = /\b((path|way|route|floor|hallway|corridor|walkway|passage|stairs?|street|road|crossing|crosswalk|intersection)\s+(?:(?:ahead|in front of you|to the door)\s+)?(?:(?:is|are|looks?|seems?|appears?|remains?)\s+)?(?:(?:completely|entirely|perfectly|totally|apparently|probably|now|all)\s+)*(clear|free|safe|open|unobstructed|passable|traversable|navigable)|(?:safe|safely)\s+(?:to\s+)?(?:walk|cross|go|move|step|climb|proceed|continue)|(?:walk|cross|go|move|step|climb|proceed|continue)\s+(?:(?:ahead|forward|onward)\s+)?safely|nothing(?:'s|\s+is)?\s+(?:in (?:your|the) way|block\w*|in front of you|ahead|on the floor)|no (?:obstacles?|obstructions?|hazards?|stairs?|steps?|drops?|curbs?|kerbs?|holes?|cars?|traffic|vehicles?)|(?:don't|do not|can't|cannot) see any (?:obstacles?|obstructions?|hazards?|stairs?|steps?|drops?|curbs?|kerbs?|holes?|cars?)|clear to (?:cross|walk|go)|cross now|cars? (?:are |is )?(?:not )?coming|it(?:'s|\s+is) (?:all )?clear|(?:clear|unobstructed|safe|passable) (?:path|way|route|passage|corridor)|free (?:of|from) (?:obstacles?|obstructions?|hazards?)|(?:all clear|clear ahead)|without (?:any )?(?:obstacles?|obstructions?|risk|danger))\b/i;
const STEP_COUNT = /\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|a few|few|several|a couple of|couple of|a dozen|a|an|a single|single)\s+(?:(?:small|little|big|short|tall|low|high)\s+)?(steps?|stairs?|paces?|strides?)\b/i;

// Model distances must sound like estimates; confident numbers belong to sensors.
const DISTANCE = /(\b\d+([.,]\d+)?[\s-]*(m|cm|metres?|meters?|centimet(er|re)s?|feet|foot|ft|yards?)\b|\b(a|one|two|three|four|five|six|seven|eight|nine|ten|half a)[\s-]+(metres?|meters?|centimet(er|re)s?|feet|foot|yards?)\b|\b(one|two|three|four|five|six|seven|eight|nine|ten)\s+and\s+a\s+half\s+(metres?|meters?|feet|foot|yards?)\b)/i;
const HEDGE = /\b(about|roughly|around|approximately|maybe|perhaps|possibly|probably|i think|seems?|looks|estimate[ds]?|or so)\b/i;
const AR_DISTANCE = /([0-9٠-٩]+\s*م(\s|$)|متر|امتار)/;
const AR_HEDGE = /(تقريبا|حوالي|ربما|اظن|يبدو|نحو)/;

const AR_HAZARD =/(درج|سلم|سلالم|حافه|حواف|عائق|عوائق|حفره|حفر|منحدر|عتبه|رصيف|ارصفه|عقبه|عقبات|هاويه|سقوط|فجوه)/;
const AR_SPATIAL = /([0-9٠-٩]|يمين|يسار|امام|خلف|اسفل|اعلي|متر|خطو|بعد|اصعد|انزل|امش|تقدم|فوق|تحت|عال|مرتفع|ارتفاع|عمق|عميق|ضحل|حاد|صاعد|هابط|قريب|بعيد|طويل|عرض|عريض|ضيق)/;
const AR_CLEARANCE = /((الطريق|الممر|المسار|الارضيه)\s+(?:(?:يبدو|يظهر|هو|تماما)\s+)*(خال|خالي|امن|مفتوح|سالك)|امن\s+(للمشي|للعبور|للتقدم)|بامان|لا\s+(توجد|يوجد)\s+(اي\s+)?(عوائق|عائق|عقبات|خطر)|دون\s+(عوائق|عائق|خطر)|خالي\s+من\s+(العوائق|العقبات)|لا\s+(?:شيء|شي)\s+(?:امامك|قدامك)|ما\s+في\s+(?:شيء|شي)\s+(?:امامك|قدامك))/;
const AR_STEP_COUNT = /(خطوه|خطوات|خطوتين|درجتين|[0-9٠-٩]+\s*درج|(?:ثلاث|اربع|خمس|ست|سبع|ثماني|تسع|عشر|عده|بضع)\s+درج)/;

export function normalizeArabic(text) {
  return text.replace(/[ً-ْـ]/g, '').replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه');
}

// Do not forget the hazard at punctuation. A later (or earlier) pronoun or
// subjectless location can refer to it. Explicit everyday-object estimates remain
// useful, but ambiguous referents in a hazard-containing answer fail closed.
const REFERENCE = /(?:\b(it|its|they|them|their|this|that|these|those|there)\b|^\s*(?:roughly|about|approximately|around|ahead|behind|to (?:your|the) (?:left|right))\b)/i;
const AR_REFERENCE = /(هو|هي|انه|انها|انهم|هذا|هذه|ذلك|تلك|هناك|يبعد|تبعد|تقع|يقع|ارتفاعه|عمقها|^\s*(تقريبا|حوالي|امام|خلف|يمين|يسار))/;

/** Whether the text names a hazard at all, so "a hazard is visible" survives when its geometry is dropped. */
export function mentionsHazard(text) {
  const normalized = normalizeArabic(text);
  return HAZARD.test(normalized) || AR_HAZARD.test(normalized);
}

export function containsSpatialClaim(text, context = text) {
  const arabic = normalizeArabic(text);
  if (CLEARANCE.test(text) || STEP_COUNT.test(text) || AR_CLEARANCE.test(arabic) || AR_STEP_COUNT.test(arabic)) return true;
  const normalizedContext = normalizeArabic(context);
  const hasHazard = HAZARD.test(normalizedContext) || AR_HAZARD.test(normalizedContext);
  return arabic.split(/(?<=[!?؟;؛،\n])\s*|(?<!\d)\.\s*|\.(?!\d)\s*/).some(sentence =>
    (HAZARD.test(sentence) && SPATIAL.test(sentence)) || (AR_HAZARD.test(sentence) && AR_SPATIAL.test(sentence)) ||
    (hasHazard && ((REFERENCE.test(sentence) && SPATIAL.test(sentence)) || (AR_REFERENCE.test(sentence) && AR_SPATIAL.test(sentence)))) ||
    (DISTANCE.test(sentence) && !HEDGE.test(sentence)) || (AR_DISTANCE.test(sentence) && !AR_HEDGE.test(sentence)));
}
