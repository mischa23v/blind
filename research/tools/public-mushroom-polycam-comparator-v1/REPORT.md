# Released Polycam reconstruction restores the fixed room-route proposals

The author-distributed textured Koivu Polycam model was rigidly aligned to the recorded-phone frame without scaling, reference/FARO data, route-based fitting, or geometry cleanup. Its original18,398 vertices and29,366 triangles are unchanged. The alignment passed its predeclared geometric-comparator gates, including33 excluded-fit doorway/table/backrest landmarks; their pooled90th-percentile distance is6.05cm. **That supports a reconstruction comparator, not centimetre-accurate physical clearance.**

## Fixed comparison

All four native configurations were declared before querying: slope5° or15°, climb0 or2.5cm, the original three body profiles,2.5cm raster,1.75m native height, and the same192 requested physical start/goal pairs per configuration. The2.5cm value is a one-cell reconstruction-noise sensitivity, not permission to cross real small objects.

| Geometry / configuration | Full native route proposals |
|---|---|
| Existing265-frame Open3D TSDF, all four settings |0/768 complete|
| Registered released Polycam, zero-climb settings |0/384 complete|
| Polycam5° /2.5cm |All32 south→east goals complete and association-valid for each body; nominal45cm VARPU31complete/17association-valid; abstract28cm VARPU32/32|
| Polycam15° /2.5cm |All32 south→east goals complete and association-valid for each body; nominal45cm VARPU32/32;55×40cm VARPU29complete/21association-valid; abstract28cm VARPU32/32|

“Association-valid” retains the existing maximum10cm horizontal endpoint projection. A native-complete path with excessive projection is not silently treated as reaching the unchanged objective. The requested VARPU objective remains farther inside the room, not a substituted doorway-only goal.

First original-rank0 nominal45cm proposals: south→east4.3852m under5°/2.5cm; VARPU entry4.8489m under15°/2.5cm. Separately frozen reverse queries succeed for all three profiles: exact original inside160→outside130 and entry-rank0 target→outside130. Nominal45cm reverse lengths are4.7363m and4.8489m respectively. Continuous execution must use the actor's actual end state, not teleport to a frozen return start.

## Why the one-cell allowance matters

A separately authored regression uses a continuous4m×2m ramp rising5cm: its physical slope is only0.716° and it contains no discontinuous step. The same native planner fails with zero climb and succeeds with a2.5cm raster-transition allowance; both settings pass the flat control. This confirms a quantization/configuration issue on known synthetic geometry. It does **not** prove that every measured room protrusion is noise.

## What this does and does not establish

The released coherent reconstruction supplies full fixed route proposals that the custom occupancy map and its measured/floor-prior repairs did not. This is evidence of a consequential reconstruction/policy difference, not proof that the Polycam mesh is complete or universally better. The systems have different fusion/frame histories: Open3D uses265 original supplied-pose training frames; custom occupancy uses294 frames and nine corrected poses; Polycam's internal optimized frame subset is unavailable.

Native radius erosion is not an oriented rectangular-body, turn, connector, contact, support or coverage proof. Original occupancy flags are retained as diagnostics, not used as a circular veto on this external-model comparator. Some proposed centerlines intersect old low-obstacle/high-obstacle/deep-floor flags. Missing mesh is not free space. No actor movement, physical success, or independent scorer result is claimed in this report; that is a separate experiment.

## Sources and receipts

- Public dataset: Xuqian Ren et al.,MuSHRoom,iPhone Basic Data,CC BY4.0, [Zenodo10230733](https://zenodo.org/records/10230733), DOI10.5281/zenodo.10230733; [official repository](https://github.com/TUTvision/MuSHRoom). Original OBJ SHA256:`79cfd017b9c88dca840c8ec969208a93593b03f600303d70cc6777b7c55438a1`.
- Existing Library model deliverable:`koivu-room-full.glb`,SHA256:`aca3efca38de7a5087d6fed25fdbebb36cd3b497d2f9f89df60b7af8a2e0e29d`; exact original OBJ/MTL/texture remain in the separately delivered original-model package. No mesh/texture duplicates are included here. The original viewer was an unaligned-model deliverable; registration37 is a later separate transformation, not a silent rewrite.
- Stage37: frozen rigid-fit protocol,24yaw candidates, exact transform, fit-surface provenance and every reserved-landmark result.53.27CPU/52.86wall seconds,208MiB peakRSS.
- Stage38: four prequery-frozen configs, all768 exact requestedXYZ receipts, complete/partial/association distinctions, first proposals, self-recount of sourceOBJ/native byte hashes.4.24CPU seconds.
- Stage39: reverse-query protocol fixed before independent movement outcomes, all six fullXYZ native results.0.58CPU seconds.
- Stage41: four frozen synthetic regression cases, no room inputs.

`PUBLICATION_MANIFEST.json` is the exact compact allowlist with sizes/hashes. Inputs not duplicated here remain identified by the original frozen source manifests; this packet is not a standalone dataset distribution. Only original public source data and derived technical receipts are referenced. No private user screenshots are included. Root owns publication; no remote write was performed by this worker.
