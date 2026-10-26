# Paired real-iPhone room reference feasibility — research stage 04

**Status: read-only research and proposed protocol, 2026-10-26. No Faro archive bytes or byte ranges were acquired; no new geometry, perception or navigation test ran.** Metadata and official source text were inspected only. This note originally requested separate acquisition authorization and protocol review. A subsequent authorization now permits a separately owned bounded Koivu download and inventory only; no metric execution is authorized. This is distinct from the frozen eight-frame tabletop component audit.

## Decision

**Use the already-acquired MuSHRoom Koivu iPhone recording with its separately captured Faro reference, if the bounded reference acquisition becomes possible.** This can produce an offline, registered **processed-depth versus reference-surface discrepancy** test in a real furnished room. It cannot reproduce the production confidence gate, causal tracking or body-clearance detector: those original fields are absent from this export.

**Computational minimum:** `gt_mesh.ply` plus `icp_iphone.json`; `gt_pd.ply` is unnecessary to execute the author’s nearest-surface mesh-depth rendering. **Defensible measured-region minimum is not yet established:** the cleaned mesh contains manually completed surfaces and no edit/support mask is documented. Mesh-only results must be called agreement with the author-processed reference, not all-pixel independently measured physical accuracy. Use the author-associated `transformations_colmap.json` file and original image/depth filename association. **Do not assume this filename means Koivu has successful COLMAP poses.** Verify the actual contents before evaluation.

## Primary provenance and important limitations

MuSHRoom used an **iPhone 12 Pro Max, Polycam and a DJI OSMO Mobile 3 handle**, and a separate **Faro Focus 3D X130** for room geometry. The authors kept objects stationary across captures. They triangulated scanner points and manually removed artifacts/completed holes in the reference mesh. Registration uses the device-estimated point cloud, global scaling/RANSAC followed by color ICP. Thus laser surface acquisition is separate, but registration is not wholly independent of the tested device reconstruction; the mesh is also not unedited, error-free truth. The supplement says COLMAP failed for Koivu/activity and the authors used Polycam poses from two captured loops. These are offline author-exported/registered poses, **not causal ARKit tracking**. [Original paper and supplement, §§3.1.1–3.1.2 and supplementary §1.2](https://arxiv.org/html/2311.02778v3)

The official record description calls `gt_pd.ply` a reference Faro scanner point cloud (not an asserted raw, unedited acquisition), and explicitly says `icp_iphone` transforms poses from `transformation_colmap.json` into mesh/point-cloud coordinates. It does not supply a reference uncertainty or edited-face mask. A point-cloud-supported metric would require verified point provenance, a preregistered support/visibility tolerance and separate boundary handling—not an ad-hoc nearest-point threshold after looking at errors. [Official reference metadata](https://zenodo.org/api/records/10222321)

The official layout identifies reference mesh/point cloud and the iPhone registration JSON; it explicitly calls the Polycam mesh a visualization asset not aligned with the poses. Therefore the previously selected phone mesh must not substitute for the Faro reference. [Official MuSHRoom data layout](https://github.com/TUTvision/MuSHRoom#data-structure)

### Exact public assets and access

All sizes below are compressed bytes from the official Zenodo API metadata, read without downloading assets. These records advertise **CC BY 4.0** and public file access, with no signup/application workflow found. No terms were accepted on the user's behalf.

| Asset | Official record | Bytes | Published MD5 |
|---|---|---:|---|
| Koivu original iPhone export, already local | [10230733](https://zenodo.org/records/10230733) | 146,575,749 | `a359dba714e7829be11747ce5dee141c` |
| **Koivu Faro mesh + point-cloud bundle, not acquired** | [10222321](https://zenodo.org/records/10222321) | **455,583,916** | `1fc9598ff73fc833b6e4db90af604062` |
| All-room rendered reference depths v2, not acquired | [10808829](https://zenodo.org/records/10808829) | 3,851,929,062 | `accdf6f79aa21b668039ca705b855d2a` |

The author's reference-depth record explicitly ties its renderings to the `transformation_colmap.json` pose file (record wording uses singular). The actual renderer reads **`transformations_colmap.json`**. The large all-room reference-depth bundle is not the minimal acquisition. [Reference-depth record](https://zenodo.org/records/10808829)

**Unknown:** the reference archive's member-by-member uncompressed sizes, ordering and exact mesh member path have not been verified. A README naming `gt_mesh.ply` does not establish its byte size. No undocumented mesh-only direct URL or random-access gzip extraction is assumed. Retaining the compressed archive and selectively extracting mesh+alignment needs transfer bytes **plus actual bounded selected extraction** plus the reserve.

At the reported free-space checkpoint, 1,072,668,672 bytes free minus 768 MiB reserve leaves 267,362,304 usable bytes. Koivu's compressed reference alone needs **188,221,612 additional free bytes**, before any extraction. This is a historical pre-cleanup checkpoint, not a claim about current free space. Storage changes were separately authorized outside this research task; no cleanup or archive acquisition was performed by this researcher.

### Smaller pair comparison (secondary, not a reason to discard existing Koivu work)

| Alternative | Phone bytes | Faro bundle bytes | Combined new transfer |
|---|---:|---:|---:|
| Honka — smallest complete pair in the official records | 170,700,232 | 239,649,902 | **410,350,134** |
| VR room — smallest Faro bundle, but larger phone capture | 244,279,042 | 218,765,772 | 463,044,814 |

Even Honka exceeds the checkpoint's usable space by **142,987,830 bytes before extraction**. Both use the same dataset/license/author alignment layout, but neither phone capture is already local. Koivu remains the practical continuation if sufficient approved storage becomes available. Exact other-room metadata is in `SOURCE_EVIDENCE.json`.

## Exact author geometry/association chain to reuse

Pinned author implementation repository: `maturk/dn-splatter`, revision **`97588b4290128ce7ba6fdbfaac3020b42b17de4c`**. This is the implementation linked by the MuSHRoom authors, not a new reconstruction algorithm.

1. [Official downloader](https://github.com/maturk/dn-splatter/blob/97588b4290128ce7ba6fdbfaac3020b42b17de4c/dn_splatter/data/download_scripts/mushroom_download.py#L28-L54) maps the selected room to the iPhone and `*_mesh_pd.tar.gz` records above.
2. [Reference-depth renderer](https://github.com/maturk/dn-splatter/blob/97588b4290128ce7ba6fdbfaac3020b42b17de4c/dn_splatter/data/mushroom_utils/render_gt_depth.py#L21-L166), SHA-256 **`967a96018eeb659bfa35813594f38347e720ca4fa64cfc5710121901fb6a5f35`**:
   - Load reference mesh without processing.
   - Read `gt_transformation`, reshape 4×4, **invert it and apply to the reference mesh** to enter the exported phone pose coordinates.
   - Read `transformations_colmap.json` and each frame's applicable intrinsics, resolution and filename.
   - Convert OpenGL C2W with right-multiplied `diag(1,-1,-1,1)`; invert to W2C, then apply the PyTorch3D renderer's camera-basis conversion.
   - Render the nearest surface as camera-axis z-depth; negative/no-hit results become zero; metres ×1,000 are exported as UInt16 PNG, preserving the image basename.
3. [Author mesh evaluator](https://github.com/maturk/dn-splatter/blob/97588b4290128ce7ba6fdbfaac3020b42b17de4c/dn_splatter/eval/eval_mesh_mushroom_vis_cull.py#L652-L677) explicitly pairs **inverse `icp_iphone.json`** with **`transformations_colmap.json`**. This establishes the correct file association; it does not prove that the original `transformations.json` is identical.
4. [Faro depth evaluator](https://github.com/maturk/dn-splatter/blob/97588b4290128ce7ba6fdbfaac3020b42b17de4c/dn_splatter/data/mushroom_utils/eval_faro.py), SHA-256 **`c6adeb81844f45349766773174585d9f9dba7c45b460848498db28f83d7257dd`**, associates reference images by source basename and reports depth-error metrics. Its neural-render resizing, skipped-file behavior and batch averaging must not be blindly imported into a raw sensor discrepancy test.

The author renderer calls `.cuda()` explicitly despite a nominal device fallback. **Do not install GPU/PyTorch3D or execute that script in this CPU-only environment.** A later bounded adapter may use installed VTK for the same reference-surface query only after independent transform/ray/axial-depth checks. Do not reinterpret Euclidean ray distance as axial z-depth. No scale fitting, unit-box normalization or per-frame ICP is permitted against the held-out tested depth.

Local Koivu inventory already lists `long_capture/transformations_colmap.json` (239,934 bytes), `short_capture/transformations_colmap.json` (98,793 bytes), and long `test.txt` (348 bytes) inside the acquired iPhone archive. These were not newly extracted here. Existing selected long `transformations.json` is 239,937 bytes; similar size is not proof of identity. A future authorized metadata extraction must compare frame IDs, transforms, intrinsics and dimensions explicitly and preserve both versions.

## Proposed next distance protocol — NOT RUN OR APPROVED FOR EXECUTION

1. **Freeze inputs before looking at errors.** Proposed development subset: existing preregistered Koivu long-capture pose-entry indices **0,4,8,12,16,20,24,28**; retain their exact basenames, not assumed numerical frame IDs. Require those same basenames in the author-associated pose file. Report missing matches; do not silently replace frames or optimize registration. Keep the remaining existing selected entries available for a separately frozen held-out check.
2. **Admission/provenance gate.** Verify archive hashes, guarded member inventory, mesh/alignment/source hashes, exact processed RGB/depth pairs, dimensions and 0.001 m depth scale. Maintain `confidence unavailable`, `tracking unavailable`, `capture timing unavailable`. No production `acceptedDepth(confidence=2)` or whole live detector invocation is eligible, and no fabricated confidence/tracking is allowed.
3. **Association gate.** Apply only the frozen author transform direction and matching exported pose file. **Do not require determinant 1 or silently rigidize the matrix:** the paper explicitly permits global scaling. Inspect the actual matrix’s singular values/determinant, similarity structure, scale and units, and compare original versus author-associated poses without changing them. Overlay reference geometry for diagnostic inspection; it is not permission to tune alignment against evaluated depth. If association remains unresolved, stop before metrics.
4. **Independent reference denominator.** Query the nearest visible Faro-mesh surface with existing CPU geometry tooling at explicitly defined recorded pixel centres; preserve reference no-hit/holes as unknown. Keep raster/pixel-centre and axial-depth conventions explicit. Record silhouette/discontinuity bands separately, not as silent exclusions. Any manual mask for author-repaired, reflective or uncertain surfaces must be created independently of the observed error, frozen and reported with its excluded denominator. Missing repair provenance remains a limitation rather than an invented mask.
5. **Actual distance discrepancy.** For positive finite exported sensor depth and valid reference depth, report signed `sensor_z − reference_z` bias, MAE, median absolute error and 90th/95th-percentile absolute errors, per frame and by preregistered reference-depth bins (0.15–1, 1–2, 2–3, 3–5, >5 m). Positive error means the exported sensor reports the surface farther away, but is not by itself a proven hazardous event. Report counts, missing sensor depth, missing reference surface and each boundary category separately; do not pool correlated pixels as independent trials.
6. **Observed coverage.** In image tiles, report reference-visible pixels versus available sensor-depth pixels, invalid/no-return counts and agreement distributions. No unseen region becomes free. Separately label camera-visible versus occluded/reference-missing geometry; no scene-map completion or free-space assertion.
7. **Interpretation/hold-out boundary.** Call a mesh-only result **offline author-registered processed-depth agreement/discrepancy with the author’s cleaned laser-derived reference**, not an all-pixel physical accuracy measurement. It combines sensor/export/registration/reference effects; it is not an isolated raw LiDAR accuracy bound. Do not retune detector thresholds from these results. A held-out scene, thin/low/transparent/overhanging object labels and unchanged protocol are needed before generalization claims.

### What remains missing for an actual hazard or clearance miss rate

A room mesh is geometry, not a complete hazard-event label set. Need independently specified hazard surfaces/object extents, visibility/occlusion at each frame, relevant body/foot/head trajectory and calibrated phone/belt/gimbal extrinsics, response deadlines and synchronized acquisition/output timing. Source confidence/tracking are absent; phone exported poses cannot stand in for measured user motion. This first test can expose room-scale distance discrepancies and missing coverage, **not count actual missed collision hazards, validate saved-map clearance, or prove A→B avoidance**. That distinction must survive the eventual report.

## Other candidates and why they do not replace this room plan

- **ScanNet++:** the original paper specifies **iPhone 13 Pro**, with separate laser reference geometry. Current official docs list RGB/depth, raw ARKit and aligned poses/IMU, but no confidence-map asset in the inspected release schema/decoder. Account/application approval and personalized token are required; no small ungated paired example was verified. Some registered iPhone frames are filtered using disagreement against scanner depth, creating selection bias for an unfiltered sensor-failure estimate. [Official access/license](https://scannetpp.mlsg.cit.tum.de/scannetpp/) · [Data schema](https://scannetpp.mlsg.cit.tum.de/scannetpp/documentation) · [Original paper §3.3–3.4](https://openaccess.thecvf.com/content/ICCV2023/papers/Yeshwanth_ScanNet_A_High-Fidelity_Dataset_of_3D_Indoor_Scenes_ICCV_2023_paper.pdf)
- **LaMAR:** official raw schema includes depth and confidence plus NavVis reference, but the original paper's collected mobile devices were iPad Pro; do not assume every folder labelled phone is a genuine iPhone. Access is by request; no small eligible iPhone subset was verified. [Raw-data schema](https://github.com/microsoft/lamar-benchmark/blob/main/RAW-DATA.md) · [Original paper](https://lamar.ethz.ch/files/LaMAR.pdf)

### Appendix: narrow physical-reference fallback, not room priority

[Zenodo 23577624](https://zenodo.org/records/23577624), published 2026-10-22, describes a 37.0 MB close-range study using an iPhone 17 Pro and a measured 50.22 mm square marker. It records depth/confidence at **one** depth-map pixel, with intrinsics/marker corners, over 86–739 mm. Marker geometry offers a separate plane-distance reference, but this is not a full depth raster, room, hazard or walking benchmark. Its original artifact/license/source and uncertainty still require a separate audit before acquisition or use. No acquisition was made; it must not displace the room-reference task.

## Authorization boundary at handoff

After the metadata research, the maintainer separately authorized the exact Koivu reference archive (455,583,916 bytes / stated MD5), compressed cap 460 MiB, 768 MiB reserve, and guarded streaming **inventory only** capped at 2 GiB decompressed / 10,000 members / five minutes. That acquisition is owned by a different work item, not executed here. Extraction still waits for member sizes; no depth metric, native detector, navigation run or alignment fit is authorized by this research note.
