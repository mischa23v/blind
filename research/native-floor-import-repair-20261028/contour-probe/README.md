# Isolated contour attribution probe — actual packed geometry captured

This is an authored diagnostic, not an app change or a completed native result.
`PACKED_ROUTING_GEOMETRY.json` is the actual collector-parsed, hard-two-public-SHA
attachment from source b1f3a9ae2dca8b9a45ece285174253de5f172255/run40780118332.
`INPUT_PINS.json` binds the verified producer test, original attachment digest,
unit artifact digest, and this pretty-serialized JSON's distinct digest. Its integer
Float32 words, indices, support labels, feature IDs and source boxes are unchanged.
All 18 route and 16 journey outcomes equal the 49a baseline exactly, including the
three original outcome attachment SHA256s. The contour probe has not run natively.

## Fixed experiment

- Exact pinned original Recast/Detour C++ adapter is copied to runner scratch twice.
  The only configuration difference is `maxSimplificationError = .5f` versus `0.0f`.
  Production CDetour, body radius, margin, height, cell size/height, climb, slope,
  mesh coordinates/indices/support/semantic IDs and requested endpoints are untouched.
- Both copies receive a diagnostic-only appended function exposing the existing
  `findNearestPoly(..., bool* isOverPoly)` result. It does **not** change admission
  or route choice. This records whether a requested point was horizontally snapped.
- `REQUESTS_49A.json` is extracted from verified iOS run40773062534/source49a9878:
  all18 frozen route queries plus7 actually executed journey queries. The9 stopped
  journey stages stay explicitly not-run; no imagined continuation is manufactured.
- Compile the exact unchanged `SavedRoomRouteCollisionOracle.swift` into the macOS
  executable. Score raw body and required margin separately against final packed
  routing triangles plus original source furniture boxes, including both requested
  endpoint/projection connectors. The existing oracle verifies its backend controls.
- Baseline route/projection Float32 bits, completion/failure results, initial contacts,
  aggregate body/margin contacts and per-segment contact booleans must reproduce49a.
  If they do not, both configuration outcomes are retained but the contrast is
  marked **inconclusive**. A completed probe process is not a geometry/safety pass.
  This is an interpretation gate: both fixed configurations execute and are retained
  even if baseline reproduction fails; no zero-error result is interpreted alone.
- Even an interpretable macOS contrast requires iOS confirmation. No result grants
  current support, complete coverage, physical clearance or actual guidance authority.

## Bounds and source discipline

The public-only exact-repository/branch workflow uses the existing standard
`xcode-27` runner and installed Xcode27.0; no private/paid runner, install, download,
Docker or new package dependency. One compiler process at a time; 300-second overall
runner deadline,120-second probe cap, bounded input/output files. Only text/JSON
receipts are uploaded, never objects, archives or executable products.

`SOURCE_PINS.json` preserves every compiled local source/header plus the exact
oracle and request schedule. `CPP_WRAPPER_SYNTAX_RESULT.json` is only two tiny
bounded Linux C++ object compiles (under0.2s each,~47MiB), **not** linking, Swift,
Apple physics or path execution. No local Xcode/Swift was run.

The required `INPUT_PINS.json` schema is `blind.public-verified-contour-inputs.v1`,
with `physicalAuthority:false`, `sourceVerified:true`, actual `captureSourceCommit`,
`captureNativeRun`, `packedGeometrySHA256`, and collector/artifact identities.
These are now populated from the verified actual capture, not predicted data.

No retries across parameter values, endpoint replacement, shortened schedules,
body/margin reduction, oracle relaxation, source-geometry edit or new planner.
