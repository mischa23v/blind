# Existing-workflow transport for public same-export comparison assets

## Scope

This layer adds transport for the user-authorized same-data OpenUSD comparison,
not a production importer change or a claim that the room geometry is correct.
The source producer and dedicated binary extractor are separate reviewed layers.
Only the original public Apple `Hallway2` and `Bedroom3` fixture-derived diagnostic
exports are eligible. No private room, camera frame, photo, full result bundle,
full test log or arbitrary attachment is admitted by this workflow addition.

The existing early reporting block retains its **three-minute total limit** and
now runs the new bounded extractor after the original aggregate-summary writer
and case-status exporter. The new extractor consumes their completed,
source-verified same-commit case record; it must not bypass that dependency.
Its exact test is
`SavedRoomRouteMeshAppleFixtureTests/testOriginalAppleSameExportForOpenUSDComparison`.
This single test contains both original public fixtures. Failed test verdicts are
retained, not promoted to passing just because comparison assets can be recovered.

```sh
python3 tools/ci/export-public-apple-same-export.py "$out/unit.xcresult" \
  "$out/unit-case-statuses.json" "$out/public-apple-same-export" || true
```

One new upload action follows the existing unit-case upload, before UI. It retains
the existing pinned upload action and three-day retention, with seven exact paths:

1. `APPLE_ROOM_ROUTE_Hallway2_SAME_EXPORT.usdz`
2. `APPLE_ROOM_ROUTE_Hallway2_SAME_EXPORT_METADATA.bin`
3. `APPLE_ROOM_ROUTE_Bedroom3_SAME_EXPORT.usdz`
4. `APPLE_ROOM_ROUTE_Bedroom3_SAME_EXPORT_METADATA.bin`
5. `APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json`
6. `APPLE_ROOM_ROUTE_SAME_EXPORT_MANIFEST.json`
7. `receipt.json`

All paths are under the fixed runner-temp directory
`blind-native-ci/public-apple-same-export`. There is no new wildcard or directory
upload. The artifact is `public-apple-same-export-${run_id}-${run_attempt}`.
The extractor contract caps each USDZ at 4 MiB, each metadata file at 64 KiB,
inventory at 128 KiB and manifest at 16 KiB, with a separately bounded receipt.
The owned attachment-export subprocess has a 15-second limit and a bounded
temporary export directory. Binaries and the complete manifest are published only
after exact fixture identity, source provenance, sizes, all hashes and inventory
binding validate. Failure can preserve a sanitized receipt, never partial or
unverified binary assets. An artifact containing only a failure receipt is not a
successful export or geometry comparison.

The added command retains reporting-only `|| true`, while the extractor records
its own success/failure. It does not change any native test verdict. The total
existing reporting deadline is not increased; runner loss or exhaustion of that
deadline can still leave no asset artifact. The parent monitors actual CI rather
than treating these source checks as an availability guarantee.

## Exact layering and checks

- **24 workflow source/shell/inverse checks passed** in `source-verification.json`.
  Removing only the added command and exact upload block recovers every original
  workflow byte. Existing jobs, triggers, permissions, runners, concurrency,
  native-test commands, conditions, deadlines and summary remain unchanged.
- **67 existing integrated stage85 checks passed** in
  `integrated85-verification.json`, including the coherent classification/timing
  pins. Only the workflow entry changes in `SOURCE_PINS.json`.
- **15 real-extractor tests passed on independent review**, including execution
  of this actual full reporting shell: summary writer → case exporter → exact-test
  binary extractor. External Git/xcresult replies and USD ZIP payloads are synthetic;
  the exporters, count reconciliation, public-fixture admission and atomic output
  code execute unchanged. Cases cover the complete seven-file result, incomplete
  case evidence, absent exact test, preserved failed verdicts, malformed/oversized
  payloads, source changes and interruption before atomic publication. The upload
  paths/caps also match the actual collector and dedicated producer declaration;
  see `interlayer-verification.json`. The separate extractor layer and its tests
  must accompany publication. This is not a real native attachment export or
  verified GitHub artifact delivery.
- No native Apple SDK tests, workflow dispatch, uploads or publication were
  performed by this workflow task.

```sh
python3 research/public-fixture-export-workflow-20261028/check.py
python3 research/native-candidate-app-integration-85/integrated/check.py
```

The frozen parent pin manifest already contains the classification-ingress and
classified-timing work. It is retained unchanged with SHA256
`4790530fe65ee2280ae3946c223e1878a1beda7e1ba8f41ffe23a5c403182a2f`; its prior
classification publication receipt remains historical to that parent layer.
`workflow.patch` and `workflow.inverse.patch` reconstruct the exact two-file
child/parent states in a disposable directory. Earlier reporting-order and
missing-summary evidence packages are not rewritten.

Candidate workflow SHA256:
`d5d9d483e138803d4c952976fe0bfa531946f8f0ebffe198abb0d08a9d3b799b`.
Candidate integrated pin manifest SHA256:
`a65951fece8fc480feac441138a80dfc782a8d813880c3db0b8d10892e4c152e`.

Only root may publish. Use this layer's `publication-manifest.json` together with
the separately reviewed producer/extractor manifests; a standalone workflow push
would refer to an unavailable extractor and is not a complete stage.
