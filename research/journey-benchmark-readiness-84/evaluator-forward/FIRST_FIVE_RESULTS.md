# First-five checkpoint — 5/100 frozen movement episodes

This is a historical checkpoint at five completed episodes; the other 95 outcomes are outside this report, not a statement of current execution status.

All five conditions on **pair0 only** arrived. These are five actual **simulated translational episodes in recorded real-room geometry**, not five distinct routes, five rooms, live phone trials or completion of the100-episode matrix.

|Episode|Condition|Ticks|Actual horizontal metres|Final original-goal error,cm|Drained/current-observation arrival|
|---:|---|---:|---:|---:|---|
|0|nominal|238|2.775828730|34.264857|Yes|
|1|command_delay|262|2.838484704|28.840529|Yes|
|2|temporal_jitter|262|2.820000000|30.676381|Yes|
|3|extra_translation|220|2.783000000|33.539025|Yes|
|4|tracking_interruption|261|2.775828730|34.264857|Yes|

Total bounded process compute:1136.628021CPU seconds /885.845866wall seconds. No geometry, source routes, seeds, conditions, body/support rules or acceptance tolerances changed after results. All20 pair-specific evaluator floor caches were frozen before these movement episodes.

All five had zero committed/predicted non-floor body contacts and zero predicted underbody contacts. A reference-world veto remains an evaluator oracle, not phone detection; zero contacts alone is not the arrival criterion. Exempted floor contacts are unmeasured. Final original35cm full3D regions, fresh post-motion observations, zero applied motion and drained FIFOs were checked independently from saved evidence.

Command delay retained3moving ticks after an issued zero command. Jitter retained measured batch progress and had2ticks without usable pose; it is temporal delivery jitter, not noisy spatial estimation. Tracking interruption withheld all30captures at ticks60–89 and resumed; it is not real ARKit relocalization.

`reviews/RECOUNT_005.json` independently recounts CSV horizontal distance, committed tick3D increments, both body half-sweeps and both underbody half-segments, final goal/queue state, and evidence hashes without rerunning world geometry. A preparation error in the first readback script (dictionary mistaken for list) was corrected and preserved in `reviews/RECOUNT_PREPARATION_ERROR.json`; it changed no runtime, evidence or threshold.

Reference/manual-floor support, supplied poses, manual unknown tabletop ROI, zero body margin and missing source confidence remain explicit. This does not close live-hazard, localization, hardware or human-safety gates. Runtime status is owned by `EPISODE_LEDGER.json`; this note captures the first-five checkpoint only.
