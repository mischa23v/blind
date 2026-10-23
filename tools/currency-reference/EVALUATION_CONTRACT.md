# Strict no-training held-out evaluation

`evaluate_reference_holdout.py` is a new, separate entry point. The old 32-query comparator remains a **development diagnostic**, not held-out evidence. This runner never trains a classifier, enables an app profile, publishes photos, or treats Python results as equivalent to the Apple Vision → native matcher → Swift/speech pipeline. Keep `SaudiBanknoteReferenceProfile.selected = nil`.

## Four stages, one unseen test

1. `validate`: verify the entire declared inventory and original/derived image SHA-256 values, path containment, labels, roles and provenance graph. No test inference. Unknown identity is reported as unsupported independence, never assigned a pretend independent group.
2. `calibrate`: compare SIFT, ORB and AKAZE **only on calibration frames**. No automatic winner or training. All three roles must be declared and disjoint first. Fix method/thresholds/references using reference and calibration information only.
3. `freeze`: explicitly select one method using that calibration report; attest that held-out images/results were not used for selection. Bind exact inventory/reference manifests, matcher/preparation/evaluator/shared-metrics source hashes, policy, all method parameters and runtime versions. A source or policy change requires a new calibration/freeze. Data hashes are pinned by the manifest and independently checked against actual local bytes. Loaded manifest/source digests are retained, then checked before and after each inference so concurrent edits cannot silently mix policies or reference packs.
4. `test`: verify the freeze and run its **one selected method on every test frame**. Exclusive `frozen.json.test-started.json` and dataset-ID-keyed `.currency-holdout-*.test-started.json` receipts prevent silent reuse in the inventory directory, including copied freeze files, new policy freezes and interrupted runs. Never delete the receipt to claim a fresh test. Changed methods or thresholds need genuinely new held-out data, not merely a new artifact filename.

Example, run from this directory with the pinned dependencies already available:

```sh
python3 evaluate_reference_holdout.py validate --inventory private/inventory.json --references private/references.json --output private/validation.json
python3 evaluate_reference_holdout.py calibrate --inventory private/inventory.json --references private/references.json --output private/calibration.json
python3 evaluate_reference_holdout.py freeze --inventory private/inventory.json --references private/references.json --calibration-report private/calibration.json --algorithm sift --selection-rationale 'Selected using calibration evidence only; explain the tradeoff here.' --attest-test-unseen --output private/frozen.json
python3 evaluate_reference_holdout.py test --inventory private/inventory.json --references private/references.json --freeze private/frozen.json --output private/heldout.json
```

The method in this example is not a recommendation. Synthetic fixtures require `--allow-synthetic` at every stage and are labeled harness-only. Existing output is never overwritten. Exit 2 means refused input/workflow; exit 3 means a completed run recorded execution errors. `calibrate` errors prohibit freezing.

## Inventory schema, version 1

Top-level fields are exactly `schema_version: 1`, `dataset_id`, `data_kind` (`real` or `synthetic`), `sources`, `samples`. All IDs are stable trimmed text. Never put guessed note/session IDs into the manifest. Placeholder identities such as `unknown` or `n/a` are rejected.

Each `sources` record has exactly:

- `id`, `path`, `sha256`, `parent_ids`.
- `path` is contained relative to the inventory directory. SHA-256 is lowercase hex and checked against actual bytes. `parent_ids` lists **all** constituent source images, including both originals of a pasted composite or the original of a mirror/crop/transform; originals have `[]`. Include parents as source records with their actual bytes. The provenance graph must be acyclic and has no unused entries. Identical source bytes and any common ancestor connect sample families.

Each `samples` record has exactly:

- `id`, `path`, `sha256`, `role`: role is `reference`, `calibration` or `test`; all three roles are required. Sample hashes must be unique, even within one role.
- `expected`: an integer in `[1,5,10,20,50,100,200,500]`, or the string `unknown`. Booleans and numeric strings are invalid.
- `condition`: positive `clean`, `folded`, `occluded`; negative `foreign`, `non_money`, `multiple_notes`, `partial_note`, `composite`, `reproduction`, `screen`. Every negative requires `expected: unknown`; any accepted denomination is a false acceptance, including a recognizable note inside a composite. No summing.
- `side`, `variant`, `issue`: positives use `front`/`back`, `paper`/`polymer` and an identified issue; this profile permits polymer only for 5 SAR. Negatives use `n/a` for all three. A note's denomination/material/issue cannot conflict across its positive samples.
- `physical_note_ids`, `capture_session_ids`: lists containing **all** physical notes and sessions represented. This includes every constituent of composites and multiple-note scenes. A single note front/back composite needs only that one true note identity, not an invented second note. Multiple notes need at least two actual identities. Foreign/partial/composite need at least one. Non-money has no physical banknotes. For reproductions/screens record any identifiable depicted notes and all source families; mark incomplete identity as unknown.
- `identity_status`: `complete` means annotations account for every identity, not that software proved them true. Use `unknown` otherwise. Missing required note IDs or capture sessions also means unsupported independence. `validate` reports it; calibration/freeze/test refuse independent evaluation until resolved. Do not use image filenames as surrogate physical-note IDs.
- `source_id`: the source record for this image's original entire frame, or the source of a prepared reference. `image_scope` is `reviewed_note_boundary` for references and **`entire_frame` for queries**. Query bytes must equal their declared source bytes. No per-query ROI, handpicked crop or mask is accepted. Reference rectification is separate and must keep its original source family and identity. Declared original provenance still requires review; a hash alone cannot reveal an upstream crop.
- `source`, `rights`: explicit provenance and rights assertions. The loader records, not independently certifies, them.
- `verification`: exactly the existing reference verification fields `verified: true`, `verification_kind`, `verified_by`, `verified_on`, `method`. Kinds are `human_review`, `assistant_visual_review` or `synthetic_fixture`; synthetic/real kinds must agree. Do not call assistant inspection human review.

The existing reference manifest schema is unchanged. Reference-role sample IDs must exactly match it, including actual path/hash, denomination, side, issue, material, physical note and session. Independent components join every physical-note ID, session ID and source-family hash transitively. A component cannot cross roles. Shared-session different denominations are joined, not mistaken for label conflicts.

## Bounds and evidence

Serial execution processes the **complete declared inventory**, not a favorable 32-frame subset: at most 4,096 samples, 8,192 source records, 256 ancestors per source, 16 MiB JSON and 2 GiB unique declared image bytes. Existing per-image/matcher/reference limits remain in force. Exceeding a limit refuses rather than truncates. Prespecify smaller cohorts by complete components before looking at test outcomes if necessary. No automatic download, install, weight acquisition or heavy training is performed.

Every frame has a completed result or explicit execution error. Errors are **not abstentions**; if any occur, aggregate accuracy metrics are withheld while the complete case/error list is retained. An interrupted run retains its started receipt, not a fabricated completed report. There is no subprocess timeout. Per-frame output retains decision details and a digest of the full matcher result; bulky per-reference candidate arrays and repeated fixed parameters are not copied into the report.

The existing `tools/currency-evaluation/evaluate.py` supplies rates, Wilson intervals and group-based metrics. Here its historical `spoken` field names mean experimental Python acceptance, **not actual speech**. Reports include abstention, per-denomination wrong amounts/precision/coverage, 100↔1 errors, absolute wrong-value costs, foreign/non-money/multiple/composite/reproduction/screen false acceptances, fold/occlusion/side/material/issue slices and explicit missing coverage cells. Coverage is reported even when incomplete; presence of one independent group is not an acceptance threshold. All reports keep `release_approval: false`, `validated: false`, `monetary_answer: null`.

The dataset ledger is local to the inventory directory, not tamper-proof or global: copying an entire inventory to a new directory, altering dataset identity or deleting receipts can bypass it and is not a new independent test. A local artifact cannot prove truthful identity annotations, actual human review, rights, absence of earlier test exposure, or tamper-proof experiment chronology. Human audit and independent native/Apple/device acceptance are still required. Fresh synthetic unit tests only verify this plumbing. No historical reconstructed-photo result or synthetic fixture is a new banknote-accuracy result.
