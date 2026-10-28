# Apple native identifier contract repair — 2026-10-28

## Actual failure, retained

Native run [`40664336968`](../native-candidate-app-integration-85/integrated/evidence/run40664336968/README.md) at source `9e8585c` built both app modes successfully. Three of four Apple-fixture methods passed: fixed original Bedroom3 world geometry, actual default-provider loading/deletion, and wrong-source-hash rejection. The both-room decode method failed twice at its old line 115, comparing identifiers from **separate native decodes** of the same bytes. The test continued its numeric/source assertions; the receipt records no failures in those assertions. All seven provider cases and all 23 recorder cases passed on that revision. This does not make the failing fixture method pass.

`original-native-failure.txt` preserves the exact two mismatching UUID pairs and failed test status, with the source receipt's SHA-256. Full original test and Node-contract preimages are in `preimage/`. The original Apple files and earlier publication/evidence manifests remain unchanged.

## Contract diagnosis

Both exact original JSON files have root keys `coreModel`, `doors`, `floors`, `objects`, `openings`, `sections`, `story`, `version`, `walls`, `windows`; neither has a root `identifier`. Their features **do** have persisted identifiers.

Apple documents [`CapturedRoom.identifier`](https://developer.apple.com/documentation/roomplan/capturedroom/identifier) as a framework-assigned UUID, and [`init(from:)`](https://developer.apple.com/documentation/roomplan/capturedroom/init(from:)) as deserialization. Those docs do not promise identifier stability across separate decodes of these older artifacts. The native result establishes that the UUID differed for each of the two independently decoded sample pairs. Treating this value as decode-local metadata for these artifacts is therefore justified; asserting that every SDK must always generate a different UUID would not be justified.

The production diagnostic adapter copies `room.identifier` into `capturedRoomID`. That metadata-copy contract remains tested, now using `extract(room, frame:)` on the **same** decoded native instance. It is not replaced with a hash-derived or invented identifier, and no runtime behavior is altered.

### Production-use audit

- `SavedRoomDiagnosticGeometryProvider` admits source bytes by `frame.roomCaptureSHA256`, then publishes only for exact selected `SavedWorldFrame`, memory owner and deletion generation; its final check is `geometry.frame == work.source.frame`.
- `NavigationTestRecordingView` and `NavigationTestRecording.sameFrameSegments(for:)` join historical geometry/camera samples by the exact saved frame, not `capturedRoomID`.
- `SavedRoomDiagnosticGeometry.capturedRoomID` is stored/encoded metadata. Synthesized whole-value `Equatable` naturally includes it, but no production consumer found compares independently decoded whole geometry values as a stable identity key. The new regression compares the stable fields explicitly.
- `PlaceStore` also records baseline/measured native room IDs in registration acquisition metadata. The acquisition gates use saved frame, source owner, scan/session/time, and explicitly chosen feature correspondences, not cross-decode room-ID equality.
- The concurrently authored `SavedRoomRouteMeshSnapshot` likewise retains this value only as metadata. Its owner confirmed source/route association uses `sourceSHA256` plus original floor/feature UUIDs; no cross-decode room-ID assertion exists there.

## Minimal repair and retained strength

Only the hosted fixture test and its Node source contract change:

1. Keep native `CapturedRoom` decoding and production decoder execution. Assert all six native surface/object counts against fixed source counts.
2. Verify metadata copying against the same native instance, then compare production output with that extraction's complete feature array.
3. Retain all original hash, frame, feature-ID, category, full transform, original dimensions, polygon and independently calculated world-witness assertions.
4. Add a fifth hosted method: decode each untouched original twice with the same synthetic test descriptor, require absence of a root source UUID and equality of frame/hash/story/counts/complete features/polylines. Neither equality nor inequality of framework-assigned room UUIDs is required.
5. Add a source contract with four negative mutations rejecting a return to separate-decode UUID equality, loss of same-instance provenance, whole-geometry equality, or loss of stable digest checking. It also checks the actual provider/view still use frame bindings rather than `capturedRoomID`.

**Executed locally:** 11/11 bounded Node fixture+geometry checks passed (`node-regression.tap`), including eight total negative mutations in the fixture test file (four original-field checks plus four new identifier-contract checks).

**Independent review:** `review_recorded_route_preview` found no source blocker in the contract repair and independently reran the five focused fixture Node checks, all passing. The original failure receipt and stable-source versus same-instance metadata distinction were reviewed; this is not a native rerun.

**Not yet executed:** repaired five-method Apple hosted fixture suite. Root publishes the independently reviewed source and obtains a fresh exact-revision native result. The original three passing methods do not prove the modified method or new regression passes.

The `SavedWorldFrame` descriptor remains explicitly synthetic test metadata, not a real paired world map or recovery receipt. This repair does not claim current room identity, camera/body accuracy, clearance, physical guidance or child-trial readiness.
