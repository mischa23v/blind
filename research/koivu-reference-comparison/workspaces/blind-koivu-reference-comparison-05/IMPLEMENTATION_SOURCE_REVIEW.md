# Independent implementation review: fixed Koivu depth/reference comparison

2026-10-26 04:13 UTC. Source/receipt inspection only. This reviewer did not load the reference mesh, decode the evaluated depth images, run analytic geometry or execute recorded metrics.

**Ready for the single maintainer-authorized eight-frame, 368,520-ray recorded pass. No concrete source-review blocker remains at the reviewed cut.** This does not predict completion within budget or establish physical accuracy/navigation safety.

## Exact reviewed cut and authority

- Protocol: `44d72636e6b7636983767d643b0cc0e1c1025425767c8f7184dca4f398695664`.
- `comparison.py`: `af5f7d052a394ab7c5a8024af3467664cc69f591aa042eed685697daee4182db`.
- `reference_geometry.py`: `2e9454fb5282bb8c7cdba0eb4a6e7da35820098579352800f953c8795503d5f8`.
- `run_bounded.py`: `40959517326554063349481e79e57ffd839c7499643efa7942ae109cb735adbe`.
- Evaluation `CONFIG.json`: `d90e11a4dd09f31d9caf7c5c0999a2899dc2f2aedc2342d81ef502f7130cb7de`.
- `DATA_CONFIG.json`: `e3c2e58971bcad597a6887df173fc83f92c50d8ec6c8c5a304c0cccc9ae8bb59`.

The maintainer explicitly approved **600 CPU / 900 wall seconds**, **3 GiB sampled process-tree RSS**, **64 MiB new outputs** and **768 MiB disk reserve**. This supersedes the earlier proposed 300/360-second envelope; it is not a silent reviewer-authorized expansion.

## Geometry and existing-library reuse

The camera rays use the source-backed half-pixel convention and actual per-frame Double intrinsics. Camera matrices and the author registration have distinct rigid-camera and positive-uniform-similarity checks. No orthogonalization, registration refit, scale fit or camera correction is performed.

With A mapping phone-export coordinates to FARO and C mapping OpenGL camera to phone-export coordinates, transforming origins/directions by **A×C** and querying the one original mesh is algebraically equivalent to the author's inverse-A mesh transform. Recovering the hit through inverse(A×C) yields axial camera depth; the independent segment-parameter expression checks that conversion. The fixed far endpoint covers every original mesh AABB corner plus one FARO coordinate unit and never depends on tested sensor depth.

The chosen existing engine is **VTK 9.3.1 `vtkOBBTree`**, first-hit overload with one reused `vtkGenericCell`, explicit build, nonempty root-representation check, level 24 and 64 cells/node. The [official first-hit implementation](https://github.com/Kitware/VTK/blob/v9.3.1/Filters/General/vtkOBBTree.cxx#L915-L980) traverses a depth-sized stack and retains the smallest segment parameter. It is not the all-intersection overload that uses closed-surface entry/exit semantics. The [triangle implementation](https://github.com/Kitware/VTK/blob/v9.3.1/Common/DataModel/vtkTriangle.cxx#L544-L640) is plane/interior based and two-sided.

This avoids the per-ray full-cell visited bitmap found in [StaticCellLocator](https://github.com/Kitware/VTK/blob/v9.3.1/Common/DataModel/vtkStaticCellLocator.cxx#L1162-L1164) and [CellTreeLocator](https://github.com/Kitware/VTK/blob/v9.3.1/Common/DataModel/vtkCellTreeLocator.cxx#L718-L720). It does **not** prove the 17.8-million-face OBB build/query will finish within budget; runtime/memory must be observed and failed attempts retained.

## Precision caveat retained, not hidden

The original PLY has Float64 coordinates, but VTK 9.3.1's [PLY reader](https://github.com/Kitware/VTK/blob/v9.3.1/IO/PLY/vtkPLYReader.cxx#L99-L140) reads vertices into Float32 storage; [output points are explicitly Float32](https://github.com/Kitware/VTK/blob/v9.3.1/IO/PLY/vtkPLYReader.cxx#L354-L366). Reporting the actual VTK scalar type is necessary. Double query arithmetic does not recover discarded source precision. The protocol addendum explicitly permits/discloses this conversion; do not describe the in-memory vertex coordinates as bit-preserved original Double geometry. Reader rounding is another limitation in a processed-reference disagreement result, not a raw sensor uncertainty bound.

## Input, metric and failure checks

- Fixed source indices/basenames and per-frame pose association; absence of distortion parameters is an explicit author-pinhole assumption, not fabricated undistortion. No confidence/tracking/body/LLM authority is introduced.
- Pinned original mesh/alignment/pose/depth inputs; unchanged source and data checks before/after. The evaluated cut requires the successful convention receipt and the same three source hashes; CONFIG separately pins the convention result/receipt. Convention mode does not read the large mesh or recorded depth inputs.
- The mesh is validated for exact counts, finite vertices, triangular offsets and in-range indices in bounded chunks. Releasing unused normals/colors does not simplify topology or transform positions. The original mesh is not duplicated for registration.
- Original unsigned-16 depth values are converted to nominal metres, with zero treated as unavailable. No confidence-2 substitution, native distance cutoff, interpolation, favourable-frame replacement or discrepancy-based exclusion occurs.
- Every scheduled address has exactly one paired/sensor-only/reference-only/neither status. All eight frames and 368,520 rays are required for completion. NPZ arrays retain scheduled identities, both depths, status, edge category and face index, including missing-reference NaNs.
- Per-frame and pooled signed/absolute statistics use fixed depth/edge categories and linear quantiles. Empty bins return null metrics. Frame totals and paired stratification reconcile; image tiles are deterministic. VTK errors, invalid hit parameters or contradictory axial depth fail rather than becoming benign no-hit rows.
- The wrapper checks live-tree plus waited-descendant CPU, sampled RSS, aggregate outputs and disk reserve, uses process-group termination, retains partial evidence and publishes with no-replace rename. Its receipt explicitly disclaims hard-cgroup/sandbox guarantees and sampling limitations. It does not turn child completion into a physical-safety conclusion.

## Existing convention outcome inspected

The owner's separate convention receipt reports five checks: zero half-pixel golden discrepancy; 2 m nearest hit for both windings; similarity/rotation/translation equivalence within `6.661338147750939e-16` m; and a retained NaN no-hit. Runtime reports VTK 9.3.1 with Sequential backend. These were inspected as existing results, not rerun by this reviewer. They test the declared conventions, not comprehensive numerical robustness or physical scene accuracy.

The recorded pass must still be reported as **offline author-registered processed iPhone-depth versus cleaned FARO-derived surface disagreement**. The reference has edited/completed surfaces without a verified support mask, and its registration is device-derived. No raw absolute accuracy, hazard recall, clearance or A-to-B claim follows.

Any later execution/result review should be a separate addendum; do not mutate this source-review cut after packet sealing.
