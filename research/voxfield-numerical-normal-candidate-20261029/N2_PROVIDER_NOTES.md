# N2 provider candidate — source prepared, not compiled or executed

## Derivation and fixed difference

`n2_adapter.h` derives from the frozen `../build-gate/n1_adapter.h`, which adapts Voxfield's `computeNormalImage` at revision `78ee6403720e0aed87f4720c04c813bb38a3b260`. The BSD-3-Clause notice is retained in the candidate header. The upstream source and N1 baseline remain untouched.

Only normal numerical validity changes: unchanged float point inputs are cast to double **before** tangent subtraction; cross product and its norm are computed in double. Nonfinite or exact nonpositive norms are unavailable; positive finite norms are normalized and converted to float. The float output must be finite and its length must be within `8 * numeric_limits<float>::epsilon()` of one. This dimensionless representational check is not a geometric area, range or noise threshold. N1's arbitrary numeric `1e-6` square-metre cutoff is absent.

Everything else is retained: axial integer-mm domain `0 < mm < 4000`, integer pixel K unprojection, original float points and raster order, strict rational five-percent discontinuity (`abs(neighbor-center)*20 > center`), +u/+v neighbor order, optical `dx cross dy` sign, border exclusion without wrap, unavailable zero normals plus reasons, all admitted points retained, no smoothing/fill/GT normal/floor classifier.

**Numerically valid is not reliable.** Tiny positive-area or nearly collinear triplets may yield extremely noise-sensitive directions. N2 does not claim calibrated confidence or recover information already rounded from float input. Optional cross-area and sine-angle diagnostics expose conditioning only; they are not a score or gate. A coincident/collinear float triplet remains unavailable.

## API for integration fixture author

Header: `n2-normal-candidate/n2_adapter.h`; namespace `n2`.

- `Raster`: same fields as N1 (`width`, `height`, `fx`, `fy`, `cx`, `cy`, `depthMm`), but separate type.
- `Result`: same fields and ordering as N1 (`points`, `normals`, `pixelIndices`, `reasons`, `counts`, `zero`, `far`).
- `Reason` values identical in order: Valid, Boundary, MissingNeighbor, Discontinuity, Nonfinite, Degenerate.
- `compute(const Raster&)`, `unproject(...)`, `admitted(...)`, `discontinuous(...)` mirror N1.
- `tripletNormal(center, right, down, Vec* normal, TripletDiagnostics* diagnostics=nullptr)` returns Reason. Diagnostics contain `crossAreaM2` and `sinAngle`; NaN means the numerical diagnostic was unavailable. Valid only means successful finite unit computation.

## Proposed provider fixture evidence

`n2_provider_fixtures.cpp` requires only Eigen and C++14. It includes the original N1 header for read-only baseline comparisons; no native mapper linkage or file input is present.

Tests preserve all existing N1 provider contract families and add N1-vs-N2 identical-point/order checks at fx=fy=810.82548516100394 and synthetic0.3m/1m/3m. At each 4×3 raster, N2 expects six valid interior normals and six unavailable border normals, retaining12 points. N1 is expected to retain12 points but produce zero valid normals at0.3m and six at1m/3m. Tests report analytic area `z²/(fx*fy)`, not measured sensor quality. Additional proposed checks cover exact-zero and collinear triplets, positive tiny area, tiny near-collinearity with no confidence claim, float-input coincidence, NaN/Inf, asymmetric K, missing/invalid depths, narrow/border rasters and strict positive/negative five-percent boundaries.

These assertions are **prepared expectations, not results**. No execution or physical/real-data accuracy claim follows from this source preparation. The full native retention/history fixtures are a separate source and must not interpret increased normal availability as safer geometry.
