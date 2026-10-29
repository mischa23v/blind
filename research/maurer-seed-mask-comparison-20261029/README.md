# Actual whole-grid versus overlapping-section mask comparison

**Completed bounded experiment: all 4,113 masks and 8,226 overlapping-tile comparisons passed.** Whole-grid integer computation used less counted work than either tiled layout on all six captured native fields and both authored scale masks. This supports qualifying the faster whole-grid method first, not automatically dividing rooms or adopting this candidate in the app.

| Input | Whole-grid work / time | Tile work (two separate layouts) | Time for both tiled layouts together |
|---|---:|---:|---:|
| Six captured native field profiles | 287,212–346,456 / 0.824–1.283 ms | 443,833–883,918 per layout | 3.490–5.987 ms |
| Authored 252×252 grid | 579,945 / 1.741 ms | 799,644; 767,638 | 5.545 ms |
| Authored 302×302 grid | 831,806 / 2.350 ms | 1,089,031; 1,253,659 | 8.156 ms |

Times are a **single Linux run under nonrecovering UBSan**, including harness allocations. Tiled times combine two layouts, so do not divide these into a claimed single-layout speedup. No iPhone latency, thermal, battery or repeated statistical benchmark was measured. Source work units are not CPU cycles and differ from disk seed comparisons.

Original disk-policy admission bounds for the two authored scale cases were 34,350,948 and 51,566,848 seed tests, exceeding that policy's 10M limit. Whole-grid and each complete tiled request stayed below a numerically equal 10M envelope-work limit. **These are different operation units and changed work-cap semantics, not like-for-like work reductions or unchanged admission semantics.** Runtime/RSS observation used the same experiment envelope. These authored grids use 2cm-labelled 5m/6m interior spans, **not production 2.5cm resolution or recorded large rooms**. They contain authored seam obstacles; they are not route-completion trials.

## What passed

- Six frozen native fields: original binary seed maps, post-stock keep masks and expected exact masks reconstructed from existing captures. These are six profiles, not six independent rooms or new scans.
- 4,096 exhaustive 3×3 seed/radius/keep combinations; eight authored boundary/empty/full/line/checkerboard/seam/block/single-site cases; one explicit strict-radius equality case; two authored scale cases. Total 4,113, with 394,938 per-case mask bits checked.
- Every final mask matched the integer-disk oracle, and every captured expected bit matched. No original-null cell was promoted. 43,355 small-fixture squared distances matched direct all-site enumeration.
- Two shifted/unshifted overlapping core layouts per case, 8,226 total. Radius-sized halos use the same global seed domain; artificial tile edges never become seeds. Core coverage exactly once and seam/equality cases passed. This establishes **threshold-mask parity**, not global far-distance equality for cropped tiles.
- Ten refusal cases, exact declared work/memory boundaries and buffer canaries passed; comparison stderr was empty. Oracle diagnostic work was 92,673,168 checks under a separately frozen 300M test ceiling, not a production-budget increase.

## Actual resources and limits

One compile and one comparison, both exit 0. Guard PASS: 1.964884 aggregate CPU seconds, 1.9938933039957192 wall seconds, 138,096,640 bytes conservative peak aggregate RSS, 542,623 bytes recorded final output. Admitted limits were one CPU, 60 CPU seconds, 120 wall seconds, 512 MiB observed RSS and 100 MiB output. All 13 frozen inputs were reverified afterward. Resource accounting is sampled with fast-exit rusage, not a kernel-enforced RSS sandbox. See RESULT.json and exact aggregate stdout.

## Reused code and adaptation

Apache-2.0, copyright NumFOCUS. Based on current ITK public main commit [`2e353bf3975631defae25f1432e3333d97ff0a95`](https://github.com/InsightSoftwareConsortium/ITK/blob/2e353bf3975631defae25f1432e3333d97ff0a95/Modules/Filtering/DistanceMap/include/itkSignedMaurerDistanceMapImageFilter.hxx), not an obsolete ITK deployment. This pin is a public development revision, not a stable-release/iOS-support claim. Exact upstream Git blob identities are in SOURCE_RECEIPT_HASHES.json; staged upstream/license/notice captures have one additional terminal newline, explicitly distinguished from upstream identities.

The small attributed candidate extracts `Voronoi`/`Remove` separable-envelope logic, specializes to int64 finite nonnegative squared costs, and retains strict removal/evaluation tie comparisons. It replaces ITK image/contour/sign/spacing/thread machinery with caller buffers and direct initialization of **every original seed** to zero. No floating metric, nearest-label approximation, contour preprocessing, heavy ITK dependency, or square root remains. This is a maintained-source **adaptation**, not upstream integer API support or a generally certified new library.

Caller must retain existing flat-single-layer/topology checks, seeds/perimeter/absent-column semantics, radius/grid and original post-stock mask. Predicate remains `originalKeep && minSquaredDistance >= radiusSquared`: equality kept, no promotion. Checked cubic bounds protect envelope intermediates. Declared storage includes logical bytes and caller-supplied extras; the experiment's capacity/canary bookkeeping is not proof of a production 2MiB heap guarantee. Production allocation ownership and a separately versioned work receipt remain integration work.

## What this does not establish

No new routes, full-body support, live sensor replay, floor-noise removal, missing-floor repair, full Recast tiled mesh adjacency, route seam collision checking, on-device execution or app activation. Captured field parity does not establish physical clearance or safety. Full raster/navmesh tiling needs additional algorithm dependency halos and portal/obstacle checks; radius-only mask halos cannot justify that broader claim.

## Preservation and reproduction boundary

This packet contains exact staged candidate/harness sources, upstream attribution, aggregate results and receipt hashes. It excludes private captured fields, raw meshes/triangles/span arrays, physical coordinates/trajectories, binaries, local runner paths and admission content/digest. The harness requires the six omitted captured-field profiles, so **this public packet is not standalone reproduction of the complete experiment**. It is not silently export-redacted executable code: source files are unchanged; private execution scripts are omitted. Future authorized replay must re-freeze inputs/toolchain and obtain a fresh explicit run admission, not rerun the preserved attempt.
