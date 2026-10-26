# Matching-height and reference-coverage audit — fixed recorded-pass protocol

## Purpose and fixed scope

Audit the reported Koivu reference-scoring conclusions at exact commit
`b9a652bbe0203f11caade0bf136e8df22badbbea`, without changing any phone map,
floor, body, margin, threshold or route. No coffee_room download or duplication.
FARO stays evaluator-only; surface agreement is not physical ground truth.
No game episodes, live confidence or physical movement authority are produced.

## Artifact association gate

The latest statistical labels require the exact saved `pipeline_out.npz`, its
SHA256, matching source/receipt and saved `lo`, `R`, `t`. The current committed
`derived/policyD1_columns.npz` is an earlier source cut: it has 10,669 walk columns,
whereas the latest pipeline receipt has 10,695. It also lacks statistical state.
The new pipeline uses half-pixel rays and refits the level frame. Never substitute
the old map for the latest labels or claim it reproduces 44/1,035.

If the exact latest artifact is supplied, verify all published mask counts and
dimensions before touching FARO. If absent, the latest-label score remains
blocked; an explicitly separate old-D1 check can use its exact committed mask
and original supplied level frame. Native D1 reproduction is prepared but not
needed merely to reconstruct an already available old mask.

## Fixed height measurements

In the exact label frame, report separate half-open bands [0.010,0.015),
[0.015,0.025), [0.025,0.075), [0.075,0.300), [0.300,1.750), and
[1.750,1.800) nominal phone metres. Report original thresholds alongside them,
never silently replace the original table. Include union counts across low and
body bands, because the original `refLow25` excludes all body-band matches.
Report exact boundary conventions; native box contacts are closed-boundary and
must carry boundary-overlap labels rather than pretending to be half-open bins.

For every label set, preserve original any-vertex coverage, floor-band vertex
evidence, band-specific positive geometry, no-reference vertices and uncertain
coverage separately. Any vertex at any height is not full-column coverage.
No vertex or triangle contact is not a verified free-space observation; the
cleaned/completed reference has no measured-support mask. Do not call unmatched
phone detections false physical obstacles or remove them from a map.

## Bounded independent triangle check

Use installed upstream VTK and the existing tested ReferenceContainer's
triangle/hexahedron intersection plus contained-vertex logic, not a custom
raycaster. Refactor a separate generic box helper only if needed to support
5–10 mm bands; preserve the old game scorer and verify the helper against its
unchanged full-container fixtures. Keep the original reference mesh unmodified;
transform query boxes through exact saved level-to-phone and author phone-to-FARO
similarity. Positive uniform scale and inverse association must be verified.

Predeclare deterministic columns from the fixed label masks before querying
FARO: all statistical-object and isolated-speck columns if at most 2,048 total;
otherwise fixed seeded sample of 2,048, with inclusion probabilities and no
population-rate claim from unweighted strata. Add a fixed seeded sample of 256
walk/stat-clear columns, selected from phone labels only. No replacement of
columns after reference outcomes. Each selected column receives all six band
boxes and fixed centre/four-quarter floor probes. Floor-probe failure and height
spread are uncertainty outcomes, not obstacle truth or clearance.

Final authorized resource cap (the prior unchanged full-reference query peaked at 2,144,088,064 bytes, nearly 2 GiB, so a 2 GiB cap would have no useful headroom): one serial recorded pass, 1,800 CPU seconds, 2,700 wall
seconds, 3 GiB sampled/waited RSS, 64 MiB output and 768 MiB free reserve. The
earlier prepared 600/900-second, 32 MiB proposal was explicitly expanded by the
maintainer before source freeze or recorded execution, not after seeing results. If the
full mesh locator or candidate cap fails, preserve failure and partial counts;
do not decimate the reference or drop difficult columns. No concurrent TSDF or
native fusion run. Exact source/data/label pins and a final input-specific plan
must be frozen before this recorded pass.

## Resolved exact-input gate and fixed selection

The user supplied the exact latest artifact at commit
`c1231d4042068176e09a33c3020647c2c0e292ba`. The 6,331,302-byte
`koivu_v1_pipeline_out.npz` matches SHA256
`dfd9a7afa958fc8012e43b9fe86f72dafb97e88d4198640080c110c14941b55e`
and Git blob `7b964f7f879b30385d264c6a09e360b8dd73a11b`. Matching receipt is
byte-identical to the pinned scoring receipt. Later pipeline-v2 and coffee_room
arrays are not inputs. Saved level transform, 241×250 grid, all phone-label
counts and all original saved reference-score counts have been verified.

Phone-only selection is now frozen at seed 20261026: all 1,157 unique columns
from the 1,035 statistical-object and 129 isolated-speck sets, plus 256 sampled
stat-clear columns, total 1,413. Exact indices are `SELECTED_COLUMNS.npz`.
No FARO values participated in selection. The complete Float64 original vertex
stream is used for global band-positive counts and must reproduce the original
saved reference columns before triangle queries proceed. Only this fixed
1,413-column subset receives native triangle checks; no full-population
triangle safety percentage will be inferred from it.

The helper frame is [levelX, height, -levelY], +Y up. Query transform is author
phone-to-FARO composed with the exact inverse saved R/t; no OctoMap +2.5 cm
height offset belongs in reference box coordinates. All six bands and five
centre/quadrant first-hit probes (+15 to −25 cm) are queried for every selected
column. Each box retains the existing 200,000 candidate-triangle failure cap.
Original mesh is never decimated or transformed. VTK PLY reader Float32 output
precision is reported; original Float64 vertex-to-Float32 rounding is measured.
No implicit 2 mm game floor exclusion applies to these explicit ≥1 cm boxes.
This audit covers 10–1800 mm only; 2–10 mm remains untested and must not be
called full near-foot clearance. Original vertex scoring preserves its exact
+2.5 cm then −2.5 cm floating-point round-trip at height boundaries.

Near-floor geometry may reflect floor registration or surface-height variation,
not a physical obstacle. Neither a negative box query nor all five floor hits
establishes measured free volume or support. The reference was cleaned/completed,
was captured at a different time, and has no measured-support mask. No phone
obstacle is removed on the basis of the audit.

Six scoring-contract and 20 band-box authored fixtures pass; label/transform
fixtures and independent whole-driver review are the final release gates.
No recorded reference pass has run. Earlier maps and selector failures remain
preserved.
