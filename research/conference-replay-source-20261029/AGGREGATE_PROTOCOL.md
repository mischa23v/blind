# Seven-objective conference comparator: aggregate execution protocol

**Source preparation only. No execution is claimed.** This run would reproduce geometry proposals using the historical estimated registration; it cannot establish camera-to-mesh calibration, a measured physical floor, complete support, full-body clearance or movement success.

## Exact scope

One serial controls process followed by one serial comparator process, never concurrently. Existing Coffee SciPy graph controls are reused unchanged. The comparator retains all seven requested objectives:

1. Table anchor 92 → 120.
2. Table anchor 120 → 200.
3. Table anchor 200 → 220.
4. Table anchor 220 → 20.
5. Table anchor 20 → 92.
6. Original VARPU anchor 130 → 160.
7. Original VARPU anchor 160 → 130.

No candidate subset, new endpoint, manual exclusion, FARO, occupancy correction, floor patch, native build, package install, extra route or automatic retry is permitted. Native radius 0.225 m / height 1.75 m is proposal geometry only; actual body remains 0.45 × 0.30 × 1.60 m plus a separate 0.15 m horizontal margin, not validated by this run.

## Reused supervisor and caps

`run_aggregate.py` is the passed Coffee source-comparison aggregate supervisor with only command expansion, provenance text and seven-objective terminal checks adapted. `GUARD_ADAPTATION.diff` and `GUARD_REUSE.json` identify the exact source and unchanged helper bodies.

- One CPU affinity, one BLAS/OpenMP thread.
- 120 aggregate CPU seconds and 180 aggregate wall seconds, including controls and terminal accounting.
- 1 GiB observed aggregate RSS, with fast-exit child RSS accounting; this is not a cgroup-enforced hard memory ceiling.
- 16 MiB aggregate output, retaining 256 KiB for the final receipt.
- Fresh owned work directory, fresh bytecode/cache paths, no reused outputs.
- Process-group retirement required even after a successful leader exit; failures/partial logs remain.
- Complete pinned input hashing before and after; repository input bytes and the manifest must match the explicitly admitted Git commit. No lazy fetch is authorized.

The worker may produce disconnected proposals or an all-grid-unavailable result after a required anchor/graph failure. Those are terminal diagnostic results, not passes. Native failure records remain and never receive an invented final connector to the goal. Hard failures, resource exhaustion, missing pins or changed projections cause failed receipts.

## Pins that must exist before freezing

There is intentionally **no `SOURCE_PINS.json` yet**. Missing extraction bytes are not assigned guessed hashes.

`freeze.py` requires:

- The exact extracted OBJ and original pose JSON, with their fixed known hashes.
- A successful `EXTRACTION.json` in the same fresh source directory. Its actual bytes are hashed then, not predicted now.
- These repository sources: `extract_source.py`, `run_comparison.py`, `run_aggregate.py`, `freeze.py`.
- `conference-replay-input-inventory-20261029/TARGETS.json`, plus exact retained registration result, transformed mesh receipt, loop freeze and reverse freeze.
- Unchanged current Coffee selector and fixture source.
- Already-built Coffee002 native library, native wrapper, graph sampler, Python C binding and corresponding native adapter source, matching current Coffee's frozen hashes.
- The same Python executable and NumPy/SciPy metadata/RECORD pins as Coffee. This is not a hermetic dynamic-library closure.

Repository input keys are repository-relative so the guard binds them to the admitted commit. Original assets/native workspace files use `@WORKSPACE@` and are content-pinned. No core manifest includes the large compressed archive, which has already been verified during extraction; source input pins cover the exact extracted members and extraction receipt.

## Proposed freeze command, after successful reviewed extraction

From the repository root, using the same Python interpreter as the current Coffee controls:

```sh
python -B research/conference-replay-source-20261029/freeze.py \
  --source-dir /workspace/scratch/90f3f6703064/conference-source-recovery/extracted-001 \
  --work-root /workspace/scratch/90f3f6703064/conference-source-comparison-attempt-001 \
  --manifest research/conference-replay-source-20261029/SOURCE_PINS.json
```

This is standard-library-only preparation, not native admission. The manifest includes `controlsCommand`, `comparisonCommand`, source/output paths and exact limits. Root must review the final source, manifest and any changed bytes. Follow the parent's existing publication policy; this child does not stage, commit or push anything.

## Proposed admitted command, only after root review

Root supplies the exact commit containing the reviewed protocol sources, inventory inputs and `SOURCE_PINS.json`:

```sh
GIT_NO_LAZY_FETCH=1 python -B \
  research/conference-replay-source-20261029/run_aggregate.py \
  --admitted-source-commit EXACT_REVIEWED_COMMIT
```

Do not replace the placeholder with an unreviewed current HEAD. Existing Coffee native-ground work must have ended before admitting this serial comparison.

## Terminal evidence

The guard requires exact seven-row order, requested XYZ and source pose indices. It independently recounts native association displacement, rejects partial-goal connector invention, checks connector-inclusive lengths and unchanged `1.5 × original shortest grid length + 0.5 m` cap, and retains every grid disconnection/unavailability. It also checks original transformed mesh byte identities, native config, declared rectangular body/margin, zero-exclusion setting, no movement and false physical/calibration authority.

`GUARD_RUN/RESULT.json` records controls/comparison exit codes, process retirement, resource/output receipts, before/after pins and seven-objective counters. `comparison/PROPOSALS.json` retains exact requested/projected endpoints and available source paths. Neither is a full-body, support, collision-free or successful room-journey report.
