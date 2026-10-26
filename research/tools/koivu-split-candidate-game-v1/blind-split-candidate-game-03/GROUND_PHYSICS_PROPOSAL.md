# Source-only ground-following proposal

Status: proposal, not implemented by the route-adapter owner. The frozen first route and episode remain unchanged. This is independent simulation-world contact semantics, not a phone floor classifier or a physical navigation permit.

The first episode's reported margin contact involved a triangle 1.761–2.015 mm above the initial foot anchor, clipping a constant 2 mm lower box boundary by approximately 15 micrometres. That alone does not establish a low obstacle or identify the contact semantically. The saved triangle, neighbouring faces and accepted support seeds should first establish whether the contact belongs to the same smooth reference-floor patch.

## Minimal candidate semantics

1. Retain the original detailed reference mesh and triangle identities. Seed ground only from initial support faces accepted by the independently declared world initialization. Do not seed a later face merely because its height is low or a ray calls it the nearest support.
2. Track local shared-edge connectivity from accepted ground. Use existing VTK locator queries to obtain a bounded local triangle set and VTK triangle normals; use original vertex IDs to form true shared edges. Installed SciPy connected-components can classify the resulting local adjacency graph. Point-touching or height proximity alone is not connectivity. Avoid a second full reference mesh or unbounded whole-mesh adjacency allocation.
3. Admit only triangles consistent with the existing 5-degree walkable-slope convention, connected through admissible edges to the seeded support. Step-up allowance is zero: a vertical riser cannot be traversed to relabel its horizontal top as ground. Keep holes, disconnected plates and unassociated faces unresolved. This is a separately declared world model, not a calibrated sensor threshold.
4. Physics foot Y follows the accepted connected support rather than remaining at its initial scalar height. Keep the actual horizontal movement and yaw requested by the controller; do not steer, relocate, select a new route or relay reference geometry to the planner. Preserve actual vertical movement and support associations in the trace.
5. Distinguish identified ground contact from obstacle contact. Only the connected admitted ground faces can be accounted as ground; retain those contacts explicitly. All other reference triangles keep existing body/margin collision semantics regardless of height. Do not increase a blanket foot-exclusion band, erase all near-floor geometry or remove obstacles based on low return confidence.
6. Preserve limits: finite support probes alone do not establish continuous support. A smooth ramp-like object may be geometrically indistinguishable from walkable ground without independent semantic labels. This proposal is not proof of small-toy, stair, drop or live-floor detection.

## Required independent fixtures before same-route retry

- Smooth connected inclined ground: ground contact does not reduce health; foot height follows it without horizontal correction.
- The same ground with a detached 1 cm box/toy: obstacle contact remains.
- Connected 1 cm vertical step, downward step, open hole and disconnected horizontal patch: no automatic step-over, floor relabel or support gap bridging.
- Wall sharing a ground edge, overhanging geometry and a near-foot object in the margin buffer: retain obstacle contact independently of ground connectivity.
- Pure rotation on inclined ground and a translated turn: account actual support/vertical change while preserving the existing continuous swept body enclosure.
- No valid initial ground component or a component lost during motion: retain an explicit incomplete/blocked outcome; safe stopping is not arrival.

Run exactly the frozen start, goal and selected path after a reviewed correction. Preserve the old failure and classify the new result under a new world-physics source cut. No route resampling or occupancy/body-margin tuning follows from this failure.
