# Reconstructed local reference-matching experiment

**Recovery version, not the original frozen bytes.** The shared workspace disappeared on 2026-10-22. This folder reconstructs the no-training prototype from retained conversation/source excerpts. No claim of original hash equality or unchanged real-image behavior is made. See `RECOVERY.md`.

This is an isolated, evidence-only Python adapter to official OpenCV SIFT, ORB and AKAZE. It does not train a classifier, use OCR as a decider, download images/models, edit an app, speak money, authenticate notes or determine legal-tender status. Every result has `monetary_answer: null` and `validated: false`. The application must remain unavailable unless separately validated and explicitly integrated.

## Run

Use Python 3.12 and the pinned official PyPI dependencies. This setup downloads software only, not photos, weights or a learned classifier:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
PYTHONDONTWRITEBYTECODE=1 .venv/bin/python reference_match.py --algorithm akaze --manifest manifest.empty.json --query absent.jpg
PYTHONDONTWRITEBYTECODE=1 .venv/bin/python -m unittest -v test_reference_match test_compare_reference_methods test_prepare_reference
```

An empty bank returns unknown without opening a query. With verified local references, select `sift`, `orb` or `akaze` and pass a private query path. SIFT uses L2; ORB/AKAZE use Hamming. Query-to-reference ratio matches feed upstream RANSAC homography. Unique inliers, spread, spatial grid, convex in-frame quad, area/angle/edge/projective/reprojection gates and different-denomination runner-up margin are required. The result includes all candidate evidence and exact parameters. A close margin gives ambiguous; low evidence gives unknown, not the nearest guessed label.

## Manifest contract

The top-level fields are exactly `schema_version: 1`, `reference_kind` (`private_banknote_photos` or `synthetic_mechanics`), `currency: SAR`, `labels: [1,5,10,20,50,100,200,500]`, and `references`. This vocabulary does not mean all eight denominations are actually covered.

Each reference has exactly `id`, `path`, `sha256`, `label`, `side`, `issue`, `material`, `physical_note_id`, `capture_session_id`, `source`, `rights`, and `verification`. Use front/back and paper/polymer. Record uncertainty instead of inventing identity or issue information. Paths must stay below the manifest directory, including symlinks; file hashes are pinned; duplicate hashes/IDs/JSON keys are rejected.

`verification` has exactly `verified: true`, `verification_kind`, `verified_by`, `verified_on`, `method`. Kinds are human_review, assistant_visual_review, or synthetic_fixture. Never call assistant inspection human approval. Synthetic kinds are forbidden in a real-photo manifest. The loader verifies that the assertion is recorded; it cannot establish that it is true. Hashes prove neither accurate labels, rights nor authenticity.

Only single-frame PNG/JPEG, orientation 1, 32–4096 pixels per side and at most 8 million pixels are supported. Normalize EXIF separately and record the derivative before hashing. At most 48 references, 256 KiB manifest, 8 MiB per image. Query/reference maximum sides are 1200/800; requested features 1800; one CPU thread, OpenCL off, at most 1500 RANSAC iterations and two hypotheses per reference. Thresholds are explicit unvalidated experimental defaults, not currency release thresholds.

Reference image corners must represent explicitly reviewed visible note boundaries, not surrounding background. `prepare_reference.py` accepts source-pixel TL/TR/BR/BL corners and writes a new grayscale PNG plus source/output/code-hashed receipt. It performs no detection. Never invent clipped corners, confuse display coordinates with source pixels, or count the derived reference as a new independent note. The preparation implementation itself is reconstructed.

## Bounded comparison

`compare_reference_methods.py --references private/references.json --queries private/queries.json --output private/new-results.json` runs all three methods with the same inputs. Output files cannot be overwritten. Query manifest top fields are `schema_version:1`, `evaluation_kind:development_diagnostic`, `independence_summary`, `queries` (1–32 entries).

Each query contains exactly `id`, `path`, `sha256`, `expected_label` (null for non-SAR negatives), `must_abstain`, `case_role`, `physical_note_id`, `capture_session_id`, `independence_from_references`, `source`, `rights`, `notes`. Unknown note/capture IDs may be null. The comparator separately counts wrong labels, negative false accepts, policy false accepts and abstentions. A correct denomination on a required-abstention scene is still a policy error. No accuracy percentage is computed.

## Major limitation and required evidence

Matching one known note **cannot prove only one note is present**. Unsupported, overlapping, heavily occluded or duplicate notes may evade the bounded second hypothesis. Historical testing of the lost original version demonstrated this failure: every method accepted a known front inside a front/back composite. This reconstruction has not repeated that photo evaluation and must not inherit its results.

Before any production use, obtain a rights-reviewed human-audited inventory for all intended denominations/sides/issues/materials, including modern 1, 20 and paper/polymer 5. Separate physical notes, captures, source images, mirrors and transformations across development/calibration/held-out sets. Include real foreign money, receipts, packaging, screens, nonmoney, folds, blur, glare, wear, hands, clipping and same/different/unsupported/overlapping multiple notes. Measure wrong-value costs, unknown acceptance, abstention and missing coverage. No finite diagnostic proves future zero error. No iPhone implementation, frame freshness, speech, cancellation, thermal or device-accessibility validation is provided here.

Reference matching does not logically require a newly trained classifier. Established local features can identify geometric correspondences, but need visible texture, approximately planar content and representative references. A trained head has different tradeoffs, not an automatic reliability advantage; either route needs real evidence.

Private photos/results must stay outside publication. `.gitignore` excludes `private/`. Upstream APIs come from OpenCV; no alternate custom feature recognizer is substituted. This package contains only adapter/tests/documentation, not upstream binaries or banknote assets.

## New dataset evidence (2026-10-23)

See `DATASET_DIAGNOSTIC_20261023.md` and its JSON for fresh, explicitly non-independent real-photo comparisons and reproduced overlapping-note failures. The profile remains disabled. `EVALUATION_CONTRACT.md` describes the new strict held-out runner; it does not turn this dataset into independent evidence.
