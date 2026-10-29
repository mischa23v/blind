# Native signed15 Coffee diagnostic: bounded attempt stopped, useful partial evidence retained

The native wrapper compiled, its two ELF dependency inspections passed, and **all 67 controls passed**. The twenty-path comparison did **not** finish: the unchanged aggregate guard stopped it at the 120-second CPU limit. No rerun, limit increase, shortened schedule or native execution was performed by this evidence review.

## Outcome and coverage

- Admitted source: `05e68926f69fa4dfd2566fb50c9e22453cd4e568`.
- Aggregate: **failed / CPU breach**, 120.075956 CPU seconds, 120.162540 wall seconds, 208,371,712 bytes peak observed aggregate RSS.
- Compile, both readelf stages and controls exited 0. Comparison exited -9. Every process group was confirmed retired. All 65 before/after input hashes agree; all 28 final payload-file hashes still match the guard inventory.
- No worker `RECEIPT.json` was produced. The retained gzip is unfinished: no terminal gzip EOF/trailer/CRC validation. Bounded standard-library recovery yields **11,188 newline-complete, valid JSON records**, no incomplete JSON tail, and 34,758,259 expanded bytes. This is a recovered prefix, not an intact archive or completed aggregate.
- **16 complete A raw-contact schedules**, **15 complete B label-only schedules**, and **15 reconstructed terminal C contact-stop sequences** are usable as partial diagnostic evidence. They are not successful journeys. No C schedule reached its end.
- **7→8:** A completed 272 events; B retained events 0–235 (236/272); C never started. **8→0, 8→1, 8→6, 8→7:** never started. These five are unknown due to resource exhaustion, not route failures.

A is the unchanged raw body/margin check. B applies ground labels without changing route geometry and checks A/B raw-count equality. C follows the finite nine-probe ground model and stops on either body or separate margin contact. Body remains 0.45 × 0.30 × 1.60 m, with a separate 0.15 m horizontal margin.

## What changed in ground classification

For the same first sixteen paths, original vertex-ID/5-degree ground setup succeeded on 4/16; exact-XYZ/5-degree setup succeeded on 12/16; native signed15/exact-XYZ setup succeeded on **16/16**. Thus the recorded initial seed failures were removed for this observed subset. This establishes a computational change, not semantic-floor correctness or support safety. The four unstarted start-8 cases remain unmeasured in this attempt.

- The earlier exact-XYZ change repaired the initial disconnected components for starts 1 and 7. Native signed15 additionally admits the previously rejected start-0 seed; saved face 27586 belongs to every observed start-0 ground component.
- The already-passed native control explicitly verifies that original blocker faces 27586, 28034 and 28076 remain rejected by original 5-degree policy but are admitted by the native fixed15 fixture. Saved native ground IDs include faces 28034 and 28076 for all four start-1 paths.
- Start-1 routes progressed farther before stopping: **1→0 event 219 instead of prior support failure at event 4; 1→6 event 117 instead of 4; 1→7 and 1→8 event 53 instead of 3**. The earlier failures were not silently relabelled as journeys.
- Start-6 remains an initial body contact: 112 non-ground body triangles, with margin counts reduced from 1,165 to 1,155. Start-7 remains an initial margin-only contact: 195 non-ground margin triangles. Ground relabelling did not remove these obstacles.

## Why the fifteen observed C sequences stopped

Events are zero-based. Heights below are whole first-witness triangle spans relative to the swept foot-height range, not measured real-world obstacles or exact contact-point heights. First witness means locator order, not earliest contact. Every listed witness is **absent from the saved accepted ground component**.

| Paths | C terminal event | Recorded stop | First witness face(s) and relative height |
|---|---:|---|---|
| 0→1, 0→6, 0→7, 0→8 | 10 | Margin only; two half-segments have 1 then 2 non-ground contacts | 27557: **+0.27 to +1.47 cm** |
| 1→0 | 219 | Margin only; 1 then 3 contacts | 27577: **about 0 to +2.84 cm** |
| 1→6 | 117 | Margin only; second half has 2 contacts | 12275: **+0.49 to +1.96 cm** |
| 1→7, 1→8 | 53 | Margin only; 25 then 45 contacts | First half 235: **about 0 to +0.48 cm**; second half 28353: **−0.04 to +3.17 cm** |
| 6→0, 6→1, 6→7, 6→8 | 0 | Body 112 / margin 1,155 contacts | Body 29484: **+88.56 to +89.91 cm**; margin 29512: **+93.55 to +104.43 cm** |
| 7→0, 7→1, 7→6 | 0 | Margin only; 195 contacts | 33098: **+6.47 to +12.49 cm** |

**Eight near-foot cases remain geometry/classification questions**, not established furniture collisions. Their first witnesses have Float64 geometric slopes approximately 16.89°, 31.83°, 21.60°, 25.70° and 74.92°; these exceed 15° and are consistent with rejection by signed15 initial marking. This is source-coordinate diagnosis, **not a new native-classifier execution**. A low triangle could be reconstruction noise, a small real object or a real surface change; height alone cannot exempt it. The 3 cm grouping is descriptive, not a new collision threshold.

The four start-6 cases contain represented geometry roughly 0.9–1.0 m above the feet: they are not merely a millimetre-scale floor-label issue. The three start-7 cases involve represented geometry 6–12 cm above the feet. Neither height identifies a chair, table, wall, foot or other semantic object; no exact collision volume or physical safety conclusion follows from the conservative swept enclosure.

## Source-only efficiency proposal

**Reuse the completed exact-XYZ A evidence rather than rerun unchanged A geometry.** Its intact, guard-verified log contains all 6,874 A events. All **5,348 native A records retained here match those prior records exactly**, excluding only the two top-level policy-label fields (`groundAdjacencyMode`, `triangleEligibilityPolicy`). The source diff confirms A’s scorer, mesh, body/margin, transforms, schedule and geometry are unchanged.

A separately reviewed, admitted **cached-A / fresh-B+C diagnostic** could pin the prior guard and compressed log, verify complete gzip integrity and exactly one expected A record per path/event, bind identical source/mesh/schedule/runtime evidence, and keep the same A/B raw-count comparison against the cached counts. Record A as reused prior evidence, not freshly executed native evidence; distinguish fresh computation counters from cached records. Keep all 67 controls, all twenty paths, all B/C rules, unchanged aggregate limits and fail-closed dependency/retirement checks. Any new implementation requires its own source review/admission; none is prepared or run here.

Do not cache B/C across ground policies, reconstruct missing face-ID sets from truncated first-16 witnesses, waive first-contact stops, loosen slope/body/margin, or claim this aborted attempt completed. A separate new route/pair experiment cannot complete this original twenty-path attempt.

## Evidence identities

| Evidence | SHA256 |
|---|---|
| Native guard receipt | `e7ee53ceba593dceedaf68695606995c3547313271eb8f27aa12d98b045ab09e` |
| Native retained partial contact gzip | `ca81ea3fb60f67998d872ade2ca05df968d3b8d2b4e80f77672544d60a8f0c6e` |
| Native controls log | `6505af148e238daf79e149d517dc10030ffe32f68a0aa3cda5701145825c0a03` |
| Built native wrapper | `5c1313ec27fe701e6d2b7f83a53eaf9c4c4013d2532bd19247de54a9e6e4e561` |
| Native admitted run manifest | `b2356f81f9ec41c2501ea47853b8dcb3201b2f3a0f27dbf10216d5e1e8de67df` |
| Prior complete exact-XYZ guard receipt | `8b2d029a46024309bfb342acdd54c784a23801aa41a6b6fbb05c9653ea30471c` |
| Prior complete exact-XYZ contact gzip | `a0493b7dc367b4fa34da57604386df9b3524d660260fd4de6cefd1310d10951a` |

`PARTIAL_EVIDENCE.json` records all twenty paths and recovery validation. `CONTACT_WITNESSES.json` records each completed path’s source face coordinates, source-coordinate slope context, saved ground membership, relative height span and prior-policy comparison. The two `*_stdlib.py` review scripts only read retained output/source data and write derivative review files; they never load a native classifier/scorer or mutate the original attempt. File hashes are in `SHA256SUMS`.

Missing real-data tabletop geometry, the user’s rejected corner route, exact-XYZ coincident-sheet ambiguity, incomplete footprint support and supervised device validation remain unresolved. No physical guidance, safety, full journey or navigation-accuracy claim is supported.
