# Open3D same-data geometry baseline: verified evidence and exact remaining work

**Status (2026-10-28): historical reconstruction recovered and checked; new saved-array arithmetic completed; no new reconstruction or comparative winner.**

The existing baseline is already a real Koivu processed-RGBD reconstruction using native Open3D, not Apple RoomPlan JSON or synthetic room geometry. This session did not rerun fusion: Open3D and the original RGB/depth/pose files are absent locally. The newly completed computation only re-counted eight already-published numeric output arrays. It must not be described as a new geometry benchmark, new sensor measurement, obstacle-avoidance pass or phone performance measurement.

## Useful findings

1. **265 training frames and 29 disjoint author-held-out frames are correctly frozen.** The restored source uses the dataset author's algorithm and camera convention; 265 depth hashes agree with the complete 294-frame extraction manifest. All 29 excluded IDs match the historical held-out comparison. `DATA_CONTRACT.json` contains the full selection and pins.
2. **Historical independent-reference comparison was not all held out.** Seven of its eight views were integrated into the TSDF; only `frame_00021` was excluded. The separate 29-frame test compared against same-capture processed phone depth, not FARO physical truth.
3. **Small median errors conceal a large reference-disagreement tail.** Historical eight-view FARO-relative paired median is 3.91 cm, MAE 27.11 cm, p95 198.37 cm. New saved-array recount reproduces these numbers and their denominator. That is not evidence that every object or gap is measured accurately.
4. **No metric room dimensions, object spacing, independent drift, real-object miss rate or false-block rate have been established by this baseline.** Mesh AABB spans are not wall-to-wall room dimensions. Supplied camera poses are not a measured localization result. Reference cleaning/completion is not an obstacle label set. Prior body-fit/floor-classification failures do not validate or invalidate reconstruction accuracy by themselves.

## Reused implementation, licenses and source

- Engine: Open3D CPU **0.19.0**, source revision `1e7b17438687a0b0c1e5a7187321ac7044afe275`, MIT. Native `ScalableTSDFVolume` integration/extraction is reused unchanged. [Release source](https://github.com/isl-org/Open3D/tree/1e7b17438687a0b0c1e5a7187321ac7044afe275); [official integration API example](https://www.open3d.org/docs/release/tutorial/pipelines/rgbd_integration.html).
- Dataset-author algorithm: DN-Splatter `generate_iPhone_pointcloud_within_sequence`, revision **`97588b4290128ce7ba6fdbfaac3020b42b17de4c`**, Apache-2.0. This is not the original MuSHRoom neural rendered-depth exporter and not the complete Open3D `reconstruction_system` SLAM pipeline. [Exact source](https://github.com/maturk/dn-splatter/blob/97588b4290128ce7ba6fdbfaac3020b42b17de4c/dn_splatter/data/mushroom_utils/pointcloud_utils.py).
- Historical wrapper: `koivu_author_fusion.py`, SHA-256 **`bec91d5b1d4877d82beef3a621e92d39ed870cf6f273d84e9dea3a742789d9e4`**; actual source is byte-identical to published revision **`9284719`**. Dataset author source SHA-256 **`2c7de7385bce72f439e8e2a3a8c661e7162eda704738895af1392f42d8a1dfae`**. `FETCH_VERIFICATION.json` preserves Git blob and SHA-256 verification for 14 restored evidence files.
- Explicit historical substitutions/extensions: author locked Open3D 0.18/Python 3.10; run used 0.19/Python 3.12. Open3D image readers replaced OpenCV/Torch loader dependencies; dimension mismatch fails rather than resizes; Python/NumPy seeds fixed at 0; native final unfiltered triangle mesh additionally exported. Do not call this byte-identical whole-pipeline execution of the author's environment.
- Dataset: Ren et al., MuSHRoom Koivu, iPhone 12 Pro Max / Polycam processed export, **CC BY 4.0**, with separate author-processed FARO reference. [Phone dataset](https://zenodo.org/records/10230733), [reference dataset](https://zenodo.org/records/10222321). Data license, engine license and adapter ownership are separate; see retained `evidence/DATA_LICENSE_AND_ATTRIBUTION.md`.

## Exact input and coordinate contract

- One room, `iphone/long_capture`: 294 supplied frame entries in original pose order, 265 integrated, 29 original `test.txt` IDs excluded. Extra image files lacking supplied pose entries are not assigned fabricated poses.
- Processed images/depth: width **738**, height **994**; uint16 axial depth divided by **1000** to nominal metres; original per-frame `fl_x`, `fl_y`, `cx`, `cy` passed unchanged.
- Source paper states raw depth was 256×192 and RGB 1024×768 before Nerfstudio cropping/alignment/upscaling to the exported raster. The adapter does **not** upsample again. Exact upstream interpolation history/native confidence cannot be reconstructed from these exports alone. [Paper §3.1.2](https://arxiv.org/html/2311.02778v3).
- Original camera-to-world OpenGL pose is right-multiplied by `diag(1,-1,-1,1)`; its inverse is passed as Open3D world-to-camera extrinsic. Depth is axial z, not Euclidean ray range. No half-pixel change is added to training K.
- Fixed author parameters: **4 cm voxel**, **20 cm SDF truncation**, **4 m input depth cutoff**, RGB8. No smoothing, hole filling, component filtering, floor fitting, FARO fitting or route-dependent selection in this fusion worker.
- Original `transformations.json` SHA-256 **`c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3`**. Its parsed 294 frame records were historically equal to `transformations_colmap.json`; naming is not evidence that Koivu has successful independent COLMAP tracking. Exact per-frame K/matrices still require that missing local pose file.
- Reference `gt_mesh.ply`: **660,550,085 bytes**, SHA-256 **`e18db651c694046de7994237e276d88138ecef9071351281a418de9c9a279b5e`**. Original `icp_iphone.json` SHA-256 **`95b4e26d6d260bd9b06cff801648fc38c030a510cf4055af2294490cf49938d4`**, similarity scale **1.0207908442387768**. Preserve transform direction; apply it once, never refit against held-out depth. Historical saved reference rays already incorporate registration, so do not scale them again.
- Reference cleaning/completion has no measured-versus-edited face mask; registration uncertainty is not a scanner ranging-noise specification. Native confidence, tracking and synchronized causal frame timing are unavailable.

## Historical measured outputs (not rerun here)

| Experiment | Denominator | Reported result |
|---|---|---|
| Author-configured Open3D fusion | 265 training frames | 242,293 vertices; 461,256 triangles; mesh SHA-256 `5a75ebce93a3c65928344ce486223aa17a01a2c196982fc97edff8c41dd56e2e` |
| Held-out processed-phone consistency | 29 views; 1,335,885 scheduled rays; 1,161,037 primary paired (`0 < phone depth < 4 m`) | Median 3.17 cm, MAE 14.50 cm, p95 73.06 cm; 9,496 no-mesh hits over all scheduled rays |
| Registered FARO-relative comparison | 8 views, 7 integrated/1 excluded; 368,520 rays; 334,223 paired | Median 3.91 cm, MAE 27.11 cm, p95 198.37 cm |

Fusion worker completed in **67.422 s wall / 105.25 s process-tree CPU** on the historical Linux host. An ANSI color-clamp warning caused the wrapper's JSON parser to fail after the worker exited 0. Saved output was recovered without rerunning fusion. **Exact peak fusion RSS was not serialized and remains unknown.** The run also extracted/sampled evolving point clouds; this is not a per-frame integration-only or iPhone latency measurement. Original warning/failure must remain in the full evidence packet.

Held-out consistency used **integer pixel centres (offset 0)**. Historical FARO-relative rays used **offset +0.5** to match an earlier frozen evaluator. They are distinct protocols and cannot be pooled into an accuracy ranking.

## New bounded saved-array computation

Root approved restoring only the eight existing public numeric NPZs: **6,477,426 bytes**. No photographs, raw phone archives, fresh sensor acquisition or external upload occurred. Every file matched its Git blob and historical result SHA-256; `allow_pickle=False`, exact seven-field dtype/249×185 shape checks, stride-4 addresses, missing-depth/cell-ID pairing, and reference edge-code checks passed.

Unchanged historical `recount_saved.py` functions revalidated all per-frame and pooled statistics: **3,578 checks**, **1,010 float comparisons**, max discrepancy **4.44e-16**. This wrapper's check total is not the historical full runner's check count and is not a count of independent trials. Recount elapsed **0.613 s**, process peak RSS **53,153,792 bytes**; neither number is reconstruction or phone performance. The executed wrapper used a 2 GiB virtual-address-space hard cap and a 512 MiB observed-RSS check, not a 512 MiB address-space hard cap; this conditional-target variance is recorded in `RESOURCE_NOTE.json`.

New tolerance bins were fixed before this recount but are **post-hoc descriptive bins relative to the old experiment**, not safety thresholds. Early means predicted surface is nearer than registered reference by more than the tolerance; late means farther. They are not proven false obstacles or missed objects.

| Tolerance | Early | Within | Late | Paired denominator |
|---|---:|---:|---:|---:|
| ±2 cm | 97,587 (29.20%) | 96,804 (28.96%) | 139,832 (41.84%) | 334,223 |
| ±5 cm | 60,207 (18.01%) | 199,177 (59.59%) | 74,839 (22.39%) | 334,223 |
| ±10 cm | 33,921 (10.15%) | 275,199 (82.34%) | 25,103 (7.51%) | 334,223 |

All **368,520** scheduled rays remain accounted for: paired **334,223**, reference-only **111**, TSDF-only **33,671**, neither **515**. TSDF-only cannot be declared a false block where the reference is missing. Reference-only is a reference-relative mesh omission, not labeled object recall.

The one excluded view, `frame_00021`, is separately retained: **40,864 paired / 46,065 scheduled**, median **3.62 cm**, MAE **9.01 cm**, p95 **34.15 cm**; ±10 cm bins **8.21% early / 84.94% within / 6.85% late**. It is one correlated view, not one held-out room or independent validation dataset. No view was selected because of its score.

Evidence: `SAVED_ARRAY_RECOUNT.json`, `RECOUNT_PROTOCOL.md`, `ARRAY_ACQUISITION.json`, `recount_diagnostics.py`. In a fresh evidence directory without a pre-existing result, run `PYTHONDONTWRITEBYTECODE=1 OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 python -B recount_diagnostics.py`. It refuses overwriting the preserved result.

## Concrete next execution sequence — pending prerequisites, not started

1. **Acquire only the exact existing public phone archive after root approval:** `koivu_iphone.tar.gz`, **146,575,749 bytes**, SHA-256 **`68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518`**, from [the retained release](https://github.com/mischa23v/blind/releases/tag/navigation-test-data-20261026). Guard archive paths/member sizes. Extract original pose/split, exactly 265 training RGBs (**47,902,609 bytes**) and 294 depth files (**67,180,136 bytes**) using the historical helpers, verifying every `DATA_CONTRACT.json` pin. No complete-dataset download.
2. **Restore isolated CPU Open3D 0.19.0 only after resource approval.** Historical closure was 28 wheels (**121,400,340 bytes download; 368,764,121 declared expanded bytes**) plus 46 installed distributions. Host dependencies changed, so re-resolve/verify the exact current closure first; these historical sizes are not a claim of a ready install. No Docker, CUDA, Torch, model weights, system-wide install or binary build. Current NumPy/Pillow and VTK are available; Open3D is not.
3. **Reuse the existing authored fusion source and guard, not invent a mapper.** Restore the exact published historical source tree, then create a new dedicated launch directory. Map normalized `$WORKSPACE` paths to actual files, verify original data hashes, regenerate a new manifest with current paths and scientific module/source pins, and independently record its new SHA-256. Do not replace placeholders and reuse original manifest hash `89e4f8…`—normalized public receipts have different own-file hashes. Review the known stdout/report-parser defect before execution; any reporting-only repair gets a new source pin. Keep the engine/algorithm/configuration unchanged.
4. **Bounded fusion launch once preflight passes:** `PYTHONDONTWRITEBYTECODE=1 python -B <reviewed-stage>/koivu_author_fusion.py --frozen-sha <new-verified-manifest-SHA256>`. Historical wrapper sets one CPU affinity and thread environments, **600 CPU / 900 wall seconds**, **2 GiB sampled process-tree RSS**, **128 MiB output**, **900 MiB stage added-disk cap**, **768 MiB free reserve**. Verify these guards against the restored environment; fail/retain evidence rather than reducing frames or loosening limits to get a favorable run. Save timing independently of native stdout so another parse failure cannot erase memory evidence.
5. **Same-data fixed-pose RTAB arm:** use the same RGB/depth/K/pose/split contract. The RTAB owner must record actual released implementation/version, native parameter table and output representation. Keep external fixed-pose mapping separate from any corrected/estimated-pose SLAM arm. Hardcoded TUM camera defaults or depth divisor 5 are ineligible for Koivu.
6. **Fresh common independent-reference score:** requires approved reference archive **455,583,916 bytes**, SHA-256 **`e16605f237f0850fd069fb9aca39d300eb1aa3a3b1f5f3f660cb64230a91dd26`**; selectively extract the **660,550,085-byte** mesh plus registration. Reuse the existing VTK first-hit evaluator, not custom ray geometry. Freeze the same **29 excluded views**, **1,335,885 stride-4 rays**, **integer-centre offset 0**, fixed registration, and all no-hit classes for both methods. This is a **new** evaluation convention, not numerically interchangeable with historical +0.5 reference arrays. Run tiny two-sided nearest-hit/axial/inverse-pose fixtures first. Resource budget must be reviewed: the historical eight-frame full-reference evaluator needed about **2.144 GB sampled peak tree RSS**, so a blanket 1 GiB cap is not credible.
7. **Dimensions/spacing/false blocks/missing geometry:** before scores, freeze independent reference landmarks, object/surface identities, measured-or-edited status where available, visibility, room-frame axes, and wall/door/gap pairs. Report metric errors and signed bias per selected landmark/gap, including unmatched geometry; do not substitute AABB spans, fitted ideal floors, post-selected clean walls or a 2 mm support checker. For all-surface comparison, use a pinned established upstream surface-distance evaluator with fixed sampling seeds and report both accuracy and completeness. Threshold early/late ray disagreement remains a diagnostic until reference labels justify physical false-block/miss terminology.
8. **Latency/memory:** record import, decode, integration, extraction, first usable geometry and final usable geometry separately, with all frames/rejections, monotonic timing, same machine, serial scheduling, peak RSS method and failures. Offline total time is not live update latency. Supplied-pose drift cannot be independently estimated from this data without trajectory truth; graph changes versus supplied pose can be reported only as pose disagreement. Actual iPhone latency/thermal/memory and supervised live physical validation remain separate.

## Exact blockers and status

| Action/target | Why blocked | Current status |
|---|---|---|
| Fresh Open3D reconstruction | Missing runtime, RGB/depth and original K/pose file; root has not approved new large acquisition/install | **Not run** |
| New common 29-view FARO score | Missing reference mesh and fresh registered integer-centre queries | **Not run** |
| Metric room dimensions, object spacing, drift | No frozen reference landmark labels/independent trajectory truth | **Unmeasured** |
| Physical false blocks/missed objects | No measured-versus-edited mask or independent visible-object labels | **Unmeasured** |
| New saved-array arithmetic | Exact derived inputs available; bounded read-only calculation authorized | **Completed; accounting only** |

No private uploads, commits, pushes, installs, GPU/Docker jobs, substituted datasets or navigation experiments were performed by this work item. Root owns publication and further resource authorization.
