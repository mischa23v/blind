# Saved-room mesh metadata diagnosis — 2026-10-28

## Result and remaining blocker

The native `missingMetadata` failure does not identify its cause. At base commit
`dc32a9bad9a75566f27924fb9f7aa8fe50a46e95`, that one error covers metadata file
read/JSON decoding, empty/invalid entries, an unmapped Model I/O mesh node and a
mapped UUID absent from the original surface/object feature inventory. The
existing [native run 40677832625](https://github.com/mischa23v/blind/actions/runs/40677832625)
blocked all 18 route and 16 journey stages there, before route/collision success
could be established. The task's independent native-evidence review also found
the three original mesh fixture tests failed at the same conflated error.

This increment improves diagnosis and fixes the test fixture admission guard.
It does **not** claim a native geometry, routing, guidance or collision fix.
The exact metadata/node mismatch is still unknown until a fresh Apple run
retains the new bounded inventory attachment.

## Implemented, without guessing an identity

- Production errors now distinguish `metadataReadFailed`,
  `metadataDecodeFailed`, `metadataEmpty`, `metadataInvalidEntries`,
  `meshNodeMissingMetadata` and `metadataUnknownFeature`. They contain no room
  name, UUID, path, metadata value or other private-room data.
- The documented flat `[String: UUID]` decoder and exact `node.name` followed by
  inherited identity matching are unchanged. Unknown geometry remains rejected.
  No inverted/nested parser fallback, path rewrite, geometric proximity match,
  section omission, winding repair or clearance inference was added.
- Test fixture loading previously only asserted the original SHA, so execution
  could continue and export substituted bytes after a failing assertion. It now
  throws before export. The diagnostic worker independently admits only the two
  hard-coded fixture ID/SHA pairs before any decode/export. A changed-but-still-
  valid JSON regression checks that no adapter/export inventory is attempted.
- `testOriginalAppleExportMetadataAndNodeInventory` executes the real adapter
  first, then a **separate** same-input Apple `.mesh` export and Model I/O import
  for diagnosis. The reports are not claimed to describe the same exported
  artifact or prove exporter determinism. No diagnostic API was added to the app.
- Both fixture reports are attached before adapter/inventory failure assertions,
  using `APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json`, schema
  `blind.saved-room-route-mesh-metadata-inventory.v1`, `physicalAuthority=false`.
  The collector change is owned separately and validates this exact attachment.

## Inventory/privacy bounds

Only original bundled public Apple Hallway2 and Bedroom3 data are admitted:

| Fixture | SHA-256 | Original features |
| --- | --- | --- |
| Hallway2 | `f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d` | 1 floor, 6 walls, 6 doors |
| Bedroom3 | `44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e` | 1 floor, 4 walls, 2 doors, 1 window, 3 objects |

The report is at most 131,072 bytes. Each fixture accepts at most 1 MiB metadata,
32 MiB USDZ, 4,096 traversed nodes and depth 64; at most 64 metadata rows and 128
node rows are emitted. Truncation is explicit. These acceptance bounds do not
bound Apple's internal exporter/importer allocations.

Metadata format is a content-free `unread`/`json`/`binaryPlist`/`xmlPlist`/`unknown`
signature classification, not an alternate parser. This can distinguish a plist
export from malformed/unknown bytes without another raw-content upload.
Metadata rows report root/value kinds, sanitized keys and UUIDs only when they
are identifiers already present in the original public fixture's feature list.
Nodes report parent/depth, mesh-versus-group type, bounded vertex/submesh counts,
direct/inherited mapping presence and known original-feature identifiers. No
vertex/index buffers, dimensions, transforms, images, coreModel, arbitrary
non-UUID values, private room input or export paths are attached. Unknown UUIDs
are omitted, while mapping-presence flags preserve the distinction between
missing and unknown identities. Node names/keys are limited to 1–128 ASCII
letters/digits/space/underscore/period/hyphen or replaced with `<redacted>`.
SHA-256 of the original key/name supports equality checks after redaction.
Temporary export directories are protected, excluded from backup and removed.

Each original source has one section, whose JSON contains only `center`, `label`
and `story`, not an identifier. Apple's section-center export or importer name
changes remain hypotheses. The inventory does not invent a section UUID or
silently classify an unknown mesh as a section, obstacle or floor.

## Platform evidence

- Apple's [WWDC23 RoomPlan session](https://developer.apple.com/videos/play/wwdc2023/10192/)
  describes an encoded String-to-UUID dictionary relating unique USDZ node names
  to CapturedRoom element identifiers. It also describes section-center nodes.
  This supports retaining the current map direction; it does not establish what
  this native run actually produced or how Model I/O named imported nodes.
- Apple's [export API](https://developer.apple.com/documentation/roomplan/capturedroom/export%28to%3Ametadataurl%3Amodelprovider%3Aexportoptions%3A%29)
  documents the metadata URL, optional model provider and export options. The
  adapter continues to use `.mesh` and no model provider.
- No new upstream package, dependency, framework, model or workflow is adopted.
  RoomPlan/Model I/O/CryptoKit remain Apple platform APIs under the Apple SDK;
  the original public-fixture provenance/license record is unchanged.

## Verification actually performed

- Restored only the two owned Swift sources from the exact base commit through
  the GitHub connector. Read root AGENTS and required design/progress/architecture
  context; no more-specific AGENTS was found at the relevant source/research
  paths. Other agents' files were not overwritten.
- Independently recomputed both original public fixture hashes from fetched
  bytes and inspected feature counts/section field names.
- **18/18 lightweight Python source checks passed**: documented parser and
  identity rule retained; no ambiguous throw; all six stage errors present; no
  production diagnostic logging; test-only inventory; digest admission before
  export; both public digests; changed-fixture regression; attachment byte bound
  and retention before assertions; no geometry buffers; metadata/node/traversal
  bounds; unknown UUID omission; temporary cleanup; no trailing whitespace.
  These are text/contract checks, not Swift compilation or XCTest execution.
- A further bounded-format-signature source contract passed after independent
  review; digest admission and whitespace were rechecked. Independent source
  review found no blocking issue. The producer's field/count/inheritance and
  optional-UUID conventions were crosschecked against the separately owned
  collector validator; native attachment generation is still unexecuted.
- **Native compile/XCTest not run:** this Linux executor has neither `swift` nor
  `xcodebuild`/Apple SDK. The two new test methods and the changed adapter require
  fresh Apple compilation/execution. Existing native failures remain open.
- No install, workflow creation, private upload, push, physical guidance enablement
  or child/device trial was performed by this change owner. Root owns publishing
  and the authorized native-run continuation.

## Next evidence required

Run the existing Apple test workflow for the exact new commit, retrieve the
allowlisted inventory and granular adapter failure, then fix only the now-proven
mapping/export defect. Re-run the unchanged route, independent collision and
journey assertions afterward; successful diagnosis alone is not route success
or evidence of live localization, current support/clearance or safe physical use.
