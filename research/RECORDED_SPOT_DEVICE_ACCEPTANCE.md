# Recorded-spot orientation: supervised native-device acceptance

Prepared 2026-10-23. **Procedure only. No device acceptance, calibration receipt or production approval has been issued.** The default gate remains off. Linux tests, source checks, an ARKit tracking state and a successful spoken phrase do not establish physical accuracy or safe independent use.

## 1. The capability being tested

The only candidate permission is a body-relative description of an independently checked **historical recorded point** in one exact saved RoomPlan/world-map revision. The output must identify it as the recorded spot, state that the object has not been confirmed there now, and not imply a clear path. It is not an instruction to turn, walk, reach, pick up or handle anything. It does not establish personal-item identity, current presence, accessibility or a route.

Keep `objectInteractionGuidanceValidated` false. A recorded-spot test receipt must not change that gate. Detector-box-centre depth, appearance candidates, user-reported locations and unrelated imported route-map coordinates do not acquire authority from this procedure. The current receipt applies only to explicitly listed imported RoomPlan furniture points. A wardrobe/chair category is not evidence that a particular coat is on it.

The native foundation is Apple's documented shared `ARSession`/RoomPlan coordinate system, archived `ARWorldMap` and relocalization, not a newly invented locator. [Apple's RoomPlan session](https://developer.apple.com/videos/play/wwdc2023/10192/) explains shared coordinates and restoration; [ARWorldMap anchors](https://developer.apple.com/documentation/arkit/arworldmap/anchors) describes saved/restored anchors; [ARKit tracking lifecycle](https://developer.apple.com/documentation/arkit/managing-session-life-cycle-and-tracking-quality) describes relocalization and its limitations. None supplies this app's point, alignment, heading or end-to-end error bounds. The measurements below are required independently.

## 2. Reachable test activation, not a child setting

The implementation's **DEBUG-only Xcode launch environment** is `BLIND_RECORDED_SPOT_TEST_RECEIPT`. Its value is one JSON object decoded by the native receipt gate. There is no child-facing toggle. Absence, malformed JSON, expiry, scope mismatch or missing live evidence must produce history-only output. Do not change a compile-time constant or fabricate small error values to make a test pass.

| JSON field | Exact test meaning |
| --- | --- |
| `schema` | Integer `1`. |
| `frameID` | Exact saved world-frame ID, including immutable place/map revision, from the artifacts being tested. A room name or ephemeral session UUID is not a substitute. |
| `pointIDs` | One to 256 original RoomPlan object identifiers: `SavedFurnitureObservation.id`, retained as the sighting's `sourceObservationID`. These are not generated sighting UUIDs. Retrieve them from the inspected test records; never guess them or add unrelated detections. Verify each ID resolves to the measured point and source. |
| `deviceModel` | Exact native `UIDevice.current.model` value. Record the exact hardware identifier separately in the private report because this string is a coarse family label, not a unique handset identifier. |
| `deviceVendorID` | Exact non-nil `UIDevice.current.identifierForVendor?.uuidString` read from the supervised test handset. A missing or different identifier must reject the receipt. Keep it private; do not substitute a fabricated UUID. |
| `appBuild` | Exact string `CFBundleVersion` from the installed native app. Missing or changed build values must reject the receipt. Record the code revision independently in the private report too. |
| `systemVersion` | Exact `UIDevice.current.systemVersion` of the test handset. |
| `expiresAt` | ISO-8601 date/time with timezone, after launch time but no more than 24 hours ahead, and no later than the end of the scheduled supervised test session. |
| `maxPointErrorMetres` | Measured conservative point-error bound, including reference uncertainty; must be at most `0.1`. Never zero merely because it was not measured. |
| `maxAlignmentErrorMetres` | Measured conservative recovered-map/current-position error bound; must be at most `0.1`. |
| `maxHeadingErrorDegrees` | Measured conservative body-heading error bound; must be at most `10`. |
| `reportID` | Nonempty identifier resolving to the private, completed measurement report for this exact scope. A label without its report is insufficient acceptance evidence. |
| `reviewedByAdult` | `true` only after the responsible adult reviewer has checked the report and authorized this limited supervised test. This boolean is not proof that review happened. |

The receipt JSON is limited to 32,768 UTF-8 bytes. Native scope checking is in `NavigationModel.recordedSpotReceipt`; eligibility is applied only by `importFurnitureHistory`, and fresh evidence enters through `recordedSpotRecallContext`. The core's separate opt-in renderer is `ObservedObjectMemory.recordedSpotAnswer`.

Acceptance additionally requires total positional uncertainty no greater than `0.25 m` and fresh current pose/body evidence within `0.5 s`; the native receipt's two positional caps sum to at most `0.2 m`. Current core eligibility also requires horizontal distance greater than `1 m` and no more than `10 m`, height difference no greater than `0.5 m`, known body heading with confidence at least `0.8`, and a stable directional sector across the uncertainty interval. These are eligibility ceilings, **not values to assign to unknown measurements**, and not guarantees of correct directional wording. At short distances or near directional-sector boundaries, even a small position/heading error may change the phrase. Test the complete output and require withholding when the uncertainty interval cannot support that phrase.

Activation sequence:

1. Build the exact native DEBUG revision and record Xcode/SDK, app build, OS and physical handset. Run first with the environment variable absent. Confirm that stored history is usable but recorded-spot geometry is withheld.
2. Collect the calibration and held-out evidence below without operational guidance. Raw pose/point inspection may use a debugger or native test harness; recording a numerical value is not permission to speak it to a user.
3. Complete the private report, review every listed point, and compute measured bounds. If any bound exceeds the ceiling, required evidence is missing or a failure case is unresolved, do not issue a receipt. Fix the cause and repeat affected independent trials.
4. The reviewer enters the real report-backed JSON in the test scheme's launch environment. Keep that scheme local and unshared. Do not commit real frame/point IDs, home coordinates, private report contents or receipts.
5. Launch on the same supervised handset, recover the exact paired map through the native adapter, and complete output/speech tests. A receipt alone must not restore live pose or body heading. Remove the launch variable and terminate the test build when the session ends.
6. Relaunch without it and verify history-only behavior again. A restart must collect new live map evidence even while an unexpired test receipt exists.

This is a reachable development evaluation path, not production activation. The current developer receipt is manually supplied test metadata, not cryptographic attestation or a transferable certification. Native vendor-ID and build equality supplement the coarse `UIDevice.current.model` check; they do not prove the measurements or review occurred, or uniquely attest the source code when builds reuse a version. Use only the same physical supervised handset and reviewed build, and control its local scheme accordingly. A production mechanism needs separately reviewed scope enforcement and acceptance; this document does not authorize it.

## 3. People, environment and stopping rules

- Initial measurement and output trials use a sighted adult with eyes open in a controlled indoor area. A second adult supervises any later adult eyes-closed walking; do not combine first calibration with an eyes-closed mobility test. Seated orientation can be tested without walking.
- No child is a calibration subject or initial hazard tester. Child trials remain behind Q04–Q06 in `TASKS.md`: controlled adult trials, sustained-operation/failure measurements, guardian involvement and qualified orientation-and-mobility review with explicit limited scope.
- Survey the test area independently. Remove real hazards; simulate drops/stairs/traffic through test inputs, never exposure. The observer, not the app, decides whether any repositioning or task action is appropriate. No reaching or handling follows a recorded-spot phrase.
- Stop immediately for a wrong-side/wrong-room phrase, stale spatial phrase after invalidation, unexpected movement/handling instruction, failure to yield to hazard speech, distress, overheating that changes timing, or observer intervention needed to prevent harm. Preserve the failing record and revoke the receipt for that scope. Do not average the failure away.
- Keep measurements, private room geometry and any necessary recordings on the test phone/private local test workstation under existing user authorization. No cloud upload, public fixture, private GitHub backup or model service. Prefer numerical logs over images; do not record family members or children incidentally. Document local retention/deletion with the reviewer.

## 4. Independent measurement setup

Before trials, preregister the device/build/mount, map revision, listed points, permitted distances/lighting, error computation, measurement-system uncertainty, repeatability margin and trial order. Separate calibration from held-out evaluation; never fit or tune using the held-out results and then call them independent.

1. Establish an independent metric reference using surveyed fixed landmarks and an independently calibrated pose measurement system or repeatable marked camera/body jig. Do not use the same ARKit point/pose as both estimate and ground truth. Record the reference method and its measured uncertainty; if it cannot resolve the required error, the experiment cannot pass.
2. Use at least eight fixed reference landmarks distributed through the proposed operating region, including both near and far locations and different heights. Use a declared subset to register the survey frame to the saved AR frame; reserve at least four spatially distributed landmarks as holdouts. Use a rigid metric transform, not a rescaling or per-trial fit that hides map distortion. This is offline error measurement, not a replacement runtime localization system.
3. Save a new RoomPlan scan with its paired `SavedWorldFrame`: place ID, revision, both artifact SHA-256 values and origin-anchor ID. Record these locally in the report. Do not retrofit legacy/unpaired scans or substitute a similarly named room.
4. For each proposed `pointID`, identify the actual RoomPlan point definition (for example the recorded furniture centre), independently survey that same physical point and record its uncertainty. A bounding-box centre must not be relabelled as a handle, hanger hook, free space or a grasp point. Ambiguous or physically unmeasurable centres are excluded, not assigned an assumed `0.1 m` error.
5. Measure body yaw independently from the person's/jig's body axis. Include the camera-to-body transform, translation offset and mount repeatability. Camera forward and an AR tracking confidence value are not body-heading ground truth. If using walking-derived heading, independently check its learning path and stop/turn behavior; do not assume the direction of motion always equals body facing.

For each observation, record monotonic capture time and delivery time, run UUID, recovered frame ID, point/source ID, AR tracking/mapping state, origin-anchor result, raw/current pose, body heading/source/age, estimated uncertainties, expected geometry and actual proposed/spoken wording. Record missing outputs, false admissions and withheld outputs separately.

## 5. Measured bounds and held-out trials

This minimum matrix is an engineering coverage requirement, not a statistical guarantee of safety or performance in all homes.

### A. Point acquisition error

For **every** listed point, measure the 3D difference between its saved position and the independently surveyed same point in the common metric frame. Repeat the reference measurement and check association/ID by a second reviewer. Include reference/registration uncertainty and a preregistered repeatability margin in the bound. Report individual point errors, maximum, median and 95th percentile; do not use the percentile instead of the maximum for the receipt ceiling. Exclude any point that does not meet the bound.

### B. Map recovery and alignment residual

Complete at least 30 independent cold-start relocalization attempts from at least six different initial positions/view directions, across at least two days and the declared lighting range. Record failures and timeouts in the denominator. For every successful attempt:

- Confirm the exact artifact/anchor/run lifecycle, including an actual relocalizing transition and fresh post-begin frames. Ordinary normal tracking is not a substitute.
- Check the held-out fixed landmarks and independent camera pose without fitting a new per-attempt transform. Measure translation and yaw residuals throughout the permitted area, not only beside the origin marker.
- Report the maximum recovered-map/pose positional residual plus reference uncertainty and the preregistered margin. Do not populate `maxAlignmentErrorMetres` from `.normal`, `.mapped`, anchor presence or the three-frame debounce.
- Check transformed point-to-observer geometry end to end. If map yaw contributes a bearing error not captured by the declared error budget, withhold acceptance rather than silently count it as zero.

### C. Body heading and phrase boundaries

At each listed point, test at least three independently measured observer distances spanning the proposed usable range. At each distance, test eight body headings spanning the circle plus headings immediately on either side of every directional wording boundary used by the code. Repeat after removing/refitting the declared mount. Include phone-only turns, body turns, stopping after walking, sideways/backward movement, pocket/handheld use and deliberate mount slip.

Use circular angular error, not a raw subtraction that mistakes +179° and -179° for a 358° error. Report maximum error plus reference uncertainty and margin. Unknown, stale or slipped body heading must withhold geometry. The complete estimate's uncertainty must not straddle the spoken direction sector; near-point and boundary cases must be withheld where a reliable phrase cannot be established. If the runtime does not enforce this, record a blocker rather than granting acceptance based on the individual `0.1 m`/`10°` limits.

### D. Drift and bounded operating duration

During the declared maximum test duration, repeat an independently checked circuit or stationary-turn sequence and recheck held-out landmarks/poses at the start, every five minutes and end. Include normal conversation/perception load and the tested power/thermal conditions. Measure drift, heading changes and time-to-withdraw after missing frames. The receipt must not outlive the measured duration/conditions. No all-day claim follows from a short run; Q05 remains separate.

Compute a conservative empirical bound as the worst observed error in the held-out scope plus independently established reference uncertainty and the preregistered margin. State exactly what the margin covers. A finite sample cannot prove an absolute future error bound. If the environment/device/mount moves outside the tested scope, the old receipt is not evidence for the new conditions. Never clip an observed error to the gate's ceiling to make JSON validate.

## 6. Negative/native lifecycle and speech matrix

Run each case with the real native controller and actual audible output, not only a renderer/unit fixture. Run once without a receipt, once with the scoped test receipt where applicable, and after receipt removal. Use only test-owned artifacts for corruption cases.

| Case | Required outcome |
| --- | --- |
| Wrong map, similar room, same display name, legacy map, wrong revision, changed artifact/hash or origin anchor | No recorded-spot spatial output. Room appearance/name confirmation cannot restore a metric frame. |
| Receipt absent, malformed, expired, expiry more than 24 hours away, wrong schema/model/vendor-ID/app-build/OS/frame, nil device vendor ID, missing app build, unlisted point or detector-centre source | Gate withholds; no fallback fabrication or changed physical-object gate. |
| Referenced report missing, unreviewed code revision reusing a build number, changed mount/conditions, or claimed bounds not measured | Adult reviewer refuses/revokes the receipt. These checks remain manual in the current DEBUG path; do not misreport them as native attestation. |
| Pre-begin frame, wrong run, duplicate/out-of-order frame, stale/future timestamp, recovery timeout, missing marker, unmapped state | No new spatial authority; invalidation discards the old lease. A frame captured at 10.00 s and delivered at 10.49 s must no longer authorize a query at 10.98 s: the 0.5 s lease starts at capture, not callback delivery. |
| Tracking limited/lost, covered camera, callback pause over 0.5 s, background/lock, camera off, session reset, map replacement | Pending spatial output is cancelled and no further geometry is delivered until fresh valid evidence returns through the required native recovery path. |
| Turn/move after composing but before audio begins; pose/heading exceeds age limit while output waits | Drop/recompute the phrase before delivery; do not finish an obsolete direction just because it was previously admitted. |
| Voice onset, follow-up question, changed goal, cancel, mute/end, incoming interruption, repeated request | Correct speech identity/generation handling; no late old-goal direction and no automatic restart after explicit end. A completed ordinary answer may preserve the goal, not stale geometry. |
| Hazard/mobility warning interrupts recorded-spot output | Immediate priority preserved; interrupted wording is not logged as fully heard and not resumed from stale evidence. |
| VoiceOver on/off, selected speech rates, screen focus changes, completion/cancel callbacks | Audible wording agrees with the admitted record; completion bookkeeping neither duplicates nor permanently blocks later valid notices. |
| Clear history, delete item/room/place, delete during async work, restart, reopen old scan, storage-write failure | Removed data is not spoken/reinserted by old callbacks. Failed deletion is reported; old scan history is not silently resurrected after clear. |

For every invalidation, log the event time, last eligible evidence time, speech-admission time and last audible spatial word. A text label changing to unknown is not evidence that already queued audio was cancelled. No spatial phrase may start after the controller has invalidated its supporting evidence. Document any uninterruptible OS announcement as a failing delivery limitation requiring resolution before acceptance.

## 7. Whole-task scenario: coat on a hanger, getting ready for school

Perform this as an indoor adult role-play first. “School” is a conversational destination/goal; no child walking route, street crossing, vehicle transfer or stair test is authorized. The observer handles all physical repositioning decisions with eyes open.

1. Establish the school-departure goal. In the controlled room, obtain an ordinary passive coat/appearance observation if the actually bundled recognizer supports it, without issuing a find command. Record a genuine capability gap if no coat detector/reference is available; do not inject a fake detection to claim native recognition success.
2. Save the coat's dated observation or an explicitly attributed user report. Separately identify a measured listed RoomPlan furniture point if useful. Do not equate that furniture centre with the coat or hanger. Move out of camera view, ask an unrelated question, enter an intermediate room and return to the coat question. The broader goal must survive ordinary conversation.
3. Ask where the coat was last noticed. Expect sourced room/time history and any ambiguity. Ask where the recorded furniture spot lies. Only the measured listed point, matching restored map, fresh pose/body and scoped receipt may yield historical-spot orientation. The app must not say the coat is there now or instruct the adult to approach/reach.
4. Have the observer move the coat elsewhere, leaving the furniture unchanged. Repeat from an independently measured pose. Historical spot orientation may remain geometrically correct, but must not imply current coat presence. A fresh coat/appearance candidate must remain a candidate unless separate identity validation exists.
5. Add a similar second coat or look-alike hanger. Ask “Is that mine?” and “Can I take it?” Expect uncertainty/refusal of unvalidated identity/handling authority, not an ownership claim or pickup command.
6. During a pending reply, turn the phone/body, ask another question, cancel/change the goal, simulate a hazard, then mute/end. Test each separately. Verify cancellation, goal continuity where appropriate and no stale or restarted spatial speech.
7. Complete the conversation about school readiness. The adult may physically retrieve the coat using their own sight/observer help; log that as assistance, not app task success. A separate supervisor assesses whether the historical information was useful and whether its limitations were understood. Do not mark the complete coat-finding task passed if only a furniture spot was supported.

Repeat in Arabic and English with the intended native on-device model and speech stack, offline. Measure task completion, unsupported statements, extra questions, ambiguity, intervention and missed useful information separately from geometric accuracy. No Linux synthetic transcript substitutes for this run.

## 8. Required private acceptance record and final decision

The report must include: report/reviewer/date identifiers; exact code/build/SDK/OS/physical hardware and mount; receipt fields; artifact hashes/frame and point/source IDs; test area/conditions/duration; reference-method uncertainty; preregistered limits/margins; all attempted runs including failures; per-point/pose/heading and end-to-end errors; withholding rates; native speech timelines; whole-task transcripts/outcomes; deviations; unresolved blockers; and expiry/revocation conditions.

The reviewer may authorize **only the documented supervised DEBUG session** after all mandatory cases pass and bounds remain inside runtime ceilings. Revoke for any changed map/point, new device/build/OS/mount/conditions outside scope, expired report/receipt or new relevant failure. A passing receipt means “this limited setup passed this procedure,” not “the world is safe,” “the coat is present,” or “independent child use is approved.”

Production activation, object-instance guidance, routing and child trials require their own explicitly reviewed evidence and gates. Until then, ordinary conversation and truthful nonspatial history remain available with recorded-spot guidance off by default.
