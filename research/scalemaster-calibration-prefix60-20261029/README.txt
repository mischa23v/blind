SCALEMASTER CALIBRATION + PREFIX60 ENGINEERING PRESERVATION

PUBLIC-CANDIDATE TEXT-ONLY PACKET; NOT PUBLISHED BY THIS TASK.
Root remains sole publisher. This preserves authored sources, exact/sanitized
provenance, aggregate engineering results and independent reviews. It contains
NO dataset archives, raw pose CSVs/per-frame trajectories, RGB/depth/confidence
images, pixel masks, geometry arrays/PLY, or private geometry preview.

Completed sequence
1. Original fixed F=diag(1,-1,-1) scale inference was INCONCLUSIVE: no eligible
   aggregate development scale; holdout geometry was not evaluated. Generic
   prior failure labels must not be mistaken for a measured heldout failure.
2. Frozen 24-proper-convention search selected identity C and .001 m/raw unit;
   four development-pair stability/control checks and two once-scored holdouts
   passed the preregistered internal checks. This is INFERRED EXPORT CALIBRATION,
   not documented encoding, independent calibration, or metric accuracy.
3. Fixed Stairs_02 first 60 depth/confidence frames replayed with existing released
   CPU Open3D 0.19: .04 m voxel / .2 m TSDF truncation / 4 m depth limit, NoColor, raw poses,
   and explicit confidence/numeric masks. Native mesh: 9,069 vertices / 16,986 triangles;
   observed endpoint ledger: 726,447 samples in 24,948 cells. Independent recount PASS.

Denominators — do not call these accuracy or room coverage
2,949,120 total raster samples -> 892,660 numeric-valid confidence-2 samples before
range clipping. The fixed 4 m limit removed 166,213, leaving 726,447 eligible samples.
726,447 / 2,949,120 = 24.6326700846% of ALL raster samples.
726,447 / 892,660 = 81.38% approximately of numeric-valid HIGH-CONFIDENCE samples before
range clipping. All 726,447 contract-eligible in-range/high-confidence samples
entered the separate endpoint ledger (100% of that input denominator). This is
NOT a claim every endpoint produced a native TSDF weight/mesh vertex. Counts are
not independent measurements, environment coverage, accuracy or clearance.
See replay/aggregates/MASK_DENOMINATORS.json for exact fractions and partition.

Scope and safety boundaries
Identity C applies specifically to this ScaleMaster export. DO NOT remove the
proper raw ARKit-to-optical conversion in production capture code because of it.
The original diagnostic geometry_assumptions retains historical F; replay uses
its separately pinned SELECTED identity/.001 contract. Exact source K /7.5,
pixel-center association and world_from_recorded_camera pose direction remain
conditional assumptions. World up/gravity direction is unverified; no floor or
stair labels were attached. RGB synchronization remains unresolved and RGB was
not read. Prefix geometry does not establish a whole stair flight or a detector
pass. No independent GT, metric accuracy, safe-floor or navigation claim exists.
Missing/excluded geometry is UNKNOWN, not free floor. Sensor data and all derived
scene geometry remain private. Public download availability did not establish a
dataset redistribution licence; this text-only packet grants none.

Preservation/reproducibility
Historical source/plans retain their original pre-execution wording; saved
results/reviews describe what later ran. Source copies are byte-exact. Original
freezes containing local input paths are represented by sanitized hashes, NOT
runnable replacement manifests. Raw inputs/runtime binaries/dependencies are
not bundled. This packet documents the experiment but is not a self-contained
reproducer. Packaging executed no diagnostic, reconstruction, image decode,
archive extraction, or network request; only authored text/saved aggregate JSON
was read. Frozen prior runs and production code were not modified.
