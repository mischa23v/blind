# Full three-arm run: RESOURCE BLOCKED

**The original batch failed its 300 CPU-second resource gate. It is not an all-three-arm success. All outputs remain quarantined under its unchanged `OUTPUT_ADMISSION.json`.**

## Terminal evidence

- Stop: `cpu_300s`, sampled conservative CPU **300.027939 s**, wall **300.875959 s**, peak summed RSS **692,690,944 bytes**.
- All **943 frozen source/input pins remained unchanged**. The complete initial 265-frame preflight passed before any engine. Read-only post-stop recount matches every original stock pixel count.
- **B completed 265/265** through frame00309 and exported a 93,386,326-byte mesh.
- **C0 completed 265/265** through frame00309 and exported a 92,971,538-byte mesh.
- **C1 completed 245/265** through frame00286. Frame00287 was attempted when terminated. No C1 final mesh or reloadable TSDF exists.
- Both complete arms submitted **164,771,607 points**. C1's completed updates submitted 152,551,249. Native state scans reported no invalid voxels before termination.
- Process audit after termination found **zero live run processes**. No paused process, automatic cap extension, retry or scoring was left running.

`QUARANTINE_RECEIPT.json` preserves per-arm counts, mesh hashes, terminal receipt and process audit. `POST_STOP_COUNT_RECOUNT.json` is an independent read-only recount, not output admission. The complete-stage wrapper's final count/output freeze was not reached.

## CPU-receipt caveat

The original field named `finalActualChildPlusGuardCPUSeconds` reports 12.63743 s, but it omits terminated descendants that were not reaped through their parent. It is **not total worker CPU** and cannot be used to reinterpret the cap or claim unused budget. The sampled 300.027939 s cap receipt governs the stop. The original receipt is retained unchanged.

## What this does—and does not—establish

All 265 inputs passed the fixed quaternion/pose, weight, normal, physical-ray and index domains with no guard relaxation. The first-pass normal totals were 162,445,241 numerically valid; 430,018 boundary; 166,478 missing-neighbor; 1,729,870 discontinuity; zero nonfinite or degenerate. These are numerical availability counts, not accuracy.

B and C0 completed their native contracts, but this batch's global quarantine still applies. Root may separately review and admit those completed arms using their complete frame/hash/state/mesh evidence; this report does not release them. The independent reviewer additionally reports B's complete PLY is byte-identical to the historical stock PLY (`B_STOCK_IDENTITY_REVIEW.json`). That is evidence against claiming a D1/projective geometry gain on this recording, not a reason to hide the original synthetic axis defect.

The separately proposed C1 recovery must start from an **empty map**, retain the same kernel/configuration/inputs, and carry a new explicit budget. It cannot resume the lost in-memory map or load a TSDF that discarded gradient history. Original failure and source freeze remain intact regardless of later recovery.

No reference scoring, accuracy gain, 90% target, small-object safety or live-navigation claim follows from this failed batch. The scorer was told to remain blocked until new explicit admission evidence exists.
