# Existing native height versus authored body foot — source trace

Read-only review after support-datum attempt001. No native run or code change.

## Verified existing behavior

- `coffee-native-replay-prepared-002/blind-clearance-centered-loop-55/planner.py`
  `build_graph` samples each 5cm grid node through `Native.sample`; that calls
  `bn_sample`. Returned Y is retained (`sourceNativeHeightRetained=true`). The
  constant anchor median Y is a search seed, not a replacement for sampled Y.
- `blind-tabletop-exclusion-planner-66/clearance_adapter.cpp` `bn_sample` calls
  released `findNearestPoly`, returning the polygon's closest point. Detour's
  `closestPointOnPoly` uses its detail mesh height when within the polygon.
- The same adapter's `bn_segment` raycasts the horizontal connection then checks
  `getPolyHeight` at the last polygon/end point with a **5cm tolerance**. It returns
  a boolean only. It neither changes Y nor supplies polygon references to the
  later schedule.
- `blind_detour_exclusion.cpp` builds a detail mesh; the current configuration is
  cs=ch=25mm, detail sample distance150mm and detail maximum error25mm. These are
  representation parameters, not a measured physical sensor-error bound. They
  are much coarser than a2mm collision-band comparison.
- `conference-body-source-20261029/schedule_source.py` interpolates each frozen
  XYZ edge at <=25mm, including requested-to-projected start/end connectors;
  it does not query native detail height per emitted movement point.

## Concrete endpoint mismatch, not speculation

Conference `table_120_to_200` last native point is
`[0.9934880137443542,0.0257081538438797,1.4958630800247192]`.
The terminal requested point is
`[0.9934880108773039,-0.0002434645272815228,1.4958630505636947]`.
The schedule therefore authors a25.951618mm downward connector while changing
horizontal coordinates only at Float32 rounding scale. The supplied requested
anchor is not a measured body-foot pose. That final point is exactly the
endpoint whose low overlaps disappeared in the estimated-datum diagnostic.

Coffee similarly connects native Y−1.6111059188842773 to requested
Y−1.6301633051396203:19.057386mm down at near-identical XZ. This is an authored
association connector, not evidence that a real person should descend there.

Do not rewrite the historical results. These were explicitly authored,
requested-connector diagnostics. A new movement integration should not silently
reuse their endpoint Y as a measured foot datum.

## Released implementation already provides the missing operation

`DetourCrowd/Source/DetourPathCorridor.cpp::movePosition` calls
`moveAlongSurface` within the maintained corridor, merges visited polygons,
then `getPolyHeight` on the resulting first polygon and assigns Y. Upstream
`DetourNavMesh::getPolyHeight` checks the polygon/detail triangles. This is a
stronger source-grounded integration direction than extrapolating an arbitrary
raw center triangle or repeatedly raising a body until it clears.

Next minimal adapter work: retain corridor/poly references and explicit query
statuses, obtain native detail height for each intended horizontal movement,
and treat requested destination association separately from the movement foot
state. Check every status, including height lookup, and retain unknown/partial
states rather than silently using prior height or changing floors.

## What this will not fix automatically

Native Y was already used at interior grid nodes. The interior table20→92
contact survived the one-triangle diagnostic; a new height lookup is not proven
to remove it. The native representation is quantized/approximated and may differ
from raw geometry. A polygon/detail height is navigational support *proposal*,
not fresh physical support or clearance of toys, stairs or high furniture.

Use a consistent explicit nav-height/body-foot/query-offset contract, then
retain the independent full-height raw contact audit. Report near-foot support
surface intersections separately from above-foot geometry without classifying
all low returns safe. Continue checking all true low-object/drop controls and
higher overlap cases. A native controller can permit motion out of an overlap;
that does not erase the original overlap or certify a human route.

Registration remains the exact historical estimated rigid transform, not an
independently calibrated camera-to-room/body frame. No source change here can
establish physical localization.

## Exact trace locations and commit scope

Repository paths below are inspected at `71d1e68c65620106b2da97658951017420761c6a`.
This records current source identity, not the date each file was first authored.

| Source | Lines | Role |
|---|---:|---|
| `research/conference-replay-source-20261029/run_comparison.py` | 90–92, 115–121 | Native projected association; explicitly appends requested anchors around native-height grid points. |
| `research/clearance-first-coffee-source-20261029/prepare_coffee.py` | 90–97 | Same requested/native connector construction for Coffee. |
| `research/conference-body-source-20261029/schedule_source.py` | 18–38 | Heading and XYZ interpolation of every connector; no native-height query per tick. |
| `research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour/clearance_adapter.cpp` | 3–17 | Exact byte-identical copy of the executed prepared `bn_sample`/`bn_segment` adapter. |
| `research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour/upstream/DetourCrowd/Source/DetourPathCorridor.cpp` | 439–459 | Released moveAlongSurface/corridor merge/getPolyHeight pattern; exact byte-identical to the prepared upstream source. |
| `research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour/upstream/Detour/Source/DetourNavMeshQuery.cpp` | 2025–2037 | Explicit upstream warning: moveAlongSurface is 2D and does not itself project Y; use getPolyHeight. |
| `research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour/upstream/Detour/Source/DetourNavMesh.cpp` | 683–731 | Height comes from detail triangles within the identified polygon. |

External prepared inputs are separately SHA-256-pinned in `SOURCE_PINS.json`:
`coffee-native-replay-prepared-002/blind-clearance-centered-loop-55/planner.py`
lines11–16 and35–60; `blind-tabletop-exclusion-planner-66/blind_detour_exclusion.cpp`
lines84–91 and124–139. Those are the inputs used by the recorded Conference
proposal run at source commit `719ec504901639f65767b717f7f7dc817a482640`;
`conference-body-source-20261029/freeze.py` verifies that receipt and freezes its
proposal hash. Do not confuse an external prepared input's SHA with a Git commit.

The current package's full `blind_detour_exclusion.cpp` is **not** byte-identical
to the historical prepared build: later seed-policy features were added. Only
the exact source copies explicitly compared above are claimed identical. Do not
silently switch to another build while testing this hypothesis.

`CONNECTORS.json` records all14 Conference and2 Coffee start/goal connectors,
not only the two largest examples. Every horizontal connector magnitude is
approximately3e-9–1.02e-7m; nonzero vertical magnitudes range0.201–25.952mm.
The tiny horizontal rounding residuals can also produce authored turns in the
historical scheduler. This report does not remove those historical records or
attribute them to a physical person's turns.

### Offline defect versus app behavior

The demonstrated issue is treating offline requested anchor Y as body-foot Y
when replaying the authored requested-connector chain. That is an unsuitable
movement-state association contract, not proof that the iPhone app currently
performs these exact downward moves. No app live execution, localization,
measured body pose or camera-floor calibration was inspected in this trace.
The current app build/status remains unchanged.
