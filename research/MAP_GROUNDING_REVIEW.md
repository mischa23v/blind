# Map grounding, restart recovery and user-approved changes

2026-10-08 user correction: the earlier home evaluator supplied room identity, current pose, names and connectivity. It did not discover those from maps/images/sensors and does not satisfy the navigation objective. Passing context-delivery tests must not be presented as resolving this gap.

## Downloaded map evidence

Two published apartment examples were downloaded from [Autodesk Platform Services OAS](https://github.com/autodesk-platform-services/open-architecture-standards-2d-floor-plans) at revision `e54861c1099964607efd86b07e858f309e3fe45f`, with Apache-2.0 license retained in `research/map-fixtures/oas-e54861c`. They contain room polygons, units, dimensions and explicit doorway connections. These are authored examples, not scans of real homes and not the user's home.

`node tools/audit-downloaded-plans.mjs` verifies pinned hashes and audits the actual source coordinates. The first plan has four rooms and four doors; the second has four rooms and three doors. The second's bathroom is declared 2.25 m² but its polygon gives 1.5 m². Record the conflict for author/user review; do not silently alter the room. Neither example establishes live place identity, ownership, pose, heading or clearance. Both remain **NOT_MET** for live navigation acceptance.

[Inspect the dimensioned maps and connections](../artifacts/map-grounding/report.html), [machine-readable audit](../artifacts/map-grounding/source-audit.json). The audit performs limited area/reference checks, not complete topology validation. It does not activate a map in the app. In particular, the first map's bedroom and bathroom share a wall but their listed doors both connect to the living area: do not invent a bedroom-to-bathroom doorway.

The existing [3DLite initial apartment scan](../maps/REAL_SCAN_EVALUATION.md) provides reconstructed geometry but lacks verified semantic room boundaries/names, door connections and current localisation. It is a separate dataset; do not attach the OAS room labels to that mesh. ResPlan was inspected as a possible real-estate-derived metric dataset, but its 100 MB compressed pickle was not downloaded or executed. Do not label the authored examples as measured house scans.

## Required place model and recovery

Keep stable venue → building/unit → floor → room/zone IDs. Personal associations such as “my home”, “relative's home”, “my bedroom” are user-confirmed metadata attached to those IDs. A café's parent mall/street and multiple entrances, cashier and toilets need explicit source records. Missing information stays unknown; room adjacency is not a doorway.

After a battery failure, process restart, tracking gap or venue change, clear the live pose, room, map transform and pending route cues. Preserve memories as historical information. Use a documented saved-map matcher to establish a fresh session alignment; GPS/address proximity only narrows candidates. Same floor plan does not establish same house. An unsuccessful match means unresolved, not necessarily a new place.

Apple's [initialWorldMap documentation](https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration/initialworldmap) says a successful reconciliation returns normal tracking in the saved frame; a different place can remain relocalizing indefinitely. Current `NavigationModel` manually selects one saved place and waits for normal tracking/mapped frames. It does not implement automatic cross-venue search, an ambiguity conversation or a bounded recovery flow. No physical relocalization test has been run here.

Ask a useful short question when it resolves ambiguity: “Are you at your home or visiting someone?” Preserve the answer as a semantic confirmation, not a measured pose. Offer a stationary camera look-around when appropriate. Do not default to asking the user to walk into unknown space. Relative motion can extend a known continuous trajectory and suggest candidate regions; distance walked alone cannot name a previously unseen room, identify its owner or prove a doorway.

## Room editing contract accepted by the user

The user can type details directly or request an AI-written draft. AI output remains a proposal with source/uncertainty and an exact old/new comparison. The user can edit, approve or reject it. Only an explicit app-user approval commits the selected proposal to that room and base revision. A changed base revision requires review again. Model text, a model-generated approval field, silence or earlier approval of a different proposal cannot authorize a write.

Keep immutable room IDs and prior versions for undo. Never merge homes or replace geometry because descriptions resemble each other. Separate approval scopes: name/relationship, description, room type, measurements and connectivity. User confirmation of a name does not certify live position or route clearance. Conflicting sources remain visible until resolved; new sensor observations must not silently rewrite confirmed map facts.

Current status: the iOS room-type suggestion already has an explicit Confirm button, and manual feature labels have Save. General editable room-description drafts, durable revision history, stale-proposal rejection and undo are **not implemented**. The scene relay has no map-write endpoint/tool. A schema rejects extra map-edit/approval fields; that is not a complete approval workflow and does not guarantee hallucination-free speech.

Regression evidence: the new test initially failed because unknown location could retain the previous room/frame. After the guard fix, the serial Node suite passed **26/26**, logged at `artifacts/home-awareness/node-tests-place-uncertainty.tap`. This does not test actual phone restarts, map matching or revision approvals.

## New acceptance cases

| Case | Required behavior | Current evidence |
| --- | --- | --- |
| Restart in a different house | No inherited live room/pose; ask/relocalize before directions | Relay now rejects unknown location carrying old current IDs; physical recovery still missing |
| Similar neighboring homes | Separate identities even with nearby GPS or matching layouts | Not implemented/device tested |
| No match or two candidates | Preserve unresolved state; ask a focused question; no invented new-place conclusion | Required, not yet executable end to end |
| Unvisited region after walking | Track relative continuity; room category/identity stays unconfirmed until evidence/review | Required, not yet executable end to end |
| Conflicting room measurements | Show conflict and require review, retain originals | Downloaded source audit exposes one real source inconsistency |
| AI draft/edit | Preview old/new; explicit approval; reject/no action leaves map intact | Only existing room-type confirmation implemented |
| Stale or cross-room approval | Reject if base revision/room differs; no replayed approval | Required, not yet implemented |

## Established projects to evaluate for navigation reuse

| Project | Relevant capability | Boundary for this app |
| --- | --- | --- |
| [CaBot navigation](https://github.com/CMU-cabot/cabot-navigation), [main project](https://github.com/CMU-cabot/cabot) | Blind travel assistance with navigation, localisation and human interaction; related people tracking repository | Strong reference for the connected experience. ROS2 robot/PC/Jetson and sensor assumptions; not an iPhone library. Source inspection only here. |
| [Nav2](https://github.com/ros-navigation/navigation2) | Goal planning, obstacle costmaps, controllers and recovery; [Collision Monitor](https://github.com/ros-navigation/navigation2/tree/main/nav2_collision_monitor) is separate from planners | Useful established navigation foundation/reference; robot footprints, motion control and recovery actions need human-specific adaptation. Do not install ROS/Docker now. |
| [NavCog iOS](https://github.com/hulop/NavCogIOSv3) | Blind indoor navigation on iPhone with mapped routes and beacon/inertial localisation | Inspect spoken instructions, map/POI structure and recovery. Requires supported maps/localisation infrastructure; not generic camera-only obstacle avoidance. |
| [RTAB-Map](https://github.com/introlab/rtabmap) | Mapping and localisation, already pinned in this workspace | Continue existing adapter rather than invent SLAM; actual map matching and iOS build/device evidence still needed. |
| [Clew](https://github.com/occamLab/Clew) | iOS ARKit short indoor path recording and retracing | Useful return-guidance reference, not full building semantics or a general dynamic obstacle planner. |

Selection recommendation: inspect CaBot's blind-user flow and NavCog's phone guidance alongside the already selected RTAB-Map mapping path. Use Nav2 as the established robot navigation reference; do not transplant a wheeled robot controller into spoken human guidance. The missing work is connecting verified map/pose, human movement constraints, approval/memory and the information engine—not asking an LLM to invent a route. No new navigation stack was installed or certified here.
