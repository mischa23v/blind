# Stage 03 results — genuine recorded camera-relative geometry

**Completed once on the original eight EM1-0387 frames, with unchanged production code and data.** This verifies the actual shared camera-projection component on real recorded Float32 depth/confidence. It is not an obstacle-detection, physical-accuracy, clearance or navigation result.

- **31,648 / 98,304 scheduled pixels projected (32.194%).** All prior scalar admissions produced finite camera points; no admitted point was silently dropped. The other 66,656 scheduled pixels were rejected for original confidence 0 or 1. An additional 294,912 full-raster pixels were intentionally unsampled by stride 2, not rejected measurements.
- Five hand-calculated convention/scaling probes: zero coordinate/intrinsic error. Maximum inverse residual **2.842170943040401e-14 pixels**, depth residual **0 m**. These are internal arithmetic checks, not measured sensor accuracy.
- Native-depth first-to-last-pixel-centre angular spans: **65.815–65.847° horizontal / 51.698–51.726° vertical**. RGB spans: **65.992–66.024° / 51.906–51.934°**. These come from original per-frame intrinsics, not a physical FoV measurement.
- Admitted-ray envelopes are narrower and vary: **41.152–59.659° horizontal / 46.012–48.065° vertical**. An envelope does not make its interior observed or free.
- Across the full rasters, original confidence counts are **114,597 low / 151,464 medium / 127,155 high**. All 393,216 depths are finite and positive, with no zero/negative/nonfinite depths or policy-range exclusions in these eight close-range frames. Finite depth is not verified correct depth.
- **15–20 of 48 image tiles per frame have no admitted scheduled ray.** Tiles are 32×32 image regions, not body/head/near-feet coverage zones.

| Frame | Original relative time (s) | Projected points | Zero-admission tiles / 48 | Admitted angular envelope H / V (°) |
|---|---:|---:|---:|---:|
| 0 | 0.000000 | 4278 | 15 | 52.707 / 46.012 |
| 1 | 0.066674 | 4296 | 19 | 43.410 / 47.041 |
| 2 | 0.133348 | 4037 | 19 | 54.627 / 46.515 |
| 3 | 0.200022 | 3692 | 17 | 57.900 / 46.529 |
| 4 | 0.266695 | 3568 | 17 | 59.659 / 46.540 |
| 5 | 0.333369 | 3878 | 20 | 41.749 / 46.540 |
| 6 | 0.400043 | 3828 | 20 | 42.854 / 48.065 |
| 7 | 0.466717 | 4071 | 20 | 41.152 / 47.560 |

## Execution and interpretation

The run used each original `[fx,fy,tx,ty]` row through the verified native Float→Double resolution scaling. No pose, tracking, gravity, body, mount, belt, floor, map or goal was forwarded. Every cloud stays in that camera's own coordinates; no registration or fusion. Global first-frame K was not repeated across frames. Original timestamps span only **0.466717 s**, not eight independent scenarios.

Observed run resources: **11.834 s wall, 12.11 s process-tree CPU, 273.766 MiB sampled peak tree RSS**, approximately **6.01 MB** new outputs before the receipt, no compiler-cache growth. The small Swift harness compile took 0.824 s with no compiler warnings. Plot logs retain nonfatal font-cache messages. Linux runtime is not iPhone end-to-end latency.

The untouched frame-0 JPEG and separate original-array depth/confidence/admission plots were visually inspected. The RGB shows a close tabletop scene, not a walking route. Plots expose the sparse original-confidence admission instead of filling holes. Initial 3D-scatter axis labels clipped at the image edge; original charts and their hashes remain preserved, with any separately documented presentation-only label repair excluded from numeric evidence.

## What this establishes—and what is next

Real recording input provenance, original confidence handling, exact shared arithmetic and recorded ray distributions now have bounded component evidence. **No independent physical geometry, body/extrinsic or hazard-event truth exists for this clip**, so no accuracy, missed-obstacle, body-clearance or zero-collision rate can be calculated honestly from it. Human viewing of RGB is not metric 3D truth. The same phone reconstruction cannot grade its own physical correctness.

The next evaluation requires an independently measured/labelled scene and visibility regions, predeclared hazard-event denominators and warning deadlines; body/phone/belt/gimbal geometry and timing must be measured separately for clearance. Compare the phone starting platform and intended phone-plus-belt/additional sensors against those same requirements. This tabletop diagnostic cannot decide the final hardware configuration's sufficiency. See `INDEPENDENT_LABEL_REQUIREMENTS.md` in the proposal packet.

Primary calibration/convention evidence: [Record3D author per-frame coefficient order](https://github.com/marek-simonik/record3d/issues/99#issuecomment-2459540413), [official pinned camera-point example](https://github.com/marek-simonik/record3d_unity_streaming/blob/49152244daa10686220c06c4f80dd9a823357e0f/Record3DUnityStreaming.cpp#L60-L75), and [author RGB/depth resolution guidance](https://github.com/marek-simonik/record3d/issues/108). Dataset: [CaryxAI pinned original clip repository](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/tree/a285cd1249fe9762085713a1c796ab68b1810ac2), CC BY 4.0. These sources establish the documented input convention, not an independent accuracy bound for this capture.
