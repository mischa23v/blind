# Source-only audit: MuSHRoom camera convention versus world up

2026-10-28. No reconstruction, reference alignment, floor fit, or human-height inference was used in this audit. Existing experimental arms were not changed.

## Verdict

**The bundled MuSHRoom/Nerfstudio input-format contract says world +Z is up, independently of OpenGL camera +Y being up.** Applying RTAB-Map's OpenGL-to-RTAB transform to the world solely because cameras use OpenGL is therefore an unsupported conflation, and is inconsistent with that documented format contract. This is more specific than merely missing an IMU stream.

There is nevertheless a provenance limitation: the original capture lacks its raw Polycam per-frame export and a converter execution receipt. The sources establish the intended convention, not a measured guarantee that every capture was exported without extra rotations or that estimated gravity was accurate. Do not claim measured physical gravity has been recovered.

## Primary source chain

All MuSHRoom links below are pinned to `3f36dbfe24c783f85e320a613096eee5216839eb`.

1. [Bundled data conventions](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/mushroom_method/docs/quickstart/data_conventions.md), Git blob `98095af956ebcfb0aef9b25b8740493a3b4ae154`: separates Camera/view space (OpenGL/Blender, camera +Y up, looking -Z) from World space (+Z up, ground parallel XY). These are different coordinate systems.
2. [Bundled Polycam converter](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/mushroom_method/nerfstudio/process_data/polycam_utils.py), Git blob `a005f1b2fb653b8df6b3acb72963aedcdbf3b04c`: writes **`transformations.json`**, sets `camera_model` to perspective/OPENCV and `orientation_override` to `none`, then builds the pose using raw Polycam **rows [2,0,1]**, including translation. That is a world-basis permutation: raw Y becomes output Z. It is not the camera-column Y/Z flip. This source is in the dataset author's own released repository, not merely a modern third-party converter.
3. [iPhone within-sequence converter](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/iphone_tools/1_nerfstudio_to_sdfstudio_within.py), Git blob `040dd178fb9451c8d5772c1d2ad4ab5dad2e5396`: reads `transformations.json`, describes the poses as OpenGL/Blender camera convention and flips **columns** 1 and 2 (`c2w[0:3,1:3] *= -1`) to OpenCV. It does not rotate world axes. Its later scene normalization translates/scales, with inverse saved as `worldtogt`; that is not a gravity correction.
4. [Dataset preprocessing instructions](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/doc/data_preprocess.doc), Git blob `f125dc7fd64f09fd1e2d16881026a8e85c5ea84c`: prescribes the within-sequence converter with `--data-type polycam`. [README](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/README.md) calls the original iPhone file Polycam poses and separately labels COLMAP poses. Neither is a per-capture IMU receipt.

Independent corroboration, not proof of which exporter generated this capture: Nerfstudio v1.1.5 commit `6b60855003011b2ca23c2fe3f8e2ca6314c69924` has the same row permutation and `orientation_override=none` in [polycam_utils.py](https://github.com/nerfstudio-project/nerfstudio/blob/6b60855003011b2ca23c2fe3f8e2ca6314c69924/nerfstudio/process_data/polycam_utils.py), and the same world/camera distinction in [data_conventions.md](https://github.com/nerfstudio-project/nerfstudio/blob/6b60855003011b2ca23c2fe3f8e2ca6314c69924/docs/quickstart/data_conventions.md).

DN-Splatter `97588b4290128ce7ba6fdbfaac3020b42b17de4c` [mushroom_dataparser.py](https://github.com/maturk/dn-splatter/blob/97588b4290128ce7ba6fdbfaac3020b42b17de4c/dn_splatter/data/mushroom_dataparser.py) defaults orientation_method to none and loads transformations_colmap.json. It does not independently certify gravity of our original Polycam input and should not be cited for that claim.

## Actual metadata, bounded inspection

Input `fresh-run/inputs/room_datasets/koivu/iphone/long_capture/transformations.json` under the Open3D benchmark has SHA-256 `c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3`.

Top-level keys are exactly `camera_model`, `orientation_override`, `frames`; values are OPENCV and none, with 294 frames. Frame keys are `fl_x, fl_y, cx, cy, h, w, file_path, depth_file_path, transform_matrix`. No gravity, world-up vector, tracking state, or applied-transform provenance is supplied. OPENCV here describes the camera model/intrinsics, not proof of camera-pose axes; the author's converter explicitly performs the optical column flip.

## Why geometry roundtrip can pass while ground semantics fail

RTAB-Map `8cd2f81a735722402d1e220147c4e83a1a746eaf` [Transform.h](https://github.com/introlab/rtabmap/blob/8cd2f81a735722402d1e220147c4e83a1a746eaf/corelib/include/rtabmap/core/Transform.h#L283-L302) defines:

```
A = rtabmap_T_opengl = [[0,0,-1],[-1,0,0],[0,1,0]]
B = inverse(A)
F = diag(1,-1,-1)  # camera OpenCV/OpenGL flip
O = camera optical-to-node rotation
B O = F
```

Current adapter uses `nodePose = A opticalPose F B`. Its exported optical pose is `B nodePose O = opticalPose`. Thus a fixed-pose roundtrip test correctly passes and cloud point comparison remains meaningful; it does not verify ground-up semantics inside the native mapper.

For an input world-up vector `[0,0,1]` under the documented convention, the left-hand `A` sends it to `[-1,0,0]`, **not native +Z**. Native ground classification therefore cannot be justified by the camera-convention identity check. Ground/obstacle labels and floor-based traversability in this arm must remain unvalidated until a separately frozen world-frame-correct arm is tested. Do not relabel the old arm silently.

## Recommended separate corrective contract

Keep world and camera basis transforms explicit and independent. Under the documented +Z world-up convention, use a world transform that preserves +Z; an identity world basis is sufficient, with camera-to-node optical rotation handled on the right. Algebraically, given an OpenCV camera-to-world pose P and camera local rotation O, use node pose `P inverse(O)` and export `nodePose O`; add a separately documented world transform only if supplied by provenance. This is a proposed contract, not a completed rerun or a claim of navigability. Add a fixture asserting the documented world-up vector remains native +Z, in addition to the existing camera roundtrip fixture. Physical gravity accuracy remains unmeasured without capture-specific evidence.
