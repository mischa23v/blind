// Spatial safety rule (AGENTS.md, task E13). Hazard geometry — stairs, steps, drops,
// edges, curbs, holes, obstacles: their distance, direction, step count, height and
// whether a path is clear — comes only from sensors computed by code. Step counts come
// only from code calibrated to the person. Approximate model directions for everyday
// objects the person asks about are allowed; later frames and sensor measurements correct them.
// Keep in step with BlindCore/Sources/BlindCore/SpatialClaimGuard.swift; both run the
// shared fixture BlindCore/Tests/BlindCoreTests/Fixtures/spatial-claims.json.

// "edge" alone is everyday description (the edge of a screen); only drop edges count as hazards.
const HAZARD = /\b(stairs?|staircase|stairway|steps|drop|drop-off|ledge|(platform|stair|step|curb|kerb|balcony|pool) edge|edge of (the |a )?(platform|stairs?|steps?|landing|balcony|pool|curb|kerb|drop)|curb|kerb|hole|obstacles?|obstruction|slope|ramp|escalator|platform|gap|threshold|hazard)\b/i;
const SPATIAL = /(\d|\b(left|right|ahead|behind|in front|forward|backwards?|o'?clock|away|close to you|near you|within|metres?|meters?|feet|foot|inches|yards|up|down|turn|walk|go|head|step|move|climb|descend|clear)\b)/i;
const CLEARANCE = /\b((path|way|route|floor|hallway|corridor|stairs?)\s+(is|are|looks|seems)\s+(clear|free|safe|open)|safe to (walk|cross|go|move|step|climb)|nothing (is )?in (your|the) way|no obstacles?|clear (path|way|route))\b/i;
const STEP_COUNT = /\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|a few|few|several|a couple of|couple of|a dozen)\s+(steps?|stairs?|paces?|strides?)\b/i;

// Model distances must sound like estimates; confident numbers belong to sensors.
const DISTANCE = /(\b\d+([.,]\d+)?[\s-]*(m|cm|metres?|meters?|centimet(er|re)s?|feet|foot|ft|yards?)\b|\b(a|one|two|three|four|five|six|seven|eight|nine|ten|half a)[\s-]+(metres?|meters?|centimet(er|re)s?|feet|foot|yards?)\b)/i;
const HEDGE = /\b(about|roughly|around|approximately|maybe|perhaps|possibly|probably|i think|seems?|looks|estimate[ds]?|or so)\b/i;
const AR_DISTANCE = /([0-9٠-٩]+\s*م(\s|$)|متر|امتار)/;
const AR_HEDGE = /(تقريبا|حوالي|ربما|اظن|يبدو|نحو)/;

const AR_HAZARD =/(درج|سلم|سلالم|حافه|عائق|عوائق|حفره|منحدر|عتبه|رصيف)/;
const AR_SPATIAL = /([0-9٠-٩]|يمين|يسار|امام|خلف|متر|خطو|بعد|اصعد|انزل|امش|تقدم)/;
const AR_CLEARANCE = /(الطريق خال|الممر خال|امن للمشي|لا توجد عوائق|لا يوجد عائق|الطريق امن)/;
const AR_STEP_COUNT = /(خطوه|خطوات|خطوتين)/;

export function normalizeArabic(text) {
  return text.replace(/[ً-ْـ]/g, '').replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه');
}

export function containsSpatialClaim(text) {
  const arabic = normalizeArabic(text);
  if (CLEARANCE.test(text) || STEP_COUNT.test(text) || AR_CLEARANCE.test(arabic) || AR_STEP_COUNT.test(arabic)) return true;
  // A hazard may be mentioned; its position, size or count may not come from the model.
  // Other distances are allowed only when worded as an estimate.
  return arabic.split(/(?<=[.!?؟;،\n])\s*/).some(sentence =>
    (HAZARD.test(sentence) && SPATIAL.test(sentence)) || (AR_HAZARD.test(sentence) && AR_SPATIAL.test(sentence)) ||
    (DISTANCE.test(sentence) && !HEDGE.test(sentence)) || (AR_DISTANCE.test(sentence) && !AR_HEDGE.test(sentence)));
}
