# Isolated selected-PDF native adapter probe — inert packet

**Prepared, not natively run.** This directory adds no app feature, executable
workflow trigger, production controller edit or release authorization. Publish it
only as a reviewed test packet; the root task owns any hosted invocation.

Local preparation checks: four Node snapshot/generator/isolation contracts and
eight Python exporter checks pass; JavaScript, shell and Python syntax checks pass.
Exporter checks mock xcresulttool and do not run Apple tools. An initial contract
regex incorrectly matched the explanatory words “never export … attachments”;
that test-only assertion was corrected, with the first failure retained. These
checks do not establish native compilation, test discovery or any of the fourteen
actual PDFKit test outcomes.

## Exact candidate snapshots

`source-pins.json` records SHA-256 and original candidate path for exactly:

1. `Sources/SelectedDocumentPDFAdapter.swift`
2. `Sources/SelectedDocumentPicker.swift`
3. `Tests/SelectedDocumentPDFTests.swift`

Each is byte-identical to the separately staged feature candidate. The generator
checks all three hashes before copying. It preserves `@testable import BlindAssist`
by naming the minimal host module `BlindAssist`, while using the distinct bundle
identifier `org.blindassist.selectedpdfprobe.host`. That name does **not** mean the
production app is included. The host consists only of a blank SwiftUI scene and
the two copied adapter/picker sources. No Core/GRDB/model package, app controller,
Feedback, camera, microphone, private storage or application entitlement is linked.

The project follows the successful scene-backed reading-component host structure,
including **ONLY_ACTIVE_ARCH=YES**, no hardcoded architecture, a dependent hosted
unit-test target, no parallel execution and no package dependencies. Importing
system PDFKit/UIKit/CryptoKit does not prove these new sources build; that remains
the purpose of the native run.

## One native invocation

The intended published path is
`tests/scenarios/integrated/selected-document-native-probe/`. On the owned public
hosted `xcode-27` runner, after checking out the reviewed packet commit with
persisted credentials disabled, invoke once:

```sh
bash tests/scenarios/integrated/selected-document-native-probe/run-native.sh "$GITHUB_WORKSPACE"
```

The runner requires `RUNNER_ENVIRONMENT=github-hosted`, the checkout HEAD to equal
`GITHUB_SHA`, a clean packet, Darwin and SDK 27.0. The activating workflow must
also require the owned public repository and reviewed `xcode-27` runner. If that
runner reports a different hosting classification, stop and independently verify
its exact identity; do not silently weaken the hosted-only boundary.
It creates exactly one new **iPhone 18 Pro Max / iOS 27.0**
simulator, waits for its real boot status (120-second bound), then issues one
fixed `xcodebuild test` command targeting only `SelectedDocumentPDFTests`.
Missing preinstalled runtime/SDK fails: there is no runtime/font/model download.
The owned xcodebuild process group has a 600-second bound; XCTest also has fixed
60/90-second per-test allowances. No retry, alternate destination, skip or
substitute success is permitted. Cleanup shuts down/deletes only the UUID this
invocation created. A workflow-level limit of 15 minutes is required in addition.

Success requires the real result summary to report **14 total, 14 passed, 0 failed,
0 skipped**, and an exit status of zero. Compilation/discovery failure and a
missing/malformed summary cannot be counted as passing tests.

## What is actually exercised

The unchanged native test file generates actual PDF bytes in memory and invokes
the production PDFKit adapter. It covers English, Arabic/mixed numerals, explicit
multipage indexing, image-only pages, malformed/locked files, independent copy
versus accessibility permissions, encoded/page-text oversize, columns, source
replacement and `NSMutableData` alias isolation. It also directly invokes the
production picker delegate's single-result/cancel methods.

There are no downloaded PDF/font fixture files or bundled binary resources. The
tests use authored text and system fonts. Native PDF generation/extraction is not
injected Core text-block testing; direct delegate calls are **not actual system
picker presentation, document-provider selection or an OS-granted scope**.

## Bounded evidence only

If activated, upload **only** files in
`$RUNNER_TEMP/blind-selected-document-probe/artifacts/`:

- `receipt.json` — exact source pins, native counts, exit code and explicit scope;
- `toolchain.txt`, `owned-simulator.txt`, `test-exit-code.txt`;
- bounded `.txt` tails (at most 32 KiB each) for the three known diagnostic logs.

Do not upload `DerivedData`, `.xcresult`, arbitrary attachments, simulator data,
the generated project, PDFs, font files or raw test logs. The exporter reads only
bounded log tails and selected summary counts; it does not export attachments.
Native system framework diagnostics may mention authored fixture content; no
user document or user provider URL is supplied to this packet.

## Explicit limits

Even a passing run does not establish NavigationModel/Feedback integration,
60-second acquisition ownership, private-route/session retirement, ordinary
budget wakes, live picker dismissal/grants, security-scoped provider access,
speech or VoiceOver callbacks, audible usefulness, participant comprehension,
manual/model binding, appliance operation or R39/R40 completion. The app/controller
projection and actual device/participant gates remain separate. The packet does
not activate the selected-PDF feature in the production app.
