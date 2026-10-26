# Retained-pose pilot failure and checkpoint restoration update

## Failed retained-pose experiment

The retained-pose jitter candidate did **not** reach its goal: it exhausted the original 450-tick budget after 1.240 m. The previous stop-on-no-new-packet baseline reached the goal in 370 ticks and 2.800 m. No-pose stop ticks fell from 193 to 2, but the journey became worse, not better. Zero predicted body/underbody contacts or support vetoes does not turn this into a navigation pass.

The preserved packet diagnosis identifies a source-waypoint progress problem: an already released observation fell within the unchanged 1 cm corner radius, but coalescing discarded it in favor of a newer observation outside that radius. Reusing delayed yaw also repeated steering corrections. This is a controller/transport failure, not evidence that the corridor is too narrow. The original failed run, frozen inputs, exact trace, independent recount and diagnostic are retained. A subsequent controller change is **not** part of this packet and cannot replace this failure.

## Separate restoration-index update

The unrelated restoration utility also carries the local number 74; its directory is explicitly named `blind-checkpoint-restore-update-74`, not the movement experiment directory. It preserves all seven old index entries and adds thirteen verified archive groups (twenty total). Its original stage 62 restoration verifier is unchanged. Fourteen fixtures and independent review pass. No real-workspace restoration or large download was performed.

The stage 73 archive emitter now reads its two pinned original wrapper snapshots instead of the later readable summaries. All three original archive hashes reproduce exactly, including member hashes, CRC checks and byte-identical repeated builds. Original archive manifests and bytes remain unchanged. Run the assertion-based emitter under ordinary Python, not `python -O`.

## Limits and provenance

Movement evidence is one short synthetic route in one static recorded room, with manually assisted source ROI and evaluator/reference floor support, a 45 × 30 × 160 cm zero-margin body, unknown source confidence and unmeasured floor contacts. This is not live iPhone navigation, human-safety validation or the planned 100-episode suite. Earlier successful assisted laps and doorway round trip remain separate results.

Public source: Xuqian Ren et al., MuSHRoom, https://zenodo.org/records/10230733 and https://zenodo.org/records/10222321, CC BY 4.0. Derived geometry and simulation changes are documented in each checkpoint. Recast source credit/license is retained. No private participant data or user attachments are included.

Each deterministic ZIP embeds the common manifest; groups retain workspace-relative paths. Dependencies remain separately pinned, so these are not standalone environments. Do not overwrite divergent files when restoring. Stage 75 Apple/package CI and subsequent stage 76 controller work are excluded.
