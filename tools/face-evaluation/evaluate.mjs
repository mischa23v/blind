/** Synthetic evaluation plumbing only. Not a face recognizer, PAD, or app policy. */
import { pathToFileURL } from 'node:url';

function finite(value) { return typeof value === 'number' && Number.isFinite(value); }
function unit(vector) {
  if (!Array.isArray(vector) || !vector.length || !vector.every(finite)) throw new Error('Invalid vector');
  const norm = Math.hypot(...vector);
  if (!finite(norm) || norm === 0) throw new Error('Invalid norm');
  return vector.map(x => x / norm);
}
export function cosine(a, b) {
  const x = unit(a), y = unit(b);
  if (x.length !== y.length) throw new Error('Dimension mismatch');
  return Math.max(-1, Math.min(1, x.reduce((s, v, i) => s + v * y[i], 0)));
}
export const DEMO_POLICY = Object.freeze({ threshold: 0.9, margin: 0.1, minQuality: 0.7, maxAge: 1 });
function validatePolicy(p) {
  if (!p || !finite(p.threshold) || p.threshold < -1 || p.threshold > 1 ||
      !finite(p.margin) || p.margin <= 0 || p.margin > 2 ||
      !finite(p.minQuality) || p.minQuality < 0 || p.minQuality > 1 ||
      !finite(p.maxAge) || p.maxAge <= 0) throw new Error('Invalid policy');
}
// Every abstention has identity=null, including ambiguity. Scores are not probabilities.
export function classify(probe, gallery, policy = DEMO_POLICY) {
  validatePolicy(policy);
  const abstain = reason => ({ identity: null, reason });
  if (!probe || !finite(probe.quality) || probe.quality < policy.minQuality || probe.quality > 1)
    return abstain('quality');
  if (!finite(probe.age) || probe.age < 0 || probe.age > policy.maxAge) return abstain('stale');
  if (probe.ambiguousTrack !== false) return abstain('track_ambiguous');
  if (!Array.isArray(gallery) || !gallery.length) return abstain('empty_gallery');
  try {
    unit(probe.embedding);
    const ids = new Set();
    const scores = gallery.map(record => {
      if (!record || typeof record.id !== 'string' || !record.id || ids.has(record.id) ||
          record.consented !== true || !record.model || record.model !== probe.model ||
          !Array.isArray(record.templates) || !record.templates.length) throw new Error('Invalid gallery');
      ids.add(record.id);
      // Fixed policy for the experiment: maximum over templates, one score per person.
      // Real template count and aggregation must be fixed before calibration.
      return { id: record.id, score: Math.max(...record.templates.map(v => cosine(probe.embedding, v))) };
    }).sort((a, b) => b.score - a.score || a.id.localeCompare(b.id));
    const best = scores[0];
    if (best.score < policy.threshold) return abstain('below_threshold');
    // No runner-up exists in a one-person gallery; absolute threshold still applies.
    if (scores.length > 1 && best.score - scores[1].score < policy.margin) return abstain('runner_up');
    return { identity: best.id, reason: 'synthetic_candidate', score: best.score };
  } catch { return abstain('invalid_input'); }
}

export function summarize(rows) {
  const counts = { total: rows.length, known: 0, unknown: 0, correctKnown: 0,
    wrongKnown: 0, knownAbstained: 0, falseUnknown: 0, unknownAbstained: 0 };
  for (const { truth, result } of rows) {
    if (truth === null) {
      counts.unknown++;
      counts[result.identity === null ? 'unknownAbstained' : 'falseUnknown']++;
    } else {
      counts.known++;
      counts[result.identity === null ? 'knownAbstained' : result.identity === truth ? 'correctKnown' : 'wrongKnown']++;
    }
  }
  const rate = (n, d) => d ? n / d : null;
  return { ...counts, unknownFalseIdentificationRate: rate(counts.falseUnknown, counts.unknown),
    knownWrongIdentityRate: rate(counts.wrongKnown, counts.known),
    knownAbstentionRate: rate(counts.knownAbstained, counts.known),
    knownCorrectIdentificationRate: rate(counts.correctKnown, counts.known) };
}
export function syntheticExperiment() {
  const model = 'synthetic-v1';
  const gallery = [
    { id: 'enrolled-A', consented: true, model, templates: [[1, 0, 0]] },
    { id: 'enrolled-B', consented: true, model, templates: [[0, 1, 0]] },
  ];
  const base = { model, quality: 1, age: 0, ambiguousTrack: false };
  const fixtures = [
    { case: 'known-A', truth: 'enrolled-A', embedding: [1, 0, 0] },
    { case: 'known-B', truth: 'enrolled-B', embedding: [0, 1, 0] },
    { case: 'unknown-orthogonal', truth: null, embedding: [0, 0, 1] },
    { case: 'ambiguous-known', truth: 'enrolled-A', embedding: [1, 1, 0] },
    { case: 'poor-quality', truth: 'enrolled-A', embedding: [1, 0, 0], quality: 0.2 },
    { case: 'stale', truth: 'enrolled-A', embedding: [1, 0, 0], age: 5 },
    // Intentional failure: a collision/spoof-like embedding defeats this similarity gate.
    { case: 'unknown-collision', truth: null, embedding: [1, 0, 0] },
  ];
  const rows = fixtures.map(f => ({ case: f.case, truth: f.truth, result: classify({ ...base, ...f }, gallery) }));
  return { schema: 1, evidence: 'SYNTHETIC ONLY: not model accuracy, PAD, or guardian verification',
    policy: DEMO_POLICY, policyCalibrated: false, biometricModelRun: false,
    presentationAttackDetection: 'not implemented', appIntegration: false, rows, metrics: summarize(rows) };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv.length !== 2) throw new Error('Synthetic-only CLI accepts no file, image, or dataset arguments');
  console.log(JSON.stringify(syntheticExperiment(), null, 2));
}
