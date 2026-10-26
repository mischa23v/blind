# Fixed western-column raw depth diagnostic

Read-only, no new map, no routes, no independent reference input. All 294 original pose-matched processed depth PNGs, source sampling and +0.5 pixel convention from the supplied pipeline. Same supplied global R/t. All 71 camera-frame ROI records deduplicated by cell, including walkable controls; no new selection after residual outcomes. Original raw endpoints and source frame/pixel/depth retained locally.

Report counts and height/range distributions by original cell flags, per frame, and within the source near radius <=2 m; no small-object/floor truth inferred. Source uses ONE global floor plane and fixed 5 cm voxel bands, not local terrain. Frame offsets affect separate statistics, not supplied split walk. Endpoint binning is not reconstruction of native occupancy probabilities. Missing confidence/tracking remain unavailable. Native Float32 XY boundary changes counted separately, not used to relabel cells.

Measured endpoint exemplars: at most three distinct frames per cell/category (floor, 2.5–7.5 cm low band, other), ordered by shortest actual camera range. These diagnose original measurements, not independently verified hazards. No visualization changes sensor values.

Bound: 120 CPU / 180 wall seconds, 768 MiB sampled/waited RSS, 16 MiB outputs, preserve 768 MiB disk. Serial after active reference comparator. No dependencies/build/install. Pin all source/data before and after; all failures retained.
