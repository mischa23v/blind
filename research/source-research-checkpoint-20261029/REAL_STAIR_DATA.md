# Real staircase recordings: what is actually available

**2026-10-29 04:46 UTC. Acquisition/inspection findings, not stair-detector evaluation.**

Real samples have been acquired and inspected, but none of the inspected bundles supplies every input and event label needed to reproduce the iPhone stair-warning study. The separate synthetic Swift tests establish implementation behavior only; they are not the paper's real-sensor success rate.

## Ordered frames already materialized: Microsoft 7-Scenes Stairs

Primary source: [Microsoft Research RGB-D Dataset 7-Scenes](https://www.microsoft.com/en-us/research/project/rgb-d-dataset-7-scenes/).

Four consecutive sequence-01 frames were extracted from bounded portions of the official archive. Each has RGB, 16-bit depth and camera-to-world pose; file CRCs and lengths were checked, and a real stairwell image was visually inspected. This was not a full archive download or a detector run. The downloaded Microsoft Research licence permits noncommercial research/personal experimentation, not commercial product use; no dataset redistribution is included here.

The source specifies millimetre depth and default depth intrinsics, and expressly discloses uncalibrated RGB/depth. Its KinectFusion/ICP-derived poses are not independent motion-capture truth. The inspected depth frames contain zero values even though the documentation describes a different invalid sentinel: mask both zero and 65535. Do not substitute familiar but unsupported camera intrinsics, assume RGB-depth registration, or treat invalid depth as floor.

No measured gravity, capture timestamps, per-pixel floor classifications or feet-boundary warning events were supplied with these samples. File indices and ZIP timestamps are not sensor timing. This is the best already-materialized ordered input for a bounded external adapter check, not faithful ARKit replay. Estimated floor normals must be labelled inferred; missing required fields remain unknown. Do not duplicate frames or invent frame rates to create a temporal success denominator.

## Matched static sample: BipedNav

Primary [author project](https://thejerrycheng.github.io/bipednav.html) and [repository](https://github.com/thejerrycheng/BipedNav); inspected public tree `1bd947e372ee5906b3f9876aae9b318958861ec7`.

A matched real RGB, 16-bit depth, organized XYZ cloud and associated tape-measurement table were inspected. Pixel-order cloud depth agrees with the author's millimetre-to-metre conversion. Some invalid zero-depth samples are finite origin points: finite-only filtering is insufficient. The author depth-to-cloud code was read, not executed.

No root dataset/code licence was found. A bundled RealSense ROS licence is not a licence for the whole dataset. Redistribution or product adoption needs clarification. The inspected static sample lacks calibration camera-info, measured gravity, world-pose sequence, sensor timestamps and hazard/alert labels. Tape association must be checked explicitly rather than inferred from similar filenames. It can support static external-hardware geometry diagnostics; it cannot establish temporal iPhone warning performance.

## Bonn RGB-D Stair Detection

Primary: [University of Bonn stair dataset](https://www.ais.uni-bonn.de/data/stairs/).

A bounded official archive prefix yielded one complete organized point cloud and real staircase images. The extracted image identifiers did not match the cloud identifier, so these are not a verified synchronized pair. The cloud contains NaNs; its header viewpoint is not independently measured gravity. Metric-looking coordinates alone do not prove documented units.

Licence, calibration, units, timing and trajectories were not established in the inspected prefix; absence from a prefix does not prove absence from the full dataset. The landing page says ground-truth segmentations are unavailable. Larger acquisition should wait for a licence/inventory plan. No temporal detector evaluation was performed.

## Explicitly licensed lead, acquisition blocked: Mendeley

Primary: [RGB-D stair dataset, version 1](https://data.mendeley.com/datasets/6kffmjt7g2/1), DOI `10.17632/6kffmjt7g2.1`.

The official page declares CC-BY 4.0 and describes a RealSense D435i test set with image/depth, point-cloud and transform folders. The public folder inventory was verified. A nested file-list request returned HTTP 403; acquisition stopped without alternate authentication or bypass. Sample bytes, calibration, units and exact transforms remain unverified. Described semantic labels are not ARKit floor classifications or warning-event labels. An ordinary permitted matched download would be useful, but this source is not yet executable input in this workspace.

## Phone-specific leads and access boundaries

- [ScaleMaster](https://github.com/JooHyoSeok/ScaleMaster-Dataset) describes iPhone 14 Pro staircase sequences with ARKit depth/confidence, camera matrices, odometry and IMU. Access requires a request form; none was submitted. Licence and actual raw encodings remain unverified. Optimized poses are not independent ground truth. This is the strongest identified phone-specific lead, not an already downloaded dataset.
- [LaMAR](https://lamar.ethz.ch/lamar/) exposes an access-request process; no request or download was performed here.
- [SF-SLAM](https://sf-slam.github.io/) describes iPhone stairs/ramps, but dataset/code availability was marked forthcoming at inspection.
- [Stray Scanner developer demonstration](https://keke.dev/blog/2021/03/10/Stray-Scanner.html) shows stairs; the linked [StrayVisualizer](https://github.com/kekeblom/StrayVisualizer) public example does not establish an available stair recording. A code licence does not license absent stair data.
- [TMO](https://github.com/JH-Choi/TMO) describes phone depth/confidence/gravity/trajectory, but its listed object scenes did not establish a staircase.

## Useful next test, and what it cannot establish

Freeze one already acquired input bundle and its documented coordinate/depth contract. Verify invalid masks, original intrinsics and pose direction before any geometry method. Keep inferred floor or gravity separate from sensor-provided evidence. Report missing coverage and actual observed geometry, including failures. Do not infer support through missing data or count a static image as repeated temporal observations.

A proper warning-success study additionally needs an approach sequence, actual sensor timing, hazard boundaries, user/feet location and alert timing. None of these source-inspection findings is a new warning-accuracy percentage, proof of collision avoidance, or permission for independent human trials.

## Access and next-step addendum — 04:48 UTC

The [pinned ScaleMaster README](https://github.com/JooHyoSeok/ScaleMaster-Dataset/blob/a294c66617deac8d93a63ea39e655a35eee88f24/README.md) and its public request form were inspected. The form asks for identity/affiliation and gives an undated April release statement; it supplies neither a dataset licence nor downloadable files. Delivery status therefore remains uncertain. No form was completed or submitted. A documented Y-up frame and IMU acceleration do not establish an independently measured gravity stream or verified synchronization. The specifically named staircase sequences do not have the reference maps attributed to other listed sequences.

A bounded diagnostic has now been authorized for the four already acquired 7-Scenes frames only: one worker, no network or installs, with explicit time/memory caps. Its task is to verify depth decoding, invalid-mask preservation, supplied pose bookkeeping and representation consistency. No completion is claimed here. Four near-identical views are not four independent approaches; a passing adapter check would not validate true dimensions, absolute pose accuracy, stair recognition or temporal warnings. The [Microsoft dataset licence](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/7-scenes-msr-la-dataset-7-scenes.rtf) remains noncommercial.
