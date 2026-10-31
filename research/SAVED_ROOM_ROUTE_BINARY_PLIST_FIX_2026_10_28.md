# Saved-room metadata binary-plist repair — 2026-10-28

## Proven cause and narrow repair

[Native run 40698547633](https://github.com/mischa23v/blind/actions/runs/40698547633)
at `6fe9d52` produced the bounded, SHA-bound public-fixture inventory preserved in
[`native-path-recovery-20261028/run40698547633`](native-path-recovery-20261028/run40698547633/).
Hallway2 metadata was **707 bytes, binaryPlist**; Bedroom3 metadata was **608
bytes, binaryPlist**. Both failed `metadataDecodeFailed` because the adapter
used `JSONDecoder` despite the export's binary-plist signature. The metadata
filename `.json` did not determine Apple's actual wire format. All 18 routes
and 16 journey stages remained blocked; none passed by this observation.

The complete node inventory contained 27 nodes/13 meshes for Hallway2 and 26
nodes/11 meshes for Bedroom3. `Section_grp` and its descendants were not meshes.
The earlier section-mesh hypothesis is disproven for these exact exports; it is
not a reason to omit geometry or accept unknown identities.

`SavedRoomRouteMeshAdapter.decodeMetadata(data:)` now:

1. Rejects empty data and more than 1 MiB before decoding.
2. Selects Apple's `PropertyListDecoder` only for the observed `bplist00` wire
   signature, decoding the documented flat `[String: UUID]` map.
3. Retains the earlier flat JSON-object input with an explicit first
   non-whitespace `{` check and `JSONDecoder`.
4. Rejects other formats, malformed/wrong-shaped data, invalid UUIDs, an empty
   map, more than 4,096 entries, empty names and names over 512 UTF-8 bytes.

No catch-and-retry alternative parser, inversion, nested-map accommodation,
name/path rewriting, section filtering or geometric proximity matching was
added. Exact node-name/inherited identity checks, known-original-feature
membership, all geometry bounds, source digest guards and no-physical-authority
boundaries remain unchanged. Errors remain content-free and use the existing
allowlisted failure cases. XML plist remains unsupported in this narrow repair.

## Diagnostic/test changes

The public-original-only inventory uses `PropertyListSerialization` solely to
inspect bounded binary-plist root/entry kinds, then calls the same production
flat decoder for node associations. No raw metadata values or geometry are
emitted. Existing schema/name, public source hashes, sanitized names/hashes,
known-source UUID-only output, traversal/sample/attachment bounds and temporary
cleanup are retained. Binary parse errors report `invalidPropertyList`.

Collector ownership is separate: it accepts decoded shape kinds for
`metadataFormat=binaryPlist`, retains prior binaryPlist/invalidJSON evidence and
permits `invalidPropertyList` only for binaryPlist. No privacy/budget widening or
new workflow is required.

Native inventory assertions now require a supported format, an object root,
nonempty metadata/mesh counts and zero unmatched/unknown-feature meshes. They
are evaluated **after** the attachment is retained, so later geometry failures
still leave metadata evidence. This is a planned native verification, not a
claim that it already passed.

Two focused XCTest methods were added:

- `testFlatMetadataDecoderPreservesPublicUUIDsForBinaryPlistAndJSON`: bounded
  synthetic serialization of both unchanged public fixtures' UUIDs through
  `PropertyListEncoder` and `JSONEncoder`; checks exact flat-map roundtrip and
  JSON whitespace handling. Synthetic keys are labelled as such, not presented
  as original exporter associations.
- `testFlatMetadataDecoderRejectsMalformedWrongShapeAndUnsupportedFormats`:
  17 rejection cases covering empty/truncated/unknown bytes; wrong roots;
  nested/non-UUID/non-string values; empty/oversized keys and maps; XML; invalid
  JSON shape/UUID; and the source-byte limit. An accepted 512-byte UTF-8 key
  checks the boundary separately.

## Evidence and verification limits

- Re-read both owned sources at `6fe9d52` through the GitHub connector and the
  actual preserved native inventory before editing. Other owners' files and
  historical reports were not overwritten.
- **16/16 lightweight source contracts passed** for byte-selected platform
  decoding, predecode bounds, strict identity, shared inventory decoder,
  original-SHA admission, test presence, attachment bound, no production logging
  or dynamic property-list parser, and whitespace. These are not Swift tests.
- Recomputed both original fixture SHA-256 values and used Python `plistlib` for
  bounded synthetic public-UUID binary-plist roundtrips (Hallway2 865 bytes,
  Bedroom3 737 bytes). This validates fixture/format preparation, **not** Apple's
  `PropertyListDecoder`, the native export metadata or mesh association.
- The collector owner reports **54 collector + 31 status-exporter + 6 early-order
  tests passing** for its separate integration changes. Producer/collector
  format/root and failure contracts were crosschecked.
- **Swift compile, new XCTest methods and corrected real-export decoding have
  not run here:** this Linux executor has no Swift/Xcode/Apple SDK. Root owns
  publication and the next exact-commit native run. Routing, guidance, collision
  and live-device safety remain unproven until their independent assertions pass.
- No install, workflow creation, private upload, push or physical-guidance
  enablement was performed by this change owner.

Apple's existing [PropertyListDecoder](https://developer.apple.com/documentation/foundation/propertylistdecoder)
is the platform decoder, not a new dependency. The [WWDC23 RoomPlan export
description](https://developer.apple.com/videos/play/wwdc2023/10192/) supports the
flat node-name-to-UUID map; the **actual native inventory**, not a guessed schema
or filename, established this repair's binary wire-format selection.
