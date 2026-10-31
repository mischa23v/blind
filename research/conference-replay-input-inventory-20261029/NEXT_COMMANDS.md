# Next commands — preparation outline, not executed replay commands

**Stop before any download/native execution until root finishes active Coffee checks and admits the next bounded stage.** No runnable Koivu comparison worker exists yet. Do not rename a Coffee output directory or loosen its assertions to make it run.

## 1. Read-only existing evidence (now safe)

```sh
cd /workspace/scratch/90f3f6703064/blind
export GIT_NO_LAZY_FETCH=1
cat research/conference-replay-input-inventory-20261029/INPUT_INVENTORY.json
cat research/conference-replay-input-inventory-20261029/TARGETS.json
cat research/conference-replay-input-inventory-20261029/NATIVE_REUSE.json
```

All compact archives are present as local Git objects at the revision in `SOURCE_RECEIPTS.json`. Use `git show REV:path` with lazy fetch disabled, then verify the recorded SHA before selecting exact regular members into a **fresh** owned directory. Preserve names and all failed evidence; never extract-all or overwrite.

## 2. Root-owned original-input recovery

First locate retained original `koivu_iphone.tar.gz` on the authorized original executor/Library/release, if available. Only if root admits bounded reacquisition, use the exact official archive URL in `INPUT_INVENTORY.json`; retain one download receipt and verify exact length plus SHA before decompression. This packet performs no such transfer.

After the archive exists in the fresh source workspace:

```sh
printf '%s  %s\n' \
  68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518 \
  koivu_iphone.tar.gz | sha256sum -c -
```

Reuse retained `guarded_archive.py` from:
`research/koivu-phone-map-negative-result/workspaces/blind-mushroom-koivu-acquisition-01/`.
Its supported CLI is `python -B guarded_archive.py list` then `python -B guarded_archive.py extract EXACT_MEMBER ...`; it uses same-directory `ACQUISITION_RECEIPT.json`, has 60 CPU /180 wall seconds /384 MiB address-space limits, validates archive identity/safe member names, refuses an existing completed selection and retains 768 MiB free disk. Source/hash review is still required before using this older helper; do not run against an unrelated folder.

The complete needed extraction allowlist is: original long-capture OBJ, original long-capture `transformations.json`, and **all 294 exact `member` values** in `evidence/DEPTH_INPUT_MANIFEST.json` (70,885,433 bytes total). No texture/RGB or FARO is needed for the initial unchanged-source route/body check. It is also reasonable to extract only OBJ+poses first (3,705,297 bytes), with the later depth extraction under a distinct fresh selection/output contract; never overwrite the first receipt or silently substitute frame subsets.

Verify OBJ SHA, 18,398/29,366 cardinalities, original pose SHA and every selected depth member hash. Parse only after verification. Do not change pixel calibration, infer confidence, align by route outcomes or swap corrected/rejected pose exports for the original.

## 3. Minimal scene-input glue, source review before run

Prepare one new scene-specific input-mapping worker around existing current code. Do not execute any of these historical mains wholesale:

- `clearance-first-coffee[-repair]-source-20261029/prepare_coffee.py` is Coffee-only and hash/cardinality/pair bound.
- stage55 `run_source.py` requires old NPZ transports, old objective and old library; use only the already-current `build_graph` function and current SciPy selector.
- `run_pilot.py` imports historical controller/reference dependencies; do not accidentally launch movement while checking paths.

New mapping should consume `TARGETS.json`, original OBJ and exact retained stage37 transform; current Coffee002 `Native(..., exclusion=False)` and `build_graph`; and unchanged root-reviewed current selector. Establish baseline native queries before any new centered/repair result. Pin all inputs, runtime metadata, library, graph/selector and source mappings. Review full-XYZ requested connectors and byte-level transformed mesh receipt. Preserve all seven objectives and historical non-successes.

Use root's existing serial aggregate guard style, at most one CPU,120 aggregate CPU seconds/180 wall seconds/1 GiB observed process-tree RSS/16 MiB output as a **proposed cap**, never automatic entitlement. Abort with retained partial/unknown result if the fixed graph/query budgets fail. No compilation, widening budget or parameter retry is part of this outline.

## 4. Contact/support admission after source proposal

Generate the current Coffee stop/turn/translate schedule for all emitted arms with unchanged subdivisions/body/margin, preserving native Y and requested connectors. Review actual maximum increment/contact-query counts before calling the existing VTK scorer. Apply the same selected Coffee ground policy, with no floor filling or hand exemption; keep support unknown when the inputs do not establish it.

Independent GEOS2D can only reject relative to genuinely supplied geometry; absent source projections/exclusions must yield unknown. It cannot certify a room from screenshots, Coffee windows or navmesh-wall clearance. Any historical manual source hull, evaluator sill/floor support or zero-margin movement replay is a separate arm and not a shortcut to current-policy acceptance.

Only a separately admitted continuous movement run may report committed motion/arrivals. Start a return from the delivered actual actor state. Stop on contact, unresolved support/coverage/association or bounds; preserve failures rather than generating a hand-carved route.
