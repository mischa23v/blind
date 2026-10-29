# Voxfield: pinned feasibility and independently checked source conditions

**2026-10-29 04:46 UTC. Source-level findings; no executed build or recorded run at this cutoff.**

## Identity and reuse boundary

Official project: [v4rl-ucy/voxfield](https://github.com/v4rl-ucy/voxfield). Inspected pin: [`78ee6403720e0aed87f4720c04c813bb38a3b260`](https://github.com/v4rl-ucy/voxfield/tree/78ee6403720e0aed87f4720c04c813bb38a3b260). Its [LICENSE](https://github.com/v4rl-ucy/voxfield/blob/78ee6403720e0aed87f4720c04c813bb38a3b260/LICENSE) is BSD-3-Clause, copyright ETHZ ASL and V4RL; preserve notices and third-party obligations. Archive SHA-256: `4e95f96e0cf76bb127531b4eab8c2df9869629e569eb9f009804d043e9cc9ca9`.

An independent reviewer checked the retained official commit receipt, archive hash and all retained source-file hashes. The saved API identifies an unsigned commit. The review's live refetch failed, so it is verification against retained official-source evidence, not a new signed-upstream authentication.

The fork retains the `voxblox` namespace and header names but extends voxel layouts. It must have a separate build, library, generated protobuf directory and include/link closure. Do not mix stock Voxblox headers or binary state with this fork. Existing dependencies appear sufficient for a native CPU core without ROS; this was feasibility inspection, not build proof. Previous stock Voxblox tests do not count as Voxfield tests.

## Released camera-wrapper defects and exact conditions

Source: [`voxblox_ros/src/np_tsdf_server.cc`](https://github.com/v4rl-ucy/voxfield/blob/78ee6403720e0aed87f4720c04c813bb38a3b260/voxblox_ros/src/np_tsdf_server.cc).

- The camera projector returns a boolean; its caller stores that value as floating-point depth. Under the default minimum-distance setting, admitted camera pixels therefore receive depth one rather than measured depth. Competing points keep the first rather than nearest return, and populated-neighbour depth-discontinuity checks become ineffective. With a minimum-distance setting at or above one, valid camera points are instead excluded. These are source semantics, not a measured failure on our recordings.
- The normal loop tests `v == height` inside `v < height`; that condition cannot protect its `v + 1` access. A populated last row with accepted neighbours can reach an out-of-raster access in the exactly sized matrices. No executed crash is claimed.
- Last-column wrap to column zero is panoramic adjacency, not perspective-image adjacency.
- Cross-product normalization has no explicit finite/nonzero degeneracy validation. This is a missing guard, not a claim that a particular input produced NaNs.

Do not adopt that perspective wrapper unchanged. A disclosed, independently reviewed adapter should use original organized depth and intrinsics; check bounds before accessing forward neighbours; compare actual axial depth; reject invalid/degenerate normal estimates; and preserve all admitted depth points, including those whose normals are unavailable. The proposed normal provider is an adaptation, not verbatim upstream behavior. It must not use reference geometry, fill missing floor, or erase difficult silhouettes to improve a score.

## Integrator confounds and persistence

Sources: [`np_tsdf_integrator.cc`](https://github.com/v4rl-ucy/voxfield/blob/78ee6403720e0aed87f4720c04c813bb38a3b260/voxblox/src/integrator/np_tsdf_integrator.cc), [`tsdf_integrator.cc`](https://github.com/v4rl-ucy/voxfield/blob/78ee6403720e0aed87f4720c04c813bb38a3b260/voxblox/src/integrator/tsdf_integrator.cc), [`core/block.cc`](https://github.com/v4rl-ucy/voxfield/blob/78ee6403720e0aed87f4720c04c813bb38a3b260/voxblox/src/core/block.cc).

- Projective weighting uses axial depth; NP weighting uses Euclidean range raised to an exponent. Equal exponent does not remove that difference.
- `normal_available` defaults false. Enabling it changes normal/gradient processing and grazing rejection. Normals-disabled versus normals-enabled NP arms isolate that combined behavior more closely; they do not isolate one mathematical term.
- A zero current normal can still use an existing voxel gradient. It is not universally equivalent to disabling correction. Preserve point order and explicit unavailable-normal counters.
- Range limits operate on point norm, not camera-z. Clearing behavior depends on configuration; out-of-range or grazing evidence must not silently become safe support.
- Serialized TSDF state omits the added gradient. Reloading is not an equivalent continuation of normal-history integration. Use uninterrupted empty-map arms and export before reload, unless serialization is separately corrected and tested.

## Experimental separation and next gates

Proposed arms are stock projective, fork projective, fork NP with normals disabled, and the same fork NP with normals enabled. Keep input frames, original calibration/poses, admitted points, masks, grid, truncation, ordering and meshing rules frozen. Keep ESDF-method changes outside this TSDF ablation. Do not tune against held-out reference scores.

First gate: isolated build and upstream tests plus synthetic adapter fixtures, with one worker, existing dependencies read-only and bounded resources. Required fixtures cover asymmetric intrinsics/units/pose, boundaries and degenerate neighbourhoods, depth discontinuities, sloped planes, thin low and head obstacles, missing support/drops, grazing rejection, unchanged point counts and gradient-loss serialization. Preserve failures; no relaxed safety margins or unknown-space policy.

Only after fixture review should separately authorized short recorded prefixes, then a full recorded run, be considered. The proposal predicts no improvement percentage. A smoother mesh or lower average error cannot outweigh new critical misses, lost coverage or worse near-field tails. No phone or human-navigation acceptance follows from this source checkpoint.
