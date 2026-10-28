# Fresh Open3D replay and independent registered-reference score

**Completed 2026-10-28. This is a reproducible reconstruction baseline, not a navigation pass.**

## What actually ran

The official CPU Open3D 0.19.0 engine integrated all 265 original training frames from MuSHRoom Koivu, with the original supplied camera intrinsics/poses and unchanged 29-frame exclusion list. It used the prior author-configured 4 cm voxel / 20 cm SDF truncation / 4 m depth cutoff, millimetre depth decoding, and unchanged OpenGL-to-OpenCV pose conversion. No reference-based fitting, cleanup, decimation, floor reclassification or route generation occurred.

This replays our declared adapter of the author algorithm, not an untouched end-to-end DN-Splatter program. In particular, it consumes the original Polycam `transformations.json` while the pinned DN-Splatter point-cloud loader names `transformations_colmap.json`. Historical preparation recorded equal parsed frame arrays; this run newly verifies the original pose-file hash and reuses that same original file. Other declared loader differences include Open3D image I/O instead of OpenCV, refusing shape mismatches instead of resizing, fixed random seeds, and an additional native final-mesh export.

Primary upstream source now verifies the registration direction: MuSHRoom's pinned `evaluate_mesh.py` applies `icp_iphone.json`'s `gt_transformation` to the predicted iPhone-coordinate mesh before comparing with unchanged FARO geometry. Our evaluator equivalently transforms camera rays once into FARO coordinates. See `../independent-review/REGISTRATION_REVIEW.md` for pinned primary links. No inverse/forward selection was based on which produced better results.

It produced **242,293 vertices and 461,256 triangles**. The complete unfiltered mesh and author-style initialization cloud are **byte-identical to the prior baseline outputs**:

- Mesh SHA-256: `5a75ebce93a3c65928344ce486223aa17a01a2c196982fc97edff8c41dd56e2e`.
- Cloud SHA-256: `052518207750369556da9f3253f473a5d8776df228a35aaec8eee9498d0c2c1a`.

The worker body is AST-identical to the earlier fusion worker except that its result JSON now goes to a dedicated file. This fixes the old stdout warning/JSON reporting collision without changing reconstruction. Reproducibility does not imply that the geometry is accurate enough for guidance.

## New comparison: all 29 excluded views against FARO

Both reconstructed TSDF and original reference geometry were queried using the same reviewed VTK nearest-intersection implementation, the same fixed camera rays and original author registration. There were **1,335,885 scheduled rays per mesh**, with integer pixel centres and stride four. No ray selection was based on agreement, and no missing ray was silently removed from availability accounting.

| Availability | Rays |
| --- | ---: |
| Both meshes return a hit | 1,187,988 |
| Reference hit, no TSDF hit | 6,556 |
| TSDF hit, no reference hit | 138,401 |
| Neither mesh returns a hit | 2,940 |
| **Total scheduled** | **1,335,885** |

These categories are numerical coverage disagreements, not proven real-world obstacle or false-obstacle labels. In particular, a missing reference hit is not proof that the TSDF surface is false, and a missing TSDF hit is not free space.

| Absolute axial-depth difference on paired hits | All ranges | Reference depth below 4 m |
| --- | ---: | ---: |
| Paired rays | 1,187,988 | 1,036,454 |
| Median | 3.40 cm | 3.39 cm |
| Mean absolute difference | 18.65 cm | 15.72 cm |
| 90th percentile | 33.77 cm | 27.79 cm |
| 95th percentile | 113.83 cm | 90.94 cm |
| 99th percentile | 311.70 cm | 248.12 cm |

The typical paired ray is fairly close, but there is a **substantial long tail of disagreement**. A small median does not validate room clearance, and the approximately zero pooled signed mean merely reflects positive and negative differences cancelling.

At the predeclared ±10 cm descriptive tolerance, 948,693 of 1,187,988 paired rays are within the band (79.86%); 102,975 hit earlier and 136,320 later. **This is not a navigation success rate or a safety accuracy figure.** The tolerance is not a safety threshold.

Per-frame results are retained. For example, `frame_00228` has a 4.65 cm median but a 3.55 m 95th-percentile difference; `frame_00197` has a 3.26 cm median and a 3.33 m 95th percentile. These are candidates for spatial investigation, not automatically sensor defects: occlusion, differing scene state, capture poses and reference processing/registration remain confounds.

## Exploratory check: are the large differences only at reference edges?

A separate post-hoc diagnostic uses the existing four-neighbour edge classifier on the stride-four reference depth grid. This does not change the main score or exclude any ray. Among 765,894 paired rays whose reference neighbours differ by at most 2 cm, the median discrepancy is 3.00 cm but P95 is still 69.45 cm, with 48,420 discrepancies above 50 cm. Larger discontinuities have worse error distributions. Therefore the long tail cannot be dismissed solely as the sampled reference-edge category, although this diagnostic does not identify the physical cause. Details: `EXPLORATORY_EDGE_STRATA.json`.

## Same-capture held-out sensor check

Using the same fresh TSDF ray results and unchanged recorded depth files reproduces the previous held-out consistency result: 1,161,037 paired rays with measured sensor depth below 4 m; median absolute difference 3.17 cm, MAE 14.50 cm, P95 73.06 cm. This is a separate comparison against held-out processed phone depth, not independent physical ground truth.

## Measured execution resources

| Phase | Wall seconds | Process-tree CPU seconds | Sampled peak tree RSS |
| --- | ---: | ---: | ---: |
| Restore and isolated install | 121.08 | 15.34 | 72,368,128 bytes |
| Fresh 265-frame fusion | 86.25 | 86.20 | 720,896,000 bytes |
| Sequential TSDF and FARO queries | 205.07 | 204.81 | 2,132,860,928 bytes |

Core timed phases total about 412.40 wall seconds and 306.35 CPU seconds; setup, source review, small post-run integrity checks and report writing are separate. New allocated stage storage after query execution was 1,946,767,360 bytes. Package/data payload transfer was 723,560,005 bytes, with additional small source/metadata reads within the 750 MB ceiling. Fusion and reference query workers did not overlap.

Memory values are sampled process-tree RSS, **not hard kernel containment**. The environment does not expose a verified aggregate cgroup limit. This is a cloud CPU measurement, not iPhone performance.

## Verdict and next use

- **Reconstruction reproducibility: passed.** Exact input hashes, frame split and engine output were reproduced.
- **Held-out reference comparison: completed with all scheduled rays accounted for.** Large residual tails and missing-hit differences remain.
- **Best reconstruction method: not established.** This result cannot rank RTAB-Map, other reconstruction engines or corrected RoomPlan ingestion that have not run under the same data contract.
- **Navigation/clearance readiness: not established.** No route, full-body sweep, dynamic obstacle trial, physical localization, stair detection or small-toy detection was tested.

Keep this as the frozen comparator. Subsequent candidates must be evaluated on the same split and rays, with false blockages and missed geometry measured separately, before selecting an engine or resuming pathing claims.

## Reproducibility qualifications

`FINAL_INTEGRITY.json` rehashes all pinned sources/inputs plus acquired archives and wheels after execution. Query workers check every listed source/geometry/pose pin before and after. The evaluator launch did not pass a separate externally frozen expected hash of its protocol JSON; the retained protocol checksum is post-run, and the file was not edited during execution. Do not overstate that as tamper-proof launch attestation.

Archive extraction used exact SHA-pinned archives, guarded member paths/types and selected-output caps. It did not add an independent running decompressed-stream counter. `ARCHIVE_STREAM_CHECK.json` records the original gzip trailer lengths matching the previously measured decompressed streams; trailer ISIZE alone is modulo 2³² and is not an independent substitute for decompression validation.

See `README.md` for code/source/data attribution and licenses, `COMMON_GEOMETRY_RESULTS.json` for every measured number, `fusion/RECEIPT.json` and `EVALUATION_RECEIPT.json` for execution receipts, and the per-view arrays for an independent recount.
