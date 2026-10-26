# Camera-anchored approach checkpoint

**Three numerical profiles reached the same fixed southern goal in simulation.** Each moved 1.800 m in 91 ticks, stopped with an empty command queue, and finished 0.328042 m from the original goal (tolerance 0.35 m). Saved non-ground actual-body and margin contact events were zero.

These are **three correlated profile checks of one route**, not three independent rooms or journeys. All three XZ/yaw traces are identical. **Every one of the 91 ticks in each run retained low-unresolved phone-map exposure.** Ground-contact metrics are unmeasured/null (trace sentinel −1), not measured zero. This is an offline permissive provided-map/reference-model result, not live clearance or physical safety.

## Complete denominator

| Numeric profile | Fixed north slot | Fixed south slot |
|---|---|---|
| Raw 0.45×0.30×1.60 m; zero margin | Association rejected; not executed | Arrival, 1.800 m /91 ticks, 0 body and margin events |
| Same raw body; 0.05 m margin on each horizontal side (0.55×0.40 m envelope) | Association rejected; not executed | Same arrival and trajectory |
| Abstract 0.28×0.30×1.60 m; zero margin | Association rejected; not executed | Same arrival and trajectory |

All six immutable phone-only selection artifacts are preserved. The blocked northern goals failed the allowed ≤0.10 m phone-cell association before any per-slot reference episode; they are **not collision-free arrivals**. Southern centreline samples remain outside the disputed western ROI, although some footprint samples touch it. This does not demonstrate traversal of the blocked passage or a completed table loop.

The tested condition is baseline only: zero reaction delay, no lag/drop/jitter/wrong-turn perturbation. Nominal speed is 0.30 m/s, capped at 0.375 m/s; 91 ticks include the final stopped/drained tick. These are nominal processed-phone/game coordinates and abstract profiles, not measured participant dimensions or calibrated phone odometry.

## Preserved execution history

- **Stage11:** historical Python module-name resolution selected the wrong ground helper. The batch failed before reference loading/actor motion. Exact source, review, fixture and failure logs remain.
- **Stage12:** corrected explicit helper ownership; setup was intentionally interrupted while the first monolithic native bounds query remained incomplete. Last recorded heartbeat was 509.50 s wall /514.21 s CPU. Final CPU/RSS were not measured; zero actor ticks occurred. This was a compute-setup failure, not a collision/no-path outcome.
- **Stage14:** same fixed approaches and ground rules, with equivalent closed tiled VTK bounds queries and sorted original-ID union. The native query returned 1,987,262 unique IDs in 2,436 tiles (4,503,760 raw IDs), taking 8.682 s. **The old 2,000,000 cap would already admit this count; raising it to 3,000,000 was not causally needed.** Tiling addressed the observed bottleneck. The old query never finished, so no precise paired speedup ratio is claimed.

The whole terminal batch took 191.597 s wall /193.47 sampled CPU seconds, with peak sampled/waited tree RSS 2,752,319,488 bytes. These Linux CPU resource measurements are not iPhone runtime evidence or a hard cgroup guarantee.

## Ownership and unchanged rules

The controller subprocess receives only the frozen phone map/profile, explicit original goal and simulated physics pose. Recast/Detour chooses the route; reference triangles, support labels and contact reports do not select or steer it. There is no actor XZ/yaw snap or reference-selected replacement start. The reference world owns vertical support and independent collision scoring.

One common broad/local ground model is built before all profiles over the fixed expanded route envelope, with the original v3 seed IDs and geometry rules. Its coefficients and detailed patch residuals remain in the full results. It is not refit for each avatar. Nine finite support rays and the declared continuous enclosed body/margin sweeps remain. The cleaned/completed reference mesh and finite probes are not perfect physical truth or a complete support proof. No cane catches are credited.

The reviewed v6 scorer skips immutable ground and conservatively separated triangles while preserving original exact non-ground predicates/order. Its included earlier comparison checked 40 saved body/margin cases, all negative-contact; positive/boundary cases came from 30 authored fixtures, not new recorded collisions. It does not establish universal collision equivalence. Seventeen tiled-query fixtures and 26 integration/controller/import fixtures are component checks, not extra movement episodes.

This checkpoint does not adopt the separate phone per-view floor fits, change supplied mask flags, solve dynamic obstacles, or perform progressive sensing. Missing actual confidence/tracking/body-mount information stays unavailable. The earlier loop and strict-clearance failures remain separate preserved results.

## Included and omitted

Included: exact stages11/12/14 source and fixture cuts; six selected plan artifacts and selector; runtime `profile_map.py` only from the otherwise unexecuted lap directory; v6/tiled-query implementation and evidence; exact frozen source dependencies; terminal readback, three NPZ traces and one inspected phone-map/trace plot. No people, photographs, personal measurements or screenshots appear in the plot.

Excluded: full FARO/phone assets, raw RGB/depth, native binaries/installed environment, unexecuted lap implementations and contiguous-arc draft, and repeated old data outputs already pinned by earlier checkpoints. `EXTERNAL_DEPENDENCIES.json` lists historical prerequisite identities. This is not a standalone clean-machine rerun package.

Four large JSON outputs (the summary plus three full per-profile results) repeat detailed shared-ground evidence. They are stored as deterministic **lossless gzip**, not edited or numerically reduced. `COMPRESSED_RESULTS.json` records each original/decompressed SHA-256 and size plus compressed identity. The plain `RESULT_READBACK.json` is the compact independently checked denominator/outcome receipt. Its arithmetic readback did not reload/rescore reference geometry.

## Validation and restoration

`python -B validate_packet.py` checks exact files, SHA-256, source/evidence associations and decompressed result identities without running scientific code or decoding traces. Nine tiny synthetic-byte restoration tests are preserved in `RESTORE_TESTS.log`; actual result restoration was verified by decompression hashing without creating duplicate full outputs.

Use the verified SHA of `COMPRESSED_RESULTS.json` from `MANIFEST.json`:

```bash
python -B restore_results.py --manifest-sha VERIFIED_SHA \
  --asset blind-split-candidate-game-03/camera-approach-executor-14/run-01/result/SUMMARY.json \
  --output /existing/output-directory/SUMMARY.json
```

The helper refuses overwrite, symlinks and traversal; checks compressed and original identities; bounds expansion; and requires a 768 MiB reserve. `--asset` values for individual results are listed in the compression manifest; keep the original output basename.

Public path-normalized receipt/log copies are separately identified in `NORMALIZATION_MAP.json`; sources remain byte-identical. Original hashes in historical receipts still identify original evidence, not a normalized own-file copy. Re-execution requires compatible dependencies, omitted assets, reviewed local paths and a newly frozen launch identity. Packaging performed no numerical fixtures, geometry queries, scoring or movement reruns.

MuSHRoom attribution, original native zlib license and native dependency provenance are retained. Repository-authored source retains its existing ownership. No new data license or endorsement is implied. Prior sealed checkpoints remain unchanged.
