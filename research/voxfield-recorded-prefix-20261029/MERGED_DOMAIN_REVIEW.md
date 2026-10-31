# Merged-aggregate finite-domain note — exact frozen three-record prefix only

Source-only derivation, 2026-10-29. No build, native execution or recorded-depth read by this reviewer. This is NOT a general proof for future captures, large translations, arbitrary point arrays or other integrator settings. Parent/reviewer report frozen per-pose maximum absolute translations0.214568,0.235424,0.531308m. The newly proposed prefix validator bounds every native translation component to16m; runtime preflight must verify that bound and exact identities before any native integration. The earlier generic scaled-origin bound1e6 (40km) alone is insufficient.

## Exact operations inspected

Pinned Voxfield `voxblox/src/integrator/tsdf_integrator.cc`, `MergedTsdfIntegrator::integrateVoxel`, and `np_tsdf_integrator.cc`, `MergedNpTsdfIntegrator::integrateVoxel`, use the same point recurrence in each endpoint-voxel bin:

`m = (m * W + p * w) / (W + w); W += w`.

The scalar/vector operations are native float. Projective weight is1/z²; NP exponent2 weight is1/r². Both skip weights<kEpsilon; admitted-domain weights below are all larger than that threshold. NP also forms a weighted normal vector then normalizes when its norm exceeds kEpsilon. Native grouping preserves the MixedThreadSafeIndex order within each bin; the bounds below hold for any bin order/count no greater than the full raster count, so do not assume exact arithmetic convexity.

Minkindr `QuatTransformationTemplate::transform` is `q.rotate(p)+translation`; rotate delegates to Eigen quaternion-vector multiplication. Retained Eigen3.4 `Geometry/Quaternion.h` lines531–540 uses the30-flop expression `uv=q.vec().cross(v); uv+=uv; v+q.w()*uv+q.vec().cross(uv)`. This must remain the reused implementation, without fast-math flags.

## Runtime facts required

Verify/report, do not assume from a file label:
- Exact three frozen frame identities/order/K/poses and expected738×994 raster dimensions; N≤733572 admitted points per frame/bin.
- Original uint16mm domain: admitted depth1..3999mm, unchanged finite float points; z≥the float representation of0.001m, z<4m, r≤5.055m.
- Actual computed per-point weights finite and within conservative[0.03,1000002]; normal arrays all finite exactzero or unit within frozen tolerance. No skipped/rewritten points.
- Native quaternion/rotation proper-SE3 checks and roundtrip gate pass; rotation orthogonality residual≤1e-4, finite translation with each component absolute≤16m for THESE records. If a later record or pose violates this, this note supplies no authority/domain proof for it.
- Frozen carving=true, allow_clear=false, no freespace points, maxray5.055m, truncation0.2m, voxel0.04m,16voxels/block, merged integration, NP exponent2.

## Conservative point/weight bounds including rounding

Assume standard IEEE float round-to-nearest, unit roundoff `u=2^-24`, no fast-math/reassociation that violates the usual floating-point error model. Existing numeric validators exclude nonfinite input; all positive z and weights below are normal-sized, not underflow-scale.

For N≤733572 positive summands, recursively rounded W is bounded by `N*wmax*(1+u)^N`. Here `N*u<0.044`, so **W<1e12**. `W+w` is positive and finite. No `w<kEpsilon` branch can remove all contributors because w≥0.03≫1e-6.

For a coordinate mean, bounding two products, sum and division gives per-step upper amplification no greater than `(1+u)^3/(1-u) < exp(5u)`. Thus the absolute coordinate envelope is at most `5.055*exp(5Nu)`, with5Nu<0.219, hence **|m_i|<8m**. Signed x/y cancellation does not invalidate this absolute bound.

All z operands are positive. The corresponding lower multiplicative bound is at least `(1-u)^3/(1+u) > 1-5u` per step. Therefore `m_z ≥ (float(0.001))*(1-5u)^N > 0.0008m`. This is a conservative roundoff bound, not a claim that the actual merged point is physically displaced by that amount. In particular **the merged local point cannot become zero** and `||m||<sqrt(3)*8<14m`.

The largest point-coordinate weighted numerator is bounded below8.1e12; that and W are many orders below FLT_MAX. Positive division denominators cannot approach zero. Normal accumulation has either zero/small previous norm or a previously normalized direction; with input unit tolerance, a conservative pre-normalization norm is below1.01e12 and its squared norm below~1.1e24. Cancellation can produce zero/small normals, explicitly allowed by upstream; it does not produce overflow. No inference of reliable normal direction follows.

## Aggregate transform and ray construction for the frozen prefix16m domain

Proper-SE3 residual≤1e-4 bounds the exact native rotation's minimum singular value at least `sqrt(1-1e-4)>0.9999`. This must be the actual native rotation after the constructor/roundtrip gate, not merely the incoming double matrix. The retained normalized quaternion representation has coefficient absolute values≤1 plus numerical tolerance; if its unit invariant is not established, add an explicit coefficient/norm preflight rather than applying this bound to an arbitrary quaternion.

For the inspected Eigen expression, each cross product comprises two products and a subtraction per coordinate. Under the standard round-to-nearest model, a conservative normwise allowance `4u*||a||*||b||` covers a three-dimensional cross product (plus tiny second-order terms). Multiplication of `uv` by2 is exact here; intermediate magnitudes are safely normal and far from overflow. With `||q.vec||≤1` and `|q.w|≤1` up to the validated quaternion tolerance:

- first cross error≤approximately4u||m||; doubled error≤8u||m||;
- scalar-times-doubled-cross propagated/rounding error≤approximately10u||m||;
- second cross propagated/rounding error≤approximately16u||m||;
- final two vector additions add≤approximately8u||m||.

A **64u||m||** bound conservatively covers these contributions, second-order terms and small unit-quaternion tolerance. At||m||<14m this is below5.4e-5m. No fast-math is allowed. This is a floating-point arithmetic bound, not a depth-error calibration.

With |t_i|≤16m, rotated point coordinates have magnitude<14.01m, so the first addition stays below30.01m/component. Its normwise rounding allowance is≤sqrt(3)*u*30.01<3.2e-6m. Subtracting the same nativefloat origin produces a vector bounded near14m, with another normwise allowance<1.6e-6m. Conservatively the combined translation-add/subtraction rounding is<5e-6m. Thus total transform/difference arithmetic error at the largest admitted aggregate is **<1e-4m**.

For nonzero-ray proof use the proportional rotation bound, not just that largest absolute bound:

`||fl(fl(q*m+t)-t)|| ≥ (0.9999-64u)*||m|| - 0.000005`.

Together with||m||≥m_z>0.0008, this remains **>0.00079m**, so native normalization cannot see a zero vector on this frozen domain. This does NOT certify geometric accuracy. The earlier40km bound did not provide this guarantee: translation quantization can erase an aggregate despite individually nonzero rays.

Native nonclearing ray end is **merged_point_G + unit_ray*0.2**, not clipped to maxray. The origin is≤16m/component; transformed aggregate is<30.01m/component; normalized truncation extension adds approximately0.2m. Bound every endpoint component by31m, hence scaled magnitudes<775 at0.04m/voxel. Global-index and block-index casts, their differences/absolute sums and uint step counters are far from limits; the conservative total-step bound<5000 also covers floor differences. Native float conversion back from global index to block index is exact for these small integer values. This is stricter than merely testing generic int64 capacity.

## Required interpretation and failure behavior

Runtime extrema/count receipts must preserve the premises above. If exact-frame identity, actual translation, weight/point/normal or SE3 premises fail, reject the whole prefix before integration—do not clip, recenter, drop points, widen limits or cite this note for another pose domain. Keep the existing per-point explicit scaled-index checks as diagnostics; they are not substitutes for the aggregate proof.

If the reviewer does not accept this source-error bound, use a separately frozen preflight that calls/exposes native bundleRays and mirrors each bin's exact weighted recurrence and native transform before any map mutation, validates the aggregate rays, and records counts. Do not silently add a native D2 validity patch. No such extra implementation is claimed here.

Postintegration finite-state inspection remains necessary for map/history behavior outside this input-bound argument. Native supplied-pixel counts are not counts of voxel updates or evidence of coverage, support, accurate clearance, safe routes or a winning mapper.
