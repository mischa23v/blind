# Native fixed-15° wrapper — SOURCE ONLY, not built or called

`native_planner_ground.cpp` exports exactly the agreed C ABI:

- `coffee_mark_walkable_15_abi_version()` → integer 1.
- `coffee_mark_walkable_15_slope_degrees()` → float 15.0.
- `coffee_mark_walkable_15(vertices, vertex_count, triangles, triangle_count, eligibility)` → 0 on success, negative on validation/exception failure; stable original triangle-order byte mask, values 0 or 1.

The wrapper calls the **existing published `rcMarkWalkableTriangles`**, not a copied normal or cosine implementation. Threshold is fixed to 15°, not exposed as a tunable input. The original library computes signed upward normal `> cosf(15°)`, so reversed winding is not silently accepted. Original triangle indices/winding and coordinates are not rewritten.

## Read-only binary inspection

`nm -D --defined-only` confirmed the exported symbol:

```
_Z23rcMarkWalkableTrianglesP9rcContextfPKfiPKiiPh
```

The existing `coffee-native-replay-prepared-002/blind-tabletop-exclusion-planner-66/libblind_detour.so` SHA-256 is:

`a0b6c3d84d20b1396a3239918abfafcc1d6fa613c5c390847cba92502a634c4a`.

`readelf -d` records dependency names `libstdc++.so.6`, `libm.so.6`, `libc.so.6`, and `ld-linux-x86-64.so.2`; no SONAME, RPATH or RUNPATH entry was present. These are host dependencies, not hermetically pinned shared-library bytes. Inspection did not load or call the library.

The single project header is the already pinned upstream `Recast/Include/Recast.h` (SHA-256 `712634ac8d933af70ef08270a2f439270cddb821cc901c216494fa843e4e5990`). It has no additional `#include` dependencies. Its declarations/constants plus the compiler's `<cmath>` are the source closure for this wrapper. Existing native implementation and all other dependencies remain in the original binary; no Recast source rebuild is needed.

## Smallest proposed build/link closure — NOT EXECUTED

Under the separately admitted aggregate guard, use the available compiler (`/usr/bin/c++`, currently resolving to `/usr/bin/x86_64-linux-gnu-g++-14`) with a command of this form:

```
c++ -std=c++17 -O2 -fPIC -shared -Wl,-z,defs \
  -I ABSOLUTE_PREPARED/native025/upstream/Recast/Include \
  ABSOLUTE_CANDIDATE/native_planner_ground.cpp \
  ABSOLUTE_PREPARED/blind-tabletop-exclusion-planner-66/libblind_detour.so \
  -o FRESH_OWNED_OUTPUT/libcoffee_mark_walkable_15.so
```

`ABSOLUTE_PREPARED/native025` abbreviates the actual saved `blind-split-candidate-game-03/body-margin-variants-07/native025` path; substitute exact reviewed paths, not these display abbreviations. Link the existing dependency using its full absolute pinned filename. Since it lacks a SONAME, this is intended to produce an absolute-path DT_NEEDED entry instead of relying on `LD_LIBRARY_PATH` or search-order coincidence. **Verify that entry with `readelf -d` after the admitted build before any load**, and hash both output wrapper and dependency before/after controls/comparison. Compiler, header, wrapper source and existing library must enter the aggregate input manifest. The emitted wrapper is new owned output and must never overwrite the original binary.

## Validation and failure semantics

Counts are bounded to 2,000,000 vertices/triangles; vertex count must be positive. Null required buffers, negative counts and out-of-range indices return errors. Input floats must be finite and within the original Coffee planner's ±10,000 coordinate domain. The caller supplies valid, sufficiently sized, non-overlapping contiguous buffers; this tiny trusted-workload ABI is not an arbitrary-pointer sandbox. The Python adapter owns a separate zeroed output array.

After all validation, output is initialized to `RC_NULL_AREA`, the published function fills eligible original triangle entries, and the wrapper maps only `RC_WALKABLE_AREA` to 1. No allocation is performed. The Recast function explicitly ignores its context argument, so null context is intentional. Catch-all exception handling zeros the mask and returns -4 rather than allowing exceptions across C/ctypes.

Original 5° and exact-XYZ-5° modes, controls and results are untouched. New fixtures must cover upward/reversed winding, near-threshold sides, the three original blocker triangles, seam/epsilon/point-only/stacked-layer behavior, stable IDs, input immutability and retained low-obstacle contacts. Passing this API only establishes **initial native triangle eligibility**, not final Recast walkability, semantic floor, full-footprint support or physical clearance. Root owns publication/build/control/full-run admission; no build, native import, test or native call occurred here.
