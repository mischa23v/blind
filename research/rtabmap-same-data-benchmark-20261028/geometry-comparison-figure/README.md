# Same-data geometry comparison — display only

`geometry-comparison.png` shows existing Open3D 4 m TSDF-derived samples, RTAB fixed-pose samples, RTAB graph-pose samples, and the shared 29-view FARO reference samples. It is **not a route, occupancy, floor-support, clearance or safety map**. No new reconstruction or reference scoring was performed.

## What the picture can establish

All panels use the **unchanged saved FARO metric coordinates**. The original author phone-to-FARO similarity was already applied once by the common evaluator; this renderer applies no transform at all, no additional scale, no recentering and no registration fit. The same projections and bounds make differences in reconstructed surface extent and shape directly inspectable. The graph output's broader low-Z spread is visible; this picture does not establish the cause or classify those points as floor or obstacles. Denser/darker panels are not necessarily better or worse: point counts and upstream representations differ substantially.

These are XY, XZ and YZ coordinate projections, **not labelled top-down or gravity-aligned elevations**. The source `fresh-run/PROTOCOL.md` explicitly records unavailable gravity/tracking metadata. Camera OpenGL convention does not establish world gravity. No plane was fitted to infer it. Colour encodes FARO Z coordinate, not independently verified height above a floor.

Every saved surface point is eligible; there is no height band, obstacle filter, residual cutoff, cleaning, outlier rejection, or clipping to a room mask. Display-only deterministic `array[::4]` selects every fourth stored sample. There is no random draw and no density-dependent resampling. This omits approximately 75% **only for rendering**, does not modify any scored array, and may make small structures disappear in the picture. Exact counts are in `RENDER_RECEIPT.json`. Transparent points can visually overlap; gaps or pale regions are not verified free space, and dark regions are not verified obstacles. Full-height projected surfaces overlap, so the figure cannot prove passage width or a traversable path.

## Coordinate bounds and sources

Shared FARO bounds: X [-6.5, 5.0] m; Y [-6.5, 6.5] m; Z [-1.0, 3.5] m. Bounds are the union of all full arrays rounded outwards to half-metre boundaries; no source points were excluded by the bounds. Each row has matching equal-aspect axes. All panels use the same colour limits, point size, alpha, and subsampling rule.

Source directory: `../fresh-run/common-surface-reader-fixed/`:
- `open3d.npz`, `fixed.npz`, `graph.npz`: `pointsFaroMetres`.
- `reference_samples_faro_metres.npy`: unchanged common reference samples.

The NPZ sources already use the frozen common 4 cm actual-point selection rule. RTAB native clouds previously underwent centroid voxelization; Open3D is sampled from a TSDF mesh. A common final grid does not erase that difference. FARO reference samples cover only 29 held-out views, not the entire reference mesh. Missing reference returns are not free space. See `../common-surface-proposal/PROTOCOL.md` and the completed `RESULT.json` for the measurement contract and limitations; this figure makes no additional accuracy or safety claim.

## Reproduction and review

Run `nice -n 19 python render.py`. Uses existing NumPy/matplotlib only, with numerical libraries forced to one thread. Does not load original meshes, images, the large FARO mesh, or run geometric reconstruction/query libraries. Exact source SHA-256, script SHA-256, PNG SHA-256, bounds, counts, colour bounds and render parameters are in `RENDER_RECEIPT.json`. The final PNG was inspected visually for labels, shared coordinate bounds, readable panels, and missing/cropped content. No GitHub or user-facing upload performed by this task.
