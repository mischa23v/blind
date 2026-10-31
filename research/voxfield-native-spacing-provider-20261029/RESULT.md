# N3 native-spacing provider: bounded synthetic + three-frame result

**PASS for provider contracts, not reconstruction accuracy.** N3 preserves every admitted point/order/coordinate and changes normal support only. Synthetic angular errors improve in the declared examples; actual recorded normal accuracy is unknown.

## Recorded first-three training distribution
All1,296,420 admitted points retained exactly against unchangedN2.

| Frame | Valid N2 → N3 | Exact optical+Z N2 → N3 |
|---|---:|---:|
|00001|427946 →413192|268118 →176|
|00002|422413 →405100|270626 →32|
|00003|425278 →406900|268486 →196|
|Total|1275637 →1225192|807230 →404|

The axis fraction drops63.2805%→0.0330% of valid normals, but that is **not an error rate or confidence measure**. Unavailable normals increase20783→71228 (50445 fewer valid). N3 reasons: boundary16040, missing13000, discontinuity42188; nonfinite/degenerate0. All invalid normals remain zero, all points remain submitted candidates. No mapper was called.

Inherited recorded log fields need precise interpretation: `equal_depth_triplets` still counts offset1(center,right,down) equal depths conditional on each arm's valid normals, NOT N3's4pixel endpoint equality. `interior_positions=731841` is the unchanged one-pixel raster interior, NOT N3's eligible support count. Actual validity and boundary counts are authoritative; these field labels are not overwritten after execution.

## Synthetic comparisons on identical common support
Every row below has3600 common-valid interior samples on .4X+.3Y+Z=intercept, actual firstK focal length; mm quantization and4×repetition. Block-startphase1 corresponds to observed transition-startphase0, but native centers/exporter are not recovered.

| Intercept | N2 mean angle | N3 mean angle |
|---|---:|---:|
|.3m|32.3335°|21.5730°|
|1m|31.5849°|5.0901°|
|2m|31.7451°|1.0246°|
|3m|31.7851°|1.8621°|

All predeclared block-start phases0/1/3 and ideal/mm-only controls are retained in RESULT.json/raw fixture ledger, not selected by best score. The .3m residual is large: wider spacing does not remove millimetre quantization uncertainty. Angle diagnostics renormalize float normals only for reporting; previous diagnostic used raw-float dot and a different tiny ideal-angle floor. Provider outputs are untouched.

## Positive and negative support contracts
Exact point/order/zero/far retention and finite/zero normal semantics passed. Last4rows/columns become unavailable; width/height1..4 tested. Missing/far intermediate offsets1..4 on each axial path reject support; exact±5% allowed and beyond5% rejected, missing precedence retained.

Explicit limitations passed as expected, not fixed: 2cm/4cm steps at2m satisfy the5% gate and can be bridged. A diagonal interior hole outside the two checked axial paths does not invalidate a normal. Synthetic head/overhang/drop labels describe depth-support arrangements, not physical mesh/navigation recall. No smoothing, unknown filling, floor normalization or classifier was introduced.

## Receipt and scope
Single admitted d62c98fc2bd97cf203d3ef7a577638e6f90d0623dacc8ad02f3cb99f75430789/14pin run: exit0,3.976169732s wall,3.924850CPU,257712128B sampled summedRSS (under256MiB=268435456B). All14pins unchanged.213JSON fixture rows including finalpass. No native/mesh/full265/GT/heldout/scorer execution. Prior mixed full265 results remain unchanged. Any next mapping comparison requires separate source freeze, identical kernel/config and root admission.
