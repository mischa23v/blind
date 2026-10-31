# Organized-cloud export fix: independent source review

2026-10-28. This review is source inspection and bounded pose-array checks, not a replay of the mapper or an independent geometry evaluation.

## Finding

The original exporter called `voxelize(worldCloud, .04)` without valid indices. Official pinned RTAB source `corelib/src/util3d_filtering.cpp`, `voxelizeImpl`, line777 only processes either a dense nonempty cloud or a non-dense cloud with nonempty indices. Lines851–853 explicitly return an empty cloud for the latter with omitted indices. A depth image cloud is organized/non-dense because zero/out-of-range pixels are invalid. Thus the initial failure is an **adapter export defect**, not evidence of an empty room or failure to reconstruct geometry.

## Correct repair

`cloudRGBFromSensorData(data,1,4,0,valid.get())` supplies the native valid indices. Pass those unchanged into `voxelize(world,valid,.04)`. Official `cloudRGBFromSensorData` lines1337–1343 copies the one-camera cloud's native index vector; no custom pixel classification is introduced. Official `transformPointCloud` overload at util3d_transforms.cpp129–138 calls PCL's all-point transform and preserves indexing. The new read-only DB exporter uses `openConnection(path,false,true)` as declared in DBDriver.h; it reads each node's saved images/calibration rather than replaying mapping.

The saved POSES.tsv contains optical camera-to-original-phone-world. Native depth cloud conversion already applies the stored camera local transform O. Exporter applies `opticalPose * inverse(O)` to that cloud, so the result equals the original intended `B * nodePose` transformation. There is no new FARO transform or pose correction here.

Existing first eight calibrated-depth, units, zero/overrange, exact4m, RGB/BGR, asymmetric-intrinsic and transform fixtures must remain. The added regression must reproduce the omitted-index empty result and verify the repaired result; reviewer additionally requested exact14 native-valid pixels in the16pixel fixture, exclusion of0/5, retention of15 at4m, finite output and a nonidentity camera-local-transform cancellation test. Runtime pass/fail must come from retained new worker logs, not this static review.

Retain original failed stage receipts. An export-only success is not an original end-to-end exit0; the truthful record is successful saved mapping state, failed original export, then corrected DB-only export. Preserve parameters and thresholds, and pin repaired source/binary and DB/pose inputs. No geometry score was used to select this repair.

## Graph coordinate gauge

`GRAPH_GAUGE_REVIEW.json` hashes and checks all265fixed and265graph rows against INPUTS.tsv. All IDs are ordered1..265 and unique. Maximum fixed-to-supplied matrix element error5.103950641641153e-7. First graph pose times inverse supplied first pose has max identity residual1.73411261350509e-7, and its translation equals the fixed anchor exactly. No additional gauge alignment is indicated or applied. Native default RGBD/OptimizeFromGraphEnd=false is consistent with preserving the oldest node. Graph nonanchor shifts (median0.142584m/max0.410540m translation) are optimization changes, not evidence that geometry improved.

## Retained worker regression evidence

The strengthened worker log `fresh-run/logs/native-fixtures9-strengthened.log` reports `FIXTURES_PASSED 9`, and its resource receipt reports exit0. Source inspection confirms exact14 valid-index/count checks and nonidentity stored-local-transform cancellation for all14points. This is reviewed worker execution evidence, not a second independent native execution. Its very short run yielded sampled RSS0 in the monitor; that is not evidence of zero memory consumption. Export POSES files were independently checked for265unique IDs. The current standalone exporter does not itself reject duplicate IDs, but the exact consumed input files were verified; do not claim a general duplicate-input guard.
