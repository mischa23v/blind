# Stage B default-guard correction — source-only proposal

The first actual Stage B attempt failed before inserting the first frame: `ValueError: upstream defaults changed`. Its failed receipt, empty frame-result list, stderr and exit 1 remain preserved. This is not a retention pass and does not establish what happens after the corrected guard.

## Evidence and minimal correction

The released OctoMap source sets hit/miss/occupancy defaults to 0.7/0.4/0.5 in `AbstractOccupancyOcTree.cpp:42–44`, stores them as `float` log-odds in `AbstractOccupancyOcTree.h:228–233`, and converts back to probabilities with `octomap_utils.h:41–48`. A pure-stdlib reproduction of that representation gives:

| Setting | Source decimal | Predicted float-logodds roundtrip | Absolute difference |
|---|---:|---:|---:|
| Hit | 0.7 | 0.69999999724559 | 2.754409922 × 10⁻⁹ |
| Miss | 0.4 | 0.40000000284949333 | 2.849493308 × 10⁻⁹ |
| Occupancy | 0.5 | 0.5 | 0 |

These are source-predicted representations, not values obtained by a new native call. The original passing native `test_defaults_frozen` already specifies `atol=1e-7, rtol=0` for the default values. The new Stage B check's `1e-12` comparison was inconsistent with that existing contract.

[CHANGE.diff](CHANGE.diff) contains the entire proposed runtime-source change: replace the three `< 1e-12` probability comparisons with `<= 1e-7`, with one explanatory comment. This is an absolute tolerance only; default values and thresholds are not changed. No occupancy output, measured endpoint, floor filter, native library, depth source, frame, mapper configuration, resource limit or route criterion is changed. The copied wrapper remains byte-identical to the reviewed rebuilt binding.

## Authored regression controls

`test_default_guard.py` uses only Python's standard library. It extracts and evaluates the **actual guard expression** from this candidate's AST without importing retention, NumPy, Pillow, ctypes or the native mapper. Its seven tests check the exact absolute-tolerance policy, nominal defaults, source-predicted float32 roundtrip, values inside/outside tolerance, materially altered defaults, and nonfinite values.

The preparer AST-parsed these files but did **not** execute these tests or any native call. Root must review/publish this new source version, run the pure-source controls, and explicitly admit a separate fresh Stage B attempt. The old failed attempt is never overwritten. No retry is authorized by this file.

Run the authored controls with the reviewed interpreter:

```sh
"$REVIEWED_PYTHON" -I -B research/coffee-table-retention-default-guard-source-20261029/test_default_guard.py
```

For any separately admitted Stage B run, retain the exact previously verified native library, original private depth/calibration bytes and frozen evaluator selection. Use this directory's `retention.py` and wrapper, a fresh result path, and the same 120 CPU seconds / 512 MiB address-space / 180-second outer wall / single-CPU / bounded-output limits. A resource stop or later assertion failure remains inconclusive/failed, never grounds for silently relaxing limits or geometry requirements.

The [Stage A result](../coffee-table-retention-stage-a-result-20261029/) and [original native-build result](../coffee-octomap-build-result-20261029/) remain separate evidence. Stage C, registration, table-corner extent, collision checking, route acceptance, physical safety and app readiness are not established by this correction.
