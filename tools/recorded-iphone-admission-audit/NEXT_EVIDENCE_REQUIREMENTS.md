# Before claiming obstacle misses, clearance or phone-plus-belt feasibility

This is a proposed evidence contract, not an executed study. The present eight-frame result is only production depth/confidence admission. An admitted pixel is not a detected obstacle, and a rejected/unsampled pixel is not known free space or an obstacle miss.

## Independent labels and geometry

1. **Visible obstacle evidence:** independently measured object/surface locations and extents, plus per-frame visibility/occlusion and sensor-range masks. Distinguish objects outside the field of view, occluded surfaces, low-confidence returns and actual detector misses. Do not label truth using the same reconstructed map or detector being evaluated. Dataset VLM task labels are not ground truth.
2. **Body-relevant clearance:** measured body dimensions and carried-equipment protrusion; calibrated phone-to-body, belt-to-body and per-sensor ray transforms with uncertainty and revision; independently observed body pose/trajectory. Camera path is not automatically body path, and camera forward is not torso heading on a gimbal. Include near-feet, shoulders/head, forward/side/backward motion and turning swept volume.
3. **Current support and negative evidence:** independently observed floor, drop edges, steps, holes and overhead geometry. Label unknown regions explicitly. Absence of returns, old map occupancy, unobserved volume and safe stalling do not establish traversability.
4. **Time and action:** retain original acquisition and receipt clocks with offset/drift uncertainty, processing completion and actual alert/haptic delivery. Define warning deadline from measured approach speed, body sweep and stopping/reaction envelope. Configured frame rate, receipt freshness and Linux function runtime are not end-to-end latency.

## Predeclare the evaluation, not the desired outcome

- Keep one development set and separately held-out rooms, layouts, materials, lighting and mounting conditions. Do not adjust depth thresholds, start placement, footprint, goal tolerance or episode budget after seeing a failure and relabel it the same test.
- Cover thin legs, low objects, protruding/overhanging furniture, transparent/reflective/dark surfaces, moving obstacles, close walls, doorways and occlusion. Define which hazards each sensor configuration can actually observe; do not infer coverage from sensor count alone.
- Separate phone-baseline, phone-plus-belt and any measured gimbal configuration. Reuse existing BeltLink, protocol, WearableEvidence and local belt hazard ownership; do not add a parallel LLM/map authority. Resolve raw zone timing, validity, clock/extrinsic calibration and gimbal-relative pose before fusion claims.
- Report object/event false negatives, late warnings, false warnings and unknown/blocked duration with denominators; report confidence/coverage loss separately. Thousands of pixels from one object are not thousands of independent hazard events.
- Only a later closed-loop test can report goal completion, time, path length, contacts, unknown-support attempts and deadlocks. The actual body must be independently integrated/measured; cue completion or projected path points must not snap it to success. Zero-collision stopping is not successful A→B travel.

## What the present recordings cannot establish

EM1-0387 is close tabletop manipulation, lacks original tracking state and body/belt calibration, and has no independent obstacle/collision labels. Its authentic confidence/timestamps and production scalar admission are useful input proof, not a navigation benchmark. Koivu contains real furnished-room RGB-D but omits native confidence/timestamps and has processed pose provenance. Neither omission establishes that the intended phone-plus-belt system is infeasible.

No further dataset acquisition, projection, detector execution or navigation run is included in this proposal. Protocol review must select the next bounded component and its independent ground truth before execution.
