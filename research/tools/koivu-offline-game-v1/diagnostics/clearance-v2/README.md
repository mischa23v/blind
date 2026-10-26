# Phone-map clearance and container conservatism diagnostic

This is a read-only diagnostic addendum, not a completed navigation experiment or a live app change. The current Koivu offline map has no footprint-valid route under the frozen model. **0 of the requested 100 game episodes were launched; collision counts are not measured.** The failed v1 and v2 maps and route selectors remain preserved.

## Result

Among the 359 eligible cell centres, shortest horizontal distance to saved native occupied positive-hit voxel squares was median 0.05 m and maximum 0.2236068 m. Missing-support cell distance was measured separately: median 0.25 m and maximum 0.7778175 m. These are estimated map-geometry distances in declared phone-model metres, not sensor accuracy or physical clearance guarantees.

The original 0.45 × 0.30 m rectangular body is circumscribed by a 0.270416 m radius circle. The existing yaw-independent square container is circumscribed again by a 0.382426 m native cylinder; adding the unchanged 0.15 m margin gives 0.532426 m. The configured Recast erosion is six 0.10 m cells, nominally 0.60 m. That nominal setting is not an exact Euclidean clearance guarantee: the pinned upstream grid/chamfer implementation owns erosion.

A future single enclosing cylinder could avoid the second bounding operation while retaining the original rectangle and margin, but it would not contain the larger historical square corners. That would require a separately declared and tested evaluator/container variant. No such variant was implemented or run here. Even the original un-margined 0.270416 m circle exceeds the maximum occupied-square distance at these particular candidates. This does not establish that the real room is impassable or that another phone would behave identically.

## Verification and boundaries

Four authored distance-metric checks passed. The recorded saved-array diagnostic completed in 1.17 s wall time with 193,836 KiB child peak RSS. Independent source review found no key-join, metric-bound or schema blocker. The terminology clarification is additive; executed source and numerical results were not rewritten.

Only saved phone-map arrays were read. Native OctoMap coordinate-to-key conversion joined saved occupied-key associations to exported 5 cm leaf boxes; no occupancy threshold, ray fusion or FARO data was used. SciPy cKDTree bounded exact distances to closed horizontal squares. No maps, body dimensions, margins, routes or poses were changed. Physical movement authority remains false.

## Source and reproduction status

The Python files are the exact executed source cut. They retain the private experiment's sibling-directory layout as relative paths; this packet is not a standalone runnable dataset or a verified portable build. Reproduction requires the separately pinned game model adapter, OctoMap build-04 wrapper/library, and the exact saved phone-map arrays listed by hash in the result. No raw frames, room mesh, map arrays, routes, trajectories, binaries or personal data are included. Recast source integration is separately checkpointed under `tools/navigation-recast`; OctoMap acquisition/build provenance belongs to its separate source packet.
