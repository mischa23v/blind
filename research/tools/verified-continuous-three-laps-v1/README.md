# Three continuous assisted table laps — verified milestone

**Stage69 completed three continuous laps with one actor, no resets and all15 original goal arrivals:61.791889m horizontal /61.903697m actual3D travel. Actual and predicted non-floor body/underbody contact counts were zero.** Independent saved-evidence review passed.

| Measure | Result |
|---|---:|
| Continuous laps / drained goal arrivals | 3 /15 |
| Horizontal distance | 61.791889m |
| Actual3D distance, including support midpoints | 61.903697m |
| Winding per lap / total | −1,−1,−1 /−3 |
| Committed movement ticks | 4,909 |
| Total ticks / saved states | 4,924 /4,925 |
| Actor instances / initial settlements | 1 /1 |
| Final gap to original nominal start | 33.052936cm |

Every arrival used the unchanged **35cm full-3D goal region**. Lap1 ended33.052121cm from its start. Laps2/3 began at the preceding actual endpoint and deterministically returned to that same pose to floating-point precision. Per-lap winding uses a **mathematical closing chord that was not walked** and is excluded from distance. No artificial closing motion, pose reset, teleport or height snap was used. Repeated deterministic laps are not independent robustness trials.

## Preserved limits

This is assisted offline simulation in **one static recorded scene**:45×30×160cm body, **zero horizontal margin**, zero-delay nominal actuator profile, simulated delivered localization, evaluator/reference-labelled floor support and manually selected source tabletop ROI/contours. Exempted floor contacts remain **unmeasured**. Finite support probes, sub2mm ambiguity, uncalibrated ±3px contour stress and unknown source confidence remain. No collision rule, obstacle, geometry or support threshold was relaxed for these laps.

This does not establish live phone perception, moving-obstacle avoidance, noisy tracking, delayed reactions, human safety, a100journey suite or device validation. Noise/delay/margin sweeps, independently chosen scenes and live ARKit/sensor integration remain open.

## Included artifacts

- **69:** exact publication-manifest allowlist: frozen protocol, code, actual traces, lossless XZ evidence, source query receipts, all results, figure and independent reviews. Fourteen source-only actual-arrival handoffs preserve one actor/FIFO/clock. Runtime identity checks retain636 marked source exclusion spans; baseline is a validator, not an alternative planner.
- **70:** only its small explicit publication allowlist.55 Linux Swift/C-ABI checks pass for static unknown-exclusion snapshots, five same-API route pairs,636 marked spans and mesh replay parity. This does not modify the app or enable physical guidance. Build caches, transient raw fixtures and binaries are excluded.

[Prior one-lap milestone](../verified-assisted-table-loop-v1/README.md) and [separate8.432m assisted doorway round trip](../verified-assisted-roundtrip-v1/README.md) remain preserved. Older failures and source audits remain in their original checkpoint packages.

## Package and reproduction

Three deterministic ZIP groups retain original workspace-relative paths. The large XZ tick-evidence member is preserved intact, not truncated. `MANIFEST.json` pins all files and original publication-manifest hashes; `PACKAGE_METADATA.json` records archive SHA-256/Git blob identities; `PACKAGE_CHECK.json` records CRC/member/determinism checks. Each group embeds the common manifest. No source mutation or external push is performed by packaging.

These compact packets are not standalone: large original data, previous checkpoints, native libraries and toolchains remain separately pinned dependencies. Do not overwrite divergent workspace files when restoring. Updating the earlier checkpoint-restorer index requires verified new publication identities and is not silently performed here.

## Attribution

Public source: Xuqian Ren et al., **MuSHRoom**, https://zenodo.org/records/10230733 and https://zenodo.org/records/10222321; [CC BY4.0](https://creativecommons.org/licenses/by/4.0/). Derivatives include annotated public images, transformed geometry, manual exclusion hypotheses and numerical simulated traces; modifications are documented per stage. Recast/Detour upstream license is included. No private participants, private scans or user attachments are included.
