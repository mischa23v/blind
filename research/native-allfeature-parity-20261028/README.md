# Bounded native all-feature geometry capture candidate

Prepared 2026-10-28. This is authored Apple test instrumentation and locally tested evidence validation, **not a native run or a parity success**.

The original public `SavedRoomRouteMeshAppleFixtureTests/testOriginalAppleSameExportForOpenUSDComparison` now requests an optional `meshParity` field in its already hash-bound inventory. No extra attachment, workflow or byte-limit increase is introduced. The normal metadata-inventory test does not request this field.

Each raw diagnostic Model I/O mesh records its inventory node index, original public feature UUID, local/global matrix, local/world positions and ordered triangle indices. Float32 matrices and positions are encoded as exact unsigned 32-bit words. This avoids decimal loss and reduces space. Triangle winding is retained, never repaired. There is no claim that capture validity proves source-scale accuracy or independent-reader agreement.

Capture is admitted only after the existing exact hash check for the two unchanged official Apple fixtures. It runs on diagnostic export #2, whose USDZ and metadata bytes are attached and rechecked before cleanup. The separate production adapter export #1 is not claimed byte-identical. Captured geometry is unrelated to any corrected route-support representation.

## Bounds and semantics

- Existing inventory cap remains 131,072 bytes; existing six-attachment manifest and seven-file published artifact remain unchanged.
- At most 64 meshes, 1,024 vertices and 1,024 triangles per fixture; all inventory mesh nodes must be represented, with known exact UUIDs.
- No truncation. Oversize/incomplete data fails the test/capture rather than reporting a partial set as complete.
- Collector validates closed field schemas, exact UInt32 words, finite bounded values, affine matrix shape, node/identity/count association, index ranges, and world/local point arithmetic under the existing Float32 roundoff allowance.
- The validator deliberately retains internally coherent source-scale or winding mistakes for independent comparison. It does not convert a correct-looking capture into a physical-clearance or import-parity verdict.
- The later comparator must use the exact attached USDZ, account for USD orientation/coordinate conventions and compare complete per-feature geometry, including ordered triangle winding and duplicate counts. Matching only bounding boxes is insufficient.

A conservative compact-JSON serialization size proxy using the currently captured 24 meshes, 1,132 vertices and 570 triangles, maximally long decimal UInt32 words and four-digit indices, is **121,592 bytes**, 9,480 below the unchanged inventory cap. This is not actual Swift serialization or a native test result; a future native export must still satisfy its real cap.

## Local verification

- 77 bounded Python collector tests passed, including seven new capture-schema and mutation tests.
- 17 bounded same-export extractor/workflow integration tests passed, including two new inventory-hash binding and invalid-parity tests.
- Six separately authored historical-support Swift tests from the parent candidate are appended to the already registered Apple fixture source file. They are not executed here.
- Existing original floor concavity/area/boundary test body is unchanged.
- No Swift/Xcode execution is available locally. Apple compilation, all-feature capture completeness, actual inventory size and independent comparison remain pending.

The integration tests execute the existing workflow shell and real Python exporters with bounded synthetic Git/xcresult responses. They do not run Apple framework exports or establish clean repository provenance on a Mac.
