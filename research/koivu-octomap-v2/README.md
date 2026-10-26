# Established OctoMap reuse: more estimated map coverage, still no game route

**The native engine and recorded v2 map completed their bounded component stages. Navigation usability did not pass. Zero game episodes ran.** The fixed phone-map route-selection lattice found no full-footprint candidates and no ordered start/goal pair; a separate diagnostic subsequently checked all 359 eligible cell centres and found zero full-body fits. Twenty unavailable schedule slots are not twenty journeys, and the proposed 100 games were not launched.

## What was actually tested

- **Existing engine, not a new occupancy algorithm:** official OctoMap **v1.10.0**, commit `007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f`; 48 selected official files / 380,478 bytes, with New BSD (3-clause) license and acquisition/blob/hash manifests preserved. [Official source](https://github.com/OctoMap/octomap/tree/007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f).
- **Native build 04:** direct serial g++ 14.2 build, no OpenMP, ROS, GPU, system install or viewer. Build completed in **14.95 wall / 14.76 CPU seconds**, observed peak RSS **167,321,600 bytes**. The 402,736-byte library is omitted from this source-first packet, with its exact hash and build recipe retained.
- **16 native ABI/wrapper fixtures passed.** The final independent adapter review found no concrete blocker for the narrow serial simulation-only ABI, not for physical clearance or iPhone release.
- **21 fusion/import fixtures passed**, including four Float32/native-key association fixtures and 17 classification/coverage cases. These are component fixtures, not rooms, hazards or journeys.
- **One recorded map construction:** all 294 original processed frames and all **215,670,168** positive input pixels, unchanged ROI/floor model and fixed upstream defaults; no FARO input, outcome-driven parameter fitting or fabricated confidence/tracking. Completed in **138.05 wall / 136.16 combined parent-plus-child CPU seconds**, reported peak sampled-or-waited tree RSS **452,489,216 bytes**.

## Recorded map change—and its limit

| Quantity | Frozen v1 endpoint union | Recorded OctoMap v2 |
|---|---:|---:|
| Original raw endpoint voxels retained | 811,806 | 811,806 |
| Supported surface cells | 2,637 | 2,637 |
| Unblocked supported cells | 13 | 372 |
| Cells passing the declared finite clearance samples | 1 | **359** |
| Demonstrated completed game journeys | 0 | **0** |

The native map contains **1,422,787 leaves**, including **699,667 leaves with hit/free conflict history**. All **812,380 raw/native associations** are preserved, including 574 non-centre associations. There were 577 pixels whose Float32 native key differed across a raw-grid boundary; these were recorded rather than silently rounded away.

This is a material change in an **estimated occupancy model**, not calibrated sensor confidence or a proof of free body volume. Known native model-free state must have actual free-scan evidence; missing/unknown states are not promoted. The original raw endpoint layer remains preserved. Floor/support logic was not refitted or widened. There are **222 surface cells with ground/native-free conflict**, including **six of the 359 sampled-clearance cells**. These retain the frozen old floor prior, not independently verified current support. Below-floor contradictions, missing support and finite-sampling limits remain explicit.

The successful map import does not imply a body fits anywhere selected for travel. The unchanged fixed route-selection procedure reported **0 footprint candidates / 0 ordered pairs** and retained 20 `insufficientPhoneMapPairs` slots with null starts/goals. This is **route feasibility evidence only**, not a stopped-game pass or 100 collision-free/failure trials. The separate unchanged-profile diagnostic checked all 359 eligible cell centres with the existing native footprint predicate and found **zero fits**; Detour reported **no supported walkable polygons**. These are phone-map feasibility checks only, not an exhaustive proof about every continuous body centre or an executed motion trial. Its 51 four-neighbour and 35 eight-neighbour cell components are index adjacency, not routes.

## Why a route is still unavailable

Read-only saved-array diagnostics found that **all 359 candidate footprints intersect retained native-occupied geometry**, including the **30–80 cm observed-height band**. Missing floor support touches 319 candidate footprints, retained below-floor contradictions touch 226, and incomplete volume coverage touches two; these classes overlap. Floor fragmentation alone therefore does not explain the failed footprint test. This is attribution within the same estimated map, not independent object labels or measured physical collision truth. No obstacle was removed, floor threshold widened or body margin shrunk to obtain a route.

The complete rectangular 20,445-cell surface grid includes cells outside the observed room/interior and unknown areas. Its 17,808 missing-support cells are **not a measured percentage of real room floor missed by the phone**. The local diagnosis instead reports the declared candidate-footprint neighbourhood: 2,766 cells, of which 1,210 lack the original support criterion. Even these are model-defined counts, not independent semantic floor labels. Height-band and frame-repetition evidence is descriptive only; no reclassification or confidence filter was applied.

## Preserved evidence

- [Final native independent review](workspaces/blind-octomap-reuse-08/INDEPENDENT_ADAPTER_REVIEW.md)
- [Final build receipt](workspaces/blind-octomap-reuse-08/build-04/BUILD_RECEIPT.json) and [16-fixture log](workspaces/blind-octomap-reuse-08/build-04/native-tests.log)
- [Frozen 69-file recorded map cut](workspaces/blind-koivu-game-07/map-v2/FROZEN.json)
- [Fusion independent review](workspaces/blind-koivu-game-07/map-v2/INDEPENDENT_FUSION_SOURCE_REVIEW.md)
- [Recorded v2 counts](workspaces/blind-koivu-game-07/map-v2/run-01/map/MAP_RECEIPT.json)
- [Exact derived map assets](workspaces/blind-koivu-game-07/map-v2/run-01/map/): native leaves, raw/native associations, surface evidence, surface JSON and per-scan records
- [Independent saved-map recount/review](workspaces/blind-koivu-game-07/map-v2/INDEPENDENT_POSTRUN_REVIEW.md) — 21,488 accounting assertions over the same output, not new trials
- [Terminal footprint/route feasibility](workspaces/blind-koivu-game-07/map-v2/FEASIBILITY_TERMINAL.json) — zero games; collision count not measured
- [Saved-array blocker neighbourhoods](workspaces/blind-koivu-game-07/map-v2/BLOCKER_NEIGHBOURHOODS.json) and [local support/height attribution](workspaces/blind-koivu-game-07/map-v2/LOCAL_SUPPORT_DIAGNOSIS.json) — unchanged map, zero games
- [Phone-only route-feasibility receipt](workspaces/blind-koivu-game-07/map-v2/ROUTE_SELECTION_RECEIPT.json)

Builds 01–03 remain separately identified intermediate source/receipt history; they are not relabelled as final build-04 tests. Older proposal/review-pending text remains historical, with final reviews supplied separately. The initial route-launch attempt failed before selection because an optional timing utility was absent; its log is retained, followed by the actual completed selection receipt.

The already-published raw v1 map is a pinned external dependency and is **not duplicated** here. Its exact SHA-256 is `1961eef94bc98f5d89d4986c8b62d7352d0e2046e1dbfa3e6baf767a54e7646d`. The 294 depth PNGs, full source archive and compiled native libraries also remain outside Git payloads. See `OMITTED_DEPENDENCIES.json` for exact identities and reasons.

No original source, frozen result or upstream license was modified. Public receipt/doc path normalization has an exact original/public hash map; historical embedded hashes retain their original referents. This evidence snapshot does not claim a complete clean-machine reproduction, real-time iPhone feasibility, physical obstacle recall, continuous clearance or successful navigation. Phone-plus-belt/additional sensors remain the intended broader architecture. No build, fixture, map or game was rerun during packaging.
