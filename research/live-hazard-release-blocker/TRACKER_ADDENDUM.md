# Priority 0 — live ground hazards and warning reliability: BLOCKED

This is an acceptance addendum to the existing belt/phone requirements, **not a new hardware proposal**. Keep `hardware/BUYING_PLAN.md`, `CONNECTIONS.md`, `PROTOCOL.md` and `research/ELEVATION_AND_LIGHTING.md` authoritative. Their independent ground-warning design and unresolved belt attitude, mounting/extrinsics, synchronization and 250 mm slant-trigger limitations remain open.

**Release condition:** before any physical movement guidance, show that missing/corrupt/stale depth never becomes confirmed floor; stairs/drop-offs and near-feet/lateral swept coverage are either reliably assessed or explicitly unavailable; and warnings arrive with a measured stopping/response allowance under declared latency and mounting conditions. No alert is not evidence of no hazard. A user's increased reliance makes this blocker especially important.

- Test timestamped raw sensor validity, unknown regions, stair edges, toys, mount changes, lateral steps, occlusion and tracking loss on a controlled rig/replay with independent truth—not children or a person approaching an unprotected drop.
- Record false-clear events, missing/late warnings, warning onset/lead time, coverage gaps and false stops. Freeze the operating envelope and limits before scoring; never derive “safe” limits from a successful room lap.
- Map routes remain proposals. Old geometry, RGB appearance, an LLM answer or a reference-world collision veto cannot grant live clearance. Existing static/synthetic successes do not pass this gate; preserve them and their failures separately.
- Current audited Koivu exports lack original timing, native confidence, raw tracking/IMU and body-to-phone calibration. They cannot establish live warning lead time. Scope this limitation to the audited inputs; do not invent fields for replay.

**Next deliverable:** a raw-input availability inventory and a frozen small missing-depth/stair-edge bench matrix, with explicit “not evaluable” results where required evidence is absent. **No physical guidance, real-user trial or certified-safety claim is authorized.** Detailed criteria: `PROTOCOL.md` in this addendum packet.
