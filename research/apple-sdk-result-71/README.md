# Apple SDK candidate bridge: verified run

**PASS** — [run 40416322676](https://github.com/mischa23v/blind/actions/runs/40416322676),
job 121899440437, source commit `caebdacedd4e19a74fa5899adf016c912caf402d`.

- macOS ARM64 native Recast/Detour library and Swift C-ABI replay built successfully.
- All **55** unchanged checks passed; **636** tabletop exclusion spans matched.
- All five original-versus-tiled routes, all five saved Python58 baseline routes,
  and all five saved Python66 excluded routes matched with **zero measured
  coordinate delta**, matching point counts, status, completion and error.
- iOS Simulator ARM64 native library and Swift executable compiled and linked.
  **The simulator executable was not launched**, and no app project, live ARKit
  input, physical device or physical-guidance behavior was tested.
- Apple Swift 6.4 (`swiftlang-6.4.0.34.1 clang-2100.3.34.1`), reported host target
  `arm64-apple-macosx27.0.0`; Xcode27.0 and SimulatorSDK27.0 enforced by harness.

## Controlled numerical correction

The initial two Apple runs compiled successfully but failed saved Linux route
parity. Their diagnostics showed extra near-collinear waypoints. The only
behavioral build change for this successful run was explicit native compiler
flag `-ffp-contract=off`. No geometry, native source, 55 assertions or `1e-5`
comparison threshold changed. A separate Linux Clang21 build with that flag
also passed all checks. This controlled result supports multiply-add
contraction as the cause of the observed cross-platform discrepancy on this
fixture; it is not a universal cross-platform numerical or safety guarantee.
Earlier failed runs and the coordinate-level analysis remain preserved in
`research/apple-candidate-ci-71/` at the source commit above.

## Timing and limits

| Stage | Wall seconds |
|---|---:|
| macOS native compile | 6.300 |
| macOS Swift compile | 6.101 |
| macOS replay | 0.590 |
| Simulator native compile | 4.397 |
| Simulator Swift compile/link | 3.322 |

Final scratch measured after commands: **51,214,708 bytes**. These are hosted CI
wall timings, not an iPhone performance benchmark. CPU usage and peak RSS were
not measured. Existing per-command timeout/CPU/file-size limits and post-command
scratch check do not constitute a hard total-memory guarantee.

## Provenance and preserved evidence

GitHub artifact ID **12695977224**, downloaded archive **8,350 bytes**, SHA-256
`04831ceb1ec92d8db35574fba4dc5743020b0f96f18078929aaa91853edb6d06`.
The archive hash was verified before extracting its eight JSON files.
`SUMMARY.json` records exact source commit, fixture hash, native/executable
hashes, toolchain and successful command receipts. `RESULT.json` retains all
checks and route outputs. Its inherited scope string mentions Linux, but this
artifact was produced by the verified Apple run; SUMMARY and receipts identify
execution provenance. No raw job logs or credentials are included.

This isolated bridge remains **candidate-only**: physical authority false,
raw-depth hazard authority unimplemented, unknown coverage retained. It does
not change previous known full-app hosted/UI test failures or demonstrate
live indoor navigation.
