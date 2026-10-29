# Coffee source-contact comparison — prepared, NOT RUN

Current path records were statically compared with historical evidence; all 72 query/endpoint records match exactly. **No VTK/native import, control test, collision query or simulated movement has run for this packet.** Python files were AST-parsed only. Root review and a separately authorized aggregate guard are required before any execution.

Read `FRAME_AND_GROUND_FOLLOW_ADDENDUM.md` for the three conditions and `PLAN.md` for source/licensing evidence. The available implementation is `run_comparison.py`, with existing all-hit triangle/OBB code and verbatim extracted ground-follow functions. No historical controller/main is executed. `run_controls.py` binds the exact extracted functions under the old test import name; the unchanged upstream tests and one new coordinate/low-obstacle control are included but unrun. This is ready for independent source review, not claimed validated/runnable by test evidence.

## Publication and exact restoration

Publish only `PUBLICATION_ALLOWLIST.json` entries. The raw 1,394,610-byte `SCHEDULE_20.json` stays local; its deterministic gzip (mtime=0) is 131,731 bytes. `SCHEDULE_STORAGE.json` records both byte counts and SHA256 values. Run `python restore_schedule.py` in this directory to restore the exact original bytes. It validates compressed/original hashes, refuses to replace different existing content, and imports no native modules. The worker's existing original schedule hash remains unchanged.

`CURRENT_PATHS_20.json` is the single published path dictionary. Do not also publish the redundant `HISTORICAL_PATHS_20.json`; historical result SHA256 remains in CURRENT and its source is [the pinned Coffee packet](https://github.com/mischa23v/blind/blob/c79fbd33171f78608f9eb2a1484fbc9266e3a695/research/tools/measured-progress-and-coffee-v1/coffee-evidence.zip). Original/public Coffee mesh is **not included**: obtain the previously verified source packet according to the parent SOURCE.md, retain MuSHRoom CC BY4.0 attribution, and require exact mesh SHA256. No images, native binaries, runtime outputs, local absolute paths or private geometry are part of this publication.

The `upstream/` allowlist contains the complete source closure actually imported by these workers/tests, plus source originals supporting verbatim extraction. It does not contain a general historical-controller runtime. Published wrapper-source redistribution-license caveat remains in PLAN.md: do not infer a BSD grant for project Python code from VTK's license.

## Proposed serial execution, not authorization

After restoring the schedule and obtaining root's source review, let `PIN` be the externally reviewed SHA256 of `SOURCE_PINS.json`. The following two commands must run serially inside root's admitted aggregate process-tree guard, with the second skipped if controls fail:

```sh
python run_controls.py "$PIN"
python run_comparison.py --pins-sha256 "$PIN" \
  --mesh "$ORIGINAL_VERIFIED_OBJ" \
  --current-result "$VERIFIED_ATTEMPT002_RESULT" \
  --out "$NEW_OWNED_OUTPUT_DIRECTORY"
```

The data/result arguments are consumer-local paths; the worker verifies their hashes before native imports. It refuses an existing output directory. No installs or retry loops. Preserve every failure and partial receipt; never rerun with relaxed geometry, labels or limits to get a pass.

### Frozen workload and caps

- Twenty current accepted paths, exact requested connectors and native points.
- 6,874 authored stationary/translation/turn events. Forward +X at zero yaw; initial yaw along first horizontal leg, in-place shortest turn (+pi tie), <=1° turn increments, <=2.5 cm 3D baseline translation increments. This is authored replay, not measured motion.
- Worst-case three-arm work <=54,992 box calls and <=124,092 support rays; C normally stops earlier at a support/cap/non-ground-contact failure. Ground setup and tests are additional small control/preparation work within the same aggregate resource admission.
- Worker caps: 55,000 box calls; 125,000 ray calls; 30,000,000 triangle tests (checked after an indivisible query; maximum overshoot <=174,740 source triangles across the two body/margin queries); 64 MiB logical logs; 16 MiB aggregate output files. Source all-hit broad-phase per-query cap remains 200,000; original mesh has only 87,370 cells. Timeout/disk/triangle/resource exhaustion is incomplete/unknown, not clear.
- Proposal: one sequential worker at a time, one thread, **120 aggregate CPU seconds / 180 wall seconds / 1 GiB aggregate memory**, enforced by root's reviewed external guard. Worker self-check wall limit is 170 seconds but is not a hard native-call interrupt. The guard must include control tests, load/build-locator, ground setup and all child processes. These budgets may legitimately terminate the full comparison; no performance claim has been made.
- Older prose's <=10,000 total-increment suggestion is superseded by this statically counted schedule and explicit per-primitive caps, pending root review—not an already admitted budget increase.

Outputs preserve raw nominal/margin counts, geometric label partitions and unknown support/coverage. C retains separate changed heights and never claims arrival at the original goal. No-contact is not known-free volume, and nine probes are not complete-footprint support.
