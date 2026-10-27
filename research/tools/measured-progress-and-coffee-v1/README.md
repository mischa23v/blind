# Measured-progress jitter pilot and Coffee source topology

## Stage 76: short jitter journey restored

Processing every valid released measurement for waypoint progress, while steering only from the newest pose, restored this short development journey: **201 ticks, 2.840 m horizontal travel, arrival inside the original 35 cm goal region, drained queue, zero predicted body/underbody contacts or support vetoes**. Actual 3D travel was 2.841876 m. Independent terminal replay and recorded-physics review passed.

The unchanged stage 74 retained-pose candidate remains a failure: 450 ticks, 1.240 m, no arrival. The stage 73 conservative jitter baseline arrived in 370 ticks with 193 no-new-pose stop ticks. Stage 76 had two no-usable-pose stop ticks and five zero-command ticks including the goal stop; these are not the same as stop episodes.

The fix uses already released measured positions, original timestamps and the unchanged 1 cm waypoint criterion. It does not invent a pose, widen clearance, replay a steering command for every historical packet or use the evaluator to correct localization. One short route and one jitter seed are development evidence, not general delayed-control stability or the planned 100-episode suite.

## Coffee: second source mesh, proposals only

The original public Coffee iPhone mesh and poses are included with acquisition and attribution records. Nine predeclared source-only endpoints produced **72 retained directed query outcomes**: 30 native-complete queries, of which 20 passed the unchanged endpoint-association checks across five valid endpoints. Ten complete queries failed association; 42 other queries were incomplete or invalid. The longest accepted proposal was 6.189526 m.

**Coffee has zero movement episodes.** These are native Recast/Detour source-geometry proposals, not swept-body passes, observed free space, simulated arrivals or safe routes. No failed endpoint was replaced. Camera/mesh registration, coverage, hazard evaluation and movement remain open. Coffee is not a fresh blind holdout.

The exact source acquisition receipt records the full downloaded archive size (183,080,957 bytes), official MD5 match, and SHA-256 `591672a1c4afa50e5109fc78ff08d8f608d05756a9181cfdd7cef38a57a1623d`. Only the selected original mesh and transformation members are packaged, not the whole archive. The independent review verified selected member hashes and saved official metadata; it did not download the entire archive again.

## Limits, restoration and credits

Stage 76 still uses a 45 × 30 × 160 cm zero-margin body, assisted source ROI and evaluator/reference floor support in one static room. Floor contacts are unmeasured, source confidence remains unknown, and actual live RGB/LiDAR/IMU corruption was not tested. Neither packet establishes live iPhone navigation or human safety.

Each deterministic archive embeds a shared manifest and retains workspace-relative paths. Dependencies remain separately pinned; this is not a standalone runtime. Verify hashes before restoration and never overwrite divergent evidence. Stage 75 package/workflow files are excluded; this publication neither resumes nor substitutes for that cancelled operation.

Public source: Xuqian Ren et al., MuSHRoom, https://zenodo.org/records/10230733 and https://zenodo.org/records/10222321, CC BY 4.0. Coffee's detailed attribution, source acquisition receipt and original member hashes are included. Released Recast/Detour source credit and license are retained with the existing native adapter. No private participant data or user attachments are included.
