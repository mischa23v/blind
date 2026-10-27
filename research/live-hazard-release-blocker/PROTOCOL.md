# Release blocker: live floor hazards and timely warnings

**Status: NOT PASSED. No movement-authority release or real-user trial is authorized by this protocol.** Successful static room laps and synthetic controller pilots do not satisfy it. A missed stair/drop can be more consequential when guidance has encouraged confidence; cane use must not excuse a detector miss or an unsupported instruction.

## Existing design, not a new hardware discovery

This tightens the existing repository requirements in `hardware/BUYING_PLAN.md`, `hardware/CONNECTIONS.md`, `hardware/PROTOCOL.md` and `research/ELEVATION_AND_LIGHTING.md`; it does not replace them. The intended belt already includes two downward TFmini-S sensors, eight VL53L5CX ring sensors, upward VL53L1X and forward MB1040, with independent local ground warnings. Existing documents already flag missing belt attitude/extrinsics/clock synchronization and the unvalidated 250 mm **slant-range** trigger. That trigger is not a validated vertical stair-height limit. More sensors do not close the gate until their real mounting, coverage, synchronization and warning timing are validated. The existing no-physical-guidance status remains in force.

## 1. Separate the two decisions

- **Map route proposal:** a possible route through previously reconstructed geometry. Old scans, a flat-floor model, RGB appearance, and an LLM description do not establish current clearance.
- **Live movement authority:** a short-lived permission for a specific swept body/foot volume and direction, based on current validated observations and their uncertainty. It must expire or be withdrawn when evidence is absent, stale, inconsistent, or out of coverage. A user may still move after withdrawal; stopping the software is not stopping a person.
- Maintain distinct **observed support**, **hazard**, and **unknown** states. Missing/corrupt/zero/invalid depth, a mesh hole, low confidence, occlusion, or no return must never become free floor. Unknown is not automatically a detected drop; announce the loss of confirmation rather than inventing a hazard identity.
- Neither a flat-floor prior nor repeated missing returns may clear an unknown region. Only valid, independently supported observations can restore authority. Preserve real low obstacles, edges and overhangs; do not flatten them to make routes connected.

## 2. Required evidence before even evaluating authority

Log raw synchronized depth/RGB, confidence/validity, calibrated intrinsics and coordinate transforms, original capture times, arrival/processing times, tracking state and resets, pose uncertainty/provenance, device/mount configuration, and instruction issue/onset times. Record camera-to-body transform and its changes: phone pointing direction is not walking direction. Identify exactly which sensors are active; do not assume simultaneous access to every camera.

For every proposed step, represent observed coverage and uncertainty over the actual prospective swept footprint, including feet, lateral/backward movement and head/body clearance. A forward-looking phone cannot authorize an unseen sideways step merely because the forward path is clear. Existing observations age while a person moves and while objects move. Registration or tracking loss invalidates affected coverage; recovery requires renewed valid evidence, not automatic reuse of old authority.

## 3. Frozen bench/replay matrix — no person near a hazard

Use independently measured ground truth, timestamped replay, and a controlled rig/mannequin. Predeclare scenes, mounting ranges, motion/speed ranges, hazard dimensions, lighting/material conditions, thresholds and holdout cases before scoring. Do not choose only visible or successfully reconstructed examples.

| Group | Required challenges | Release-blocking outcome |
|---|---|---|
| Invalid inputs | Missing frames/tiles, zero/NaN/out-of-range depth, stale/reordered packets, mismatched RGB/depth/pose, tracking reset | Any unsupported region becomes confirmed floor; stale permission survives its validity interval |
| Downward hazards | Stair first edge, landing, shallow/deep drop, threshold, ramp transition, edge partly occluded | Forward/lateral authority intersects an unconfirmed edge or unsupported region; warning is absent/late |
| Small obstacles | Toys, shoes, cables and chair feet against carpet/wood/tile, with real floor ripple retained | A hazard above the declared detection limit is wrongly cleared; below-limit regions are represented as assured clear |
| Coverage/mounting | Chest/hand/belt placements, height/tilt/yaw changes, pocket/occlusion, phone bounce, turn then side-step, near-feet blind spot | Unseen foot/body swept space is authorized; mount change silently preserves prior coverage |
| Temporal changes | Object enters previously clear space, delayed sensing/compute/audio, queued prior instruction, thermal/load variation | Warning arrives after the last defensible stopping point, or queued guidance continues after authority withdrawal |
| Recovery | Tracking loss, map/session change, restart, reacquisition with disagreement | Old coordinates/permission are reused without revalidation; apparent recovery grants unsupported clearance |

A blocked/unknown result is not a navigation success. Separately score availability and false stops, so an always-stop system cannot pass as useful. Correct rejection remains preferable to falsely asserting clearance, but neither proves the product meets its purpose.

## 4. Warning lead-time acceptance

Record hazard encounter boundary from independent truth; first valid observation; detector decision; authority withdrawal; actual audible/haptic onset; and any continuing queued instruction. Report capture-to-warning latency, missed warnings, first-warning distance/time, and minimum lead time—not just averages.

For a declared speed/motion envelope, the required verified look-ahead distance must cover **motion during worst-case validated sensing/processing/output delay + response delay + stopping distance + spatial/pose uncertainty**. During lateral or turning motion use the swept extremities, not centre speed alone. Each term needs measured evidence and a predeclared conservative bound. No universal safe number is established here; unknown human response/stopping bounds keep this gate open. Device warning onset is not proof that a person heard, understood, or stopped.

An oracle collision veto in simulation counts as a detector/controller failure if live perception did not warn in time. Report attempted and prevented collisions separately from executed contacts. Never present zero executed contacts, achieved by a reference-world veto, as proof of live obstacle avoidance.

## 5. Required acceptance record

For every frozen case retain inputs/hashes, complete coverage/validity history, proposed versus authorized motion, warning timestamps, independent hazard labels, uncertainty, and terminal reason. Report denominator, false-clear events, missed/late warnings, minimum lead time, false stops, time without authority, recovery success and unsupported exposure. Include failed and unexposed scenarios; lack of exposure is not a pass.

**Any false-clear or late/missing required warning in the declared test domain blocks release pending diagnosis and a separately frozen correction.** Zero observed failures alone is not a reliability estimate: report sample size, coverage and uncertainty. Unspecified operating envelope, unavailable required fields, or unvalidated warning/stopping bounds also block release. Independent review must distinguish software logic checks, recorded-sensor evidence and physical-device evidence. No certification claim follows from these gates.

## 6. What current MuSHRoom evidence cannot supply

The locally audited Koivu iPhone archive provides exported RGB/depth, per-frame intrinsics/poses and a reconstructed mesh. The complete inventory and exported metadata audit found **no native depth confidence, original capture timestamps, raw ARKit tracking-quality/IMU history, or body-to-phone calibration**. Frame number divided by assumed FPS is not measured time. Exported/optimized poses are not a demonstrated causal online pose stream. Processed image-sized depth is not an untouched native depth/confidence buffer.

It also does not provide this app's capture-to-output latency, actual warning onset, wearer response/stopping behavior, calibrated walking/body trajectory, dynamic hazard coverage, or labelled stair/drop warning encounters. The current selected static room evidence therefore cannot close this release blocker. Available images can help investigate artifacts, but cannot certify absent hazards or current foot coverage.

These absence claims are scoped to the **audited Koivu archive/current selected pipeline**, not every file or recording ever released under MuSHRoom. Check each additional dataset independently rather than filling missing fields with synthetic values. Synthetic values may test software plumbing only when labelled as such.

## Immediate next step

Inventory a suitable timestamped raw capture source against the required fields, then freeze a small bench/replay missing-depth and stair-edge matrix. Do not add room laps or real-user trials as a substitute. Keep this blocker first in the tracker; preserve stages 69/73/74/76 as separate static/synthetic evidence, including failures.

### Local evidence references

- `blind-mushroom-koivu-acquisition-01/RECORDED_INPUT_FINDINGS.md`
- `blind-mushroom-koivu-acquisition-01/ARCHIVE_INVENTORY.json`
- `blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json`
- `blind-synthetic-first-leg-pilot-73/README.md`
- `blind-retained-pose-jitter-pilot-74/README.md`
- `blind-batched-observation-progress-76/README.md`

This is a proposed release-blocking engineering acceptance protocol, not a completed experiment or a claim that phone-only navigation is either proven safe or impossible.
