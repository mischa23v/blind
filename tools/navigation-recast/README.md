# Actual pinned Recast/Detour simulation engine

This is a **local simulation-stage adapter**, not published app integration, new SLAM, a new search algorithm, verified human guidance, or proof of physical safety.

## What was acquired and executed

- Official repository: <https://github.com/recastnavigation/recastnavigation>.
- Exact revision: `9f4ce64458dfae86e1239c525ddc219c4e9e06f1`; official tree `3f2171f00146970f294af02a8e0056647a559b64`.
- License: **Zlib**. Unmodified notice and all upstream file notices retained under `upstream/`.
- 43 source/header/license files, **738,805 source bytes**; **807,980 acquisition bytes** including official commit/tree metadata. Every acquired file was checked against the official tree's Git blob SHA-1 and recorded SHA-256. See `UPSTREAM_MANIFEST.json` and `acquire_recast.py`.
- No ROS, CMake, graphics, GPU, model weights or new installed dependencies. Existing `g++ 14.2.0` compiled 24 upstream translation units plus our adapter serially. Core upstream code is C++98-compatible; adapter uses C++11.
- Initial actual build: 5.98 seconds, 50,640 KiB peak child RSS, 327,400-byte shared library. `build-result.json` and `build.log` retain actual evidence; later revalidation receipts must identify changed source hashes.
- An initial instrumentation command failed before compilation because `/usr/bin/time` was unavailable; `build-attempt-1-missing-time.log` preserves it. Python `resource` supplied the actual build measurement instead.
- Initial **12/12 local native adapter checks passed** (`tests-attempt-1.log`), including real obstacle detour, body width, overhead barrier, partial routes, unknown gap, query association and malformed input. They are component checks, **not completed navigation episodes**. The historical upstream 32-case suite was not rerun here.
- GCC emits retained `-Wmaybe-uninitialized` diagnostics in upstream `DetourNavMesh.cpp`; its pinned root CMake also explicitly disables treating that diagnostic as an error. We did not modify upstream sources or claim the warning proves safety. One local indentation warning and wrapper lifecycle/concurrency hardening were corrected after initial build; see the final revalidation receipt for the exact tested cut.

Source acquisition cap: 20 MiB. Native work directory cap: 200 MiB. Initial materialized native directory is approximately 1.3 MiB. No remote write was performed.

## Binding contract

`blind_detour.h` exports:

- `bn_build`: caller-provided triangles → real Recast heightfield/erosion/contours/poly mesh → real Detour navmesh. +Y up, metres. Floors require upward winding. Body dimensions and raster resolutions are explicit bounded inputs. No low-hanging-obstacle promotion, off-mesh shortcuts or silent winding repair.
- `bn_path`: actual Detour polygon path and straightened corridor, plus **separate** projected query endpoints and completion/status. Partial, buffer-limited and exhausted-node paths are **not complete**. Failure to associate start/goal returns an explicit error.
- `bn_velocity`: upstream `dtObstacleAvoidanceQuery` candidate velocity. It does **not** model a person's delay, acceleration, comprehension or adherence and is not a clearance certificate.
- `bn_destroy` and `bn_last_error`: explicit handle lifecycle/error reporting.

Python's `detour_engine.py` uses standard `ctypes` plus already installed NumPy 2.3.5. The library does **not** instantiate `dtCrowd`, own actor position, snap actor position, integrate movement or access evaluator truth.

```python
from detour_engine import Engine, Config
with Engine(vertices_xyz, triangles, Config(radius=.5204, height=1.6),
            mode='known-provided-map') as engine:
    route = engine.route(body_floor_start_xyz, body_floor_goal_xyz)
    # Require route.complete; validate association displacement separately.
    # Never replace actual body state with route.projected_start.
```

`mode` is explicit provenance metadata, not proof of observation provenance. In `known-provided-map`, mesh geometry is deliberately supplied. In `progressively-observed-map`, the caller must provide **only causally observed geometry**, preserve unknown holes and maintain provenance. This adapter does not derive free volume or floor support from absent returns. The progressive observation/frontier coordinator is not implemented by changing this string.

`query_half_extents` defaults to `(0.20, 0.30, 0.20)` m; callers must validate projected endpoints against their allowed association and floor policy. Camera-height coordinates and body-floor anchors are different. RTAB's Z-up and app/Recast's Y-up are different. Rebuilds must atomically replace an observed mesh generation and retire older route tickets; they cannot silently combine different frames/revisions.

## Rebuild and verification

Coordinate the serial compiler slot first. `./build_serial.sh` verifies acquisition hashes, builds with no `-j` or fast-math, then atomically replaces the library. It has a 180-second build cap and 200-MiB directory check. `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python -m unittest -v test_detour_engine` executes bounded actual native checks.

An independent actor/evaluator must still check swept body/head volume, support, wrong turns, control delay, moving obstacles and true arrival. Success is **goal reached plus zero health loss**, not a route returned or a safe stop. Known-map completion, progressive sensing, native localization and supervised device performance are separate acceptance gates.

## Independent source review

A separate read-only reviewer found no blocking defect for the bounded serial known-provided-map baseline. It confirmed separate query projections, partial/truncated status handling and ordinary allocation ownership. It emphasized that missing vertical observations are not clearance and `Route.complete` means only corridor completion to a projected goal. The wrapper now serializes native route/close access because ctypes releases the GIL; direct C ABI callers must similarly enforce single-owner handle access. Work-directory byte limits are disk limits, not strict peak-memory limits.
