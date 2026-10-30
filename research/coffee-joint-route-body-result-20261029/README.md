# Coffee joint-centered 0→8: completed 3D diagnostic, margin test not passed

The complete original route was checked. **No nominal-body enclosure overlaps
were reported, but the 15 cm horizontal-margin enclosure overlaps the source
mesh.** The separate ground-following arm stops almost immediately during a
turn. This is not a completed journey, a physical collision observation or a
clearance/safety pass.

## Independently recounted saved results

| Arm | Scheduled events examined | Nominal-body overlap occurrences | Margin raw occurrences | Margin component-ground / other occurrences | Events with other-margin overlaps |
|---|---:|---:|---:|---:|---:|
| A — exact original XYZ/yaw, no ground exemptions | 1,644 | 0 | 17,102 | 0 / 17,102 | 426 |
| B — same trajectory, translated frame and geometric ground labels | 1,644 | 0 | 17,102 | 18 / 17,084 | 426 |
| C — separately support-adjusted Y trajectory | 11 | 0 | 41 | 38 / 3 | 1 |

These are **triangle-query overlap occurrences**, repeated across events and
half-sweeps, not unique triangles, obstacles or physical impacts. The margin
volume includes the body volume; it is not a disjoint ring. Overlaps use
conservative swept enclosures, not exact-body contact points or times.

A/B raw counts agree for every event and both modes. Their 426 other-margin
events comprise **362 turns, 63 translations and the terminal pose**. These arms
deliberately continue scanning after contact; that does not represent travel.
B's 18 ground-labelled occurrences occur in two events. C made 21 static/half-
sweep queries per mode: eight events contain any raw margin overlap, but only
event 10 has overlaps outside its frozen ground component. At that rejected
turn, the two margin half-sweeps contain respectively **4 ground + 1 other** and
**3 ground + 2 other** occurrences; nominal-body counts remain zero.

C accepted the tiny initial connector and eight turns before rejecting the next
turn: **8.7271663854747e-8 m** modeled translation, less than 0.1 micrometre and
not meaningful progress along the room route. Its initial **0.354418 mm** support
height correction is separate and never counted as travel. It neither completed
the 1,644-event schedule nor claimed arrival. The failed proposed turn does not
advance the accepted state. C changes Y by the retained support rule; it does
not preserve the original connector's vertical travel or erase A/B contacts.

## The first witnesses have different height scopes

Event and segment indices below are zero-based. “First witness” means the first
returned **locator-order** triangle in that query, not the first physical impact.
Height ranges describe the **whole triangle**, not a measured contact point.
All-hit counts are recorded, but only the first other/non-ground face ID is
retained per mode/sweep, not the complete other-contact face list. The second
half of C's failed turn therefore has one additional other-face occurrence
whose identity/height cannot be recovered from this log. The first-witness
height must not be generalized to every reported overlap.

- **A/B:** first margin-contact event **14**, a turn on segment 1, witness face
  **45802**. Its vertices span **1.468073–1.653405 m above the authored foot**.
  This is upper-body-height geometry in the mesh, not a low-floor-only witness.
  Part of that whole-triangle range exceeds the 1.60 m nominal body height; the
  record does not identify a contact-point height. It is a margin-only
  conservative overlap, not a nominal-body hit or identification of a table,
  chair, wall or person.
- **C:** first rejected margin-contact event **10**, a turn on segment 1,
  witness face **27557** in both half-sweeps. Its vertices span
  **2.735887–14.674887 mm above the current modeled foot**: near-foot geometry,
  not a body-height-obstacle witness. This face is absent from the saved
  4,827-face ground component. Simple float64 arithmetic on the source vertices
  gives a signed-normal slope of **16.894798°**, beyond the retained 15° initial-
  eligibility threshold; this diagnostic arithmetic is not a rerun of the
  float32 native classifier or proof of the complete exclusion cause.

Low height does **not** establish semantic floor, sensor noise or a false
positive. Likewise, a high triangle does not identify furniture. Neither
witness justifies changing labels, body dimensions, margins or thresholds.

## Why the earlier 2D centering pass is not contradicted

The saved 2D result checked **143 segments × two manual windows = 286 checks**,
with zero contacts and a minimum residual of **129.583630 mm** beyond its
0.420416 m body-plus-margin circle. Those windows were explicitly approximate
exclusions, not measured complete table/chair boundaries or the whole room.

This diagnostic asks a different question: full XYZ, authored yaw/turn sweeps
and full-height body/margin enclosures against the available source mesh.
Even the margin shape differs: the 3D box has horizontal half-extents
**0.30 × 0.375 m**, corner radius **0.480234 m** before conservative sweep
padding, rather than the 2D radial circle. C also changes Y through its separate
support-following rule. A better route relative to two manual windows therefore
need not pass this broader, different 3D margin check. Neither check establishes
clearance around geometry missing from the mesh.

## Execution and provenance verified

- Exact run source: `3d6b7a6fdb4ae80f8fe99060a17f93573c0477d8`.
- Run manifest: `9ee9ad130a163b2ab38a1c4abb5ee4ea7fac2fd834538a709d5fe385259cc835`.
- Original schedule retained: **655,653 bytes / 1,644 events**, SHA256
  `19bc3032e46b7218e62c1481d54be9a978c3233cbf19c19d1400ba4234d44d40`.
- All **75** before/after/current input hashes match. All **six commands** exited
  zero and their process groups retired. Six native-boundary checks agree.
- Saved **6 source + 67 native controls** passed. The diagnostic completed within
  the unchanged limits: **22.337979 CPU s / 22.413493 wall s /
  208,969,728 bytes peak observed aggregate RSS**. Observed RSS is not a hard
  cgroup memory guarantee.
- All **3,301** saved contact/setup rows were recounted. Query totals agree:
  **6,618 boxes / 2,547,270 candidate-triangle queries / 189 support rays**.
- All **16** terminal payload files match saved sizes and SHA256 hashes:
  **291,594 bytes**, excluding the final guard receipt.

Successful process exit means a completed diagnostic, **not** a passed route.
Nine support rays are not whole-footprint support; the component is not semantic
floor. Complete mesh coverage, actual location/heading, live obstacles,
physical travel, conference-room/general robustness and phone/child-use
acceptance remain unproved. Earlier twenty-path CPU exhaustion is not replaced
by this successful single-pair diagnostic.

## Public files and reproduction

Publish only `README.md`, `PUBLIC_SAFE_RESULT.json`, `recount.py`,
`INDEPENDENT_REVIEW.md` and `PUBLICATION_FILES.json` in this result folder.
The public summary is coordinate-free text/JSON and omits host-environment
records. No raw receipts, binaries, arrays, mesh/contact archives or other
payloads are included. No archive was created, and the review did not rerun
native planning, collision scoring, controls or builds.

From the original workspace, saved-data recount only:

```sh
python3 -B research/coffee-joint-route-body-result-20261029/recount.py
```
