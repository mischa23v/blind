# One offline map, complementary evidence, live safety

**2026-10-30 — proposed, unexecuted integration plan.** This document connects
released upstream methods to the existing Coffee/conference experiments. No
new mapper, repair, native build/test, model download, paid compute, app caller,
map publication or physical guidance was executed or enabled by this work.

## Decision

Use complementary **surface, occupancy/coverage and semantic layers** rather
than select a visually attractive mesh or let several meshes vote on safety.
Do expensive, evidence-supported processing once per accepted scan revision;
export a compact versioned map for the phone. Keep fresh local sensing,
localization, body heading and support checks independent and continuously
eligible. A static map never establishes present clearance.

Multiple methods can expose different defects, but methods using the same
depth and poses share errors. No ensemble can certify an obstruction that no
input observed. TSDF-to-ESDF conversion and semantic annotation add useful
representations, not independent measurements. All missing/conflicting evidence
must remain visible rather than become an artificial certainty score.

The zero-budget first increment is **existing OctoMap plus a calibrated TSDF
comparison**, not several full SLAM stacks or a cloud/GPU requirement. Reuse
upstream reconstruction, traversal and collision algorithms; our work should
be narrow adapters, provenance, comparison and evidence gates.

## What the actual repository evidence permits

| Existing packet | Consequence for this plan |
| --- | --- |
| [Coffee shared-pose occupancy result](../coffee-shared-pose-occupancy-result-20261029/README.md) | Measured endpoints are retained with explicit hit/free conflicts in the supplied-pose world. This is not true-world calibration, held-out accuracy or alignment to the supplied Polycam mesh. Preserve both conflicts and unknown volume. |
| [Coffee held-out result](../coffee-heldout-depth-result-20261030/README.md), run `coffee-heldout-depth-attempt-001`, and [read-only ray controls](../coffee-readonly-ray-controls-result-20261030/README.md) | Actual run001 recreated the exact baseline and recorded endpoint coverage without mutation. Both held-out camera origins were unknown: all 18,904 valid sampled rays stopped there, producing **zero residuals**, not zero error. Retain this coverage limitation; no ray-depth accuracy or navigation verdict follows. |
| [Conference native proposals](../conference-native-comparison-result-20261029/README.md) | Native Recast/Detour proposals and their centering proxies are not full-body, support or localization acceptance. Retain original requested connectors and every objective. |
| [Conference complete contact IDs](../conference-contact-ids-result-20261030/README.md) and [simplified-body result](../conference-simplified-body-result-20261030/README.md) | Low nominal contacts remain, while margin contacts also include higher geometry. Low triangle height alone is not a floor label; fewer authored events are not proof of repaired geometry or safer travel. Preserve all original contact IDs and the documented lower-query exclusion. |
| [Rapier complete analytic result](../rapier-analytic-collectall-result-20261030/README.md), preserving the [first failed run](../rapier-analytic-controls-result-20261030/README.md) | Attempt002 completed all 72 wrappers/108 nested rows; two margin-envelope 1 cm down-step assertions fail, and aggregate status stays failed. Both mesh-flag arms have identical movement/grounded outputs on all paired probes. A separately reviewed known-failure real-room diagnostic may proceed with those limits retained; trusted replacement and physical authority remain unaccepted. |

Historical registration of the conference mesh remains an **estimated
comparator**, not calibrated camera/body alignment. VTK and Rapier query the
geometry supplied to them; neither can detect an omitted physical surface.
An independent collision implementation is not an independent scene survey.
Rapier's complete analytic run also proposes forward motion over an unsupported
gap while `grounded=false`, and upward input can bypass its horizontal slope
rejection. Preserve independent support/hazard checks and unsupported-turn
reporting; diagnostic movement proposals must not be applied as corrections.

## Prerequisite: one explicit metric frame contract

Freeze a manifest before comparing methods: exact input/source hashes, original
frame IDs and partition, timestamps when present, RGB/depth association,
per-frame intrinsics, resolution/resizing convention, axial-versus-ray depth,
depth scale, camera basis, pose direction, units, valid-range/confidence rules
and missing metadata. Never fill absent tracking/confidence fields by guessing.

Keep these frames distinct:

- **P:** original capture's supplied-pose world. Coffee's existing adapter uses
  the reviewed `T_frame @ diag(1,-1,-1,1)` camera conversion and original
  translations as sensor origins. Reuse it; do not add another axis shuffle.
- **M:** released Polycam mesh frame. The official MuSHRoom README explicitly
  says that mesh is not aligned with the camera poses and is for visualization.
- **R:** independent FARO/reference evaluation frame. Any P-to-R or M-to-R
  transform must retain its actual provenance and uncertainty.

No cross-layer merge is admissible without the applicable documented transform
and independently checked metric scale. Plausible visual alignment is
insufficient. Do not optimize each method's scale or registration against the
evaluation geometry and then report those fitted results as capture accuracy.
If only fitted alignment is available, label that comparison and its limit.

Primary evidence: [MuSHRoom data contract](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/README.md#data-structure),
[official camera conversion](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/iphone_tools/1_nerfstudio_to_sdfstudio_within.py),
and [existing Coffee source contract](../coffee-shared-pose-occupancy-source-20261029/README.md).

## Proposed layers and responsibilities

| Layer | Upstream reuse and useful output | Must not imply |
| --- | --- | --- |
| Surface geometry | [Open3D TSDF integration](https://www.open3d.org/docs/latest/tutorial/t_reconstruction_system/integration.html): fuse calibrated depth at known poses, retain weights/coverage and extract a surface. Compare against the existing mesh using identical inputs and poses. | Smoothing recovers all thin/low objects, fills unseen surfaces correctly, or fixes pose drift. |
| Occupied/free/unknown | Existing pinned OctoMap adapter. Retain observed endpoints, valid ray-free evidence, unknown stops and hit/free conflicts. [Released traversal contract](https://github.com/OctoMap/octomap/blob/007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f/octomap/include/octomap/OccupancyOcTreeBase.h). | No triangle/no detection/no valid depth means free space. Missing/range-excluded rays must not carve free space. |
| Semantics | An optional separately verified local detector/segmenter associates labels with measured geometry and source views. [Kimera-Semantics](https://github.com/MIT-SPARK/Kimera-Semantics) demonstrates integration of labels with volumetric mapping. | A label measures a boundary, identifies floor safely, or authorizes reach/movement. Kimera reuses Voxblox/OpenChisel geometry; it is not another independent geometry vote. |
| Fast clearance | Consider a derived ESDF only if needed for compact queries; [Voxblox](https://github.com/ethz-asl/voxblox) provides TSDF-to-ESDF implementation. Preserve observation masks alongside distances. | A finite distance in an unobserved region is verified clearance, or an ESDF is additional sensing evidence. |
| Native collision/support evaluator | Keep current complete-chain/body/margin diagnostics. A separately frozen comparator may run diagnostically with declared analytic failures; it must not silently replace the existing comparison baseline or become a clearance override. Separate surface collision, solid containment, floor support and coverage tests. | A successful query against an incomplete mesh proves physical avoidance or full support. |

### Repair policy, not mesh averaging

Propose a floor/wall correction only where original observations, calibration,
coverage and bounded residuals support that surface. Preserve the raw version,
proposed corrected version, changed region and justification. Never globally
flatten near-foot triangles, erase low contacts, fill holes as walkable floor,
or shrink the body/margin to obtain a favorable outcome. Keep low-object
residuals, boundaries, slopes, steps/drops and unknown support.

When layers disagree, retain a conflict/rescan region. A conservative hazard
union can increase false alarms; an intersection/majority vote can delete a
real obstruction. Neither is an automatic acceptance rule. Semantic guesses
may prioritize review, but may not clear occupied/unknown space. FARO remains
evaluation-only and must not choose repairs, routes or mapper parameters.

## Smallest experiment and acceptance dimensions

1. Preserve Coffee's completed zero-residual outcome and endpoint coverage.
   Do not carve either held-out origin free or bypass unknowns within the
   primary visibility criterion. A separate observed-surface diagnostic may
   search beyond unknown space only with an explicit unknown-visibility status,
   never as clearance or a live fallback. Any expanded-training or different-view
   experiment needs a new frozen partition and purpose; it cannot rewrite run001.
2. Establish frame/scale prerequisites and reuse the recovered Git-resident
   TSDF sources below. Review exact inputs and runtime/dependency availability
   before execution; sparse-worktree absence is not missing repository source.
3. Freeze comparison arms: unchanged current surface; calibrated TSDF; TSDF
   with occupancy/unknown constraints; evidence-supported repair only as a
   separately identified arm. Keep the same frames, poses, original objectives,
   body, margin, endpoint connectors and evaluator. A pose-estimation change is
   a separate experiment, not an undocumented improvement to one arm.
4. Preregister denominators, units, acceptance bounds and resource limits from
   the sensor/export contract and intended use **before** results. This plan
   invents no accuracy target, safety percentage or device speed claim.
5. Score all arms against the independent FARO/reference evaluator with its
   known limits, and retain failures/timeouts/unavailable cases. Run the native
   full-body/support checks separately; do not choose favorable routes only.

Required outcome dimensions:

- Surface accuracy **and** completeness; missing-obstacle and false-obstacle
  behavior by low/body/head-height regions, including thin structures.
- Known-free versus occupied/unknown coverage, false-free space, conflicts,
  unscored rays and genuine observation gaps; no zero-filled missing scores.
- Floor/support residuals, slopes/steps/drop boundaries, doorway/clearance
  error and complete-footprint support, not only a room-average mesh score.
- Original-route body and margin contacts, support uncertainty, invalid starts,
  refusals, no-path, interrupted runs and completed movement/arrival separately.
- Artifact size, bounded offline processing resources, and later actual-phone
  load/query/update latency, memory, energy and thermal behavior. Desktop timings
  cannot establish phone performance.

Improvement must not come from deleting difficult data, hiding unknowns,
changing geometry tolerances after inspection, leaking reference data into the
mapper, or calling a stopped/refused route successful avoidance. A candidate
can improve a dimension while remaining unaccepted overall.

## Offline baseline versus live phone responsibilities

The proposed compact export contains revision/hash/provenance, metric frame,
support surfaces, connectivity, collision/clearance representation, coverage
and conflict masks, semantic annotations and survey age. It need not contain
every reconstruction model or full-resolution input. Preserve version-specific
verification; do not switch maps silently during an active route.

The phone still needs validated map-relative position, body-versus-camera
heading and mounting, fresh local obstacles/support, drift/change detection,
timely independent hazard warnings and bounded stop/recovery behavior. Dynamic
changes invalidate local map assumptions; uncertainty must withhold unsupported
physical claims. Models, saved maps and a map's rating never override those
gates. The required supervised device/O&M acceptance remains open.

Privacy and cost remain as required by `AGENTS.md`: private home scans/photos
and personal memory stay on the phone, with no new upload/backup path. Heavy
computer-side research here concerns already-authorized public licensed data;
public-venue processing/distribution additionally needs the required consent
and permission. No account, paid API, cloud service, GPU rental or network at
runtime becomes a prerequisite for the core app.

## Open3D reuse inventory — read-only, no restore/install

Inspected Git tree `2bc9cfbfea94423576d0c2cad81d6e67be164e31`. Sparse checkout
omits these paths locally, but their source blobs were successfully read from
the existing repository objects:

- [`tools/tsdf-baseline-comparators/`](https://github.com/mischa23v/blind/tree/2bc9cfbfea94423576d0c2cad81d6e67be164e31/tools/tsdf-baseline-comparators): prior Koivu fusion source, stage11 held-out and stage12 saved-reference evaluators, fixed manifests, source notices, dependency locks/acquisition recipe and historical environment/result receipts. The baseline source `blind-open3d-author-baseline-10/koivu_author_fusion.py` is 11,473 bytes, SHA256 `bec91d5b1d4877d82beef3a621e92d39ed870cf6f273d84e9dea3a742789d9e4`.
- [`research/open3d-same-data-benchmark-20261028/fresh-run/`](https://github.com/mischa23v/blind/tree/2bc9cfbfea94423576d0c2cad81d6e67be164e31/research/open3d-same-data-benchmark-20261028/fresh-run): later fusion/common-evaluation source and frozen receipts. `fusion_worker.py` is 8,257 bytes, SHA256 `cce6699ab0430fda0c9bdac02fb992af2d82f4f1a689b934cbb71d2f43cc5086`.

The existing engine pin is **Open3D CPU 0.19.0**, upstream revision
[`1e7b17438687a0b0c1e5a7187321ac7044afe275`](https://github.com/isl-org/Open3D/tree/1e7b17438687a0b0c1e5a7187321ac7044afe275).
The retained historical receipt names
`open3d_cpu-0.19.0-cp312-cp312-manylinux_2_31_x86_64.whl`, SHA256
`dc935427a28cdba4ef511e9ee366b6001962b583e64231887c9b2e4cff787ee2`.
The packet explicitly excludes installed packages, wheels and caches; a recipe
and an earlier successful import are not a runtime on this executor.

Read-only workspace/shared/tmp and standard Python-site inventories found no
Open3D installation or wheel. Current Python reports 3.12.14, but ABI/architecture
and the complete numerical dependency closure have **not** been admitted for
execution. No scientific import, historical script, archive restoration or
installation was performed. This was a bounded location check, not a claim
about every machine or cache.

The separately referenced `research/coffee-original-pose-tsdf-comparator-20261028/`
is absent from both the inspected Git tree and worktree. Koivu source is
reusable; it is not an exact recovered Coffee run. The next source step is to
recover the original Coffee manifest/partition or explicitly prepare a new
reviewed Coffee adapter and launch manifest. Historical normalized manifests
contain placeholder paths and cannot be relabelled exact executable inputs.
Fresh fusion remains blocked on those input and compatible-runtime checks;
reuse existing source/results first rather than reinstall blindly.

## Official code-license evidence and adoption status

License checks below concern upstream code, not transitive dependencies,
model weights or datasets. Preserve required notices and review the actual
selected source closure before adoption. This is source screening, not an
approved dependency update or completed legal/security review.

| Candidate | Official evidence | Suitability and unresolved work |
| --- | --- | --- |
| Open3D | [MIT license](https://github.com/isl-org/Open3D/blob/main/LICENSE) | Permissive reuse with notice retention. Prior CPU 0.19.0 source/provenance is recovered from Git; compatible local runtime, Coffee inputs and new bounded integration remain unverified. No install or upstream tests run here. |
| OctoMap core | [Official project license statement](https://octomap.github.io/) and [pinned existing source](../coffee-shared-pose-occupancy-source-20261029/README.md) | New BSD core is suitable for this reuse path subject to notices. **Octovis is GPLv2**, a separate component not proposed for app bundling. Retain existing reviewed OctoMap 1.10.0 revision rather than silently upgrading. |
| Voxblox | [BSD-3-Clause terms](https://github.com/ethz-asl/voxblox/blob/master/LICENSE) | Permissive optional clearance-representation candidate; preserve notices/non-endorsement terms. No dependency or iPhone-port selection made. |
| Kimera-Semantics | [BSD-2-Clause terms](https://github.com/MIT-SPARK/Kimera-Semantics/blob/master/LICENSE.BSD) | Permissive semantic-fusion reference. Separate segmentation weights/runtime and transitive notices are not approved by this license; no model selected/downloaded. |

MuSHRoom input attribution and CC BY 4.0 provenance remain in the existing
Coffee/conference packets and [official data release](https://zenodo.org/records/10230733).
No raw depth, images, map arrays, native binaries or new data copies are part of
this document. Root retains publication and separately scoped execution review.
