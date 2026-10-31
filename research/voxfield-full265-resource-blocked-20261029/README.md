# Original full-265 batch: resource blocked, outputs quarantined

This preserves the **original failed batch**, not a later C1 recovery. Read RESULT.md and INDEPENDENT_TERMINAL_REVIEW.json. At the sampled 300.027939 CPU-second cap, B/C0 had completed 265 frames each; C1 had completed only 245, with its next update attempted. No C1 final mesh exists. B/C0 meshes exist privately but remain quarantined under this batch's OUTPUT_ADMISSION.json pending separate explicit admission. No PLY, raw recording, pose manifest or large per-frame/per-point payload is published here.

The final child-plus-guard rusage field undercounts killed orphan descendants. Its 12.63743 seconds is not total CPU and cannot justify a claimed unused budget. The sampled cap and terminated status remain authoritative. The final wrapper freeze was not reached. Neither successful earlier arms nor later recovery may overwrite the failed batch.

An independent reviewer found B's entire PLY byte-identical to prior stock, with the same complete SHA-256. This is not a D1 room-geometry gain and does not erase the synthetic exact-axis defect. Byte identity alone does not admit reuse of old scoring unless scorer/cache/pose/protocol identity and explicit admission are separately established. C0 is not scored here. No accuracy, winner, small-object safety or live-navigation result follows.

## Publication review

The publication reviewer separately recounted saved native update records: B265/C0265/C1245 completed, B265/C0265/C1246 attempted. Completed point submissions are 164,771,607 for B and C0, and 152,551,249 for C1. All 265 initial preflights total 164,771,607 admitted points; normal-reason totals are 162,445,241 valid, 430,018 boundary, 166,478 missing-neighbour, 1,729,870 discontinuity, zero nonfinite and zero degenerate. Submitted points are not independent voxel observations or accuracy. No fusion, scoring or mesh parsing was rerun by this publication lane; independent completed-arm mesh checks are included as their own evidence.

Original source/receipt hashes and any sanitized published copies are recorded in PUBLICATION_REVIEW.json. Only ephemeral absolute workspace prefixes are replaced by <WORKSPACE_ROOT>. PLAN.md and source preparation comments describe historical preparation; terminal receipts describe what subsequently executed. Original failed evidence and quarantine remain intact.

## Source and reproduction boundary

Official Voxfield source is https://github.com/v4rl-ucy/voxfield/tree/78ee6403720e0aed87f4720c04c813bb38a3b260 with included BSD-3-Clause licence. Prior zero-direction and numerical-normal candidate checkpoints document D1/N2 changes. Third-party and dataset licences remain separate.

This is not a self-contained runner. It requires lawful original 265-record data, the original calibration/pose rows, matching decoded input hashes, prior reviewed Linux dependencies and D1 core, and an independently reviewed local execution freeze. Those input/pose/freeze files and binaries are not bundled. execute.py's placeholder paths and adapter.cpp's historical ../n2-normal-candidate/n2_adapter.h include refer to the retained layout; reconstruct that layout explicitly rather than assuming a repository checkout provides it. The copied N2 header is evidence of the version used, not an undisclosed code change. Keep original input ordering, masks, empty-map starts and resource guards. Any further run needs separate admission and budget. A C1 recovery must start empty because no resumable gradient-preserving state was retained.
