# Actual recorded iPhone → unchanged production depth-admission gate

## Executed result

The preregistered audit invoked the real production `NativeDepthObservationPolicy.acceptedDepth(Float, confidence)` on the same eight recorded iPhone frames, preserving Float32 bit patterns and original confidence. No uint16-mm conversion was used.

| Outcome | Stride-2 samples |
|---|---:|
| Attempted | **98,304** |
| Admitted by the production return | **31,648** |
| Rejected: original confidence 0 | **28,299** |
| Rejected: original confidence 1 | **38,357** |
| Rejected: other confidence | 0 |
| Rejected: confidence-2 nonfinite depth | 0 |
| Rejected: confidence-2 depth below range | 0 |
| Rejected: confidence-2 depth above range | 0 |

There are 393,216 full-raster pixels; **294,912 were not sampled** by the native stride and must not be counted as rejected. Rejection reasons are disjoint, confidence first. Every admission returned exactly the Double conversion of its original Float value. Per-frame counts reconcile and match an independent recount of the unchanged source arrays.

| Original frame | Admitted | Confidence-0 rejection | Confidence-1 rejection |
|---|---:|---:|---:|
| 0 | 4,278 | 3,363 | 4,647 |
| 1 | 4,296 | 3,088 | 4,904 |
| 2 | 4,037 | 3,220 | 5,031 |
| 3 | 3,692 | 3,633 | 4,963 |
| 4 | 3,568 | 3,871 | 4,849 |
| 5 | 3,878 | 4,041 | 4,369 |
| 6 | 3,828 | 3,736 | 4,724 |
| 7 | 4,071 | 3,347 | 4,870 |

This is **scalar admission evidence only**. No native Observation was created, no obstacle detector called, and no intrinsics, pose, tracking, body, floor, map or goal entered the runner. The authentic recording is a close tabletop manipulation sample, not a walking-room benchmark. Admission is not obstacle detection, recall, clearance or avoidance success; rejection is not proof of an obstacle miss or hardware failure.

## Source and data ownership

- Actual recording: CaryxAI `EM1-0387.r3d`, immutable dataset revision `a285cd1249fe9762085713a1c796ab68b1810ac2`, clip SHA-256 `aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4`. Same original frames 0–7 as the earlier field audit; no further download. Dataset license/attribution remain in the separate frozen 41-file raw-input packet.
- Production source SHA-256: `0e6e55ddc3321b6b89998ca43c9fcd3711ec8e54d7395ea99b6edeb52e2b6e7c`.
- Existing production module library SHA-256: `b52ad4059563b983e4277fcdca28238475c3d1884c2be4846d16796bbc180d2f`. The compiled policy source differs only by its required `import BlindCore` module import; exact comparison was checked before execution.
- `SOURCE_DATA_PINS.json` records all sixteen original decoded-input hashes, module/support library hashes, actual native sampler source, runner and preregistered protocol. Inputs/source/libraries were checked unchanged after execution; `ldd` resolved the expected libraries at the explicit paths.
- Only a small audit harness was compiled; production libraries and source were not changed. Compiler wall time was 0.798 seconds, peak child RSS 170,748 KiB. Actual Linux runner wall time was 0.032 seconds, **not iPhone acquisition-to-warning latency**. Runner binary SHA-256 is `1fe85f729845d1e3f8ddcac26725a574203ae17b9dba1c4f77888767df762f63`.

The closed-loop worker independently reviewed the harness and protocol before execution and found no blocker for this exact scalar scope. It did not run this audit. The independent Python recount is a verification check, not the admission authority and not a new obstacle algorithm.

## Newly resolved intrinsics provenance — separate from admission

Record3D's author explicitly documents `perFrameIntrinsicCoeffs` as **[fx, fy, tx, ty]**, where tx/ty occupy the principal-point positions, and global `K` as **first-frame-only**. [Exact author explanation](https://github.com/marek-simonik/record3d/issues/99#issuecomment-2459540413), [pinned official matrix construction](https://github.com/marek-simonik/record3d/blob/0c6e7692da100aad2d5195e307f01e75427a6a2a/demo-main.py#L40-L43).

The original metadata check confirms column-major `K` exactly equals the matrix constructed from coefficient row 0; **88 of 89 rows differ** from the first. Global K must not silently replace per-frame values. The recorded RGB is 1920×1440 and depth 256×192; both coordinate axes scale by 2/15. The author confirms the streams are already aligned and all four coefficients scale with resolution. That provenance is not an independently measured registration error bound. [Author's alignment explanation](https://github.com/marek-simonik/record3d/issues/108).

`INTRINSICS_METADATA_CHECK.json` and `INTRINSICS_PROVENANCE_REVIEW.md` record the checks and exact sources. **No pixel/world projection was performed.** `initPose`/gravity composition, tracking state and body/belt calibration remain unresolved. The earlier 41-file packet's then-unresolved coefficient-order note is retained as historical evidence; it was not overwritten.

## Next evidence boundary

`NEXT_EVIDENCE_REQUIREMENTS.md` specifies independent obstacle/visibility/support labels, measured body/sensor extrinsics and timestamps, held-out conditions and separate event/journey metrics needed before actual miss/clearance claims. Phone-plus-belt/additional sensors remain the intended architecture; this audit imposes no phone-only requirement. No navigation run or broader perception evaluation is authorized by this packet.

## Reproduction and publication

This is a snapshot-specific source/evidence packet. `run_audit.py` expects the separately verified raw-input workspace and pre-existing exact Swift support builds at the documented sibling paths, checks their hashes, and compiles only `AdmissionAudit.swift` using the installed Swift 6.4.1 toolchain. It refuses an existing `build` directory rather than overwrite evidence. `check_intrinsics.py` performs only the separate original-metadata association check.

The publication packet contains no raw frames, clip, full poses, compiled binary or personal sensor capture. `source-cuts/` contains exact production text for auditability, not replacements installed into the application. Source-only publication is performed by the repository maintainer; this audit made no remote write.

## Public copy note

This is a public-normalized copy; see `PUBLIC_NORMALIZATION.md` for path placeholders, original-versus-public hashes, configurable wrapper changes (where applicable), and the exact limited verification performed. Historical execution claims above describe the original pinned source cut, not a new run during publication preparation.
