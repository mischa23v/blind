# Reusing room coverage and active mapping for accessible acquisition

Research date: 2026-10-26. Status: source review and proposed requirements, not implemented or validated. No installations, new recordings, remote writes, or navigation trials performed for this note.

## Decision

Use existing acquisition/SLAM components and teach useful translation through a room before building a custom exploration planner. The user's intended multiple passes mean observations from different physical positions, not standing still and rotating or rereading a recording. A useful acquisition system must distinguish:

- **Cleaning coverage:** a tool footprint traverses floor area.
- **Sensing coverage:** relevant surfaces are observed despite occlusion, viewing geometry, range, and uncertainty.
- **Loop closure:** a valid revisit constrains accumulated pose error. Fusing more depth frames does not by itself implement pose-graph loop closure.
- **Live collision protection:** recent observations guard motion; a historical reconstruction is not evidence that a corridor remains clear.

## Existing evidence and limitations

The saved project evidence reports an Open3D TSDF reconstruction of 265 Koivu frames, held-out median disagreement of 3.17 cm and p95 disagreement of 73 cm. These are agreement figures, not independent ground-truth accuracy or navigation validation. Floor misclassification remains material.

The saved project evidence also reports a split0.5support/0.7obstacle OctoMap experiment on two real rooms: routes only on a permissive unresolved map (`coffee21`; `stat-cleared0`), no additional open-floor misses versus its baseline, and four Koivu baseline misses remaining. Preserve these labels as reported; this note did not inspect the experiment artifacts or independently verify its metrics. Permissive routing through unresolved cells is not successful conservative navigation. No increase in baseline misses is not evidence that the baseline is safe.

Existing recordings can test **only the viewpoints actually recorded**. Nested subsets can show whether previously excluded recorded viewpoints resolve uncertainty. Processing changes may reinterpret old evidence; neither reprocessing nor duplicating frames supplies new sensor evidence, reveals unseen occlusions, or constitutes a physical rescan.

## Primary evidence

1. **Quality-aware active mapping:** Schmid et al., RA-L 2020, separates unknown-volume exploration from TSDF reconstruction quality. Its planner discovers surfaces then revisits uncertain areas. The paper warns that high fusion weight need not imply high quality; some revisits have similarly poor views and do not improve reconstruction. Its real-MAV experiment used Vicon state information to avoid compounding pose drift, limiting transfer to phone-only SLAM. Source: https://arxiv.org/html/1909.09548v2
2. **Loop closure:** RTAB-Map's authors describe appearance-based loop closure and visual/LiDAR SLAM for online operation. This is a reusable comparator, not evidence that it fixes this dataset. Source: https://arxiv.org/abs/2403.06341
3. **Apple capture conditions:** RoomPlan offers distance, speed, lighting, and texture guidance. Apple recommends at least 50 lux, avoiding single scans over five minutes, and notes challenges with mirrors, glass, dark surfaces and high ceilings. LiDAR-enabled hardware is required. Verify whether 'iPhone 12' means Pro/Pro Max; a base iPhone 12 cannot be assumed compatible. Source: https://developer.apple.com/videos/play/wwdc2022/10127/
4. **Accessible reuse:** RoomPlan added VoiceOver spoken scanning guidance and scene descriptions in iOS 17. It also supports custom ARSession use and linking room scans through a continuous session or saved-world-map relocalization. Shared coordinates do not establish complete geometry or safe navigation. Source: https://developer.apple.com/videos/play/wwdc2023/10192/
5. **Local mapping status:** ARKit `mapped` describes mapping of the currently visible/local area and reliability for world-map relocalization, not whole-room completion. Source: https://developer.apple.com/documentation/arkit/arframe/worldmappingstatus-swift.enum/mapped?changes=late_8&language=objc
6. **Separate live layers:** Nav2 uses static, live obstacle/voxel, and inflation layers. Collision Monitor can consume fresh sensor data outside the costmap/planner path and explicitly does not provide hard real-time safety certification. Sources: https://docs.nav2.org/jazzy/configuration_and_development/configuration_guide/core_servers/costmap_2d/ and https://docs.nav2.org/rolling/configuration_and_development/configuration_guide/core_servers/collision_monitor/configuring_collision_monitor_node/

Inference from these sources: count diverse useful views, not frames, when evaluating confirmation. Correlated frames, common pose error, and persistent depth bias can agree while being wrong. The sources do not prescribe a universal minimum translation or number of passes for this phone/task.

## Reusable code and constraints

| Candidate | Role | License/platform caveat |
|---|---|---|
| https://github.com/introlab/rtabmap | Existing capture, loop closure, desktop analysis baseline | Core BSD-3-Clause; audit optional dependencies. iOS app targets LiDAR iPhone/iPad. Source build needs Xcode; dependency script documented as tested on Apple Silicon. |
| https://github.com/ethz-asl/mav_active_3d_planning | Quality-aware view/trajectory scoring and evaluation | BSD-3-Clause. Core can build standalone; full demonstrations use Linux/ROS catkin and drone-specific assumptions. Not a ready-made human walking coach. |
| https://github.com/ipa320/ipa_coverage_planning | Indoor cleaning/floor-inspection coverage reference | ROS 1. `ipa_room_exploration/package.xml` declares academic/noncommercial LGPL use and commercial contact with Fraunhofer. Do not treat it as an unrestricted commercial dependency. |
| https://github.com/Fields2Cover/Fields2Cover | Permissive sweep-pattern baseline | BSD-3; C++17/Python; GDAL/GEOS/OR-tools dependencies. Agricultural coverage assumptions; does not solve sensing or unknown-space exploration. |
| https://github.com/ros-navigation/navigation2 | Static/live map separation and collision architecture | ROS 2, not native iOS. Licenses vary by package/file; repository lists Apache, BSD and LGPL terms. |

License/build evidence: https://github.com/introlab/rtabmap/blob/master/LICENSE ; https://github.com/introlab/rtabmap/wiki/Installation ; https://github.com/ipa320/ipa_coverage_planning/blob/noetic_dev/ipa_room_exploration/package.xml ; https://github.com/ros-navigation/navigation2/blob/main/LICENSE . Recheck exact versions and dependency licenses before adoption.

## Proposed acquisition-coach requirements — not tested

First reuse RoomCaptureView VoiceOver and RoomCaptureSession instructions. Add custom prompts only for gaps demonstrated by tests. All prompts must be available as speech and accessible text; haptics may supplement, not replace, understandable speech. Avoid visual-only references such as 'scan the red patch'. Allow repeat, pause, stop, and explanation. Do not make users memorize an unverified route.

### Required state and logging

Record timestamped tracking state/reason, world-mapping status, camera pose/intrinsics, depth availability/confidence where supported, RoomPlan instruction events, session identity, and accepted/rejected pose corrections where exposed. Record measured geometry coverage separately from semantic labels. Per region, retain observed/unknown/contradictory states, range, spatial/view-direction diversity, and provenance. Do not label raw fusion weights as calibrated confidence. Record unavailable signals explicitly; do not infer lux from image brightness without calibration.

Candidate camera viewpoints and full swept human corridors must be separate objects. A view may be valuable while the path to it is unsafe. A room-level mapped flag must never authorize movement.

### Trigger-to-prompt specification

| Measurable trigger | Example nonvisual prompt | Required guard |
|---|---|---|
| Tracking unavailable/limited or relocalization unresolved | 'Pause walking. Tracking is uncertain. Keep the phone steady while we recover.' | Suspend movement coaching and geometry-confidence promotion; explain relevant reason when available. |
| Framework reports excessive motion | 'Stay where you are and move the phone more slowly.' | No implied instruction to take a step. |
| RoomPlan reports inadequate light | 'The room is too dark for a reliable scan. Please improve the lighting if you can do so safely.' | Prefer actual framework signal; no fabricated lux measurement. |
| RoomPlan reports unsuitable distance | 'The camera needs more distance from this surface. Pause; I cannot yet confirm a place to move.' | Never translate 'farther away' into blind backward walking. Movement waits for separately verified clearance. |
| Region still unknown or seen only from a narrow range of positions | 'This area needs another viewpoint, not more time from here.' | Announce a specific destination only when localization and an entire safe corridor have been validated. Otherwise ask for assistance or leave region unresolved. |
| Useful surface accessible from current stationary position | 'Stay where you are. Slowly aim the phone lower to scan the wall and floor boundary.' | Direction grounded in pose/target; no promise that phone aiming alone completes the region. |
| Cross-view geometry disagreement or unresolved floor support | 'These observations disagree. This area is not confirmed for walking.' | Preserve uncertainty; do not vote it away with repeated same-view samples. |
| Qualified revisit opportunity | 'We can check alignment against an earlier view.' | Only propose physical return over a currently verified route; report actual relocalization outcome separately from arrival. |
| Fresh obstacle sensing stale/unavailable or corridor uncertain | 'Pause. I cannot confirm the way ahead.' | Fail closed for app-directed movement; historic free space is insufficient. |
| Information gain plateaus despite additional frames | 'This position is not adding useful coverage. We need another safe viewpoint, or we can stop with this area unresolved.' | Do not invent a universal frame count or baseline threshold. |

Thresholds for viewpoint diversity, tracking recovery duration, range, stale sensing, corridor clearance, and completeness require sensor/task calibration and accessibility review. No numerical thresholds are specified here beyond Apple's explicitly sourced capture recommendations. Even a fresh depth corridor is not automatically validated human safety: drop-offs, transparent obstacles, body/head clearance and sensor failure require dedicated testing. Initial acquisition experiments must use a human-inspected route and appropriate supervision, not autonomous instructions into unknown space.

Priority order: stop/uncertainty > tracking recovery > capture-condition correction > useful next view > optional progress. Rate-limit/debounce prompts, cancel stale instructions, and ensure speech cannot overlap or obscure urgent information. 'Scan complete' must distinguish geometric completeness, semantic completion, and tracking quality; never imply navigation certification.

## Bounded next experiment

### A. Existing recording, offline only

1. Inventory actual camera centers, orientations, ranges and temporal blocks. Determine whether meaningful translated revisits exist. If none exist, report that the dataset cannot test the proposed benefit.
2. Build a fixed first-pass subset, then nested subsets adding distinct recorded spatial/viewpoint blocks. Compare against an equal-frame-budget adjacent-frame control. Never duplicate frames to simulate new evidence.
3. Hold out an entire separate pass or spatially distinct block when available; do not call interleaved near-identical frames independent validation. If no suitable holdout exists, report descriptive coverage only.
4. Keep calibration, fusion and occupancy rules fixed to isolate added recorded evidence. Separately test processing changes under fixed input. Label these two comparisons distinctly.
5. Report unknown/contradictory area, view diversity, floor/support errors, missed obstacles, completeness, median/p95 held-out disagreement, and conservative route availability. Re-audit the four reported baseline misses individually. Compare against independently labeled/measured evidence where available; withheld sensor observations are not ground truth.
6. End after all eligible recorded viewpoint blocks have been evaluated. Success is evidence about marginal coverage/consistency, not declaring navigation solved. If uncertainty remains where no recorded ray can resolve it, explicitly require new capture.

### B. New physical recording, only when authorized and available

Use one static, well-lit room with an inspected walking route. Compare an initial perimeter loop against additional cross-room/opposite-side views and a return to the start, plus targeted views of unresolved areas. Do not require stepping through unknown cells to resolve them. Keep conditions and processing comparable; capture an independent later pass and measured door/obstacle dimensions. Compare existing TSDF processing with RTAB-Map loop closure; use RoomPlan as a semantic/layout comparator, not truth. Keep scan duration/thermals within Apple guidance. End once the planned safe route and targeted checks are complete, then report unresolved regions honestly. Real navigation remains out of scope until separate live-obstacle, localization and human-safety validation.

## Retrieval limitations

Apple's general session-lifecycle page returned JavaScript-only content and its Markdown endpoint produced a web-tool content-type error. No claims here depend on the unread body. Sources listed above were accessible. No commercial-vacuum proprietary mapping algorithm was inspected; these are transferable robotics/Apple methods, not claims that every vacuum implements a particular technique.
