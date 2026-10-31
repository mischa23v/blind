# Native Apple same-export capture: run 40721822359

**Terminal failure**, exact source `4eb0d10f1724bce3ef2f6e6a8ff8ae35a06b85e6`, tree `7b7074133c219b83c3d919bfa48aeac1d5da49f1`; completed 2026-10-28 16:12:29 UTC.

[Native run](https://github.com/mischa23v/blind/actions/runs/40721822359) · [Native job](https://github.com/mischa23v/blind/actions/runs/40721822359/job/122934455287)

## Immediate blocker

The new hosted test bundle failed to link. Undefined arm64 symbols referenced by ClassificationIngressTests.o are:

- `MeshBufferDecoder81.MeshBufferDecoder.ValidatedRevision` nominal type descriptor.
- `MeshBufferDecoder81.MeshBufferDecoder.ClassificationDiagnostic` nominal type descriptor.
- `MeshBufferDecoder81.MeshBufferDecoder.Limits.init(vertices:faces:inputBytes:decodedBytes:)`.

Both hosted unit and UI attempts were cancelled because the test build failed; their xcresult summaries contain **zero cases**. This is not a behavioral regression count or evidence that route, collision, guidance or capture tests ran. Default app build and separate diagnostics-flag compile passed. Core and Memory package steps passed. Exact linker lines and zero-case summaries are retained in bounded-link-failure-lines.txt.

## Same-export artifact correctly withheld

The unit exporter reported `No test case statuses found`, `complete=false`, `source_verified=false`; actual checkout SHA and clean-source provenance were observed, but no case verdict was available. The same-export collector therefore returned `unverified_case_evidence`, `sourceVerified=false`, `files=[]`.

**No USDZ, metadata sidecar, same-export inventory or manifest bytes were produced for the requested comparison.** The uploaded public artifact contains only receipt.json; successful artifact upload is not successful capture. The comparison agent and parent were notified immediately. Source identity checks and capture gates were not relaxed, no unrelated private artifacts were downloaded, and no manual rerun or workflow was started.

- Same-export artifact 12830728547: ZIP 488 bytes, SHA256 `760757e1526b29d6e170e1065b04581ef02db2d8c008fa01e0869936e93db498`; exact error receipt saved as same-export-failed-receipt.json.
- Unit artifact 12831392286: ZIP 966 bytes, SHA256 `301258a51ec61fcc39cdea657d5693ab2258238e69b1175836219b6228023c6f`; exact original JSON saved separately. Final log JSON is semantically identical.

## Sibling proof results on the same source

- [SwiftPM proof 40721821544](https://github.com/mischa23v/blind/actions/runs/40721821544): terminal success at 16:02:27 UTC. Native SwiftPM backend, macOS product and public client executed: 55 legacy, 32 runtime, 5 failure-commit, 19 discard checks. Simulator product/client linked, not executed. Default Swift build backend was not proved.
- [Ingress proof 40721821664](https://github.com/mischa23v/blind/actions/runs/40721821664): terminal success at 16:03:44 UTC. 83 real-runtime synthetic host checks and actual ARKit Simulator-boundary compilation passed; no simulator/device execution or physical authority.

Separate sibling directories retain terminal and bounded proof receipts. These successful isolated proofs do not override the hosted test-target link failure. Native same-data OpenUSD comparison remains blocked until that link dependency is repaired and the exact public capture test actually executes.
