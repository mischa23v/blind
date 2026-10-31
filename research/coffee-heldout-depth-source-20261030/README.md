# Fixed held-out depth consistency evaluator — prepared, not run

This is a finite next diagnostic after the 38 actual read-only OctoMap controls passed. **Neither held-out depth raster has been opened by this preparation. No new map/native execution, depth extraction, accuracy result or clearance decision is claimed.** Nine pure metric controls and five synthetic-archive extraction controls passed. Their fabricated archive bytes are not sensor data.

## Frozen inputs and actual native prerequisite

- Construction only: original frames 00290, 00357, 00391, unchanged projection/K/pose convention `T @ diag(1,-1,-1,1)` and native defaults/resolution 5 cm.
- Held-out depth only: 00232 and 00370, exactly the already frozen metadata/frustum selection, never substituted after results.
- Candidate ray source: `coffee-octomap-readonly-rays-v2-source-20261030`, published at `e9088cf7d17c23d9486d5d380e8a2eeb9634b267`.
- Actual binary SHA256: `fa53b4153a7c1765880eabf5f8029d87173af6ed4ecdb425ea37f5d1d799bd84`.
- Passed 16 original + 22 new controls receipt SHA256: `0e9fc37f627db97423ed1c4c36ef44927bcc9eb0ab104b01a2f60a4b0417a166`.
- Actual build receipt SHA256: `7ea517485f255d41ba13d1676ccef7c3e2986187236aa7780a498503515de87d`.

`INPUT_PINS.json` binds input/source/receipt bytes. The invocation must supply the independently reviewed binary and controls receipt hashes; arbitrary hashes are refused. There is no native NPZ loader: the evaluator really reconstructs the map from only those three construction rasters, then compares every canonical uncompressed exported NPY member against the saved baseline. World endpoint float64 bytes and all original insertion counters must also match. Any mismatch stops before opening held-out data.

## Two-member extraction, after baseline identity

From the retained, SHA-bound 183,080,957-byte Coffee archive, read only the exact depth members into a fresh local output/depth directory. Selected members must be regular, unique, at most 1 MiB each/2 MiB total; archive membership is limited to 2,000 entries. Paths are never passed to tar extraction: only the two fixed basenames are written exclusively. Missing, duplicate, link or oversized selected members fail. Unrelated members are not materialized or inspected. Archive SHA is checked before and after. RGB is not opened. The resulting depth hashes are newly recorded without editing the original selection.

## Metrics frozen before holdout access

1. Full 738×994 raster denominator with zero-depth, >=4m exclusion and accepted 0<z<4m counts.
2. Full accepted endpoints queried against the three-frame map: pixel-weighted and distinct-key-weighted known occupied / known not occupied / unknown. Hit-and-free conflicts are a separate overlapping category, not another partition class.
3. Fixed original pixel grid u%8==0 and v%8==0: exactly 11,625 candidates per frame, with zero/range exclusions retained. Every valid candidate is queried in batches of at most256. No ROI, favorable-view subset, resampling or threshold tuning.
4. Query max range is four metres axial times world-direction norm; preserve the official center-based range test and unknown-stop semantics. Reject the whole experiment if metadata requires a range beyond the existing8m ABI bound; never clamp.
5. All ray statuses are counted separately. Only `hit-known-prefix` from a known-not-occupied origin receives residuals. Unknown origin/gap, occupied origin, bounds/input/range/intersection failures and unresolved cases remain unscored, never zero-error or clear.
6. Primary residual: official voxel-entry point converted back with the **exact inverse** of the same supplied 3×3 camera rotation, minus original axial recorded depth. Center axial residuals are separately labeled; centers are never substituted for entry points.
7. Along-ray residual: native entry projection minus measured endpoint projection, both using the actual Float32 native origin/direction. This avoids mixing original-double and native-Float32 ray conventions.
8. For each residual stream, publish signed and absolute min,p05,p25,median,p75,p95,max,mean,RMS and count. Quantiles use linear interpolation at (n−1)p. Keep every finite scored residual; no clipping, guessed tolerance subtraction or invented accuracy cutoff. Empty samples produce null distributions.
9. Before and after each holdout, scan/evidence/tree state, defaults and every canonical NPY payload hash must be identical to the reconstructed baseline. Holdout paths never insert, update or alter thresholds.

The fixed coordinate-domain rejection |coordinate|<100m protects unchanged baseline native endpoint-query conversions. It is a conservative input bound, not a filter: reject the entire frame if exceeded. It does not alter any retained endpoint in the baseline.

## Resource and run boundary

Same established limits: one CPU,120 CPU seconds,512 MiB address space,175s internal alarm,178s external TERM plus2s KILL,32 MiB per-file cap,500,000 nodes/leaves. No downloads, installation, paid services, namespace/security changes or native build. The only new persistent data is two depth PNGs and a text receipt, kept local. Preserve every incomplete/failing output directory; no automatic retry, budget increase or view replacement.

Run only after independent review, verified source publication and root admission. From the workspace, with exact reviewed paths:

```sh
bash blind/research/coffee-heldout-depth-source-20261030/run_bounded.sh \
 /opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12 \
 /workspace/scratch/90f3f6703064/blind/research/coffee-octomap-readonly-rays-v2-source-20261030/build-readonly-02/libblind_octomap.so \
 fa53b4153a7c1765880eabf5f8029d87173af6ed4ecdb425ea37f5d1d799bd84 \
 /workspace/scratch/90f3f6703064/coffee-readonly-ray-controls-attempt-001/RESULT.json \
 0e9fc37f627db97423ed1c4c36ef44927bcc9eb0ab104b01a2f60a4b0417a166 \
 /workspace/scratch/90f3f6703064/coffee-heldout-depth-attempt-001
```

Root must externally verify the exact final manifest before running and retain exit/stdout/stderr/resource evidence. The script validates local input pins but does not attest a Git commit by itself. CPU/RSS in the receipt are worker metrics, not an independently sampled process tree. A timeout or killed process is incomplete, never passing.

## Interpretation and subsequent comparison

This is **same-capture view-to-map consistency**, not sensor accuracy or independent calibration. Shared pose drift, smoothing, occlusion, sparse observations and occupied voxel discretization remain confounds. Frame232's opposite view may have low/zero known-prefix visibility; retain that outcome. No unaligned Polycam OBJ, FARO reference, LLM judgement or camera path is used to declare rays clear. No path/body/support/localization/physical guidance follows from a favorable result.

After this finite diagnostic, report both coverage and residuals. A later TSDF comparison must use the same camera convention, construction frames, heldout set and visibility denominators. No TSDF result or implementation is included here. Only text summaries/source/hashes should be published; the extracted PNGs remain local.
