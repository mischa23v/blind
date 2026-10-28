# What we should reuse, what we must build, and the next navigation milestone

**Decision plan — 28 October 2026.** Based on the [verified current audit at `da71dd7`](https://github.com/mischa23v/blind/blob/da71dd745abfcd7d6b7c29e900bdcadd1574760a/research/geometry-independent-audit-20261028/CURRENT_AUDIT.md), the [live wiring audit](../live-navigation-wiring-20261028/README.md), and existing implementation contracts. This is a plan, not a claim that the missing integration or device tests have run. Publication receipts for the associated benchmark bundles are separate.

## Recommendation

**Continue, but finish one connected furnished-room navigation slice before expanding the navigation scope:** observe the room → establish actual phone/body position and heading → create a route on correctly scaled geometry → independently check body collisions and supporting floor → update or withdraw the route as live evidence changes. Demonstrate the intended route and actual tracked trajectory together.

Do not write another SLAM engine, 3D engine or pathfinder. Reuse the existing Apple acquisition and Recast/Detour components. Use the corrected RTAB-Map/OctoMap result as the leading offline occupancy candidate and comparator, then determine which minimal occupancy integration is necessary on the phone. Do not port the whole research stack by default.

The evidence supports this direction, not a navigation pass. Corrected RTAB plus OctoMap had **4.19 cm median and 43.25 cm 95th-percentile forward surface error**, with **90.84% of sampled reference points within 5 cm**. The high error tail and retained hazards matter more than a favorable median. Raw fixed-pose RTAB covered more reference samples; neither result establishes current floor safety or collision-free movement.

## Reuse decisions

| Component | Use it for | What still belongs to our integration |
| --- | --- | --- |
| **ARKit and the existing native adapters** | Live camera tracking, calibrated observations and available scene-depth/classified-mesh input. Preserve Apple's tracking rather than inventing phone SLAM. | Owned buffer lifetime, bounded admission, frame/time/calibration identity, coordinate conversion, update/removal handling and explicit missing coverage. Camera pose is not body pose. |
| **RoomPlan** | Saved semantic layout, room landmarks, architectural connections and destination context. Existing source-floor polygon correction separates exported visual solids from historical support. | Verify exact native import parity; associate the saved room with the current session. Its processed floor/layout is historical, not evidence that today's floor or doorway is clear. |
| **Corrected RTAB-Map plus native OctoMap** | Reproducible offline candidate on the same recorded observations; occupancy evidence accumulation and observed-free/occupied/unknown comparison. | Validate retained low/head obstacles and support before routing. For iOS, compare an ARKit-to-occupancy adapter against existing ARKit reconstruction; do not assume full RTAB is necessary or already integrated. |
| **Existing BlindRoomMesh / Recast–Detour** | Candidate navigation meshes and routes on admitted geometry. The released code is already wrapped; no new planner is required. | Correct support/obstacle inputs, route-to-map registration, body/heading treatment, start-to-path connectors and independent continuous body checks. A game navmesh cannot certify floor safety. |
| **Open3D and OpenUSD** | Offline reconstruction comparator and independent same-file geometry reader, respectively. | Preserve their independent role: neither a nice rendering nor matching readers proves sensor accuracy. Open3D is not the chosen live navigation stack. |
| **Existing application lifecycle, guards and local memory** | Goal/session ownership, cancellation, privacy, hazard priority and saved-place context. | Connect real evidence producers. Passing ownership guards with absent sensing is not a functioning navigation system. |

**Licensing:** retain pinned versions and notices. Recast is under the included Zlib-style license; Open3D is MIT. RTAB core is BSD-3-Clause, but the actual research build includes **TORO under CC BY-NC-SA** and is not cleared for app redistribution. Audit the exact OctoMap components/dependencies chosen for an app build; do not bundle the research runtime wholesale. InfiniTAM remains an unexecuted, license-constrained candidate, not a prerequisite. The graph-corrected RTAB arm performed worse here; keep fixed poses as the present comparator. Do not adopt the globally worse 5 m Open3D variant because it fixed one local region.

## The specific code we still need

1. **One geometry contract.** Every observation carries metres, its named world/camera frame, original calibration, capture time, session and revision. Apply transforms exactly once. The MuSHRoom processed dataset is world-Z-up; the live ARKit contract is Y-up. Fixing the offline adapter must not globally delete the app's different conversion. Preserve raw geometry separately from routing support and render them registered together.
2. **Real live ingress, not another mock map.** Connect the existing `ARKitMeshAdapter82 → MeshCandidateIngress83 → BlindRoomMesh` chain. The current normal app does not copy and ingest the full mesh through this seam. Establish native callback/Metal-buffer ownership first; never enqueue borrowed buffers or stall urgent sensor processing. Retire outputs on removed anchors, gaps, tracking loss, background, stopped scanning or session replacement.
3. **Evidence layers with different meanings.** Keep historical structure/destinations, currently observed occupancy, currently observed support and unresolved coverage separate. OctoMap occupancy must use current probability/occupied state, not stale semantic labels. A native ground label is not support certification; missing triangles or unknown cells are not free space. Repeated contradictory observations require a tested fusion policy, not permanent vetoes or automatic clearing.
4. **Body localization and route admission.** Measure phone-to-body placement and heading, with editable body dimensions and an explicit uncertainty budget. Do not infer a narrow-clearance guarantee from age, gender or weight. Validate the entire footprint's support and the swept body/head volume, including turns, connectors and motion during delay. A centre-floor sample and `hazard == .observing` do not establish this.
5. **Closed-loop navigation.** Detect deviation from the selected route, replan from the actual current body pose, invalidate stale instructions, recover or stop after tracking loss/restart, and verify the route back using current observations. Saved room recognition alone does not locate the wearer. Conversation can ask a short useful question, but neither an LLM nor a user's recollection can clear unseen space.
6. **Inspectability and privacy.** Record planned and actual trajectories, input/revision timestamps, stops, contacts and uncertainty locally. Export reviewable evidence under explicit developer/test consent; personal camera frames and room memory remain on-device. Use bounded retention and deletion, not indefinite photo accumulation. Keep spoken movement under code-owned evidence; language models handle conversation, not geometry authority.

These are substantial integration and validation tasks. Calling them “glue” does not make them already solved or justify inventing untested clearance algorithms.

## Delivery order and concrete acceptance

### A. Finish the geometry correction and hazard audit in parallel

**Apple lane:** execute the exact `12a0b64` correction with all-feature native capture, independent reader comparison, then the unchanged 18 route and 16 supplied-pose cases. Check concave source-floor boundaries, slab rims, floor sides/undersides, furniture and openings separately. Display raw export, source support and route overlays in one metric frame.

**Occupancy lane:** on the corrected actual grids, score low, body-height and overhead obstacle retention, false blockages, missing support and unknown areas. Preserve disagreements and capture/reference confounds. Freeze policy and error budgets before an untouched holdout. Simplification must preserve measured openings, obstacle extents and support connectivity relative to the accepted original—not merely look smooth.

**Exit evidence:** reproducible geometry and hazard reports with the original failures retained. The native job is currently blocked by the private-repository workflow guard; approval to push does not approve changing that guard or paid runner use. No skipped case is a pass.

### B. Produce meaningful offline paths, not just arrival counts

Use the accepted geometry and existing released planner. Freeze starts, goals and body profiles. Test the wide passage, both sides of the table, an attempted table loop, doorway transition/return and connectors from chair/bed-adjacent standing positions where the data supports them. Compare raw geometry and route in registered top-down and 3D views.

**Exit evidence:** independently checked swept-body contacts and full-footprint support; actual moved distance, invalid starts, stops, unknown exposure and arrivals reported separately. Show the exact obstruction/evidence for each failure. Use reference geometry only for evaluation, never to carve a favorable route. A failed start is not an executed movement trial; zero collisions achieved by never moving is not useful navigation. The existing short synthetic collision-oracle checks are not this full-room proof.

### C. Connect one-room live capture in a nonwalking diagnostic

First demonstrate real native add/update/removal events changing the candidate room model and routes, with bounded owned buffers and explicit unknown coverage. This diagnostic must retain physical authority false. Measure capture-to-result latency, urgent-hazard delay and working set; verify interruptions and late callbacks on the actual app.

Then connect measured localization, body calibration and a **separate fresh clearance/support owner**, rather than enabling movement merely because geometry is now visible.

**Exit evidence:** instrumented current-session observations, correct body/map association, target-specific coverage and timely withdrawal/replan under moved furniture, occlusion, missing feet/head coverage, frame delay, tracking loss and restart. Recorded supplied poses are not a live localization result.

### D. Controlled end-to-end device evaluation

Measure sustained latency, thermal/memory behavior, instruction cancellation, VoiceOver, route deviation and map update behavior on supported hardware. Begin with bench and adult eyes-open comparison under the project's observation/stopping protocol. Do not use a child or a real unprotected stair/drop to discover integration failures. Passing offline tests does not authorize child mobility trials.

**Exit evidence:** the user receives an installable, specified build with a documented supported test flow, locally recorded actual versus planned paths, explicit failure behavior and remaining sensing limits—not a request to test an unconnected feature. The broader 400-journey acceptance remains open.

### E. Expand map hierarchy after the local slice works

Connect world/building hints → floor → room → objects/destinations using versioned local map identities and transforms. GPS can suggest a building; it cannot establish indoor floor, room, heading or body pose. Visual/geometry relocalization must resolve those, or ask the person rather than guess. Load only relevant map regions. Community maps supply historical topology, never current clearance. Existing useful nonphysical assistant features remain available throughout; this sequence prioritizes navigation engineering, not the person's access to other information.

## Working recommendation

Assign separate owners to native Apple parity, occupancy/hazard evaluation, and bounded live integration, with an independent reviewer for coordinate/body/support contracts. Integrate only against a common pinned input contract. At each stage publish source, protocol, passed/failed/not-run status, compact evidence and verified remote commit. Preserve failures rather than overwriting them with a later attractive result.

**Immediate target: a correctly registered furnished room and useful collision-checked routes, followed by a connected one-room phone diagnostic.** Better geometry results justify this next experiment; they do not yet establish reliable navigation.
