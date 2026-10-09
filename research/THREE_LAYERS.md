# Three layers of mobility

The user wants a private, reusable map of a café, supermarket, school or mall; a moving person represented inside that map; and sensors checking the space around that person. The LLM interprets requests and explains results, while geometric code owns localization, collision checks and route planning.

| Layer | Inputs and state | Output | Current implementation |
| --- | --- | --- | --- |
| 1. Immediate surroundings | Phone camera/depth/motion; belt and wrist range measurements; floor calibration; freshness | Urgent hazard alerts, observations for descriptions, local motion estimate | Phone AR depth, Vision OCR/people/categories, BLE summary/raw fragments, local firmware alerts. Wearable readings are not yet transformed into a shared world map. |
| 2. Venue | Saved 3D geometry, per-floor collision surfaces, named landmarks, traversable connections, current pose with uncertainty | Destination lookup, route, next landmark; updated obstacle state | RoomPlan/ARWorldMap storage; RTAB-Map native adapter; imported indoor graph; optional collision surfaces; manually aligned route cues; blocked-leg rerouting; current-session retracing. Automatic saved-map localization and mesh-to-navigation conversion are unfinished. |
| 3. Outdoor location | GPS/accuracy, outdoor destination, venue catalog | Candidate venue and indoor map identifier | MapKit search/directions and Google Maps handoff. Tested VenueCatalog candidate filtering exists but is not wired to map loading. |

GPS should suggest a venue, not establish an indoor position. Adjacent shops and floors need disambiguation. Loading a file does not prove the user is localized in it. Camera landmarks, depth geometry and motion must jointly establish the correct map transform, with a measurable confidence gate; loss of that confidence must stop route cues. Current manual landmark alignment makes this limitation explicit.

## Example café request

“Take me to the restroom” resolves to an existing destination ID. The planner starts from a confirmed position and finds verified connected passages. The speaker gives the next useful landmark/direction. Live hazards preempt the route cue. If a chair blocks a passage, guidance pauses and a route can be recalculated after the blockage is represented in map coordinates. A camera reading “Restrooms” is supporting evidence; it is not by itself proof of the user's exact pose.

The Ask screen can now suggest an existing map destination. It matches unique names offline first; an available on-device Foundation Models model may propose an ID from a bounded map context. Unknown or ambiguous IDs are rejected. The user selects the suggestion in Routes and confirms the starting landmark. There is no autonomous movement and no model-generated coordinate accepted by the planner.

## Body clearance and game navigation

`NavigationSurface` is a per-floor 2.5D grid: X/Z locate a cell, `floor` is the supported Y elevation, `clearance` is known free height above it, and `blocked` records an occupied cell. Unknown measurements are impassable. The body's default cylinder is radius 0.30 m and height 1.80 m, with 0.15 m margin. These are prototype configuration values, not measurements of a particular person. The core API accepts an explicit envelope; a device fitting/configuration UI remains to be added.

For maps with surfaces, `IndoorMap.route` sweeps that envelope along every candidate straight graph edge before path search. It rejects walls, unknown cells, insufficient headroom, rises/drops over 0.09 m, map boundaries, missing floors and floor transitions. Those thresholds deliberately restrict this implementation to level passages. It does not infer stair or lift traversal. Corner waypoints must be authored so that no graph edge cuts through a shelf or wall. Older maps without surfaces retain graph-only behavior and are labelled that way in the interface.

This is a conservative static-map collision check, not fresh proof of walking clearance. Live sensing still has priority. Dynamic obstacle fusion needs calibrated sensor poses, timestamps and confidence, and is unfinished. The currently isolated `LocalPlanner` experiments are not used to steer people around hazards.

[Recast/Detour](https://recastnav.com/) is a suitable integration candidate for generating and querying navigation meshes from 3D geometry. Its own tests ran separately (32 passed, one upstream skip, 5,000 assertions). It is not linked to the iPhone app. The next integration step is a reproducible adapter from RTAB-Map mesh geometry into per-floor navigation data, followed by localization and live obstacle updates—not asking an LLM to interpret every mesh triangle.

## Information the language model receives

`MapContext` supplies venue name, up to 80 destination IDs/names/levels, route IDs, position status and optional manually aligned position. A truncation flag prevents a partial catalog being represented as complete. Geometry remains with the planner. The photo service receives separate selected fresh scene evidence and one deliberately submitted photo; it does not receive the user's private map or journey archive.

Eventually a route-explanation tool should return a validated next-step record: destination ID, route revision, landmark, direction, distance estimate, pose confidence and current interruption state. That live route tool and automatic venue loading are not implemented yet. Persisted maps must retain coordinate frames, units, provenance, timestamps, level connections and semantic labels across updates.
