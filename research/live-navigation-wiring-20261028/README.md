# Live unfamiliar-place navigation: source wiring audit

**Source inspected:** `mischa23v/blind` at exact commit `dc32a9bad9a75566f27924fb9f7aa8fe50a46e95`, using the GitHub connector. All line references below refer to that commit, not an assumed moving branch. Parent reports documentation/evidence successor `5ee13e098468c342e2787f309111f505a1cbb22a` with the audited source unchanged; this audit does not claim a separate source comparison of that successor.

**Scope:** answer whether an unfamiliar place automatically becomes usable geometry and how present obstacles enter navigation. Read-only source inspection; no app implementation, feature activation, build, test, phone execution, push or movement authorization occurred in this audit. AGENTS.md and the continuous/contextual capability requirements were read. Prior saved-room/native test results are separate evidence.

## Bottom line

The normal foreground camera path already requests ARKit scene reconstruction on supported hardware, samples actual depth/anchors into local history, and accumulates an observed-surface preview with a short-horizon candidate planner. It is inaccurate to say the app has no automatic sensing or no geometry creation.

It is equally inaccurate to say this is a complete automatically built current-room navigation mesh with demonstrated obstacle avoidance. The full mesh-to-native-planner ingress is not live; current scene plans are explicitly nonphysical candidates; the production body-pose/support/error issuer is absent; and the delivery gate does not establish fresh full-body/head/ground clearance. New places cannot currently be promised working physical navigation from this source.

## The actual runtime paths

| Stage | Exact source evidence | Meaning / boundary |
| --- | --- | --- |
| Start the normal AR session | `ios/BlindAssist/NavigationModel.swift:1047–1064`; `NativeARObservationAdapter.swift:9–17` | Requests scene depth when supported, horizontal planes, and `.meshWithClassification` or `.mesh` when supported. Runs within the permitted foreground camera session; this is not a completed room scan or proof of complete coverage. |
| Existing sensor/hazard loop | `NavigationModel.swift:1218–1273,1319–1357,1435–1447`; `DepthSampler.swift:52–94` | Processes current depth and the independent hazard detector before nonurgent scene/history work. Tracking/depth loss withdraws evidence. No saved room is required to observe the local scene. |
| Bounded raw geometry history | `NativeARObservationAdapter.swift:49–101`; `NativeARObservationBridge.swift:6–9,82–110` | Captures actual camera/depth/plane/mesh observations into the history pipeline. Inspects at most 128 anchors, selects at most 32 surfaces and budgets 2,048 vertices, recording omissions. This sampled history is not a complete current navigation mesh, localization capture or route authority. |
| Live local surface preview | `NavigationModel.swift:1348–1354`; `ObservedSceneRuntime.swift:156–198,210–217`; `BlindCore/Sources/BlindCore/ObservedScene.swift:3–4,39–50,166–196` | High-confidence depth hits become bounded historical surface cells. The candidate planner uses only the current depth observation, not accumulated history as free space. Missing body profile permits accumulation but not a plan. |
| Candidate short-horizon planning | `BlindCore/Sources/BlindCore/LocalPlanner.swift:21–38,46–65,85–93`; `BlindCore/Sources/BlindCore/ObservedScene.swift:24,36` | Unknown cells are impassable; this is a look-ahead candidate, beginning 0.6 m ahead rather than verifying the wearer-to-path connector. Both snapshot and plan hard-code `authorizesPhysicalGuidance = false`. No authority to speak movement follows from a candidate path. |
| Full AR mesh to native candidate runtime | `ios/BlindAssist/MeshCandidateDiagnostics.swift:1–15,33–44`; `NavigationModel.swift:1188–1216` | Separate diagnostic seam, gated by `DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS`, process-local off by default. Add/update callbacks count events and explicitly refuse copying/ingest; they stop the owner. Removal passes an ID, not clearance. It does not produce a live mesh route. |
| Optional RTAB-Map grid | `ios/BlindAssist/NativeMapping.swift:25–37,98–151,172–188`; `NavigationModel.swift:259–260,1064,1254–1258` | Requires the separate `BLIND_RTABMAP` build and private-mapping choice. Its published local-grid status explicitly says “Not walking guidance.” No route consumer is established by this code. |
| Native camera candidate to body/map pose | `NavigationModel.swift:439–473`; `NativeLocalizationRouter.swift:82–95,104–112`; `NativeLocalizationIssuer.swift:4–6,20–32,45–56` | Calibration revision is `unconfigured`. Router/issuer collect only a candidate and withdraw physical evidence. No independently measured camera/body transform, support-coverage or uncertainty provider is supplied. Bench preparation never installs a pair or releases motion. |
| Physical route acceptance seam | `NavigationModel.swift:4745–4755`; `IndoorNavigator.swift:413–421` | Explicit acceptance/configuration APIs exist, but the source documents that the current camera/room-recognition path does not call them. Normal AR tracking or a recognized room cannot substitute for the missing measurements. |
| Stored-map route validation | `BlindCore/Sources/BlindCore/SpatialRouteOwner.swift:20–22,213–275` | Validates current pose/support ownership, uncertainty, route association and collision against the **installed map surface and restrictions**. It does not ingest the latest AR mesh or establish fresh whole-path clearance. A stored geometry ticket is explicitly not proof a real path is clear. |
| Guidance dispatch | `NavigationModel.swift:1789–1798,4785–4802`; `SpatialRouteOutputController.swift:19–43` | Rechecks exact route ownership, freshness and existing sensor status before dispatch/playback/watchdog. This protects ownership/expiry but cannot supply missing sensing, coverage, calibration or current obstacles. |

Unless a path is explicitly qualified as BlindCore above, filenames abbreviated in this table are under `ios/BlindAssist/`.

### Build flag and scan distinctions

The committed app Debug/Release flags in `ios/BlindAssist.xcodeproj/project.pbxproj:150–151` are respectively `$(inherited) DEBUG` and `$(inherited)`. They do not themselves enable RTAB-Map or mesh-candidate diagnostics. Linking the mesh package is not activation.

Deliberate RoomPlan scanning is a separate mode: `PlaceStore.swift:109–133` starts `RoomCaptureSession` and explicitly warns that phone hazard monitoring is paused; `188–197` updates `liveScanLayout`; `168–186` handles finish/cancel. This must not be described as automatic continuous full-room capture during normal walking. Existing voice confirmation requirements also remain.

The saved `originalRoomPlan`/Apple fixtures and `SavedRoomRouteMeshAdapter` tests concern saved source geometry. Their path results do not exercise new-place live mesh ingestion, actual body localization, moved furniture, current support, end-to-end phone latency or physical obstacle avoidance. They must not be counted as completion of the live pipeline above.

## Do not equate `observing` with clear space

`NavigationModel.swift:1794–1798` currently requires a fresh tracked frame and `detection.hazard == .observing` before checking the connected-journey ticket. That is not an independent target-specific swept-volume clearance proof:

- `BlindCore/Sources/BlindCore/HazardDetector.swift:22–23` calls the detector a level-floor research prototype, not a clearance test.
- Its measured corridor is camera-relative, 0.3–2.2 m ahead and ±0.38 m wide (`63–65`). Its nonhazard `observing` status follows repeated floor returns in the two central columns of the ground rows (`103–110`), not observed clearance through the intended full body/head/equipment trajectory.
- `BodyCollisionWarning.swift:3–5,22–26,73–75,96–104` supplies positive-observation warnings only. No observed intersection is not clearance, and this supplemental path deliberately does not classify feet, small steps, drops or terrain.
- `SpatialRouteOwner.swift:244–274` checks fresh pose/support metadata but collision geometry comes from the installed map plus restrictions. Metadata freshness does not refresh old obstacles.

Accordingly, filling in the missing pose issuer alone would not complete safe navigation. Do not bypass it, equate no detection with free space, lower body bounds to force paths, or convert a historical mesh/route into permission to walk.

## Smallest safe next implementation stage

**P0 — one connected, explicitly nonwalking live-mesh diagnostic.** Reuse the already implemented `ARKitMeshAdapter82 → MeshCandidateIngress83 → BlindRoomMesh/Recast–Detour` chain rather than creating another mapper/planner. The immediate blocker is valid native callback/buffer ownership and bounded copy/admission, not missing Recast code.

1. First establish the serialized native producer/Metal-buffer lifetime contract for the existing app owner. The current delegate is on `.main` (`NavigationModel.swift:671`); blindly copying there, queueing borrowed anchors/buffers, moving the entire delegate, or creating another camera session is not the solution. Preserve independent hazard-first processing.
2. Connect bounded owned geometry updates/removals to the existing candidate runtime in a separately reviewed opt-in diagnostic. Carry session, anchor revision, missing-update/coverage state and coordinate frame. Preserve explicit unknown/gap state, and invalidate stale results on removal, tracking loss, scan transition, stop/background and owner replacement.
3. Display the actual evolving observed geometry/candidate route with camera-pose provenance and unknown areas. Do not label camera pose as body pose, invent room boundaries/free floor, install a physical route ticket, or connect speech/beacon movement output. Keep candidate/physical-authority boundaries false.
4. Verify real callback lifecycle and native memory ownership, then measure hazard/main callback delay, capture-to-candidate latency and bounded working set on a supported phone. Review original failures and unknowns rather than relaxing gates. A seated/bench diagnostic establishes capture/wiring only, not walking acceptance.

This scope is complete only when the exact native app can demonstrate real new-place geometry updates, explicit removals/loss retirement and bounded diagnostic behavior, with no physical output. A compile-only pass or static fixture path is not that result. Source changes, device activation and experiments require their separately applicable authorization; this audit activates none.

**P1 — measured localization and a separate current-clearance owner.** After the diagnostic contract is established, connect reviewed measured camera-to-body transform/body heading and uncertainty, floor/frame association and target-specific support. Add fresh positive coverage of the intended uncertainty-expanded swept body/equipment/head/ground/near-feet path, including stopping/delay motion, as a separately owned delivery condition. Moved/occluded/unknown obstacles must retire a route; historical geometry can propose a route but never grant current clearance. Use established platform/upstream components and document remaining sensing gaps rather than inventing a replacement algorithm.

**P2 — controlled end-to-end acceptance, then supervised walking.** Exercise new room, changed furniture/door, low and overhead obstacles, missing head/foot/side coverage, tracking loss, background, late callbacks, body/mount change, goal change and replanning. Keep recording, simulation, native build, actual-phone sensing and supervised physical evidence distinct. No child or eyes-closed trial should be used to discover these integration failures; preserve the repository's adult/sighted-observer and O&M/guardian gates.

## Supporting existing contracts

- [`research/arkit-mesh-adapter-82/README.md`](../arkit-mesh-adapter-82/README.md): native snapshot ownership and pre-copy budgets; no capture timestamp invented from anchor receipt; copy/main/hazard latency still needs device evidence.
- [`research/mesh-candidate-ingress-83/README.md`](../mesh-candidate-ingress-83/README.md): owned values only, single bounded capture/decode reservation by default, exact revision retirement and explicit unknown gaps; not an activated app pipeline.
- [`research/native-candidate-app-integration-85/integrated/README.md`](../native-candidate-app-integration-85/integrated/README.md): integration remains lifecycle/counters only; no geometry copy or movement authority. Earlier proposal-only notes are historical, not a claim the source file is absent now.
- [`research/CONNECTED_NAVIGATION_USER_FLOW.md`](../CONNECTED_NAVIGATION_USER_FLOW.md): connected current-room/body-pose/geometry/route requirements.

**Verification status:** exact-revision source read and line-bound audit only. No tests or Apple/device commands were run. No claim of native readiness, comprehensive recognition, complete room coverage or safe independent use is made.
