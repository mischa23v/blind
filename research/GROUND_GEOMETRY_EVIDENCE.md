# Ground geometry: measurement before warnings

2026-10-23. Source increment after master `43dbc9c23d84b0f5ba4058f47e15b979155b3dc3`.

## What changed

`BlindCore/GroundGeometryEvidence.swift` measures bounded local patches from the same gravity-aligned `Observation` that the existing phone hazard detector consumes. It retains source/frame/time/profile, signed forward and cross gradients, local normal, maximum vertical fit residual, sample/grid coverage, and signed height differences between adjacent patches. It rejects stale/future frames, invalid tracking/axes, oversized input, sparse or non-planar patches. Missing patches are not connected across a gap. A measured patch is **not** a ground/obstacle identity or safe surface classification.

The diagnostic profile uses an explicitly unvalidated 15 mm fit tolerance. Tests also supply an exact-fixture 2 mm profile. Neither is a calibrated iPhone uncertainty, clinical cutoff or permission to ignore smaller changes. Reported uncertainty fields propagate that engineering tolerance, not statistical confidence. Values below tolerance remain unresolved, not harmless. Surface material, friction, movability/rolling, body clearance and reach safety cannot be inferred from flatness or height. A low loose object and a fixed lip are different hazards, even with the same height.

No language model is involved. No new weights, dependency, cloud inference, SLAM, path planner or firmware threshold was introduced. Existing `HazardDetector` and `GroundMonitor` behavior remains unchanged. The new adapter has no speech/clearance authority. Native integration is a DEBUG-only shadow diagnostic on actual `DepthSampler` observations, after hazard publication on nonurgent frames only, with lifecycle invalidation; its exact integration is owned by the companion integration slice. This is source-level wiring, not measured device operation or a released slope-warning feature.

## Established foundations and adaptation boundary

- Apple ARKit [raw sceneDepth point-cloud projection](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth): the existing `DepthSampler` already scales intrinsics and transforms confidence-filtered raw depth into gravity-aligned world points. Raw sceneDepth is used, not a smoothed depth substitute. Apple SDK/sample documentation is a reference; no Apple sample code was copied by this increment.
- PCL [plane segmentation documentation](https://pointclouds.org/documentation/tutorials/planar_segmentation.html), viewed 2026-10-23, documentation identifying 1.15.1-dev, demonstrates local plane coefficients, inlier selection and distance tolerance. [PCL license](https://github.com/PointCloudLibrary/pcl/blob/master/LICENSE.txt) is BSD. No PCL dependency, source or upstream test result is claimed here. Its tutorial's 1 cm example is not adopted as a device calibration.
- This adapter uses ordinary centered least-squares covariance equations for `y = a*ahead + b*side + c`, separately in nine local strips. It is new small domain diagnostic code, NOT a port of PCL RANSAC or a proven robust ground recognizer. It rejects the entire patch when ANY sampled residual exceeds tolerance, rather than discarding a protruding object as an outlier. This trades availability for honest unknowns; a future maintained robust segmentation integration must preserve coherent small-object evidence.
- Every accepted patch requires occupied cells in a 3x3 footprint. That is a sampled-support check, not complete swept-body coverage. At least one nondegenerate independent subdivision on each axis is also required: three-row samples can fit one plane while failing to distinguish a step. Numerical split-boundary ownership is consistent across rigid rotations (1e-9 m round-off epsilon, not a physical noise tolerance). Truly flat but undersampled patches therefore also remain unknown. Internal quarter/half/three-quarter subpatch comparisons on both forward and lateral axes also reject resolved jumps before a single plane can hide them. Two patches with enough support can yield a rise/drop diagnostic if the height difference exceeds the tolerance on the left, center and right boundary. Conflicting edge signs are labelled conflicting. A transition within tolerance is only a continuous candidate, never a ramp traversal permission.
- Apple [reconstructed-scene documentation](https://developer.apple.com/documentation/arkit/visualizing-and-interacting-with-a-reconstructed-scene) is a complementary mesh foundation. Floor classification and plane detection alone do not certify ramp safety. Reconstructed/flattened geometry must not overwrite live edge evidence.

## Height is not the sole warning criterion

The requested 0.1 cm is 1 mm. Sub-5 mm variation is an important noise/nuisance test stratum, not a universal ignore rule. A measured change, a loose/slippery object, a drop and uncertain support require different context. Children and adults differ, and available gait studies do not establish a universal safe cutoff for blind children.

The [US Access Board floor/ground guidance](https://www.access-board.gov/ada/guides/chapter-3-floor-and-ground-surfaces/) uses design boundaries of 6.4 mm vertical and 13 mm beveled changes. Those are built-environment design rules, not evidence that the app can ignore smaller hazards or warn reliably above them. The [Schulz adult gait study](https://pmc.ncbi.nlm.nih.gov/articles/PMC5375113/) concerns adult foot clearance and obstacle adaptation; it is not a pediatric blindness warning calibration. Hazard direction, slope, uncertainty, speed, footwear, cane, material, friction and loose objects remain relevant.

## Preserved failure baseline

The earlier actual Core/firmware replay remains the baseline, not replaced by this increment:

- Recorded stair expectations depend on assumed floor/camera heights and unverified gravity. Of 18 upward variants, seven gave obstacle, ten incorrectly gave drop, one uncertain. These are sensitivity variants, not independent recordings or an accuracy estimate.
- The ideal static belt sweep missed 13/21 rises and 13/21 drops: 4, 8, 10, 12 cm at all tested 30/45/60 degree pitches, plus 18 cm at 60 degrees. Those are NOT millimetre-scale floor noise.
- Firmware compares slant range with a baseline ±250 mm and has no current mount attitude/height input. The ideal vertical trigger is approximately `250 mm * sin(pitch)`, around 125/177/217 mm. Reducing the range constant is not a validated fix. To evaluate vertical change later requires a versioned per-sensor mount/attitude/calibration/noise/quality payload, freshness and slip invalidation, and measured physical testing. Do not infer those missing values or silently change the wire protocol.

## Executed portable evidence

Eleven dedicated XCTest methods pass, including 84 analytic signed-gradient/yaw/cross-slope combinations; six 4/12/18 cm step-direction cases; 12 offset step cases rejecting mixed patches; 1/2/3/5 mm values retained without safety authority; holes, narrow stripes, low confidence, stale/future frames, invalid axes/profile, wrong/no anchor, 1 mm noise and 4 cm protruding points. These are mathematical/code checks, not live perception accuracy or clinical validation.

The new analyzer also executes on the original recorded replay inputs without changing their labels or tuning to them:

- 84 mixed synthetic/conditional stair cases: 15 measured, 32 incomplete support, 37 unanchored; 390 accepted local patches.
- Six base apartment virtual-ray cases: all six unanchored; two patches.
- Six dense apartment virtual-ray cases: one incomplete support, five unanchored; 17 patches.

These status counts are NOT successes or failures against a hazard-label denominator. `measured` means the selected patches fit this diagnostic profile and an assumed reference, not that the world is safe or even that the sampled surface is ground. Recorded data uses its original assumptions, reconstructed virtual rays are not iPhone walks, and Intel RealSense RGB-D is not iPhone LiDAR. Inadequate support remains unknown. The independent prospectively frozen 102-case analytic holdout initially passed 101 expectations and exposed a 4 cm within-patch step that the 15 mm profile flattened into a ramp. That failure is preserved. The subsequent structural subpatch comparison fix is evaluated as a regression, not an independent accuracy gain. A newly frozen 175-case grid then passed 171 expectations and exposed four ±4 cm lateral-step cases; applying the same internal split check to the lateral axis addresses that directional omission. Both pre-fix receipts are preserved. A further fresh 68-case grid passed 64 expectations and exposed four sparse ±4 cm steps; nondegenerate subfit requirements and consistent numeric row ownership address the cause, at the explicit cost of rejecting sparse true planes. All pre-fix receipts remain, including the intermediate yaw-dependent failure. Final unchanged-expectation regression: 311/345 match; the 34 mismatches are 32 sparse-edge cases and two sparse true-plane controls, all now unanchored with zero accepted patches. All four sparse ±4 cm mixed patches, including yaw 41 degrees, are rejected; both earlier suites pass all 277 expectations. This is an explicit availability regression, not a 345/345 pass or a physical accuracy figure. Full isolated Core regression is 781/781 (770 hardening baseline plus 11 new methods). Subcell holes, layered surfaces separated by less than tolerance and combined steep gradients remain diagnostic limitations, not clearance evidence.

## Reproduce

Run the dedicated Swift package tests with `swift test --package-path BlindCore --jobs 1 --filter GroundGeometryEvidenceTests`, using writable Swift/Clang caches in restricted environments.

For replay, copy `tools/ground-geometry-replay.swift` to a temporary `main.swift`; compile it alongside `BlindCore/Sources/BlindCore/Geometry.swift` and `BlindCore/Sources/BlindCore/GroundGeometryEvidence.swift` with `swiftc`, then run the resulting executable with a `SensorReplay` JSON input path. Output keeps original assumptions, group and historical expected label separate from diagnostic measurements. Fixtures/results stay outside the repository; do not publish private recordings.

## Gates still open

1. Actual iPhone calibration and ground-versus-object association, measured noise by range/material/lighting/motion/mount, independent replay labels and valid gravity/pose metadata.
2. Steep planes, mixed support, partial occlusion, small coherent protrusions, low/high reflective surfaces, cloth, glass, dark floors, motion distortion and camera/mount shifts.
3. Real signed gradient/edge accuracy and rejection rates, plus resource/latency effects of the bounded shadow analysis. Normal camera/body pose changes must not become fake stairs.
4. Native Apple SDK compilation and actual shadow lifecycle, then controlled adult bench trials. No child trials on real drops/stairs or independent navigation approval follows.
5. Only after a separately accepted native profile and evidence-bound speech integration may short slope/step cues be considered. No guessed universal child cutoff, friction confidence, or 'path clear' claim is part of this work.
