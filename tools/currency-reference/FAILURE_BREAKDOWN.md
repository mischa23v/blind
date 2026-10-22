# Retained historical failure details

**Historical source excerpts only; not results from reconstructed code.** The original complete per-query table and candidate JSON cannot be recovered exactly. This document preserves only specific values available in the retained conversation, without inventing the missing rows.

- 50: visible reference/query design appeared consistent, but source edge was close to the frame. Prepared SIFT: 84 inliers, ratio 0.318, reference/query spreads 0.145/0.095 and out-of-frame quad. ORB: 28 inliers, low spread, score 3.61 and out-of-frame quad. AKAZE: 36/100 consensus, plausible in-frame quad, rejected below the frozen 0.42 ratio.
- 200: visible commemorative design matched; query was waved/creased. SIFT: 137 inliers, ratio 0.413 and a corner about 7 pixels above the image. ORB: 95 inliers, out-of-frame corner. AKAZE: 72 inliers, reference spread 0.197 and four occupied grid cells, below 0.20/five. A single planar transform was imperfect for the curved note.
- 500: SIFT/ORB/AKAZE respectively found 150/56/124 unique inliers but extrapolated a corner to y approximately 1319–1333 in a 1200-high image. The query was clipped/curved near the lower-left edge. Many inliers did not override the full-frame gate.
- Polymer 5: ORB accepted its paper-5 reference hypothesis, 46 inliers, so did not demonstrate material discrimination. SIFT's polymer hypothesis had 81/279 inliers, ratio 0.290. AKAZE's paper hypothesis had 65 inliers with out-of-frame/low spread; polymer hypothesis had 51 inliers with low spatial support.
- Historical 1 composite: all three accepted the front while failing to identify the unsupported back region. This was a single-note-policy false acceptance even though label 1 was correct.
- All methods reportedly abstained on the five partial/folded cases and two unsupported-side cases, and on the USD/apple images. Exact candidate-by-candidate rejection details are not recoverable here.

The original 17-case query list was: flat 100 A; folded same 100 A; folded 10 front; folded 10 back; low-resolution unsupported 100 back; USD; apple; folded 50; unsupported folded 200 back; waved 200 front; folded 500; paper 5; polymer 5; historical-1 front/back composite; clean 10 front; clean 50 front; normalized rotated/clipped 500 front. These are case descriptions, not a recovered reproducible manifest.

No thresholds were relaxed in response to those historical failures. No fresh failure statistics, full note count, authenticity, current-issue status or phone readiness can be inferred for the recovery version.
