# Voxfield synthetic feasibility checkpoint — incomplete, with a reproduced defect

2026-10-29. **No recorded frames, real-data mapper comparison, accuracy improvement, phone result or physical-safety claim.** This packet contains source and aggregates only: no binary, sensor recording or reference geometry.

## Actual results

- Built all26 official core source files at `78ee6403720e0aed87f4720c04c813bb38a3b260`, unchanged, in an isolated `libvoxfield_native.so`/protobuf/include tree. ELF closures exclude stock Voxblox core ABI mixing.
- **9/10 upstream targets passed.** `upstream_layer_utils` exceeded the2GiB process-tree RSS cap and remains **RESOURCE_BLOCKED**, not skipped-to-green or passed. No rerun/rescaling. Exact subcase is unknown.
- Original13 adapter fixtures passed.
- Source-derived N1 normal provider passed1303 assertions with ASan bounds and UBSan. LeakSanitizer failed in the execution environment; one reviewed same-binary rerun disabled leak detection only. **Leak checking unavailable.**
- NP fixture suite passed24 named checks, then **failed** `grazing control missing disabled observation`. Later gradient-serialization and malformed-normal checks were not reached. Suite remains failed.

## Separate diagnostic explains the original-axis failure

An independently frozen diagnostic used the unchanged fork core. For original ray(0,0,1), native RayCaster emitted index(0,0,0)31times, rather than progressing through z indices0–30. Probe(0,0,24) was unallocated with normals off and on. Moving a query would conceal this failure, so the original failed test is retained.

A separate oblique ray(.13,.23,1.01) visited all40 analytically expected cells. At its near-surface probe, normal-off weight was0.9175153375 and distance0.02998125553m; perpendicular-normal-on weight was0, consistent with the intended grazing rejection. This control does not make the original-axis test pass.

Read-only source inspection found always-false `abs(ray_scaled.axis)<0.0` guards followed by division by the zero axis component in both pinned stock and fork `integrator_utils.cc`. The fork's axis failure is now observed; **the stock binary was not tested**. No source correction was applied. Translated-axis/translated-oblique controls were suggested after this two-case freeze and were not run. `RAY_TRACE.json` contains complete expected/actual lists and off/on outcomes.

## N1 is explicitly adapted—not the released ROS provider

`n1_adapter.h` retains BSD attribution and documents changes: organized original integer-pixel axial-mm data; forward+u/+v cross product; no wrap or out-of-bounds access; fixed strict5% axial gate; finite cross-product norm>1e-6; unavailable normals zero with reason; all admitted points/order retained. No GT normals, smoothing, interpolation or floor classifier.

The norm threshold has square-metre units. At focal lengths810.825px, synthetic0.3m clean plane produced6degenerate+6boundary normals while retaining12points;1m and3m each produced6valid+6boundary. Thus this fixed threshold can reject close/high-focal-length normals on clean surfaces. It is not a measured sensor uncertainty model. No threshold tuning was performed.

## Limits and failure history

Initial compile stopped because our NP fixture omitted `voxblox/io/mesh_ply.h`; an independently reviewed include-only repair was the only source change after first freeze. Official core/test code stayed unchanged.

All work was single-worker, reused dependencies read-only, with no installs/network/spend or publication/ref changes. Hard limits remained900cumulativeCPU/900original-freeze wall,2GiB sampled treeRSS,512MiB newdisk; the RSS cap stop is preserved. Final aggregate conservativeCPU191.93s and original-freeze-to-diagnostic-end wall627.65s. RSS peaked2,165,166,080B at the terminated test; that is **an enforced cap breach**, not a within-cap successful test. Resource sampling is100ms and may miss instantaneous peaks; CPU child accounting is conservative.

Hazard checks here are limited existence/point checks, not complete obstacle coverage or swept-body safety. N1-to-mapper end-to-end fixtures cover plane/hole, not all tiny-toy/drop/overhang cases. Mixed/repeated-view signs and cached-gradient+zero-normal behavior remain pending. A12cm patch is not proof of tiny-toy detection. No recorded-prefix admission follows automatically.

## Reproducibility

- [Pinned official source](https://github.com/v4rl-ucy/voxfield/tree/78ee6403720e0aed87f4720c04c813bb38a3b260), BSD-3-Clause: see `VOXFIELD_BSD3_LICENSE` and `SOURCE_PINS.json`.
- `CMakeLists.txt` documents the26-source/10-target isolated core build; all paths supplied as CMake variables. Fixtures are synthetic-only and require retained upstream source/dependencies.
- `STATUS.json`, `NP_CHECKS.json`, `N1_CHECKS.json`, `RAY_TRACE.json`, `RESOURCE_LEDGER.json` preserve aggregate outcomes, including unresolved failures. `SHA256SUMS.txt` identifies packet files.
- Build/gate execution scripts and original immutable freezes/logs remain in the private coordination evidence folder; this source packet is not a claim that every standalone build environment has been validated.
