# Fixed singleton voxel-resolution ablation — prepared, not executed

## Question
The 5 cm singleton maps already showed early occupied-box ray hits compared with their own source depth. Saved-array audits found internally consistent projection and ray intersections and measured neighboring-pixel support for those boxes. This experiment changes **only map resolution**, using the same released OctoMap insertion and reviewed ray adapter, to isolate the coarse-representation contribution. It does not optimize an obstacle threshold or measure physical safety/phone accuracy.

## Frozen six cases
1. Rebuild each original singleton view **290, 357, 391 at 5 cm** first.
2. Require each 5 cm map state, probabilities, canonical arrays, ray status counts, distributions and every saved per-hit array to reproduce the previous singleton result exactly. Any mismatch stops the experiment.
3. Rebuild the same three singleton views **at 2.5 cm**, in the same order.

No fused map is constructed. Each native tree receives local scan ID 0. Only one map is resident at a time and every handle closes on success/failure. Every case uses the same full original accepted points and supplied poses; original world-coordinate hashes must match. No downsampling, denoising, smoothing, alignment, carving, held-out reads or scene substitution.

Both resolutions keep hit/miss/occupancy/clamp defaults unchanged. Grid stride remains 8; each frame has 11,625 candidates; axial depth rule remains 0 < depth < 4 m. Every valid ray uses both conservative and observation-only mode. Unknown and range-exhausted counts remain separate and never become clear space or zero error. Every observed occupied hit is scored with the existing entry/center axial and entry-along-ray metrics, identical Float32 native-ray convention and exact inverse supplied pose. Neither resolution is selected for production based on these three views.

## Measurements
- Full raster, candidate, excluded and valid-ray denominators; compare identical denominators across resolutions.
- All ray-status counts, plus signed/absolute residual distributions over actual observed hits.
- Counts of negative/zero/positive entry residuals. A negative value means a nearer **voxel prediction**, not an independently verified false obstacle. Grazing incidence and foreground edges can amplify axial differences.
- Endpoint known-occupied, known-not-occupied, unknown and hit/free-conflict counts, both pixel-weighted and distinct-native-key-weighted. The unique-key denominator is expected to change with resolution and is reported explicitly.
- Map leaf/node counts, leaf-size distribution and state/default/canonical-payload read-only invariants.
- Per-hit pixel indices, returned voxel centers and residual arrays, retaining all hits for later paired comparison. Full status denominators prevent disappearing hits from masquerading as improved agreement.

## Bounds and failure evidence
Exactly the existing bounds: one CPU, 120 CPU seconds, 178-second outer timeout plus 2-second kill grace, 512 MiB address space, 32 MiB per file, and **500,000 leaves / 500,000 tree nodes** checked before export or scoring. Maps are built serially, with no new dependencies/downloads/native compilation. The native insertion itself remains protected by the same process bounds; if its completed map exceeds the node cap, scoring stops rather than exporting or relaxing the cap.

Outputs must be fresh. A completed case JSON is written separately alongside its array; the final receipt records the active case and last observed map state on a handled failure. Preserve timeout/OOM/native failure evidence and all earlier case receipts. **Do not enlarge budgets** to finish a failed fine-resolution run.

## Exact command after independent review and publication

From `blind/`:

```sh
bash research/coffee-resolution-ablation-source-20261030/run_bounded.sh /opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12 research/coffee-octomap-observation-rays-source-20261030/build-observation-01/libblind_octomap.so 82afb6c94b3e0234ee371395b6f7ba17ae159987293ac357463bde43605ebc26 ../coffee-observation-ray-controls-attempt-001/RESULT.json 51624c3c11456971709fd41ef6bd2b63f303e7f0df1b58bec5403d73d607f3e4 ../coffee-resolution-ablation-attempt-001
```

The actual passed 48-control receipt and exact binary are pinned. Source-only metric tests do not run the engine or read rasters. Any outcome remains a fixed representation diagnostic, not evidence of reliable navigation or permission to remove real hazards.
