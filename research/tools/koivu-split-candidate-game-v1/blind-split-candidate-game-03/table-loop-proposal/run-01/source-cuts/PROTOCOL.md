# Phone-only central-obstacle loop: three-lap proposal

Status: source-only proposal; no map connectivity computation, route query or lap episode has been executed for this proposal. The first short-route pilots and their frozen start/goal remain untouched.

## Question and target interpretation

Can the exact supplied Koivu split-support occupancy-threshold-0.7 map admit a body-feasible closed route around its central interior obstacle, and can the simulated actor complete that same loop three times without reference-scored contact or support failure?

The map contains geometry/flags, not a verified semantic table label. The code will identify a geometric central-obstacle proxy and show its outline on a phone-map-only diagram. It must not silently call an arbitrary free-space circuit “around the table.” If the proxy cannot be associated with the intended central table/chair structure from existing phone-derived visual evidence, report the semantic target unresolved before a lap episode. Neither an LLM label nor a FARO feature may choose coordinates.

## Unchanged inputs and engine

Use the same two pinned phone artifacts and CandidateMap adapter as the first pilot. Only the split phone masks/flags and metadata `lo`, `R`, `t`, `res` are permitted. No `ref_*`, `refWalk`, reference mesh, reference support, contact results or new reconstruction enters target/waypoint selection. Reuse the pinned actual Detour engine and the exact existing sampled rectangle check: 0.45 m lateral × 0.30 m forward body, 0.15 m margin on every side, native radius 0.375 m, 5 cm cells, 2.5 cm rectangle samples and 5-degree sampled turns. These checks are model feasibility, not physical clearance.

## Deterministic target and loop construction

1. Use installed SciPy connected-components on the Boolean supplied mask. Label blocked cells with 8-neighbour connectivity and walkable cells with 4-neighbour connectivity. Mark every blocked component touching the grid border as exterior. Do not fill any hole in the actual planner input.
2. Among enclosed blocked islands, choose the largest by cell count. Tie-break by squared centroid distance to the walkable-cell centroid, then lowest flat cell index. This is a fixed geometric proxy, not a semantic detector. If there is no enclosed island, retain `noEnclosedPhoneObstacleTarget`; do not create a table outline or use reference geometry to invent one.
3. Compute the target island's bounding rectangle. Define four target side-midpoints in the fixed order north, east, south, west, each offset outward by `0.375 + 0.05*sqrt(2)/2` metres. These are selection targets, not obstacles or added padding.
4. Candidate waypoint centres come only from the same upstream distance-transform clearance rule used by the first selector. For each side, restrict candidates to that side's outward half-plane; sort by squared distance to its fixed target, then source `(i,j)`. Choose the first candidate that fits the unchanged rectangle at some one of the original 72 headings. Require four distinct centres. No random seed search, alternative margin, unknown-mask opening or reference feedback is allowed.
5. Query actual Detour for the ordered cycle N→E→S→W→N. Require complete endpoint association within the original 0.1 m horizontal bound. Retain every native failure and projected endpoint; never snap the physics actor.
6. Validate all concatenated legs and their joins with the unchanged sampled rectangle routine. Explicitly check the first-to-last seam and return-to-start connection rather than assuming the source checker samples every exact segment endpoint. The actual world still owns continuous swept body collision.
7. Require the closed centreline to have winding number +1 or −1 around every cell centre of the chosen blocked island, consistently. This rejects backtracking, shortcuts and a route that merely visits different sides without encircling the target. It is a geometric validation of native routes, not a custom search/planner.
8. Freeze the target, all four waypoints, all native corners, route/flag diagnostics and source/input hashes before any reference-world call. No replacement after a contact, missing support or failed completion. Failure of this fixed construction is reported as “no loop found by this construction,” not proof that no conceivable orientation-aware route exists.

## Three laps, if and only if the closed route is admitted

Run one continuous simulation episode with three traversals of the same frozen cycle. Keep actor state between laps; do not reset health, pose, queue or map. Each lap requires actual trace progression through the four waypoint regions in order, a complete signed winding around the fixed target, and return within the unchanged 0.35 m start tolerance. Cue completion or route output is not lap completion.

Preregister a tick budget from the frozen route length and turn angles before reference scoring, using the existing 0.02 m nominal translation / 1-degree yaw limits and a disclosed fixed allowance. No budget extension after a stall. Use the reviewed independent ground/contact physics source cut selected for the short pilot; do not alter the phone mask, body dimensions or margins to make laps possible.

Report each lap's completion, distance, elapsed ticks/time, actual body contacts, margin contacts, ground contacts, unknown/support failures, minimum available clearance diagnostic and unresolved-flag exposure. Distinguish total flagged visits from unique flagged cells. Stop at the first preregistered failure; remaining laps are not completed. Zero collision counts without three completed laps are not success.

Three repetitions of a supplied-map route do not reveal new recorded sensor views, establish fog-of-war sensing or count as three independent rooms. The original capture lacks native confidence/tracking/body metadata. Do not count route queries as movement runs or label this the requested 100-run study.

## Proposed API and next bounded step

New isolated module `table_loop.py`, leaving current sources unchanged:

- `propose_loop(candidate_map) -> {status, targetComponent, targetOutline, waypoints, nativeLegs, closedPath, windingChecks, sampledFit, flagCounts, rejectedStages, sourcePins, physicalAuthority:false}`
- `write_phone_only_diagnostic(proposal)` plots only the supplied mask, unresolved flags, target outline and candidate route.

First perform bounded phone-only connectivity/route feasibility and tiny topological fixtures; no reference mesh or actor episode in that step. Suggested caps: 60 CPU / 90 wall seconds, 512 MiB RSS, 8 MiB outputs, 768 MiB free reserve. Then review the concrete target/route and freeze the separately declared three-lap world episode. If no full perimeter route exists in this construction, report that result rather than forcing a loop.

## Pre-execution numerical endpoint amendment

Before any loop fixture or recorded feasibility query, candidate-validation
geometry may coalesce consecutive horizontal vertices separated by **at most
1e-6 m**. This bound matches the numerical segment scale already ignored by the
upstream sampled sweep and is not selected from a game outcome. In particular,
when a native Float32 projected goal is within this bound of its unchanged exact
requested waypoint, retain the exact waypoint in the candidate path rather
than inventing a sub-micrometre connector with an arbitrary turn angle.

Every original native endpoint/corner remains in `nativeLegs`. Record each
coalescing residual, original candidate point, retained point and reason.
Vertices separated by more than 1e-6 m are not coalesced; substantive native
corners and longer associated endpoint connectors remain. Recompute sampled
closed-path checks, winding and route-length/turn budgets on the final candidate
path. This changes no physics actor pose, selected start/goal, map or margin;
it is not actor snapping or a trajectory correction.
