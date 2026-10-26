# Recorded OctoMap v2 map construction protocol

A single offline estimated-map construction, not navigation or live sensing. Preserve v1 and its failed usefulness. No FARO geometry, registration-error feedback, route selection or controller changes are inputs. Original confidence, tracking, capture clock and body mount remain unavailable. The level-floor model is an experiment assumption supported only by the recorded geometry; flat carpet may be support, but the3cm floor band does not establish absence of small objects, folds, steps or drops.

## Frozen inputs and unchanged level model

Use the same294 pose-listed depth frames, all215,670,168 nonzero pixels, original Float64 half-pixel projection, original order, same original-pose ROI and exact pinned phoneToApp transform as v1. Original frame hashes and pose associations must match the existing manifest. Reuse the v1 raw811,806 endpoint voxels, observed point Y extents, four-quadrant/two-frame support,3cm band and below-floor contradiction rules without widening or refitting. All raw points/evidence remain preserved. Zero/no depth never supplies free evidence.

## Established fusion engine

Official OctoMap1.10.0 pin007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f, reviewed local native adapter/build04. Resolution0.05m; unchanged upstream hit0.7, miss0.4, threshold0.5, clamps0.1192/0.971; validate with native om_defaults before use. These are occupancy-model weights, not calibrated physical confidence. Convert projected points/camera origin to OctoMap Float32, report maximum conversion deviation.

Every original in-ROI endpoint enters its scan. Native key deduplication chooses the first ACTUAL measured Float32 endpoint per key, not an invented voxel centre; native occupied-set equality is asserted. Native computeUpdate uses real representative rays and occupied-wins, followed by upstream updateNode/updateInnerOccupancy. Retain all distinct-scan hit/free counts and raw-positive/native-free conflicts. Free traversal is a subset of actual source rays, not full-cloud coverage equivalence. Unknown absent nodes remain unknown. No threshold tuning after outcomes.

## Exact raw/native association

Recompute each original point's Float64 raw voxel index with the exact v1 transform/origin/resolution and require membership in the pinned original raw voxel tuple set. Obtain ACTUAL native keys from the same Float32 point array using upstream coordToKeyChecked. Record for every raw voxel all native keys observed among its member endpoints. A centre key is only an indexing shortcut: it enters the association set only after actual member-key equality has been seen. Retain every deviating key, measure/count conversion/boundary differences, and fail rather than silently discard overflow. Require complete association for every raw voxel and reconcile all215,670,168 hits. Query associations by native keys, never guessed centre coordinates.

## Surface import / coverage

Use the separately pinned IMPORT_PROTOCOL_PROPOSAL.json and surface_import.py, with native isNodeOccupied flags. Raw positive candidates may stop obstructing only when every actual associated native key is known, non-occupied, has hitScans>0 and freeScans>0. Unknown or missing association stays blocked. Below-floor contradictions and missing support remain blocked regardless of occupancy estimates. This only reclassifies the offline game model; no raw evidence is erased.

Recompute unchanged90-point projected coverage over all newly eligible cells, using all294 original depth frames. The original five horizontal sample positions and18heights, half-pixel inverse/nearest rounding, complete3×3 minimum and5cm observed-depth margin are unchanged. Every one of90samples must ALSO be native known-free with actual freeScans>0. An absent v1 coverage row is not free. Floor uncertainty remains null/unavailable. Export the same SurfaceCell schema with nullable clearance; Recast/actual native Surface footprint guard remains unchanged.

## Evidence / limits

Store per-scan accounting, full native leaf coordinates/sizes/non-thresholded scores/hit/free counts, exact raw/native association pairs, all raw classification states, coverage reasons, final surface and source/input hashes. The original raw layer is referenced by exact hash, not duplicated or silently replaced. Unknown/thin/low/overhead limitations remain explicit. Saved native scores are not converted to maximum likelihood.

One serial recorded construction under600CPU/900wall seconds, <=2GiB observed process-tree RSS, <=64MiB new output, >=768MiB free reserve. No concurrent detailed reference mesh load. Watchdog and terminal checks preserve any failure. No subset/frame/threshold retry is authorized by this protocol. Native/source/import fixture review and all exact pins freeze before execution. A useful map is still not an arrival or collision result; the separate100-run launch requires the already planned route/condition protocol and independent reference scoring.
