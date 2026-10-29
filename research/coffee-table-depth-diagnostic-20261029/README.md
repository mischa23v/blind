# Coffee: processed depth retains table-surface evidence missing from source-mesh neighborhoods

**Targeted recorded-data diagnosis, not a reconstructed path or physical clearance result.** Source: Xuqian Ren et al., [MuSHRoom iPhone Basic Data](https://zenodo.org/records/10230733), CC BY4.0. No network transfer, dependency install, mapper/native rerun, mesh fitting/edit or raw-photo publication.

## Preselection and retained inputs

Selected three views from the already frozen24-frame sample: original frame00290,00357,00391. Actual RGB images were inspected first. Inset tabletop and nearby visible-floor rectangles were frozen in `PATCH_SELECTION.json` **before any corresponding depth raster was opened**; SHA256`7e938424d28ae9b3a64480c2629aacd422a75d00cb8087cbfc0724fd99b81497`. No patch or frame was replaced after seeing depth.

`extract_depth.py` verified the retained183,080,957-byte archive SHA256`591672a1c4afa50e5109fc78ff08d8f608d05756a9181cfdd7cef38a57a1623d`, then safely selected only the three exact regular depthPNG members. Additional retained bytes631,495 (<10MB), network0. Exact member/hash receipts in EXTRACTION.json. Originals remain untouched and local; no image/depth arrays are included in this packet. Executed source is preserved, with logical sibling artifact paths instead of machine-specific paths.

## Verified processing contract and remaining unknowns

- All three RGB files and processed depth rasters are738×994, matching the original per-frame `w/h`; depth isuint16. RGB EXIF does not require rotation. No raster rotation, flip, resize or upsampling was applied by this diagnostic.
- Use original per-frame `fl_x/fl_y/cx/cy`, not shared guessed intrinsics. Decode1000units/metre. This follows the published Coffee W6 source's direct `/1000` and shape/intrinsic checks: [comparison.py](https://github.com/mischa23v/blind/blob/c79fbd33171f78608f9eb2a1484fbc9266e3a695/research/coffee-w6-plane-comparison-20261029/source/comparison.py). Its [source limitations](https://github.com/mischa23v/blind/blob/c79fbd33171f78608f9eb2a1484fbc9266e3a695/research/coffee-w6-plane-comparison-20261029/README.md) remain applicable.
- Camera-local backprojection only: `(u−cx)z/fx,(v−cy)z/fy,z`, withxright/ydown/zforward and integer export pixels. No camera-to-world pose, OpenGL conversion, mesh registration or source-axis alignment is used or inferred here.
- These are **processed, registered export rasters**, not native independent LiDAR samples. Original upsampling/filter details, synchronization, calibration uncertainty, tracking and confidence streams are not established by saved inputs. Matching shapes and per-frameK do not independently verify those properties. Do not promote pixel count to independent measurement count.

## Results: selected tabletop pixels are not missing or floor-like in this diagnostic

| Frame | Tabletop pixels / zeros | Table depth min–max (m) | Floor patch median depth (m) | Median signed table-point distance to locally fitted floor plane (m) | Table/floor normal angle |
|---|---:|---:|---:|---:|---:|
|00290|5,000 /0|1.483–1.730|2.550|+0.650|1.26°|
|00357|2,100 /0|2.366–2.678|3.288|+0.631|1.78°|
|00391|4,000 /0|1.590–1.786|2.812|+0.621|5.34°|

Every tabletop pixel is positive and below the historical4m truncation. Local planes use existing NumPy SVD/least-squares geometry on every positive<4m point at fixed4-pixel stride, no outlier removal or retuning. Plane fit residuals, singular values, sample counts, full distributions and exact per-frameK are retained in DEPTH_DIAGNOSTIC.json. Extrapolated floor-ray depth is substantially farther than the observed tabletop-ray depth in all three patches.

The signed separations are **diagnostic small-patch plane comparisons**, not surveyed table heights, table dimensions, measured floor truth or navigation authority. The floor plane is extrapolated outside its observed patch; calibration/processing, reflective material and local fit uncertainty remain. Three views from one processed capture are not three independent sensor validations. Similar plane normals/separation do not certify every tabletop pixel or all table surfaces.

## Interpretation for real paths

This evidence argues against explaining the source-mesh gap as “the depth export never saw the tables.” These three RGB-selected regions have distinct nearer, approximately planar processed-depth returns consistent with visible tabletop surfaces rather than missing/through-floor readings. The original source mesh nevertheless lacks broad mid-height triangles in the separately checked source-space neighborhoods.

**The exact loss stage remains undiagnosed:** original Polycam mesh generation/export and the published processed-depth stream need not share an identical fusion history; mesh-camera registration is still absent. No cross-view or mesh alignment was fitted here. Do not assert a particular mesher bug, trust complete table coverage, or insert a guessed table plane into planning.

Continue path debugging with unchanged outcomes, and next trace the table observations through a documented reconstruction/registration pipeline. A same-incomplete-mesh collision pass cannot resolve missing obstacles. Registered independent/source evidence is needed before calling routes table-clear; photos are now only issue-localizing evidence, not a gallery milestone.

## Reproduction

Stage logical sibling `coffee-recovered-source/transformations.json` and `coffee-semantic-coverage/` containing the verified archive and selected originalRGB. In a fresh local directory containing PATCH_SELECTION.json, run `extract_depth.py` once (refuses existing depth files), then `diagnose.py`. Both are bounded30CPU/512MiB; no source data downloaded. Results include executed-source hashes. Reproduction requires the same source bytes and annotations; do not silently substitute different frames. Root owns publication/admission; files are not an instruction to rerun without scope approval.
