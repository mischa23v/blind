# Raw recorded iPhone capture: provenance and bounded inspection plan

Research snapshot: 2026-10-26. Scope: original recorded RGB/depth/confidence and camera metadata, not synthetic mesh re-rendering, closed-loop navigation or a safety verdict. The phone is a starting platform; the intended product may include a belt and additional sensors. Missing phone coverage is a measured input gap, not a declaration that the product is infeasible.

## Verified public metadata; clip bytes not yet verified by this reviewer

Publisher: [CaryxAI / Everyday Manipulation 3D (raw)](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw). Public API reported `gated: false`, `private: false` and revision **`a285cd1249fe9762085713a1c796ab68b1810ac2`**. README, license, complete 1,513-row index and bounded D2/D4 repository listings were inspected without an account. No raw clip was downloaded or decoded by this reviewer. The maintainer owns separately authorized acquisition and must record its actual results, not infer them from this plan.

Publisher says chest-mounted iPhone 12 Pro / iPhone 17 Pro, Record3D captures with audio removed and all remaining archive entries byte-identical to capture output. This is a publisher provenance assertion, not an independently established sensor calibration. Semantic labels in the index are machine-generated and unreviewed; never use them as obstacle, floor, identity or collision truth.

| Choice | Pinned archive path | Exact bytes | Device / indexed duration |
| --- | --- | ---: | --- |
| Authorized smallest indexed clip | `clips/D2/EM1-0387.r3d` | 13,973,317 | iPhone 12 Pro; 89 frames; 5.93 s; approximately 15 fps |
| Optional later floor-oriented candidate; not authorized here | `clips/D4/EM1-1199.r3d` | 17,793,463 | iPhone 12 Pro; 103 frames; 6.87 s; approximately 15 fps |

Repository LFS SHA-256 values (index sizes agree with pinned tree metadata):

- EM1-0387: `aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4`
- EM1-1199: `e4a083c4273ce5fd166cf0daaefa43a03fd2bba0d6e5b37fdb70a3feb0fbeec1`

Evidence: [pinned index](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/blob/a285cd1249fe9762085713a1c796ab68b1810ac2/index.csv), [D2 tree API](https://huggingface.co/api/datasets/CaryxAI/everyday-manipulation-3d-raw/tree/a285cd1249fe9762085713a1c796ab68b1810ac2/clips/D2?recursive=false&expand=false), [D4 tree API](https://huggingface.co/api/datasets/CaryxAI/everyday-manipulation-3d-raw/tree/a285cd1249fe9762085713a1c796ab68b1810ac2/clips/D4?recursive=false&expand=false).

## License and attribution

[Pinned publisher LICENSE](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/blob/a285cd1249fe9762085713a1c796ab68b1810ac2/LICENSE): copyright 2026 CaryXAI, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/legalcode). Attribution: **CaryX AI. Everyday Manipulation 3D (raw RGB-D). 2026.** Include dataset and license links and describe transformations/subsetting. The separate annotated dataset may have different terms; it is not part of this plan.

## Expected archive schema — inspect actual fields before accepting

Publisher [pinned README](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/blob/a285cd1249fe9762085713a1c796ab68b1810ac2/README.md) describes a ZIP `.r3d` with:

- `metadata`: JSON `K`, `poses`, `frameTimestamps`, `perFrameIntrinsicCoeffs`, `initPose`, `cameraType`, `w`, `h`, `dw`, `dh`, `fps`.
- `rgbd/<i>.jpg`: original RGB; `rgbd/<i>.depth`: LZFSE float32 metres; `rgbd/<i>.conf`: LZFSE uint8 confidence 0/1/2; `icon`: JPEG.
- `K` is column-major RGB-camera intrinsics. Pose arrays use `[qx,qy,qz,qw,tx,ty,tz]`.
- Portrait and landscape both occur. EM1-0387 index says RGB 1920 x 1440, depth 256 x 192; actual archive must agree. Do not hardcode dimensions from this or older examples.
- Configured `fps` is not reliably actual cadence. Preserve measured `frameTimestamps` and audit units, monotonicity and synchronization. Do not synthesize timestamp spacing from FPS.

## Primary Record3D guidance and unresolved conventions

1. **Depth/confidence:** app author confirms LZFSE float32 depth in metres and uint8 confidence, 0/1/2: [issue 7](https://github.com/marek-simonik/record3d/issues/7), [issue 39](https://github.com/marek-simonik/record3d/issues/39). Preserve original confidence; no fabricated confidence 2.
2. **Registration:** author confirms `K` belongs to RGB and Apple aligns RGB/depth: [issue 76](https://github.com/marek-simonik/record3d/issues/76). This describes intended registration, not measured error bounds for this clip.
3. **Resolution scaling:** author scales fx, fy, cx, cy by depth/RGB resolution, and rejects subtracting an extra half image width/height: [issue 94](https://github.com/marek-simonik/record3d/issues/94). The publisher README gives two allegedly equivalent formulas, but its first uses `px/(dw-1)*w`, while its second scales K by `dw/w`; they differ. Use the author-confirmed resolution-ratio convention with actual dimensions and explicitly validate orientation/pixel mapping. Do not silently upsample confidence or manufacture new geometric observations.
4. **Pose axes:** right-handed OpenGL camera convention, negative Z forward; author builds the rotation from `[qx,qy,qz,qw]` and uses `-R[:,2]` for camera forward: [issue 59](https://github.com/marek-simonik/record3d/issues/59), [issue 33](https://github.com/marek-simonik/record3d/issues/33). Do not copy the incorrect initial question's transform in issue 59 instead of the author's correction.
5. **Initial orientation:** stored trajectories can be relative to the initial camera. Author added `initPose` in Record3D 1.6.12 to retain the initial true pose: [issue 27](https://github.com/marek-simonik/record3d/issues/27). Do not assume stored +Y is gravity-up. Exact composition must be established from actual metadata/format evidence; `T_init * T_relative` is a hypothesis until checked, not a verified claim here.
6. **Not yet established:** exact ordering/units of `perFrameIntrinsicCoeffs` and timestamps in the chosen bytes, tracking-quality/relocalization indicators, whether each timestamp/pose matches each RGB/depth/confidence member, metric/gravity consistency, temporal smoothing and timestamp domain. Missing data must remain explicit rather than inferred from a category label or successful decode.

## Authorized acquisition/decode boundary (maintainer-owned)

Root authorized only EM1-0387 transfer <=16 MiB; metadata and first eight RGB/depth/confidence frames <=64 MiB output; tiny pinned native decoder, no package installation. Do not acquire EM1-1199 or the full 279 GiB corpus under that authorization.

1. Verify exact archive byte count and SHA-256 against the pinned LFS metadata; retain receipt and source links.
2. Inventory ZIP before selection; reject traversal, absolute/duplicate/ambiguous names, links/special files and unexpected dimensions/counts. Enforce member-count, metadata, aggregate output, memory/time and free-space limits. Avoid `extractall`.
3. Inspect metadata schema and first eight member correspondences. Audit finite/invertible intrinsics, rigid/unit quaternion poses, dimensions and timestamp validity without assigning missing tracking status.
4. Decode depth into a capacity-bounded buffer; require exactly `4*dw*dh` bytes, and confidence exactly `dw*dh`; reject invalid confidence values. Preserve invalid/nonfinite/nonpositive depth as invalid evidence, not clearance. Bounds should distinguish truncated output from an exact-length success (e.g. one extra sentinel byte or decoder completion status).
5. Record original member hashes, decoder revision/build flags and resulting dimensions/value summaries. Inspection is not a perception accuracy score. No navigation pass or safety/coverage conclusion at this stage; evaluation protocol comes first.

## Minimal codec reuse

Installed Python inspection found NumPy/Pillow available, but neither `liblzfse` nor `lzfse`. No installs performed. Use the official [LZFSE C reference](https://github.com/lzfse/lzfse), BSD-3-Clause, revision **`e634ca58b4821d9f3d560cdc6df5dec02ffc93fd`**. The maintainer's `LZFSE_SOURCE_PLAN.json` records 213,037 bytes for source plus notices, source hashes and a bounded serial gcc plan. This reviewer has not independently downloaded/built that revision. Keep all notices. A decode-only C ABI needs no ROS, Open3D, USB stack, GPU or Record3D streaming library.

## Product/evaluation boundaries

Recorded original confidence/timestamps address key gaps in the Koivu processed export, but do not supply calibrated phone-to-body or belt-to-body transforms, mount-slip bounds, full-body collision truth or independently labelled obstacles. A chest mount is not a measured extrinsic calibration. Device tracking quality may be missing. Prerecorded manipulation trajectories cannot respond to a planner, so this stream can test ingestion and sensor-response behavior, not controlled A-to-B goal completion.

The intended phone-plus-belt/additional-sensor architecture remains in scope. Assess each sensor's measured field of view, timing and validity in a common calibrated body frame; unknown coverage remains unknown. Do not declare the project infeasible because a phone alone cannot observe every region. Keep real recorded sensor replay distinct from authored closed-loop 3D simulation and from later supervised hardware validation.
