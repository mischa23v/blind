# Bounded public Apple route evidence export

Source-only support for the existing native Apple lane, 2026-10-28. This is not a
native path, guidance, collision, localization, get-up-motion or safety result.

## Scope and destination

`tools/ci/export-native-unit-statuses.py` retains its CLI, schema 1 case statuses,
aggregate reconciliation, target witness/provenance checks and exit semantics.
Its existing `unit-case-statuses.json` gains separate `routeDiagnosticEvidence`.
No workflow, artifact activation, shell runner, app or Swift test was changed.
The established workflow already uploads this same file after UI completion.

The helper selects three exact existing case identifiers from that case tree:

- `SavedRoomRouteDiagnosticAppleTests/testPredeclaredApplePathsWaypointSinkAndIndependentFullBodySweeps`
- `SavedRoomRouteDiagnosticAppleTests/testSeparatelyPreregistered28cmWidthDoesNotReplaceBaseline`
- `SavedRoomRouteJourneyAppleTests/testPredeclaredSuppliedBedChairConnectorsAroundRoomDoorWithholdingAndReturn`

An optional exact `BlindAssistTests/` prefix and `()` suffix are accepted, never
arbitrary prefixes or parameterized descendants. Every export command passes
that observed identifier via `--test-id`; there is no suite/all-test export,
`--only-failures`, retry, replacement outcome or change to test verdicts.

`xcresulttool export attachments` uses the established modern API/manifest
pattern from the existing UI exporter and Chromium's Xcode16LogParser:
https://chromium.googlesource.com/chromium/src/+/HEAD/ios/build/bots/scripts/xcode_log_parser.py
Apple documents this command family in its Xcode 16.3 release notes:
https://developer.apple.com/documentation/xcode-release-notes/xcode-16_3-release-notes
No legacy payload API or guessed object schema is used.

## Privacy and validation

Only the exact authored report basename (plus xcresulttool's optional generated
index/identifier suffix) is accepted for that test:

- `APPLE_ROOM_ROUTE_original-baseline_OUTCOMES.json`
- `APPLE_ROOM_ROUTE_width28-addendum_OUTCOMES.json`
- `APPLE_SUPPLIED_POSTURE_JOURNEY_OUTCOMES.json`

Per-test exports are in private temporary directories, removed on success and
failure. Unknown attachments reject collection; their contents are never opened
or included. No screenshots, private history, audio or model output is published.
Any type/size metadata present in the export manifest is checked. Only flat,
non-symlink regular `.json` files are opened. No raw manifest, arbitrary filename,
OS error path or subprocess output is retained in the public result.

The helper checks the unchanged three protocol SHA256 values and two original
public Apple source SHA256 values against repository bytes. Full schedule
accounting remains 12 baseline + 6 width-addendum + 16 journey stages, including
unexecuted/failed stages. Known source UUIDs, fixed outcome identifiers, exact
false physical-authority/coverage flags, strict field allowlists and finite
numeric vectors are required. Guidance receipts must match the independently
scored segment and fixed production-formatter grammar; arbitrary text is denied.
Known authored error codes/text are retained; unknown error strings fail closed.
Original attachment hashes/byte counts accompany the validated JSON structures.
Source/test/formatter hashes and the existing before/after clean-commit check
establish provenance without exporting source code or fixture geometry blobs.

`status: complete` means all three reports were collected and validated, not
that any XCTest passed, a candidate arrived, a real person was localized, a
get-up transition was modeled or physical guidance is authorized. Every native
case result is retained separately and may be `Failed` with complete evidence.

## Bounds and failure behavior

- Each export has a 30-second timeout; the entire owned process group is retired.
- Child file-size limit is 1 MiB. At most eight flat regular export files and
  1 MiB + 64 KiB total temporary export bytes are accepted; the extra allowance
  is only for the bounded manifest. These aggregate/count checks are monitored
  every 50 ms and checked again after exit, not a claim of atomic disk quotas.
- Raw accepted report bytes across all three tests are at most 1 MiB.
- Existing published artifact remains at most 1 MiB. If additive reports exceed
  it, their data is omitted with explicit `artifact_over_budget` status before
  any original case metadata is considered. Compact serialization can preserve
  whitespace-limited case data. The prior base-artifact failure fallback remains.
- Missing/duplicate tests/reports, unsupported export/schema, unexpected files,
  source mismatch, nonfinite values and over-budget results are explicit evidence
  statuses. None changes the original case verdict, target witness or script exit.
- If final source provenance fails, the collected route reports are discarded.

## Verification

Run only the bounded Python fixtures (standard library, no build/install):

```sh
python3 tools/ci/test-native-unit-statuses.py
python3 tools/ci/test-native-route-diagnostic-evidence.py
```

The latter includes a real subprocess CLI stub recording exactly three `--test-id`
commands and verifying temporary deletion. Other fixtures exercise schema/source
pins, all schedules, failed-case retention, artifact budget, malformed manifests,
traversal, symlinks, unexpected attachments, privacy/model-text denial, nonfinite
vectors and code-guidance/segment association. These synthetic tests do not
establish native xcresulttool compatibility; the first exact Apple CI run must
check the separate collection status as well as native results.
