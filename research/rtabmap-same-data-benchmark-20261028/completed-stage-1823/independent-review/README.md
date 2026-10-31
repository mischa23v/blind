# RTAB-Map adapter independent pre-execution review

2026-10-28. **Source/input/numpy preflight passed, not an executed-engine result.** No build, reconstruction, or raycast duplicated by reviewer. Official source revision `8cd2f81a735722402d1e220147c4e83a1a746eaf` is present in `fresh-run/source/`.

`check_inputs.py` / `INPUT_REVIEW.json`: 4,777 assertions; all 530 RGB/depth file hashes and raster metadata; exact 265 training/29 disjoint holdout membership and order; all per-frame intrinsics; all optical matrices; 795 asymmetric world-point equivalence checks. Inputs retain original 738×994 resolution. No RGB EXIF rotation required. TSV transforms already contain OpenGL-to-optical flip once.

## Source findings

- Let F=diag(1,-1,-1,1), C=supplied OpenGL camera-to-world, P=C F, A=rtabmap_T_opengl, B=A^-1, O=CameraModel::opticalRotation. Native definitions satisfy B O=F. Mapper node pose A P F B and export B node O reduce exactly to P. This is **not** a duplicate camera flip.
- `cloudsRGBFromSensorData` in upstream `corelib/src/util3d.cpp` already applies the CameraModel local transform O. Exporting that node-local cloud with B node is correct; applying O again would be wrong.
- Per-frame CameraModel construction preserves each frame's distinct fx/fy/cx/cy. Native RGB decoder and `cloudFromDepthRGB` both use BGR (`bgr[0]` blue, `[2]` red), so colors are not swapped. uint16 depth is interpreted in millimetres by the released projection path; native execution fixtures still required.
- `getGraph` flags request images and local grids, not scan/user data/words. Exported clouds come from saved RGB-D observations and graph poses plus native voxelization, **not a fused surface**. They cannot receive mesh first-hit metrics without a separately declared surface reconstruction.
- `SensorData` stamps remain zero; no actual capture timing supplied or inferred from filenames. No IMU, odometry velocity, or measured covariance exists in this adapter. Default process covariance is identity by API, not a precision estimate. This limits graph/motion inference; no physical localization accuracy claim.
- Local-grid labels depend on native normal/height defaults and map-frame projection. They are algorithm labels, not validated support/obstacle truth or safe empty space. In particular, missing IMU does not become synthetic gravity evidence.

## Issues found and corrected/disclosed before execution

1. **Depth endpoint mismatch:** upstream `cloudFromDepthRGB` accepts positive depth <=maxDepth. RTAB maxDepth=4 therefore admits exactly 4000 mm; Open3D excludes >=4000 mm. Worker froze retaining native behavior, documenting the difference and counting boundary pixels. This is an engine comparison, not identical admitted-sample membership at the boundary. No result-based choice.
2. `Rtabmap::init` can load an existing database even with `loadDatabaseParameters=false`. Adapter now rejects preexisting `map.db`.
3. Export previously skipped missing signatures silently. Adapter now fails for missing signatures/unknown input IDs and asserts fixed-arm optical poses agree with supplied poses within 1e-4. Completeness and accepted-frame totals still require runtime reporting; these assertions do not force every observation to survive native mapper policies.
4. Existing projection fixture used a centre pixel only. Added off-axis asymmetric intrinsics and exactly-4000-mm boundary cases; these must pass in the actual linked runtime.

Current reviewed mapper SHA256 is in `INPUT_REVIEW.json`. Production worker owns compilation and final launch freeze. If it changes, rehash/review applicable changes. Nothing here certifies that C++ build, fixtures, data ingestion, graph optimization, or exports have actually completed.
