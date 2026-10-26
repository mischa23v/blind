# Independent Coffee saved-evidence review

**Result: the finite route-availability summaries are supported; they do not establish whole-room traversal or movement validation.**

The independent recount verifies all 18 manifest hashes, manifest identity shared by results and run receipt, all 42 ordered endpoint pairs exactly once for each profile, accepted-path exact requested endpoint retention, endpoint association flags, and path lengths recomputed directly from saved coordinates (absolute tolerance 1e-12 m for independent floating-point summation). Counts reproduce as 16 / 14 / 18 accepted for the 45 cm, 55 cm effective-envelope and abstract 28 cm profiles. The three maximum lengths reproduce as 2.12248 / 2.15127 / 2.08849 m; maximum accepted endpoint displacement is 2.05 m for each.

The same 24 directed queries are native-incomplete for all profiles, exactly the cross-group pairs between endpoint IDs {0,1,5,6} and {2,3,4}. All endpoints reportedly lie in one raw 4-connected walk component, which is not the same as configuration-space/native connectivity. This audit did not recompute raster topology or endpoint selection from NPZ arrays.

## Source/data separation

Source inspection confirms `prepare()` writes endpoints and the frozen manifest without creating an engine; `main()` requires the matching manifest, verifies all file hashes, checks the repeated selector result, and only then constructs the profile engines. The selector operates solely on `walk` and `lo` under the declared EDT/extreme/tie policy. The source explicitly materializes only the eight phone-mask fields and metadata keys `lo`, `res`, `R`, `t`. Parent profile loading reuses the pinned dimension definitions and native library; it does not call the original Koivu map constructor. Full-file hashing reads compressed NPZ bytes for identity but does not materialize reference arrays or pass them to planning. The access log is self-reported and corroborated by source review, not independent OS-level tracing.

The fixed profiles preserve 0.45 x 0.30 x 1.60 m with zero margin; that body with 0.05 m horizontal margin per side (0.55 x 0.40 m effective footprint); and abstract 0.28 x 0.30 x 1.60 m with zero margin. Native proposal radii remain 0.225 / 0.275 / 0.150 m and planner cells remain 0.025 m. The inherited checker is a sampled planar rectangle test, not continuous body/vertical clearance.

## Reporting cautions

- Two accepted ordered queries per profile are only **5 cm** long (endpoints 0 and 6). Only **two ordered accepted queries per profile** are at least 2 m long. Accepted counts must not be described as physical-area coverage.
- The endpoints span 5.0 x 3.1 m, but accepted paths connect only local groups. No frozen cross-group traverse succeeds.
- Every accepted route's saved sampled-footprint diagnostic contains low-unresolved cells. Recount ranges are 72–503 / 130–640 / 56–340 cells. This audit verifies those saved counts' aggregation, not their underlying raster computation.
- No new route query, NPZ array load, FARO triangle score, synthetic actor advancement or physical movement occurred in this independent review.
- Freeze ordering is supported by source control flow and matched artifacts; there is no external timestamp attestation.

The bounded run receipt reports success, 1.685114 CPU s, 1.713457 wall s, and 57,110,528 bytes peak sampled-or-waited RSS. Original evidence is unchanged. `RECOUNT.json` and `recount_saved.py` provide the independently reproducible saved-data checks.
