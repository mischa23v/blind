# Saudi banknote decision evaluation

Dependency-free Python 3 evaluation of **exported model decisions**, not a note
recognizer, model, dataset, or evidence that any recognition model is accurate.
No real banknote images or real prediction records are bundled. The unit tests
generate clearly labelled synthetic records to test the harness only.

## Run

```sh
python3 -m unittest discover -s tools/currency-evaluation -v
python3 tools/currency-evaluation/evaluate.py \
  --manifest /path/to/manifest.jsonl \
  --predictions /path/to/predictions.jsonl \
  --run-metadata /path/to/run-metadata.json \
  --min-groups 30 \
  --output /path/to/report.json
```

Run these from the preparation root, or use absolute paths. No packages need to
be installed. Exit 0 means input validation and report generation succeeded,
**not** that a model passed a release gate. Exit 2 means evaluation was refused.
The evaluator does not pick a confidence threshold or tune on the test set.

`--min-groups` defaults to 1 so a collected pilot can be inspected; this is not a
statistically adequate sample-size recommendation. Choose a sample size and
risk limits before collecting/inspecting test results. The example 30 is also
illustrative, not a safety guarantee. Unrecorded capture-session correlations
can invalidate even a seemingly large set of physical-note trials.

## Manifest contract (JSON Lines)

One JSON object per image/frame/capture. Required fields:

| Field | Meaning |
| --- | --- |
| `sample_id` | Globally unique stable capture ID. |
| `group_id` | Stable physical-note ID for a single-note sample; stable scene/source-object ID for a negative. Never a different ID for each crop or frame of the same note. |
| `split` | Exactly `train`, `calibration`, or `test`. All three must be declared and nonempty. |
| `expected` | Integer SAR value: 1, 5, 10, 20, 50, 100, 200, 500; or string `unknown`. |
| `condition` | Recognizable single supported Saudi note: `clean`, `folded`, `occluded`. Negative: `foreign`, `non_money`, `multiple_notes`, `partial_note`. Severe/incomplete note views that must abstain use `partial_note`, never positive `occluded`. |
| `side` | Positive: `front` or `back`. Negative: `n/a`. |
| `variant` | Positive: an explicit stable issue/material label. 5 SAR variants use exactly `paper` or `polymer`. Negative: `n/a`. |
| `physical_note_ids` | Optional array for positive single notes; required for `partial_note` (at least one ID) and `multiple_notes` (at least two IDs), including every physical note's stable ID. Share identifiers with positive, partial and multiple-note images of those notes. |
| `image_sha256` | Optional lowercase 64-character image-content digest. Duplicate image bytes are rejected, including within a split. |

Illustrative schema only, **not a dataset**:

```json
{"sample_id":"capture-0001","group_id":"note-0001","split":"test","expected":100,"condition":"occluded","side":"back","variant":"paper"}
{"sample_id":"capture-0002","group_id":"scene-0002","split":"test","expected":"unknown","condition":"multiple_notes","side":"n/a","variant":"n/a","physical_note_ids":["note-0001","note-0002"]}
{"sample_id":"capture-0003","group_id":"scene-0003","split":"test","expected":"unknown","condition":"partial_note","side":"n/a","variant":"n/a","physical_note_ids":["note-0001"]}
```

Use one identity namespace across `group_id` and `physical_note_ids`. All images,
crops, augmentations, videos, sides, and captures of a physical note belong to
one split. Every listed identity is checked across train/calibration/test;
single-note records cannot disagree on their identity's value or variant.
Positive, partial and multiple-note scenes sharing physical notes form a connected component and are counted as
one group for coverage and confidence intervals. Do not reuse IDs for unrelated
notes. Do not renumber a note to hide overlap.

The harness cannot determine whether a person supplied truthful identities,
whether unknown-source training data overlaps, or whether near-duplicates with
different bytes exist. Record capture-session/source provenance externally and
design splits conservatively. Shared devices, locations, illumination, and
collection sessions need separate study. A declared `train` split is not an
audit of a pretrained model's complete upstream training corpus.

Test coverage is mandatory for every denomination × front/back ×
clean/folded/occluded cell. Both paper and polymer 5 SAR get separate mandatory
coverage for each side and condition. Foreign currency, non-money objects,
multiple-note scenes and severe/incomplete `partial_note` scenes are each required. Every cell needs at least
`--min-groups` connected physical-note/scene groups. The 20 and 200 SAR notes are
not omitted. `variant` can distinguish their issue designs, but the default
profile does not claim to cover every historical Saudi issue.

Have qualified annotators define the positive/negative visibility boundary
before inspecting predictions. Positive `occluded` samples retain sufficient
visual evidence for a reliable value label; the recognizer may still abstain.
Severe/incomplete partial views that cannot safely support a spoken value must
be negative `partial_note`, with expected `unknown`, even when their physical
source note is known. Never relabel these unknown partials as positive occluded
samples to meet coverage. Track the original physical note ID across every
partial crop and its other positive/multiple-note images to prevent split leakage.
Multi-note scenes must be `unknown`, even when every note has the same
value: this evaluator tests a **single-note spoken-value** policy, not sums.
More severe/combined conditions, lighting, distances, blur, orientation,
language/script cues, foreign-currency diversity, counterfeit detection and
live camera/audio behavior require additional held-out tests. This profile
does not certify that those scenarios work.

## Prediction and run-metadata contract

Exactly one record for every manifest `test` sample, no other samples:

```json
{"sample_id":"capture-0001","spoken_denomination":100}
{"sample_id":"capture-0002","spoken_denomination":"abstain"}
```

`spoken_denomination` is an integer supported SAR value or exactly `abstain`.
Export the **final app decision after its locked gating/debouncing policy**,
not an ungated classifier argmax. An abstention is an explicit decision, never
an omitted prediction. Record crashes/timeouts separately; do not silently
convert a failure to a deliberate abstention. Missing output refuses evaluation.
Other prediction fields are ignored. No threshold sweep is performed.

Run metadata is a single JSON object:

```json
{"model_id":"actual-model-artifact-hash-or-version","dataset_id":"actual-dataset-version","decision_policy_id":"actual-frozen-gating-version","frozen_before_test":true,"data_kind":"real"}
```

Keep model weights, policy/thresholds, and dataset fixed before test evaluation.
Metadata is a provider assertion, not provenance verified by this tool. Record
the actual model/app build and test-collection evidence alongside the report.
Synthetic data must set `data_kind` to `synthetic` and requires explicit
`--allow-synthetic`; its report is prominently marked **NOT MODEL ACCURACY**.
Input-file SHA-256 digests are attached to CLI reports for reproducibility.

## Interpretation

- Overall spoken-decision precision includes wrong values on known notes and
  false acceptance of foreign/non-money/multiple-note/partial-note scenes. Report it together
  with abstention and positive correct coverage; never praise precision achieved
  by abstaining on everything. No spoken decisions means precision is undefined
  (`null`), not 100%.
- Per-value precision counts all predictions of that value, including negatives.
  Recall is correct spoken decisions divided by all expected-value samples.
  Every denomination has outgoing confusion counts; the full confusion matrix
  includes unknown and abstention. 100→1 and 1→100 are explicitly separated.
- Costly confusions list each wrong known-value direction and absolute face-value
  error in SAR. That difference highlights risk; it is **not an estimate of
  actual monetary losses**. Wrong decisions include sample IDs for review.
- Condition, side, and variant breakdowns expose hidden failure modes rather
  than relying only on a pooled average.
- Frame rates are descriptive. The 95% two-sided Wilson intervals instead use
  connected physical-note/scene groups: `error_free_spoken_group_rate` is the
  fraction of groups with any spoken decision that had **no wrong spoken
  decisions**; `unknown_group_false_acceptance_rate` is the fraction of groups
  containing a negative that falsely accepted **at least one negative**. These
  are distinct from per-frame precision, not bounds on that precision.
- Multiple frames of one note do not inflate confidence-trial counts. Groups
  must still be independent of each other in the real collection process.
  A zero-error finite sample has a nonzero upper error bound. Intervals are
  unadjusted, not simultaneous cross-stratum guarantees. One group is evidence
  of presence, not reliable recognition.
- This harness never grants release approval. Real held-out images, independently
  labelled ground truth, real exported decisions, predeclared risk criteria and
  real-device spoken-output testing are still needed. If test results influence
  model/policy changes, use a new untouched test set for the next evaluation.

## Unit tests

The unittest suite uses synthetic in-memory fixtures only. It checks arithmetic,
100↔1 mistakes, all four negative categories' false acceptance, partial-note
coverage and identity leakage, all-abstention undefined precision,
independent-group bounds, shared-note components, cross-split leakage, content
duplicates, metadata, missing coverage/output, invalid denominations, and CLI
refusal/provenance behavior. Passing tests validates **the evaluator**, not any
Saudi banknote recognition model or the app.
