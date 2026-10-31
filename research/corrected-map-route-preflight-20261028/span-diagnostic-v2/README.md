# Read-only stage instrumentation: where candidate support disappears

This instrumentation changes no input, planner/profile parameter, floor label, obstacle or native filter. It captures existing merged spans after ledge/headroom filtering and compact areas after erosion/region assignment. The unchanged21 synthetic fixtures pass. All20 instrumented recorded query outputs equal the original frozen outputs exactly after normalizing tuple/list serialization.

| Stage | Surviving provisional spans |
|---|---:|
| Occupied floor/obstacle priority merge |26,748|
| Released ledge filter |24,952|
| Released low-headroom filter |13,652|
| Compact heightfield |13,652|
| Released radius erosion |737|
| Distance field / regions |737|
| Resulting navmesh |126polygons,254vertices|

The direct dominant attrition is headroom rejection followed by erosion of the remaining fragmented support, not ledge rejection alone. A read-only translation of the released ledge predicate reproduced all26,748 decisions with zero disagreements. Config's CFloat arithmetic yields61height cells (~1.22m),0climb cells and6radius cells (~0.24m). There is no second body/margin inflation.

[Saved-span analysis](../span-diagnostic-v1/SAVED_SPAN_CONNECTIVITY_DIAGNOSIS.json) finds464 pre-erosion connectivity components,262singletons; the largest have4,404 and4,058spans. Both A0/A1 local windows touch the same4,404-span component before erosion, yet their frozen post-erosion corridors are disconnected. Among missing directional links after headroom filtering,5,634 point to a headroom-rejected neighbor,1,784 to ledge-rejected ground and1,748 to obstacle-only/no-ground-hypothesis columns. No remaining missing link is solely a height jump beyond zero climb; many such edges were already removed by ledge filtering.

Of11,300 low-headroom rejections,9,952 have an obstacle-priority next span and1,348 another ground-hypothesis span.2,658 have at most8cm of modeled vertical clearance, including447 ground-on-ground cases. Median modeled clearance is34cm. Some may be real under-furniture obstacles, some may be noisy near-floor layering. These categories alone do not identify real object semantics or prove phantom obstacles. Existing raw observations/reference-local scoring remain necessary before map correction. No whole-floor flattening,2mm floor rule, artificial corridor clearing or margin shrink was applied.

Anchor-specific recorded cause: A0/A1 original columns survive headroom but are eroded; A2's provisional floor is removed by ledge filtering; A3's low merged span already has obstacle priority; A4's next occupied span begins34cm above its provisional floor, causing headroom rejection. The exact span layers and raw voxel ROI counts are in `STAGE_DIAGNOSIS.json`. ROI counts use an enclosing AABB, not independently certified swept-cylinder collision checks. Missing support/unknown volume is not called free.

Instrumentation build/tests:5.706s wall,5.456CPU s,71,122,944B sampled aggregate RSS under1CPU/1GiB/300s. Recorded diagnosis:1.106s elapsed,216,449,024B peak process RSS under1CPU/1GiB/60CPU/60wall. The earlier v1 instrumentation preserves two harness failures: a syntax error before execution, then a tuple-versus-JSON-list equality error after its first query. Correcting those reporting errors changed no geometry/configuration. The original recorded20-pair result was never replaced.

`MERGED_SPANS.npy` is locally retained derived geometry with its SHA256 in the report, but omitted from text publication. Reproduction needs the separately preserved original corrected ledger and exact pinned sources. No physical movement, support certification or live localization is established.
