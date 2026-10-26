# Independent mapping audit — Koivu phone-only maps (2026-10-26)

**Verdict: the mapping implementation is wrong in specific, measurable ways and also over-conservative. Its failure is not evidence that the iPhone depth hardware is inadequate.** After correcting the floor/support logic with the released OctoMap engine, the same recording yields connected full-body space and complete Recast/Detour routes, but only short ones at the current body margin. **Zero of the 100 game episodes were run.** Arrivals, collisions, stops and invalid starts are unmeasured, not zero. Nothing here is live-device or physical-safety evidence. The FARO reference was not given to any planner and was not used at all in this audit.

Inputs: release `navigation-test-data-20261026`, `koivu_iphone.tar.gz` (sha256 `68735cfa…6518`), all 294 pose-listed depth frames (hashes match the v1 manifest 294/294). Map numbers are in `RESULTS.json`. Scripts are in `scripts/`, and top-down views are in `figures/`. **The recommended correct approach is in [`CORRECT_APPROACH.md`](CORRECT_APPROACH.md).** Small derived map files with checksums are in `derived/`: the all-range OctoMap `.bt`, the near-tier and policy-D1 column arrays, and the level-frame transform. They are derived from the public CC BY 4.0 MuSHRoom data (Xuqian Ren et al., doi:10.5281/zenodo.10230733), and contain geometry only. The figures show colour-coded map classes and camera positions only, no RGB.

## 1. What was checked and found correct

| Item | Result |
|---|---|
| Depth units | uint16 millimetres; 0.919–6.44 m; no zero pixels |
| Axial vs range depth | Axial (as implemented) is right. Single-frame floor fits: residual 1.87 vs 2.39 cm, curvature 0.007 vs 0.030 for a range interpretation |
| Intrinsics / pixel centre | Half-pixel OpenGL projection is consistent. Pixel vs LiDAR-block-centre ray differs ≤1.5 px (~0.5 cm at 3 m), so it is not a cause |
| Pose direction / axes | OpenGL camera-to-world, +Z up (gravity). Measured floor tilt is **0.05°** |
| Frame association | `depth_file_path` ↔ pose entries match for all 294 frames |
| v1 reproduction | Rerun from released data gives **identical counts**; `SURFACE.json` is **byte-identical**; NPZ differs by ≤1.8e-15 m. The only deviation was re-pinning the path-normalized `MAP_PROTOCOL.md` text |

There is one input fact the pipelines ignore. The depth PNGs are **4× nearest-neighbour upscales of the 256×192 LiDAR map, cropped 15 px**. The 215,670,168 "endpoints" are really 13,415,808 independent measurements, each repeated about 16 times. Hit counts, "≥2 frames" and per-voxel extremes therefore overstate the evidence. All analyses below use one ray per LiDAR sample, through the block centre.

## 2. What is wrong (ranked by measured impact)

**A. The floor rule turns the floor into an obstacle (v1, and inherited unchanged by v2). This is the primary cause.**
- **How it works:** a voxel is "ground" only if *every* hit in it lies within ±3 cm, and "obstacle" if *any* hit is above +3 cm. The test takes the min/max over hundreds to thousands of hits, so the result is driven by the noise tail, and more data makes it worse.
- **Measured floor dispersion, by range (p95 / p99):**
  - 0–1.5 m: 1.7 / 4.8 cm
  - 1.5–2.5 m: 5.3 / 8.4 cm
  - 2.5–4.5 m: 7–8 / 9–10 cm
  - Per-frame vertical offsets are ±1 cm, with two bursts up to 3.5 cm (frames 60–69 and 116–119).
- **Effect on v1:** 16,619 of 22,668 voxels in the 0–5 cm floor layer became obstacles. Another 7,768 floor voxels in the −5–0 cm layer became "below-floor contradictions". Support also needs all four quadrants clean, so only 2,637 cells remained.
- **Effect on v2:** v2 kept these rules. 15,650 floor-layer voxels, whose hits never exceed about 5 cm, remain occupied obstacles, because OctoMap correctly says the floor is occupied. They alone block 1,365 surface cells. Support stayed at 2,637.
- **Result:** the pinned Recast builds **no walkable polygons** from the v2 surface **even at the bare 0.27 m body circle**. v2 fails at mapping, before body size matters.

**B. Below-floor "drop" evidence is long-range noise.**
- With all ranges, layer −1 (2.5–7.5 cm below the plane) is occupied in 9,446 supported columns. With beams ≤2 m only, it is 463.
- Deeper layers (≥7.5 cm below) are occupied in only 235 columns.
- Purple "below" regions have the same median floor height as walkable ones, so they are not real dips or drift.
- Fix: drop detection must use range-appropriate precision, not one band for all ranges.

**C. The body is enlarged twice.**
- The 0.45 × 0.30 m rectangle already has a yaw-independent circumradius of **0.2704 m**.
- `game_model.py` then multiplies by √2 (0.3824), adds the 0.15 margin (0.5324) and rounds up to 10 cm cells: **0.60 m Recast erosion**.
- The √2 step has no geometric justification for this rectangle. Removing it keeps the person's size; the margin remains a separate policy choice. See section 4 for its effect.

**D. Permanent single hits (v1 only).** OctoMap fusion correctly fixes this. It was not the dominant blocker.

**E. Not material here (measured, so they need not be chased further):**
- **Ray reduction.** Inserting one ray per endpoint voxel instead of all rays gives 5,826 vs 5,738 walkable columns.
- **Quantized floor fit.** It is a weak method, and it can collapse residuals and force zero tilt. But in this recording it lands at −1.275 m against a measured −1.272 m.

## 3. Smallest evidence-backed fix tried ("policy D1", diagnostic, not frozen)

Released OctoMap 1.10 with default sensor model, 5 cm voxels, LiDAR-native rays and a measured level plane. The plane is placed at the centre of voxel layer 0, so layer k spans k·5 ± 2.5 cm. Two trees are built: all ranges, and beams ≤2.0 m (OctoMap `maxrange`). Rules:
- **Support:** layer 0 occupied (floor seen).
- **Blocked** if any of:
  - fused occupancy ≥7.5 cm below the plane at any range;
  - near-range occupancy 2.5–7.5 cm below;
  - layer +1 (2.5–7.5 cm) occupied near, or occupied far unless near-range says free;
  - layer +1 unknown to both trees;
  - any occupancy from 7.5 cm to 1.775 m in either tree;
  - anything unknown in that body band in both trees.
- Raw evidence is untouched. Isolated multi-frame specks (104 columns, never single-frame, median 3.5 frames) are **kept**.

Results:
- **Walkable columns:** 10,669 (26.7 m²), versus 1 cell in v1 and none Recast could use in v2.
  - 7,012 of them carry a **low-band-unresolved** flag. Their 2.5–7.5 cm band is judged only from beyond 2 m, where floor noise is 5–8 cm, and these flags must not be read as clearance.
- **Full-body centres and connectivity:**

| Planner radius | Full-body centres | Largest connected extent | Detour complete routes (seeded endpoints) | Longest route |
|---|---:|---:|---:|---:|
| 0.2704 (body circle, no margin) | 1,645 | 6.9 m | 602 / 1,560 | 5.8 m |
| 0.3704 (+0.10 margin) | 642 | 5.7 m | 510 / 1,560 | 2.6 m |
| 0.4204 (+0.15 margin, single bound) | 365 | 1.7 m | 614 / 1,560 | 1.35 m |
| 0.5324 / 0.60 (current) | 35 / 5 | 0.5 / 0.1 m | — | 0.4 m |

  Connectivity collapses between radius 0.37 and 0.39. The aisles of this furnished room are the binding constraint once the floor is fixed.
- **Retention fixture.** Noise-free 10×10 cm boxes, 4 cm and 8 cm tall, were rendered into the *real recorded rays* in both near-observed and far-only aisle zones. After re-fusion, **all four were blocked (9/9 columns each)**. This shows the corrected rules do not erase such objects. It does not show the phone would detect real ones at that size.
- **Declared blind spot:** anything under 2.5 cm sits inside the floor layer and is not separable from floor here. v1's 3 cm band had the same blind spot, larger.

## 4. Decisions for you (not made here)

1. **Margin.** At +0.15 m the longest route in this room is 1.35 m, too short for 20 meaningful route pairs. At +0.10 m it is about 2.6 m. Choose the margin from a measured error budget, not by fitting to routes. The inputs are per-frame offsets of ±1 cm (bursts to 3.5 cm), 5 cm quantization (already conservative because a whole voxel blocks) and reference-scored horizontal error.
   - Alternative that keeps 0.15 m: an orientation-aware footprint. Half-width 0.225 + 0.15 = 0.375 m when walking along an aisle, with the 0.27 m circle only for turning in place. Recast cannot do this; it needs an SE(2) validity check, for example OMPL (BSD) with this map as the collision checker, or an evaluator-side rectangle check on the Detour corridor.
2. **Low-band-unresolved cells.** Either block them (strict; this recording then has little routable area) or allow them with the flag, and have reference scoring report low contacts separately. This is a policy choice. It is not a mapping fix and should not be hidden inside one.

## 5. Released baselines

| Component | Source / version / license | Status here |
|---|---|---|
| OctoMap | github.com/OctoMap/octomap v1.10.0, commit `007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f`, BSD-3. Python wheel `octomap-python==1.10.0.0` (github.com/wkentaro/octomap-python, BSD-3) | **Run** (`scripts/m2_octomap.py`, about 40 s, 13.4 M rays) |
| Recast/Detour | github.com/recastnavigation/recastnavigation `9f4ce64458dfae86e1239c525ddc219c4e9e06f1`, Zlib (vendored in `tools/navigation-recast`) | **Run**: rebuilt with g++ 13.3, 12/12 adapter tests, routes above |
| Open3D TSDF | github.com/isl-org/Open3D v0.19.0, tag commit `1e7b17438687a0b0c1e5a7187321ac7044afe275`, MIT. Wheels cover Python ≤3.12; `open3d-cpu 0.20.0` (104 MB) covers 3.13 | **Not run** (heavy install deferred per AGENTS.md) |
| MuSHRoom code | github.com/TUTvision/MuSHRoom HEAD `3f36dbfe24c783f85e320a613096eee5216839eb` | Checked. `test.txt` lists the 29 held-out frames (265/29 split). **At this commit, Open3D TSDF appears only in `kinect_tools/`. The iPhone path's `ns-export tsdf` integrates depth rendered from a trained model, not raw phone depth.** Ask for the file and line if another session says otherwise. Its license file was not found in the shallow clone; check before reuse |

Open3D comparator recipe (prepared, not executed):
- Use `ScalableTSDFVolume(voxel_length=0.02, sdf_trunc=0.06, color_type=NoColor)`.
- For each training frame, integrate the depth image (`depth_scale=1000`, `depth_trunc=4.0`) with:
  - `PinholeCameraIntrinsic(738, 994, fl_x, fl_y, cx−0.5, cy−0.5)`. The −0.5 converts the half-pixel convention to Open3D's integer-centre projection.
  - `extrinsic = inv(c2w_gl @ diag(1,−1,−1,1))`.
- Expected validation:
  - median absolute depth error rendered at the 29 held-out poses against their measured depth;
  - floor planarity of the mesh;
  - TSDF weight > 0 kept as a separate coverage layer, because a missing triangle or a smoothed surface is not free space;
  - then the same Recast export and body table as section 3, plus the injected-box fixture.

TSDF averaging should narrow the floor (≈σ/√n). It can also smooth away thin or low objects, so the retention fixture is mandatory.

## 6. Untested / next

1. **Freeze a candidate map before any reference scoring.** Write a v3 protocol: policy D1 or a variant, the margin decision and route selection. Do not tune it afterwards.
2. **Reference-score that frozen map (FARO evaluator only):**
   - Are the 104 specks real?
   - How wide are the aisles in reality?
   - Which low objects exist, and does the map hit them?
3. **Then run the 20 × 5 game** with the Swift worker. It cannot run in this container: no Swift toolchain, and Docker is prohibited.
4. **Open3D TSDF comparator** (section 5).

## Reproduce

```
export KOIVU_LONG_CAPTURE=<extracted>/room_datasets/koivu/iphone/long_capture BLIND_REPO=<repo> RECAST_ADAPTER_DIR=<built tools/navigation-recast copy>
python a4.py; python a5.py                     # LiDAR-native samples, floor cells
python m2_octomap.py; python m3_octomap_near.py 2.0; python m3_octomap_near.py 1.5
python policyD.py; python routes.py; python inject.py; python inject_check.py; python discretize.py
```

Run these from one working directory; intermediate `.npy` files are written there. Memory peak was not instrumented. The serial OctoMap insertions took 18–48 s each with 2 OpenMP threads.
