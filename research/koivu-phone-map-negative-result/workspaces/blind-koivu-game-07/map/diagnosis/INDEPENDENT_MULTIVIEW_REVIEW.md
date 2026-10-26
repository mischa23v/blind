# Independent multiview diagnostic review

Read-only source and saved-result review, 2026-10-26. No original images/depth, VTK, FARO geometry, mapping rebuild or navigation was run by this reviewer. No frozen source, protocol or result was edited.

## Source/result pins

- `diagnose_multiview.py`: `7a7e5c6d76113c0bd9eaa5ac994558b8a482541b563cfa691be583a067922dc4`.
- `DIAGNOSTIC_PROTOCOL.md`: `cb0ae46dc3421c9b6c9d4981b4c5276457392c205415deeeb94a9df6678faaae`.
- `multiview-run/RESULTS.json`: `ab0858714ad1ada919cdae9dc0f4123d4055132121384cd91814de4f6bfa05ee`.
- Existing phone input/source cut: `d69e2c1bd61ebb61d307056e53f5c8b653e06eb9ae8189667fa425500461b350`.

## Findings

No concrete projection/indexing/bin-accounting bug was found. The source matches the fixed stride-8, original-pose/intrinsics protocol; uses the same half-pixel forward/inverse convention; requires a complete positive 3×3 target neighbourhood; and separates source missing, projection unavailable, neighbourhood unavailable, candidate free contradiction, fully occluded, central agreement and other/edge outcomes. The body subset is relative to the declared fitted approximation `phoneZ+1.275`, not independently measured gravity.

Independently read the saved JSON and verified all **293 pairs i→i+1** and **264 pairs i→i+30** in their exact order; every per-pair category sum equals its scheduled count; every aggregate category and body-band count equals the sum of its pairs; and all 294 per-frame patch records remain present in order. These are recounts of the same data, not new experiments. Pooled residual quantiles were not recomputed from raw residual arrays because those arrays were not retained; they remain source/owner-computed values.

| Fixed lag | Scheduled samples | Available target comparisons | Available fraction | Candidate free contradictions | Fraction of available |
|---|---:|---:|---:|---:|---:|
| 1 frame | 3,406,125 | 2,329,759 | 68.40% | 207,735 | 8.92% |
| 30 frames | 3,069,000 | 143,306 | 4.67% | 42,722 | 29.81% |

The larger lag's 29.81% is a result for a **small-overlap subset**, not the entire sequence. No unavailable projection is counted as agreement. Body-band candidate contradictions are 135,435 / 1,356,369 available (9.99%) at lag 1 and 28,882 / 90,513 (31.91%) at lag 30.

## Interpretation corrections

“Observed-free contradiction” should be read as a **cross-view inconsistency candidate**, not a proof that a physical scene is impossible or that the phone sensor is wrong. Export processing, pose error, actual scene motion, finite angular/pixel sampling, thin surfaces and disocclusion can contribute. Even a positive 3×3 minimum is not a measurement exactly on every continuous ray through that footprint. Near-horizontal patch candidates are not semantic floor labels; table surfaces can qualify. None of these statistics supplies a valid endpoint-removal rule or confidence value.

The source's 1 GiB RSS condition is checked at the end using `ru_maxrss`, while its address-space hard limit is 2 GiB; it is not a live hard 1 GiB RSS cap. The successful report states approximately 14.24 wall seconds, 14.57 CPU seconds and 240,181,248 bytes peak RSS, so the observed run is below that threshold. Hash checks of original inputs before/after belong to the source execution; this independent review did not reread all original PNG bytes.

This is useful diagnosis of the preserved phone map's restrictive endpoint union. It does not authorize filtering, widening the floor band, changing registration, using FARO to choose a map, treating confidence as known, or launching the proposed game. The intended phone-plus-belt/additional-sensor architecture remains outside the scope of this one processed-recording diagnostic.
