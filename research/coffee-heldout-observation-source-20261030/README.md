# Fixed two-view observation-only diagnostic — prepared, not executed

## Purpose
The primary conservative test remains unchanged: both camera origins were unknown, all 18,904 valid rays were origin-unknown, and **0 residuals were scored**. This separate experiment asks whether the first *observed occupied voxel* along each held-out ray agrees with the measured endpoint. It uses official OctoMap `castRay(ignoreUnknown=true)` through the separately reviewed observation-only ABI. It does not establish free space, visibility, true surface location, safe movement, or sensor accuracy.

## Frozen experiment
- Reconstruct frames 290, 357 and 391 with the exact original projection, supplied poses, default probabilities and 5 cm resolution. Require canonical arrays plus state/defaults to match the original primary run before extracting held-out depth.
- Keep held-out frames 232 and 370, original 738 × 994 rasters, axial 0 < depth < 4 m, grid stride 8, and all 11,625 candidate positions per frame. No frame selection, threshold changes or rejection of inconvenient rays.
- Require extracted bytes identical to the primary run. Preserve all primary frame records verbatim in `primaryResultsRetained` and bind their published JSON hash.
- Query the conservative ABI again at every valid grid ray; require the status partition identical to the primary run. Query the observation-only ABI separately at every same ray. Status 9 is `observed-hit-visibility-unverified`, never `hit-known-prefix`.
- Score every observation-only occupied hit; range exhaustion, unknown or error statuses do not become zero residuals or clear space. All ray status counts and full grid/raster denominators are retained. Endpoint coverage is both pixel-weighted and distinct-key-weighted, and must exactly match the primary result.
- Keep voxel surface-entry and voxel-center axial residuals separate. Entry here means intersection with the occupied *voxel box*, not a measured physical surface. The original exact inverse of the supplied transform computes axial predictions. Along-ray projection uses the actual Float32 native ray origin/direction. Quantiles, signed/absolute distributions and no clipping are unchanged.
- A first observed hit may be beyond a missing nearer object. These diagnostics therefore cannot certify the intervening space. Supplied-pose error, registration and sparse coverage remain confounds.
- Require native state, defaults and canonical payloads unchanged after both view queries. No hold-out insertion, carving, pose correction, map tuning, OBJ alignment or planner involvement.

## Admission and bounds
`INPUT_PINS.json` binds the actual newly built library and successful 48-control receipt (16 original, 22 conservative, 10 observation-only). Source manifest and receipt checks fail closed. Data execution remains unperformed.

- Library SHA-256: `82afb6c94b3e0234ee371395b6f7ba17ae159987293ac357463bde43605ebc26`
- Control receipt SHA-256: `51624c3c11456971709fd41ef6bd2b63f303e7f0df1b58bec5403d73d607f3e4`
- Build receipt SHA-256: `5cd8ccc9754498f0ae2d6889395ff7d550b7e9d3e9b332cebf4aa499970ec81d`

Unchanged aggregate bounds: one CPU; 120 CPU seconds; outer 178-second timeout with 2-second kill grace; 512 MiB address-space limit; 32 MiB file limit; 256-ray batches; 8 m ABI limit. Original local archive and just the two frozen PNG members are read; no new download or dependency installation.

After independent review and publication, from `blind/`:

```sh
bash research/coffee-heldout-observation-source-20261030/run_bounded.sh /opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12 research/coffee-octomap-observation-rays-source-20261030/build-observation-01/libblind_octomap.so 82afb6c94b3e0234ee371395b6f7ba17ae159987293ac357463bde43605ebc26 ../coffee-observation-ray-controls-attempt-001/RESULT.json 51624c3c11456971709fd41ef6bd2b63f303e7f0df1b58bec5403d73d607f3e4 ../coffee-heldout-observation-attempt-001
```

Source-only validation comprises 12 standard-library metric tests and 5 synthetic extraction tests. Those do not run OctoMap or read dataset rasters. Native and real-data results must be reported only after execution. The earlier primary source and results are not modified.
