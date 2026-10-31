# Export repair: actual mapper retained, no replay

The frozen full RTAB-Map fixed and graph runs each accepted all265 training frames and returned265 poses/native local-grid records. Both combined executable invocations ended exit2 at `nonempty enginecloud`. This was not evidence of an empty room.

Root cause: the adapter passed an organized, non-dense depth cloud to native `voxelize(cloud,0.04)` without valid indices. Released util3d_filtering.cpp:777 requires either a dense nonempty cloud or a non-dense cloud with nonempty supplied indices; the no-index overload supplies an empty vector. The original input/projection fixtures did not cover this API precondition.

The first export-only attempt read saved RGB/depth/calibration successfully using released DBDriver read-only but reproduced the same omitted-index failure. The correction asks released cloudRGBFromSensorData for its native valid indices and passes them unchanged to released voxelize. Neither map generation nor its poses/classification/thresholds were changed or replayed. The saved database poses were used without alignment or FARO access. Export cancels the stored camera local transform exactly once (`opticalPose * localTransform.inverse()`) because the native cloud decoder already applies it.

Both repaired exports succeeded: fixed693573 points; graph813869 points. All265 IDs are unique and cover1..265. Frozen original binary, input hashes and failed receipts remain. EXPORT_FIX_FREEZE.json pins the database/poses/newexporter before repaired exports.

The original8 native fixtures remain archived. Strengthened ninth regression reproduces the omitted-index empty result, verifies exactly14 native valid indices (excluding invalid0/5, retaining inclusive4m index15), all14 finite transformed/voxelized points, and nonidentity optical local-transform cancellation with unchanged indices. It passed in the actual compiled runtime.

This verifies the export repair, not obstacle recall, clear-space support, path safety or device readiness. Grid/RayTracing=false and noOctoMap compiled: there is no3Dfree-space-clearing evidence in these runs. The graph arm reported45 loop-closure event frames; its pose changes are not independently accurate until reference comparison. Native maxDepth4 admits50544 exactly4000mm pixel observations across the training input, unlike Open3D's exclusive4m cutoff; this known boundary difference is disclosed, not tuned.
