# Current geometry mapping and navigation audit

**Evidence cutoff: 28 October 2026, 19:18 UTC. Prepared for the Blind Assist project.** This report consolidates the completed same-file Apple comparison, fresh same-input reconstruction comparisons, corrected RTAB-Map and OctoMap experiment, independent reviews, implementation defects and remaining navigation work. It supersedes the *current-status statements* in the earlier [17:09 report](FULL_REPORT.md), without changing that historical record. It is not an exhaustive claim that every bug has been found.

## Main result

**Several serious problems were in our integration and validation code, not evidence that the rooms were physically impassable.** We now have actual released-engine comparisons on the original recorded inputs, rather than only a list of libraries or source-level checks.

The corrected fixed-pose RTAB-Map plus native OctoMap output is the leading candidate for the **next controlled geometry-to-pathing experiment**. On the shared reference comparison it has a 4.19 cm median output-to-reference distance and 90.84% of sampled reference points within 5 cm of output, compared with 4.26 cm and 81.53% for Open3D. Its 43.25 cm forward 95th-percentile error remains substantial. The denser raw fixed-pose RTAB cloud covers more sampled reference geometry, at 94.92%, so there is no universal winner. These are geometry measurements—not navigation accuracy, hazard recall or a safety rating.

The Apple saved-room correction is implemented and published, but **has not run in the new native test attempt**: the workflow skipped both jobs under its private-repository guard. The last executed native Apple evidence still has 18 route cases and 16 supplied-pose stages blocked before route creation. No new table loop, cross-room journey, live localization or safe physical navigation result follows from the newer offline geometry scores.

**Decision:** continue the project’s controlled engineering evaluation, using the corrected native occupancy result as the next candidate. Do not call the navigation system complete or ready for physical use. First validate retained hazards and full-footprint support, then geometry-aligned paths and swept-body collisions, then the connected device pipeline.

## What actually ran

| System or stage | Input and purpose | Execution status | What it does not establish |
| --- | --- | --- | --- |
| Apple Model I/O versus official OpenUSD 26.5 | Exact retained diagnostic exports of original Hallway2 and Bedroom3 public RoomPlan fixtures | Completed; independent same-file reread | Physical survey accuracy; all native vertices; live scans |
| Apple semantic floor correction at `12a0b64` | Separate exported visual solids from historical floor-support polygon | Source and local contract checks completed; new native jobs skipped | Corrected room routes, native full-feature parity or device behavior |
| Official Open3D 0.19.0 TSDF | Koivu, 265 training frames, 29 excluded views; supplied intrinsics and poses; 4 m cutoff | Fresh fusion and full excluded-view FARO depth scoring completed | SLAM, real-time localization, full-body clearance |
| Open3D 5 m diagnostic variant | Same split and settings except one declared range change | Completed and independently recounted; not adopted | General improvement or a pure ray-clearing experiment |
| Official RTAB-Map 0.24.2 fixed-pose arm | Same 265 original RGB/depth frames; original supplied motion | Actual mapper completed; saved cloud export repaired and scored | Native free-space clearing in that original arm |
| RTAB-Map graph arm | Same input; native graph optimization | Actual mapper completed; cloud scored; worse on this comparison | Better pose accuracy simply because loop closures occurred |
| Corrected world-Z-up RTAB plus native OctoMap 1.9.7 | Same 265 training frames; regenerated native local grids; native occupied/free updates | Completed; 98 independent checks passed on saved ledger, metrics and contracts | Verified floor support, real low-object recall, paths, iPhone runtime |
| InfiniTAM v3 | Source and CPU/headless/calibration feasibility investigation | Not built or run; license and bounded execution permission unresolved | A failed reconstruction score or app redistribution eligibility |
| ElasticFusion and BundleFusion | Official implementation compatibility review | Required CUDA/OpenGL or Windows/DirectX/CUDA unavailable here | Any measured comparison result |
| Kimera-VIO | Input compatibility review | Required IMU/timing input unavailable for faithful replay | A failed mapping result |
| Blender | Independent reader candidate | Installed build lacks USD support; no same-file USD execution | An independent geometry confirmation |

Two questions must stay separate. **Reader parity** asks whether two readers interpret the same exported bytes correctly. **Reconstruction comparison** asks how engines process the same original sensor observations. Neither alone proves a mapped passage is currently safe to walk through. Recast/Detour is a routing component, not a substitute for correct reconstruction and observed support.

## Comparable measured results

### Common point and surface comparison

These four arms share the same supplied phone-to-FARO registration, deterministic actual-point 4 cm representative selection, and 127,774 reference points visible in the excluded views. Forward distance is unsigned output-point distance to reference triangles. Reverse distance is reference-point distance to sampled output points. The registration includes the author-supplied scale 1.020790844, applied once—not fitted to improve these results.

| Common metric | Open3D TSDF | RTAB fixed cloud | RTAB graph cloud | Corrected RTAB and OctoMap |
| --- | ---: | ---: | ---: | ---: |
| Sampled output points | 231,472 | 497,307 | 588,726 | 247,832 |
| Forward median | 4.26 cm | 6.64 cm | 10.36 cm | **4.19 cm** |
| Forward mean | 10.73 cm | 12.84 cm | 15.74 cm | **9.50 cm** |
| Forward 95th percentile | 49.71 cm | 48.28 cm | 49.38 cm | **43.25 cm** |
| Reverse median | 2.71 cm | **2.19 cm** | 2.78 cm | 2.47 cm |
| Reverse 95th percentile | 8.31 cm | **5.03 cm** | 10.10 cm | 6.19 cm |
| Reference samples within 5 cm | 81.53% | **94.92%** | 78.07% | 90.84% |

This is not whole-room coverage or obstacle recall. The 141,341 missing reference rays remain unknown, not clear. Output representation and density differ: a mesh-derived point sample, a raw depth cloud and occupied reference endpoints are not equivalent surfaces. Nearest-distance scores can conceal wrong occlusions. Reference completion, capture differences, registration uncertainty and moved furniture remain possible confounds.

The corrected OctoMap arm changes the gravity-sensitive coordinate interpretation, regenerates segmentation and applies occupancy filtering/ray clearing together. **The comparison does not isolate which change caused improvement.** The independent reviewer recounted saved distances and independently reproduced sample selection; it did not independently rerun every nearest-triangle query.

Sources: [completed original RTAB comparison](https://github.com/mischa23v/blind/blob/ce62bbe38b067592f3703e7276d95791b2cba687/research/rtabmap-same-data-benchmark-20261028/completed-stage-1823/RESULTS.md); source records `rtabmap-same-data-benchmark-20261028/fresh-run/octomap-stage/ZUP_RESULTS.md` and `independent-review/octomap-zup-final/REVIEW.md` in the retained research bundle. The latter records were complete but awaiting publication at this report’s cutoff.

### Open3D excluded-view depth comparison

The fresh baseline used 4 cm voxels, 20 cm SDF truncation and a 4 m depth cutoff. All 265 training views were integrated; 29 views were excluded. Original processed images and per-frame intrinsics/poses were used. Its 242,293 vertices and 461,256 triangles reproduce the historical mesh and cloud byte-for-byte.

Of 1,335,885 scheduled ray pairs, 1,187,988 hit both surfaces, 6,556 hit reference only, 138,401 hit TSDF only and 2,940 hit neither. On paired rays, median absolute axial discrepancy was **3.40 cm**, mean **18.65 cm**, and 95th percentile **1.138 m**. Restricting reference depths to under 4 m yielded 3.39 cm, 15.72 cm and 0.909 m respectively. Independent review reproduced 12,236 checks, including 2,310 numerical comparisons, with maximum difference about 8.88e-16.

These are axial first-hit differences and must not be ranked against the point-distance table as if they were the same metric. A missing reference hit is not automatically a false obstacle; a missing reconstruction hit is not free space. The large tail matters even with a good median.

Source: `open3d-same-data-benchmark-20261028/fresh-run/RESULTS.md`, `COMMON_GEOMETRY_RESULTS.json`, and `independent-review/REVIEW.json`; [published audit addendum](UPDATE_1732.md). This is an author-configured adapter using released Open3D, not an untouched execution of the entire DN-Splatter application.

### Local diagnosis and the rejected 5 m generalization

The errors are not uniformly bad floors. In a fixed frame-197 floor region, 5,328 paired rays had a 4.91 mm median and 16.93 mm 95th percentile discrepancy. In a different fixed frame-228 region, the TSDF median first hit was about 0.398 m while FARO and excluded phone data were about 3.939 m and 3.990 m. The phone-versus-FARO median discrepancy there was 5.3 cm. A selected chair region had 312 of 378 paired rays differing by over 0.5 m. These are retained post-hoc diagnostic regions, not an unbiased whole-scene accuracy estimate.

Six deterministically selected points were traced through all 265 training frames. Three suspect points matched near-foreground observations around a chair/background depth boundary; later background returns were often beyond the original cutoff. That suggests an evidence-admission/occlusion issue worth testing, but does not prove exactly which frame created a particular TSDF triangle.

One predeclared 5 m variant reduced the fixed 4,166-ray region’s median discrepancy from **3.5677 m to 4.47 cm**. However, global mean discrepancy worsened from **18.65 to 18.97 cm**, and the 95th percentile worsened from **1.138 to 1.228 m**. Eleven frame means improved, seventeen worsened and one was unchanged. Independent review performed 11,581 checks. **Do not adopt 5 m globally from the attractive local result.** Increasing cutoff changes both admitted endpoints and allocated coverage, not only free-space clearing.

Sources: `open3d-same-data-benchmark-20261028/error-tail-diagnostic/README.md`, `TRAINING_TRACE.md`, `range-ablation-proposal/RESULTS.md`, and the corresponding `TAIL_REVIEW.json`, `TRACE_REVIEW.json`, `RANGE_5M_REVIEW.json`. The five-meter evidence was retained but not yet fully published at cutoff.

## Confirmed geometry and adapter defects

### Apple source planes were compared against exported solids

Our original validator assumed exported vertices had to remain within original RoomPlan planar dimensions with only floating-point tolerance. The exact same-file OpenUSD comparison disproves that contract:

- Original architectural features have zero depth; exported walls and doors are about 16 cm thick, and floors/windows about 8 cm thick.
- Some wall endpoints extend about 16 cm.
- Both exported floors extend about **16 cm beyond the original polygon bounds on all four planar sides**.
- Bedroom furniture dimensions agree with original half-dimensions.

This caused source-geometry rejection before the planner could find a route. It is not evidence that an empty hall lacks space. Increasing epsilon or accepting all export floor faces would be wrong: it would promote exporter-generated slab rims, sides or undersides to supporting floor.

A separate source inspection found that every triangle associated with a floor UUID was assigned support, including those slab sides and underside. That was hidden by the earlier admission failure. The correction published at `12a0b64` preserves raw exports and all non-floor obstacles, while tessellating the original historical floor polygon using Apple’s zero-extrusion SCNShape and checking boundary, area, concavity and frame consistency. Historical model floor remains historical model support—not current observed support or proof of no drop. Exported wall extensions are retained and may still overblock passages; this candidate does not shave them away to obtain routes.

**Validation status:** 32 source checks, 77 collector checks, 17 extractor checks and nine route contracts passed; a canonical project proof also passed. Six Swift tests were authored, but **zero new native cases ran**. Run `40738486723` skipped both jobs under the existing public-only workflow condition after the repository became private. Permission to change that guard and assess runner cost remains outstanding. No guard was bypassed.

Source: [exact Apple reference comparison](../independent-usd-reference-catalog-20261028-1514/run40726507227/RESULTS.md), [correction proposal](../roomplan-support-contract-proposal-20261028/PROPOSAL.md), [candidate evidence](../roomplan-support-candidate-20261028/README.md), `ios/BlindAssist/SavedRoomRouteMeshAdapter.swift`.

### Scale and transforms have some proof but not complete proof

Both Apple stages author metres-per-unit 1 and Y-up. All 24 independently read feature transforms and 133 source-anchor distances are preserved exactly. The first failing native wall in each room agrees with OpenUSD bounds within 0.405 and 0.283 micrometers. That rejects a gross unit-scale or double-transform explanation **for those witnesses**, not every historical room or every native vertex.

Full per-feature native vertex/topology parity is now instrumented but unexecuted on the correction. Anchor spacing is not passage clearance. Bounding-box agreement does not prove door openings or concave floor integrity. Original saved model dimensions are not an independent physical survey.

The same-byte comparison retained diagnostic export number 2. Production export number 1 had already been deleted and was separately generated; we cannot claim those two exports are byte-identical. This evidence limitation remains explicit.

### The RTAB offline adapter confused camera axes with world axes

MuSHRoom’s pinned bundled processing documentation distinguishes **OpenGL camera +Y up from processed world +Z up**. The original offline adapter applied a world-axis rotation based on the camera convention. Inverse export rotation cancelled it for raw point coordinates, so the earlier raw-cloud/reference comparisons remain valid. Gravity-sensitive ground classification did not receive that protection.

The corrected arm uses `nodePose = P * O.inverse()`, where `O` is the released camera optical rotation; export yields `nodePose * O = P`. It applies no extra world A/B rotation and regenerates native local grids from original images instead of rotating previously classified labels. A native world-plane fixture classified 400 floor points as ground and zero as obstacles.

This is a confirmed mismatch with the documented processed-data contract. It does **not** imply the app’s separate ARKit Y-up world conversion is wrong, or establish capture gravity from unavailable raw tracking metadata. No FARO fit selected the corrected orientation.

Source: `rtabmap-same-data-benchmark-20261028/independent-review/WORLD_FRAME_SOURCE_AUDIT.md`; corrected arm `ZUP_CORRECTION_PROTOCOL.md`, `ZUP_PRE_RUN_FREEZE.json` and final independent review.

### RTAB cloud export omitted a released API precondition

Both actual RTAB runs accepted all 265 frames and saved their databases, but our first cloud export omitted native valid indices for a non-dense organized cloud. The released voxelization path returned empty output. This was **our export adapter bug**, not proof of an empty room or failed mapper.

An export-only helper reopened the saved databases, uncompressed original sensor data and passed native valid indices unchanged. It did not rerun mapping, change poses or adjust thresholds. It produced 693,573 fixed-arm points and 813,869 graph-arm points. Nine native fixture checks include the old empty failure and fourteen expected finite points, zero/out-of-range exclusions, the inclusive 4 m boundary and nonidentity transforms.

Source: `rtabmap-same-data-benchmark-20261028/completed-stage-1823/EXPORT_REPAIR.md` and `independent-review/EXPORT_FIX_REVIEW.md`.

### The common evaluator also had an input reader failure

VTK’s PLY reader crashed on the PCL zero-face point-cloud format with its camera element. The failed evaluator and receipts are retained. Only cloud decoding was replaced with the already installed official Open3D reader, in sequential subprocesses before the large FARO allocation. Counts, hashes and asymmetric coordinate fixtures passed; no smoothing, filtering or geometric completion was introduced. This fixes an evaluator interoperability failure, not the room geometry itself.

## What the corrected occupancy result means

All 265 regenerated local grids were processed through released `LocalGridCache -> OctoMap::update` with native ray clearing. The result contains:

- **2,268,956 observed leaves**;
- **325,714 occupied**, comprising 63,720 native-ground-tagged and 261,994 other occupied leaves;
- **1,943,242 observed-free leaves**;
- unrepresented space remaining **unknown**, not silently free.

The independent reviewer decoded every leaf and reproduced category indices, all 265 frame records, sampling and saved metric summaries: **98 checks passed**. Synthetic native fixtures cover repeated hit/free evidence, unchanged state without evidence, unknown space, low/head endpoints, duplicate-prefix handling and nonidentity poses. These do not establish real-world small-hazard recall.

**Important handled pitfall:** 174,769 currently free leaves retain historical obstacle labels; another 17,686 retain historical ground labels. Current occupancy probability/flag—not historical label or node identifier—must decide occupied/free state. This was handled in the new adapter; it is not evidence that the old app necessarily made this error. Ground endpoints are occupied-ground classifications, not verified supporting floor. Ray-free space does not establish support beneath the body. Native hit/miss weighting is also asymmetric: repeated endpoint hits and unique free keys are not independent equally weighted measurements.

Native `.ot` serialization preserves occupancy/color, not all RTAB custom semantic/reference fields. The separate leaf ledger preserves its documented fields; original reference-endpoint geometry is separately exported. The ledger alone does not recover all sensor history.

The corrected mapper was interrupted during post-mapping export. Its database passed SQLite checks and retained all 265 nodes/images/depth/grids; the partial 54-row pose export was kept. Read-only recovery obtained all saved poses, matching frozen inputs within 3.28e-7, without rerunning mapping. Interruption CPU/RSS were not measured; conservative resource charges and limited process visibility are recorded rather than invented. Occupancy replay took 36.22 seconds with about 359 MB peak sampled RSS; common scoring took 36.28 seconds with about 2.26 GB. These are cloud CPU measurements, not iPhone performance forecasts.

## Earlier findings and their current status

The earlier full report has nineteen individually sourced findings. None is silently removed because the newer reconstruction looks better.

| ID | Finding | Current status and consequence |
| --- | --- | --- |
| G01 | `.json` extension led to JSONDecoder on `bplist00` metadata | Repaired and natively verified; both original fixtures map identities correctly. Serialization success is not geometry success. |
| G02 | Planar source bounds reject Apple exported solids and expanded outlines | Confirmed; semantic correction published, native rerun skipped. New all-floor-face support defect covered above. |
| G03 | Exact failing production export was not retained | Same-byte diagnostic capture now works; earlier production artifact remains unavailable. |
| G04 | Units, transforms and scale required an independent reader | Two exact exports and stated witnesses checked; full native topology and physical dimensions still open. |
| G05 | Displayed body differs from actual planning envelope | Declared envelope arithmetic verified; exact visual/path contradictions still unresolved. |
| G06 | All-blocked evidence was at risk of being called an impassable room | Source rejection is now separated from no-path and physical obstruction; no admitted route existed in those receipts. |
| C01 | Mixed floor/wall collision query missed a modeled wall | Narrow separated-category repair passes native synthetic controls; not a universal full-scene oracle proof. |
| C02 | Some floor contact was treated as potentially sufficient support evidence | Full-footprint support remains unverified; old floor polygons and native ground labels cannot close it. |
| C03 | Native mesh build nearly exhausts callback deadline | Instrumented; 9,948 ms callback included 9,781 ms native build. No demonstrated performance fix or target-phone timing. |
| L01 | Existing sensing not connected into full live room navigation | Sensing/preview exists; audited mesh diagnostic callbacks did not own/ingest live mesh. New complete runtime execution unproved. |
| L02 | Ingress did not forward per-face classification | Explicit opt-in classified-floor path published; nine hosted fixtures passed. Default legacy behavior and actual classifier accuracy are separate. |
| L03 | Camera pose substituted conceptually for calibrated body pose/current clearance | Live calibrated body/map/support installation remains open; room recognition alone is insufficient. |
| P01 | Historical assisted simulations cannot establish phone navigation | Retained as limited simulations. Invalid starts, supplied poses and reference-assisted trials are not independent physical arrivals. |
| P02 | Stale source pins stopped proof workflows before tests | Four active entries/nested manifest repaired; 55-target check and follow-on proofs passed without weakening provenance. |
| P03 | Stub-tested early exporter ran before its real summary dependency | Reordered actual exporter/collector; six real-shell regressions and native complete extracts verify bounded repair. |
| P04 | Passing component counts mistaken for completed journeys | Still open; skipped model cases are not repaired cases; 400 full journeys and sustained guidance acceptance unfinished. |
| P05 | Accessibility clipping/contrast defects | Clipping repair prepared; contrast persists in last executed UI run. No complete accessibility pass. |
| P06 | Unlike historical reconstruction scorers mixed training and held-out evidence | Fresh 265/29 experiments now executed and separated by metric; historical receipts remain labeled with their limits. |
| P07 | New hosted tests omitted required direct link dependency | Stage-81 hosted membership fixed; exact-source run linked and executed nine ingress and same-export cases. Not a geometry repair. |

Source links and exact earlier revisions are preserved in [the original detailed report](FULL_REPORT.md). This table updates statuses; it does not claim new reruns of every historical test.

### Body envelopes and the reported wall crossings

A nominal 28 × 20 cm profile with a 15 cm horizontal margin has a circumscribed-cylinder planning diameter of **64.41 cm**, not 28 cm. A 45 × 30 cm profile yields **84.08 cm**. These are declared test assumptions, not calibrated human measurements or recommended margins. This difference does not explain the current Apple all-blocked result: geometry admission failed first.

The user’s reported lines through walls/furniture and narrow accepted fragments in apparently broad passages remain unresolved. Neither a photograph nor a top-down plot alone establishes exact clearance. Equally, “conservative” is not an adequate explanation for false blockage. Required evidence is one registered view containing source geometry, actual candidate path, raw body, margin envelope, requested/projected endpoints and continuous swept-volume checks. Do not reduce bodies, delete obstacles or fill unknown floor until a preferred-looking line appears.

### Last actual Apple native evidence

At `c4ffa28`, run `40726507227` recorded **236 hosted cases: 223 passed, 7 failed, 6 skipped**. All nine classification-ingress cases passed. Eighteen routes and sixteen supplied-pose journey stages remained blocked by `sourceGeometryMismatch`; no useful original-room route was produced. The UI receipt contains 18 cases: 14 passed, one contrast failure, three skipped. Its current failure metadata lacks a target snapshot, so an earlier identified button cannot automatically be called the latest failing element.

The collision fixture specifically demonstrated wall-only combined queries passing 6/6, mixed wall/floor combined queries passing 4/6, and mixed separated-category queries passing 6/6. All eight collision-oracle cases passed within that witness. This does not establish collisions against incomplete sensed geometry, support, child safety or real device behavior.

## Approaches not justified by the evidence

- **Treating shadows or carpet color as the established cause.** Their visual overlap with artifacts is a useful hypothesis, not a measured causal result. RGB evidence may help alignment and diagnosis; it cannot simply erase depth hazards because an LLM says a picture looks empty.
- **Flattening all floor or widening a band until paths appear.** Historical local-floor attempts admitted almost no starts or could hide low objects. Local support must reconcile observations without promoting unseen areas or erasing coherent raised geometry and drops.
- **Calling graph optimization an improvement by default.** The RTAB graph arm moved poses by a median 14.26 cm, maximum 41.05 cm, with 45 loop-event frames; both common metric directions worsened here. Gauge consistency was checked; no post-hoc alignment concealed the outcome.
- **Promoting the 5 m local improvement to a global fix.** Its global tail worsened.
- **Using a single accuracy percentage for safety.** The user’s reported 92% study is not confidently identified. The verified near-match Corridor-Walker’s 92.9% concerns intersection-shape labeling, not room reconstruction or collision avoidance. Likewise 90.84% in this report is sampled reference proximity, not safe navigation.
- **Assuming a newer phone solves geometric uncertainty.** No target-phone runtime, thermal, battery, sensing or low-hazard experiment was performed in these comparison stages.
- **Treating absent obstacles or native ground labels as supporting floor.** Missing, stale or contradictory evidence still requires explicit handling.

## Reuse and licensing boundaries

Released code is being used, but integration bugs remain our responsibility. OpenUSD is an importer reference under TOST 1.0, not a mapper. Open3D is MIT; the reviewed DN-Splatter adapter is Apache 2.0. RTAB-Map core is BSD-3-Clause, but this research build includes TORO under CC BY-NC-SA, so this build is not cleared for app redistribution. MuSHRoom data/reference attribution and CC BY 4.0 obligations remain separate from code licenses.

InfiniTAM has a plausible CPU headless/file-pose path, but stock single-calibration input is unsuitable for the varying per-frame Koivu intrinsics without an explicit adapter. Its default mesh allocation is about 4.5 GiB; a bounded build must cap allocation and reject saturation. The stock build also pulls GUI/OpenGL dependencies. More importantly, its noncommercial license explicitly limits commercial-product research and development and has publication/attribution obligations. Source feasibility is not permission or a completed comparison. No model has been scored as “worse” merely because its hardware or input requirements are unavailable here.

Public upstream sources: [MuSHRoom](https://github.com/TUTvision/MuSHRoom), [Open3D](https://github.com/isl-org/Open3D), [RTAB-Map](https://github.com/introlab/rtabmap), [OctoMap](https://github.com/OctoMap/octomap), [OpenUSD](https://github.com/PixarAnimationStudios/OpenUSD), [InfiniTAM](https://github.com/victorprad/InfiniTAM). Version-specific source, license and build receipts—not repository popularity—govern the comparisons in this report.

## Required next work and acceptance gates

1. **Verify support and hazard retention in the corrected actual grids.** Separate floor from low, body-height and overhead geometry; inspect known false obstacles and missed reference geometry. Native segmentation may remove a low object before occupancy fusion. Score retained hazards and supporting coverage, not merely nearby surfaces. Freeze decisions before an untouched holdout; do not tune on its outcomes.
2. **Complete the Apple native correction test.** With the required runner authorization, run the exact published candidate, collect every raw mesh feature, compare native and official-reader geometry/topology, then rerun unchanged route and journey cases. A skipped run remains skipped until it actually executes.
3. **Run geometry-aligned route and swept-body tests.** Record starts, goals, connectors, route lengths, full-body contacts, ground support, unknown exposure and failures separately. Include table circulation, wide passages, doorway transition and return. Use the actual candidate map, not manually rebuilt reference geometry. Preserve failed and rejected episodes. A failed start is not an executed movement trial.
4. **Verify simplification rather than cosmetic smoothing.** Check metric units, local surface displacement, obstacle retention, openings, floor elevation and connectivity against the accepted unsimplified map. A prettier mesh is not a more reliable one.
5. **Connect incremental live observations and localization.** Establish map/building/floor/room selection, actual position and heading, camera-to-body mount calibration, fresh support and obstacle coverage, map updates/removals, off-route detection and restart/tracking-loss recovery. Replaying recorded poses is not localization. Old maps support destinations and topology, not current clearance.
6. **Measure guidance and runtime on device.** Validate sustained update latency, cancellation, hazard priority, near-feet/head coverage, spoken instruction timing, VoiceOver and accessibility. Keep LLM output out of movement authority. Preserve local privacy and user-controlled lifecycle semantics.
7. **Only then conduct controlled physical validation.** Begin with bench and controlled adult device comparisons, with appropriate observation and stopping arrangements. Child-facing testing needs its separate supervised protocol and orientation-and-mobility review. Do not use a real stair/drop as the first discovery of a failure.

This sequence is not permission to indefinitely defer useful paths. It identifies the exact missing evidence that makes the next path result meaningful. Geometry rejection, false blockage and no usable movement are failures to fix, not successful safety metrics.

## Reproducibility and publication status

The verified research branch is `codex/recovery-hazard-order-20261027`; the last verified remote head at this cutoff is **`ce62bbe38b067592f3703e7276d95791b2cba687`**. `master` was not changed by this audit work. Historical snapshots remain separate:

| Commit | Published evidence |
| --- | --- |
| `caf1e0229d677b4fa62a501ce2bf344783dfc8cb` | Original nineteen-finding audit and actual Apple/OpenUSD comparison |
| `3f01d4a285878c0cba5d307fd3ae2920de7a79b7` | Fresh Open3D benchmark and new floor-support defect addendum |
| `12a0b64bc403db3f48a997aea868b9ad670e73fb` | Apple floor semantic correction candidate and full native parity instrumentation |
| `98a47d6f4c7758fe51ca47ae6edcbb0b0aba9345` | Localized error diagnostic, InfiniTAM feasibility and skipped native status |
| `162b199230248ea46869431f5f6f80c487f9884b` | Six-point training-evidence trace |
| `4e3eac061c00c67e8b1947ec9401f6a6248b3ba0` | Actual RTAB build/runs and retained initial export failures |
| `ce62bbe38b067592f3703e7276d95791b2cba687` | Completed fixed/graph cloud comparison and export/evaluator repairs |

The completed 5 m variant and corrected OctoMap receipts, source, arrays and independent reviews are retained separately. Their complete numerical publication was awaiting specific approval at cutoff; **they must not be described as already pushed**. Bulk derived outputs are preserved separately and not all are in GitHub. This report contains aggregate findings and source locators, not raw RGB/depth databases, private images, health/body records or absolute host paths.

For exact reproduction, use each stage’s frozen input manifest, software revision, source and build receipts, protocol, launch arguments, interruption/failure records, output manifest and independent recount script. The corrected OctoMap source records are under `research/rtabmap-same-data-benchmark-20261028/fresh-run/octomap-stage/`; its final independent review is under `research/rtabmap-same-data-benchmark-20261028/independent-review/octomap-zup-final/`. The original 69-file text allowlist and later review files need to be reconciled before any complete stage publication. An aggregate report is not a substitute for those reproducibility records.

**Current verdict:** the audits found and repaired concrete code defects, and a released occupancy pipeline now gives a materially better candidate than the previous reconstruction on this comparison. We have not yet demonstrated reliable room navigation. The next job is to validate that candidate’s support and retained hazards, then produce registered, collision-checked paths—not claim completion from a favorable median or another passing source test.
