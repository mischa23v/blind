# Recent iPhone recording: completed bounded comparison

**We acquired and tested an actual publisher-labeled iPhone 17 Pro Record3D clip. It decodes and passes the unchanged depth-admission/camera-projection pipeline. This is not a device-accuracy or navigation-safety comparison.**

## Measured results

Eight evenly spaced original frames per clip were frozen before inspecting depth/confidence. Each set contains 393,216 full-raster pixels, or 98,304 candidates under the unchanged stride-2 policy.

| Measurement | 17 Pro: EM1-1093 | 12 Pro: EM1-0387 |
|---|---:|---:|
| Publisher capture date | 2026-07-23 | 2026-07-21 |
| Whole clip frames | 394 | 89 |
| Original depth / RGB raster | 256×192 / 1920×1440 | 256×192 / 1920×1440 |
| Actual frame-timestamp cadence | 59.9766 Hz | 14.9984 Hz |
| Configured `fps` metadata | 60 | 30 |
| Full-raster confidence-2 pixels | 344,878 / 393,216 (87.707%) | 137,463 / 393,216 (34.959%) |
| Admitted by unchanged native policy | 86,236 / 98,304 (87.724%) | 34,240 / 98,304 (34.831%) |
| Rejected confidence 0 / 1 | 3,125 / 8,943 | 27,490 / 36,570 |
| Rejected below 0.15 m | 0 | 4 |
| Other-confidence / nonfinite / above-5 m rejection | 0 / 0 / 0 | 0 / 0 / 0 |
| All positive depth min / median / max | 0.153 / 0.458 / 0.661 m | 0.106 / 0.457 / 1.189 m |

Original full-raster confidence counts (0, 1, 2): 17 Pro `(12,357, 35,981, 344,878)`; 12 Pro `(110,981, 144,772, 137,463)`. All selected depth pixels are finite and positive; this does not establish that all are correct real-world distances.

The native component used original Float32 depth converted to Double, confidence exactly 2, inclusive 0.15–5 m, and stride 2 from pixel zero. It used original per-frame intrinsics, resolution-ratio scaling and Record3D's integer-pixel convention. Every admitted sample produced a finite camera-relative point. Five independent analytic projection probes and nine scalar-boundary probes passed per invocation; maximum algebraic back-project/reproject residual was `2.842170943040401e-14` pixels, with zero depth residual. This checks implementation arithmetic, not physical calibration accuracy.

Independent re-reading of the original decoded bytes matched every native per-frame admission/rejection count. The previous first-eight-frame 12 Pro result is a different sample and was not overwritten or substituted.

## What the result means—and does not mean

- The newer recording provides inspectable original depth, native confidence, timestamps, per-frame intrinsics and ARKit camera poses. The byte/field checks found no acquisition mismatch or selected-frame decode failure.
- The tested 17 Pro clip yields more accepted pixels **in this scene**. JPEG inspection shows a near wall/wood floor/charger/cable; the 12 Pro clip shows a glass tabletop/bowl/camera. Scene, surface, range, wearer and recording conditions differ. Confidence is device-relative, not a comparable probability of correctness. The dataset-wide median confidence ordering is opposite to this pair.
- The 12 Pro comparator here is CaryX EM1-0387, **not** Koivu's iPhone 12 Pro Max Polycam capture. Original 256×192 Float32/confidence streams are not equivalent to Koivu's processed 738×994 millimetre-PNG export.
- Device model comes from the publisher index. Actual metadata confirms `cameraType=1` (LiDAR), but does not record exact device model, app/iOS version, depth-smoothing mode, tracking state, gravity or camera-to-body calibration. Valid numerical camera poses do not validate tracking accuracy.
- No independent surface/trajectory truth, thin-cable labels, obstacle-recall score, latency measurement, world/body projection, map, route or physical-navigation test is available here. Neither higher confidence nor successful algebraic projection proves safe clearance or that a newer phone fixes Koivu's failure.

## Selection and integrity

CaryX AI, *Everyday Manipulation 3D (raw RGB-D)*, 2026, CC BY 4.0, immutable revision `a285cd1249fe9762085713a1c796ab68b1810ac2`. See [the pinned card](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/blob/a285cd1249fe9762085713a1c796ab68b1810ac2/README.md) and `SOURCE_AND_INTERPRETATION_NOTES.md`.

The selected 17 Pro archive is the smallest by bytes, not confidence: 55,082,489 bytes; SHA-256 `5cd8b4d03fd7e1ed2ec28d005d4e01209dddd9583029787f85e5b5f65376e6cb`, exactly matching the pinned publisher LFS entry. None of the 646 indexed 17 Pro clips fits the original ideal 32 MiB cap. There are 73 reported zero-high-confidence 17 Pro clips; the smallest is 101,270,887 bytes, outside the approved 64 MiB transfer budget, not excluded because of its outcome. There is no 12 Pro `plug_charger` clip in this pin. Existing 12 Pro bytes were reused without another download.

Frozen IDs: 17 Pro `[0,56,112,168,224,280,336,393]`; 12 Pro `[0,12,25,37,50,62,75,88]`, using `floor(k*(N-1)/7)` for `k=0..7`.

Selected members passed ZIP CRC checks; unselected member CRCs were not tested. Selected compressed-member copies plus decoded arrays total 6,462,226 bytes. Native audit outputs, executable and local compiler cache total 17,874,112 bytes. Final native receipt reports 975,462,400 bytes free, above the 805,306,368-byte reserve. No dependencies were installed or rebuilt; the existing verified LZFSE decoder and shared policy libraries were reused.

## Evidence files

- `ACQUISITION_RECEIPT.json`, `SELECTED_INDEX_ROWS.json`, `FROZEN_FRAME_SELECTION.json`
- `audited/{EM1-1093,EM1-0387}/FIELD_AUDIT.json` and original selected members/decoded arrays
- `INDEPENDENT_BYTE_RECHECK.json`, `INDEPENDENT_PREDICATE_RECHECK.json`, `NATIVE_INDEPENDENT_RECHECK.json`
- `native/PROTOCOL.md`, `native/NativeCameraAudit.swift`, `native/run_native_audit.py`
- `native/run/{SOURCE_DATA_PINS,EM1-1093,EM1-0387,RECEIPT}.json`

Keep source data and receipts separate. The `native/run/build` compiler outputs/cache are not required in a review/publication packet. Stop condition reached: bounded acquisition, provenance/field audit, unchanged component execution and independent result check are complete; no broader hardware or navigation claim follows.
