# Conference: seven raw sweeps completed; original aggregate failed afterward

**All seven route sweeps completed in the worker, but the original aggregate remains
FAILED.** After the three child commands had exited zero, the supervisor raised
`ModuleNotFoundError: No module named 'contracts'` in its terminal validation
import. The root invocation used isolated Python (`-I`); the sibling-module
import was not available on that isolated search path. This is a reporting/
validation-boundary failure, not a reason to erase the failure, rerun the
geometry or call the original aggregate successful.

The saved all-hit records nevertheless allow an independent, exact recount.
**Five of seven authored routes have nominal-body enclosure overlaps; all seven
have horizontal-margin enclosure overlaps.** These are mesh/model diagnostics,
not observed bodily impacts, completed room journeys or safety certification.

## Full saved-event recount

| Authored centered route | Events | Body contact-bearing events / overlap occurrences | Margin contact-bearing events / overlap occurrences |
|---|---:|---:|---:|
| table_92_to_120 | 1,844 | 0 / 0 | 855 / 11,336 |
| table_120_to_200 | 2,052 | 2 / 30 | 652 / 13,383 |
| table_200_to_220 | 1,530 | 2 / 30 | 101 / 279 |
| table_220_to_20 | 1,555 | 0 / 0 | 119 / 335 |
| table_20_to_92 | 2,863 | 265 / 2,094 | 1,590 / 34,352 |
| varpu_130_to_160 | 1,923 | 374 / 3,021 | 979 / 20,255 |
| varpu_160_to_130 | 1,937 | 376 / 3,046 | 988 / 20,421 |
| **Total** | **13,704** | **1,019 / 8,221** | **5,284 / 100,361** |

“Occurrence” is a triangle/query overlap, repeated across events. It is not a
unique obstacle, object or physical impact. The margin volume includes the
nominal body; the two columns cannot be added as independent impacts. Swept
enclosures conservatively contain the authored motion and can overcount exact
body intersections. Every authored event was scanned even after contact; no
actor traveled these routes or stopped/arrived according to this raw scan.

All **13,704** logged increments exactly match the frozen schedules, including
all original XYZ points, both requested connectors and authored turns. No route
or event was removed. Query totals independently agree with the receipt:
**27,408 body/margin boxes, 8,710,095 candidate-triangle queries, zero support
rays**. The logical contact log contains 41,413,079 bytes. Each objective starts
independently; the five table-named requests are not evidence of a continuous
observed loop.

## What the witness heights do—and do not—show

The scorer records complete per-query overlap **counts**, but only **one first
non-ground face ID and height range per contact-bearing query**. This is a
locator-order witness, not the first collision in time. The field named
`groundContactFaceIDsFirst16` is always empty because this run exempts no ground
faces; it is not a list of the raw hits.

Consequently, **7,202 nominal-body and 95,077 margin overlap occurrences lack
individually recorded identities/heights**. There are multiple hits in 960 of
the 1,019 body-contact events and 5,102 of the 5,284 margin-contact events.
Unlogged hits cannot inherit the first witness's height or classification.

These descriptive bands apply **only to the recorded first witness's whole
triangle relative to the authored sweep-start foot**:

| First-witness reporting band | Nominal body | Margin |
|---|---:|---:|
| Entire triangle within ±25 mm of start foot | 784 | 2,579 |
| Entire triangle at least 0.50 m above start foot | 0 | 442 |
| Other or mixed first-triangle range | 235 | 2,263 |

All recorded nominal-body first-witness vertices lie between **−23.995 mm and
+34.607 mm** relative to the authored start foot. That describes near-foot
geometry in the *available witnesses*, not semantic floor, a proven false
positive, or the heights of all 8,221 nominal-body overlap occurrences. The
235 witnesses outside the narrow ±25 mm band are not thereby upper-body
objects. A negative start-relative height during a descending connector is
compatible with the sweep extending down to its lower endpoint; end-relative
ranges are retained separately in the text result.

There are also clearly higher **margin** witnesses, not just near-foot ones.
Examples, with zero-based event and original face IDs:

- `table_92_to_120`, initial event **0**, face **26870**: whole-triangle height
  **0.839152–0.935839 m** above the authored foot; six raw margin occurrences in
  that query, but only this first face is identified.
- `table_20_to_92`, event **541**, face **23402**: a retained first witness spans
  **1.056613–1.094980 m** above the authored foot.
- `varpu_130_to_160`, event **960**, and the reverse route's event **966**, face
  **10860**: **1.330956–1.426233 m** above the authored foot.

Those ranges are verified directly against the exact registered source
triangle vertices using standard-library arithmetic. They are **not measured
contact points**, semantic table/chair/person identifications or live body
measurements. The 0.50 m band is an explicit reporting choice, not a new safety
threshold or geometry filter. No contact is removed or forgiven by any band.

## Preserved geometry, policy and failure

- Executed source: `c204b0e63e4c7444c02ea8ccf50e347693a15684`.
- Executed manifest:
  `ed735949ea0d21bf0fbf64754980a61d67d8b8095193b11d5ba72920dc8d6dc9`.
- All **32** frozen before/after/current input hashes match. The original guard,
  source manifest and attempt files remain unchanged; an import-only remedy and
  any post-run validation belong to separate source/output records.
- All **three child commands** have saved zero exits and retired process
  groups. **Six source controls and 32 kernel controls** passed. The original
  guard still reports failure at its later terminal import; this recount does
  not change that status.
- All **eight terminal payload files** match saved sizes and SHA256 hashes:
  **1,141,964 bytes**, excluding the final guard receipt.
- Original guard resources: **65.999001 CPU s / 66.033000 wall s /
  172,802,048 bytes peak observed aggregate RSS**, within the unchanged
  120 CPU s / 180 wall s / 1 GiB observed RSS / 64 MiB output limits. Observed
  RSS is not a hard cgroup memory guarantee.

The body remains **0.45 × 0.30 × 1.60 m**, plus **0.15 m per horizontal axis**,
with the inherited **2 mm lower-body exclusion**. No face-ID ground exemption
or support-following adjustment was used. Low surfaces below the query trim
can be omitted; absence of a hit does not establish clearance or support.

The original mesh's exact historical registered float32 vertices and original
triangle indices were preserved. This registration is an estimated comparator,
not calibrated camera/body alignment. Missing source surfaces, present-world
obstacles, whole-footprint support, actual location/heading and device/child-use
acceptance remain unknown. No low-height relabeling, reduced body/margin, new
budget, endpoint change or successful-navigation claim follows from this run.

## Public artifacts

Publish only `README.md`, `PUBLIC_SAFE_RESULT.json`, `recount.py`,
`INDEPENDENT_REVIEW.md` and `PUBLICATION_FILES.json` from this folder.
These are text-only and omit host-environment dumps and raw coordinates. Raw
contact archives, receipts, mesh/array/binary payloads are not included. No
archive was created. This review did not rerun native work.

Saved-data verification only, from the original workspace:

```sh
python3 -B research/conference-body-result-20261030/recount.py
```
