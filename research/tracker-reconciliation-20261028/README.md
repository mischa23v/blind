## Combined source checkpoint — publication annotation, 2026-10-30 17:41 UTC

**This checkpoint includes the reviewed continuation labelled “unpublished” in the unchanged 17:30 snapshot below.** That label is now historical. The published Boolean repair is retained; native validation of this **combined source** has not run at preparation time. Source inclusion is not native/device acceptance.

At 17:41 UTC, the **previous ff0 source's** full hosted-unit step had failed; the overall job was running UI work, with aggregate counts/causes not yet collected. Its seated result remains **13 pass / eight fail / zero skip**. [Previous-source run](https://github.com/mischa23v/blind/actions/runs/41096090593); it does not validate this combined checkpoint.

**Zero accepted workstreams; zero accepted whole journeys of 400; F01/Jev remains deferred.** Prior snapshot/history is unchanged. Only the continuation's publication label is superseded; record new terminal outcomes separately against their exact source.

---

# Current tracker pointer — 30 October 2026

Read [CURRENT_STATUS.md](CURRENT_STATUS.md) for the exact published commits, current Apple evidence and concise 16-workstream status. [TRACKER.json](TRACKER.json) separates source, testing and device/data gates and retains historical evidence. At 17:30 UTC: 13 partial-implementation workstreams, two evaluation/device stages, one user-deferred; **zero accepted complete and zero accepted whole journeys of 400**. These groups are not a completion percentage.

The remainder of this document and the original `SOURCE_PINS.json` / `CHECK_RESULT.json` are the dated 28 October audit. Its source inventory and owner snapshot are historical, not instructions to reimplement work completed since then. The unchanged historical checker is separate from the additive current-checkpoint validation.

---

# Historical reconciliation — 28 October 2026

This is a bounded evidence audit, **not new navigation execution, release approval or a replacement for TASKS.md**. `TRACKER.json` maps 16 workstreams and the existing 53 requirement families. Historical family descriptions are retained as historical dependencies, not asserted to supersede subsequent source fixes. Parent publication must verify its remote commit separately.

## What has actually been achieved

- **TESTED, assisted offline:** the archived stage67 result completed one table lap (20.393912 m); stage69 completed three continuous deterministic laps (61.791889 m, 15 goals, one actor). These are real saved simulation results, not merely planned paths. Their 35 cm arrival regions allow a final gap of 33.05 cm; mathematical closing chords were not walked. Both used a 45×30×160 cm zero-margin body, supplied localization, reference-labelled floor support and manually assisted source exclusions. Ground contacts were unmeasured. Three repeated laps are not three independent robustness trials.
- **TESTED, final matrix:** all 100 schedules accounted for; 94 completed movement episodes, comprising 90 arrivals, three support stops and one predicted-underbody rejection. Five interrupted unknowns and one CPU-limited partial remain. Fourteen of 20 directed pairs arrived under all five conditions. This is one room, not 20 rooms, and **not 90% iPhone accuracy**. The matrix itself did not measure table loops; historical assisted laps must not be erased by saying no loop ever completed.
- **TESTED components, not product journeys:** the integrated receipt summary has 372 deduplicated partial code sequences and zero complete user/model/device episodes. Its historical status mix includes failures. The 400-slot obligation file contains 40 authored navigation plumbing slots plus 360 unexecuted obligations. Neither the matrix nor these component sequences closes the 400-journey requirement.
- **CODE/native evidence exists, not physical acceptance:** memory, async map storage, connected journeys, observation history and contextual tools have later implementation checkpoints. Old 'staged/unwired' paragraphs and old unchecked boxes are not reliable current implementation inventories. The reviewed practice fix still needs the exact revised native run and physical accessibility checks; this audit does not claim their results.

## Immediate next build slice (latest user priority)

Finish a connected recorded-data build before asking for a live walking test. The current source has the parts but not the full handoff:

- `NavigationModel.swift` installs `IndoorNavigator.registeredJourneyInstallation` into `ConnectedJourneyRuntime` through its existing map-publication callback.
- Its `configureConnectedJourney` / `acceptConnectedJourneyCapture` seam explicitly has **no current camera/room-recognition caller**.
- `NativeLocalizationIssuer.offer` captures a candidate but withholds calibration. `prepareForBench` returns a pair and invalidates physical release; it does not install a live capture. No shipped independently validated measurement producer was established.
- `NativeMapping.swift` publishes `localGridSnapshot`, but source search found no consumer outside that owner. This is not already a room-route installation. `ObservedSceneRuntime` deliberately owns neither map registration nor output.

**Next implementable integration:** use one pinned recorded hierarchy (world/place → floor → room), actual registered-map installation, and the existing owner/planner in a replay-only harness. Feed explicitly supplied-pose/support bench evidence into a separate nonphysical sink, then exercise current hazard and code-guidance/output-retirement paths. Test doorway outbound/return, wrong room/floor/map revision, stale session, tracking loss, blocked path and cancellation. Real production classes should execute; no copied planner and no synthetic claim of camera localization. Verify the build includes all source files. Do not remove the app release gate or let an LLM supply physical directions. This connected replay can be completed **before** live sensor calibration/device trials; the device gate is not a reason to stop building it.

## Priority remaining checklist

| Order | Work | Current evidence / completion gate |
|---|---|---|
| 1 | Localization, orientation and deviation | Candidate contracts are not a calibrated live pose issuer. Test held-out matching RGB/depth/IMU, random starts, wrong rooms/floors, tracking loss/restart and measured error. |
| 2 | Progressive live obstacle/floor mapping | Feed chronological observations, never unseen future mesh. Test moved furniture, small toys, steps/drops/overhangs and sensor gaps; measure missing hazards and latency rather than only route area. |
| 3 | Closed-loop routing and return | Join real pose, current collision evidence, body/margin and app output. Complete doorway exit/return, deviation, blocked return and room/floor transitions without evaluator rescue. |
| Parallel | Independent rooms and error budget | Predeclare holdouts; quantify geometry, pose, body and reaction error. Reference geometry is evaluator-only. |
| Parallel | Native practice, accessibility, privacy | Current owners are addressing practice cancellation, accessibility and image retention. Native success is separate from physical VoiceOver/audio, lifecycle, storage and endurance. |
| After prerequisites | 400 full journeys | Each needs actual input, source/tool path, assertions, delivered outputs and outcome; blocked/not-run stays distinct. No helper-count substitution. |
| Before physical release | Reproducibility and adult/device review | Clean-copy data/toolchain provenance, measured hardware performance, supervised adult/O&M validation before any child progression. |

`TRACKER.json` records exact next tests, dependencies and current owner snapshot. Graph:

```
N02 localization -> N03 progressive sensing -> N04 closed-loop route/return
N01 offline baseline -> N05 holdout/error budget
A01 native/accessibility -> E02 complete voice/everyday tasks
N04 + E01 perception + E02 + E03 adapters -> J01 400 journeys
J01 + N05 -> J02 clean-copy release review
N04 + N05 + A01 + E01 + E02 -> D01 supervised physical acceptance
```

## Lower-priority independent work (do not displace connected navigation)

1. **Whole-journey definitions:** expand unexecuted obligations into precise reproducible cases, starting with shopping-list add/review/remove/restart, reading interrupted by a hazard, and historical-object correction. Use actual app/core paths and delivered-output callbacks. These can be authored now; genuine native/model/device execution remains pending. Preserve original failed receipts instead of overwriting them.
2. **Source/action adapter inventory:** verify implementation and missing tests for weather/daylight (SC03), recipes/timers (SC16), venue/menu/booking (SC28/29), external assistant/dictation/send (SC42/43), and online sources (SC44). Test offline/unavailable/authorization outcomes. Do not quietly turn a future network feature into a dependency of the free offline core.
3. **Shipped asset and licensing inventory:** exact model/detector/face/currency hashes, licenses, redistribution rights, sizes and offline availability. A source wrapper or synthetic recognizer input does not establish a real licensed working asset.

These are candidate next assignments, not authorization to launch paid services, new workflows, uploads or physical trials. Jev and similar visual-answer verification are **deferred by the user's latest decision**, not an active navigation blocker. Raw archive publication and newly proposed workflow activation have separate approval gates.

## Verification

Run `python research/tracker-reconciliation-20261028/check.py` from any directory. It validates pinned source bytes, actual archived lap result members, final matrix accounting, 400 obligation cardinality, 53 family mappings and the dependency DAG. It does not rerun physics, inspect all archived ticks, measure phone accuracy or claim tracker closure. `CHECK_RESULT.json` records this narrow check. `SOURCE_PINS.json` excludes actively edited root trackers so their continuing updates do not invalidate immutable evidence checks.
