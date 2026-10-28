# Smallest bounded InfiniTAM comparison proposal

**Source-only plan, not authorization or a measured result. No command below was executed.** Root decides after RTAB-Map finishes; no concurrent CPU build/run and no mutation of its workspace. This supplements README.md rather than replacing its license and metric caveats.

## What can be reused read-only

The active RTAB-Map preparation now contains a hash-verified Debian **CMake 3.31.6-2** binary plus matching `cmake-data` in `research/rtabmap-same-data-benchmark-20261028/fresh-run/prefix/usr/`. Its `DOWNLOAD_LEDGER.json` pins the package. Existing `/usr/bin/g++` and make are available. The old claim that no CMake exists applies to PATH, not this newly restored isolated prefix.

Use that CMake executable and its package/module paths read-only, with a completely separate source/build/output directory. Do not change symlinks, CMake files, package cache, or configuration in RTAB's prefix. Copy neither RTAB nor PCL into the InfiniTAM binary. CMake compatibility remains to be tested: 3.31 retains old policy compatibility with warnings; a successful RTAB build does not establish InfiniTAM compatibility.

**Zero new dependency-package download is the target**, not a promise. Do not use libpng/OpenCV/PCL in the smallest arm: decode existing PNGs once with the already available Python/Pillow into explicit little-endian signed-short millimetre files, and supply a dummy RGB buffer required by the released API. Geometry-only `ITMVoxel_s` ignores color. Persist and hash the conversion manifest. Keep original source depth files untouched; mask zero and >=4000 mm only in adapter output for the declared common input domain. Conversion occupies 388,793,160 bytes for 265×738×994×2; source image hashes and decoded-pixel counts are retained.

The input dimensions, calibration, pose and 265/29 split reuse the completed Open3D freeze, not RTAB's inclusive-4-m domain. No FARO data in build/fusion process.

## Minimal official-source build shape

Download only official source pinned to `4156547e7f118c3a303d0b3c20f4da2aa3bfc9c9`; cap compressed and unpacked bytes; record archive SHA and tree identity. No third-party installation scripts or GPU tooling.

Use an external CMake harness that adds unchanged upstream library subdirectories:
- `ORUtils`
- `FernRelocLib`
- `MiniSlamGraphLib`
- `ITMLib`

Set the harness's upstream module root explicitly for the upstream subdirectory CMake files (`PROJECT_SOURCE_DIR` references in their includes). Do **not** add upstream `Apps` or `InputSource`: that avoids the top-level unconditional GUI/OpenGL check and unnecessary sensor drivers. This changes build selection, not mapper math or upstream source. Link one small runner to those static libraries. Explicitly set `WITH_CUDA=OFF`, `WITH_OPENMP=OFF`, `WITH_PNG=OFF`, `WITH_CSPARSE=OFF`; standard C++11 on Linux. Do not imply this harness has already configured successfully; record any compatibility adjustment before proceeding, never silently patch reconstruction code.

Primary build-source inspection: [ORUtils CMake](https://github.com/victorprad/InfiniTAM/blob/4156547e7f118c3a303d0b3c20f4da2aa3bfc9c9/InfiniTAM/ORUtils/CMakeLists.txt), [ITMLib CMake](https://github.com/victorprad/InfiniTAM/blob/4156547e7f118c3a303d0b3c20f4da2aa3bfc9c9/InfiniTAM/ITMLib/CMakeLists.txt), [flags](https://github.com/victorprad/InfiniTAM/blob/4156547e7f118c3a303d0b3c20f4da2aa3bfc9c9/InfiniTAM/cmake/Flags.cmake), [optional PNG](https://github.com/victorprad/InfiniTAM/blob/4156547e7f118c3a303d0b3c20f4da2aa3bfc9c9/InfiniTAM/cmake/UsePNG.cmake).

## Small runner, no replacement mapper

1. Read manifest/depth buffer and initialize `ITMBasicEngine<ITMVoxel_s,ITMVoxelBlockHash>` in CPU/basic mode. Fix initial calibration from the first training frame.
2. Use upstream `trackerConfig="type=file,mask=<isolated poses/%04i.txt>,initialFrameNo=0"`; leave its actual tracker active. Write exactly 265 pose files in the file reader's documented element order and verify via asymmetric fixture. Files contain `Cgl * diag(1,-1,-1,1)` camera-to-world matrices. IDs refer to original frames in manifest, not fabricated time.
3. For subsequent images update public `GetView()->calib` to that frame's K before `ProcessFrame`. The view is allocated at first call, not before; do not dereference null. Assert effective K and resulting pose after every call. Original depth converter uses `view->calib`; no per-frame assumption is hidden.
4. Use `FAILUREMODE_IGNORE` only with independent fail-fast checks that every pose file parses, is finite, is the expected frame, the returned tracker result is good, and resulting pose matches input. Prefer an appropriate upstream non-relocalizing failure mode plus these checks. No tracking-failure frame may be silently integrated or omitted. Freeze the chosen setting before run.
5. Explicit fixed configuration: voxel 4 cm, TSDF truncation 20 cm, 0<depth<4 m adapter mask, no bilateral filter, no swapping, no learned/hybrid tracking or relocalization. Maximum-weight behavior stays recorded upstream default. This is fixed-pose fusion under supplied poses, not loop-closure or SLAM testing.
6. [File tracker](https://github.com/victorprad/InfiniTAM/blob/4156547e7f118c3a303d0b3c20f4da2aa3bfc9c9/InfiniTAM/ITMLib/Trackers/Interface/ITMFileBasedTracker.h) does not require point-cloud/colour rendering. [Tracking controller](https://github.com/victorprad/InfiniTAM/blob/4156547e7f118c3a303d0b3c20f4da2aa3bfc9c9/InfiniTAM/ITMLib/Core/ITMTrackingController.h) consequently returns before tracking raycast preparation. We do not need to build a new renderer, and do not modify native fusion.
7. After integration, call released CPU marching cubes with an explicit `ITMMesh(MEMORYDEVICE_CPU, 2000000)` buffer rather than `SaveSceneToMesh`'s 4.5-GiB default. This allocates about 72 MB when Triangle has the expected 36-byte layout; assert `sizeof` at runtime. If native count reaches cap−1, abort as possible truncation; never score that mesh. Check voxel/hash allocator capacity each frame and abort on exhaustion rather than reporting skipped allocation as valid reconstruction.
8. Export native mesh to OBJ/STL or lossless PLY adapter. Preserve unedited coordinates; use the existing common evaluator in a separate process, not a tiny custom renderer. All 29 heldout rays and missing-hit categories remain unchanged. A small capped mesh buffer is not mesh simplification.

## Requested reservation (caps, not expected measurements)

| Stage/resource | Proposed limit |
|---|---:|
| Concurrent CPU workers | 1; `make -j1`, OMP/OpenBLAS threads 1 |
| New network | 25 MiB official source only; no dependency installs |
| New disk | 1.5 GiB including raw depth/build/output, excluding existing read-only inputs |
| Build + fixtures | 20 minutes, 2 GiB process-tree RSS stop |
| Full 265-frame fusion + meshing | 30 minutes, 2 GiB process-tree RSS stop |
| Existing common evaluator | 10 minutes, 3 GiB process-tree RSS stop; run after fusion exits |
| Mesh triangle capacity | 2,000,000; reject saturation, do not silently grow |

These are conservative initial **abort bounds**; no build/runtime/peak size has been measured. Source fixed voxel storage alone is approximately 512 MiB with the ordinary 4-byte default voxel layout, plus hashes/images/tracking buffers. If the fixed source pool or 2-million-triangle buffer cannot represent this room within these bounds, record resource-inconclusive, not geometry failure. Any expansion needs a new decision; don't shrink the room, alter heldout set or delete surfaces to fit.

Before full execution: synthetic known-plane, missing/4-m depth, asymmetric K, changing-K, rotation+translation, native file-pose loading, fixed-pose preservation and forced-capacity-failure fixtures. Then a fixed small prefix of training frames to check memory/export plumbing only. No reference results guide smoke acceptance or thresholds. Freeze adapter/source/config/data hashes after the plumbing passes and before the 265-frame run. Reuse existing reference evaluator arrays only if their complete ray/pose/registration contract and hash match; otherwise separately account for the query budget.

## Private test versus publication: conditional license scope

The [pinned license](https://github.com/victorprad/InfiniTAM/blob/4156547e7f118c3a303d0b3c20f4da2aa3bfc9c9/LICENSE) offers noncommercial use and contains no separate requirement in its text to notify Isis **before every private noncommercial run**. That is a source reading, not a legal determination that this user or experiment is eligible. The project's stated free core is recorded; do not infer paid/commercial intent, nor assume future intent is settled. Commercial-purpose research is expressly included in its restriction even before a sale exists. The earlier report quotes the relevant phrase.

A private eligible noncommercial experiment and publishing its outputs are different actions. Results/data publication requires prominent software attribution, copyright and licensed-source statement, and providing a copy to Isis. That external communication requires the user's specific authorization; none was made. Redistribution of upstream/modified code also has separate source-inclusion and license-passing conditions. Avoid vendoring upstream code into our public product repository by default, but do not claim that avoiding redistribution removes use restrictions. No generated result is to be published while applicable obligations are unresolved.

**Decision requested of root, not executed:** after RTAB result, decide whether the incremental fixed-pose TSDF comparison is worth this bounded budget and resolve license scope/publication handling with the user. If not, retain this as a concrete source-learning candidate, not an unsuccessful benchmark or GPU-incompatible method.
