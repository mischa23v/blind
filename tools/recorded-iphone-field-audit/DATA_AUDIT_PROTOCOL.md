# Preregistered raw iPhone field/decoder audit — no navigation evaluation

## Fixed inputs and limits

- Dataset: CaryxAI/everyday-manipulation-3d-raw at immutable revision `a285cd1249fe9762085713a1c796ab68b1810ac2`.
- Only clip `clips/D2/EM1-0387.r3d`, 13,973,317 bytes, expected SHA-256 `aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4`. Publisher identifies iPhone 12 Pro. Choice is the smallest indexed actual recording, not selected by detector success.
- Download cap 16 MiB. Select only archive metadata and the first eight numerically ordered original RGB/depth/confidence triples; combined selected/decoded-output cap 64 MiB. Retain at least 768 MiB free. No other clip, model, reference mesh or point cloud.
- Codec: official BSD-3-Clause LZFSE C reference, pin `e634ca58b4821d9f3d560cdc6df5dec02ffc93fd`; proposed source set 213,037 bytes, acquisition cap 1 MiB, working-directory cap 10 MiB. Direct serial installed gcc only, no package/OS installation or USB streaming library.

## Audit stages and fail conditions

1. Verify the official pinned clip size/hash and retain dataset license/provenance. Hash-matched ZIP content is still treated as untrusted input.
2. Validate complete ZIP inventory before use: reject traversal, links, special types, encrypted entries, duplicates and oversized entries; bound total uncompressed sizes and process resources. Do not extract all. Keep incomplete output separately, never consume it as complete.
3. Inspect original metadata keys, dimensions, frame counts, frame timestamps, intrinsics, camera type, poses and `initPose`. Missing fields remain missing. Do not create capture times from frame number/configured FPS, invent normal tracking or a body mount, or replace poses with globally optimized estimates.
4. Build only the existing bounded codec. Decode depth into an exact `4*dw*dh`-byte float32 buffer and confidence into an exact `dw*dh`-byte uint8 buffer. Fail on truncated/oversized decode, nonfinite/invalid dimensions or out-of-range confidence. Preserve original compressed member and decoded hashes. No confidence replacement/filtering is permitted to make a frame pass.
5. Inspect actual first-eight RGB headers, depth finite/zero/range counts, confidence0/1/2 counts, timestamp ordering and intervals, pose numeric validity, and intrinsic metadata shapes. Do not equate these statistics with detection recall or safe clearance.
6. Validate coordinate conventions before any later projection: Record3D pose is OpenGL camera-to-world, negative Z forward; intrinsics are for RGB and all focal/principal entries scale by depth/RGB resolution ratio. Original `initPose` and its relation to gravity must be inspected, not guessed. No unit-box normalization.
7. Mark tracking state **unknown** unless an original field establishes it. The present Linux transport hardcodes normal tracking and must not be used unchanged for authority-bearing replay. Missing calibration/pose/tracking inputs bar route/localization/body-clearance authority. A separately labeled depth-only geometry component may be proposed later without claiming that authority.

## Acceptance and stopping condition

This audit succeeds only in establishing authentic input provenance and exact decoder/field compatibility, or in producing an exact supported blocker. It does not claim native policy admission, obstacle detection success, hardware feasibility in all scenes, or A→B completion. No perception thresholds, planner features or navigation scenarios are changed. No held-out miss-rate study or navigation run begins before the protocol maintainer reviews the resulting field contract and approves a separate perception protocol.

Phone is the starting platform, not a required final stand-alone device. Subsequent feasibility work must evaluate the existing phone-plus-belt/additional-sensor architecture against measured coverage, latency and body/extrinsic requirements. An export omission or phone field-of-view limitation does not establish whole-project infeasibility.
