# Exact-public-export capture for independent comparison — 2026-10-28

## Purpose and current status

The user requested comparison with proven upstream code using the data already
tested, with scale, dimensions and spacing preserved before any performance
reduction. The parent authorized an independent OpenUSD reader. Earlier native
tests deleted their temporary USDZ/metadata after inspecting them, so those old
assets cannot be recovered or honestly recreated byte-for-byte.

This increment prepares a **new paired-input capture** from the same unchanged
public Apple Hallway2/Bedroom3 source fixtures. It retains the exact diagnostic
USDZ and metadata that its Model I/O inventory/probe read, allowing OpenUSD to
read those identical bytes. It does not claim any OpenUSD comparison result yet.
No geometry acceptance, epsilon, dimension, spacing, frame rate or production
adapter behavior is changed.

## Exact provenance boundary

The new allowlisted XCTest is:

`SavedRoomRouteMeshAppleFixtureTests/testOriginalAppleSameExportForOpenUSDComparison`

It shares the existing `exportInventory` helper. For each original public
fixture, that helper first invokes the production adapter, which makes and
deletes its own export. It then creates a separate diagnostic export, imports
**that same URL** through Model I/O and records the existing inventory/bounds
probe. The latter diagnostic export is the retained paired-reader input.

The manifest explicitly records `exportRole=diagnostic-export` and
`productionAdapterExport=separate-unretained`. It must not be interpreted as
showing that the initial production adapter consumed these exact bytes, nor as
proving deterministic or byte-identical RoomPlan export between invocations.
The paired comparison applies to this new test's diagnostic asset and inventory,
not the separately executing older inventory test's temporary asset.

The new comparison test's pass means capture/inventory admission succeeded. Any
production `adapterFailure` remains in the hash-bound inventory. That test does
not turn a successful artifact capture into passing geometry or routing.

## Capture and bounds

- The original fixture ID/SHA pair and source byte limit are checked **before
  every decode/export**, including when retention is requested. Replaced input
  cannot produce a raw asset attachment.
- The new test opts into retention explicitly; the existing inventory test
  defaults to `retainSameExport=false` and still attaches only its existing JSON.
  This preserves the old strict JSON collector and its size limits.
- Only regular files are read. Each USDZ is nonempty and at most 4 MiB; each
  exact metadata file is nonempty and at most 64 KiB. Size is checked before and
  after reading. The same retained metadata bytes drive node-name/UUID decoding.
- USDZ and metadata bytes are read before Model I/O imports the same `meshURL`.
  At scope exit, the files are re-read under those bounds and compared byte for
  byte. Retention succeeds only when both remain unchanged. This check runs
  before the existing temporary-directory removal, also on importer failure.
- Raw bytes live in separate **non-Encodable** `SameExportAssets` /
  `InventoryCapture` wrappers. They cannot be accidentally embedded as base64 in
  the existing inventory JSON. They are attached only by the new comparison
  test, with fixed names for the two admitted public fixtures.
- Inventory remains capped at 131,072 bytes and the manifest at 16,384 bytes.
  There are exactly six intended attachments: inventory, manifest, two USDZs and
  two metadata binaries. The bounded extraction integration is separately owned;
  no new workflow is added by this change owner.

## Attachment contract

Common attachments:

- `APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json`
- `APPLE_ROOM_ROUTE_SAME_EXPORT_MANIFEST.json`

For each fixture ID `Hallway2` / `Bedroom3`:

- `APPLE_ROOM_ROUTE_<fixtureID>_SAME_EXPORT.usdz`
- `APPLE_ROOM_ROUTE_<fixtureID>_SAME_EXPORT_METADATA.bin`

Manifest schema is `blind.saved-room-route-same-export.v1`. It contains exactly:

- `schema`, `physicalAuthority=false`, `exportRole`, `productionAdapterExport`
- fixed `testIdentifier`, fixed `inventoryAttachmentName`, `inventorySHA256`
- `fixtures`, exactly the two admitted original public source identities

Each fixture record contains exactly `fixtureID`, `sourceSHA256`,
`assetAttachmentName`, `metadataAttachmentName`, `assetSHA256`, `metadataSHA256`,
`metadataFormat`, `assetByteCount` and `metadataByteCount`. Hashes are calculated
from the actual retained bytes. The manifest's inventory hash covers the exact
JSON bytes attached by this same test. The independent reader must verify this
manifest/test/source/asset/metadata/inventory chain before comparing results.

Original-source admission remains:

| Fixture | SHA-256 |
| --- | --- |
| Hallway2 | `f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d` |
| Bedroom3 | `44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e` |

These are public original Apple test fixtures, not user room scans. No private
input, photo, new live capture, asset substitution or geometry reconstruction is
admitted. Temporary files remain excluded from backup and are deleted.

## Checks actually performed

- Preserved the previous frozen probe sources in
  `/tmp/blind-same-export-baseline/` before editing.
- Confirmed production `SavedRoomRouteMeshAdapter.swift` is byte-identical to
  that baseline (SHA-256
  `00607603fa3725182a1bfa809eeb880b9930b6654fd29ca92c96f59951789983`).
- **17 lightweight source checks passed**: production unchanged; exact public
  SHA before export; separate test/default-no-retention; non-Encodable raw data;
  regular-file/size checks; per-file caps; read-before-ModelIO and byte comparison
  after traversal; retained metadata used for mapping; manifest/inventory digest
  and separate-production-export labels; manifest/inventory caps; rejected-source
  capture nil; regression presence; unchanged bounds test; clean whitespace.
- The changed-original-SHA regression now requests retention and asserts it
  produces no raw capture. A small synthetic file regression checks the exact
  read limit and rejects empty, oversized and non-regular inputs.
- **Native compilation/new XCTest execution are unrun here**: this executor has
  no Swift compiler/Xcode/Apple SDK. No retained assets or comparison results have
  been generated by this change owner yet. Parent owns publication, native run,
  extraction and the independent reader's eventual results.
- No new dependency installation, workflow, private upload, push or physical
  guidance enablement was performed by this change owner.
