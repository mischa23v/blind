# Independent collision comparison source review — 2026-10-29

**No remaining core source-review blocker identified to a separately admitted bounded serial control-plus-comparison experiment.** An external aggregate guard remains mandatory and is not supplied/approved by this note. No VTK/native import, geometry query, test/control suite or worker was executed by this reviewer. This is not collision evidence or physical clearance approval.

## Frozen evidence reviewed

- SOURCE_PINS.json SHA-256: `74541290438c53a972a8691c19848f0beccc062f39924bd881d36d09391ef7ae`.
- PUBLICATION_ALLOWLIST.json SHA-256: `f6178d313d773cbdc71d0370e08cdd310e1567e54199dff5a9322452e7d2c07b`.
- run_comparison.py SHA-256: `dd4548740f613e0ef899ccb2324e6fb5bb1021829989260db84b7b08fecf40d5`.

All 23 publication entries and all 20 source-manifest entries match bytes/hashes. All 11 copied upstream/extraction-original/test files independently match exact published Git blobs at c79fbd33171f78608f9eb2a1484fbc9266e3a695. The three extracted support functions match their original function text and declared hashes exactly. All published Python files AST-parse; no imports executed. Source contains 47 authored test methods, not 47 passing tests.

Independently decompressed the hash-verified 131,731-byte gzip with Python standard library into memory: original 1,394,610 bytes, SHA-256 `2b6f6594dfc741a5e28e1332ce02d36b1d46f7abf4e6fc585d6950aea85b507b`, identical to local schedule; gzip timestamp is zero. Read restoration helper source, but did not execute it. It checks compressed/original identity and refuses differing existing schedule content. No archive setup code was executed.

## Exact path and schedule reconciliation

All twenty CURRENT_PATHS entries equal the actual attempt002 accepted query dictionaries, native point arrays and requested start/goal coordinates. Full chains exactly prepend requested-to-projected start connector and append projected-to-requested goal connector; no path, height or connector was shortened/replaced. Actual-result hash matches the pinned current result.

All 6,874 schedule events were independently checked using JSON and arithmetic only: 20 initial, 3,156 translations, 3,678 turns and 20 terminal events. Paths are contiguous, start/end at exact requested coordinates, every chain edge is traversed, translations remain on the original edge and are <=0.025 m in 3D, and turns are in-place with <=1 degree increments. Translation yaw follows each nonzero horizontal leg and summed turns implement the shortest interval with positive-pi tie. The initial direction can derive from a very small connector horizontal component; it is an authored orientation convention, not a measured heading. CURRENT_PATHS yawProtocolFrozen=false is historical metadata; the separately pinned SCHEDULE is the actual later yaw freeze.

## Geometry and arm review

The original vertex/face arrays remain in original OBJ coordinates, with explicit double-precision VTK points, cardinality/index/roundtrip checks and preserved original vertex/cell IDs. No point welding or geometry modification is introduced. Body remains width .45 m, depth .30 m, height 1.60 m; margin .15 m is separately horizontal; original .002 m bottom exclusion is unchanged.

For frozen floor statistic f=-1.6301633051396203, local q=p-(0,f,0), while model-to-original-source T adds (0,f,0). The sign is correct: local query corners map back to original geometry; inverse T supplies local ground-patch heights. This is translation, not flattening, gravity calibration or camera alignment.

A uses identity transform and empty/unknown ground IDs, preserving raw contacts. B changes only coordinate representation and adds per-path geometric labels; it verifies raw body/margin contact-count equality with A for every event. Ground labels require initial nine-hit finite support, <=5-degree eligible triangles, fixed local patch and shared-original-edge connectivity to every seed. Every triangle is intersected before membership classification, and all candidates continue after first hit. Low height alone never removes a triangle. Ground membership remains geometric, not semantic floor; unlabelled/non-ground is not confirmed furniture. Counts/witnesses are conservative triangle/OBB overlaps, not exact first-contact time, closed-solid containment or known-free-volume proof.

C is explicitly a different vertical-follow trajectory using the unchanged three extracted functions. It preserves XZ/yaw, checks midpoint/end support against frozen component and previous height, uses maximum probe height, and rejects a two-half-segment 3D increment exceeding .025000001 m. Missing/disconnected/excess-height support stops C; any nominal or margin non-ground candidate contact also stops it. It does not re-seed, repair, shrink bodies, skip to later points, or claim original-goal arrival. Initial vertical correction is a comparison initialization, not scored physical motion. Nine rays can miss holes/low objects; C cannot clear an A/B warning. Adjusted intermediate positions are explicitly labelled local in worker logs and reconstructable using fixed T; final accepted position is also converted to source coordinates. This is not recorded actor motion.

## Finding repaired during review

The worker checked the triangle budget around swept_contacts, which performs two body/margin OBB queries. Earlier documentation understated maximum post-check overshoot as one mesh (87,370 triangles). Author corrected documentation/receipt limitation to **two queries, at most 174,740 triangles**, without changing upstream geometry code. Reviewed hashes above include that correction.

## Minimum execution gate and limitations

Run controls first and skip comparison on any failure. Required external guard must bind exact published source/input hashes before and after, include controls/native imports/locator construction/ground setup/worker and descendants, retain fresh owned outputs and failure evidence, and enforce the separately admitted aggregate 120 CPU seconds / 180 wall seconds / 1 GiB observed memory / one worker. No native result is assumed from source review.

Worker counters cap 55,000 box calls, 125,000 support rays and 30 million triangle tests with the stated two-query overshoot. Frozen full-workload upper bounds are 54,992 boxes and 124,092 support rays; controls and ground setup are additional within aggregate resources. Runtime may legitimately exhaust the budget before all paths complete; aborted/partial/classification-unavailable is unknown, never clear. No cap growth or automatic retry is implied.

Worker checks 64 MiB logical contact log and 16 MiB output after writes; ground-ID arrays and final receipt can be written between checks. Therefore the external guard must own aggregate output/disk observation and final receipt/inventory validation. Worker wall checks do not interrupt an indivisible native call. Failures before the worker's inner receipt block must still be retained by the guard. These are trusted-workload limitations, not requests for a new hostile-process framework.

No new algorithm, engine edits, model, install, image copy, app activation, push or execution occurred during this review. Original input and prior result packets remain unchanged. Public mesh attribution and wrapper-license caveats remain as documented; VTK's license is not a substitute license for project-authored wrappers. Root owns publication and exact-run admission. No permission denial occurred in this review.
