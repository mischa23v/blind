# Next real-data comparison: primary-source screening

Checked 2026-10-29. No dataset/model download or author contact. These are **not** the original SensoryScape recordings and cannot reproduce its trial denominator or alert-before-foot-boundary result.

## First candidate: Bonn RGB-D Stair Detection

https://www.ais.uni-bonn.de/data/stairs/
Official University of Bonn page: moving hand-held camera in LBH building; 230 RGB-D PCD point clouds + PNG color frames; published archive 513MB. No ground-truth segmentations included. Landing page does not establish gravity, timestamps, camera trajectory, intrinsics, sensor identity, coordinate conventions or data licence. Those are open prerequisites, not assumed fields.

Bounded plan: inspect licence/README and archive metadata first; request approval before the513MB download if no per-file route is offered. Do not download whole archive just to learn whether it is useful. If permitted, unpack only bounded first/last and one stair-approach subsequence, hard total byte budget, no executable content. Inventory finite metric coordinates, order, camera calibration, pose/gravity, and scene labels. If gravity/pose absent, do not fabricate them; at most separately labeled local point-cloud geometry analysis. A PCD is not an ARKit triangle mesh; reconstruction method and raycast sampling must be separate explicit experimental choices. Without foot-boundary/alert timing labels, report per-frame geometry candidates and unknown rate, not92.5%-comparable success.

## Static fallback with explicit licence

https://data.mendeley.com/datasets/p28ncjnvgk/2
DOI10.17632/p28ncjnvgk.2. Wang, Pei, Qiu, Tang;2023;CC BY4.0. RealSense D435i real scenes.2388 training and608validation RGB/depth pairs with convex/concave stair-line endpoints; padded/resized512x512. Useful real-image/edge checks but not inherently temporal replay. Confirm metric depth encoding, original-to-padded intrinsics, gravity, and per-file sizes before download. Author paper: https://www.mdpi.com/1424-8220/23/4/2175 . Do not infer geometry from resized depth without calibration.

## Better hardware fit, not released yet

https://sf-slam.github.io/
Author project describes iPhone15ProMax/StrayScanner RGB-D and ARKit trajectories on stairs and ramps. However it explicitly labels both Code and Dataset **Coming Soon** (anonymous T-RO2026 under-review page). No available release/license verified; no guessed storage URLs. Keep as future lead, not usable data.

## Small-sample secondary lead

https://thejerrycheng.github.io/bipednav.html
Author's project page describes five archived real stairs with RGB, RealSense depth in millimetres, point clouds and tape measurements. Source/data licence and calibration must be verified before use. Single scenes do not validate temporal persistence or same-input phone detection. Do not use monocular estimated depth as sensor truth; page explicitly distinguishes those products.

## Acceptance of a real replay adapter

Require: source/version/checksum/licence, bytes and bounded scene scope, documented units and depth validity, camera intrinsics/resizing, timestamp ordering, coordinate frame and gravity, actual camera forward, pose validity, occlusion/missing-depth semantics, and independently inspectable stair/drop/ramp/flat labels. Author mesh classifications must not be invented from model labels. If any required field absent, carry unknown or limit evaluation rather than pretending original paper equivalence. No user/child recording upload, no live mobility trial.
