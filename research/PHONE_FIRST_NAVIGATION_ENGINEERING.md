# Phone first navigation engineering

Reviewed 26 October 2026. This is a technical research and source audit, not a device benchmark, procurement decision or approval for independent navigation. App code references are pinned to [`e677c185c208728b02b103247913ef03a1467c1b`](https://github.com/mischa23v/blind/tree/e677c185c208728b02b103247913ef03a1467c1b); its production source is unchanged from `c8aa872` apart from the hosted workflow.

## Decision

Build on the existing phone, body geometry, mapping, route and wearable code. First measure and optimize the phone's sensing and computation; then measure the intended belt's complementary coverage and integrate it. **Phone first is a development sequence, not a phone only product.** A faster processor can help run more computation, but cannot see behind the wearer, through an occluder, or establish a trustworthy floor where the sensor supplied no usable observation.

All acquisition, transformations, maps, room/container relationships, object detection, collision checks, route generation and replay remain code owned. An LLM may explain a structured result; it must not invent geometry, clearance, location or movement commands. Practical prototypes may use explicitly labelled assumptions, but an assumed body or ideal mount is not evidence about an individual wearer.

## What the two phones actually provide

These are manufacturer specifications, not measured performance in this app.

| Capability | iPhone 13 Pro | iPhone 18 Pro Max |
| --- | --- | --- |
| Processor | A15 Bionic; 6 CPU cores, 5 GPU cores, 16-core Neural Engine | A20 Pro; 6 CPU cores, 7 GPU cores with Neural Accelerators, dual 16-core Neural Engine |
| Rear RGB cameras | 12MP Wide, Ultra Wide and Telephoto | 48MP Main, Ultra Wide and Telephoto; Main has variable aperture |
| Depth and inertial hardware | LiDAR scanner, gyroscope, accelerometer, barometer | LiDAR scanner, high dynamic range gyro, high-g accelerometer, barometer |
| Mount load and size | 204 g; 71.5 × 146.7 × 7.65 mm | 249 g; 78.0 × 163.4 × 8.75 mm |
| Wired connection | Lightning | USB-C with USB 3 support |

Sources: [Apple iPhone 13 Pro specifications](https://support.apple.com/en-us/111871), [Apple iPhone 18 Pro specifications](https://www.apple.com/iphone-18-pro/specs/).

Both specifications associate **120° with the Ultra Wide RGB camera, not the LiDAR field of view**. Neither inspected specification establishes the LiDAR's usable near-field coverage, per-material error, minimum detectable obstacle or sustained mapping-plus-model throughput. Camera megapixels are not depth-map resolution. No A15-to-A20 speed ratio, navigation battery life or RAM capacity is asserted here.

Apple Intelligence eligibility is a separate question from ARKit support. The 13 Pro is outside Apple's eligible hardware list; the 18 Pro Max is eligible hardware, subject to software, language, region and model availability. This does not mean the 13 Pro cannot run any third-party local model, nor that an eligible phone can run every task concurrently within a latency budget. Select the actual provider/model, verify on-device availability, and enforce the app's local-only policy across tool calls and external services as well as inference. Framework eligibility alone does not establish the whole app's execution policy. [Apple eligibility](https://support.apple.com/guide/iphone/get-started-with-apple-intelligence-iphc28624b81/27/ios/27), [Foundation Models availability and generation](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models).

## Sensing limits that computation does not remove

Apple describes scene depth as a lower-resolution depth product derived from LiDAR and RGB, with confidence categories; reflective and absorbing surfaces affect accuracy. ARKit depth represents distance from the camera plane in metres, so projection must use the actual intrinsics and coordinate conventions rather than treating every depth value as Euclidean ray length. Confidence is not a calibrated probability that a body-sized corridor is safe. [ARKit depth data](https://developer.apple.com/documentation/arkit/ardepthdata), [Apple ARKit 4 technical session](https://developer.apple.com/videos/play/wwdc2020/10611/).

AVFoundation also exposes synchronized LiDAR depth/video capture on supported devices, but formats must be enumerated at runtime. It is a capture interface, not proof that two independent camera owners can operate together without interference. [Apple LiDAR capture](https://developer.apple.com/documentation/AVFoundation/capturing-depth-using-the-lidar-camera).

The next measurements must distinguish:

- **Coverage:** actual RGB/depth intrinsics, image boundaries, chest tilt, near-field blind area, legs/body/strap occlusion, side and rear gaps, and coverage at head, torso, knee and foot heights.
- **Measurement validity:** glass, mirrors, dark/absorbing surfaces, thin legs and edges, bright light, motion, confidence holes and missing depth. These are test conditions, not claimed measured failure rates.
- **Association:** sensor acquisition time, processing age, tracking quality, world-frame/session changes, camera-to-body transform and mount slip.
- **Ground evidence:** an observed support surface with uncertainty and continuity, not simply a nearby horizontal tabletop or a remembered plane.

A body envelope needs recorded dimensions and equipment extent; a mount needs measured position and orientation relative to the body. Age, weight and gender may support an explicitly approximate setup or simulation preset, but cannot establish an individual's width, head clearance, stride or phone transform. Camera optical heading is not walking direction. Speed and step data can support motion estimation and a time-to-contact budget; they do not fill missing depth or authorize running.

The existing detector's 0.65–1.9 m floor-calibration height interval is a real operating-range question for low mounts and short users. Do not widen it merely to make a recording pass. A subsequent profile-bound design should retain observed-plane, stationary, consistency and incorrect-plane rejection gates, with mount uncertainty and dedicated low-height fixtures.

Apple itself excludes Magnifier Detection Mode from navigation and other high-risk reliance. That warning does not forbid engineering a prototype; it does mean the platform feature is not a navigation safety certification. [Apple Detection Mode guidance](https://support.apple.com/guide/iphone/detect-doors-people-and-furniture-around-you-iph35c335575/ios).

## Efficient geometry rather than photorealistic rendering

**Proposed architecture, not a claim that every layer is complete:**

1. Keep a bounded, timestamped local 3D representation near the body: occupied observations, genuinely ray-observed free space, unknown volume and separately validated support. Retain source/session/frame provenance and uncertainty. Use existing spatial indexing and mapping libraries, not a new SLAM or ray-casting algorithm.
2. Retain coarser submaps farther away. Rooms, portals, containers and object identities form a typed semantic graph anchored to observed geometry. Detector labels enrich that graph; labels alone cannot make an unseen region traversable.
3. Derive a 2D or 2.5D navigation graph/navmesh from support and clearance evidence. Preserve floor level, slope/step constraints, overhead height and body/equipment dimensions instead of flattening everything into an obstacle-free image.
4. Check a proposed route's swept body volume against local 3D obstacles and support uncertainty. A global route never suppresses a current hazard, mount fault or stale localization. Unknown remains unknown.
5. Render a debug view only when needed. A navigation system needs geometric queries and state, not a continuously shaded photorealistic game scene. A game commonly starts with a known complete world; this app must construct and qualify an incomplete one.

Continue the existing RTAB-Map, local observation and Recast/Detour adoption boundaries. Their reputation does not validate our adapters or turn a navmesh polygon into physical clearance. Existing adoption records are in [the upstream review](ASSISTANT_UPSTREAM_REVIEW.md). Google Maps or other outdoor/POI context must remain separate from current private-interior furniture, floor and collision evidence.

## Concurrent workload and resource priorities

There is no verified sustained benchmark here for tracking + mapping + detectors + local LLM + speech on either phone. CPU/GPU/Neural Engine core counts are not additive guarantees of app throughput. Model weights, intermediate tensors, language-model caches, camera buffers, maps and audio work compete for resources.

Apple documents thermal states that require reducing work, and camera system pressure can interrupt capture. Measure these states rather than assuming a fast cold run predicts sustained operation. Direct AVFoundation controls apply only where that capture owner exposes them; an ARKit-owned session needs its own supported configuration and lifecycle handling. [Thermal state](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property), [serious thermal state](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum/serious), [camera pressure](https://developer.apple.com/documentation/avfoundation/avcapturedevice/systempressurestate-swift.property).

The proposed scheduling order is:

| Lane | Priority and bounded behavior |
| --- | --- |
| Urgent sensing and warnings | Freshness, tracking/mount validity, direct depth/body hazards and wearable local alerts. No LLM or network dependency. Expired data cannot authorize movement. |
| Local geometry and association | Latest-frame bounded work, pose association, support/obstacle updates and candidate body collision. Do not build an unbounded backlog. |
| Persistent mapping | Incremental keyframes, registration and loop closure with revision fences. Map corrections must retire stale route coordinates. |
| Object and contextual perception | Event/region-driven, bounded image size and concurrency; do not rerun every large model on every camera frame. |
| Language and ordinary speech | Explain validated results, cap generation and queue length, defer/cancel nonurgent work under pressure. Urgent fixed cues must not wait for model completion or ordinary narration budgets. |

Profile Core ML execution choices on the actual model. `cpuAndNeuralEngine` can avoid GPU contention, but does not promise Neural-Engine-only execution or a faster whole app. [Core ML configuration](https://developer.apple.com/documentation/coreml/mlmodelconfiguration), [Apple optimization session](https://developer.apple.com/videos/play/wwdc2022/10027/).

Measure capture-to-decision and capture-to-delivery p50/p95/p99, worst observed age, dropped/skipped frames, warning queue delay, peak memory, thermal state, battery drain and sensor outages during sustained mixed workloads. Start with sensing alone, then add mapping, detectors, speech and language generation one at a time. Reduce optional model/rendering work before compromising urgent sensing. If quality or deadlines cannot be maintained, report degraded/unavailable capability rather than silently loosening confidence thresholds. Manufacturer video-playback battery figures do not establish navigation runtime.

### Existing code that should be retained

The following files were locally read and their Git blob hashes matched the pinned app tree:

- [`NavigationModel.swift`](https://github.com/mischa23v/blind/blob/e677c185c208728b02b103247913ef03a1467c1b/ios/BlindAssist/NavigationModel.swift) admits the hazard lane at at most approximately 15 Hz. RTAB mapping is deferred until callback exit and observed-scene offers follow the detector; an earlier native-observation consumer can already offer bounded raw history. Whole-lane latency and resource ordering still need measurement. This is app processing admission, not a claim that ARKit acquisition or hardware power runs at 15 Hz. Room scanning currently excludes this phone hazard callback, an important mode boundary.
- [`NativeDepthObservationPolicy.swift`](https://github.com/mischa23v/blind/blob/e677c185c208728b02b103247913ef03a1467c1b/BlindCore/Sources/BlindCore/NativeDepthObservationPolicy.swift) shares stride 2, confidence 2, 0.15–5 m and projection arithmetic with replay. These are application filters, not Apple accuracy specifications.
- [`ObservedSceneRuntime.swift`](https://github.com/mischa23v/blind/blob/e677c185c208728b02b103247913ef03a1467c1b/ios/BlindAssist/ObservedSceneRuntime.swift) bounds asynchronous candidate work and fences revisions. [`BodyProfile.swift`](https://github.com/mischa23v/blind/blob/e677c185c208728b02b103247913ef03a1467c1b/BlindCore/Sources/BlindCore/BodyProfile.swift) distinguishes recorded bounds from estimated/default preview values.
- [`BackgroundPerceptionAdmission.swift`](https://github.com/mischa23v/blind/blob/e677c185c208728b02b103247913ef03a1467c1b/BlindCore/Sources/BlindCore/BackgroundPerceptionAdmission.swift) bounds nonurgent producers. Cancellation retires output but does not magically stop an in-flight native inference. This is useful admission infrastructure, not a global thermal governor.

No centralized thermal/system-pressure admission policy was found in the inspected native owners. That is an implementation gap to address after measuring this workload, not grounds for replacing tested geometry code. Existing signposts are a starting point; they are not a sustained device benchmark.

## The belt already has a concrete sensing design

The existing [buying plan](https://github.com/mischa23v/blind/blob/e677c185c208728b02b103247913ef03a1467c1b/hardware/BUYING_PLAN.md), [connections](https://github.com/mischa23v/blind/blob/e677c185c208728b02b103247913ef03a1467c1b/hardware/CONNECTIONS.md), [firmware](https://github.com/mischa23v/blind/blob/e677c185c208728b02b103247913ef03a1467c1b/firmware/belt/src/main.cpp) and [BLE protocol](https://github.com/mischa23v/blind/blob/e677c185c208728b02b103247913ef03a1467c1b/hardware/PROTOCOL.md) were inspected before considering new sensors.

| Existing component | Intended complementary role | Still needs measurement |
| --- | --- | --- |
| Two downward TFmini-S sensors | Ground-range changes outside the phone's useful view | Mount angle/height, footprint, surface response, motion compensation and latency |
| Eight VL53L5CX ring sensors | Body-sector ranging; firmware uses 4 × 4 zones at 5 Hz | Actual overlap/gaps, zone orientation, interference and clothed-body occlusion |
| Upward VL53L1X | Overhead range warning | Head/equipment coverage and off-axis hazards |
| Forward MB1040 ultrasonic | Complementary front ranging | Beam geometry, material/angle response and interaction with other channels |
| Eight LRA haptic channels | Directional output | Perceptibility, motor operation, fit and command-to-pulse latency |
| Optional wrist ranging node | Pointing range and local pulse | Wrist orientation, coverage and correct association |

A haptic belt without ranging adds output, not sensing coverage. Conversely, a ring of sparse range sensors is not automatically dense 360° 3D perception. The phone/body transform does not calibrate each belt sensor.

Current transport facts: the summary is nominally 20 Hz, while ring sampling is 5 Hz; raw samples carry MCU uptime and sequence numbers, and the phone assembles only complete fragments. The 0.8 s summary timeout is liveness, not detection latency. Application payload is budgeted at about 4,400 bytes/s before BLE overhead/retries. Unknown ranges stay unknown.

The protocol lacks sensor extrinsics, IMU orientation, clock synchronization, battery reporting and negotiated capability tables. MCU timestamps are not synchronized phone time. Secure transport currently uses encrypted but unauthenticated bonding, without completed physical-owner enrollment/reset. The local warning path continues without the phone, but this is not proof against stuck buses or failed motors. The downward 250 mm threshold is a prototype slant-range-change threshold, not a guaranteed detectable stair height.

**Next sensor decision:** make a measured phone-plus-belt coverage matrix before choosing another SKU. Determine whether the unresolved gap is downward geometry, side/head coverage, timing, strap motion, material response or power. A belt IMU or another sensor may be justified by that gap, but neither has been selected or installed by this research.

## Reusable research and code

Source availability, licensing, an upstream demonstration and our tested integration are different evidence levels. No listed upstream package was installed or built during this audit. A root license does not automatically cover bundled weights, datasets, trademarks or every dependency.

| Work and inspected revision | Verified evidence | Reuse boundary |
| --- | --- | --- |
| [Corridor-Walker, CMU, 2022](https://publications.ri.cmu.edu/corridor-walker-mobile-indoor-walking-assistance-for-blind-people-to-avoid-obstacles-and-recognize-intersections) | Institutional abstract describes LiDAR-to-2D-occupancy navigation/intersection assistance and a study with 14 blind participants. | Relevant design and study precedent. A released, licensed implementation was **not verified** in the bounded author/institution/repository search; this is not a claim none exists. |
| [RAIS, ASSETS 2024](https://makeabilitylab.cs.washington.edu/media/publications/Su_RaisTowardsARoboticMappingAndAssessmentToolForIndoorAccessibilityUsingCommodityHardware_ASSETS2024.pdf) | iPhone 13 Pro Max, Create 3 robot and phone gimbal; preliminary scans of three indoor spaces. Paper reports 75% of accessibility issues detected; the routing-width category was manually filtered. | Demonstrates commodity-phone mapping feasibility, not continuous blind-wearer collision avoidance. A standalone licensed release of the complete robot/gimbal stack was not verified. |
| [RASSAR `23c92be`](https://github.com/makeabilitylab/RASSAR/tree/23c92be842733236613a5d11fd5a083cce0c7c3a) | Public iOS source; [MIT license](https://github.com/makeabilitylab/RASSAR/blob/23c92be842733236613a5d11fd5a083cce0c7c3a/LICENSE); ARKit/RoomPlan and detector integration. | Candidate semantic/accessibility audit adapters, not a complete live route system. Model-file metadata was inspected, not weights downloaded; verify model/data licenses separately. No test/workflow paths were found in the inspected tree. |
| [Clew `b8ef390`](https://github.com/occamLab/Clew/tree/b8ef390aa47074a8faabfd32f765e2359ad8b927) | Public Swift ARKit breadcrumb/retrace source; README describes older toolchain/dependency setup. No repository license file was found in the inspected tree. | Useful architectural reference; **copy/adaptation permission unresolved**. Public source and an app demonstration do not establish permission or current buildability. |
| [iOS-LiDAR2ROS `736343a`](https://github.com/Soboroo/iOS-LiDAR2ROS/tree/736343a0e4cfcf27a3ceb263b84225efd3b79f58) | [Apache-2.0](https://github.com/Soboroo/iOS-LiDAR2ROS/blob/736343a0e4cfcf27a3ceb263b84225efd3b79f58/LICENSE), separate Apple MIT notice; image/depth/point-cloud/intrinsics/transform transport. | Reuse candidate for a bounded recording/coordinate bridge. Its external ROS receiver and network failure modes are not phone-only navigation evidence. |
| [ARKit-to-ROS-Bridge-V2 `4136bb6`](https://github.com/ion206/ARKit-to-ROS-Bridge-V2/tree/4136bb6c4ce4ae960c020e11732fa68db54d2441) | Swift sender and chunked UDP design; separate ROS receiver. No license file was found in the inspected tree. | Reference only pending permission. README latency/accuracy claims were not independently measured. |
| [CaBot navigation `e8a9970`](https://github.com/CMU-cabot/cabot-navigation/tree/e8a9970e2fc94e4180d453b84e6a3a2e4bfb1479) | [MIT root license](https://github.com/CMU-cabot/cabot-navigation/blob/e8a9970e2fc94e4180d453b84e6a3a2e4bfb1479/LICENSE); actual build/test workflows and planner/path/evaluator test sources exist. | Strong robot-navigation reference; retain dependency notices. Test presence is not a verified green run, and robot odometry/control/footprints do not establish wearer pose or gait. |
| [Create 3 examples `fe3d408`](https://github.com/iRobotEducation/create3_examples/tree/fe3d408a266b755b94cb7334a92f2d58dd661c13) | [BSD-3-Clause](https://github.com/iRobotEducation/create3_examples/blob/fe3d408a266b755b94cb7334a92f2d58dd661c13/LICENSE.txt). Its LiDAR SLAM example explicitly adds Raspberry Pi 4 and RPLIDAR A1M8 plus calibrated mounting transforms. | Reuse transform and integration patterns. Do not present this as a bare vacuum or phone alone performing the whole stack. |

The existing [Soundscape review](ASSISTANT_UPSTREAM_REVIEW.md) remains relevant for callout ordering, history and motion context. It explicitly records an audio-engine race caveat in the inspected workflow. Soundscape is not a substitute for body collision, ground sensing or local map uncertainty; no whole-app adoption is implied.

## Next evidence gate

Keep route/map/return test expansion paused until the sensing/workload protocol is reviewed. The next authorization should specify:

1. Exact phone, OS, app commit and model versions; measured mount height/offset/pitch and body/equipment dimensions. Record approximate inputs as approximate.
2. Bench fixtures with independent distance/support truth, including low mounts, tabletop confusion, head-height obstacles, thin obstacles, reflective/absorbing surfaces, near-field occlusion and deliberate mount slip.
3. Sensing-only baseline, then mapping, detectors, speech and local-model load added separately; sustained thermal/battery runs and injected transport delays. Compare identical fixtures across devices rather than extrapolating chip specifications.
4. Phone-only measurements followed by each existing belt channel and combined operation. Record observed gaps, false warnings, misses, stale samples, end-to-end latency and unknown coverage; do not just count successful detections.
5. Only after those results, candidate path, map persistence and return-route tests with independent localization and collision truth. Recorded walks are open-loop; simulation is conditional on its sensor/body assumptions. Neither is a completed real-world journey following our guidance.

This research changes no thresholds, installs no dependencies, purchases no hardware and authorizes no exposed-drop or child mobility trial. It establishes a practical next measurement plan while preserving the existing code.

## Confidence and unresolved questions

**High confidence:** the cited manufacturer specifications, the inspected paper claims within their stated scope, and the pinned source/license findings. **Not established:** comparative sustained speed, detection reliability, complete body coverage, battery duration, actual belt calibration, model quality under load or physical navigation safety. Code availability is not integration validation; a missing license finding is an unresolved permission question, not a legal determination. Dynamic vendor pages and repository heads can change, so this audit records its date and exact code revisions.

