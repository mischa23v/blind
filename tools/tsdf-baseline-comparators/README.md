# Established TSDF baseline and two distinct comparators

This is an evidence packet for completed offline component experiments—not an obstacle-avoidance, body-clearance, SLAM or walking success. No navigation episode is represented here. The source and numeric results remain separate from clinical or physical safety claims.

## Results at a glance

| Experiment | Fixed inputs and denominator | Actual outcome |
|---|---|---|
| Official Open3D smoke | Five synthetic Redwood/ICL-NUIM sample frames | Native CPU integration completed; 146,747 vertices / 279,171 triangles. Not iPhone data. Sample images, archive and both supplied/derived sample geometry are excluded because their complete redistribution scope is unresolved. |
| Koivu author-configured baseline | 265 training frames; 29 author test frames excluded | Native Open3D CPU 0.19.0 integration completed: 242,293 vertices / 461,256 triangles; separate author-style 1,000,000-point initialization cloud. Original wrapper report parsing failed after the worker exited 0. Saved output was recovered and verified **without rerunning fusion**. The original warning, failed parser record and recovery receipts are preserved. |
| Stage11 held-out same-capture processed-depth consistency | All 29 excluded frames; 1,335,885 scheduled rays | 1,161,037 primary paired samples (`0 < sensor depth < 4 m`, with all positive finite mesh predictions retained): MAE 0.144951 m, absolute median 0.031704 m, p95 0.730580 m. Across all scheduled rays, 9,496 lack a mesh hit. This is consistency with processed phone depth and supplied poses—not independent physical truth. |
| Stage12 saved registered-reference comparison | Eight fixed views; 368,520 scheduled rays; **seven integrated views and one excluded view** | 334,223 paired, 111 reference-only, 33,671 TSDF-only, 515 neither. Paired MAE 0.271090 m, absolute median 0.039115 m, p95 1.983739 m. The long error tail is retained. The saved reference is independently acquired but author-processed and registered; it is not a new ground-truth capture or an all-held-out test. |

The two comparators have different pixel conventions and domains. Stage11 uses integer-centre rays (offset 0); stage12 preserves the saved stage06 half-pixel convention (offset 0.5). Do not combine their ray counts or metrics into a claimed accuracy score. Stage12 did not reopen or reraycast the large FARO mesh, reapply its scale, refit poses, alter the TSDF, or select rays by sensor agreement.

Independent saved-array recounts passed: stage11 28,774 checks; stage12 3,943 checks. Maximum absolute statistic discrepancy was 4.44e-16 in each. Recounts confirm arithmetic and retained denominators, not sensor correctness, registration accuracy, or raycasting geometry. Fixture successes and arithmetic checks are not additional episodes.

## Contents

- Mirrored stage10, stage11 and stage12 source/protocol/result directories; historical protocol proposals stay historical and are not rewritten as results.
- Unmodified author DN-Splatter source and Apache-2.0 license; pinned Open3D notebook/source provenance, MIT licenses, exact dependency closure/locks, environment installation recipe and acquisition/import receipts. Installed packages, wheel archives and caches are not copied.
- Exact inherited `blind-koivu-reference-comparison-06/reference_geometry.py` dependency. Its old `camera_rays` helper is used only where the declared stage requires it.
- Stage11: 29 derived NPZs; stage12: eight derived NPZs. These retain numeric sampled input/derived outputs, not copied full RGB/depth images. They are not actual ARKit confidence/tracking packets.
- Two analytical mesh plots, their source and receipts. Visual privacy inspection found only coordinate charts, not people or identifying photographs. White display regions are not observed-free space. No AI-generated images or gap filling.
- `artifact-parts/`: the complete Koivu derived mesh and initialization cloud, split without changing a byte. `PARTS_MANIFEST.json` preserves original/part hashes and ordered reconstruction.
- `NORMALIZATION_MAP.json`: every copied file's original/public bytes and SHA-256. `EXTERNAL_PREREQUISITES.json`: historical pins for omitted input dependencies. `EXCLUSIONS.md` describes the deliberate omissions.

## Verify and restore

Run `python -B validate_packet.py`. This checks the exact packet inventory, source syntax, hashes, part concatenation, size caps, and public path/credential patterns; it does **not** import scientific modules or run a mapper. `python -B test_restore_parts.py` runs 13 tiny byte fixtures only.

To restore a derived asset into an existing dedicated directory, first obtain the SHA-256 of `PARTS_MANIFEST.json` from the independently verified packet manifest, then run:

```bash
python -B restore_parts.py --manifest-sha THE_VERIFIED_MANIFEST_SHA256 \
  --asset unfiltered-tsdf-mesh.ply --output-dir /your/existing/output-directory
```

Use `--asset author-style-initialization-cloud.ply` for the second asset. Restoration refuses existing files/partials, traversal and symlinks, verifies every part and final file, uses atomic no-overwrite publication, and requires a 768 MiB reserve. The package validator streams and hashes actual parts without writing a duplicate 39.5 MB copy; restoration itself was exercised using small synthetic byte fixtures. It does not validate PLY geometry.

## Reproduction boundary

All included runnable historical scientific sources are byte-identical to the executed cuts. **Public normalized receipts and frozen manifests are not byte-identical executable launch inputs.** They retain original source/data/module hashes but have different own-file hashes. Original hash references therefore refer to the private original evidence, not the normalized display copy. Paths are documented placeholders, not environment expansion instructions.

A fresh execution requires the separately pinned data, compatible numerical stack, a reviewed local path mapping, a newly generated launch manifest and its new external expected hash. Do not replace placeholders and claim that the historical original launch hash still matches. The included install recipe is a bounded, hash-pinned historical recipe, not permission or a guarantee to install into an arbitrary machine. Its original proposal hash can differ from a normalized copy. The dependency resolver's metadata-body cache is omitted, so its original metadata validation is retained as evidence rather than claimed rerun here.

The preserved original Koivu `koivu/RESULT.json` is raw worker stdout: a native ANSI color-clamp warning precedes JSON. This intentional non-JSON file explains the report-parser failure. `RECOVERED_RESULT.json` is the separately recovered JSON. Do not silently remove the failure or reinterpret the native color warning as geometry validation. The failed wrapper did not serialize exact peak RSS; no missing peak measurement is invented.

## Limits and attribution

Koivu is processed iPhone 12 Pro Max / Polycam data from MuSHRoom, CC BY 4.0. See retained official record metadata and attribution. This packet's mesh/cloud are **new derivatives** produced from 265 supplied-pose training frames, not the dataset's supplied phone mesh, not aligned live ARKit replay, and not an original measured point cloud. Reconstruction changes are explicitly recorded: author 4 cm voxel / 20 cm TSDF truncation / 4 m depth truncation configuration; fixed random seeds; Open3D image loading; no resize on dimension mismatch; added native unfiltered mesh export. The author-style cloud samples evolving extracted surfaces and is not independent truth.

Original native confidence/tracking and complete TSDF weight/free-coverage are unavailable. Missing mesh does not imply free space; projections do not establish floor continuity or body clearance. Supplied camera poses and reference registration are not online localization evidence. Reference edited-versus-measured labels are unavailable. None of these results establishes obstacle recall, complete coverage, a safe route, or a hardware choice.

MuSHRoom: Ren et al., *MuSHRoom: Multi-Sensor Hybrid Room Dataset for Joint 3D Reconstruction and Novel View Synthesis*, WACV 2024; [official dataset](https://zenodo.org/records/10230733), [project](https://github.com/TUTvision/MuSHRoom). Author baseline: [DN-Splatter pinned source](https://github.com/maturk/dn-splatter/tree/97588b4290128ce7ba6fdbfaac3020b42b17de4c). Engine: [Open3D 0.19.0](https://github.com/isl-org/Open3D/tree/1e7b17438687a0b0c1e5a7187321ac7044afe275). Author/engine licensing does not grant a new license to repository-owned audit code; retained notices and existing repository ownership apply. No endorsement is implied.
