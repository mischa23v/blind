# Fixed fine fused-map held-out comparison — prepared, not executed

## Separate, explicitly allocated offline protocol
This is a new serial research protocol, not a retry that silently changes earlier limits. The parent explicitly allocated the existing broader native-benchmark envelope: **1 GiB address-space limit, 1 GiB RSS stop, 120 CPU seconds, 180 wall seconds, one CPU, 32 MiB per file**. No paid service, download, installation or native build. Earlier 512 MiB protocols and the failed 500k enumeration attempt remain unchanged.

Only the existing reviewed library with 48 passed controls is used. Neither this budget nor finer voxels relaxes a physical-safety rule or authorizes live movement.

## Frozen order and data
1. Rebuild the original 5 cm map from frames **290, 357, 391**, original full accepted depth points, supplied poses and insertion order. Require original world-coordinate hashes, insertion receipts, native state/defaults and canonical payload hashes exactly.
2. Extract only the previously fixed held-out images **232 and 370**, require their bytes match the original run, and query both modes. Require the complete original coarse endpoint coverage, fixed-grid denominators, conservative statuses/residuals and observation-only statuses/residuals to reproduce exactly. Preserve all original primary records, including 18,904 origin-unknown rays and zero primary residuals.
3. Close the coarse map. Build the fine **2.5 cm** map from the identical three input frames, original points/poses and scan order. Check counts and world hashes again. Check native state after each insertion against **2.2M nodes and 2.2M leaves**; stop before export/scoring if exceeded. Probability defaults must match coarse exactly; only resolution differs.
4. Query the same fixed two held-out views with the same full raster endpoint coverage, stride-8 grid, depth range, ray directions/ranges and residual definitions. No new hold-out choice, crop, threshold, denoising, registration or source-frame admission.

One native map is resident at a time. The two already selected held-out rasters are reused, never inserted into either map. Native defaults/state/canonical payloads must remain unchanged around every read-only scoring pass.

## Modes and denominators
- **Primary:** original conservative unknown-first ray query. Every known-prefix hit is scored; unknown origin, unknown-before-hit, occupied origin, range exhaustion and errors remain separate. An empty primary score is null, never zero error.
- **Secondary:** explicit observation-only upstream `ignoreUnknown=true`. Only status9 hits are scored; they remain visibility-unverified and cannot establish intervening clearance. No automatic fallback or replacement of primary status.
- Full raster, valid/excluded pixel and all 11,625 grid-candidate denominators remain frozen for each view. Endpoint coverage is pixel-weighted and distinct-key-weighted; distinct-key totals can change at finer resolution.
- Entry-axial, center-axial and entry-along-ray residuals remain separate, with the exact inverse supplied pose and Float32-native-ray projection convention, unchanged quantiles and no clipping. Every mode's returned hit is scored. Per-hit pixel/residual arrays are saved for later paired comparison; disappearing hits cannot be disguised as better geometry.
- Completed per-view JSON receipts and partial progress remain available on failure. No automatic retry, bound increase or production-resolution selection.

## Prospective memory assessment
The measured fine singleton node sum is 2,145,238, motivating the separately frozen 2.2M enumeration cap. The fine singleton leaf sum is 1,848,893; this is an upper bound on same-lattice known-cell union before shared overlap, not a measured fused size. Exact fine fusion size is not yet known.

At that leaf sum, canonical exported arrays occupy approximately **96.14 MB** (52 bytes per leaf). At the full 2.2M cap, they require **114.4 MB**. The largest array is 40 bytes per leaf. Canonical NPY hashes stream into a counting SHA writer, avoiding a second complete serialized-array buffer; NumPy chunk temporaries, native tree/evidence storage, input/projected arrays and allocator overhead still count. Canonical map arrays are hashed, not written as files larger than 32 MiB. Small per-hit outputs remain below that file limit.

The earlier largest singleton run peaked at 243,852 KiB RSS, but RSS cannot establish future fused virtual-address use. **1 GiB is a hard experiment budget, not a guaranteed fit.** RLIMIT_AS enforces the address-space ceiling; peak RSS is checked at map-state/export boundaries and after fine insertions. CPU/wall controls remain unchanged. Native insertion is protected by process limits, while enumeration checks occur after each fine insertion and before export. If any limit fails, stop and retain the failure without increasing it.

## Exact command after independent review and publication
From `blind/`:

```sh
bash research/coffee-fine-fused-heldout-source-20261030/run_bounded.sh /opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12 research/coffee-octomap-observation-rays-source-20261030/build-observation-01/libblind_octomap.so 82afb6c94b3e0234ee371395b6f7ba17ae159987293ac357463bde43605ebc26 ../coffee-observation-ray-controls-attempt-001/RESULT.json 51624c3c11456971709fd41ef6bd2b63f303e7f0df1b58bec5403d73d607f3e4 ../coffee-fine-fused-heldout-attempt-001
```

Source-only controls: 12 metric, 5 synthetic extraction and 6 small streaming-NPY equivalence tests. They do not load OctoMap or read dataset rasters. No native execution has occurred for this source. This measures supplied-pose reconstruction consistency, not hardware accuracy, obstacle recall or human/child navigation safety.
