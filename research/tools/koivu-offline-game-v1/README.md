> Publication update (2026-10-26): the pinned Recast/Detour source adapter and preserved component evidence are now available at [`tools/navigation-recast`](../../../tools/navigation-recast), commit `86e657b64964b66e9117cb6cd92a6d5d18cfb50f`. Statements below about its unshipped/pending state describe this packet at preparation time. The 100 recorded-room game episodes still have not launched.

# Offline real-room game harness — component checkpoint only

**Status: 32 authored component checks pass. Zero of the requested 100 Koivu game episodes have run. This is not a live app change or physical guidance release.**

The first phone-only all-hit map left only 13 supported, unblocked 10 cm cells before clearance checks. It is retained as a failed mapping model; no stationary/no-path batch is presented as 100 avoidance trials. Revised upstream occupancy fusion is being evaluated separately. A final map, route list, source/input pins and maintainer-reviewed protocol are required before launch.

## Exact code reused

- Actual compiled `BlindCore.NavigationSurface`, `StoredTerrainPolicy`, `BodyEnvelope` and a no-evidence `SpatialRouteOwner`, through `SurfaceGameWorker.swift`.
- Pinned native Recast/Detour (9f4ce64458dfae86e1239c525ddc219c4e9e06f1), through a separately prepared, pinned native adapter. That adapter has not yet been included in the public application repository and is an unshipped prerequisite; this packet does not make it available by itself. No new search or SLAM algorithm.
- Existing deterministic command/pose queues. Old commands remain in flight after a new stop.
- Installed VTK 9.3.1 StaticCellLocator, cell intersection and explicit volume containment. The detailed FARO surface only scores; the controller receives a frozen phone-derived model and explicitly simulated body poses.

The Python/Swift files and `component-fixtures-04.log` are the exact tested checkpoint bytes. `reference_geometry.py` and `impairments.py` are exact reused source cuts. Native binaries, module cache and datasets are deliberately excluded. The build example below is a path-normalized handoff, not an independently tested portable installation. Original executor-relative dependency layout remains in source defaults; integration into the main app is not claimed.

### Native dependency handoff

The prepared adapter sources are at `blind-authored-navigation-pilot/native/blind_detour.cpp`, `blind_detour.h` and `detour_engine.py`; acquisition is `blind-authored-navigation-pilot/native/acquire_recast.py`, with `UPSTREAM_MANIFEST.json` and `build_serial.sh` in the same directory. Verified upstream files are under `blind-authored-navigation-pilot/native/upstream/`, pinned to [RecastNavigation commit 9f4ce64458dfae86e1239c525ddc219c4e9e06f1](https://github.com/recastnavigation/recastnavigation/tree/9f4ce64458dfae86e1239c525ddc219c4e9e06f1). These are prepared-workspace source locations, not a claim that the public repository already contains the dependency. The separate 57-file native publication packet remains pending publication. A compatible native library and the verified Swift support modules must be built/provided before this harness can execute; no binary is bundled here.

## What the 32 checks cover

16 evaluator fixtures cover swept thin walls, enclosed triangles, large crossing triangles, 1 cm low geometry, head geometry, similarity transforms, missing/offset/square-corner/swept support, descending steps, slopes, error latching and immutable transform ownership. Eight actual Swift checks cover footprint, unknown floor/clearance, obstacles, head clearance and nonlevel/uncertain stored geometry. Eight controller/model checks cover pose ownership/freshness, no truth input, bounded following and actual native Detour/Surface behavior.

These are authored component fixtures, not recorded obstacle events, rooms, successful journeys, or a stair-detection benchmark. The unchanged actual actor/run orchestrator is prepared and source-reviewed but its full 100-run integration is not yet executed. A four-case end-to-end authored accounting fixture is being prepared separately and is not included in the 32 count.

## Fixed experimental direction (draft, not launch authority)

20 immutable phone-map-selected routes × five conditions: baseline, delay, translation scale, wrong turn, combined. 15 Hz; nominal 0.30 m/s, cap 0.375 m/s; at most 1 degree/tick; 1,200 ticks/run; 35 cm goal tolerance. Initial overlap, support ambiguity, no route, deadlock, collision and timeout are separate from clean arrival. First reference-container overlap ends a run as one event; mesh-triangle count is not a hit count. Initial and moving contact counts are separate. All failed starts/routes stay in the denominator; no truth-assisted resampling or repositioning.

The experimental full-body player container and fitted level map are declared models, not the recorded person's body/mount. Native stored fit does not establish present clearance. Unknown cells remain blocked. A 3 cm floor-model band has unresolved tiny-height ambiguity; all raw positive evidence remains in the separately owned map artifact. Reference scoring excludes only the lowest 2 mm, does not erase near-feet/head geometry, and marks low contacts as potentially floor-registration ambiguous.

## Limits

Processed Koivu depth lacks original confidence, tracking, timing and body extrinsics. No such fields are fabricated to call live APIs. A prerecorded scan cannot respond to counterfactual motion: this is an offline provided-map game with simulated pose delivery, not live replay. The cleaned/completed FARO surface lacks a measured-support mask; contact/support scores are reference-relative. Finite support probes do not prove continuous support, and unlabeled surfaces do not establish closed-solid occupancy. None of this proves phone-only safety, iPhone 18 equivalence, child mobility suitability or live hardware latency.

No raw mesh, frames, trajectories, binary, personal data or absolute workspace path is included. Public source/dependency licenses remain separate from dataset licenses. The packet is local source only; publication and integration remain maintainer-reviewed work.
