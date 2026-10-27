# Incremental observation and original visual localization — research checkpoint

This compact source-and-evidence checkpoint contains two distinct offline experiments, not an integrated navigation system. It grants no physical movement authority.

## Completed prefix replay

`blind-progressive-prefix-preflight-77/` records the two-observation preflight. `blind-progressive-prefix-runner-78/` records the frozen, independently reviewed single run of all 294 depth observations, in original order, at checkpoints 1, 2, 16, 32, 64, 128, 192, 214, 256 and 294. It completed in 63.189 seconds wall / 63.066 seconds child CPU with 198,270,976 bytes sampled process-tree peak RSS. The first two checkpoints reproduce preflight exactly. Final known/free native occupancy volumes are 148.788875 / 122.1925 m³.

These are **air occupancy** statistics, not observed floor support, body clearance, walkable area, a route, or a completed return. Seventeen cumulative endpoints fall outside the diagnostic sample grid; its connectivity is not whole-map connectivity. Exported Polycam poses may be globally optimized using future observations: this is not causal-pose live SLAM. Confidence, original timing and mounting extrinsics are unavailable. The route-connectivity stage is unimplemented. Native source/build receipts are included; compiled binaries are deliberately excluded.

## Original visual localization v1/v2

`blind-visual-relocalization-77/` preserves the original combined-landmark baseline **0/8 accepted**, reference-candidate v2 **1/8 accepted**, and `audit-20261027/` reproducibility review. These are eight **fixed development queries from one recording**, not random queries, a new holdout, live tests, or human-navigation success. V2 was developed on the same queries. The accepted frame 50 has 0.01974 m position error, 0.2525° full-camera rotation error and 0.1881° optical-heading error against the withheld exported pose. Seven candidates were rejected. No observed false acceptance in this tiny set establishes neither reliability nor a false-acceptance rate.

Audit estimates reproduce byte-for-byte; scored results match except resource measurements. Rejected estimates include catastrophic errors and must not be used for routes. Query poses were removed from estimator dictionaries, but combined metadata had been parsed in that process; this was code-level separation, not a separately isolated blind input package. Camera heading is not body heading. No causal live localization, connector safety or human navigability is established.

The audit report's next-experiment section is a proposal at that checkpoint, not evidence of execution. Denser-reference v3/v3b, calibration audit and subsequent sequence experiments are **excluded** from this immutable original-result packet.

## Reproduction and exclusions

Archives preserve workspace-relative source paths. `MANIFEST.json` gives SHA-256 and size for every member. Original result/frozen manifests preserve raw-input hashes, runtime pins and build provenance. Raw RGB, depth, poses dataset, meshes, binaries, caches, temporary preparation backups and all stage75 blocked package/workflow material are excluded. This is consequently an auditable source/result bundle, **not a standalone runnable dataset**. Re-running requires separately available original inputs, the pinned OctoMap build/runtime, Python dependencies and OpenCV 4.14.0. Original source paths and budgets are preserved rather than silently rewritten; do not run audit scripts over preserved audit outputs.

Input dataset attribution: Xuqian Ren et al., MuSHRoom, https://zenodo.org/records/10230733 and https://zenodo.org/records/10222321 (CC BY 4.0, https://creativecommons.org/licenses/by/4.0/). This packet contains derived diagnostic results and local experiment code; it does not redistribute raw imagery/depth or third-party binaries. OctoMap upstream pin is retained in the frozen/build records.

## RAM-only transport

`memory_package.py --metadata` prints deterministic archive sizes, SHA-256, Git blob SHA and base64 lengths. `memory_package.py GROUP OFFSET` emits at most 120000 base64 characters at a zero-based character offset. `memory_package.py --check` validates member hashes, determinism and archive integrity in memory. No ZIP is written locally. `PACKAGE_CHECK.json` records the packaging check, not a new experimental run. Only the parent task may publish externally.
