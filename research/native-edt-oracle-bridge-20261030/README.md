# Additive EDT shared-oracle provenance adapter

Source-only preparation, 2026-10-30. The historical fixed EDT runner pins the
original test-only collision oracle. Sharing that same kernel under an explicit
compile guard changes its source bytes and requires the test compile condition.
Without an adapter the existing lane correctly refuses the changed pin; without
the compile flag Swift does not expose the oracle class. Neither failure should
be hidden by replacing historical pins or disabling the lane.

## Exact change

`run_bridge.py` verifies the immutable historical `run_native.py` and
`NATIVE_SOURCE_PINS.json`, the guarded current oracle, and retained baseline
snapshots. It removes only the exact outer conditional and final `#endif`, then
reverses the exact documentation-header replacement. The resulting **entire
oracle file must equal the original bytes**, SHA-256
`30941a88fda667560962fc1baca7f980ba534f613d093b79662b3951e0da5fd9`.
The current guarded file is separately pinned at
`9581e63244f89a5183d752124d306e6808bf114dfc5cb3eecf809b03183e9b53`.
No collision algorithm, cylinder, contact category, threshold or phase changes.

The launcher derives an in-memory runner through four exact, reversible edits:

1. Original bulk pin verification calls an explicit provenance checker. Only the
   named oracle can use the verified reversal; every other file still matches its
   historical SHA exactly.
2. The runner's per-input pin assertion uses that same checker. Runtime mutation
   of the oracle is rejected, not authorized by an earlier successful comparison.
3. Receipt preserves the historical pin map as expectations and labels its
   meaning explicitly, alongside actual oracle and reversed-kernel hashes,
   generated-runner identity and adapter provenance.
4. The one Swift compile receives `-D BLIND_COLLISION_ORACLE_TESTS`.

`RUNNER_ADAPTER.diff`, `ORACLE_GUARD.diff` and `SOURCE_REVERSAL_RECEIPT.json`
make these changes auditable. Reversing all four runner edits returns the original
runner byte-for-byte. The original runner and historical pin file remain at their
original repository paths, unmodified. Baseline `.txt` files are inert provenance
snapshots, not alternate executors. `MANIFEST.json` pins this additive packet.

## Unchanged protocol and controls

The original runner still requires the Apple platform, approved public repository
and branch, matching clean checkout commit, Xcode 27.0 and every original native
source/input pin. Its 300-second global deadline, existing subprocess limits,
single-thread environment, all original cleanup/failure recording and source
cleanliness comparison remain intact. No dependency installation or download is
added. The original **51 native hook checks and 50 original controls** still gate
the same **25 EDT candidate requests**, with the same packed geometry, six
profiles, masks, expected baseline results and Swift assertions. No candidate
success or physical guidance is inferred from a green job.

The staged workflow changes only the launcher command and adds this packet's path
to the existing triggers. Its separately reviewed public-repository gate,
standard runner, timeouts, no-cache behavior, default-disabled artifact upload
and bounded metadata-only observer are preserved. This preparation does not
activate or publish that workflow.

## Verification and invocation

Pure standard-library source controls:

```
python3 research/native-edt-oracle-bridge-20261030/test_bridge.py
```

Eight checks passed: exact oracle reversal; algorithm, guard, header and trailer
mutation rejection; runner mutation rejection; exact compile flag and preserved
control/budget statements; and real filesystem pin checks rejecting subsequent
oracle or unrelated-input mutation. These tests do not load Swift, SceneKit,
Recast, any native binary, or a CI executor.

After applying the reviewed bridge in a complete repository checkout:

```
python3 research/native-edt-oracle-bridge-20261030/run_bridge.py --verify-only
```

This mode checks **adapter provenance only**, not every native dependency and not
a native result. It rejects an unguarded old oracle rather than silently switching
protocols. For the original authorized Apple lane, its explicit entry becomes:

```
python3 research/native-edt-oracle-bridge-20261030/run_bridge.py
```

Ordinary Python is required: optimized execution that strips original assertions
is rejected. The launcher itself uses explicit exceptions for its pin/reversal
checks. Normal execution delegates native commands to the historical runner,
not a new test harness. It retains the same `RUNNER_TEMP/blind-edt-navigation-probe`
receipt/result paths consumed by the existing metadata observer.

## Status and remaining blocker

Prepared and source-tested only, in an isolated candidate directory. No shared
application source was applied, no Swift/native build executed, no CI dispatched,
no installation/download performed and no publication made. Independent review
and application to the exact bridge candidate are required before the existing
lane can evaluate native behavior. This adapter resolves a source-provenance and
compile-guard incompatibility; it does not resolve or reinterpret any existing
route, margin, collider or navigation failure.
