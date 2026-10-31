# Live floor support: exact missing producer and a usable temporal design

2026-10-30. **Source audit, not a navigation implementation, sensor experiment or release approval.** This packet changes no app code, defaults, thresholds, geometry, physical-output gates or calibration. It deliberately does not add another receipt-only owner. Source was resolved as reviewed post86 source28, then reviewed86, then exact `ff0f50df695bfa48fd72697858c574fda653dc4e`; `SOURCE_PINS.json` records exact bytes. The independent review and root publication remain separate.

## Finding

There is no independently validated production `NativeLocalizationMeasurements` producer to connect. `NavigationModel.nativeLocalizationCalibrationRevision` is literally `unconfigured`. The latest issuer retains candidates but retires registered output with `missingCalibration` (or `localReferenceOnly`); only its explicit bench seam can prepare a pair, and it never installs that pair. Goal-free saved-world references intentionally have no floor identity or physical authority.

This is **not proof that useful phone navigation is impossible**. Two distinct issues were conflated:

1. Missing measured inputs: camera-to-body reference, metric/radian error model, observed support coverage and its change/freshness validity.
2. A restrictive current interface: `NativeLocalizationEvidenceGate.prepareForBench` requires `support.observedAt == candidate.capturedAt`. It has no explicit representation of a fresh evaluation of older, directly observed floor now briefly occluded by the wearer. Relabeling an old source timestamp to satisfy equality would be false evidence; merely removing equality would be unsafe.

## Actual connected path

| Existing producer / consumer | What reaches it | What it does not establish |
|---|---|---|
| `DepthSampler.observation` → `processDepthHazards` | Original `sceneDepth`, confidence 2, scaled frame intrinsics, full camera transform; stride 2 depth samples, original timestamp | Pixel identities/intrinsics are not retained in `Observation`; body transform and quantified errors are absent. A confidence ordinal is not a covariance. |
| `HazardDetector` → `CurrentNavigationHazards` | Fresh positive hazards and a retained level-floor calibration | The floor scalar is not newly measured full support. Current hazard receipts always report `fullFootprintSupportKnown == false`. |
| `ObservedSceneRuntime` → existing `LocalPlanner` | Same sampled world points, retained floor, recorded body-envelope preview | Candidate look-ahead only, not current foot location or body-to-start connector. |
| `NativeARObservationAdapter.capture` → private observation history | Actual frame pose/intrinsics plus bounded sampled depth pixels and confidence; sparse anchors | At most 1,024 sampled raster positions, historical storage, no certified coverage. Unreadable/missing data remain explicit. This is not the motion producer. |
| `NativeMapping.consume` → pinned RTAB-Map → local-grid owner | Original RGB/depth frame and upstream ground/obstacle/empty cells with transforms and associations | Ground labels, empty rays and a 30-second retained tile do not mean current support. Latest-pose lease is separate. |
| `offerNativeLocalization` → selected router → issuer | Same-frame recovered-world association, full pose, session/selection/map/mount owners | No measured body pose, support or total error is supplied. A recovered coordinate frame alone is not calibration. |

The raw depth and RTAB offers are already deferred behind urgent processing. The raw/history path does not depend on the hazard lane's horizontal-heading admission. No missing callback here justifies passing a retained floor scalar into `SpatialFloorSupport`.

## Blind spots versus unnecessarily strict requirements

**Code-defined exclusion:** `HazardDetector` samples its corridor from 0.3 m ahead; `GroundGeometryAnalyzer` also starts at 0.3 m and uses diagnostic unvalidated tolerances. `LocalPlanner` deliberately starts its grid at approximately 0.6 m ahead of the camera. None establishes the near connector, underfoot region or rear region. These are coordinates relative to the camera, not a calibrated wearer footprint.

**Sensor visibility:** a forward-facing depth camera cannot observe a surface through an occluding body or outside its frustum. But floor can be observed before the wearer reaches it; a stationary supervised scan can also observe currently visible near-floor regions. Whether a given chest pose sees a specific region is determined by that frame's intrinsics, full pose, valid depth and occlusion—not a universal invented iPhone field-of-view number. A roughly downward camera can still produce raw observations; the hazard `DepthSampler` intentionally rejects horizontal optical length at or below 0.25 because its camera-relative horizontal direction is undefined. Do not invent body yaw to bypass this condition.

**Overstrict if interpreted as a perpetual rule:** demanding every required supporting surface be directly visible in the *same instant* as the pose is incompatible with ordinary occlusion during walking. It is a defensible current fail-closed gate, not necessarily the eventual operational definition of fresh support. Previously observed floor should remain dated evidence, not vanish solely because a foot now covers it; neither should it become indefinitely current.

**Still not observable from these inputs:** an occluded newly opened hole, loose or moving covering, traction, actual contact/load bearing, or a new obstacle hidden from all current sensors cannot be ruled out by a frozen depth map. A useful operating domain, residual-risk policy and supervised validation are required; the app must not promise universal support/clearance. A cane/companion/user assertion is not sensor proof. First-start support has no prior observation unless it was actually acquired.

## Established method, not a new mapper

[ANYbotics' original robot-centric elevation mapping](https://github.com/ANYbotics/elevation_mapping/tree/f4b082c64a3e660980da53b33c7936a8f2a2ea22) uses distance measurements, pose/covariance and transforms, propagating localization uncertainty through robot motion. It retains terrain rather than requiring every point in every scan; it also has visibility cleanup and explicit sensor-noise inputs. Its BSD-3-Clause repository now says it is not actively maintained. This is a relevant method reference, **not an adopted iOS dependency or a safety-certified algorithm**. Its constant-plane initialization is unsuitable for this app's missing-data rule and must not be used. No upstream code was installed or copied into the app; reference source text was inspected read-only.

[ETH's traversability estimator](https://github.com/leggedrobotics/traversability_estimation/tree/14d24c059e1c43466aadf328280adf6394d78039) has a footprint-path query on an elevation map, but is ROS research software and its README reports no unit tests. Its configurable default score for unknown regions must not be accepted as clearance. Its root license is BSD-3-Clause. It is evidence of an established task decomposition, not proof of phone integration. Exact inspected revisions and file blob IDs are in `UPSTREAM_REFERENCES.json`. No upstream tests or builds ran.

The primary [2018 terrain-mapping paper](https://doi.org/10.1109/LRA.2018.2849506) is the algorithm reference. The ETH download returned HTTP 403 in this pass; no paper details beyond the upstream repository's explanation are claimed from an unread full text. No retry or alternate download was attempted.

[Apple's scene reconstruction API](https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration/scenereconstruction) estimates geometry and can smooth detected planes. [Depth confidence](https://developer.apple.com/documentation/arkit/ardepthdata/confidencemap) is ordinal and affected by reflective/absorbing surfaces. Thus neither a `.floor` label nor a smoothed mesh is a substitute for original, time-associated depth and measured uncertainty.

## Smallest justified next integration slice

**Design hypothesis needing independent review and device validation, not implemented here:** evaluate already directly observed, short-lived floor evidence at the *current* pose, carrying acquisition age and propagated uncertainty separately. Reuse the existing ARKit acquisition/projection and selected RTAB-Map ownership/transform foundations; select a maintained suitable terrain-estimation implementation before porting an algorithm. Do not write a substitute mapper merely to make the gate pass.

Before changing the gate, define a producer input/output contract with these actual values:

- Raw source frame IDs, original acquisition times, depth/confidence pixels (including invalid/unobserved regions), intrinsics/resolution, full camera-to-session-world transforms and tracking/recovery epoch. Reuse the existing adapter; the sparse history cap must be disclosed, not treated as a dense guarantee.
- Independently measured camera-to-body transform and revision, body reference convention, supported mount orientation, full support-query footprint and body/equipment geometry revision. Reported mount offsets and heuristic `BodyHeading.confidence` are not this measurement.
- Validated depth/pose/time/mount error model for the intended hardware/mount/domain. ARKit `.normal` and confidence 2 do not provide metric error bounds by themselves.
- **Separate** `evaluatedAt`/current candidate identity from each source acquisition time (at minimum oldest/newest plus resolvable source IDs). Evaluation may age/reproject evidence; it must not refresh acquisition age. The producer must retain uncertainty and unknown coverage across motion, not flatten to one floor.
- Coverage of the intended support-query region expanded by current uncertainty, and a local support-height interval/model. A single `supportHeight` plus digest is only a downstream summary; the trusted validator must resolve the real geometry and provenance. Ground support and full-body obstacle clearance are separate checks.
- A validated maximum source age, motion/uncertainty domain and change/contradiction policy. **No numerical expiry or motion threshold is selected by this audit.** New contradictory returns retire the affected support; missing returns do not imply either a new floor or free space. Unknown cells stay unknown.
- Mandatory reset on stop/background/session or recovery change, mount/body/calibration revision change, tracking loss, map-frame change, expiry, stale/reordered callbacks and source contradictions. Current-candidate and output-delivery freshness remain mandatory even if support sources are older.

The immediate honest code seam remains `NativeLocalizationMeasurements` → `NativeLocalizationEvidenceGate.prepareForBench` with the real validator. First extend that seam only alongside the real producer so raw observation time and current evaluation time cannot be confused. The production issuer should stay withheld until the accepted validation/release boundary is met. An extra receipt containing only IDs or a boolean cannot close this gap.

### Explicit proposed types — design only, no constructors shipped

`HistoricalFloorObservation` would own the original AR session/recovery epoch, frame ID/time, raw raster and validity mask, intrinsics, full optical transform, source revision and independently characterized measurement errors. Immutable acquisition fields never change when the observation is re-used. It describes measured surface samples, not proof that a surface is semantically floor, stable, or load-bearing.

`CurrentSupportEstimate` would own the exact current localization candidate ID/time, body/mount/calibration/geometry revisions, all referenced historical observations and their ages, the query region, propagated errors, observed-versus-unknown coverage, contradictions, the estimated support geometry and the expiry/domain. It has no public conversion to a route lease or `SpatialFloorSupport`. A current estimate is not a claim of current direct visibility of every source sample.

`SupportValidationContext` would resolve actual retained records and the separately frozen sensor/mount/domain validation protocol. Only a reviewed producer plus trusted validator could turn the estimate into the existing bench measurement summary; the current physical release boundary would still apply. A valid current pose plus an old map ID cannot construct an estimate. This separates two clocks without turning equality removal into a permission switch.

### Noise and context assumptions that must be measured

The inspected upstream [motion updater](https://github.com/ANYbotics/elevation_mapping/blob/f4b082c64a3e660980da53b33c7936a8f2a2ea22/elevation_mapping/src/RobotMotionMapUpdater.cpp) uses previous/current poses and covariance to update height and horizontal variance; its state-estimation assumptions are not supplied by ARKit tracking status. Its [structured-light processor](https://github.com/ANYbotics/elevation_mapping/blob/f4b082c64a3e660980da53b33c7936a8f2a2ea22/elevation_mapping/src/sensor_processors/StructuredLightSensorProcessor.cpp) propagates rotation/sensor variance and contains a Kinect-derived parametric noise model. Those coefficients and confidence-ratio semantics are not iPhone LiDAR calibration.

For this app, measure error as a function of range, incidence angle, material, lighting, motion and mounting; measure temporally correlated pose drift and discontinuities, not just per-frame residuals. Mount flex and time synchronization need their own bounds. Validate the chosen error-envelope coverage on held-out sequences; a variance is not an automatic worst-case safety bound. Distinguish multi-level terrain from the estimator's supported representation. Even a perfect geometric covariance model cannot account for an unseen physical surface that changed after acquisition: its bounded-persistence assumption must be explicit and tested in the operating domain. These are proposed local validation requirements, not claims about completed upstream validation.

## Required local observations / decisive next experiment

Use a seated or sighted-supervised bench setup, not a child walking test. Record on-phone only: original synchronized depth/confidence/pose/intrinsics, measured mount/body reference and a separate reference measurement of known floor/edge geometry. Include a visible patch becoming body-occluded, revisit after motion/turn, tracking loss/recovery, mount slip, stop/restart, reflective/absorbing floor, a controlled removable *simulated* support patch and a new obstacle. No actual drop/stair or unsupervised eyes-closed walking.

Pre-register the supported domain, independent reference accuracy, source/model versions, frozen calibration split and held-out validation split, the relevant false-accept/unknown metrics, and reviewer-approved acceptance criteria before evaluating. Do not choose a convenient expiry after seeing the held-out failures. For a frozen upstream-backed temporal producer, compare current evaluation against independent reference and explicitly measure unknown coverage, error growth, stale acceptance, changed-surface withdrawal and latency. Retain failures. The decision is whether bounded reuse can support the defined footprint/domain—not whether an idealized flat sample yields a route. Exact age/error limits require those observations. Until then the precise blocker is **missing measured producer inputs and validated temporal-support policy**, not a missing permission or a proven hardware impossibility.

## Verification and handoff

`audit.py` checks pinned source and specific connections/exclusions. It is source text inspection only, not Swift execution or geometry accuracy testing. See `RESULTS.json` for its result. There was no Swift toolchain in this executor; Apple build/device tests were not run. Root may record this result under N02/N03, leaving measured localization, support and navigation acceptance open. No tracked source or shared checkout was edited.
