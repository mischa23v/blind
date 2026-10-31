# Blind Assist geometry and navigation audit

**Evidence cutoff 29 October 2026 03:45 UTC | Prepared for the project owner**

## 1 Executive verdict

**There is real progress, but the navigation system is not complete, release-ready or demonstrated to be 90 percent accurate.** Several earlier failures were caused by our adapters, validation rules and test infrastructure. Others reflect incomplete observations or limitations of the tested reconstruction configuration. Those categories must not be conflated.

The latest verified repository checkpoint is `d93085743e02f5e0efa7445c4388bd39fa9bee23`, on the recovery branch. The default branch was last verified at `8471d58`; draft PR 2 is mechanically mergeable, not accepted as functionally correct. This report is an aggregate evidence review, not a merge or publication action.

**Completed improvements:** native Apple floor import now works on the original public fixtures; strict endpoint tests reject three misleading projected starts; an exact-distance diagnostic removes the Apple margin contacts at the same Hallway corner under two body profiles without shrinking the body or changing the collision oracle. Real Koivu reconstruction runs now include fixed-pose Open3D, RTAB fixed/graph, corrected RTAB plus OctoMap, native Voxblox and the full Open3D registration/refinement workflow. Coffee provides a second-scene regression rather than another synthetic room.

**Important failures remain:** the current full app retains twelve hosted failures and an Ask Dynamic Type failure. Coffee produces only one complete source corridor in both directions out of twenty fixed queries. Full footprint support, live localization, body heading/calibration, current obstacle coverage and the assembled sensor-to-guidance loop remain unverified. A six- or eight-corridor diagnostic is not safe navigation around a room.

The previous corrected RTAB/OctoMap result remains a useful occupancy candidate, not a universal winning mapper. Voxblox improves some pooled errors but worsens near-range tails and tight agreement. The new full Open3D workflow completed its native stages but its actual A/B scores are substantially worse than the supplied-pose baseline: median paired errors about 1.3 meters, with many missing reference hits. Native success flags did not establish a correct trajectory. This is an important failed configuration, not progress to conceal.

**Practical decision:** continue bounded comparative engineering, with geometry and meaningful route progress measured together. Select proven components for specific jobs rather than declare one package the entire solution. Keep physical guidance disabled until the connected system has the missing evidence. Refusing every route is not success; nor is a path through unobserved or colliding geometry.

This audit distinguishes **executed**, **source-reviewed**, **blocked**, **repaired in limited fixtures**, and **not yet demonstrated**. It supersedes old current-status sentences, while preserving historical reports and failures. It does not claim every possible defect has been found.

---

## 2 Repository and component coverage

The recovered shortlist has not all been executed. The table separates different jobs; a scene importer, TSDF mapper and path planner are not interchangeable competitors. [E1, E2]

| Component | Actually executed | Remaining limitation |
| --- | --- | --- |
| Open3D 0.19, MIT | Koivu fixed-pose TSDF; 5 m variant; Coffee TSDF; full Koivu registration/refinement A and original-input refusion B | No demonstrated live localization; results depend on configuration and input adaptation |
| RTAB-Map 0.24.2, BSD core | Koivu 265-frame fixed and graph mapping; native cloud export | Graph arm worse here; build includes TORO CC BY-NC-SA, not cleared for app redistribution |
| RTAB plus OctoMap 1.9.7, BSD core | Corrected world-axis replay, native grids and ray clearing; 98 independent checks | Native ground labels are not supporting floor; real low-hazard recall unverified |
| Voxblox `c8066b04`, BSD-3-Clause | Forty upstream cases; 265-frame integration; original 29-view score | No ESDF/navigation or live-device result follows from TSDF execution |
| OpenUSD 26.5, TOST 1.0 | Exact two Apple diagnostic USDZ files, source/transform comparison | Reader agreement is not physical survey accuracy |
| Apple RoomPlan, Model I/O, SceneKit, ARKit | Native saved-fixture import, floor, collision, endpoint and diagnostic cases | Proprietary SDK; not a live-phone mapping evaluation |
| Recast/Detour pinned 1.6-era revision, Zlib | Recorded meshes, Coffee reference/source paths, strict and EDT diagnostics | Requires valid support, endpoints and independent continuous clearance |
| Earcut v3.2.4, ISC | Native source-polygon triangulation repair and regressions | Triangulates supplied geometry; does not discover actual floor |
| SciPy EDT, BSD | Recorded-grid exact-distance diagnostic and native mask experiment | Distance to grid seeds is not guaranteed distance to physical surfaces |
| DetourCrowd; OMPL 2.0.2 | Source review only | No completed steering or clearance-objective comparison |
| InfiniTAM v3 `4156547e` | Native per-frame calibration and capped CPU-mesher plan prepared; not built | Technical plan exists; noncommercial-purpose license gate blocks execution |
| nvblox v0.0.10 `7f4d5de4`, Apache-2.0 | Exact source/license recovered; no run | CUDA/toolchain unavailable here |
| ElasticFusion `e3b1a7e7`, Imperial noncommercial | Exact source/license reviewed; no run | NVIDIA/CUDA/OpenGL/Xorg and license-purpose gate |
| BundleFusion `d1c04077`, CC BY-NC-SA 4.0 | Exact source/license reviewed; no run | Official Windows/DirectX/CUDA recipe unavailable |
| Kimera-VIO | Input review, no run | Missing synchronized original IMU/timing; supplied poses are not VIO |
| Kimera-Semantics | Candidate review only | Distinct from the now-executed Voxblox component; semantic input contract absent |
| Blender; Unity USD; Assimp/tinyusdz; Godot | Source/capability checks only | Installed Blender lacks USD; installed Assimp lacks USD support; other runtime comparisons unexecuted |
| Active mapping, Nav2, elevation mapping | Primary-source robotics research | Proposed transferable techniques, not implemented or benchmarked here |

The older coverage matrix is superseded for Voxblox/full Open3D execution and later recovered source/license identities. Exact revisions and license texts are in the retained baseline source receipt. Compatibility blocks are not failed accuracy scores. Upstream test counts are not system acceptance.

---

## 3 Data and fair comparison contracts

**Koivu:** 265 original posed training frames and 29 excluded views. Fixed-pose comparators use original per-frame camera calibration and processed RGB/depth. The original processed depth images contain upsampled sensor information, not that many independent LiDAR measurements. Original confidence/tracking/gravity streams are unavailable. The author-supplied FARO registration is evaluator-only and includes scale 1.020790844; it was not fitted to improve our outputs. Reference processing, capture differences and registration uncertainty remain confounds. [E3–E6]

**Apple:** original public Hallway2 and Bedroom3 saved RoomPlan fixtures. Their exact retained diagnostic exports can test readers and adapters, not sensor accuracy against a surveyed room. **Coffee:** 350 posed training frames, 38 official test frames and three unposed frames excluded. It is now a second-scene regression, not an untouched holdout after repeated inspection. [E7–E9]

### Same-protocol Koivu depth results

The fixed Open3D and Voxblox scores use the same 29 excluded views, 1,335,885 integer-pixel stride-four rays and immutable FARO answers. No missing ray is silently discarded as free space. Units below are centimeters. [E3, E6]

| Paired axial-depth metric | Fixed Open3D | Voxblox |
| --- | ---: | ---: |
| All-range median | 3.404 | 3.179 |
| All-range mean absolute error | 18.650 | 16.949 |
| All-range 95th percentile | 113.830 | 103.294 |
| Below-4 m mean absolute error | 15.722 | 16.588 |
| Below-4 m 95th percentile | 90.941 | 102.290 |
| Paired values within 2 cm | 36.886% | 35.392% |
| Paired values within 10 cm | 79.857% | 82.322% |
| Both reference and mapper hit | 1,187,988 | 1,189,925 |
| Reference only | 6,556 | 4,619 |
| Mapper only | 138,401 | 138,669 |
| Neither | 2,940 | 2,672 |

**Mixed outcome:** Voxblox improves pooled mean/tail and hit coverage, but below-4 m mean/tail and tight agreement worsen. Paired subsets differ. These percentages are not route success, obstacle recall or safety. The independent reviewer verified 87 saved arrays and recomputed all per-view/pooled summaries, not a second complete geometry-query execution.

### Separate common-point comparison

This earlier metric uses 4 cm actual-point sampling and 127,774 reference points. It cannot be ranked directly against first-hit depth errors above. [E4]

| Arm | Forward median | Forward P95 | Reference points within 5 cm |
| --- | ---: | ---: | ---: |
| Open3D fixed TSDF | 4.26 cm | 49.71 cm | 81.53% |
| RTAB fixed cloud | 6.64 cm | 48.28 cm | 94.92% |
| RTAB graph cloud | 10.36 cm | 49.38 cm | 78.07% |
| Corrected RTAB/OctoMap | 4.19 cm | 43.25 cm | 90.84% |

Different representation/density and missing reference visibility matter. Nearest-surface proximity can hide wrong occlusions. The corrected arm combines world-axis correction, regenerated segmentation and occupancy clearing; it does not isolate one cause of improvement.

---

## 4 New full reconstruction results

### Native Voxblox

The full run integrated all 265 original training frames, excluded the same 29 test views, admitted 164,771,607 depth observations and produced 434,956 triangles. Forty upstream cases actually passed. The independent output review checked 570 pins/hashes and all 530 decoded image/depth files; output freeze begins `bc1c2258`. It is a native integration result, not a custom mapper relabeled Voxblox. The mixed accuracy outcome is on the preceding page. [E6]

### Full Open3D A

All four released reconstruction stages ran: fragments, inter-fragment registration, refinement and integration. This is now more than the earlier fixed-pose TSDF or one-fragment pilot. Actual results: [E5]

- All 262 within-fragment consecutive RGB-D attempts returned success; two boundary edges are absent under the unchanged 100-frame fragment design.
- Of 458 optional pair attempts, 29 were accepted; only one optional local edge remained after optimization.
- Three global pairs were attempted; two accepted and refined, one rejected. The resulting three-node/two-edge graph is connected.
- Unfiltered A mesh: 128,461 vertices and 151,005 triangles; 532.264 seconds overall, one CPU, about 501 MB sampled peak RSS.

A uses common-intrinsic resampling, native 4 cm truncation, 4 cm voxels and 4 m range. Those are not the fixed baseline’s original-intrinsic/20 cm-truncation configuration. No supplied-pose fallback, failed-frame deletion or FARO fit was introduced.

### Controlled refusion B

B completed separately: all 265 original images/per-frame intrinsics were fused using A’s estimated trajectory, 4 cm voxels, 20 cm truncation and 4 m range. Its 164,771,607 admitted and 29,624,973 clipped nonzero pixels exactly match the original fixed-pose baseline. B produced 350,645 vertices and 639,880 triangles in 14.176 seconds including checks, about 515 MB sampled RSS. [E5]

Only B isolates the pose change. Independent review checked all 265 mapping rows and source-first-camera gauge application: A is transformed once; B integrates gauged poses, without a second transform or reference fit. Output bounds are not measured room dimensions.

**Actual accuracy result: both A and B fail this comparison badly.** The same 29-view, 1,335,885-ray evaluator completed and an independent reviewer reproduced all saved per-view/pooled statistics and 87 array hashes per arm. [E15]

| Same protocol | Fixed baseline | Full A | Refusion B |
| --- | ---: | ---: | ---: |
| Paired rays | 1,187,988 | 236,213 | 477,400 |
| Reference only | 6,556 | 958,331 | 717,144 |
| Mapper only | 138,401 | 10,990 | 30,991 |
| Neither | 2,940 | 130,351 | 110,350 |
| Median absolute error | 3.404 cm | 132.464 cm | 129.884 cm |
| Mean absolute error | 18.650 cm | 138.085 cm | 142.471 cm |
| P95 absolute error | 113.830 cm | 328.337 cm | 396.243 cm |

B's added coverage does not improve every error statistic. Preserve missing-hit counts; do not fit the output to FARO. A saved-graph diagnostic finds disagreement in the first local edge: native displacement 0.135 m versus supplied 0.332 m, translation disagreement 0.211 m. It begins before global registration. Supplied poses are not independent ground truth; this identifies timing, not a proven root cause. [E17]

### Retained adapter failures

The first pilot had a metadata-row defect, then identity-intrinsic resampling incorrectly introduced border zeros. Both failures remain preserved. The repaired first-frame identity case now has zero added/outside pixels, with ingress fixtures and independent source review. These were our adapter defects, not evidence that native Open3D could not reconstruct. Rejected optional registrations and graph pruning, by contrast, are actual algorithm outcomes under the recorded configuration.

---

## 5 Confirmed defects and bounded repairs

| Defect or evidence failure | What changed and what remains |
| --- | --- |
| Metadata decoder chosen from `.json` extension despite binary plist bytes | Actual signature-based PropertyListDecoder/JSON handling native-verified; identity admission preserved |
| Apple planar source dimensions used as strict bounds for exported solids | Same-file reader proved wall/door thickness and approximately 16 cm expanded floor outlines; semantic support separated from visual slabs |
| All floor-UUID faces treated as support | Slab sides, underside and generated rim excluded from historical support; native source polygon tests now pass |
| SceneKit zero-extrusion buffer approach failed natively | Bounded released Earcut bridge uses original polygon vertices; malformed/concave/boundary regressions and duplicate normalization pass |
| Exact duplicate exported wall faces polluted routing representation | Only witnessed exact duplicates normalized for routing; raw export retained, source identity/order/bounds checked; not arbitrary obstacle deletion |
| Offline RTAB camera/world axis conflation | Processed world +Z contract separated from OpenGL camera +Y; regenerate grids using correct node/optical transforms. App ARKit world convention is a separate contract |
| RTAB export omitted valid indices for non-dense clouds | Export-only repair from retained actual mapper databases; no hidden remapping/retuning |
| VTK reader crashed on zero-face PCL cloud format | Official Open3D cloud decoding substituted; counts/asymmetric coordinates checked, metric unchanged |
| Mixed wall/floor collision query missed modeled wall | Separated-category synthetic native witness fixes that case; not universal collision proof |
| Nearest-poly projection counted starts outside actual polygon as complete | Opt-in strict admission rejects three specific misleading starts and preserves eight complete legacy corridors |
| Recast erosion retained local points inside required margin | Trace attributes deficit before simplification; exact-grid-distance native diagnostic clears the same Hallway corner under two profiles and unchanged oracle |
| Pipeline source pins, hosted linking and evidence collection ordering failed | Repaired with exact-source native executions and real-shell evidence checks; failures retained rather than relabeled algorithm errors |
| Model-unavailable compatibility expectation diverged from revised typed outcome | Original legacy test repaired and passes at `d3aeb55`; full app still has twelve hosted failures |

Several earlier observations remain **gaps, not repaired bugs**: visible actor versus actual padded body; full-footprint support versus one floor contact; camera pose versus body heading; current map alignment; source surface completeness; actual phone latency. Original wall-crossing plots need registered geometry, actual path and swept-body evidence, not dismissal as a drawing issue. [E7–E11]

No evidence establishes that visible shadows themselves caused every blocker. Some source artifacts correlate with missing or occluded views, some with pose/floor ripple, and some with our code. Appearance can support diagnosis; a model saying “looks empty” cannot authorize deleting obstacles or filling unseen ground.

A 5 m Open3D variant improved one severe local error region from about 3.57 m median discrepancy to 4.47 cm, while worsening global mean and tail. It was not adopted. Earlier optimizer/floor-rule failures likewise remain failures, not silently replaced successes. [E3]

---

## 6 Native routes and application acceptance

### What the exact-distance experiment established

Native run `40803064242` executed a fixed 75-case diagnostic: 50 unchanged controls and 25 candidate requests. All controls reproduced exactly. The candidate retained six previously complete no-contact corridors, made the same Hallway corner under two body profiles complete with no recorded contacts, preserved three strict projected-start refusals, and retained fourteen other failures. Initial-contact receipts and all 75 native layout receipts were preserved. [E10]

The original corner margin-contact segments changed from six to zero and four to zero. Body, margin, source geometry and collision oracle were unchanged; no radius or tolerance retuning. This is a meaningful bounded improvement, not merely rejection of everything.

**Limits:** scratch-only mask application; six complete compact layouts; no production integration or iOS portability execution; full-footprint support false; no continuous source-clearance guarantee. The shortest funnel remains, not a maximum-clearance objective. Grid-seed EDT is not exact physical-wall distance. No corrected live movement result follows from this native macOS experiment.

### Latest main-app acceptance

The last completed main-app run is `40806114667` at `d3aeb55`, not the later paper-package source. Hosted: **255 total, 237 passed, 12 failed, 6 skipped**. Four runtime-failure-policy cases and three strict-endpoint cases pass; the repaired legacy-unavailable case passes. UI: **18 total, 14 passed, one failed, three skipped**. Ask full accessibility audit still fails; practice explicit End passes with a 26.241-second measured upper bound. Separate macOS classification has 18 passes, with five iOS-only cases excluded. [E11]

Timing failures cannot be “fixed” by a later passing run alone. Evidence distinguishes first native-build wall stall and serial queue effects; exact CPU/identity attribution is limited by missing per-element/runtime snapshots in the retained artifact. Do not guess the failing UI element or relax timeouts to obtain green results.

### What is not wired or demonstrated

Strict/EDT research candidates do not constitute normal `NavigationModel` routing. Existing sensing, preview, recording and partial planning components are real, but the audited complete chain remains unfinished: owned live mesh updates/removals; map/room selection; independent map-relative pose; body heading and phone mount calibration; fresh support and full-body/head obstacle coverage; valid connectors; deviation and loss/restart recovery; goal progress and accessible code-owned cues.

A supplied standing pose is not successful localization after rising from a chair or bed. A diagnostic waypoint sink is not timely spoken guidance. The 400 end-to-end journeys, multi-room exit/return, sustained runtime and supervised physical acceptance remain open. No current result authorizes children or independent users to rely on the app for mobility.

---

## 7 Coffee and observation limitations

Coffee is important because a cleaner numerical mapper cannot recover geometry that was never observed reliably. Its released Open3D source mesh came from all 350 original posed training frames, no FARO mapping input, and contains 136,847 vertices and 268,806 triangles. [E8, E9]

A fixed reference-qualified registry selected twenty directed queries before source pathing. Reference geometry completed all twenty. Source geometry completed two, returned sixteen partial paths and failed association twice. The two completions are one approximately 2.372 m corridor in opposite directions. The declared synthetic body radius is 0.24 m and height 1.2 m, not a calibrated person. Source and reference slope settings differ by declared protocol; this is not an untouched identical-map competition.

The lossless reference evaluator cast **244,306 rays at 2,162 path samples**. Reference corridors had zero sampled raised-body contacts and missing-floor rays. Source complete/partial paths had zero sampled raised-body contacts but **two missing floor rays**, both on partial queries. The complete pair had zero missing samples; its predicted feet were 1.74–2.80 cm above reference floor. Feet were not shifted to make the result pass. Independent review reclassified all rays and verified all 56 packet hashes. Discrete sampled clearance is not continuous full-body/support clearance.

### What the failed connection investigation says

W0, W2 and W7 raised-gap witnesses are predominantly occluded by nearer foreground. They do not have enough independent compatible views to establish the hidden low geometry as either real obstruction or removable noise. W6 has some compatible floor observations, steep reconstructed normals and an initial-null classification, supporting a local floor-ripple/slope-rejection hypothesis. It does not establish one global flat-plane correction. [E9]

The reviewer verified the source column/ray metadata and reprojected observations from all 350 original depth files. Neither reconstructed fusion weights nor physical clearance were recovered by that check. A floor-only smoothing operation may help ripple but cannot legitimately solve an unseen region behind furniture.

### Useful next response

Keep unknown, observed-free, occupied and supporting-ground evidence separate. Identify the exact failed corridor and ask what additional view would resolve it. Use already supported positions for view changes; do not guide a person into unknown ground to obtain a better scan. Test geometry error, false blockage and recovered useful connectivity together. “No path” in a spacious room is a product failure, but removing uncertainty labels without evidence is not a repair.

This is why multi-pass robot-style scanning is relevant without being sufficient. A different viewpoint can resolve occlusion; repeated copies from the same angle may only reinforce a correlated error. Phone pose, motion, coverage and depth validity must be measured alongside the mesh.

---

## 8 Stair research and robot lessons

### The actual 92.5 percent paper

Herdt et al., *A single-user feasibility study demonstrating real-time raycast-based stair and elevation-change detection on consumer smartphone LiDAR hardware*, Scientific Reports (2026), DOI **10.1038/s41598-026-73419-5**, used an **iPhone 17 Pro Max with iOS 26.2**, not an iPhone 12. One trained sighted investigator performed 120 approach trials. Success meant warning before feet reached the hazard boundary: **111 successes, nine misses**. This is stair/elevation-warning performance in that protocol, not pathing or map accuracy. [E12]

The public trial workbook was independently audited: 120 unique rows and 111/120 reproduced; raw rows resolve a subgroup count disagreement in the article’s prose. Successful alert distances averaged about 2.31 feet. There were no separate hazard-free routes, and the workbook does not independently reconstruct the paper’s reported zero false positives. It contains outcomes, not RGB/depth/pose/mesh recordings or verified author code.

Our separate paper-derived Swift reference exposes published predicates and explicitly labels experimental interpretations of underspecified details. **Seventeen named synthetic macOS XCTest cases actually passed** in run `40809875873` at `d930857`. That tests arithmetic/state choices, including retained steep-ramp counterexamples; it does not reproduce 92.5%, infer missing paper parameters, create an ARKit ray generator or integrate the app. The author code and raw sensor replay remain unavailable. [E12, E13]

### Ranked techniques worth transferring

1. **OctoMap observed/free/unknown semantics:** calibrated endpoints and sensor origins; preserve freshness and separate ground support. Missing depth is not a clearing ray.
2. **DynamicEDT3D and cost-aware planning:** hard geometric admissibility first, preference for wider routes second; independent body sweeps and uncertainty margins remain necessary. Bound dense distance-field storage locally.
3. **Nav2 Collision Monitor concept:** independent fresh sensor hazard processing bypassing ordinary route/planning latency. Transfer validity and stop/withhold semantics, not a robot’s braking constants.
4. **Uncertainty-aware elevation mapping:** estimate local height and uncertainty without inpainting unseen ground or losing overhead objects in a 2.5-D projection. ANYbotics reference is no longer actively maintained.
5. **RTAB localization and verified return:** re-establish map pose and revalidate each segment; saved routes are topology, not current clearance. Startup/default pose is not localization.
6. **Active viewpoint selection:** reduce uncertainty in the goal corridor from already supported space. Drone/vacuum motion policies are not human walking instructions. [E14]

Source review found active-mapping gain switch fall-through, an empty elevation-map test, and Nav2 monitor scheduling driven by velocity callbacks: a phone needs its own fresh-data watchdog. Library names or test directories do not establish tested semantics. [E14]

Vacuum platforms can have rigid sensor mounts, controlled wheels, dedicated downward cliff sensors and optical flow. A chest phone has different blind spots and human-response uncertainty. Borrow evidence handling and validation methods, not a hardware safety claim. These research candidates have not been implemented or scored in our app.

---

## 9 Proposed architecture and next acceptance gates

**Best tool per job is a candidate architecture, not a measured winning system.**

- **Acquisition and calibration:** native ARKit RGB/depth/mesh/pose, timestamped and copied into owned bounded buffers. Maintain camera versus world versus body frames explicitly.
- **Historical structure:** RoomPlan semantic rooms/floors/objects for identity and topology, with raw geometry and uncertainty retained; no generated slab rim treated as current floor.
- **Incremental evidence:** evaluated native occupancy/fusion component, with unknown, free, occupied, support and freshness separate. Keep fixed Open3D and Voxblox as independent baselines; do not select by one pooled statistic.
- **Localization:** independently validated map-relative pose/body heading and uncertainty. RTAB is a candidate, but the failed graph arm shows why library adoption alone is insufficient.
- **Routing:** retained Recast/Detour with experimentally validated clearance mask and explicit endpoint policy; wider-path preference only after hard collision/support eligibility. Validate the complete connector and moving body, not just centerline points.
- **Hazards and speech:** local independent current-data evaluator; code owns distances and movement instructions. LLMs may explain and converse, never fabricate clearance or override the map/sensor gates.

### Accuracy research worth testing next

Freeze isolated confidence/range-angle weighting and Voxfield normal-aware integration comparisons before another mapper swap. Voxfield requires measured, correctly aligned normals; disabled normals mean no normal correction, and grazing returns may be skipped. Verify camera-depth versus ray-range conventions. Other source-only candidates are joint calibration/pose refinement, uncertain support layers, targeted new views and transient-object separation with decay to unknown. BAD SLAM requires CUDA and synchronized/global-shutter assumptions; Dynablox data uses different LiDAR hardware. None has demonstrated an improvement here. Keep the same conservative clearance and critical-miss gates. [E16]

### Measured gates before expanding claims

**G1 Geometry:** same inputs, units, coordinate conventions and preserved missing data. Compare errors by range/height and missing-hit categories. Verify simplification against original geometry; no cosmetic hole filling.

**G2 Observability and support:** frozen real floor/toy/threshold/drop/overhang examples; hazard retention and false-free volume, supporting footprint coverage and false blockage. Abstention is separate from success.

**G3 Useful paths:** unchanged body and margins; registered source/model/path views; requested endpoints and connectors; continuous sweep; complete versus partial versus rejected accounting. Require nonzero useful completion and zero accepted known intrusions under the independent oracle.

**G4 Live integration:** room/floor/map selection, position/heading, mount calibration, incremental map changes, moved furniture, occlusion, restart and tracking loss. Measure wrong localization and false arrival, not only retrieval confidence.

**G5 Runtime and user experience:** sensor-to-cue latency distribution under load, stale callback retirement, interruption, VoiceOver, Arabic/English and largest text. No improvement claim from source tests alone.

**G6 Controlled physical evaluation:** bench and controlled adult device trials before a separately reviewed child protocol. Do not use real hazards as the first discovery of a failure. No independence claim without task-specific evidence.

Licensing remains an adoption gate: RTAB research transitive TORO terms; InfiniTAM noncommercial scope; CUDA/toolchain blocks and verified noncommercial restrictions; dataset CC BY 4.0 and code obligations separately. A phone-portability objection does not invalidate an offline comparator, but an offline result does not establish a practical phone implementation.

---

## 10 Evidence index and remaining boundaries

**Report source snapshot:** verified recovery head `d93085743e02f5e0efa7445c4388bd39fa9bee23`. Some new runs are local retained evidence, not yet GitHub-published. Source protocols often intentionally preserve pre-run language; later immutable result receipts determine completion. No private imagery, personal data, raw coordinates or credentials are included here.

- **E1 Coverage:** `coordination/repository-coverage-audit/COVERAGE_MATRIX.md`; later `coordination/remaining-mapping-baselines/PLAN.md` and `SOURCE_RECEIPT.json` supersede missing-license/pin statements. New full Open3D/Vox receipts supersede unrun status.
- **E2 Earlier full audit:** `research/geometry-independent-audit-20261028/CURRENT_AUDIT.md`; detailed original nineteen findings and prior source pins. Native “skipped” status is historical, not current.
- **E3 Fixed Open3D:** `research/open3d-same-data-benchmark-20261028/fresh-run/RESULTS.md`, `COMMON_GEOMETRY_RESULTS.json`; range variant and independent reviews in the same research tree.
- **E4 RTAB/OctoMap:** `research/rtabmap-same-data-benchmark-20261028/completed-stage-1823/RESULTS.md`; `fresh-run/octomap-stage/ZUP_RESULTS.md`; `independent-review/octomap-zup-final/REVIEW.md`.
- **E5 Full Open3D:** `research/open3d-calibrated-full-koivu-20261029/RESULTS.md`; `research/open3d-calibrated-refusion-b-v2-20261029/RESULTS.md`; `coordination/independent-open3d-review-20261029/AB_RECOUNT.json`.
- **E6 Voxblox:** `coordination/remaining-mapping-baselines/stage-d-full265/`; `coordination/voxblox-same-protocol-score/COMPARISON.md`; `coordination/batch2-independent-reviews/VOXBLOX_FULL265_REVIEW.json` and `VOXBLOX_SCORE_RESULT_REVIEW.json`.
- **E17 Trajectory diagnostic:** `research/open3d-calibrated-trajectory-diagnostic-20261029/RESULTS.md`; saved poses/graphs only, no independent trajectory ground truth.
- **E7 Apple import:** `research/native-floor-import-repair-20261028/NATIVE_FLOOR_REPAIR_RESULT.json`; original same-export evidence under `research/independent-usd-reference-catalog-20261028-1514/run40726507227/`.
- **E8 Coffee:** `research/coffee-original-pose-tsdf-comparator-20261028/qualified-results-v1/README.md` and reference route evidence in that research tree.
- **E9 Coffee review:** `coordination/batch2-independent-reviews/COFFEE_REVIEW.json`; all-ray recount and later source-column/occlusion checks, not a second planner run.
- **E10 Strict/EDT:** `research/native-floor-import-repair-20261028/native-strict-result-40791907324/`; `native-edt-result-40803064242/SUMMARY.json` and independent review.
- **E11 App acceptance:** `merge-readiness-audit/run40806114667/TERMINAL_RESULT.json`; source `d3aeb55`, not the later isolated paper package.
- **E12 Paper:** `coordination/paper-925-review-20261029/REVIEW.md`, `TRIAL_AUDIT.json`; DOI 10.1038/s41598-026-73419-5; public trial data DOI 10.6084/m9.figshare.32180439.
- **E13 Paper implementation:** `research/paper-stair-baseline-20261029/SPECIFICATION.md`; `merge-readiness-audit/run40809875873/INDEPENDENT_RECORD_RECOUNT.json` verifies seventeen named passes.
- **E14 Robotics:** `coordination/robotics-improvement-review-20261029/README.md` and `IMPLEMENTATION_TRANSFER_AUDIT.md`; primary OctoMap, DynamicEDT3D, Nav2, ANYbotics and active-mapping sources. Research only.
- **E15 New A/B scores:** `coordination/FOUR_MAPPER_SAME_PROTOCOL_COMPARISON.md`; `coordination/open3d-a-same-protocol-score/RESULT.md` and B equivalent; independent `OPEN3D_A_SCORE_RESULT_REVIEW.json` and `OPEN3D_B_SCORE_RESULT_REVIEW.json` under `coordination/batch2-independent-reviews/`.
- **E16 Accuracy research:** `coordination/accuracy-methods-review-20261029/README.md`; six proposed ablations and source limitations, no execution.

Reproduce from each stage’s freezes, versions, logs, failures, output manifests and recount scripts. This report does not authorize publication of the separately pending 114-file payload or chart.

**Still open:** production EDT/strict wiring, continuous support, real low hazards, live localization, app failures, 400 journeys and physical acceptance. A/B scores are complete and negative. No percentage promise or release approval.
