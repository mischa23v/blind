# Mapping a school for the first supervised trial

Start with one level and a short classroom–corridor–restroom route. An adult mapper and the school's orientation-and-mobility teacher prepare and verify the route before children try it with their canes. A school floor plan helps, but it may omit furniture, locked doors, thresholds or changed layouts.

## 1. Survey the route

Choose a stable origin such as the classroom doorway. Define X as right and Z as forward on your drawing, in metres. Keep the same axes throughout this map. Y is the floor elevation, not camera height. Give every turn a waypoint so straight connections do not cut through walls. Do not use GPS coordinates as indoor metre coordinates.

For every landmark, record:

| ID | Arabic name | English name | Floor | X/Z metres from origin | How someone confirms it |
| --- | --- | --- | --- | --- | --- |
| classroom | الفصل | Classroom | 0 | Measure | Door frame and room identifier |
| corner | زاوية الممر | Corridor corner | 0 | Measure | Stable corner/tactile landmark |
| restroom | دورة المياه | Restroom | 0 | Measure | Confirmed door and sign |

For every connection, record measured length, minimum passage width, headroom, floor condition, thresholds, doors and whether it is actually available. Mark inaccessible/unknown connections unavailable. Avoid stairs, ramps, lifts and road crossings in this first route; the current collision layer supports level passages, and there is no validated automatic floor-transition system.

## 2. Capture geometry separately

On a supported LiDAR iPhone, use Places to scan and name each room. Move slowly with the camera seeing walls, doors and furniture. Scans and ARWorldMaps remain on that phone. The native RTAB-Map build can grow a 3D database across an area, but it still needs a Mac build and device testing.

Saved rooms now offer a 2D overview, editable bilingual labels, and SVG/JSON/USDZ exports. Spoken RoomPlan scan instructions are wired; they and the new screens still require an iPhone test. See HOME_MAPPING.md for the family workflow. These room diagrams do not automatically populate the Routes graph.

The app currently does **not** automatically turn those scans into a labelled, reusable school navigation mesh, nor reliably locate a child anywhere within a saved large school map. The room scan and the authored route are separate data today. Do not treat “map saved” as “navigation ready.”

## 3. Prepare the route file

Copy `school.example.json`, replace every coordinate and distance with the measured school values, and change names/IDs as needed. It is a fictional format example, not a real school map. `nameArabic` supplies the spoken Arabic landmark name; `name` supplies English. Each edge is a straight, undirected connection. Add extra nodes for every bend; do not draw an edge through a room merely because its endpoints are nearby.

The example is an authored graph without a collision surface. The app labels this limitation. A `surfaces` array can add surveyed per-cell floor/head clearance, as demonstrated by the generated `artifacts/simulation/cafe.synthetic.json`; unknown cells reject passage. There is not yet a visual authoring tool or scan-to-surface converter. The default body envelope must be reviewed for the actual child and equipment; its configuration UI is unfinished.

## 4. Import and rehearse as an adult

Add [keep-out areas](KEEP_OUT_AREAS.md) for surveyed restricted locations. The planner rejects crossings with body clearance and will refuse the route if all authored alternatives are blocked. These restrictions persist in the exported JSON. They do not supply physical tape detection or continuous proximity alarms.

Transfer the JSON using Files or AirDrop. In the app, select Routes > Import indoor route JSON. Choose the **known** starting landmark and destination. Plan the route, then stand at that landmark facing the next known waypoint and use Align. Start monitoring and calibrate on known level ground first. Reconfirm and align at each landmark. Route bearings depend on this manual alignment; the app cannot silently recover a wrong starting location.

An adult first checks the entire path, spoken Arabic, cue timing, phone mounting and sensor coverage. Test a blocked passage and tracking loss without approaching a real hazard. An imported graph cannot determine whether a door is currently locked. A blocked-leg alternative starts from the last confirmed landmark; confirm actual position there before resuming.

## 5. Supervised child session

Use a familiar, controlled area with the mobility teacher alongside. Begin with stationary questions, controls and harmless simulated alerts, then a short verified route with the cane. Record confusing wording, missed/repeated alerts, inaccurate position estimates and unwanted interruptions. Stop if tracking or sensor coverage is uncertain. The prototype is not ready for unattended school travel or emergency evacuation guidance.

## 6. Share and maintain

Export the route JSON from Routes and import it on each phone. Keep maps private to the school; do not include children's names, schedules or personal location histories. Room scans, saved-map localization and 3D database transfer are not yet a complete multi-phone deployment workflow. Date and recheck the survey whenever furniture, doors or room use changes. A future map version must invalidate old alignments and routes on each phone.
