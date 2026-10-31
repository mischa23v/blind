# Separate C1-only recovery — prepared for conditional admission

The original 300-CPU-second three-arm batch remains **RESOURCE_BLOCKED** and its global output admission remains false. This is a new, separately authorized stage, not a resumed map or retrospective cap increase. Root set a new cap of180CPU/210wall/oneCPU/2GiB/256MiB after reviewing measured costs. Execute only after independent final source/guard review; no automatic scoring or B/C0 release.

## Exact delta
`SELECTION_ONLY.patch` changes only selected native arm from B/C0/C1 to C1 and labels the output accordingly. All preflight/shared-validator/hash logic, formulas, config, full-pixel admission/order, original per-frame K/poses, D1 core, N2 provider, mesh extraction and dataset split stay unchanged. A fresh empty C1 map and persistent integrator process all265 frames. There is no TSDF reload or partial-map continuation; the terminated C1 map was never exported.

Reuse the same exact265 training rows and530 raw files, all29heldout IDs excluded. Complete initial streaming preflight before any engine, then stream/revalidate all265 for C1 with actual raw-buffer SHA256 and deterministic ledger equality. Same original count checks, finite state checks and source/input post-hashes. No geometry/scorer/reference feedback, parameter change, classifier, smoothing, input omission, install/network/new core build or spend.

## Budget evidence
Original initial preflight36.13s. C1 completed245frames in85.36s before the whole batch hit its cap; linear265projection≈92.3s plus mesh≈3s and compilation/hash/monitor overhead. These measurements support a180CPU/210wall ceiling but do not guarantee completion. Stop and preserve any cap/failure; no automatic retry or enlargement. Dedicated new run directory; original source, logs, failed receipt and B/C0 meshes remain untouched.

Expected sole mesh `run/C1_native_mesh.ply`; final raw counters/ELF/output freeze and output-admission receipt must all pass. This stage can admit only its own C1 output for subsequent independent review. B/C0 remain quarantined until root separately decides their per-arm admission; no adapter or guard here can release them. Accuracy remains unevaluated.
