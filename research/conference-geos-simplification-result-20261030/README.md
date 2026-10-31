# Conference fixed-tolerance simplification — actual paired result

**The fixed 0.025 m GEOS diagnostic reduced authored zigzag/turn scheduling across all seven retained objectives. This is not a clearance improvement or physical acceptance.** Every candidate remains provisional with independent coverage unknown; full-body comparison is separate.

## All seven pairs retained

Values are **unchanged centered baseline → fixed-tolerance candidate**. Length is the full-XYZ polyline including both requested connectors. Turn is cumulative absolute authored yaw, not observed human movement. Events use the unchanged stop/turn/translate scheduler (at most 1° per turn increment and 25 mm per translation increment).

| Objective | Length (m) | Authored turn (°) | Total events |
| --- | ---: | ---: | ---: |
| Table 92 → 120 | 3.403184 → 3.280008 | 1,663.646 → 648.011 | 1,844 → 796 |
| Table 120 → 200 | 5.217547 → 5.113642 | 1,754.357 → 871.083 | 2,052 → 1,101 |
| Table 200 → 220 | 2.480559 → 2.378718 | 1,393.642 → 540.840 | 1,530 → 653 |
| Table 220 → 20 | 4.114779 → 4.049420 | 1,340.006 → 710.005 | 1,555 → 889 |
| Table 20 → 92 | 7.130919 → 7.008670 | 2,463.288 → 1,428.726 | 2,863 → 1,740 |
| VARPU 130 → 160 | 5.542600 → 5.455506 | 1,615.866 → 907.098 | 1,923 → 1,145 |
| VARPU 160 → 130 | 5.542600 → 5.455506 | 1,615.866 → 907.098 | 1,937 → 1,146 |
| **Sum, 7/7 in each arm** | **33.432190 → 32.741471** | **11,846.672 → 6,012.861** | **13,704 → 7,470** |

- Length decreased **0.690719 m / 2.07%**; cumulative authored turn decreased **49.24%**; total events decreased **45.49%**.
- Turn increments decreased **12,049 → 6,070**; total chain vertices **594 → 156**. All seven rows are included, with no unavailable candidate or easier-arm substitution.
- The two VARPU candidate chains are exactly the same geometry reversed. The unchanged scheduler retains its directional event-count differences; these are not two independent scenes or evidence that one physical direction is easier.

## What was actually checked

**7/7 candidates and 7/7 baselines pass the saved bidirectional native-corridor segment checks:** 1,472 calls = 2 × (587 original + 149 candidate segments), including requested connectors. All seven candidates have a full reconstructed XZ simple-line result and are eligible only for a **separately admitted full-body diagnostic**.

The saved-result review independently verified all **42 input pins**, committed source identity, before/after pin receipts, final payload digests, seven exact original baselines/endpoints, strictly ordered original-XYZ subsequences, unchanged requested connectors and first/last graph edges, original length caps, and regenerated schedule counts. An exact-rational intersection audit of the saved candidate XZ polylines also agrees with all seven saved full-line GEOS simplicity results. It checks topology only, not obstacles or clearance.

No tolerance tuning, retry, route search, geometry repair, moved endpoint, invented height, dropped objective or default activation was introduced. The review used only saved bytes and standard-library arithmetic; it made **zero GEOS/native calls**.

## Execution and evidence

- Source commit: `dad87dcc75d86e3b170201e778ccef69c76ccca4`.
- Attempt: `conference-geos-simplification-attempt-001`; **completed-zero-exit**. All **17 authored controls passed**, comparison exit 0, both process groups retired. Controls include explicit corridor stubs; they are distinct from the actual saved native segment results.
- Observed aggregate resources: **1.788577 CPU s / 1.804427 wall s / 65,929,216 bytes peak RSS**. Caps remained 120 CPU s / 180 wall s / 1 GiB observed RSS / 16 MiB output; observed RSS is not a hard cgroup limit.
- Manifest SHA-256: `d44748a362013322f5ad11ad8f30995b29d7e7021a294ce639f63b0c74c18caf`.
- Saved `PAIRS.json` SHA-256: `3b47960077f817b627b2868748204174020378832b50c3459c8bcdf35d73be47`.
- Terminal receipt SHA-256: `9cd5e45a6b435f7d79a94ef56938d21b8da6739a115ed9cf9fdc942f0f7ae662`.
- [Machine-readable recount](RESULT_REVIEW.json) and [stdlib-only review source](review_result.py). Reproduce locally from repository root: `timeout 20s python3 -B research/conference-geos-simplification-result-20261030/review_result.py`.

## Acceptance boundary unchanged

GEOS simplicity and native corridor success do **not** establish complete independent 2D obstacle/coverage evidence, rectangular-body or margin clearance, full-footprint support, fresh sensing, calibrated camera/body alignment, or safe movement. Historical registration remains an estimated comparator. The declared body remains 0.45 × 0.30 × 1.60 m with a separate 0.15 m horizontal margin; this attempt did not run the full-body comparison. No contact-event percentage is presented as a safety improvement. `accepted=false`, `physicalAuthority=false`, and `movementExecuted=false` throughout.

This packet contains text, reviewed aggregate metrics and audit source only—not a mesh, archive, raw route/pose array or new gallery. Original public dataset provenance remains in the [conference inventory](../conference-replay-input-inventory-20261029/); source preparation and independent review remain in the [frozen proposal packet](../conference-geos-simplification-proposal-20261030/).
