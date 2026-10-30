# Read-only OctoMap rays: successful build and38 controls

The additive read-only ray adapter built successfully at source commit `e9088cf7d17c23d9486d5d380e8a2eeb9634b267`. All **16 unchanged original controls and22 new ray controls passed**, with0 failures/errors/skips. Exact named tests were recounted from the saved log, and source, binary, build and control receipt hashes were independently verified without rerunning native code.

The earlier v1 compile failed because our adapter used `[]` on OctoMap Vector3. The separate v2 corrects15 vector access sites to official `operator()`, keeps C arrays unchanged and preserves the original bounds/query semantics. That failed attempt remains recorded in `../coffee-readonly-ray-build-failure-20261030/`.

## Measured execution

- Fresh candidate library:407,232 bytes; SHA256 `fa53b4153a7c1765880eabf5f8029d87173af6ed4ecdb425ea37f5d1d799bd84`.
- Build:12.333208CPU seconds,12.347461wall seconds,183,246,848-byte peak sampled-or-waited RSS. Compiler exit0 and process-group retirement recorded; before/after inputs match.
- Control worker:0.224224CPU seconds,0.163910wall seconds,33,992,704-byte peak RSS. CPU includes process startup while measured wall begins later, so these are different accounting scopes. The worker result is complete; a separate outer process-group control receipt is not supplied here. Root observed the launcher terminal completion.

## What passed

The unchanged occupancy controls plus synthetic ray cases cover known-prefix hits, occupied/unknown origin distinction, unknown gaps, native center-based range censoring versus voxel-entry coordinates, oblique entries, zero/nonfinite/unnormalizable directions, huge positive/negative finite origin rejection before native integer conversion, conservative envelope bounds, batch/shape limits, closed owners and non-mutation of map payload/evidence/defaults.

The implementation uses the retained official OctoMap1.10.0 traversal and intersection methods. These controls verify the adapter's bounded behavior on authored cases. They do not establish real sensor accuracy, source-mesh alignment, floor support, collision avoidance, navigation readiness or user safety. No new held-out depth image was opened or evaluated by this work. The metadata-selected232/370 holdouts and real-data evaluator remain a separate next gate.

## Verification and contents

Run `python -I -B research/coffee-readonly-ray-controls-result-20261030/verify_saved_result.py` from the repository. The read-only stdlib script requires the original local build/control artifacts and frozen source files; it does not load the library or execute controls. It prints the same deterministic verification JSON.

This packet contains text receipts, named control logs, verification script and summary only. No native library, photos, depth data or raw maps are published. All physical-authority flags remain false.
