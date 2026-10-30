# Conference complete contact identities: verified text-only result

**Actual complete-ID diagnostic finished; this is not a physical clearance pass.**
Exact source `e9bfe8deefd7b91494aec0c77afb5787f3913712`, manifest
`94fb3b077aca01dc0fc35c9dcbfdbde8ad5d0eb6013f02ad2ed3a43f73bf1905`.
All five command groups exited zero and retired. The aggregate used
67.017946 CPU seconds / 67.131563 wall seconds / 176,222,208 bytes observed peak
RSS, inside the unchanged 120 CPU / 180 wall / 1 GiB observed RSS / 64 MiB output
budget, on one CPU. It ran 3 isolated-import, 6 schedule, 6 recorder-source and
35 kernel controls (50 controls), then all seven route schedules.

The earlier body-only attempt remains **failed** because its supervisor could
not import the terminal contract under isolated Python. Its completed worker
evidence was separately reconciled. This successful new diagnostic does not
rewrite that earlier outcome.

## Main finding

The complete nominal-body contacts are confined to low source triangles, but
**not every contact falls inside the declared ±25 mm near-foot band**:

- **1,019 nominal contact events** out of 13,704 authored increments. Relative
  to start-foot height, 688 events have *every* hit within the band; 331 have at
  least one hit outside it. Relative to end-foot height, these are 685 / 334.
- **8,221 nominal hit occurrences across 62 unique source face IDs**. Their
  whole-triangle height ranges span −36.84 to +39.78 mm relative to start foot,
  or −40.45 to +39.78 mm relative to end foot. All out-of-band nominal
  occurrences overlap a near-foot band boundary; none is wholly ≥0.5 m.
- **5,284 margin contact events**. Start- and end-reference totals are each
  1,320 all-hits-near / 3,964 any-hit-not-near. Of those events, 2,313 include
  a triangle wholly ≥0.5 m above the authored foot reference.
- **100,361 margin hit occurrences across 1,015 unique face IDs**. There are
  43,556 wholly ≥0.5 m occurrences involving 404 unique faces. The body IDs are
  included in the margin ID union; total union is 1,015 original source faces,
  **not 1,015 distinct physical obstacles**.

These observations distinguish low/straddling versus higher source geometry.
They do **not** establish semantic floor, tolerated contact, missing-object
coverage, continuous support, actual body pose, arrival or safe travel. No
contact was erased or reclassified as allowed. The retained **2 mm lower-body
query exclusion** can miss lower/tiny geometry. Historical estimated
registration is still not validated camera/body alignment.

## Per-request event accounting

“All near” / “any outside” below refer to **all triangle hits in that event**,
relative to authored **start-foot** height, not merely its first witness.
They partition the contact-event column. A no-hit event is separate, not
vacuously all-near and not a physical pass.

### Nominal body

| Request | Authored events | Contact events | All hits near | Any hit outside | Repeated hits | Unique faces |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| table_92_to_120 | 1,844 | 0 | 0 | 0 | 0 | 0 |
| table_120_to_200 | 2,052 | 2 | 2 | 0 | 30 | 15 |
| table_200_to_220 | 1,530 | 2 | 2 | 0 | 30 | 15 |
| table_220_to_20 | 1,555 | 0 | 0 | 0 | 0 | 0 |
| table_20_to_92 | 2,863 | 265 | 154 | 111 | 2,094 | 28 |
| varpu_130_to_160 | 1,923 | 374 | 264 | 110 | 3,021 | 19 |
| varpu_160_to_130 | 1,937 | 376 | 266 | 110 | 3,046 | 19 |
| **Total** | **13,704** | **1,019** | **688** | **331** | **8,221** | **62 deduplicated** |

The end-foot reference changes three nominal events from all-near to
any-outside. Exact per-route start/end accounts and source ID sets are in the
individual `public/*.json` files; none was dropped.

### Independent horizontal margin

| Request | Contact events | All hits near | Any hit outside | Any wholly ≥0.5 m | Repeated hits | Unique faces |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| table_92_to_120 | 855 | 238 | 617 | 417 | 11,336 | 203 |
| table_120_to_200 | 652 | 193 | 459 | 360 | 13,383 | 234 |
| table_200_to_220 | 101 | 35 | 66 | 0 | 279 | 34 |
| table_220_to_20 | 119 | 17 | 102 | 8 | 335 | 26 |
| table_20_to_92 | 1,590 | 259 | 1,331 | 687 | 34,352 | 356 |
| varpu_130_to_160 | 979 | 289 | 690 | 418 | 20,255 | 316 |
| varpu_160_to_130 | 988 | 289 | 699 | 423 | 20,421 | 313 |
| **Total** | **5,284** | **1,320** | **3,964** | **2,313** | **100,361** | **1,015 deduplicated** |

“Any wholly ≥0.5 m” is a subset of “any outside”, not an additional partition.
There are 685 nominal and 1,318 margin events whose hits are all near **both**
start and end foot references. Equal start/end margin totals do not imply the
same individual events belong to the band.

## Complete whole-triangle height distributions

The three principal bands are mutually exclusive per hit occurrence. Start
and end references are calculated separately. Boundary subsets below are
retained diagnostic subsets, not additional mutually exclusive bands.

| Envelope / foot reference | Within ±25 mm | Wholly ≥0.5 m | Other, retained | All occurrences |
| --- | ---: | ---: | ---: | ---: |
| Nominal / start | 7,611 | 0 | 610 | 8,221 |
| Nominal / end | 7,606 | 0 | 615 | 8,221 |
| Margin / start | 27,403 | 43,556 | 29,402 | 100,361 |
| Margin / end | 27,395 | 43,556 | 29,410 | 100,361 |

Unique source IDs in those bands, respectively:

- Nominal/start: **56 / 0 / 14**; nominal/end: **55 / 0 / 15**.
- Margin/start and margin/end: **247 / 404 / 398**.

Those unique counts are **not additive**: a fixed triangle may occupy different
foot-relative bands on different increments. Global totals deduplicate source
IDs, rather than summing route or band counts.

All 610 start-relative / 615 end-relative “other” nominal occurrences touch or
cross a near-foot band boundary. Margin near-foot boundary subsets are 18,630
start-relative and 18,628 end-relative occurrences. Margin triangles touching
or crossing the 0.5 m boundary account for a further **1,715 occurrences** under
each reference; they remain in “other”, not the wholly-high band. Other margin
geometry that crosses neither boundary is also retained.

### Height limits (metres, entire source triangles)

| Envelope | Registered Y range | Relative to start foot | Relative to end foot |
| --- | --- | --- | --- |
| Nominal | −0.009265 … +0.065601 | −0.036839 … +0.039780 | −0.040450 … +0.039780 |
| Margin | −0.033689 … +1.913036 | −0.039493 … +1.912328 | −0.040450 … +1.912328 |

Authored start/end foot heights range from −0.001189 to +0.039612 m across the
scheduled increments. These limits are **not contact-point heights or
penetration depths**. For example, a triangle touched by a 1.6 m enclosure may
extend above it; the maximum whole-triangle height is not the collision height.

## Independent complete-stream verification

The read-only stdlib recount verified:

- Exact source commit, all **46** current execution input hashes, identical
  recorded before/after hashes, and every terminal output length/SHA256.
- Every row of both streams: **13,704 CONTACTS + 13,704 HIT_IDS records**;
  no missing, duplicated, reordered or extra events. Exact frozen schedules,
  including connectors and every authored bounded increment, reproduced.
- **Every new CONTACTS record is byte-identical to the earlier completed
  worker's record.** All original per-event nominal/margin hit counts and the
  ordered candidate-count digest match: 27,408 boxes / 8,710,095 candidates /
  zero support rays / 108,582 combined hit occurrences.
- All recorded IDs are unique within each query and refer to original faces;
  the first ID equals the original first witness. Every first-witness source
  height, start/end relative height and near-band flag reconciles.
- The registered mesh byte digests were independently reproduced with stdlib
  scalar rigid-transform arithmetic and Float32/Int32 packing:
  vertices `50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb`,
  triangles `2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324`.
- Contact-log logical size 41,413,079 bytes; ID-log logical size 1,986,838 bytes.
  Source bounds were respected. Recount used **2.514450 CPU / 2.516083 wall
  seconds / 23,724,032 bytes peak RSS**, with no NumPy, SciPy, VTK or native rerun.

Four stdlib accounting fixtures passed: inclusive thresholds/retained
straddles, mixed hits not promoted by a near first witness, distinct start/end
references and empty events, and unique IDs versus repeated occurrences.

These repeated mesh-contact occurrences are not independent physical
observations, obstacles or journeys. Continuous conservative enclosures can
overcount exact body contact, missing source surfaces remain unknown, and the
saved VTK intersection truth was not recomputed by this analysis.

## Public text artifacts and local raw evidence

`public/SUMMARY.json` contains complete global counts, ranges, definitions and
sorted original ID sets. Seven per-request JSON files retain corresponding
start/end event partitions and occurrence/unique-ID distributions. All are text
and below 100 KiB each. Raw `CONTACTS.jsonl.gz`, `HIT_IDS.jsonl.gz` and native
attempt archives remain local; none is part of `PUBLICATION_FILES.json`.

Reproducible source: `recount_heights.py`, `test_height_bands.py`, and
`ANALYSIS_PINS.json` SHA256
`6a383c830da45298a62f4369e9464fe81a4c6cbc9e985cb01241b32629e7d2bf`.

```sh
python -I research/conference-contact-ids-result-20261030/recount_heights.py \
  --pins-sha256 6a383c830da45298a62f4369e9464fe81a4c6cbc9e985cb01241b32629e7d2bf \
  --out <fresh-workspace-directory>
```

This reproduces text accounting only; it neither reruns native geometry nor
authorizes movement. Root owns publication of the reviewed text result.
