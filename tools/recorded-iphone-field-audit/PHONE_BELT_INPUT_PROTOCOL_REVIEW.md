# Phone + belt / additional sensors: input and evaluation prerequisites

Read-only source/design review, 2026-10-26. No firmware or app implementation changed; no tests, builds, installations, purchases or dataset downloads performed by this reviewer. Source root: `../blind-navigation-combined/full-source/`.

## Product baseline and reusable implementation

The existing `hardware/BUYING_PLAN.md` already says the belt is core to the intended mobility system and phone-first evaluation is only a development stage. The current phone is not a final sensor-coverage constraint. Additional sensors may address measured gaps; a sensor's presence or count alone does not prove coverage. This review does not select or recommend purchasing new hardware.

Reuse these existing modules rather than introducing parallel sensor authorities:

- `ios/BlindAssist/BeltLink.swift`: CoreBluetooth central, separately selected belt/wrist roles, summary and raw-measurement subscriptions, reconnection and per-connection freshness/assembly ownership.
- `BlindCore/Sources/BlindCore/BLEProtocol.swift`: 20-byte version-1 hazard summary; role, flags, sequence and eight body-sector ranges; calibrated/fault distinctions; urgent hazard precedence; 0.8 s receipt liveness.
- `BlindCore/Sources/BlindCore/SensorMeasurements.swift`: version-2, 20-byte fragments; sensor ID, MCU uptime, sequence, 1/16 zones; complete assembly only, duplicate/replay/wrap handling, 250 ms assembly expiry and 0.3 s receipt freshness.
- `BlindCore/Sources/BlindCore/WearableEvidence.swift`: fresh calibrated fault-free **body-relative** range reports, no object identity or world coordinates; unknown/zero omitted; pending spoken range revalidation. Its confidence value means an accepted report, not measured physical accuracy.
- `firmware/belt/src/main.cpp` and shared mobility protocol: local urgent decisions and haptics before BLE bulk data, explicit level-ground calibration, valid sensor returns versus unavailable data. Phone navigation commands do not overrule active local urgent warnings.
- `ios/BlindAssist/NavigationModel.swift`: wearable callback immediately calls `publish()` while running; highest-priority wearable/phone hazard path remains outside the LLM and ordinary narration.

Raw belt arrays are currently retained for diagnostics, not inserted as accurately positioned map points. Do not turn that deliberate boundary into an assertion that the belt is absent or irrelevant.

## What the current reference rig describes, not establishes

`hardware/CONNECTIONS.md` describes eight VL53L5CX ring modules, two downward TFmini-S channels, one upward VL53L1X, one front MB1040, and independent belt haptics; wrist VL53L1X is pointing-range only. These are the existing firmware targets, not newly verified specifications or purchase recommendations. The ring is configured for 4 x 4 zones at 5 Hz and hazard summary nominally 20 Hz. Configured rate is not measured acquisition-to-warning latency.

The protocol preserves 65535 as unknown, not free space. Summary sectors are coarse body-relative directions; drop/overhead summaries deliberately contain no invented horizontal distance. Native zone order has no calibrated body-ray projection yet. Two downward rays do not establish a whole foot corridor, and an eight-direction array does not establish gap-free vertical or horizontal coverage.

`research/ELEVATION_AND_LIGHTING.md` already identifies missing belt-attitude integration, varying belt height/pitch, unknown turn/side/backward coverage, correlated surface/lighting failures and unmeasured warning distance. The existing 250 mm **slant-range change** is not a stair-height specification. No need to rediscover or disguise these limitations by changing constants.

## Protocol to freeze before perception evaluation

| Input boundary | Required evidence / behavior |
| --- | --- |
| Ownership | Explicit device, role, boot/session, sensor, sample sequence and firmware/protocol version. Reconnect/reboot retires old samples and calibrations. Preserve original source fields and distinguish recorded versus simulated streams. |
| Time | Acquisition timestamp and clock domain, phone receipt timestamp, clock mapping and bounded offset/drift/transport uncertainty. A source MCU uptime is not synchronized ARKit time. Do not call 0.8 s liveness or 0.3 s receipt freshness a latency guarantee. |
| Measurement validity | Range units, per-zone status/confidence, invalid/no-target/saturation distinction, sensor availability and exposure/integration interval where available. Preserve unknown zones; absence cannot clear old hazards or certify free space. A summary nearest range is not a substitute for raw zone geometry. |
| Geometry | Measured per-sensor rigid transform and zone-ray/field-of-view model, units/axes, calibration revision and uncertainty. Preserve belt-to-body and phone-to-body transforms separately; include body dimensions, mount offsets and carried-equipment protrusion. |
| Motion / gimbal | Independent body orientation; belt attitude; time-aligned dynamic camera-to-body transform when a gimbal moves; gimbal state/encoder or other measured relative pose, with age and uncertainty. Unsupported motion invalidates spatial guidance, not the entire nonspatial assistant. |
| Coverage | Measured observed/unknown volumes across body width and height, head/shoulders/feet/equipment and turning swept volume. State each sensor's valid range and material/lighting/occlusion conditions from measurements, not a headline specification. |
| Safety priority | Valid new hazard bypasses map/LLM delays; failures do not clear hazards. Local belt warning remains functional without phone/radio. New hazard or invalid calibration retires cached movement candidates before rebuild. No generated labels, remembered maps or interpolated floor become clearance. |
| Release / recovery | Versioned calibration validity, reason-specific unavailable states, mount-slip invalidation and deliberate recalibration. Record haptic/alert delivery separately from BLE acknowledgment; a successful write is not proof of motor output. |

The current `hardware/PROTOCOL.md` explicitly lacks sensor extrinsics, IMU orientation, capability tables, battery information and clock synchronization. A versioned extension is needed before claiming those fields or world-map fusion; keep compatibility and fail-closed handling for existing version-1/2 devices. BLE encrypted unauthenticated bonding is not authenticated physical owner provisioning.

## Gimbal-specific boundary

No gimbal integration appeared in the inspected app/hardware source. `BodyHeadingEstimator` currently learns a fixed camera-yaw-to-walking-direction offset and uses a declared fixed mount while stationary. `ChestMountMetadata` stores body-relative position only, not a dynamic orientation transform. `BodyCollisionWarning` is gated by fixed mount and profile metadata.

A gimbal can turn independently of the torso. Therefore it must not be labeled `fixedBodyMount = true` merely to bypass existing gates, and camera forward must not become body forward. Keep the useful ARKit camera pose, but supply measured time-varying camera-to-body/belt transforms and independent body heading before granting equivalent spatial authority. Intentional gimbal motion must also be distinguished from a physical mount slip. This is an integration prerequisite, not a claim that gimbals cannot be used.

## Source-level issues to resolve before using raw belt arrays for fusion

1. In `firmware/belt/src/main.cpp`, ring arrays are transmitted with `ringRange[i].timestamp` (around line 202), while that timestamp changes only after a valid nearest return. A new all-unknown array can inherit an older valid-range timestamp; the assembler may reject it as a replay instead of accepting the new unknown observation. Preserve a separate acquisition/readout timestamp per sensor frame, including invalid frames. This is source reasoning, not a reproduced hardware failure.
2. `SensorMeasurement.validZones` excludes only 65535, so zero counts as valid. Firmware currently retains only positive valid ring readings and `WearableEvidence` excludes zero. The raw-consumer validity contract must reconcile zero and status handling before map fusion. No existing world-map corruption is claimed because these arrays are presently diagnostic-only.

## Evaluation order and acceptance evidence

1. **Raw phone format inspection now:** hash and decode the authorized Record3D subset; audit original fields, alignment and missing data. No perception or navigation pass is implied. Do not synthesize tracking normal, confidence, body calibration or missing timestamps to make the replay run.
2. **Freeze evaluation protocol:** distinguish original phone replay, synthetic phone-plus-belt fixtures and eventual synchronized real rig captures. Define independent geometry/obstacle labels, occlusion/coverage masks, field validity, sensor delay and failure scenarios before evaluating. Do not use VLM labels as ground truth.
3. **Bench/replay integration:** actual existing parsers and policy paths, delayed/reordered/duplicate/partial packets, stale clocks, wrap/reboot/reconnect, mount movement, sensor covering, failed motors and radio loss. Measure warning latency and valid/invalid transitions; documentation or parser test counts are not physical validation.
4. **Closed-loop simulation separately:** same code-driven planner/controller, independently integrated body and swept-volume collision oracle. Test authored and held-out multi-room layouts, progressive observation, jitter/lag/wrong turns and dynamic obstacles. Success requires actual goal completion with zero collision/health loss; stopping, timeout and deadlock are failures, reported with completion time and distance.
5. **Real synchronized rig later:** measured extrinsics/clock uncertainty, material/lighting/speed/attitude cases, known safe fixtures and adult supervision before any child trial. Report missed/late/false warnings, observability and completion separately; don't claim independent use from a decode, build, upstream library or simulation.

## Repository references reviewed

- `hardware/BUYING_PLAN.md`, `hardware/CONNECTIONS.md`, `hardware/PROTOCOL.md`.
- `research/ELEVATION_AND_LIGHTING.md`, `CONTINUOUS_COMPANION_DESIGN.md`, `CONTEXTUAL_CAPABILITIES_ACCEPTANCE.md`.
- `ios/BlindAssist/BeltLink.swift`, relevant `NavigationModel.swift` hazard callback/frame paths.
- `BlindCore/Sources/BlindCore/{BLEProtocol,SensorMeasurements,WearableEvidence,BodyHeading,BodyProfile,BodyCollisionWarning}.swift`.
- `firmware/belt/src/main.cpp` and `BlindCore/Tests/BlindCoreTests/WearableEvidenceTests.swift` source. Tests were read, not run.
