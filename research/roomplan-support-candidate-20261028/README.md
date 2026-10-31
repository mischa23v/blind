# Original RoomPlan floor support candidate

Prepared 2026-10-28. Isolated implementation and source-reviewed candidate, not yet Apple-compiled, native-tested or proven improved.

## Change

The adapter retains the raw Apple export and its feature identities separately. Historical routing geometry copies every non-floor exported triangle unchanged and obtains floor triangles from Apple's `SCNShape(path:extrusionDepth:0)` over the original source `polygonCorners`. The generated export slab's sides, underside and extended rim are never floor support. No source fixture, coordinate scale, body dimension, margin, door state or route protocol is changed. All physical/live authority properties remain false.

Known source-plane-versus-solid bounds failure is no longer applied indiscriminately to architectural export vertices. Strict original furniture bounds remain; both metadata-bearing feature frames and each mesh's world frame must agree with the original feature frame within the unchanged Float32 roundoff budget. This intentionally supports the export structure verified in the two public fixtures; differently structured future exports remain unsupported until independently validated. No thickness constant or widened epsilon is introduced.

The original source floor may carry a tiny local-plane offset. That offset is preserved. Degenerate, crossing, nonplanar and duplicate-edge source polygons are rejected, not repaired. Platform tessellation must have upward-facing positive triangles, correct area, paired interior edges and full bidirectional original boundary coverage. This is geometry validation, not a custom triangulator.

## Provenance and limits

Apple describes the final RoomPlan polygon as beautified model output. The new support is historical semantic support, not evidence of current full-footprint clearance, drops, toys, or successful localization. Neither raw exporter solids nor source polygons are surveyed physical truth. Exported wall extensions are retained and may still overblock passages; this candidate does not shave obstacles to obtain routes. Peak native allocations and SCNShape layout/winding need actual measurement.

The same-file all-feature parity instrumentation in the existing native fixture test captures raw diagnostic Model I/O data, independent of the corrected routing representation. Its existing128KiB cap is unchanged. Actual native export size and independent OpenUSD triangle comparison remain pending. See ../native-allfeature-parity-20261028/README.md.

## Verification completed here

- 32 source-contract checks passed, not Swift execution.
- 77 Python evidence-collector tests passed.
- 17 same-export/workflow-extractor integration tests passed.
- Six historical-support Swift tests authored and appended to the already registered test file. Zero native executions of these new tests here.
- Original concavity/area/boundary test body preserved. Existing route/journey protocols untouched.
- Independent source review found two initial issues (AABB/area-only validation and unchecked child mesh transforms); both addressed. Final review found no further blocking source issue, pending Apple compilation and runtime tests.
- No project membership, workflow, runtime deadline, evidence cap, stage85 inverse chain or frozen source pin changed. Changed adapter/test/collector files were not entries in stage85's integrated SOURCE_PINS. Historical run receipts remain unchanged.

Run `python research/roomplan-support-candidate-20261028/check_source.py` for the bounded source contract. The retained `.before.swift` is the c4ffa28 adapter (SHA25600607603fa3725182a1bfa809eeb880b9930b6654fd29ca92c96f59951789983), not a second production file.

## Primary APIs

- https://developer.apple.com/documentation/scenekit/scnshape/init(path:extrusiondepth:)
- https://developer.apple.com/documentation/roomplan/capturedroom/surface/polygoncorners
- https://developer.apple.com/videos/play/wwdc2023/10192/

No additional dependency installation or third-party source vendoring. Apple's SDK implementation is reused; the local validation/adapter is new and must be tested as such.
