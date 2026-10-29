# C1_N3 full265 — frozen primary score and secondary common-pair comparison

**Prepared only; not executed.** Requires independent source review, independent fresh retry output review, root SCORE_ADMISSION, and an exclusive CPU slot. No result-based refit/tuning, mesh edit, raw-data export, publication, download, install, or spend.

## One mapper change; preserved failure and baselines

Candidate mesh: `coordination/accuracy-methods-review-20261029/voxfield-feasibility/n3-reconstruction/full265-retry1/run/C1_N3_native_mesh.ply`. It is a fresh empty-map C1 run using all original 265 training frames / 164,771,607 admitted points. Same D1 core, original per-frame K/poses/pixels/colors, input mask, TSDF/configuration and mesh extraction as C1_N2. N3 changes the numerical-normal provider from one exported-pixel spacing to four-pixel support plus intermediate-validity policy for this documented upsampled Koivu export. It is not a pure angle-only ablation, recovered raw sensor calibration, or a rule for native phone imagery/other datasets.

The first full N3 attempt stopped through external environment loss at 159 completed / 160 attempted frames. No final mesh or terminal resource receipt existed; its cap compliance remains unknown. `full265/INTERRUPTED_OUTPUT_ADMISSION.json` must remain false/quarantined. The separately reviewed retry must complete all 265 frames, non-normal input-ledger equality, finite mesh/state checks and its own resource/integrity guard. No partial TSDF resume or reinterpretation of the interrupted attempt as passed.

Preserve B/C0/C1_N2 scores and their full 118-pin output freeze: `coordination/voxfield-recovered-full265-same-protocol-score/OUTPUT_FREEZE.json`, SHA256 `f18050b5af9ea282ac3d3466262ef3a005091608a0e4811b039ba7246576d699`. Verify every pin before and after this run. Prior mixed N2 evidence remains intact: B reproduced historical stock, C1_N2 gained some coverage/tails while losing tight-band/median agreement and worsening far-reference tails. Do not overwrite or claim a blanket winner.

## Unchanged primary endpoint

Use original `research/open3d-same-data-benchmark-20261028/fresh-run/evaluate_common.py` SHA256 `06503818a4a402a2e9ca73e622c8cef8e9eb92f124f0e32c9abd72204175c3ee` and `summarize_common.py` SHA256 `74e553a69f06ad17875c6e01532b302ae473fc93a6bd30df56fc80859ac251e1`. Candidate evaluator changes only source/output/mesh paths and adds the existing tsdf-only assertion. Summary changes only source/prediction/output paths. Unified patches expose exact differences. No scoring math, threshold, axis, ray, pose, scale or registration change.

Exactly the original 29 excluded views, original heldout poses/K, integer pixels with offset 0 / stride 4, 46,065 rays per view, **1,335,885 scheduled rays**. World metres already use Cgl × diag(1,-1,-1,1); the evaluator's generic `tsdf` identity transform is intentional. The inherited `TSDFOnly` means C1_N3-only, not an Open3D algorithm label.

Unchanged serial VTK first-hit two-sided query, vtkStaticCellLocator / 16 cells per node / 2,097,152 maximum buckets / 1e-7 tolerance; ray endpoint spans mesh-bounds corners plus 1 m. Camera-axis depth, not slant range. Unsimplified native mesh: 0.04 m voxel / block side 16 / 0.20 m truncation; mesh minweight 1e-4, color true, one worker, generateMesh(false,false), convertMeshLayerToMesh(...,false). No crop, filtering, semantic floor, proximity merge or repair.

Reuse original immutable FARO hit arrays: no reference locator/requery. Before/after verify original EVALUATOR_FROZEN and all nine source/input pins (including reference bytes, original baseline mesh, registration, pose/K and split); both original cached RESULT files and all 58 FARO/Open3D NPZ hashes; original baseline summary; all 29 heldout processed-sensor PNG pins; all 118 prior N2 output pins; new candidate mesh/output/admission/independent-review/ledger/resource evidence. Fresh outputs are exclusive and never overwrite old results.

Primary summaries retain per-view and pooled availability (paired, reference-only, mapper-only, neither), signed mean/p05/median/p95, absolute mean/median/p90/p95/p99/max and paired count. Bands remain exactly ±0.02/0.05/0.10 m with strict earlier/later and inclusive within. Depth strata remain all rays, positive reference <4 m, reference ≥4 m, and original seven bins: (0,.15), [.15,1), [1,2), [2,3), [3,4), [4,5), [5,∞). Show scheduled and paired denominators. Reference-missing rays have no reference-depth bin. Original processed-sensor consistency remains secondary/nonindependent, not FARO accuracy.

## Separately frozen secondary analysis — no new mesh query

Root requested this analysis **before** candidate scoring. `secondary_common_pairs.py` reads saved reference/B/C1_N2/C1_N3 arrays with exact frame/row/column identity; it does not change primary results or select mapper settings. It compares C1_N3 against C1_N2 and B separately, per view and pooled, for the same all/<4/≥4/seven reference bins.

For every reference-positive ray, classify:
- Common paired: both old and new mapper hit. Compute each mapper's errors on this **identical intersection**, using original ten statistics and all 2/5/10 cm earlier/within/later counts.
- Gained paired: only new mapper hits. Retain count and new-versus-reference errors; do not invent an old error.
- Lost paired: only old mapper hits. Retain count and old-versus-reference errors; do not invent a new error.
- Neither paired: both mapper predictions missing despite a reference hit.

These four categories sum to the reference-positive denominator; old paired = common + lost, new paired = common + gained. For reference-missing rays, separately retain both mapper hit / old-only / new-only / neither, without geometric error or depth-bin assignment. Cross-check every reconstructed primary availability/paired denominator against the unchanged primary reports. No missing-error imputation, intersection-only winner, weighted overall score or deletion of changed-coverage cases. Improved conditional error cannot be interpreted without gained/lost counts and their available-side error tails.

`SECONDARY_COMMON_PAIRS.json` is explicitly supplemental. Report both common-subset methods, gained/lost coverage and near-reference strata alongside all-ray primary availability/tails. Independent saved-array recount must cover the primary original groups and this secondary logic before final claims.

## Guard and admission

One attempt only: **60 CPU seconds, 90 wall seconds, one CPU, 1 GiB sampled summed RSS, 1 GiB new output**, covering input/cache checks, primary query/summary, secondary saved-array analysis and final integrity. Existing reviewed guard includes its own CPU/RSS and starts timing before admission checks; checks final self+reaped-child CPU/wall/disk as well as conservative sampled CPU. Sampled limits do not promise zero transient overshoot; terminal reaped-child usage can undercount killed descendants, so keep conservative peak and stop reason.

Root fills `SCORE_ADMISSION.template.json` only after actual independent gates. It binds candidate output/admission/resource/input-ledger/independent review, original interruption quarantine, preserved N2 output freeze and current scorer source review. It must affirm fresh empty map / same inputs-kernel-config / only the N3 normal-provider change / original interruption unchanged. No score is admitted merely because a mesh exists.

After explicit root admission and exclusive CPU release:
```
python3 coordination/voxfield-n3-full265-same-protocol-score/run_guarded.py C1_N3
```
Stop on any cap, failed check or changed evidence. Preserve diagnostics; no automatic retry, cap increase or score tuning. Final acceptance requires primary 29-view outputs, secondary comparisons, matching before/after receipts, guard success and independent output recount.

## Interpretation limits

These are first-hit geometry discrepancies to author-registered, edited/completed FARO with unbounded registration/completion uncertainty. Missing hits never establish clearance. One-sided hits and signed errors are not physical hazard labels. No live localization, route-success, object-handling, full-body clearance, iPhone-runtime or safe-guidance claim follows. A synthetic normal improvement is not a recorded mapping improvement. Later pathing must remain separately evaluated and admitted.
