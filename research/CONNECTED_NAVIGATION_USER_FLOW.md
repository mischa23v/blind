# Connected navigation user flow — requirements, not completion

Recorded 2026-10-28 from the user's connected-world-map and optional body-profile requests. **This document records required behavior and acceptance gaps; it does not claim implementation or authorize HealthKit access.** Navigation is the first priority. The user needs a connected build before a navigation-walking handoff, not disconnected room previews or language-model-generated paths.

## Required end-to-end flow

1. **World context → candidate building.** A world map (the user named Google Maps) and available location provide candidate buildings/public venues. Coarse location does not establish indoor room, floor, body pose, or a traversable entrance. Provider selection, licensing and offline availability are separate implementation decisions; this requirement does not claim a Google integration exists.
2. **Candidate building → selected map package.** Load the appropriate versioned building map, floors, rooms, portals and associated recognition references. Handle no map, multiple candidates, outdated maps and offline retrieval explicitly. Public map distribution must preserve existing permission/privacy rules; no private pictures or health/body data enter a shared package.
3. **Live visual evidence → room/floor association.** Compare live camera evidence to the selected map's references, using the code-owned recognition pipeline and uncertainty/ambiguity rules. A room name is not a position. A floor claim requires a verified map association or other suitable evidence; visually similar rooms on different floors must not silently resolve to one floor. User knowledge may narrow candidates, not fabricate measured pose.
4. **Association → measured position and orientation.** Establish position and facing in the active map coordinate frame, including source, capture time, map revision, uncertainty and recovery status. Distinguish phone orientation from body heading. On lost tracking, restart, map transition or conflicting evidence, revoke affected guidance until re-established; do not retain an apparently valid route merely because it was previously displayed.
5. **Localized scene → relevant nearby geometry.** Load the relevant floor/room and neighboring portals rather than the entire world at high detail. Represent observed floor support, walls, furniture, objects and unknown space with explicit provenance. Update with current sensor/camera observations. Old maps may supply destinations and route candidates, never current clearance. New toys, moved chairs, stairs/drops, overhangs and occlusions must not disappear because the saved map was simpler.
6. **Body and mount profile → collision envelope.** Support an editable starting profile with explicitly labelled estimates/defaults, then user/helper corrections and measured values where available, together with a documented uncertainty/motion margin. Do not represent dimensions inferred from age, sex, gender, weight or appearance as measured facts. Exact centimetre measurements must not block building the system or running declared-profile replay tests. Calibrate the phone-to-body transform for the user's chest mount and detect invalidation/slip. A stored height is not a calibrated phone height or chest-mount transform. The collision envelope must cover the relevant body volume and motion, not just a point at the phone.
7. **Verified current position → checked route connector.** Connect the actual current pose to a route only through presently admissible observed space, checking the swept body envelope and turns. Do not snap through walls/furniture to the nearest path. A center-seeking route preference is useful only within valid space; route shortening must not override clearance and uncertainty constraints.
8. **Route → goal and ongoing task.** Track deviation and progress continuously, replan when justified, and invalidate guidance when evidence becomes inadequate. Preserve the user's objective across rooms and allow goal changes, pauses and return journeys. The conversational companion explains, asks for useful observations and adapts information volume; it never invents route authority. Changed goals or sessions must cancel stale work and cues.

## Optional body profile: HealthKit is a source, not a measurement oracle

The user proposed consented Apple Health values, including body measurements when available. Apple's [HealthKit data-type documentation](https://developer.apple.com/documentation/healthkit/data-types) is the primary source for the available categories. Relevant candidates are height, body mass and waist circumference; biological sex and date of birth should be requested **only if a specific necessary feature justifies them**. Apple's [biologicalSex documentation](https://developer.apple.com/documentation/healthkit/hkhealthstore/biologicalsex()) describes a biological-sex characteristic, not a gender field. Do not relabel it as gender or treat it as measured geometry.

Required policy before any implementation:

- **Optional, explicit, granular read-only consent.** No automatic collection or permission prompt is introduced by this requirement. Navigation must provide a manual measured-profile route when access is absent, denied, incomplete or unwanted. Do not write health records.
- Keep any accepted values on-device under the existing privacy policy. No cloud upload, GitHub backup, shared-map export, analytics payload or model-training use. Explain purpose and allow correction/removal.
- Preserve value, unit, date and source/provenance for measurements, normalizing units explicitly. Characteristics and sample measurements have different provenance/date availability; do not invent a measurement date for a characteristic.
- Ask the user to review stale, missing or implausible measurements; do not silently substitute population averages. Record manual entries as manual, with units and date, not as sensor measurements.
- Height, mass and waist circumference do not establish shoulder width, body depth, arm reach, gait/sway, or safe clearances. Age and sex/gender cannot supply these dimensions reliably. For shoulder width, hip width, body depth and other required fields, permit a declared starting configuration, display its values and estimated/default source, and let the user or helper edit them now or later. Preserve measured versus estimated labels per field; do not silently upgrade estimates to measurements. Calibration and any physical-guidance acceptance must account for the remaining uncertainty, but this does not prevent implementation or replay with declared profiles.
- No assumption that children have complete HealthKit records. Applicable guardian consent and the project's supervised acceptance requirements remain separate from data availability.
- A known strap model or declared chest placement is only a prior. The measured camera-to-body translation/rotation, user posture and mount stability must be calibrated, versioned and revalidated independently.

**No HealthKit permission was requested, no health data was read, and no HealthKit integration was implemented in preparing this document.** Available data types do not establish that this user's device contains any of them.

## Latest user clarification: editable starting numbers

The user explicitly requested showing starting shoulder/hip/body dimensions and allowing edits later. The setup flow is **prefill declared estimates/defaults → show values, units and source → user/helper edits → preserve per-field estimated/manual/measured status → revise when better information exists**. No population formula or numerical default is selected or claimed accurate here. Defaults are configuration for development and explicit-profile testing, not medical measurements or a claim of physical safety.

Exact body measurements are not a prerequisite for building the connected system or testing its geometry with declared profiles. Profile uncertainty must not be used to explain away a mapper rejecting a demonstrably wide passage: independently diagnose scale, coordinate transforms, floor/obstacle classification, duplicated margins, body sizing and path connectivity. Report map/pathing defects separately from profile uncertainty. User-editable dimensions do not silently waive margins or evidence requirements for physical guidance.

## Acceptance dependencies and current status

The current N00 preview work is **not** the complete localized 3D navigation flow above. A room mesh/route preview, a successful source-level fixture, a historical camera trajectory or a simulated arrival does not establish connected live guidance. Keep the following independently visible in the tracker:

- world/building candidate selection and correct map loading;
- room/floor identification with rejection of look-alikes;
- measured map-relative pose and body heading;
- body envelope and chest-mount calibration;
- current support/obstacle evidence and incremental scene updates;
- validated current-pose-to-route connector, including doorway/floor transitions;
- deviation detection, restart/lost-tracking recovery and return journeys;
- goal/task continuity, cancellation and speech ownership;
- assembled native build and reproducible recorded-input replay before the user's navigation-walking handoff.

For each accepted transition, retain an inspectable record of input ownership, map/session revision, evidence age/uncertainty, selected action and rejection reason. Test wrong-building/wrong-floor, repeated-looking rooms, stale maps, unavailable body data, moved furniture, mounting slip and lost tracking—not only the happy path. Compare planned and executed swept geometry against independent reference evidence where available, without leaking evaluator geometry into the mapper.

The connected handoff must state what is implemented, what was replay-tested, what passed Apple build/tests and what still needs supervised device validation. Device validation remains necessary, but an unfinished model-generated route is not an adequate navigation build to hand the user. Preserve staged adult/supervised trials and existing child/O&M gates; this requirements record does not certify walking safety.
