# Corrected world-Z-up RTAB-Map + native OctoMap: completed geometry experiment

Completed 2026-10-28 19:00 UTC, inside the existing 19:08:24 stage deadline. This is an offline geometry experiment, not a navigation, collision, stair, toy-detection, child-use or device-safety pass.

## Useful result

All 265 original training RGB/depth frames were accepted by the corrected fixed-pose released RTAB-Map mapper. All 265 saved, regenerated local grids were then replayed through released `LocalGridCache -> OctoMap::update`, with native ray clearing enabled. The frozen reference geometry evaluation completed with zero invalid queries. No custom floor fit, threshold sweep, manual corridor carving, image-based obstacle removal or FARO mapping input was used.

| Same common geometry metric | Prior RTAB fixed cloud | New Z-up native OctoMap endpoints |
|---|---:|---:|
| Forward median to original reference triangles | 6.64 cm | **4.19 cm** |
| Forward mean | 12.84 cm | **9.50 cm** |
| Forward 95th percentile | 48.28 cm | **43.25 cm** |
| Reverse reference median to sampled output | **2.19 cm** | 2.47 cm |
| Reverse 95th percentile | **5.03 cm** | 6.19 cm |
| Reference samples within 5 cm | **94.92%** | 90.84% |

The new output improves forward geometric agreement but loses reverse coverage relative to the denser fixed sensor cloud. This is not an overall winner. The comparison combines corrected gravity-sensitive classification and occupancy filtering; it does not isolate the individual benefit of the world correction. A cloud of retained occupied reference endpoints is not the same representation as a raw sensor cloud or a reconstructed triangle mesh. Nearest-surface distance can hide wrong occlusions and is not hazard recall or proof of a clear path.

## Native occupancy output

- 2,268,956 observed leaf records.
- 325,714 occupied: 63,720 native-ground classified; 261,994 other occupied.
- 1,943,242 observed-free leaves; unrepresented space remains unknown, not free.
- 325,714 native occupied reference endpoints; 247,832 representatives after the unchanged 4 cm common sampling.
- Identical 127,774 FARO reference samples and SHA-256 `55ece9f280595f12dc02644588d69d7f6ef71ffa7a8456d25102a7e96eb066e0` as the prior completed comparison.
- 174,769 currently free leaves retain historical obstacle type; 17,686 retain historical ground type. This empirically confirms why occupancy probability/flag, not historical type or node ID, must determine occupied/free state.

Ground endpoints are native occupied-ground classifications, **not verified supporting floor**. Native `.ot` serialization does not preserve RTAB custom semantic fields; the explicit `leaves_dataset_world.bin` ledger and category indices preserve those fields separately. `ZUP_LEAF_FORMAT.json` is the schema for this corrected arm; the older `LEAF_FORMAT.json` belongs to the preserved unexecuted original-frame plan.

## Why a new arm was necessary

MuSHRoom's bundled processing contract says processed WORLD +Z up, separately from OpenGL CAMERA +Y up. The old adapter left-multiplied a world-axis conversion A and cancelled it on cloud export; point positions roundtripped, but ground classification operated in the wrong gravity frame under that contract. This arm uses `nodePose = P * O.inverse()`, where O is released `CameraModel::opticalRotation`, with no A/B world rotation. It regenerated local grids from the original images rather than rotating old semantic labels. The original capture gravity stream/exporter receipt is unavailable; this honors the documented format contract, not a measured gravity calibration.

Native world-plane fixture passed before recorded data: 400 floor points classified ground, zero obstacle. Existing native hit/free/unknown/head-height/duplicate and coordinate fixtures passed. `ZUP_PRE_RUN_FREEZE.json` pins source, binaries and inputs before the corrected replay.

## Interruption recovery, not a hidden rerun

The environment interrupted the corrected mapper during its post-mapping cloud export. Its log ended after frame 265; the original partial pose export has 54 lines, local-grid count file was empty, and the original final mapper/resource receipts were absent. Those partial files were preserved.

The saved DB passed SQLite quick_check and contains all 265 nodes and all 265 RGB, depth, ground and obstacle records. `recover_zup.py` reads its saved node poses read-only, converts with the released optical rotation, and checks **every** pose against frozen input. Maximum absolute discrepancy is 3.2782554626464844e-7. Recovered complete poses are separate `RECOVERED_POSES.tsv`; no input mapping was rerun. The occupancy adapter then opened this DB read-only. No old wrong-world cached grids were reused.

No matching worker was visible in the current process namespace, and the old log remained unchanged across inspection. Host-wide process absence could not be established from the isolated namespace. A conservative 420 CPU-second charge is included for interrupted mapping/export, in addition to the earlier 180-second build-interruption charge. Actual interrupted-run peak memory and final CPU usage are unavailable and are not represented as measured.

Native occupancy replay: 36.22 s elapsed, 35.90 CPU s, 358,637,568 B sampled peak process-tree RSS. Common scoring: 36.28 s elapsed, 35.31 CPU s, 2,261,356,544 B peak. Aggregate charged stage CPU: 1,409.17 s of 2,100 s. Each resumed heavy stage used one CPU under the existing wall/disk/RSS supervisor, with no new dependencies/downloads for this recovery.

## Checks and remaining work

`ZUP_OUTPUT_CHECKS.json` passes all 15 checks: every leaf's finite values and occupancy threshold, exact category indices, all 265 replay records, only `Grid/RayTracing=false -> true` changed for global occupancy, identical reference sample hash/count and numerical summaries reconstructed from saved arrays. These are worker checks; independent review is separate.

Not done here: full raw-cloud export of the interrupted corrected mapper, isolated coordinate-only comparison, full-body routes, collision/low-object recall scoring, incremental live localization, moving obstacles, unknown floor-support validation or an iPhone runtime trial. No app integration or movement authorization follows from this result. Use the completed probability/semantic ledger to investigate classification and support before claiming traversability.
