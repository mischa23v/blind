# Independent review of the Koivu floor-routing diagnostic

Reviewed diagnostic **7506ad9cd2fa171bf53cb2e1ec66628f20d4f61d** against mapper branch
**57fdf25f2c17b3f1cf6c5aba1156756c1e808eee** on 2026-10-26.

**Conclusion:** global-only floor/support classification is a confirmed implementation
defect and a strong explanation for false blockage in the western passage. The fixed
loop proposal is also restrictive. Neither failure establishes an impassable room or
inadequate iPhone hardware. The underlying view-dependent geometry discrepancy is
not yet separated into pose drift, depth/calibration bias and actual surface variation.

This publishes the focused follow-up review, not every artifact from the earlier audit.
No mapper fix, reconstruction, native plane fit, new FARO query, route or movement
episode was executed by this follow-up. Existing unfinished movement work remains open.

## Reproduced evidence

`REVIEW_7506AD9_CHECKS.json` preserves the original numerical result. Independent checks:

| Check | Result |
| --- | --- |
| Packet | 120 files accounted for; all 118 manifest payload hashes match |
| Source | pipeline.py, pipeline2.py, occthres.py and routes_rect.py byte-identical to 57fdf25 |
| Camera centres | 39 of 294 lie in blocked cells |
| Western passage | 33 blocked camera records; 25 unique blocked cells |
| Blockage classes | 15 low-obstacle cells; 10 missing-support cells |
| Endpoint evidence | 8,567 saved associations and residual equations reconciled |
| Three source frames | Original frames 62-64 independently reprojected; saved endpoints exact |
| Signed-key fix | 796/1,384 fit rows change; maximum western height effect 0.02038 mm |
| Camera return at frame 214 | 0.339645 m in XY; 0.361518 m in 3D; angular sweep 1.003913 turns |

| Frame | Global median height | Saved per-view median signed residual | Plane tilt |
| --- | ---: | ---: | ---: |
| 62 | 61.40 mm | 0.754 mm | 1.75 degrees |
| 63 | 66.50 mm | 1.151 mm | 2.15 degrees |
| 64 | 61.84 mm | 1.437 mm | 1.78 degrees |

These are in-sample plane residuals, not calibrated physical accuracy. The fit does
not prove that inliers are safe to remove. Saved results contain 236 valid and 58
invalid fits. Half-pixel alternatives change the selected heights by at most 1.30 mm.

The ten missing-support cells contain 812 endpoints but none within 2 m. Plane
extrapolation cannot establish support there. In nominal cell [44,171], conditional
near/far median heights differ by 71.43 mm; exact physical surface correspondence
has not been established. Closer observations are not automatically more trustworthy.

The saved reference join has 13 low-flag cells with zero contacts across tested
bands from 1 cm to 1.8 m and five support hits each, at -4.71 to -2.72 mm. This review
checks the saved join against current mask flags; original triangle arrays and the
FARO mesh were not independently reloaded. The other 12 blocked cells have vertex-only
evidence. FARO cleaning, hole completion, different capture and author registration
remain limitations; reference evidence is never fed into the planner.

## Source diagnosis

`pipeline2.py:29` and `:39` classify fixed global height bands. Classification at
line 105 precedes frame offsets at line 106. Those offsets affect `lowband_stat`,
not the occupancy/support classification. The statistical-clear mask intersects
existing walkability and cannot restore a cell already blocked by it.

`occthres.py:24-25` retains floor support from the 0.5 threshold and reclassifies
obstacles at other thresholds, including 0.7. It does not introduce a local floor.
Changing occupancy thresholds is therefore not a correction for misregistered floor.

The signed-Y key decoder is defective, but its measured effect here is far too small.
Units, pose direction, level rotation and game-axis conversion show no gross error in
the inspected path. Correct rotation matrices do not establish accurate physical poses.

`table_loop.py:338` deliberately constructs one fixed loop proposal. It selects four
waypoints outside the target bounding rectangle and does not search alternate choices
after a leg fails. The target is a blocked component with an approximately 5.2 x 7.7 m
bounding box, not an independently verified table outline. These failures are not an
exhaustive orientation-aware route search. Preserve all failed profiles as failures.

The dataset authors list Koivu as **10 x 8 x 2.5 m**:
https://github.com/TUTvision/MuSHRoom#list-of-data-sets . This is an overall scale check;
measurement uncertainty and exact passage widths are not supplied by that table.
No independent minimum table-to-furniture gap was measured in this review.

### Measurement protocol for the next step

Use calibrated metric depth and camera intrinsics/poses, with sensor confidence when
actually available. Koivu's processed export lacks original confidence and tracking
metadata; do not invent them or treat repeated upscaled pixels as independent readings.
Measure opposing observed surfaces in 3D at foot, body and head heights relative to
locally verified support. A floor-width number alone misses chair bases and overhangs.

Compare separate views and revisits. Released Open3D registration can diagnose pose
disagreement using rigid transforms with scale fixed to one; do not fit a similarity
scale to force agreement. Preserve the original observations and evaluate changes on
held-out floor and non-floor surfaces. Keep observed-free, occupied and unknown
evidence distinct; absence of returns or mesh triangles does not establish clearance.
Floor association and repeated-view consistency are the next measurement work, not
an AI estimate of room scale or a claim of millimetre clearance from a plane fit.

## Smallest recommended correction

Keep poses, raw returns, the global coordinate frame and released occupancy fusion.
Replace global-only classification with locally observed support height/slope and
explicit uncertainty. Reuse the pinned Open3D 0.19.0 plane estimator as an estimator,
not a point-deletion or clearance rule.

1. Retain each support patch's observed extent, contributing frames, uncertainty and conflicts.
2. Evaluate low-object and body/head heights relative to local support.
3. Retain all residuals, secondary surfaces, step edges and below-support evidence.
4. Do not infer support from plane extent or its convex hull. Invalid/conflicting fits remain unknown.
5. Do not adjust an entire pose to flatten its floor without independent non-floor consistency checks.

Freeze affected cells and controls. Estimate with one subset of observations and test
held-out patches/views. Compare overlapping floor and non-floor geometry across frame,
range, viewing angle and location. A pose correction must improve independent surfaces
as well as floor agreement. Test raised objects, steps, ramps and holes through the
actual classifier; a fitter retaining points is not a passing hazard test.

Freeze this policy before new reference scoring. Rebuild the phone-only map and permit
alternative route proposals around a verified target, while retaining body dimensions,
declared margins and collision checks. Do not widen the floor band to swallow 6-7 cm,
carve the camera trace, use FARO to repair the map or manufacture a movement pass.

## Reproduction

Requires Git, Python 3.10+, NumPy 1.26.4 and Pillow 11.3.0. No Open3D, SciPy, VTK,
OctoMap bindings, native builds or model weights are required for these small checks.
Use an existing isolated environment, or install these two packages into a new venv.

Run from the repository root. Fetch the comparator if its commit is absent:

```text
git fetch origin master claude/affectionate-curie-bolib1
python -m pip install numpy==1.26.4 pillow==11.3.0
python research/mapping-audit-20261026/prepare_review.py --iphone-archive PATH/koivu_iphone.tar.gz
python -B research/mapping-audit-20261026/review_7506ad9.py
```

The archive is the existing `koivu_iphone.tar.gz` release asset:
https://github.com/mischa23v/blind/releases/tag/navigation-test-data-20261026

Expected SHA-256: `68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518`.
The preparation command performs no network access. It verifies the archive, exports
the exact Git subtrees with CRLF conversion disabled and extracts only the pose JSON
and three depth PNGs. Existing differing files are preserved and cause an error.
MuSHRoom data attribution/license: CC BY 4.0, as recorded in the diagnostic packet.

New results go to `artifacts/mapping-audit-20261026/REVIEW_7506AD9_REPRODUCED.json`;
the recorded result is not overwritten. All scientific fields should match the
recorded JSON, allowing small floating-point differences across platforms; elapsed
time is environment-dependent. The checker asserts exact source projection/association
and bounded numerical checks internally. This validates computation, not physical accuracy.

## Execution history and publication

The initial local packet check failed because Windows Git archive output converted
text to CRLF. Git blob hashes matched the packet; extracting with
`git -c core.autocrlf=false archive` fixed the local export. That failure and subsequent
successful local logs remain preserved, not rewritten as a scientific result.
The final original check was serial, bounded to 60 seconds / 512 MiB, and used
19.922 seconds wall time with 78,606,336 bytes peak sampled process-tree RSS.

The publication changes only output handling in the executed review script: an optional
`--output` argument and a default untracked artifact path. Publication reproduction
is recorded separately in `PUBLICATION_VALIDATION.json`. No app code or map is changed.
