# Six-point training-observation trace

Post-hoc, bounded diagnostic; no reconstruction/raycast execution or map edits. Existing TSDF first hits are projected into the original 265 training frames. This is not a record of actual TSDF voxel updates, nor a test of physical free space.

## Protocol fixed before depth inspection

`trace_training.py` selects indices `floor(q*(N-1))`, q = 0.25, 0.5, 0.75, from the row-major index lists of the already defined largest frame_00228 residual component (4,166 samples) and the frame_00197 central-floor rectangle (5,328 samples). No re-selection followed the results. The deterministic floor samples happen to lie at the rectangle's right boundary, x=600; they are not spatially representative of the whole floor.

World points use the saved TSDF **axial** depth, the evaluation's integer pixels (no half-pixel offset), exact per-frame intrinsics and supplied OpenGL camera-to-world poses. The inverse training pose yields camera coordinates; positive axial depth is `-camera_z`. Projection uses x-right/y-up/z-back conventions. Nearest integer pixels use `floor(coordinate + 0.5)`; zero or out-of-image samples are excluded with recorded reasons. Original integration discards recorded depth >=4 m, regardless of the projected point's depth. All accepted signed residuals, including occluded points, remain in the results.

The script reads one PNG at a time, keeps only six observations per training frame, hashes depth inputs and performs no fusion or geometry query. Six point coordinates are selected before the loop reads any training depth. Confidence/tracking metadata is unavailable.

## Results

Residual is **recorded depth minus point axial depth**. Positive means the recorded return lies behind the projected point; negative means a nearer return may occlude it. Neither sign alone proves a physical obstruction or free space.

| Source sample pixel | TSDF depth (m) | Admitted depth views | Visible views clipped at 4 m | Admitted residual min / median / max (m) | Views within existing 0.20 m axial band |
|---|---:|---:|---:|---|---:|
| 228 (640,172) | 0.36665 | 5 | 39 | −2.75989 / +0.00280 / +3.27346 | 1 |
| 228 (672,288) | 0.39112 | 4 | 41 | −2.73973 / −1.28060 / +1.93346 | 1 |
| 228 (652,452) | 0.41699 | 6 | 39 | −2.74537 / +1.06626 / +3.00638 | 1 |
| 197 (600,824) | 2.50399 | 52 | 0 | −3.83811 / −2.63416 / +0.00867 | 5 |
| 197 (600,872) | 2.26757 | 51 | 0 | −4.12892 / −2.71318 / +0.01718 | 5 |
| 197 (600,920) | 2.07199 | 50 | 0 | −4.38799 / −2.80557 / +0.01120 | 5 |

The 0.20 m band comes from the already fixed fusion truncation distance; it is an **axial descriptive comparison**, not the exact ray-distance-weighted TSDF update rule or a new correctness threshold. Continuous distributions and every observation are preserved in `TRAINING_TRACE.json`.

### Concrete lead

All three suspect near-surface points have their one near-compatible return in **frame_00074**:

| Point | Training sampled pixel | Point axial depth | Recorded depth | Residual |
|---|---|---:|---:|---:|
| 228 q=.25 | (115,150) | 3.32320 m | 3.326 m | +0.00280 m |
| 228 q=.50 | (111,162) | 3.30875 m | 3.336 m | +0.02725 m |
| 228 q=.75 | (113,183) | 3.32275 m | 3.372 m | +0.04925 m |

Frames 75 and 76 instead report much nearer surfaces at these projections (negative residuals about 2.6–2.8 m), consistent with occlusion. Other admitted frames report surfaces roughly 1.9–3.3 m farther away. Most other visible recorded returns are excluded by the original 4 m integration cutoff. Thus these sampled near-surface points **do have a corresponding original training observation under the supplied poses**; they were not shown to have arisen without any raw depth support. Sparse, conflicting training observations and cutoff behavior are specific leads to inspect before blaming extraction alone.

Floor controls each have five near-compatible observations from frames 136–138 and 195–198 (specific frames differ by point). Many other views see foreground occluders, which explains why the overall negative median is not a floor-error statistic. Do not count occluded observations as direct contradiction of a hidden floor.

## Limits and next discrimination

- Nearest-pixel sampling can alias depth boundaries; poses, calibration and processed depth may themselves be wrong. These are not independent physical measurements.
- Projecting a mesh point does not establish that its containing voxel was allocated or updated by that frame. The TSDF's active volume coverage, weights, truncation-distance geometry and update order were not exported here.
- A surface-behind-point observation is not automatically a clearing vote in every TSDF implementation. This trace cannot infer which view generated the extracted triangle.
- Three points do not characterize all 4,166 rays. No general sensor-failure, drift, hallucinated-surface, physical hazard or safety claim follows.
- No thresholds were tuned, frames removed, geometry corrected or main scores changed.

The next causal check would examine the released integrator's allocation/update behavior at these fixed points, or compare the unchanged input with another released reconstruction. That is separate work, not performed here.

## Visual inspection of the supporting training frame

The original frame_00074 RGB and the plotted depth raster were viewed, with all three projected points marked alongside the original frame_00228 source pixels (`plot_trace.py`; local-only `local-figures/trace_frame74.png`). In frame 74 the three projections fall on the narrow visible display/background strip immediately left of the large foreground chair-back silhouette. The depth panel places them in the transition from the near chair to farther background. In frame 228 the first two source pixels overlap the display and the third the wall between chair backs.

Depth-boundary mixing or RGB/depth misregistration is consequently a specific hypothesis to check, alongside pose inconsistency; appearance does not establish any of them. The later far observations clipped at 4 m could contribute to retaining an earlier surface, but this is not proven without tracing the released integrator's actual voxel update/coverage behavior. No integration cutoff is changed here. The original photographs and this annotated comparison remain local, excluded from publication pending parent review.

`TRACE_INPUT_VERIFICATION.json` records that all 265 training depth hashes match the frozen fusion inputs, plus source and pose hashes.

Of the 39 / 41 / 39 clipped observations for the three suspect points, 27 / 29 / 27 occur after frame 74. This is a temporal count only, not evidence of actual integrator updates.

## Independent review

`../independent-review/recount_trace.py` and `TRACE_REVIEW.json` independently recompute all 1,590 observations using OpenCV-coordinate inverse transforms, all 265 depth hashes, the connected-component quantile selection and summary lists. **11,180 checks passed**: exact sample pixels/statuses; floating results agree within the review's 1e-9 absolute plus 1e-12 relative tolerance. The maximum absolute difference of 1.34e-8 is in a projected coordinate extremely near the camera plane, not a changed sample or depth. The reviewer also viewed the frame 74 panel and confirmed the described boundary placement, without claiming physical correspondence or TSDF contribution provenance.
