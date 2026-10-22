// Conversation evidence rules (2026-10-22 hallucination fix). The language model never decides
// where an object is or what the camera saw: code parses the child's reports, stores them with
// time and source, and renders every sentence about them. Model chat text and image descriptions
// are checked before speech.
// Keep in step with BlindCore CompanionFacts.swift, ConversationClaimGuard.swift and
// VisualGrounding.swift; all run the shared fixture
// BlindCore/Tests/BlindCoreTests/Fixtures/companion-evidence.json.
import { normalizeArabic } from './spatial-guard.mjs';

// --- Child utterances: find requests and location reports -----------------------------------

const PLACE = String.raw`((?:on top of|in front of|next to|on|in|under|underneath|inside|behind|beside|near|by|at)\s+.+)`;
const AR_PLACE = String.raw`((?:على|علي|في|تحت|عند|جنب|بجانب|قرب|فوق|داخل|ورا|وراء|خلف|[اأ]مام)\s+.+|بال\S.*)`;
// "my cup" is the child's own thing; "the remote" keeps its "the" so replies never say "your remote".
const OWNED = String.raw`(?:(?:my|our)\s+|(?=the\s))`;
const FIND = [
  new RegExp(String.raw`^(?:(?:can|could|will|would) you\s+)?(?:please\s+)?(?:help me\s+)?(?:to\s+)?(?:find|look for|search for|locate)\s+` + OWNED + '(.+)$', 'i'),
  new RegExp(String.raw`^i\s+(?:can't|cannot|can not|couldn't|could not)\s+find\s+` + OWNED + '(.+)$', 'i'),
  new RegExp(String.raw`^i(?:'ve| have)?\s+lost\s+` + OWNED + '(.+)$', 'i'),
  new RegExp(String.raw`^i(?:'m| am)\s+looking for\s+` + OWNED + '(.+)$', 'i'),
  new RegExp(String.raw`^where(?:'s|\s+is|\s+are)\s+` + OWNED + '(.+)$', 'i'),
  new RegExp(String.raw`^where\s+did\s+i\s+(?:leave|put)\s+` + OWNED + '(.+)$', 'i'),
  /^(?:ساعدني|ساعديني)\s+(?:[اأ]لاقي|[اأ]لقى|[اأ]جد|[اأ]دور على|[اأ]بحث عن|في البحث عن)\s+(.+)$/,
  /^(?:ما|مو)\s+(?:لقيت|حصلت|[اأ]جد|[اأ]لقى)\s+(.+)$/,
  /^(?:ضاع|ضاعت|فقدت|[اأ]ضعت)\s+(.+)$/,
  /^(?:وين|[اأ]ين)\s+(.+)$/
];
const HEDGE_SUFFIX = /\s+(?:i think|i guess|maybe|probably|[اأ]ظن|ربما)$/i;
const TIME_PLACE = /^(?:in|at|on|by)\s+(?:the\s+)?(?:morning|afternoon|evening|night|weekend|monday|tuesday|wednesday|thursday|friday|saturday|sunday|[0-9])/i;
const REPORT_ACTION = new RegExp(String.raw`^i\s+(?:last\s+|just\s+)?(?:left|put|placed|dropped|set|had|kept|saw|forgot)\s+(?:(?:my|the|our)\s+(.+?)|(it|them))\s+` + PLACE + '$', 'i');
const REPORT_STATE = new RegExp(String.raw`^(?:(?:my|the|our)\s+(.+?)|(it|they))(?:\s+(is|are|was|were)|('s))\s+(?:still\s+)?` + PLACE + '$', 'i');
const AR_REPORT_ACTION = new RegExp(String.raw`^(?:تركت|حطيت|وضعت|نسيت|خليت)(ه|ها|هم)?\s+(?:(.+?)\s+)??` + AR_PLACE + '$');
const HEDGE_PREFIX = /^(?:i think|i guess|maybe|probably)\s+(?:that\s+)?/i;
const AR_HEDGE_PREFIX = /^(?:[اأ]ظن|[اأ]عتقد|يمكن|ربما)\s+(?:[اأ]ن(?:ي|ه|ها)?\s+)?/;
const TRAILING = /\s+(?:please|again|now|for me|right now|instead|too|as well|back|down|away)$/i;

function cleanObject(value) {
  const object = value.replace(TRAILING, '').trim();
  return object && object.length <= 40 && object.split(/\s+/).length <= 4 ? object : null;
}

function cleanPlace(value) {
  const place = value.replace(TRAILING, '').trim();
  return place && place.length <= 80 ? place : null;
}

/** Returns {kind:'find', object} | {kind:'report', object|null, place, tense:'earlier'|'current', hedged} | null.
 * Sentences are tried from last to first, so "I changed my mind. Help me find my backpack" finds the backpack. */
export function parseUtterance(raw) {
  const parts = sentences(raw.replace(/[’‘]/g, "'")).map(part => part.trim()).filter(Boolean);
  for (const part of parts.reverse()) {
    const parsed = parseSentence(part);
    if (parsed) return parsed;
  }
  return null;
}

function parseSentence(sentence) {
  const question = /[?؟]\s*$/.test(sentence);
  let text = sentence.replace(/[\s.!?؟,،;؛]+$/u, '').replace(/^(?:okay|ok|um|so|and)[\s,]+/i, '').trim();
  for (const pattern of FIND) {
    const match = text.match(pattern);
    if (match) {
      const object = cleanObject(match[1]);
      return object ? { kind: 'find', object } : null;
    }
  }
  if (question) return null;
  let hedged = false;
  if (HEDGE_SUFFIX.test(text)) { hedged = true; text = text.replace(HEDGE_SUFFIX, ''); }
  for (const prefix of [HEDGE_PREFIX, AR_HEDGE_PREFIX]) {
    const match = text.match(prefix);
    if (match) { hedged = true; text = text.slice(match[0].length); }
  }
  let match = text.match(REPORT_ACTION);
  if (match) return report(match[1] ?? null, match[3], 'earlier', hedged);
  match = text.match(REPORT_STATE);
  if (match) {
    const verb = (match[3] ?? 'is').toLowerCase();
    return report(match[1] ?? null, match[5], verb === 'was' || verb === 'were' ? 'earlier' : 'current', hedged);
  }
  match = text.match(AR_REPORT_ACTION);
  if (match) return report(match[1] ? null : (match[2] ?? null), match[3], 'earlier', hedged);
  return null;
}

function report(objectText, placeText, tense, hedged) {
  const object = objectText == null ? null : cleanObject(objectText);
  const place = cleanPlace(placeText);
  if ((objectText != null && !object) || !place || TIME_PLACE.test(place)) return null;
  return { kind: 'report', object, place, tense, hedged };
}

// --- Model chat claims ---------------------------------------------------------------------

// A chat reply with no live camera may not state where an object is now, that it is present
// or absent, or that the assistant perceived anything. Past-tense attributions ("you said your
// cup was on the table") and questions are allowed. Conservative lexical check, not a proof.
const PREP = String.raw`(?:on top of|in front of|next to|on|in|under|underneath|inside|behind|beside|near|by|at|over there|right there|there|here|to your (?:left|right)|nearby|close by|where you left (?:it|them))`;
const ADV = String.raw`(?:(?:still|now|right|probably|likely|definitely|just|already)\s+)*`;
const POSE = String.raw`(?:(?:sitting|lying|located|kept|placed|standing|resting)\s+)?`;
const CLAIMS = [
  new RegExp(String.raw`\b(?:your|the|my|his|her|their|our|a|an|some)\s+[a-z][a-z' -]{0,30}?(?:'s|'re|\s+(?:is|are|'s|'re|sits|lies|stays|remains))\s+` + ADV + POSE + PREP + String.raw`\b`, 'i'),
  new RegExp(String.raw`\b(?:it|they)(?:'s|'re|\s+is|\s+are|\s+sits|\s+lies)\s+` + ADV + POSE + PREP + String.raw`\b`, 'i'),
  new RegExp(String.raw`\b(?:it|they)(?:'s|'re|\s+is|\s+are)\s+not\s+` + PREP + String.raw`\b`, 'i'),
  new RegExp(String.raw`\b(?:might|may|could|must|should)\s+(?:still\s+)?be\s+` + POSE + PREP + String.raw`\b`, 'i'),
  new RegExp(String.raw`\b(?:is|are)\s*(?:not|n't)\s+` + ADV + String.raw`(?:found|around|in (?:the|this|your) room|on|in|under|inside|behind|beside|near|by|at|here|there)\b`, 'i'),
  /\b(?:isn't|aren't)\s+(?:here|there|around|on|in|under|inside|behind|near)\b/i,
  /\b(?:not found|is missing|are missing|is gone|are gone|has gone|have gone|is lost|are lost|no longer there)\b/i,
  /\bi(?:'ve|\s+have|\s+just|\s+already)?\s+(?:can see|could see|found|spotted|located|noticed|saw|seen|see (?:a|an|the|your|it|them|some))\b/i,
  /\bi\s+(?:don't|do not|can't|cannot|couldn't|could not)\s+see\s+(?:your|the|it|them|a|an|any)\b/i,
  /\bhere (?:it is|they are)\b/i,
  new RegExp(String.raw`\byou(?:'ll|\s+will|\s+can|\s+should)?\s+find\s+(?:it|them|your\s+[a-z]+)\s+` + PREP + String.raw`\b`, 'i'),
  /\bthere(?:'s|\s+is|\s+are)\s+(?:no\s+[a-z]+|a|an|the|some|your|two|three|many|[a-z]+s)\b/i
];
// A tag question ("…, right?") still asserts its statement.
const TAG_QUESTION = /,\s*(?:right|isn't it|aren't they|isn't that right|ok|okay|yes|no)\s*[?؟]\s*$/i;
const AR_CLAIMS = [
  /(موجود|موجوده|يوجد|توجد|يقع|تقع)\s+(على|علي|في|تحت|عند|جنب|بجانب|قرب|فوق|داخل|هنا|هناك)/,
  /(?:^|\s)(غير موجود|مفقود|ضاع|ضاعت|اختفي|اختفت|ليس هنا|مو هنا)(?=$|\s|[.!,،؛؟])/,
  /(?:^|\s)(?:اشوف|اري|رايت|شفت|وجدت|لقيت|الاحظ)(?:ه|ها|هم)?(?=$|\s|[.!,،؛؟])/,
  // Arabic location sentences need no verb: "كوبك على الطاولة", "هو تحت الكنبة", "الكوب في المطبخ".
  /(?:^|\s)(?:\S+(?:ك|كم)|هو|هي|هم|ال\S+)\s+(?:على|علي|في|تحت|عند|جنب|بجانب|قرب|فوق|داخل|هنا|هناك)(?=$|\s|[.!,،؛؟])/
];
// Attributions to the child ("قلت إن كوبك كان …") are history, not current claims.
const AR_ATTRIBUTION = /(كان|كانت|قلت|تظن|ظننت)/;

function arabicFolded(text) {
  return normalizeArabic(text).replace(/ى/g, 'ي');
}

export function sentences(text) {
  const result = [];
  let current = '';
  const chars = [...text.replace(/\r\n/g, '\n')];
  chars.forEach((ch, i) => {
    current += ch;
    const decimal = ch === '.' && i > 0 && i + 1 < chars.length && /[0-9]/.test(chars[i - 1]) && /[0-9]/.test(chars[i + 1]);
    if ('.!?؟;؛،\n'.includes(ch) && !decimal) { result.push(current); current = ''; }
  });
  if (current) result.push(current);
  return result;
}

export function isUnsupportedClaim(sentence) {
  let plain = sentence.replace(/[’‘]/g, "'").trim();
  if (TAG_QUESTION.test(plain)) plain = plain.replace(TAG_QUESTION, '.');
  else if (/[?؟]\s*$/.test(plain)) return false;
  if (CLAIMS.some(pattern => pattern.test(plain))) return true;
  const arabic = arabicFolded(plain);
  if (AR_CLAIMS.slice(0, 3).some(pattern => pattern.test(arabic))) return true;
  return !AR_ATTRIBUTION.test(arabic) && AR_CLAIMS[3].test(arabic);
}

export function containsUnsupportedClaim(text) {
  return sentences(text).some(isUnsupportedClaim);
}

/** Drops the sentences that make unsupported claims; '' when none remain. */
export function supportedText(text) {
  return sentences(text).filter(sentence => !isUnsupportedClaim(sentence)).join('').trim();
}

// --- Image description grounding -----------------------------------------------------------

// Everyday object groups. A model sentence naming one of these is spoken as fact only when the
// phone's own detectors (Vision classification, detector, text, people) agreed on it in at least
// two of the recent frames; otherwise the sentence must be hedged or it is dropped. Arabic words
// are in normalized form (أ→ا, ة→ه, ى→ي). Words not on the list cannot be checked (known gap).
export const OBJECT_GROUPS = [
  ['cup', 'cups', 'mug', 'mugs', 'tumbler', 'كوب', 'اكواب', 'فنجان', 'كاس'],
  ['table', 'tables', 'desk', 'desks', 'طاوله', 'طاولات', 'مكتب'],
  ['chair', 'chairs', 'stool', 'stools', 'armchair', 'armchairs', 'كرسي', 'كراسي'],
  ['sofa', 'sofas', 'couch', 'couches', 'كنبه', 'اريكه', 'كنب'],
  ['bed', 'beds', 'سرير', 'اسره'],
  ['door', 'doors', 'doorway', 'باب', 'ابواب'],
  ['window', 'windows', 'نافذه', 'شباك', 'نوافذ'],
  ['lamp', 'lamps', 'مصباح', 'لمبه', 'اباجوره'],
  ['television', 'televisions', 'tv', 'tvs', 'تلفزيون', 'تلفاز'],
  ['monitor', 'monitors', 'screen', 'screens', 'شاشه'],
  ['laptop', 'laptops', 'computer', 'computers', 'keyboard', 'keyboards', 'حاسوب', 'كمبيوتر', 'لابتوب'],
  ['phone', 'phones', 'smartphone', 'smartphones', 'هاتف', 'جوال', 'تلفون'],
  ['book', 'books', 'notebook', 'notebooks', 'كتاب', 'كتب', 'دفتر'],
  ['bag', 'bags', 'backpack', 'backpacks', 'handbag', 'handbags', 'حقيبه', 'شنطه'],
  ['bottle', 'bottles', 'زجاجه', 'قاروره'],
  ['plate', 'plates', 'bowl', 'bowls', 'dish', 'dishes', 'صحن', 'طبق', 'صحون'],
  ['refrigerator', 'refrigerators', 'fridge', 'fridges', 'ثلاجه'],
  ['oven', 'ovens', 'stove', 'stoves', 'microwave', 'microwaves', 'فرن', 'موقد'],
  ['sink', 'sinks', 'مغسله'],
  ['toilet', 'toilets', 'مرحاض'],
  ['shelf', 'shelves', 'bookshelf', 'bookshelves', 'bookcase', 'bookcases', 'رف', 'رفوف'],
  ['cabinet', 'cabinets', 'cupboard', 'cupboards', 'wardrobe', 'wardrobes', 'drawer', 'drawers', 'خزانه', 'دولاب'],
  ['painting', 'paintings', 'picture', 'pictures', 'poster', 'posters', 'frame', 'frames', 'لوحه', 'صوره'],
  ['plant', 'plants', 'flower', 'flowers', 'vase', 'vases', 'نبته', 'نبات', 'زهره', 'ورد'],
  ['rug', 'rugs', 'carpet', 'carpets', 'mat', 'mats', 'سجاده', 'زوليه'],
  ['pillow', 'pillows', 'cushion', 'cushions', 'مخده', 'وساده'],
  ['blanket', 'blankets', 'بطانيه', 'لحاف'],
  ['clock', 'clocks', 'ساعه'],
  ['mirror', 'mirrors', 'مرايه', 'مراه'],
  ['box', 'boxes', 'carton', 'cartons', 'صندوق', 'كرتون'],
  ['toy', 'toys', 'teddy', 'doll', 'dolls', 'لعبه', 'العاب', 'دميه'],
  ['ball', 'balls', 'كره'],
  ['shoe', 'shoes', 'sneaker', 'sneakers', 'boot', 'boots', 'حذاء', 'جزمه', 'نعال'],
  ['car', 'cars', 'سياره'],
  ['bicycle', 'bicycles', 'bike', 'bikes', 'دراجه'],
  ['dog', 'dogs', 'puppy', 'كلب'],
  ['cat', 'cats', 'kitten', 'قطه', 'قط'],
  ['person', 'people', 'man', 'men', 'woman', 'women', 'child', 'children', 'kid', 'kids', 'boy', 'boys', 'girl', 'girls',
    'mom', 'mum', 'mother', 'dad', 'father', 'brother', 'sister', 'baby', 'grandma', 'grandpa', 'grandmother', 'grandfather',
    'someone', 'somebody', 'teacher', 'friend', 'شخص', 'اشخاص', 'رجل', 'امراه', 'طفل', 'ولد', 'بنت', 'ام', 'اب', 'اخ', 'اخت', 'احد', 'ماما', 'بابا'],
  ['remote', 'remotes', 'ريموت'],
  ['fan', 'fans', 'مروحه'],
  ['curtain', 'curtains', 'blind', 'blinds', 'ستاره', 'ستائر'],
  ['bin', 'bins', 'trash', 'basket', 'baskets', 'سله', 'زباله'],
  // Never stated from a model guess: these need detector support or a hedge.
  ['knife', 'knives', 'scissors', 'blade', 'blades', 'pill', 'pills', 'medicine', 'medicines', 'medication', 'lighter', 'matches',
    'needle', 'needles', 'fire', 'flame', 'flames', 'سكين', 'مقص', 'دواء', 'حبوب', 'ولاعه', 'كبريت', 'ابره', 'نار']
];
const PEOPLE_GROUP = 'person';
const VISUAL_HEDGE = /\b(?:maybe|perhaps|possibly|probably|might|may be|could be|looks like|appears|seems|i think|not sure|unclear)\b/i;
const AR_VISUAL_HEDGE = /(ربما|يبدو|قد يكون|اظن|لست متاكد|يشبه|غالبا)/;
// Model directions to everyday objects must sound uncertain (spatial rule 3).
const DIRECTION = /\b(?:to your (?:left|right)|on your (?:left|right)|in front of you|ahead of you|straight ahead|behind you|o'?clock)\b/i;
const AR_DIRECTION = /(يمينك|يسارك|امامك|خلفك|قدامك|علي اليمين|علي اليسار)/;

/** English words with possessive 's removed. */
function words(text) {
  return text.toLowerCase().replace(/_/g, ' ').replace(/[’‘]/g, "'").split(/[^a-z']+/)
    .map(word => word.replace(/'s$/, '').replace(/'/g, '')).filter(Boolean);
}

function arabicWords(text) {
  return arabicFolded(text).split(/[^ء-ي]+/).filter(Boolean);
}

const GROUP_BY_WORD = new Map();
for (const group of OBJECT_GROUPS) for (const word of group) if (!GROUP_BY_WORD.has(word)) GROUP_BY_WORD.set(word, group[0]);

function groupOf(word) {
  return word ? GROUP_BY_WORD.get(word) ?? null : null;
}

/** Arabic word → {group, owned}: exact, then without a joined و/ب/ل/ف, then without ال,
 * then without a possessive suffix (ك/كم = "your", which is an identity claim). */
function arabicGroup(word) {
  const forms = [word];
  if (/^[وبلف]/.test(word) && word.length > 3) forms.push(word.slice(1));
  for (const form of [...forms]) if (form.startsWith('ال') && form.length >= 4) forms.push(form.slice(2));
  for (const form of forms) { const group = groupOf(form); if (group) return { group, owned: false }; }
  for (const form of forms) {
    for (const suffix of ['كم', 'ك', 'ها', 'هم', 'ه', 'ي']) {
      if (form.endsWith(suffix) && form.length - suffix.length >= 2) {
        const group = groupOf(form.slice(0, -suffix.length));
        if (group) return { group, owned: suffix === 'ك' || suffix === 'كم' };
      }
    }
  }
  return null;
}

/** Object groups named in a sentence (English and Arabic). */
export function mentionedObjects(text) {
  const found = new Set();
  for (const word of words(text)) { const group = groupOf(word); if (group) found.add(group); }
  for (const word of arabicWords(text)) { const match = arabicGroup(word); if (match) found.add(match.group); }
  return found;
}

/** Groups supported by detector labels seen in at least `minimum` frames. Fewer frames confirm nothing. */
export function agreedObjects(frames, minimum = 2) {
  const counts = new Map();
  for (const frame of frames) {
    const seen = new Set();
    for (const label of frame.labels ?? []) for (const group of mentionedObjects(label)) seen.add(group);
    if ((frame.people ?? 0) > 0) seen.add(PEOPLE_GROUP);
    for (const group of seen) counts.set(group, (counts.get(group) ?? 0) + 1);
  }
  return new Set([...counts].filter(([, count]) => count >= minimum).map(([group]) => group));
}

// A model missing an object is not evidence of absence (small models miss visible stairs), and a
// generic sighting is not the person's own item (identity needs image comparison with saved views).
const VISUAL_ABSENCE = /\b(?:there(?:'s|’s|\s+is|\s+are)\s+no|there\s+(?:isn't|aren't|is not|are not)|(?:is|are)\s*(?:not|n't)\s+(?:here|there|visible|in (?:the |this )?(?:view|picture|photo|image|room))|(?:isn't|aren't)\s+(?:here|there|visible|any)|no\s+[a-z]+\s+(?:here|in view|visible|in (?:the |this )?(?:picture|photo|image))|no\s+[a-z]+\s+(?:is|are)\s+visible|see\s+no|i\s+(?:don't|do not|can't|cannot|couldn't|could not)\s+see\s+(?:a|an|any|the|your)|nothing\s+(?:here|in view|visible)|not\s+found|is missing|are missing)\b/i;
const AR_VISUAL_ABSENCE = /(لا يوجد|لا توجد|ليس هناك|ليست هناك|لا اري|غير موجود|مفقود|ما في|مافي|مو موجود|ما اشوف)/;

function identityClaim(sentence) {
  const list = words(sentence);
  const english = list.some((word, index) => (word === 'your' && list.slice(index + 1, index + 4).some(groupOf)) ||
    (word === 'yours' && list.some(groupOf)));
  return english || arabicWords(sentence).some(word => arabicGroup(word)?.owned === true);
}

export function isAbsenceClaim(sentence) {
  return VISUAL_ABSENCE.test(sentence.replace(/[’‘]/g, "'")) || AR_VISUAL_ABSENCE.test(arabicFolded(sentence));
}

function hedged(sentence) {
  return VISUAL_HEDGE.test(sentence) || AR_VISUAL_HEDGE.test(arabicFolded(sentence));
}

/** Keeps hedged sentences and sentences whose named objects were all confirmed; '' when nothing remains.
 * Absence and "your <object>" identity claims are always dropped, and so are unhedged directions. */
export function groundedDescription(text, confirmed) {
  return sentences(text).filter(sentence => {
    if (isAbsenceClaim(sentence) || identityClaim(sentence)) return false;
    if (hedged(sentence)) return true;
    if (DIRECTION.test(sentence) || AR_DIRECTION.test(arabicFolded(sentence))) return false;
    return [...mentionedObjects(sentence)].every(group => confirmed.has(group));
  }).join('').trim();
}
