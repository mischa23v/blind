# Fixed supplied-map game checkpoint: one short arrival, loop still unresolved

**The v3 simulation actor reached the same fixed goal:** 108 ticks, 1.715355 m horizontal travel, final goal error 0.322712 m (declared tolerance 0.35 m), zero non-ground body contacts and zero margin contacts. The terminal command was stopped and no motion remained pending. Status is deliberately **`arrivalReferenceModelOnly`**.

This is one short, offline, **provided-map** A→B episode under a declared planar-ground simulation model—not fog-of-war mapping, live iPhone sensing, physical clearance, a completed room loop, or a multi-layout safety result. All **108 ticks carried unresolved low-obstacle exposure** in the permissive phone-derived candidate map. Those flags were logged, not proven clear.

## Preserved sequence, without inflating episode counts

| Stage | Actual outcome |
|---|---|
| Selector attempt 01 | Wrapper failed before map loading: child attempted to raise inherited CPU hard limit from 60 to 65 seconds. Exact old source and failure remain. |
| Selector attempt 02 | Same masks, seed, body, thresholds and candidate order; bounded wrapper completed after correcting the limit. First accepted route was pair index 56 after 57 native queries. These queries are **not movement episodes**. |
| Fixed-foot pilot 01 | 0.175355 m travel, no arrival; zero actual-body hits, one margin contact near the floor. Failure retained, not relabeled success. |
| Raw-ground-following v2 | 0.315355 m travel, no arrival; stopped on unknown reference support during motion. Zero body/margin contacts alone did not make this a success. |
| Controlled planar-ground v3 | Same start, goal, route, actor XZ/yaw/controller/profile and arrival tolerance; changed only the separately declared world ground-support model. Arrived as described above. |
| Phone-only loop feasibility, run 01 | Source-writing race detected by postrun hash verification. Partial result is not a verified terminal run. Recovered old source snapshots match the original frozen hashes. |
| Phone-only loop feasibility, run 02 | Mutable Matplotlib-cache output census raised `FileNotFoundError`; harness failure preserved. |
| Phone-only loop feasibility, run 03 | Bounded complete-census retry fixed only accounting. Technically verified, but returned **`noFixedSideWaypoint` (WEST)**: zero route legs and **zero movement episodes**. It does not prove global loop infeasibility. |

The WEST diagnostic is a separate saved-mask-only calculation, not a model change or another episode. In the fixed west half-plane it found 344 walk centres but zero centres passing the specified disc test; the maximum reported conservative disc-clearance estimate was 0.300055 m against the declared 0.375 m search radius. The geometric target remains an unresolved component proxy, not an established semantic “table.” No three-lap run occurred.

## What owns each decision

- **Candidate map and route:** exact supplied phone-derived occupancy-threshold-0.7 split masks, original level transform, inherited sampled footprint checker, and pinned native Recast/Detour. The supplied metadata archive has reference arrays, but `CandidateMap` does not materialize them. No new search, SLAM or LLM navigation authority is added.
- **Controller:** candidate route and explicit goal only. Query endpoint projection is reported/limited but never teleports the actor. The actor's applied increments determine its pose; independent reference geometry does not steer, choose endpoints, relocate the start or select a replacement route.
- **World support and scoring:** separately owned processed/registered reference mesh, finite support probes and declared continuous enclosed body/margin sweeps. Ground support is a simulation assumption. Scored ground triangles are separate from obstacle contact events; 206,746 repeated ground triangle reports are not 206,746 collisions or trials.
- **Nominal profile:** 0.45 m width × 0.30 m depth × 1.60 m height, plus a separate 0.15 m horizontal margin per side; 15 Hz; nominal 0.30 m/s, maximum 0.375 m/s. These are declared game-frame dimensions, not measured wearer dimensions or calibrated phone odometry. This checkpoint contains no live mount, confidence, tracking, cane-credit or warning-stream validation.

## Ground model and units are explicit limitations

V3 retains the originally seeded, shared-edge, low-slope ground component; fits one robust broad support plane; and permits a separately declared local residual rule for excluded noisy microfaces (20 cm patches on a 10 cm lattice, 2 mm residual criterion, specified slope/connectivity limits). The world uses the one fixed plane for actor Y while keeping the unchanged nine raw support rays and their finite association/hole checks. It does not claim that finite probes prove continuous floor support. Other reference geometry remains in collision scoring. The 2 mm ambiguity band and shallow ramp-like objects remain unresolved.

The reference is a cleaned/completed mesh with no measured-versus-completed support mask, not perfect physical truth. The fitted ground region is a training assumption, not an independent floor label. V3 is therefore a useful controller/world-model component result; it is not evidence that unresolved small obstacles are absent.

Plots and result distances use nominal processed-phone/game metres. The author phone-to-reference similarity includes positive scale approximately 1.02079084. Do not silently interpret these values as independently calibrated human dimensions or measured walking distances.

The permissive map is supplied in advance; this episode does not test progressive sensing, dynamic obstacles or perturbed motion. The stored impairment module is a code dependency, not proof that all its conditions were run here. The strict-clearance map's reported lack of 2–6 m routes remains separate from this permissive experiment.

## Included evidence

The mirrored `blind-split-candidate-game-03/` tree contains exact source cuts, frozen protocols, source reviews, acquisition receipts, route selection, fixture logs, all three movement histories, source-race snapshots, all three loop attempts, the unchanged WEST diagnostic, three small actor-trace NPZs and analytical plots. Direct controller/scorer/ground/native-binding source dependencies and native provenance/license are included at their original sibling-stage relative paths.

Historical fixture logs include 7 adapter checks, 20 oriented-container checks, 7 controller checks, 31 final combined v3 checks and 24 loop checks. They overlap and are **not summed into independent scenarios**. The helper's original failed authored-slope fixture and subsequent correction are preserved; helper behavior was not changed to make that fixture pass. A failed invocation due to missing `/usr/bin/time` is likewise retained. Packaging did not rerun any fixture, numerical diagnostic, mapper, reference query or episode.

`HISTORICAL_SOURCE_MAP.json` matches each frozen source/protocol identity to preserved exact bytes, including four historical-path aliases (the old selector plus three loop-race snapshots). `NORMALIZATION_MAP.json` records every copied file's original/public bytes and hashes. `EXTERNAL_DEPENDENCIES.json` identifies omitted runtime/data prerequisites. `MANIFEST.json` is the exact public payload inventory.

The analytical plots were inspected as diagrams, not photographs; no people or personal documents appear. The historical v2 figure has overlapping lower labels and is retained unchanged as a diagnostic display, not repaired or used for scoring. No raw RGB/depth or generated sensor imagery is published here.

## Verification and reproduction boundary

Run `python -B validate_packet.py` for read-only file/hash/JSON/path checks. It does not import scientific modules, decode NPZs, load reference geometry, or execute fixture tests. Historical results and executable source bytes stay unchanged. Five public log/receipt copies required path normalization; the exact map records which. Hash fields retain the historical original identities.

Normalized frozen/receipt copies are **not byte-identical historical launch files**, and copied dependencies alone are not a clean-machine rerun guarantee. Reproduction requires the omitted pinned masks, registration/reference assets and compatible native/runtime dependencies, reviewed local paths and a newly frozen launch identity. Do not substitute a different map, remove unresolved flags, or silently alter body/goal/support rules and attribute the result to this checkpoint.

## Provenance and exclusions

Phone-derived masks and upstream checker code were acquired from repository commit `57fdf25f2c17b3f1cf6c5aba1156756c1e808eee`; acquisition receipts retain exact public source identities. Native Recast/Detour is pinned to `9f4ce64458dfae86e1239c525ddc219c4e9e06f1`, with its original zlib license. MuSHRoom Koivu provenance/CC BY 4.0 attribution is retained separately. Existing repository ownership applies to authored adapters; no new license or author endorsement is invented.

Excluded: the input mask NPZs, full FARO mesh/cloud/archive, phone archives/raw RGB/depth, native binary, upstream engine source already separately published, installed packages/caches, active v4 ground-skip comparator and unapproved topology/new-loop work. No evidence from active or future work is implied. The previously sealed 207-file TSDF packet is a separate artifact and was not modified.
