# Completed worker, failed aggregate: isolated-mode source remedy

The original aggregate at `conference-body-comparison-attempt-001` remains
**failed**. All three subprocesses exited zero and retired; then Python `-I`
prevented its terminal `from contracts import validate_receipt` from resolving
the sibling source. Original source commit:
`c204b0e63e4c7444c02ea8ccf50e347693a15684`. Original manifest:
`ed735949ea0d21bf0fbf64754980a61d67d8b8095193b11d5ba72920dc8d6dc9`.

**No original executed source, manifest or attempt output was modified. No
native worker was rerun.** This separate source directory contains:

- `run_aggregate_isolated.py`: successor guard, same accounting/bounds, plus
  explicit byte-pinned loading of both original `contracts.py` and its
  `schedule_source.py` dependency. It does not depend on cwd/PYTHONPATH or an
  ambient imported module. The temporary import slot is restored.
- `test_isolated_import.py`: three stdlib regressions, passed under `python -I`
  (0.043 seconds): hostile cwd/PYTHONPATH, modified source rejection, and
  restoration of a preexisting conflicting module.
- `SOURCE_PINS.json`: separate **future, not executed** guard manifest, with
  fresh attempt002 output path. It is not permission for another native run.
- `validate_postrun.py` / `POSTRUN_PINS.json`: separate read-only stdlib
  validation of the saved attempt001 evidence.
- `POSTRUN_VALIDATION.json`: exact copy of the completed post-run result from
  `conference-body-postrun-validation-001/VALIDATION.json`.

## What the post-run check establishes

All 32 original current input hashes equal the recorded before/after dictionaries.
All terminal output lengths/digests match the failed guard's stable inventory.
All six source controls and 32 kernel controls have zero-exit/no-skip evidence.
All original child process groups were recorded retired and the aggregate
resource usage remained within the original limits: 65.999001 CPU seconds,
66.033000309 wall seconds.

The validator streamed every saved record, rather than inspecting a prefix:
**13,704 authored increments, 27,408 boxes, 8,710,095 candidate triangles, zero
support rays**. It regenerated all seven schedules, checked exact order,
endpoints and increments, recomputed enclosure metadata with scalar math, and
reconciled every contact-event count, near-foot first-witness count and first
witness summary with the receipt. Original mesh transformation/float32 vertex
and int32 triangle byte digests were independently reproduced using only
stdlib scalar arithmetic/`struct`. Every recorded first-witness height matched
its original source face, with start/end relative heights checked.

This is **completed worker evidence reconciled after an aggregate bookkeeping
failure**, not a retroactive aggregate pass. The saved VTK intersections were
not recomputed. It is not physical movement, support, arrival, semantic floor,
camera/body alignment or clearance validation. The inherited 2 mm lower-body
exclusion remains; first-witness near-foot labels do not classify every hit.

## Source identity and commands

Future source manifest SHA256:
`4b71c31cbbb2cfb33587c92be34716bc7f1ad0df12557a06d4df8059a21ecb30`.

Post-run validation manifest SHA256:
`076949164d5bb614da9f13c6340321e533f66ce21e293d6367561b7c1c4b13a8`.

The completed source-only reconciliation was:

```sh
python -I research/conference-body-postrun-source-20261030/validate_postrun.py \
  --pins-sha256 076949164d5bb614da9f13c6340321e533f66ce21e293d6367561b7c1c4b13a8 \
  --out ../conference-body-postrun-validation-001
```

The output must be fresh; reusing the completed path is refused. Separate
validation bounds are 30 CPU / 60 wall seconds, 256 MiB observed RSS and a
256 KiB result file. Original attempt inputs and outputs remain read-only.

`ISOLATED_GUARD.diff` exposes the narrow successor changes. A future native
attempt still requires publication, independent review and root admission of
the exact new source commit; it is not needed to recover the saved worker
evidence.
