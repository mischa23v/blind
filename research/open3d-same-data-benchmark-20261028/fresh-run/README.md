# Fresh Open3D same-data reconstruction and held-out reference evaluation

This is an actual fresh CPU execution, using the same MuSHRoom Koivu iPhone processed capture, original supplied poses/intrinsics, and original 265-training / 29-excluded split as the saved author baseline. No frame subset was selected for better results. This is our declared adapter of the author algorithm, not the untouched DN-Splatter pipeline: original Polycam transformations.json is used rather than the pinned upstream loader's transformations_colmap.json, alongside documented image-I/O, seed and output differences. The library is official `open3d-cpu==0.19.0`; this is not RTAB-Map and not a fresh live ARKit trial.

## Reproduction and provenance

Create empty `archives`, `wheels`, `source`, `environment` and `logs` directories in this stage folder before starting. Keep the published sibling DATA_CONTRACT, resource-proposal and evidence files in their relative locations. The host must match the pinned reused-distribution metadata; otherwise restoration fails rather than silently resolving a different runtime. Existing output folders are not overwritten. Verify SHA256SUMS from the parent open3d-same-data-benchmark-20261028 directory.

1. `restore.py` restores the two pinned public release archives and exact 28-wheel official PyPI closure from `../resource-proposal/ACQUISITION_PROPOSAL.json`, verifies hashes, selectively extracts public data, and installs into `environment/target` without global installation.
2. `prepare_fusion.py` compares every training RGB and all 294 depth hashes with the historical manifests, then remaps local paths into `FUSION_FROZEN.json`.
3. `run_fusion.py` invokes `fusion_worker.py` under the sampled process-tree resource watchdog. `WORKER_EQUIVALENCE.json` records AST equality with the existing author-configured fusion worker except result output serialization. Open3D performs integration, cloud extraction and mesh extraction. No mesh cleanup, completion, decimation or alternate floor rule is applied.
4. `run_evaluation.py` runs two serial workers through `evaluate_common.py`: first the TSDF mesh, then the original FARO mesh. They use unchanged `source/reference_geometry.py` VTK first-hit queries and the same 29 excluded camera views, fixed stride 4 and integer pixel centres. The original author `gt_transformation` is applied once from phone coordinates to FARO coordinates, never refitted.
5. `summarize_common.py` compares all 1,335,885 scheduled rays without outlier removal or missing-hit removal. It also computes same-capture held-out processed-depth consistency from the unchanged original depth rasters.

The result files and receipts distinguish completed execution from accuracy conclusions. Source input dimensions are 738×994 processed exports, not independent native LiDAR measurements at every pixel. The original confidence and tracking streams are unavailable. Held-out views use supplied capture poses; this does not evaluate live localization.

## Resource scope

Approved ceiling: 750 MB transfers, 3 GiB new allocated disk, one serial logical CPU worker; sampled process-tree RSS abort thresholds 2 GiB for fusion and 3 GiB for reference scoring. No GPU, Docker, model weights or source compilation. The environment does not expose a verified hard aggregate cgroup RAM limit, so watchdog sampling is not kernel containment. Actual measurements are in the execution receipts.

Package/data payload downloads total 723,560,005 bytes; additional small source/metadata reads remain within the 750 MB envelope. Runtime wheels, installed packages, raw RGB/depth, archives and the large FARO file are local execution material and must not be included in the publication allowlist.

## Interpretation limits

A registered-reference residual is not a physical collision label. FARO includes author processing/completion and lacks a measured-versus-edited face mask; its registration uncertainty is not bounded here. Missing TSDF surfaces are not free space. No small-toy or stair label set, dynamic obstacle experiment, full-body sweep, route trial or child trial is included. This test cannot establish a safe-navigation percentage or select the best system until comparable alternative systems are actually run.

## Attribution and licenses

MuSHRoom by Xuqian Ren et al.: iPhone Basic Data, DOI https://doi.org/10.5281/zenodo.10230733 ; reference mesh/point cloud, DOI https://doi.org/10.5281/zenodo.10222321 . Data and derived geometry/arrays: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/ . The outputs are derived geometry and sampled numerical comparisons; no endorsement by the data authors is implied.

Open3D 0.19.0 is MIT: https://github.com/isl-org/Open3D/tree/v0.19.0 . The author-configured recorded-iPhone integration derives from DN-Splatter commit `97588b4290128ce7ba6fdbfaac3020b42b17de4c`, Apache-2.0; its license is retained in `source/DN-SPLATTER-LICENSE`. VTK, NumPy, Pillow and other library binaries are not redistributed in this packet. The original mapper adapter changes are documented in the prior baseline and this stage changes only materialization, path binding, reporting and the fixed evaluation wrapper.
