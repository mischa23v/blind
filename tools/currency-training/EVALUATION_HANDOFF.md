# From training evidence to real app evaluation

## Two different evaluations, never interchangeable

`currency_training.py evaluate` measures the classifier on **ground-truth note
crops** using cached real encoder features. It produces a JSON metric summary.
It does not know whether the app found the note, cropped it correctly, rejected
other rectangles, stabilized over time or spoke the right denomination.

The sibling `../currency-evaluation/evaluate.py` expects a **whole-frame/scene
manifest plus actual final spoken decisions**, not a crop confusion matrix.
Do not convert head argmax or probabilities into `spoken_denomination`: that
would omit the app's proposal, quality, abstention and temporal decision logic.

## Reusable training provenance

Keep these artifacts together privately:

- Original local image hashes and reviewed physical-note/scene identities.
- Frozen `manifest.grouped.json`, including train/calibration/test assignments.
- Cache `manifest.json` and `cache.json` hashes, and the pinned encoder hash.
- Trained `head-v1.json`, calibration evidence, and crop-only test report.
- Exported raw `.mlmodel` plus `.contract.json` with actual model SHA-256.

The training manifest has one row per **object crop**. Multiple object rows may
share a source image. The runtime evaluation manifest instead needs one reviewed
row per full scene/sample, with all constituent physical-note IDs, and no
cross-partition identity reuse. Do not duplicate a multiple-note scene as if its
individual crops were independent single-note camera inputs.

## Runtime evidence requirements

At the time this handoff was written, the sibling evaluator requires JSONL
manifest fields:

- `sample_id`: stable whole-frame/scene ID, matching the captured prediction.
- `group_id`: repeated scene or physical-note group.
- `physical_note_ids`: identities of every constituent note, particularly in
  multi-note scenes. Reuse the exact IDs from training and negative manifests.
- `split`: train, calibration or test. The evaluator requires declarations of
  all partitions but scores test samples only.
- `expected`: integer 1/5/10/20/50/100/200/500, or string `unknown`.
- `condition`: clean/folded/occluded for positives;
  foreign/non_money/multiple_notes/partial_note for unknown scenes. The sibling
  evaluator must include the explicit partial-note schema update described below.
- `side`: front/back for a positive note, n/a for unknown scenes.
- `variant`: reviewed actual note issue/material; n/a for unknown scenes.
- `image_sha256`: recommended original full-frame image digest.

Training VOC boxes do not establish side, variant, physical-note identity,
fold/occlusion status or full-frame expected behavior. These fields need real
review; no defaults should invent that evidence.

Prediction JSONL must contain each actual test `sample_id` and final
`spoken_denomination`: an integer supported denomination or `abstain`.
Missing or failed app predictions must not be silently dropped. Record an
actual abstention only if that was the observed final runtime decision.

Run metadata needs stable `model_id`, `dataset_id`, `decision_policy_id`,
`frozen_before_test: true`, and `data_kind: real`. Set these only when true.
Use the raw model hash/contract to identify the exact model and document the
actual frozen thresholds, margin, temporal and rectangle-selection policy.

The evaluator's required coverage is stricter than this training pipeline:
front/back and clean/folded/occluded cells for every denomination, 5 SAR
paper/polymer cells, and negative conditions. Passing training-manifest presence
checks does not satisfy these runtime coverage requirements.

## Partial-note schema compatibility

The training schema explicitly supports `partial_note` as an unknown example
and requires its underlying physical-note IDs. Use the sibling evaluator version
that explicitly supports `partial_note` as a negative condition, requires at
least one `physical_note_ids` member, checks those IDs in the same leakage
namespace as full-note groups, and requires partial-note test coverage. This
update is being coordinated separately; older evaluator versions reject it.
Do **not** silently rename partial unknown notes to positive `occluded`,
`non_money`, or another category merely to pass validation.

## Required verification still not performed

1. Actual encoder hash/config validation and HDF5 loading.
2. Real Saudi embeddings, fitted head and data-independent held-out metrics.
3. Successful actual Core ML conversion with the nine-label output contract.
4. Probability/top-label parity for real held-out crops on macOS or iPhone.
5. Real app full-frame inference using its exact capture/crop/proposal policy.
6. Runtime false-acceptance, abstention and spoken-decision evaluation using
   sufficient independent groups, including foreign, non-money, partial and
   multiple-note scenes.

Nothing in this preparation automatically selects the phone profile or proves
recognition quality, genuine-note authentication, legal clearance or release
readiness. The source and synthetic plumbing tests are the completed work.
