# Coffee W6 fixed local-plane comparison: inconclusive, no floor recovery

**Actual software checks passed; the scientific floor-validation criterion did not.** This is a fixed recorded-data diagnostic using released PCL1.15.0, not an app/mapper change or walking guidance.

One0.48m local patch, constrained15° normal,2cm descriptive fit band,128 iterations/fixed seed;350 original training frames and38 heldouts. Controls remained untouched. The successful run compiled once, passed6 native analytic groups and reproduced all1,400 full legacy observations. It retained1,552 control and3,492 local ray/frame cases. A prior512MiB compile attempt failed and is preserved; the separate1GiB run passed in12.554414CPU/12.596303wall seconds, with558,440,448B conservative peak RSS. One CPU/60CPU/120wall/100MiB output limits remained fixed. Compiler and recorded-fit stderr are empty;667bytes of analytic no-model/degenerate-sample warnings remain preserved, not hidden.

| Split | Paired cases / distinct frames | Baseline median / P95 absolute residual | Candidate median / P95 | Baseline / candidate within descriptive4cm |
|---|---:|---:|---:|---:|
| Training |162 /35|1.630901 /2.297560m|1.658731 /2.339279m|15 /7|
| Heldout |3 /1|1.838573 /1.879287m|1.877798 /1.906771m|0 /0|

The exact outcome is `INCONCLUSIVE_NO_HELDOUT_COMPATIBLE_EVIDENCE`. A219/220-inlier,1.0764° plane is **not** floor truth. No settings, samples, fit or acceptance criteria were changed after seeing the result. All original source geometry, missing/raised evidence and route policy remain unchanged; no routes were requeried.

## Why metre-scale residuals were not a metre-scale plane change

An additional root-authorized read-only check used existing VTK9.3.1 on the unchanged full Float64 source, for exactly the3 paired heldout camera rays. All three encounter a nearer mapped surface matching processed depth within3.69–10.20mm; their original floor triangles are recovered farther along the same rays. Original RGB inspection shows the foreground red sofa in that pixel region; nearest mesh vertex colors agree. This supports foreground occlusion for these specific stored rays, rather than concluding the large residual measures floor error. The plane only shifted predicted axial depth by about18–43mm.

The original floor validation remains inconclusive: the nearer observations do not reveal the hidden floor. No blanket occlusion label, geometry deletion, filling, floor-support certification or physical-clearance conclusion follows. Same-stream source/depth agreement is not independent calibration. The3 cases are one view, not3 independent views.

Independent metadata audit found consistent witness IDs, original Float64 triangles, exact per-frame K, inverse OpenGL C2W projection and one camera-basis conversion. Legacy equality establishes regression consistency, not external calibration. Depth is processed uint16 millimetres; calibration/synchronization/confidence/tracking evidence is incomplete. This declared DN-Splatter/Open3D adapter uses original `transformations.json`, distinct from upstream's COLMAP-pose file selection; Coffee equivalence was not established and no alternative poses were tried.

## Source/provenance and scope

Data attribution: Xuqian Ren, *MuSHRoom iPhone dataset (Basic Data)* (2023), [Zenodo10.5281/zenodo.10230733](https://doi.org/10.5281/zenodo.10230733), coffee_room_iphone.tar.gz, CC BY4.0. PCL dependency: released1.15.0/Debian1.15.0+dfsg-2, existing installed headers/libraries; VTK dependency: existing9.3.1 static-cell locator. No installation/download was made for this experiment.

`source/` contains exact authored comparator/probe and post-result three-ray diagnostic source. Synthetic fixture coordinates are authored analytic tests, not recorded room geometry. `RESULT.json` is an allowlisted aggregate derived from private exact receipts, not a replacement for them. `EVIDENCE_SHA256.json` binds source and evidence digests. This is a **nonstandalone preservation packet**: frozen input manifests, original private observations and the existing Float64 VTK adapter remain outside it. The diagnostic source names its fixed dataset frame filename; it does not include that image or measured pixel/XYZ values. No raw XYZ/poses/pixel arrays, images, per-ray/face/vertex result lists, binary, credentials, admission data or private environment inventory are included. No app activation or physical guidance is authorized.
