# Reference-query profiling and tiled broad phase — completed cuts 16/17

This additive checkpoint preserves the **completed evaluator-performance**
investigation in `query-profile-16/` and `ground-query-tile-v17/`. It is not the
separate pose-consistency stages with similar numbers. No new navigation episode,
route, phone map, body envelope, contact tolerance or physical permit is created.
Previous movement results and earlier performance results remain unchanged.

## Measured bottleneck before optimizing

The frozen V6 scorer and an instrumentation-only copy were applied to the same
10 saved v3 ticks (0, 9, 15, 28, 30, 45, 60, 75, 90, 106), 20 continuous
half-sweeps, and **40 actual-body / 15 cm margin box queries**. Pair order alternated.
All original collision-result dictionaries/counters matched. Timers were outside
those dictionaries; nested owner/helper timings were not added twice.

Native `vtkStaticCellLocator.FindCellsWithinBounds` took **41.35424 s of
42.41135 s (97.51%)** of the instrumented swept-query time. Ground skipping plus
bounds rejection accounted for every candidate: 2,287,073 total, 1,780,895 ground
skips and 506,178 non-ground bounds rejections; zero exact-triangle survivors.
Twelve authored fixtures and a fresh-import smoke preceded this measurement.
The independent `TIMING_READBACK.json` reconciles phases, pair order and counters.

## The bounded optimization and its actual result

The new scorer reuses the existing tiled VTK bounds-query helper for the **same
closed AABB and union of original triangle IDs**. It does not simplify the mesh,
delete geometry, loosen collision predicates, change ground membership or alter
the conservative motion enclosure. Candidate/cap/owner failures remain explicit.

Sorted tiled IDs can change diagnostic order. On **any non-ground positive
prepass**, the unchanged original V6 method is rerun on the same box and its
original result is returned. This preserves native first-contact ID, height,
near-foot classification, reason and counts; extra prepass/fallback work is
recorded separately. Positive cases can be slower; no positive-case speedup was
measured or promised. Authored fixtures include a case where sorted first ID is
a body-height contact but native first ID is near-foot, preserving native output.

On the same fixed saved boxes, all **40 sorted candidate-set hashes** and physical
result/classification comparisons matched. **All 40 recorded cases are negative**;
none executes positive fallback or an exact-triangle survivor. Seventeen authored
fixtures cover positive/order, boundary, rotation/sweep, margin, cap and ownership
behavior separately. These are not 40 new walking trials or universal equivalence.

| Paired query timing | Seconds |
|---|---:|
| Original, excluding separately measured identity capture | 42.448274 |
| Original identity capture | 0.526491 |
| Original including capture | 42.974765 |
| Optimized, including its own metadata/digest work | 7.513937 |

The primary measured ratio is **5.649×**, comparing 42.448274/7.513937. It excludes
only separately measured original identity capture; optimized digest time
(0.017416 s) remains included. The optimized pass makes **4,480 native tiled calls
for 40 logical boxes**, not 40 native calls. Candidate/ground/rejection totals match
profiling. Shared loaded locator/cache, alternating order, one host and this fixed
negative set limit interpretation: **not an iPhone latency or real-time guarantee**.
Do not derive a paired speedup by comparing earlier unrelated runs.

### Explicit result difference

The negative `skippedGroundCandidateIDsFirst16` diagnostic preview order differs
in **all 40** cases because the tiled union is sorted. This is not a contact
measurement/control input. All other old collision-result fields must match.
The comparison is therefore **not byte-identical equality of all output fields**.
Positive original-order behavior is covered by authored fallback fixtures, not
by positive contacts in this recorded set.

### Whole-process costs and source chronology

Profiling whole process: 106.113 s wall / 107.10 sampled CPU, 2,383,118,336 B peak
sampled/waited tree RSS. Tiled comparison: 69.033 s wall / 69.63 sampled CPU,
2,385,018,880 B peak RSS. These include setup/ground-model construction and both
comparison sides; do not substitute the 7.51 s query subtotal for whole-process
latency. Watchdog limits were 600 CPU / 900 wall seconds, 3 GiB observed tree RSS,
64 MiB outputs and 768 MiB reserve; not hard-cgroup guarantees.

Executed sources, source-generation scripts/diffs, frozen manifests, authored
fixture/import logs, stdout/stderr, heartbeats and full PROFILE/EQUIVALENCE JSON
are preserved. `prepared-pre-digest/` is historical preparation, **not the final
timed scorer**. Supplementary implementation-verification and readback receipts
were completed after the launch freezes; they are review evidence, not silently
backdated launch conditions. Exact source/freeze/result hashes identify the cut.

Independent `TIMING_READBACK.json` and `RESULT_READBACK.json` are saved-JSON review
receipts. This packet does not imply that an additional standalone recount source
was retained; the executed profiling/comparison drivers and assertions are present.
No reviewer geometry or comparison rerun is implied by these arithmetic reviews.

## Publication and reproduction boundary

`NORMALIZATION_MAP.json` records original/public byte identities. Executed code,
diffs and original scientific receipts are not rewritten for portability.
`DEPENDENCIES.json` preserves every historical frozen dependency and matches exact
already-public source/result cuts where available. Raw mesh, saved input traces,
phone assets, native libraries and installed Python/VTK/NumPy are **not duplicated**.
These prerequisite/build/acquisition identities remain necessary; a standalone
clean-machine replay is not claimed. Repository-owned code retains its original
ownership; no invented license grant is applied. No external runtime is copied.

The packaging validator uses only file bytes/hashes and JSON syntax. No scientific
code, geometry, native query, array decoder or movement was run to build this
packet. Private participant/family details, raw images and screenshots are absent.
