# Exact historical EDT source-view comparator

This is a separately labelled historical comparator, **not a test of the current
optional seed-veto/envelope native implementation or the current app**. It repairs
a stale provenance boundary without accepting changed native source as old code.
No model, geometry, routing, collision, controls or candidate thresholds change.

## Why a new packet

Public run `41008743162` at `7bb0532073b541fe86dd6dec579e0927ab072eab`
failed before native execution because an original native source pin no longer
matched. Its original failure is retained, not overwritten or reclassified.
The complete 58-input audit found 55 unchanged inputs and three differences:

- The oracle shared guard/header at `7bb0532` (kernel unchanged).
- Native seed-radius veto additions at `4b51e4273817bd7fa1d8830041bafdf302c11aee`.
- Native envelope additions at `6d1a5d60511071e572ed586c7132af6f7805a869`.

Those native additions are material compiled changes even though opt-in. The new
comparator does not blind-repin them or include their new headers. All 58 original
inputs are recoverable byte-for-byte at original protocol commit
`5a6ad0ad5c64879a9e95bae9212054ab9daf950d`. `OVERRIDES.json` records exact old and
current identities for the three files. Their original copies are public repo
source, retaining their existing headers and licensing; no third-party dataset
or private capture is added.

## Exact execution and authorization boundary

`run_snapshot.py` verifies this packet, the original pin manifest, and the actual
workflow's repository, approved ref and checkout HEAD. It does not fabricate a
historical Git checkout or set `GITHUB_SHA` to an old commit. The original runner's
repository/ref/HEAD, tracked-diff and before/after status checks are also retained
and execute with their working directory set to the **actual workflow checkout**.

A fresh runner-temp source view contains only the 58 exact pinned inputs plus
their original manifest. Fifty-five inputs come from the actual checkout and
must match their historical hashes. Three explicitly pinned historical copies
replace only the known current identities; unknown new changes fail closed.
All 58 hashes, the manifest hash, and the exact file inventory are rechecked before
every original subprocess and at successful completion. Symlinks, missing,
altered and additional input files are rejected. Compilation source/include
paths and fixed input data refer to this staged historical view, not the current
app/native tree. Generated instrumented sources and compiler outputs remain in
the original runner's output directory, as before.

The original runner remains byte-identical on disk and its self-pin remains
active. `RUNNER_ADAPTER.diff` documents the five in-memory orchestration changes:
include staging in the same 300-second deadline, use the real checkout as process
working directory, reverify the source view before commands and completion, and
attach provenance to the existing receipt. Exact reversal reconstructs the
original runner bytes. The original unguarded oracle is compiled: no extra
compile flag is necessary. No validators are removed or bypassed.

`receipt.sourceCommit` stays the actual workflow commit. A distinct
`historicalSourceView` object identifies the historical protocol, manifest and
58-input content identity. A closed `EDT_HISTORICAL_SOURCE_VIEW` JSON log line
emits this small public provenance before native work; this is source provenance,
not a successful native result. The existing receipt and result observer remains
unchanged. Early staging rejection exits nonzero before the original native
receipt exists; it cannot claim native success.

## Unchanged test and resource contract

Both original 25-request control arms (50 controls) must reproduce before the
single fixed 25-request candidate runs. All 51 native hook checks remain required.
The original source pins, test assertions, geometry and result schemas are
unchanged. Job/step limits remain 7/6 minutes; original global time remains 300
seconds including new staging, per-child CPU 120 seconds, output-file cap 128 MiB,
and single-thread environment unchanged. Artifact upload stays disabled by
default. No new install, cache, paid service, fetch or model is introduced.

## Source checks and reviewed command

Portable controls (no compiler, native library or Apple invocation):

```
python3 -B research/native-edt-historical-view-20261030/test_snapshot.py
python3 -B research/native-edt-historical-view-20261030/verify_checkout_view.py --repo .
```

The second command requires the existing public checkout to contain the 58 input
files. It creates a temporary source view only. Thirteen portable controls pass;
the separate complete staging check reproduces all 58 historical hashes from the
exact `7bb0532` source. See `SOURCE_RECONSTRUCTION_RECEIPT.json`.

Only after independent review/publication, the approved Apple workflow invokes:

```
python3 -B research/native-edt-historical-view-20261030/run_snapshot.py
```

No native run has been performed for this packet. A later native result is about
this historical fixed synthetic comparator, not room accuracy, live clearance,
child safety, or validation of the current production geometry implementation.
