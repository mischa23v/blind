# Supplied pose experiments and paired fixed routes — stages 17 and 18

**Completed review and fixed-query comparison only. No movement, no adopted map,
no validated full loop.** Later stages, unstarted stage 15 and new optimization
work are not included. A later joint-registration/source note can be published as
a separately identified addendum; it is not implied to be present here.

## Stage 17: what the saved evidence supports

External checkpoint: `b0be8628b159e0fc0446a7af8c57c13c99553a77` in
[mischa23v/blind](https://github.com/mischa23v/blind/tree/b0be8628b159e0fc0446a7af8c57c13c99553a77/research/mapping-audit-opus-20261026/pose-consistency).
The packet retains 24 initial source/report/pose/receipt files, six additional
source/report files, and all four acquired derived arrays: **12,150,161 bytes**.
All 34 external SHA-256, Git blob identities and byte lengths were reverified.
Rejected pose exports, rejected experiment logs and validation failures remain.
The external report's strong causal/safety statements are preserved as evidence,
not automatically endorsed; read `REVIEW.md` and `INDEPENDENT_POSE_REVIEW.md`.

- Koivu: exactly **9 of 294** supplied pose matrices changed, indices
  23, 24, 61, 62, 63, 119, 132, 229, 230. All 285 others and all non-pose frame
  fields match the original export. Relative corrections are rigid/no-scale
  to numerical precision. This is an identity/transform-contract check, not
  proof that the corrections represent true camera poses.
- Rotating about a floor centroid moves camera centres horizontally by
  **1.90–7.15 cm** despite no separately estimated horizontal translation.
- All **153** saved Koivu/Coffee accept/reject decisions reconcile with the
  rounded nearest-neighbour rule (at least 10% and 2 mm improvement), without
  rounding ambiguity. These scores select corrections: they are validation,
  not an untouched final test. Coffee's original raw pose export was not
  acquired; Coffee identity/preservation claims are limited accordingly.
- New Koivu source has **251 fits / 77 flagged / 43 no-fit**, using Float32
  pipeline points and Euclidean range. Earlier stage16 had 252/78/42 under
  Float64 projection and axial range. Do not silently mix those conventions.
- The target pool is unflagged, not exclusively fitted-consistent: it includes
  no-fit frames before temporal/sample exclusions. Pose drift is plausible,
  not uniquely established against depth/export/calibration/selection effects.

### Saved split-0.7 mask recount

| Candidate | Raw walk cells | Reference-covered walk cells | Edge-miss proxy | Open-floor-miss proxy | Reference-walk cells blocked |
|---|---:|---:|---:|---:|---:|
| Koivu original | 11,559 | 11,501 | 359 | 4 | 1,287 |
| Koivu corrected | 11,827 | 11,766 | 363 | 4 | 1,030 |
| Coffee corrected | 6,790 | 6,779 | 154 | 0 | 1,220 |

These reproduce supplied vertex-column/EDT predicates, **not physical hazard
miss rates, continuous triangle/body clearance, support or dynamic safety**.
Koivu's four open-miss indices remain, with no added/removed indices. Independently
refitted level frames move their nominal physical centres about 1.05–1.07 mm.
Coffee's original arrays were not acquired for the paired recount. Low geometry
below the proxy threshold and missing coverage are not proved clear.

## Stage 18: same objectives, old versus corrected model

The frozen batch made **36 native queries**: three unchanged numeric profiles,
two supplied maps, six fixed objectives each (four loop legs plus north/south
approaches). Profiles are 0.45 × 0.30 × 1.60 m, that same body plus 0.05 m margin,
and abstract 0.28 × 0.30 × 1.60 m. No participant identity is represented.

Every original objective is transported through original phone coordinates into
the new level frame, retaining Y; there is no convenient new start/goal, actor
snap, reference-driven selector or new search algorithm. The supplied archive
contains evaluator fields, but the model reads only allowlisted phone fields and
R/t/lo/res metadata. Native Recast/Detour and original sampled rectangle/turn rules
are reused. No reference geometry or proxy enters route selection.

**All 18 paired accept/reject outcomes are unchanged.** Across both maps:
- All six southern approach queries are accepted by the candidate model.
- The abstract 28 cm south-to-west leg is accepted on both maps.
- All other 28 fixed queries are rejected; **zero full fixed loops** are accepted.

The six complete old/new artifacts preserve partial routes, native reasons,
endpoint projections, rectangle/turn checks and unresolved flags. Independent
postrun confirms all 36 outcomes, all 12 historical old-loop native results, and
phone-coordinate/round-trip residuals no greater than 8.89e-16 m. Requested new
Y ranges from −0.320 to +2.219 mm; projected-minus-requested Y is recorded
(22.781–25.320 mm), not silently discarded.

Every accepted southern path has low-unresolved flags at all 87 sampled poses.
The abstract south-to-west legs have such flags at 271/281 old and 264/274 new
sampled poses. These are planned-route samples, **not executed actor exposure**.
The available split artifact cannot reconstruct all far-only/dip-conflict history.

The batch completed in **2.214 s wall / 2.119 s child CPU**, observed/waited peak
RSS 73,052,160 B. Eight authored adapter fixtures preceded it. The saved-array
postrun used no new native route calls. Fixture/query counts are not movement
trials. **No movement episode or three-lap run was launched.**

This is failure of the frozen compass/objective construction, not proof that no
loop exists anywhere. `FLEXIBLE_SEARCH_PROPOSAL_ONLY.md` is retained explicitly as
**unexecuted proposal**, not a replacement result or implemented search.

## Exact bytes and reproduction limits

All original executed sources and evidence are preserved under their stage
names. `EXTERNAL_SOURCE_VERIFICATION.json` records the pinned external identities.
`NORMALIZATION_MAP.json` records original/public hashes and any public-only path
or coordination normalization; historical hashes continue to identify originals.
`DEPENDENCIES.json` lists exact unchanged native/source/objective prerequisites
and their prior-publication paths where available. Existing source cuts, raw
capture and native binaries are not duplicated. Original input-array identities
and their pinned repository asset paths are retained. No clean-machine rerun is
claimed: source layout, prior inputs, verified native builds and dependency
versions still must be provisioned. Repository-owned source is attributed without
inventing a new license grant; external runtime code is not redistributed.

The four NPZ files are **derived masks/metadata**, not raw camera images. Some
contain saved evaluator fields. Their inclusion is for review/recount and is not
authority to expose those fields to the candidate selector. Corrected/rejected
pose exports are historical experimental data, not adopted tracking truth.

Excluded: raw RGB/depth, FARO mesh/cloud, installed packages, compiled libraries,
caches, unstarted movement work, private participant/family details and screenshots.
Packaging performs byte/hash/schema checks only: no source import, array decoding,
geometry, fitting, fusion, routing, movement or scientific re-evaluation.
