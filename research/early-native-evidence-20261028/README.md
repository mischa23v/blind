# Hosted-unit evidence before the UI wait

## Result

Prepared a reporting-order-only change against public source commit
`dc32a9bad9a75566f27924fb9f7aa8fe50a46e95`. Hosted-unit cases can be exported and the
existing artifact uploaded immediately after the hosted-unit step, rather than
waiting behind the UI step (whose unchanged limit is 20 minutes).

**37 bounded source/stub-flow checks passed. No Apple SDK build, native test,
GitHub Actions run, artifact upload or publication was performed by this work.**
Actual runtime artifact availability still needs verification on the eventual
published commit. No application behavior or physical-readiness claim follows.

## Minimal source change

1. Insert one `always()` reporting step immediately after `Hosted iOS unit tests`.
   It reuses the existing collector's exact three public input/output arguments
   and `|| true` handling from `tools/ci/native-apple.sh summary`; `$out` is expanded
   explicitly to `$RUNNER_TEMP/blind-native-ci`. The new reporting step is bounded
   to three minutes, matching the existing summary reporting-step bound.
2. Move the **same** `Preserve bounded hosted-unit case statuses` upload step
   directly after that extraction and before UI. Artifact name, single JSON path,
   action pin, retention, missing-file failure and `always()` condition are intact.
   There is still only one upload of that artifact, not a second upload under its
   immutable name.
3. Update only the workflow SHA256 entry in the existing integrated source pins.

Every pre-existing workflow step remains byte-identical apart from its position
and surrounding blank separator. Existing test commands, selectors, conditions,
timeouts, skip/failure logic, jobs, permissions, triggers, runners, concurrency,
visibility guard and diagnostic compile job are unchanged. No new workflow or
job is added. The late summary and its repeated local collector call remain
unchanged; they do not re-upload or overwrite the already uploaded artifact.
Source/helper implementations are outside this patch.

An unfinished/missing unit bundle still cannot produce a passing verdict. Early
reporting does not turn a failed unit step into success. Cancellation/runner loss
can still prevent artifact production; this change is not an availability guarantee.

## Consumer and pin review

The exact baseline `research/native-candidate-app-integration-85/integrated/check.py`
iterates `SOURCE_PINS.json["integrated"]` before the diagnostic build. Its workflow
pin therefore requires the companion update. The checker itself is unchanged.
Its later workflow assertions concern the isolated diagnostic job, which remains
byte-identical. The workflow's artifact consumer retains the same name and path.
Repository search only indexed an older default-branch source; it was not treated
as an exhaustive search of this recovery revision. This limited restoration does
not contain all inputs for the full integrated checker; that aggregate was not run.

## Reproducible verification and inverse

```sh
python3 research/early-native-evidence-20261028/check.py
```

The checker compares the exact allowed transformation against frozen baseline
bytes, preserves each original step's complete body, checks all reporting
arguments, validates the manifest's sole changed entry, rejects nine representative
contract regressions, and applies the forward/reverse patches in a disposable
two-file directory. The shell check substitutes an inert owned `python3` stub:
exit codes 0, 1, 2 and 137 retain the existing `|| true` behavior and paths with
spaces remain single arguments. This is not execution of the collector or GitHub's
expression/runtime engine. The earlier checker-only blank-separator error is
recorded separately; no workflow fix or native-test result is hidden by that correction.

- [Final check results](verification.json)
- [Forward diff](reporting-order.patch)
- [Standalone inverse diff](reporting-order.inverse.patch)
- [Frozen workflow](native-apple.before.yml)
- [Frozen helper reference, not an executable helper](native-apple-sh.before.txt)
- [Frozen source-pin manifest](SOURCE_PINS.before.json)

Both `git apply -R reporting-order.patch` and `git apply reporting-order.inverse.patch`
restored the exact baseline workflow and manifest in the disposable check. No
repository rollback or Git initialization was performed.

## Exact identity

| File | Baseline SHA256 | Candidate SHA256 |
| --- | --- | --- |
| `.github/workflows/native-apple.yml` | `fa2fed05f2fcdce59f1cdcb92fb77442a3c7e5c3d0bf53ef78c0fe1c2df40672` | `faafd69a05f4d6e65a21e5317d105b74c61d0779d00a0099cab2fa0c740aba81` |
| `research/native-candidate-app-integration-85/integrated/SOURCE_PINS.json` | `6944b4ea0cc0df54ddf46eb3b27119fc4009b0337561df1a80387d039f307203` | `79e3acf8b144a05ccd9dc163a7219bb1b5abf8909393065061da2cd6310fd6f8` |

Candidate Git blob IDs: workflow `d157d252b52adb8a61d67b27e673681b3231b687`;
manifest `656db678a154cda7234a679c65ac09c2f5b54930`.
Forward patch SHA256 `d0b69c653a25d3fca7132c226bad7698f3f1ff6a8a56129d5dcdb5d2d0a7be52`;
inverse patch SHA256 `a04c35aab2bac83de0d9f0b3308056b1550ed493afac80a448e3560ab9de6d74`.
The complete proposed file list and hashes are in `publication-manifest.json`.
