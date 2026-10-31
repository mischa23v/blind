# Repair the early export's missing aggregate-summary dependency

## Actual defect and correction

[Run 40698547633](https://github.com/mischa23v/blind/actions/runs/40698547633), at
`6fe9d5270f23954fa59fc3509cccf23445cefa51`, published an early artifact, but its
collector result was **incomplete**, with `FileNotFoundError` for
`unit-summary.json`. The collector had accepted initial source provenance, then
required that missing file to reconcile exact case totals. It correctly did not
claim verified cases. The existing helper produced the file only in its final
summary after UI. The hosted test failure is separate; this reporting error does
not establish the cause of any native test failure.

Original evidence is retained in
[`../native-path-recovery-20261028/run40698547633/`](../native-path-recovery-20261028/run40698547633/).
The original reporting-order patch and its 37 structural/stub checks are retained
unchanged in [`../early-native-evidence-20261028/`](../early-native-evidence-20261028/).
Those checks **missed this real file dependency**: substituting an argument-only
collector stub did not exercise summary production or case reconciliation. They
are not evidence that the original early reporting worked on GitHub.

The correction changes only the existing early reporting step's `run` body:

1. Set `out` to the helper's existing `$RUNNER_TEMP/blind-native-ci` location.
2. Reuse the helper's exact unit-bundle existence guard and `--summary` invocation,
   including its bounded sanitized exporter and unchanged failure-message fallback.
3. Then invoke the same three-argument case collector, retaining its `|| true`
   handling. A failed/missing/mismatched summary still cannot certify case counts.

The same single JSON artifact upload remains immediately after the reporting step.
No collector, app, existing native-test, job, trigger, permission, timeout, skip rule or acceptance
criterion changes. The existing late summary remains intact. Only the workflow
entry in the integrated source-pin manifest is updated. This cannot repair the
already-running job; runtime verification requires the eventual new commit.

## Verification

- **15 source/shell-syntax/inverse checks passed**, recorded in
  [`source-verification.json`](source-verification.json). They reconstruct the new
  block directly from the original helper loop body with `$suite` replaced by
  `unit`, and prove every byte outside that run body and its pin remains unchanged.
- **Six independent collector regression tests passed**, then passed on a separate
  review run. They execute the **actual workflow shell block and real exporter**
  with synthetic external Git/xcresult inputs, rather than stubbing the Python
  collector. They verify summary-before-case query order, sanitization, retained
  failed/skipped counts, historical missing-summary failure, aggregate mismatch,
  summary failure, missing bundle and source mismatch. These are separate from the
  source-check count; see `test-export-order.py` and `integration-review.json`.
- **No Apple SDK/native tests, new workflow execution, uploads or publication were
  performed by this repair task.** This source result is not a native CI pass or
  physical-guidance acceptance.

```sh
python3 research/early-native-summary-repair-20261028/check.py
python3 research/early-native-summary-repair-20261028/test-export-order.py
```

The frozen `native-apple.before.yml` and `SOURCE_PINS.before.json` are the exact
published `6fe9d52` bytes. Forward and standalone inverse patches are supplied;
applying them in a disposable two-file copy reproduced the exact before/after
bytes. No shared repository rollback was performed. The original helper at
`6fe9d52` was re-read via the connector and remains Git blob
`318f61957ae3755f4b13ee69b62ffb1776552cbb`, SHA256
`d798efeed160cb0a0513991ee7d291bffe88b30844ba112121662e0d79add32a`.

## Exact candidate identity

- Workflow SHA256:
  `ba74cd55736aa76248b885cf3c2454ba7ce2d082b0f7f040cd87ad8389e37a8e`.
- Source-pin manifest SHA256:
  `88a89117ecd1b17cfa90e8432b47c67ab761e091e55c01079b92e78a30c4ac61`.

Only root may publish. `publication-manifest.json` enumerates this task's exact
proposed files when finalized; reviewer-owned regression files are reported
separately and must accompany the fix.
