# Three-frame D1+N2 prefix: completed engineering check

**PASS for these three frozen records only. Accuracy was not evaluated.** Original training frames 00001, 00002 and 00003 retained their per-frame K, poses, depth/RGB bytes, full pixel order and 0 < axial depth < 4 m admission. All arms shared D1+N2, started empty, and used uninterrupted maps and persistent integrators. No reference/GT input, smoothing, classifier, serialization/reload, geometry export or full 265-frame run.

## Actual results

- **36 shared-validator tests passed** before recorded preflight, with zero engine constructions or native integration calls. All three frames then passed preflight before any engine was constructed. No rejected pixels or frames.
- Admitted counts: **433,900 / 429,680 / 432,840**. Each arm received the same **1,296,420 points, colors, normals and order**. These are submitted points, not independent voxel updates: endpoint merging, grazing and cached-gradient behavior affect updates.
- Normal reasons: 1,275,637 numerically valid; 4,025 boundary; 3,403 missing neighbor; 13,355 discontinuity; zero nonfinite or degenerate. All **20,783 unavailable normals retained their points**. Numerical validity is not normal accuracy or calibrated confidence.
- Every native update produced observations and zero nonfinite/negative-weight state violations.

| Final arm | Allocated voxels | Observed, weight > 0 | Unknown allocated | Nonzero gradients |
|---|---:|---:|---:|---:|
| B: projective | 700,416 | 166,557 | 533,859 | 0 |
| C0: NP, normals off | 700,416 | 166,556 | 533,860 | 0 |
| C1: NP, normals on | 700,416 | 167,354 | 533,062 | 65,678 |

**More observed voxels or gradients does not establish better geometry, safer support, fewer missed hazards or better route completion.** Observed TSDF voxels include non-surface regions. No accuracy ranking follows.

## Input-domain evidence

Original optical pose conversion was Cgl × diag(1, −1, −1, 1), without adjustment. Minimum axial depths were 0.919 / 0.814 / 0.968 m. Maximum Euclidean ranges were 4.662588 / 4.657310 / 4.644248 m, below the frozen 5.055 m limit. The largest scaled coordinate was 129.9845; the largest per-point ray index count was 191. World/local ray-length mismatch was at most 1.43052e−6 m. Native quaternion norms were within approximately 6e−8 of one; native rotation residuals were at most 2.292e−7. Actual weights met the source-derived positive, finite bounds.

Preflight checked original arrays and order, normal/weight domains, proper pose and quaternion, the prefix-only 16 m translation bound, nonzero finite physical rays, truncation-extended scaled coordinates and index counts, and nonempty frames. `MERGED_DOMAIN_REVIEW.md` derives conservative float aggregation and transformation bounds for these records and settings—not arbitrary future inputs. Post-integration finite-state inspection remains necessary. Native D2 invalid-input handling was not patched or exercised with invalid data.

## Resource and integrity receipt

One worker/CPU; **8.178346 s wall**, **8.04 conservative sampled CPU seconds**, **587,558,912 bytes peak summed RSS**. Caps were 60 CPU seconds, 90 wall seconds, 2 GiB RSS and 256 MiB new output. No cap, retry, network, installation, new core build or spend. All **267 frozen inputs remained unchanged**. ELF checks resolved only the isolated D1 core. Outputs stayed in the dedicated run directory.

This includes compilation, raw preflight and nine native updates. Three-frame integration plus state scanning took approximately 0.441 / 0.525 / 0.511 s per arm in this environment; these are not iPhone or live-system performance measurements.

Final admitted freeze: `e4bb5ae5176929cfe4e035acf08ba585fdf0332ce5e7001ce7e781e5fdc8a519`. Earlier unexecuted source/freeze remains in `pre-review/`. Raw logs retain denominators, range-by-reason counts, commands and state details. The publication packet contains source and aggregates, not raw depth/RGB or the pose manifest.

## Limits and next decision

This establishes bounded ingestion and numerical-state admission for three records only. Recorded N1-versus-N2 quality was not compared. Historical stock arm A remains unpatched while the new arms share D1; engine claims must not conflate that ray fix. B/C0 differ beyond normal availability, and C0/C1 bundles correction, cached gradients and grazing.

Small 2/4 cm hazards, reliable floor support, unknown-space handling, complete shape/clearance, pose/calibration errors, dynamic objects and collision-free route tails remain unresolved. Earlier upstream resource blocking, unavailable leak checking, serialization gradient loss and the original failed baseline remain recorded. A static prefix does not prove live blind-navigation safety or a 90% gain.

**No automatic full run, export or scoring is authorized by this result.** Further evaluation needs a separately frozen protocol, unchanged metrics and explicit admission; observed-voxel counts must not substitute for hazard misses, false blockage or failure tails.
