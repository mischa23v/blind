# Koivu / VARPU / Coffee: bounded room tests, failures and one partial arrival

**New offline partial movement only: 2.760 m, 139 ticks, nominal 45 × 30 × 160 cm body, zero margin.** The original main-room goal region was reached with recorded non-ground body/margin contact counts 0/0. **125/139 ticks retain unresolved-low phone-map exposure.** Ground contact is unmeasured/null, not a measured zero. Nothing here authorizes human navigation or establishes live safety.

| Test | Saved outcome | What did not happen |
|---|---|---|
| Main-room horseshoe, camera 92 → 120 → 200 → 220 → 20 | 99 phone-only native queries across three unchanged profiles; first leg admitted, each profile's 32 second-leg candidates failed | No full horseshoe movement; later legs unattempted |
| VARPU entry/return, outside 130 → inside 160 → outside 130 | 96 entry queries, zero admitted | No entry episode; return untested; separate closed door's far side unknown |
| Explicit first-leg-only main-room episode | 2.760 m / 139 ticks; original-task error 0.326103 m horizontal / 0.326130 m full 3D; final actual stop with drained motion queue | Not a room traverse, loop, area-coverage measurement, 55 cm envelope result or safety certificate |
| Coffee fixed-map routes | 16/42 nominal45, 14/42 margin55, 18/42 abstract28 accepted sampled-mask routes | No actor episode, physical movement or FARO triangle-scored movement |

## Read the evidence

- `blind-remaining-room-partial-executor-25/RESULT_README.md` gives the partial episode, prior support authority, independent recount, limits and exact files.
- `blind-remaining-room-partial-executor-25/postrun/room-coverage.png` shows actual partial movement, retained hazards, excluded western region and failed/untested links. Dotted task links are not traversed paths. Shading is sampled visited envelopes, not floor-area coverage.
- `blind-small-room-identification-23/README.md` and its normalized evidence manifest identify the wooden/glass VARPU entry/return doorway from original public-dataset images. Images are not duplicated. Camera positions are not measured body centres; threshold samples are not jamb endpoints or measured doorway width. A separate closed gray door near exit signage has no observed far side.
- `blind-coffee-room-traverse-24/RESULT_SUMMARY.md` and `independent/` preserve independently recounted local-route results and the later isolated reference-column triage.

**Coffee is the older b0be8628b159e0fc0446a7af8c57c13c99553a77 supplied `coffee_floorfix` split0.7 candidate, NOT the latest color/v3 candidate.** Every accepted route touches unresolved-low cells; two accepted queries per profile are only 5 cm. Broad cross-group routes remain native-incomplete. A point-grid witness is not an accepted body route or physical-width measurement. The later proxy triage covers one fixed witness neighborhood, not all barriers: 158 blocked cells partition into 93 low/body-geometry proxies, 47 floor-present/no-saved-obstacle proxies and 18 no-floor proxies. Vertex columns are not triangle/body clearance tests. A ±6 cm floor proxy does not disprove dip/support flags; the reference body band is 0.30–1.80 m, not exact 1.60 m swept geometry. No blockers were removed.

## Reproduction levels

1. **Packet validation:** `python validate_packet.py` verifies exact delivered bytes, JSON syntax, path/privacy checks and source-copy identity. `MANIFEST.json` excludes itself and `VALIDATION.json` from its payload list; the private upload plan hashes every delivered file.
2. **Self-contained saved-evidence arithmetic:** `python packet_recount.py` requires Python + NumPy and reads only included JSON/trace data. `PACKET_RECOUNT.json` is its recorded PASS output. It does not load maps, query native routing, rescore reference geometry or validate contact truth independently.
3. **Historical worker recounts:** original scripts/receipts are preserved. They additionally expect their pinned historical data/source layout; public path normalization and excluded raw assets mean they are not claimed plug-and-play in a clean checkout.
4. **Scientific replay:** use a separate versioned reproduction copy, restore required historical layout/assets and exact manifests, and satisfy existing native/runtime prerequisites. All pinned Python/C/C++ sources from the four current freezes are included unchanged. Large raw FARO/phone data and native binaries are deliberately external. Wrappers create run directories exclusively: do not overwrite frozen runs. `restore_results.py` restores only two compressed historical north/south JSON result documents in a reproduction copy; it does not run geometry or modify the sealed packet.

`DEPENDENCIES.json` identifies included dependencies and prior packet paths without falsely calling unpublished stages public. Stages20/21/22 were unpublished at handoff; minimum stage20/21 source/context plus prior north plot result/trace are included. Stage22 is historical failure context, not new execution or a claimed publication. Other prior packet paths are unverified pointers pending remote review, not a guarantee of remote availability.

## Integrity and boundaries

Original results, source, freezes and failed attempts remain untouched. `NORMALIZATION_MAP.json` maps every original/public hash: only public-copy local-path placeholders and private coordination wording changed; executable sources are byte-identical. Original embedded hashes intentionally keep original-file identities. `COMPRESSED_RESULTS.json` records deterministic lossless historical JSON compression.

This packet includes the three unchanged profiles, frozen selection protocols, full current result/query receipts and trace, fixtures/logs, final plots, sources and independent saved-data reviews. It excludes screenshots, private participant/user metadata, raw image copies, raw FARO, bulk data, environment caches, future map corrections and the separate evolving route-disconnection/source-cause investigation. No GitHub write, raw-data download, deletion, geometry rerun, human/device trial or live-safety validation occurred during packaging. Prior source ownership/licenses are unchanged; no new redistribution grant is invented.
