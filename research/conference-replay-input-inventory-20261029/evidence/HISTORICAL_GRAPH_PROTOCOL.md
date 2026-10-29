# Source-only clearance-weighted loop planner, frozen before source execution

Same registered original Polycam geometry and pinned released Recast/Detour engine as44. Same45cm native-radius configuration (radius0.225m),1.75m nativeheight,2.5cm cells,15degree slope,2.5cm climb. Same five source anchors and required clockwise winding. The actual body remains45x30x160cm for later independent guarded movement; no body validation occurs here.

## Deterministic objective

Construct a5cm world-origin-aligned8-neighbor graph inside that same navmesh. Native Detour `findNearestPoly` supplies native height; reject horizontal projection beyond0.1mm for regular grid nodes. Every edge must pass native Detour raycast both directions and endpoint-height consistency. Native `findDistanceToWall` measures residual distance to the already-eroded navmesh boundary, capped2m. Do not subtract or add the body radius again. It is NOT a calibrated real-obstacle clearance.

Minimize sum of horizontal edge length times the trapezoidal endpoint penalty:
`penalty(c) = 1 + (0.30 / (c + 0.05))^2`.

This explicitly penalizes near-wall travel instead of funnel-shortest distance. It is a clearance-weighted route, not a mathematical guarantee of the exact medial axis or maximum minimum clearance. Equal-cost ties use stable node IDs. No FARO geometry, failure face, original statistical mask, or prior failure location is a planner input.

Original anchors associate under the unchanged10cm horizontal limit; retain exact caller XYZ separately and explicit projected endpoint connectors. Each projected endpoint connects to every raycast-valid grid node within0.15m. No endpoint selection/tuning. Native projected Y is retained. Only exactly collinear3D intermediate points may be compressed; no corner-cutting smoothing. A disconnected graph is a reported failure, not justification to relax parameters.

Freeze all source inputs/code/parameters before source execution. Report route lengths, sampled residual-clearance distributions and winding versus the original44funnel under the same query, with exact endpoint connectors and all failures. Do not tune from reference scoring. Later full-body evaluation must preserve original support/collision/underbody guards; native proposals alone are not verified movement.

Bounds: at most100000grid samples,1GiB address space,120CPU/180wall for source queries,5MiB individual output,768MiB disk reserve; no downloads or upstream copies. Compile against existing pinned upstream with120CPU/1GiB/5MiB file cap. Outputs remain below10MiB total. Preserve all earlier44/50/52/53results.
