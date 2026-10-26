# Independent stage-06 implementation review

Reviewed 2026-10-26, before the single recorded performance retry. **Ready: no concrete blocker found for the authorized bounded offline comparison.** This review did not execute code, load VTK, load the mesh, decode frames, compile, download data or modify any implementation. It is not an accuracy, completeness, collision-safety or runtime guarantee.

## Exact reviewed cut

| File | SHA-256 |
|---|---|
| `comparison.py` | `3915ee3db74f8dfdbe925cac9713e5958326163e6b0be8172036aa6aa96f664f` |
| `reference_geometry.py` | `266026051a781f122a59187f599688e8c5eb38807984b7e607401e7b4356386d` |
| `run_bounded.py` | `c74bbbd8757a2eac52fe5d4a7ecef632971974092a2af12cacbb70a1b3c9ba38` |
| `CONFIG.json` | `e98938f3c0a3ddcc39070c3ffbe0897f6d61f2b4bf32f6b32dfa4f6bc73f431e` |
| `../blind-koivu-reference-comparison-proposal-06/PROTOCOL.md` | `02d14c36dfd7225c7e920314ae40eb9d1af51d98772f708867d85e80adb533a6` |
| Unchanged `DATA_CONFIG.json` | `e3c2e58971bcad597a6887df173fc83f92c50d8ec6c8c5a304c0cccc9ae8bb59` |

The review compared all three source files and the protocol against the previously reviewed stage-05 cut, inspected the evaluation config and read the completed analytic convention report/receipt. The three convention receipt source hashes match this exact evaluation source cut. The config pins the actual `vtkCommonDataModel` extension supplying StaticCellLocator, the PLY extension, original input hashes, and the convention results/receipt. Extension pins do not by themselves establish hashes of every transitive shared library.

## Changes and acceptance

- The backend is installed **VTK 9.3.1 vtkStaticCellLocator**, using the existing generic-cell first-hit overload. It explicitly enables automatic divisions, sets 16 target cells per node and a maximum 2,097,152 buckets, builds once and checks positive divisions and VTK error events. These settings are supported; no ignored OBB-specific `MaxLevel` setting remains. There is no geometry simplification, transform duplication or native search rewrite.
- A source concern in CellTree's single-nearest overload was independently reproduced by the owner's analytic diagnostic: input plane order 2, 4, 1 m returned 2 m, whereas Static returned the actual nearest 1 m. This is a specific installed-version/fixture result, not a claim about every CellTree query or version. The rejected backend's result is retained.
- All six owner-executed analytic checks passed: half-pixel ray golden; first surface with both windings; translated/rotated/similarity-transform equivalence; the unsorted 2/4/1 ordering fixture; and no-hit staying missing. The report contains no recorded frame evaluation. Its maximum reported transform-equivalence difference is approximately `6.66e-16` nominal metre. These limited checks are not a comprehensive ray tracer proof.
- The scientific evaluation is unchanged: eight fixed correlated frames, 368,520 scheduled stride-4 rays; actual exported depth; fixed author pose/registration; half-pixel convention; geometry-only ray extent; two-sided surface queries; inverse-transform axial-depth cross-check; all four availability categories; unchanged depth/edge/tile bins; no fitting, metric tuning, fabricated confidence or exclusion of large disagreements.
- Progress now distinguishes mesh loading/validation, locator build entry/completion, query entry, **first native query return**, every 4,096 completed-ray checkpoint, query completion and frame completion. The first-return event is emitted before the no-hit branch, so an absent hit does not hide progress. Child logs carry wall/CPU/peak-RSS observations; the separate driver appends approximately two-second process-tree resource heartbeats.
- The latest maintainer-authorized envelope is **1,800 CPU seconds / 2,700 wall seconds**, **3 GiB sampled process-tree RSS**, **64 MiB derived output**, and **768 MiB free reserve**, one recorded retry. These values agree in the current protocol and runner. They supersede the earlier 600/900-second proposal described in `LOCATOR_SOURCE_REVIEW.md`. No new retry is implied. Bounds remain sampled watchdog limits plus per-process/per-file limits, not a cgroup or hard aggregate quota; output checks account for the heartbeat.
- Previous source/input before-and-after verification, exclusive staging, no-replace publication, failure preservation, child-group termination and controlled environment remain in place. No new network or install path was introduced.

## Remaining boundaries

Static's six-double-per-cell bounds cache and geometry-dependent cell fragments can still consume significant memory; its per-query visited bitmap still incurs cumulative work. Passing tiny fixtures does not guarantee this full reference mesh will finish. Stage 05 remains a preserved budget failure with no completed metrics; its missing build-complete checkpoint does not establish an exact bottleneck.

Any successful result must be labeled **offline fixed-author-registration processed iPhone depth versus cleaned FARO-derived reference-surface disagreement**. The reference has edited/completed surfaces without a verified measured-support mask; camera/registration/export/reader precision are contributors. This is not isolated raw sensor accuracy, detector recall, body clearance or navigation success. Runtime is measured on the recorded Linux CPU environment, not an iPhone.

This note is complete and should remain unchanged after its hash is handed off. Put eventual result review in a separate addendum, not an append here.
