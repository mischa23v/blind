# Geometry audit update: fresh Open3D result and newly exposed support defect

**2026-10-28, 17:32 UTC.** This is an addendum to the [19-finding audit snapshot](FULL_REPORT.md), published at `caf1e0229d677b4fa62a501ce2bf344783dfc8cb`. Its historical “fresh reconstruction not run” statements describe the earlier checkpoint. This addendum updates the Open3D execution status without rewriting that evidence history. RTAB-Map is being provisioned/run under separately approved limits; no RTAB reconstruction result or ranking is established here.

## What has now run

Official CPU Open3D 0.19.0 completed a fresh Koivu reconstruction using the same 265 training frames, fixed supplied camera poses/intrinsics, and unchanged 29 excluded views. The 4 cm voxel, 20 cm truncation and 4 m depth cutoff are the earlier declared configuration. This is the project's documented adapter of the author algorithm, not an untouched execution of all DN-Splatter loaders: it uses original Polycam `transformations.json` rather than the upstream point-cloud loader's `transformations_colmap.json`, with declared image-I/O and output differences. No pose/refit selection was made to improve this score.

The new 242,293-vertex / 461,256-triangle mesh and initialization cloud are **byte-identical to the historical outputs**. This verifies reconstruction reproducibility. It does not establish useful navigation or that every modeled object is accurate. [Full results](../open3d-same-data-benchmark-20261028/fresh-run/RESULTS.md), [execution and attribution](../open3d-same-data-benchmark-20261028/fresh-run/README.md), [all numerical results](../open3d-same-data-benchmark-20261028/fresh-run/COMMON_GEOMETRY_RESULTS.json).

## New held-out reference measurement

All 29 excluded views were evaluated with 1,335,885 scheduled rays per mesh, using the same nearest-intersection query, integer-pixel sampling, and the fixed author registration. The reference transformation direction was checked against pinned primary upstream code, not chosen from whichever direction gave a better score. Its fixed scale is about 1.02079, applied once; reported residuals are phone-frame axial metres, not FARO Euclidean ray length. [Registration review](../open3d-same-data-benchmark-20261028/independent-review/REGISTRATION_REVIEW.md).

| Outcome | Count |
| --- | ---: |
| Both reconstructed and reference geometry return a hit | 1,187,988 |
| Reference hit only | 6,556 |
| Reconstruction hit only | 138,401 |
| Neither returns a hit | 2,940 |

On paired hits, median absolute difference is **3.40 cm**, mean **18.65 cm**, and the 95th percentile **113.83 cm**. The median is promising, but the long tail is substantial. Neither the median nor the fraction within ±10 cm is a navigation-accuracy or safety percentage. Missing returns are explicitly retained; they are not silently classified as clear or discarded to improve the score.

FARO processing/completion, unbounded registration uncertainty, scene changes, supplied poses and occlusion remain confounds. A reference disagreement does not by itself identify a real hazard, a phantom object, a sensor limitation or a defect in our adapter. This experiment did not test stairs, small toys, moving people, live localization, body sweeps or routes.

## Independent review and exploratory material

The main comparison passed an independent saved-array/hash/statistic and coordinate-algebra review: **12,236 checks, 2,310 floating comparisons**, maximum statistic difference approximately `8.88e-16`; all 58 query arrays and all 29 held-out recorded depth files were rehashed. The reviewer **did not repeat the full fusion or expensive mesh raycasts**. [Review receipt](../open3d-same-data-benchmark-20261028/independent-review/REVIEW.json), [recount script](../open3d-same-data-benchmark-20261028/independent-review/recount.py).

The result folder also contains a **post-hoc exploratory edge-strata diagnostic**. A separate independent recount now passes 92 checks and reproduces the edge strata exactly. In its smooth-reference stratum, 765,894 paired rays have a 69.45 cm 95th-percentile discrepancy and 48,420 differences above 50 cm. This shows that large differences persist outside that sampled edge category; it remains exploratory and does not establish the physical cause. No ray was excluded or parameter retuned. [Independent edge recount](../open3d-same-data-benchmark-20261028/independent-review/EDGE_REVIEW.json). [Exploratory output](../open3d-same-data-benchmark-20261028/fresh-run/EXPLORATORY_EDGE_STRATA.json).

The measured fresh fusion took 86.25 wall seconds with sampled peak process-tree RSS of 720,896,000 bytes. Sequential TSDF/FARO queries took 205.07 wall seconds with sampled peak 2,132,860,928 bytes. Restore/install took 121.08 wall seconds. These are cloud CPU measurements, not estimates of iPhone latency.

The child evaluator did not receive a separately frozen expected hash for the protocol JSON. Retained checksums and before/after input checks support reproducibility, not tamper-proof launch attestation. Resource figures are sampled process-tree measurements, not hard kernel containment or iPhone performance.

## Another concrete defect exposed behind the RoomPlan rejection

The same-file Apple comparison established that our zero-depth source-bound rule rejects exported solids and expanded outlines. Code review now identifies a second problem that rejection had masked: **the adapter classifies every triangle with a floor UUID as floor support, including slab sides and underside**. The export also expands the floor outline approximately 16 cm in each planar direction in these fixtures. Removing the original rejection alone would therefore admit the wrong support geometry.

The proposed correction keeps the raw exported scene separate from a source-bounded historical support polygon, and uses a released tessellator rather than invented polygon triangulation. Exported non-floor obstacle geometry remains intact. This is a **design proposal, not an implemented or tested fix**. Source floor polygons are processed RoomPlan model output, not current measured clearance. [Exact code points, proposal and regression gates](../roomplan-support-contract-proposal-20261028/PROPOSAL.md).

Before routing resumes, native all-feature vertex/triangle parity and the source-floor tessellation tests must pass, including concavity, boundaries, orientation, unsupported export-only rim and preservation of non-floor obstacles. Existing route pairs, body profiles and margins must remain visible and unchanged for the comparison. Current physical authority remains false.

## What this changes in the decision

1. **Our validation code is a demonstrated blocker for the two Apple fixtures.** It was wrong to use their failure as evidence that those rooms were physically too narrow.
2. **Open3D can reproducibly reconstruct the tested Koivu capture**, but the new held-out reference score still has large residual tails. Reproducibility is not clearance acceptance.
3. **No best engine is selected yet.** RTAB-Map and corrected RoomPlan ingestion cannot be ranked until their compatible tests actually run; these are also different input representations and must not be presented as a single identical-data contest.
4. **Geometry correction precedes new route claims.** Neither this result nor the support proposal establishes movement around the table, doorway exit, child safety or independent live use.

## Publication boundary and reproduction

This packet publishes text reports, fixed protocols, attribution, licenses, source/reproduction scripts and receipts. It **does not publish the optional approximately 63 MB derived mesh/query-array package** at this checkpoint. Raw photographs, depth images, original archives, FARO mesh, wheels and installed runtime are also excluded. References to local files in original receipts record what actually executed, not downloadable GitHub assets. The numerical recount requires the derived arrays or a new reproduction run; the text packet alone cannot execute the recount.

The main scripts and data acquisition instructions are retained with exact hashes, so the baseline can be reproduced after acquiring the pinned public data and approved runtime. MuSHRoom-derived evidence is attributed under CC BY 4.0; the copied DN-Splatter-derived code retains its Apache-2.0 license. The optional files must not be implied available through a broken public link. [Publication contents and limits](../open3d-same-data-benchmark-20261028/PUBLISHED_TEXT_PACKET.md).
