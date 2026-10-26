# Koivu fixed-section diagnostic — addendum v1

This addendum contains one completed, evaluator-only comparison. It adds no map changes, route queries, new reference queries, or physical clearance claim.

## Frozen section and result

The section is anchored at original recorded camera **frame 39**, source XY **[-3.455317, 2.836569] m**, in the previously disputed passage. Its direction is perpendicular to camera displacement from frames **38 to 40**; the segment extends **2 m each way**. This new fixed diagnostic was selected before inspecting its reference-column results, not optimized to find a favorable width. The camera displacement is a local direction proxy, not a verified aisle axis.

Both results use the **same segment and 5 cm source grid**, traversed by exact raster-edge intersections. No native-planner erosion is applied.

| Model | Relevant contiguous interval |
|---|---:|
| Supplied phone permissive-walk mask | **0.686 m** |
| Saved independent-reference vertex-column proxy | **1.222 m** |

The reference proxy interval contains the camera anchor. The phone interval does not: it ends **7.16 cm before** that anchor. These are discretized model intervals, not millimetre-precision physical measurements. All other intervals, including section-end-clipped intervals, are retained in `RESULT.json`; no smaller disconnected runs have been silently merged.

## Why this is not physical gap clearance

The reference proxy requires vertex coverage, a finite floor sample, and no vertices in **[0.015, 0.30) m** or **[0.30, 1.80) m** above the saved global plane. Floor samples use the open band **(-0.06, +0.06) m**. These are saved vertex-column summaries, **not triangle intersection or continuous-volume tests**. Missing vertices do not prove observed free space. The reference includes cleaned/completed geometry and a different capture time; global-plane registration can place floor vertices in the low band.

The camera is not a body centre. No semantic wall/chair/table boundaries or exact pair of photo edges were identified. This section is consistent with the disputed region, but it is **not a measurement of the exact user-indicated photo gap**. A single section proves neither corridor traversability nor a complete loop.

The generated plot uses **game X = source X; game Z = -source Y**. White indicates the corresponding model proxy, not certified free space. The retained plot was visually inspected. No screenshots or private participant attributes are included.

## Files and provenance

Original bytes are preserved under `workspaces/blind-split-candidate-game-03/fixed-cross-section-12/`:
- `measure_section.py`: executed comparison source.
- `plot_section.py`: executed plot source.
- `RESULT.json`: exact saved numerical receipt, per-cell evidence, input hashes and measurement-source hash.
- `FIXED_SECTION_GAME_XZ.png`: inspected generated plot.

`PUBLICATION_RECEIPT.json` records byte identity against those original artifacts. `MANIFEST.json` records payload hashes. Packaging did **not rerun** either scientific or plotting script. No remote write was performed by this packaging step.

## Required external inputs / rerun boundary

The input files are **not bundled**. Preserve the paths under `workspaces/` listed in `EXTERNAL_INPUTS.json`, and verify their SHA256 values before a rerun. The metadata archive supplies the saved independent-reference columns; the mask archive supplies phone classification; the original transformations JSON supplies camera poses. Python, NumPy and Matplotlib are required. Run the scripts from their retained directory hierarchy; the scripts resolve relative paths through `__file__`.

This is an addendum, not a self-contained raw-data release. External-input availability, source-data licensing and reference acquisition provenance remain those of the original MuSHRoom Koivu sources and prior diagnostic publications.
