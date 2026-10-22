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
const FIND = [
  /^(?:(?:can|could|will|would) you\s+)?(?:please\s+)?(?:help me\s+)?(?:to\s+)?(?:find|look for|search for|locate)\s+(?:my|our)\s+(.+)$/i,
  /^i\s+(?:can't|cannot|can not|couldn't|could not)\s+find\s+(?:my|our)\s+(.+)$/i,
  /^i(?:'ve| have)?\s+lost\s+(?:my|our)\s+(.+)$/i,
  /^i(?:'m| am)\s+looking for\s+(?:my|our)\s+(.+)$/i,
  /^(?:ساعدني|ساعديني)\s+(?:[اأ]لاقي|[اأ]لقى|[اأ]جد|[اأ]دور على|[اأ]بحث عن|في البحث عن)\s+(.+)$/,
  /^(?:ما|مو)\s+(?:لقيت|حصلت|[اأ]جد|[اأ]لقى)\s+(.+)$/,
  /^(?:ضاع|ضاعت|فقدت|[اأ]ضعت)\s+(.+)$/
];
const REPORT_ACTION = new RegExp(String.raw`^i\s+(?:last\s+|just\s+)?(?:left|put|placed|dropped|set|had|kept|saw|forgot)\s+(?:(?:my|the|our)\s+(.+?)|(it|them))\s+` + PLACE + '$', 'i');
const REPORT_STATE = new RegExp(String.raw`^(?:(?:my|the|our)\s+(.+?)|(it|they))(?:\s+(is|are|was|were)|('s))\s+(?:still\s+)?` + PLACE + '$', 'i');
const AR_REPORT_ACTION = new RegExp(String.raw`^(?:تركت|حطيت|وضعت|نسيت|خليت)(ه|ها|هم)?\s+(?:(.+?)\s+)??` + AR_PLACE + '$');
const HEDGE_PREFIX = /^(?:i think|i guess|maybe|probably)\s+(?:that\s+)?/i;
const AR_HEDGE_PREFIX = /^(?:[اأ]ظن|[اأ]عتقد|يمكن|ربما)\s+(?:[اأ]ن(?:ي|ه|ها)?\s+)?/;
const TRAILING = /\s+(?:please|again|now|for me|right now|instead|too|as well)$/i;

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
  if ((objectText != null && !object) || !place) return null;
  return { kind: 'report', object, place, tense, hedged };
}

// --- Model chat claims ---------------------------------------------------------------------

// A chat reply with no live camera may not state where an object is now, that it is present
// or absent, or that the assistant perceived anything. Past-tense attributions ("you said your
// cup was on the table") and questions are allowed. Conservative lexical check, not a proof.
const PREP = String.raw`(?:on top of|in front of|next to|on|in|under|underneath|inside|behind|beside|near|by|at|over there|right there|there|here)`;
const CLAIMS = [
  new RegExp(String.raw`\b(?:your|the|my|his|her|their|our)\s+[a-z][a-z' -]{0,30}?\s+(?:is|are|'s)\s+(?:still\s+|now\s+|right\s+|probably\s+|likely\s+|definitely\s+)?` + PREP + String.raw`\b`, 'i'),
  new RegExp(String.raw`\b(?:it|they)(?:'s|’s|\s+is|\s+are)\s+(?:still\s+|now\s+|right\s+|probably\s+|likely\s+)?` + PREP + String.raw`\b`, 'i'),
  new RegExp(String.raw`\b(?:might|may|could|must|should)\s+(?:still\s+)?be\s+` + PREP + String.raw`\b`, 'i'),
  /\b(?:is|are)\s*(?:not|n't)\s+(?:here|there|found|around|in (?:the|this|your) room)\b/i,
  /\b(?:isn't|aren't)\s+(?:here|there|around)\b/i,
  /\b(?:not found|is missing|are missing|is gone|are gone|has gone|have gone|is lost|are lost|no longer there)\b/i,
  /\bi\s+(?:can see|could see|found|spotted|located|noticed|see (?:a|an|the|your|it|them|some))\b/i,
  /\bthere(?:'s|’s|\s+is|\s+are)\s+(?:a|an|the|some|your|two|three|many)\s+[a-z]/i
];
const AR_CLAIMS = [
  /(موجود|موجوده|يوجد|توجد|يقع|تقع)\s+(على|علي|في|تحت|عند|جنب|بجانب|قرب|فوق|داخل|هنا|هناك)/,
  /(?:^|\s)(غير موجود|مفقود|ضاع|ضاعت|اختفي|اختفت|ليس هنا|مو هنا)(?=$|\s|[.!,،؛؟])/,
  /(?:^|\s)(اشوف|اري|رايت|شفت|وجدت|لقيت|الاحظ)(?=$|\s|[.!,،؛؟])/
];

function arabicFolded(text) {
  return normalizeArabic(text).replace(/ى/g, 'ي');
}

export function sentences(text) {
  const result = [];
  let current = '';
  const chars = [...text];
  chars.forEach((ch, i) => {
    current += ch;
    const decimal = ch === '.' && i > 0 && i + 1 < chars.length && /\d/.test(chars[i - 1]) && /\d/.test(chars[i + 1]);
    if ('.!?؟;؛،\n'.includes(ch) && !decimal) { result.push(current); current = ''; }
  });
  if (current) result.push(current);
  return result;
}

export function isUnsupportedClaim(sentence) {
  if (/[?؟]\s*$/.test(sentence.trim())) return false;
  const plain = sentence.replace(/[’‘]/g, "'");
  if (CLAIMS.some(pattern => pattern.test(plain))) return true;
  const arabic = arabicFolded(sentence);
  return AR_CLAIMS.some(pattern => pattern.test(arabic));
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
// two of the recent frames; otherwise the sentence must be hedged or it is dropped.
export const OBJECT_GROUPS = [
  ['cup', 'cups', 'mug', 'mugs', 'glass', 'glasses', 'tumbler'],
  ['table', 'tables', 'desk', 'desks'],
  ['chair', 'chairs', 'stool', 'stools', 'armchair', 'armchairs'],
  ['sofa', 'sofas', 'couch', 'couches'],
  ['bed', 'beds'],
  ['door', 'doors', 'doorway'],
  ['window', 'windows'],
  ['lamp', 'lamps'],
  ['television', 'televisions', 'tv', 'tvs'],
  ['monitor', 'monitors', 'screen', 'screens'],
  ['laptop', 'laptops', 'computer', 'computers', 'keyboard', 'keyboards'],
  ['phone', 'phones', 'smartphone', 'smartphones'],
  ['book', 'books', 'notebook', 'notebooks'],
  ['bag', 'bags', 'backpack', 'backpacks', 'handbag', 'handbags'],
  ['bottle', 'bottles'],
  ['plate', 'plates', 'bowl', 'bowls', 'dish', 'dishes'],
  ['refrigerator', 'refrigerators', 'fridge', 'fridges'],
  ['oven', 'ovens', 'stove', 'stoves', 'microwave', 'microwaves'],
  ['sink', 'sinks'],
  ['toilet', 'toilets'],
  ['shelf', 'shelves', 'bookshelf', 'bookshelves', 'bookcase', 'bookcases'],
  ['cabinet', 'cabinets', 'cupboard', 'cupboards', 'wardrobe', 'wardrobes', 'drawer', 'drawers'],
  ['painting', 'paintings', 'picture', 'pictures', 'poster', 'posters', 'frame', 'frames'],
  ['plant', 'plants', 'flower', 'flowers', 'vase', 'vases'],
  ['rug', 'rugs', 'carpet', 'carpets', 'mat', 'mats'],
  ['pillow', 'pillows', 'cushion', 'cushions'],
  ['blanket', 'blankets'],
  ['clock', 'clocks'],
  ['mirror', 'mirrors'],
  ['box', 'boxes', 'carton', 'cartons'],
  ['toy', 'toys', 'teddy', 'doll', 'dolls'],
  ['ball', 'balls'],
  ['shoe', 'shoes', 'sneaker', 'sneakers', 'boot', 'boots'],
  ['car', 'cars'],
  ['bicycle', 'bicycles', 'bike', 'bikes'],
  ['dog', 'dogs', 'puppy'],
  ['cat', 'cats', 'kitten'],
  ['person', 'people', 'man', 'men', 'woman', 'women', 'child', 'children', 'kid', 'kids', 'boy', 'boys', 'girl', 'girls'],
  ['remote', 'remotes'],
  ['fan', 'fans'],
  ['curtain', 'curtains', 'blind', 'blinds'],
  ['bin', 'bins', 'trash', 'basket', 'baskets']
];
const PEOPLE_GROUP = 'person';
const VISUAL_HEDGE = /\b(?:maybe|perhaps|possibly|probably|might|may be|could be|looks like|appears|seems|i think|not sure|unclear)\b/i;

function words(text) {
  return text.toLowerCase().replace(/_/g, ' ').split(/[^a-z']+/).filter(Boolean);
}

function groupOf(word) {
  for (const group of OBJECT_GROUPS) if (group.includes(word)) return group[0];
  return null;
}

/** Object groups named in a sentence. */
export function mentionedObjects(text) {
  const found = new Set();
  for (const word of words(text)) {
    const group = groupOf(word);
    if (group) found.add(group);
  }
  return found;
}

/** Groups supported by detector labels seen in at least `minimum` of the frames. */
export function agreedObjects(frames, minimum = 2) {
  const counts = new Map();
  for (const frame of frames) {
    const seen = new Set();
    for (const label of frame.labels ?? []) for (const group of mentionedObjects(label)) seen.add(group);
    if ((frame.people ?? 0) > 0) seen.add(PEOPLE_GROUP);
    for (const group of seen) counts.set(group, (counts.get(group) ?? 0) + 1);
  }
  return new Set([...counts].filter(([, count]) => count >= Math.min(minimum, frames.length)).map(([group]) => group));
}

/** Keeps hedged sentences and sentences whose named objects were all confirmed; '' when nothing remains. */
export function groundedDescription(text, confirmed) {
  return sentences(text).filter(sentence => {
    if (VISUAL_HEDGE.test(sentence)) return true;
    return [...mentionedObjects(sentence)].every(group => confirmed.has(group));
  }).join('').trim();
}
