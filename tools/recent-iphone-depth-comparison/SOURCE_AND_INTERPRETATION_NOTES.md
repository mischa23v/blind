# Source and interpretation notes

Prepared 2026-10-26. This is an internal research/audit note, not a navigation validation report.

## Primary sources for the acquired clips

- CaryX AI, *Everyday Manipulation 3D (raw RGB-D)*, 2026, [pinned dataset card](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/blob/a285cd1249fe9762085713a1c796ab68b1810ac2/README.md), revision `a285cd1249fe9762085713a1c796ab68b1810ac2`. CC BY 4.0; attribution applies to derived subsets. The publisher says audio was removed and sensor streams were not modified. No independent surface/trajectory truth is provided in this raw release.
- [Pinned index](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/resolve/a285cd1249fe9762085713a1c796ab68b1810ac2/index.csv). Device names and capture dates come from this publisher index, not hardware identification embedded in the tested archives. Semantic descriptions are machine-generated and unreviewed. The actual JPEG spot-check corroborates different scene types, not all semantic labels.
- [17 Pro EM1-1093 archive](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/resolve/a285cd1249fe9762085713a1c796ab68b1810ac2/clips/D3/EM1-1093.r3d?download=true). Acquired bytes and SHA-256 match the pinned publisher LFS entry; selected ZIP member CRCs were checked. This establishes byte integrity for this acquisition, not sensor accuracy or correctness of every unselected member.
- [12 Pro EM1-0387 archive](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/resolve/a285cd1249fe9762085713a1c796ab68b1810ac2/clips/D2/EM1-0387.r3d?download=true). Reused the existing verified local archive; no second raw download.

## Do not turn confidence fractions into a hardware ranking

The publisher explicitly cautions that confidence is device-relative. The same pinned index has 867 clips labeled 12 Pro and 646 labeled 17 Pro; their median reported high-confidence fractions are 0.8785 and 0.69215 respectively. These corpus medians are not accuracy measurements either. They demonstrate why the opposite ordering in our two small selected clips must not be generalized.

The index includes 73 17 Pro clips with reported high-confidence fraction zero. None was removed for that reason. The smallest is 101,270,887 bytes, beyond the authorized 64 MiB new-archive transfer budget. No 17 Pro clip fits the original ideal 32 MiB cap. The selected 55,082,489-byte clip is the smallest 17 Pro archive irrespective of confidence. There is no 12 Pro `plug_charger` row to use as a task-matched comparator. See `INDEX_CONTEXT_RECHECK.json` and the frozen selection/authorization records.

## Native app depth is not untouched laser returns

- Apple's [Explore ARKit 4](https://developer.apple.com/videos/play/wwdc2020/10611/) explains that scene depth combines RGB and LiDAR using machine learning. A dense depth raster therefore must not be described as an equal number of independently measured laser returns.
- Apple's [`smoothedSceneDepth` documentation](https://developer.apple.com/documentation/arkit/arframe/smoothedscenedepth) distinguishes extra temporal smoothing from `sceneDepth`.
- The Record3D author [confirmed in December 2020](https://github.com/marek-simonik/record3d/issues/8#issuecomment-750374809) that the app used `sceneDepth` without added USB post-processing, and [said the same then applied to `.r3d`](https://github.com/marek-simonik/record3d/issues/8#issuecomment-750383717). This is historical provenance, not proof of the setting in unknown app versions used in July 2026. Neither tested archive records app version, iOS version or a raw-versus-smoothed semantic selector. Leave that unresolved.
- Record3D's [official demo](https://github.com/marek-simonik/record3d/blob/master/demo-main.py) maps camera type 1 to LiDAR and gives intrinsic coefficient order. Both tested archives have `cameraType=1`. It does not identify the exact iPhone model.

The native comparison uses original Float32 metre depth and uint8 confidence from the recordings, without a new millimetre-PNG conversion, fabricated confidence or interpolated upsampling. Timestamp cadence is not a measurement of sensor latency or independent LiDAR acquisition rate.

## Projection convention

The pinned dataset card contains two allegedly equivalent pixel-mapping snippets whose denominator conventions differ (`dw-1` versus resolution-ratio scaling). Do not combine them. This audit follows the previously author-verified Record3D SDK convention: original per-frame `[fx,fy,cx,cy]`, RGB-to-depth resolution-ratio scaling, and integer depth pixel coordinates. The prior `INTRINSICS_PROVENANCE_REVIEW.md` retains the primary SDK/author evidence. Camera back-project/reproject consistency is an algebraic implementation check, not validation against real geometry.

## Relevant software evidence, not an explanation established for Koivu

[Apple Developer Forums thread 827240](https://developer.apple.com/forums/thread/827240) contains Apple staff confirmation of a LiDAR-device ARKit tracking issue reported after iOS 26.4. Later participants report partial improvement after newer versions. Do not present participant reports as a universal Apple-certified fix, and do not apply a 2026 regression to old Koivu capture without matching capture/app/OS evidence.

## Camera claim boundary

The [18 Pro official specifications](https://www.apple.com/iphone-18-pro/specs/) list a variable-aperture main camera, while the [17 Pro specifications](https://support.apple.com/en-us/125090) list a fixed f/1.78 main camera. These are not identical whole camera systems. Both list a LiDAR scanner without a sensor-module part number; neither establishes LiDAR module identity or comparative depth accuracy.
