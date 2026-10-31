# Released planner + corrected occupancy: tested adapter, negative room result, diagnosed attrition

2026-10-28. This checkpoint contains completed evidence, not a navigation-readiness claim.

1. [Initial native smoke](README.md):43 pinned released Recast/Detour files verified; current wrapper built;12 unchanged component fixtures passed.
2. [Reviewed occupancy adapter v3](occupancy-prototype-v3/README.md):21 synthetic fixtures passed. An independent reviewer repeated all21 and verified source/manifests. Requested versus projected endpoints are now explicitly separated; original ambiguous v1 and failed v2 fixture remain preserved. A1cm support gap can be bridged by4cm Recast raster, so no floor-support authority follows from a corridor.
3. [Frozen real recorded ledger](recorded-ledger-proposal-v1/README.md):20 fixed source-only pair queries completed with **0 complete projected corridors,18 association failures and2partial corridors**. Actual occupancy/path figures are included. No endpoints/profile were tuned after results; no movement occurred.
4. [Native stage attribution](span-diagnostic-v2/README.md):26,748 provisional spans fall to24,952 after ledge filtering,13,652 after headroom and737 after radius erosion. Original20query outputs remain identical. A0/A1 belong to the same4,404-span pre-erosion component but end disconnected after erosion. The failure is not proof that the physical aisle is impassable; local false-obstacle versus legitimate-furniture attribution remains ongoing separately.

## Evidence boundaries

The fixed diagnostic profile is synthetic: radius24cm, height1.2m,4cm×2cm raster, zero climb. It is not a measured user/phone-to-body profile. Ground semantics are only support hypotheses; observed free and unknown stay distinct. Current leaf probability overrides historical semantic labels, but the ledger does not establish per-leaf temporal freshness. Native height quantization is61cells≈1.22m; radius6cells≈24cm is applied once.

No requested-to-projected connector, swept body/head collision clearance, full-footprint support, live pose or physical movement is admitted. FARO is not mapper/planner input. A future independent reference audit may explain apparent barriers but must not carve or fit a favorable route. Named A→B/table/door/return journeys and the original100movement schedule are not replaced by these20structural queries.

## Reproduction and publication

`CHECKPOINT_PUBLICATION_MANIFEST.json` is the combined exact allowlist; its SHA256 is adjacent. It includes source, commands, freezes, exact outcomes, resource receipts, numeric stage analysis and derived figures. Generated native libraries/objects, duplicate upstream source, raw photos/depth/reference inputs and large binary map/span payloads are excluded. Their hashes remain provenance; this checkpoint alone is not a standalone dataset/runtime distribution. Use the pinned original sources and separately retained corrected ledger, in fresh output directories; one-shot runners deliberately refuse overwrite.

The original smoke, v1/v2/v3 fixtures, negative recorded result and failed diagnostic harness attempts are retained separately. Later aisle investigation is outside this frozen checkpoint, not an unreported rewrite of its outcomes.
