# Native fixed15 aggregate proposal — SOURCE ONLY, NOT RUN

The separate `run_aggregate_native_ground.py` reuses the previously executed exact-XYZ guard's process-group accounting, limits, output inventory, retirement and failure preservation. It adds only native workload stages and identity checks. Root must independently review and bind the full packet to an admitted source checkpoint before executing. This proposal does not authorize a run by its author.

## Before execution: material budget risk

The prior exact-XYZ aggregate completed at **118.973865 CPU seconds / 120** (1.026135 seconds spare). New compilation/linking, ELF inspection, ten additional controls, repeated native identity checks and any additional eligible path work all count inside the same unchanged budget. A resource-aborted/partial run is a valid inconclusive outcome; do not retry silently, expand the cap, shorten the schedule or count partial journeys as success. Root must acknowledge this cost warning before execution.

## Exact reproduction entry point after independent review/admission

From the `blind` checkout, using the exact reviewed/published checkpoint value (not an arbitrary current HEAD):

```sh
/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12 -B \
  research/coffee-room-journey-recovery-20261029/collision-protocol/native-planner-ground-candidate/run_aggregate_native_ground.py \
  --admitted-source-commit EXACT_REVIEWED_PUBLISHED_COMMIT
```

Fresh work root is `coffee-body-native-ground-attempt-001` beside the checkout. Existing output is refused, never deleted/reused. Full argv, compiler/source/header/planner/runtime-byte hashes and the explicit policy are in `NATIVE_GROUND_RUN_PINS.json`. Dynamic wrapper hash is generated only after a successful build and read-only ELF validation; controls and comparison get the same hash. No direct child stage is an alternative to this entry point.

## Ordered work and binding

1. Existing source and input checks bind repository bytes to the exact admitted commit; original frozen schedule remains bound to its committed gzip and restored SHA256. Original/default source is untouched.
2. Compile the tiny C++ wrapper into owned output, link the absolute existing pinned planner path with `-Wl,-z,defs`; never rebuild or overwrite the planner library.
3. Run pinned `readelf -W -d` on existing planner and produced wrapper as accounted children. Before any library load, require the existing planner's four documented dependencies, require the wrapper's exact absolute planner `DT_NEEDED`, reject unknown needed names and any RPATH/RUNPATH/SONAME. No `ldd` or loader-based inspection.
4. Hash and verify wrapper, primary planner, selected host library bytes and loader cache before/after native stages and during final evidence. Resolve/pin current system symlink targets and reject any `/etc/ld.so.preload` file. Child environment remains sanitized with no `LD_PRELOAD`/`LD_LIBRARY_PATH`. These controls are an exact trusted-workload binding in this environment, not a hermetic OS/toolchain or malicious-process attestation.
5. Run original47 + exactXYZ10 + native10 controls serially; require a zero exit and the `Ran 67 tests ... OK` summary without skips. Only then run the unchanged twenty-path/6,874-event comparison. Receipt validation binds mode, policy, wrapper SHA256, ABI1/fixed15 and no physical authority. Preserve partial logs and failures.

## Unchanged aggregate limits and limitations

120 aggregate CPU seconds / 180 wall seconds / 1 GiB observed aggregate RSS / one CPU / 64 MiB owned output, including preflight, compile/link, native imports, controls, setup, comparison and final hashing/receipts. Existing 20 ms group polling, fast-exit accounting, leader/descendant retirement, stable terminal inventories and final resource checks remain. This is not hard cgroup memory containment or protection against hostile process-group escape. Complete system headers, compiler internals, all Python package bytes and every possible host dependency are not hermetically pinned.

The classifier is only initial signed Recast triangle eligibility. No final-walkability/semantic-floor/full-footprint/physical-clearance authority follows. Exact topology can join coincident sheets ambiguously; nine probes can miss holes/low objects. Missing real-data tabletops and the user's visually rejected corner route are not repaired by ground relabeling. No policy adoption, app activation, successful journey or physical trial is approved here.
