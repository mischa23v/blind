# Blind reconstruction tracker

Prepared 2026-10-25 from owner-provided requirements, historical status reports and a read-only repository recovery assessment. This is a reconstruction plan, not a recovered implementation or a current test report. All implementation checkpoints below are OPEN. Document preparation does not establish any source edits, test executions, commits, or pushes.

## Evidence and status rules

- Baseline: `mischa23v/blind` at `4b00872f1bbc4ea92dca55f47f008f33460c4e71`, as inspected in the supplied recovery assessment. The current repository check also reported this SHA on primary branch `master`; record later commits separately.
- Source basis: owner-provided requirements and historical status reports, plus the pinned repository assessment. Private conversation exports are not included in the repository. An additional longer supplied history remains to be reconciled additively after this initial documentation checkpoint.
- **PRESERVED BASELINE** means the assessment identified code/assets in the pinned tree. It does not mean the code was rerun or validated on an iPhone.
- **REBUILD NEEDED** means a later implementation/fix is unavailable, or a concrete requirement still needs to be implemented or verified. Some promised features may never have been implemented. Re-inspect the baseline before replacing existing functionality.
- **NOT PREVIOUSLY IMPLEMENTED** is used for explicitly unfinished work or required outcomes never demonstrated in the supplied record, not an assertion that every underlying component is absent.
- **TEST EVIDENCE UNAVAILABLE** means historical status reports an execution/result, but its exact executable inputs, source revision and raw artifacts have not been recovered here. Historical reported passes are never current passes.
- Each ledger item has one primary category. A preserved component can have a separate rebuild item for missing integration and a separate unavailable-evidence item for its historical tests.
- Do not estimate a percentage lost from test counts. Missing from this snapshot does not establish permanent deletion. A later recovered source backup must be compared, never blindly overlaid. This initial ledger covers the first supplied record and assessment; reconciliation against the subsequently supplied longer history remains pending. It is not a final scope inventory.

## Non-negotiable architecture and product boundaries

1. Code owns physical state, localization, coordinate transforms, routes, collision clearance, reaching/movement cues, hazard priority and their speech. The LLM may interpret a request or conduct ordinary conversation; it cannot invent, paraphrase into, or authorize physical guidance. Fixed validated inputs must yield deterministic safety output across model choices.
2. Maintain world/outdoor → building/place → floor → room → object identity plus measured transforms, position, heading, evidence age, map revision and uncertainty. Room recognition alone is not a pose. GPS proximity, a face guess, a user room label or an old photograph is not proof of present location.
3. Preserve last verified history without giving stale history current guidance authority. Unknown geometry is not free space; an old route is not proof its next segment is safe.
4. Default-untrusted microphone transcripts, nearby speech, TV and announcements cannot change destinations, routes, tasks or safety state. Recognizing a family member is not command authority. Real speaker verification remains a separate unfinished capability, including intended-addressee and replay/noise tests.
5. Quiet/hold silences ordinary conversation, not ongoing navigation or valid urgent hazard warnings. Cancellation, task change and route replacement invalidate stale task directions without erasing independently valid obstacles.
6. No new screen, button, history UI or room-permission system. Debug logs are local, debug/developer retrievable, and never automatically uploaded. Existing configured no-go zones and hazards constrain navigation; do not turn ordinary room visits into approval flows.
7. Chest mounting is the design assumption. Account for phone height, tilt and offset, body dimensions and uncertainty. Camera orientation is not automatically walking direction.
8. Synthetic transitions, rotated floors and assigned imagery are explicitly synthetic. Measured datasets retain their real image/depth/pose relationships. Ground truth is held out of localization inputs.
9. Reconstruct in small testable checkpoints and publish verified checkpoints immediately through the authorized repository workflow. Do not wait for all 400 scenarios or a final package to save verified work remotely. An intermediate checkpoint is not a release or iPhone safety claim.

## A. Preserved baseline inventory

These are assessment findings, not newly verified implementation claims.

| ID | Category | Preserved area | Required handling |
| --- | --- | --- | --- |
| B01 | PRESERVED BASELINE | iOS application, conversation/task controls and local-memory foundations | Retain working foundations and inspect before replacing. |
| B02 | PRESERVED BASELINE | Familiar-person enrollment/recognition modules | Relationship recognition and everyday journeys still require integrated tests. |
| B03 | PRESERVED BASELINE | Currency, color, OCR and photo features | Feature presence is not proof every workflow works. |
| B04 | PRESERVED BASELINE | Existing code-based spatial/output guards and tests | Audit bypasses and false positives; do not remove existing guards. |
| B05 | PRESERVED BASELINE | `IndoorMap` route graph and per-floor `NavigationSurface` collision grid | Actual 2.5D geometry already exists. |
| B06 | PRESERVED BASELINE | `BodyEnvelope`, swept clearance, no-go zones and sensor hazards | Missing dynamic integration is not absence of all collision code. |
| B07 | PRESERVED BASELINE | RoomPlan/world-map provenance, room recovery, `SavedWorldFrame` and recovery gates | Preserve verified evidence provenance. |
| B08 | PRESERVED BASELINE | `IndoorNavigator` and `ReturnTrail` | Baseline floor changes are manual and return is one uninterrupted AR session. |
| B09 | PRESERVED BASELINE | Native RTAB-Map adapter accepts AR frames and saves a private database | Localization/occupancy integration must be re-established separately. |
| B10 | PRESERVED BASELINE | Listening/mute controls, output interruption and private-headphone removal handling | These do not establish speaker verification. |
| B11 | PRESERVED BASELINE | `CompanionMemoryRetrieval`, observed history and original user reports | Regression fixes are separate work. |
| B12 | PRESERVED BASELINE | Photo/reading tools and actual `CompanionClock` capability | Do not rebuild these capabilities as though absent. |
| B13 | PRESERVED BASELINE | Narration history, Soundscape research, test suites, requirements, research, prior handoffs and acceptance documents | Narration history is not the promised full debug log. |

## B. Reconstruction and regression ledger

All R items are **REBUILD NEEDED**. A previous claim of a repair does not close the row. Each row requires current code inspection, an executable reproducer/acceptance test and evidence tied to the rebuilt commit.

### Guardrails, authority and conversation continuity

| ID | Category | Concrete feature or failure | Required acceptance |
| --- | --- | --- | --- |
| R01 | REBUILD NEEDED | Code-only physical guidance across every speech/output/tool path; no LLM-generated or paraphrased navigation, reaching, measurements or collision facts | Attempt malicious/confident model outputs and compare identical sensor inputs across models; unsupported guidance must never be emitted. |
| R02 | REBUILD NEEDED | Default-untrusted speech command barrier, including cancellation before authority checks | Public chatter, overlapping speech, TV, family/children saying “come here,” “stop,” or a new destination cannot redirect or cancel. Verified identity and addressing intent are separate. |
| R03 | REBUILD NEEDED | Quiet/hold, ordinary chat and interruptions preserve navigation, task progress and hazards | English/Arabic chat, family/waiter/airport/police interactions and silent mode do not discard task or suppress urgent hazards. |
| R04 | REBUILD NEEDED | Request intent and destination authority | Asking about a place must not start navigation or silently choose a destination. Destination changes must not leave an old route active. |
| R05 | REBUILD NEEDED | Preview is strictly read-only | Preview cannot replace active destination or return point, mutate task/route state, or produce actionable invented directional audio. |
| R06 | REBUILD NEEDED | Task completion scoped to the actual task | “I'm at the table” and “I did it” cannot finish a different broader task. Repeating a request cannot reset progress. |
| R07 | REBUILD NEEDED | Initial connected conversation failures | Reproduce harmless-joke/backpack-acknowledgment blocks, empty goal/progress after updates, retrieval omitting stored backpack and absent model route-request connection. |
| R08 | REBUILD NEEDED | Task resume/cancel and truthful cancellation response | Resume after interruptions; cancellation stops the intended task, reports correctly, retains valid hazard warnings and blocks stale navigation cues. |

### Connected spatial core, evidence and mapping

| ID | Category | Concrete feature or failure | Required acceptance |
| --- | --- | --- | --- |
| R09 | REBUILD NEEDED | Persistent world/building/floor/room/object hierarchy and verified coordinate-frame links | Forward/inverse/composed position and heading transforms, map ownership and transition invariants. No silent resets or unexplained frame jumps. |
| R10 | REBUILD NEEDED | Continuous spatial state, active map selection and outdoor travel mode | Load/extend saved partial maps; walking/car/outdoor/building transitions preserve journey and destination. Home room is a configured reference, never a cold-start assumption. |
| R11 | REBUILD NEEDED | Building/floor/doorway/elevator transitions in both directions | Verify floor evidence and connection transforms; unresolved transitions stay unresolved. User floor answers are reports, not automatic pose proof. |
| R12 | REBUILD NEEDED | Multi-clue relocalization with explicit uncertainty and competing candidates | Approximate location shortlists buildings; sensor/depth/motion and saved views resolve room and pose separately. Similar walls/floors, mirrors, adjacent buildings, changed furniture and viewpoints stay ambiguous when needed. |
| R13 | REBUILD NEEDED | Confidence calibration and independent evidence accounting | Repeated views of the same clue cannot inflate confidence; contradictions lower confidence. Require separation from competing matches and independently validated pose. |
| R14 | REBUILD NEEDED | Cold start/battery-dead restart in another room; tracking loss and recovery | Preserve last verified history, withhold unsupported movement, calmly request a room label only when useful, gather new observations and re-align before resuming. |
| R15 | REBUILD NEEDED | Place/object/time/map-revision binding and old-map/stale-evidence rejection | Wrong house, floor, fridge, scene or old timestamp cannot support current claims/clearance. Reject delayed location/evidence from superseded map/session while preserving provenance. |
| R16 | REBUILD NEEDED | Automatic observation storage, room-candidate records and useful saved viewpoints | Store measured view pose, source, timestamps and map identity; update naturally in permitted areas without new UI. Repeated observations and partial coverage remain explicit. |
| R17 | REBUILD NEEDED | RTAB-Map localization corrections and occupancy data connected to spatial state | Consume actual native outputs with provenance; distinguish observed/unknown/occupied. Occupancy absence cannot become clearance. |
| R18 | REBUILD NEEDED | Empty-map incremental mapping and map extension without future-data leakage | Reveal only ordered observations; compare separately withheld ground truth for pose, geometry, explored area, graph links and return. |
| R19 | REBUILD NEEDED | Camera/map restart continuity and persistent route history | Restart must not cancel a valid return or reset the world into an assumed room; revalidate current localization before guidance. |
| R20 | REBUILD NEEDED | Safe map deletion and replacement | Deleted map images/references cannot reappear. Deleting the active map withdraws authority. Replacing a building removes obsolete floor guidance while retaining historical records. |
| R21 | REBUILD NEEDED | Atomic map/obstacle transactions, including rejected update and database-write failure | A rejected update must preserve previous valid obstacle state; crash/killed writer must recover atomically. Test replay and actual app APIs independently. |
| R22 | REBUILD NEEDED | Nonblocking durable map writes/imports and delayed update history | Slow saves/imports cannot block hazard handling or lose queued camera/map history. Validate large maps without an unverified performance claim. |
| R23 | REBUILD NEEDED | Malformed-map validation and conflicting/stale geometry handling | Reject corrupt/invalid transforms, geometry and map records without removing a prior valid map. |
| R24 | REBUILD NEEDED | No-go zones without a new room-permission system | Exclude routes and warn on approach to configured zones; do not block ordinary home rooms by default or conflate recording and navigation restrictions. |

### Collision, route continuity and return

| ID | Category | Concrete feature or failure | Required acceptance |
| --- | --- | --- | --- |
| R25 | REBUILD NEEDED | Static map collision and dynamic/live obstacle integration | Test known walls, moving people, changed doors/objects, outdated geometry and reliable localization. Stored geometry never overrides contradictory live evidence. |
| R26 | REBUILD NEEDED | Swept full-body clearance, conservative size and route refresh | Test shoulders, head, arms, backpack, corners, narrow gaps, doors, tables/chair legs and above-chest obstacles. New body dimensions must invalidate/recompute old routes. |
| R27 | REBUILD NEEDED | Chest-holder calibration and degraded sensors | Account for sensor-to-body offset, height, tilt, shifted/covered phone, travel direction and position error. Late/uncertain data increases margins or blocks unsupported motion. |
| R28 | REBUILD NEEDED | Hazard freshness, speech scheduling and independent lifetime | Eliminate stale/repeated warnings without erasing still-valid hazards on task changes/cancellation; moving-map updates must not starve guidance. |
| R29 | REBUILD NEEDED | Continuous cross-map outbound and return journeys | Complete home → outdoor → other building/floors/rooms → saved start, not just three transitions. Preserve destination, provenance and actual queued/completed narration callbacks. |
| R30 | REBUILD NEEDED | Fresh obstacle-aware return from unfamiliar/partial places | Retain entrance used, visited route and chosen meeting point; block newly obstructed sections and reject similar corridors/wrong floors. No promise that a remembered route is still clear. |
| R31 | REBUILD NEEDED | Conversational “take me back” connection | English/Arabic clarification of starting point, interruption handling, broader-task retention and code-owned return completion with real narration callbacks. |
| R32 | REBUILD NEEDED | Useful Soundscape-inspired audio, landmarks, approach monitoring and headset controls | Integrate only useful compatible behaviors; route preview is read-only, directional cues require measured direction, headphone removal preserves privacy, MIT notices accompany reused code. |

### Memory, references, clock and privacy

| ID | Category | Concrete feature or failure | Required acceptance |
| --- | --- | --- | --- |
| R33 | REBUILD NEEDED | Fresh item observations versus historical/user-reported memory | Changed fridge contents and moved belongings update state; one missed frame cannot prove absence. Explain “last seen”/reported sources without claiming present visibility. |
| R34 | REBUILD NEEDED | Retrieval of latest exact user report and safe pronoun resolution | “I left it on the desk” must not revert to shelf or attach to wrong item when cup/keys switch; saved-item answers cannot be blocked or omitted. |
| R35 | REBUILD NEEDED | Correction chronology and restart timestamps | Older correction cannot veto a newer valid report; replayed old dialogue cannot gain a fresh timestamp after restart. |
| R36 | REBUILD NEEDED | Limited-context/new-session memory and task provenance | Cold start with saved memory, the original backpack journey, hazard-deferred answers and repeated requests preserve state without false current claims. |
| R37 | REBUILD NEEDED | Supported recurring-item/low-quantity assistance | “Running low” requires quantity evidence or explicit user report, not habit. Shopping-list suggestion is not an authorized shopping-cart transaction. |
| R38 | REBUILD NEEDED | Photo/source intent routing | A fridge-photo question must not become movement; bind answers to the actual selected photo and stale/current source distinction. |
| R39 | REBUILD NEEDED | Actual OCR and exact-model reference/manual execution | Read the intended image/document text, not only a heading; preserve exact model, qualifiers, citations/source trace and unreadable/conflicting cases. No unsupported labels/numbers. |
| R40 | REBUILD NEEDED | Complete long-reference delivery | Preserve oversized manual answers in intact ordered parts, including all qualifiers; care-label reading must run through the real tool flow. |
| R41 | REBUILD NEEDED | Code-owned time and freshness | Query actual `CompanionClock`, preserve ongoing task and expire stale time answers; model must not fabricate time or retain a once-current response as current. |
| R42 | REBUILD NEEDED | Local debug session log, no UI and no automatic upload | Capture actual utterances/model responses, calls/results, sensor/map evidence references, timing, blocked/changed output and narration. Developer/Xcode retrieval only; review data handling/retention without adding a user-facing control. |
| R43 | REBUILD NEEDED | Harmless language false positives without weakening physical safeguards | Reproduce joke/backpack acknowledgments, rainbow “wavelengths bend,” basic arithmetic and quoted-story explanations. Test exact outputs, not only classifier labels. |
| R44 | REBUILD NEEDED | Actual queued/completed narration and repeat controls | Stale speech, repeated answers and repeat-control bugs require output-event assertions; synthetic final text alone cannot prove correct audible delivery. |

### Everyday workflow coverage and deliverables

| ID | Category | Concrete feature or failure | Required acceptance |
| --- | --- | --- | --- |
| R45 | REBUILD NEEDED | Familiar people and separation recovery | Enroll/recognize mother, father, sister, brother; handle uncertainty and outdated location. Preserve route/meeting information and guardian-contact capability without treating a face or family voice as movement authority. Contact flow must be explicit, not autonomous wandering. |
| R46 | REBUILD NEEDED | Child color, item and school tasks | Choose crayon/toy by color; identify own bag/belongings at school/home; find a braille book from conversational goal; read worksheet/table/classroom-board text relevant to the task. |
| R47 | REBUILD NEEDED | Adult currency and supermarket tasks | Saudi-note identification, requested product on a shelf, image/location comprehension and unknown-shop/restaurant entrance return. Use measured sequences for spatial outcomes. |
| R48 | REBUILD NEEDED | Airport and restaurant sign journeys | Read boarding-pass seat/gate and compare current signs; handle changed gate/unreadable/conflicting text. Recognize correct restaurant exterior/sign, not a similar storefront. Task-relevant speech takes priority after hazards. |
| R49 | REBUILD NEEDED | Real paired datasets and randomized starts | Acquire/access-check complete indoor/furnished geometry, RGB/depth/pose and multi-place data; randomize starts/headings without giving the answer to localization. Label fake outdoor placement/rotated second floors synthetic. |
| R50 | REBUILD NEEDED | Complete model-driven limited-context conversation/replay harness | Use actual memory/map/routing/collision/tools and output records; include interruptions, corrections, restart and all failed steps. Trusted-input replay is not live-mic validation. |
| R51 | REBUILD NEEDED | Reproducible clean-copy package and all source-contract checks | Fix outdated runner definitions and harness/source-contract mismatches; include real-image fixtures and original failed runs. Run from clean checkout with pinned inputs, not hidden workspace state. |
| R52 | REBUILD NEEDED | Claude/independent review handoff | Architecture, changed files, exact dataset provenance/license/checksums, commands, outputs, failed cases, native blockers and precise Mac/iPhone next checks. Preserve disagreements and limits. |
| R53 | REBUILD NEEDED | Durable progress and immediate verified remote checkpoints | Track each open item and exact commit/test evidence; verify remote contains pushed commit before claiming saved. Do not defer all publishing to final 400-scenario completion. |

## Supplemental technical contracts from later historical detail

These are prior recorded design/fix requirements supplied during reconstruction, not proof of current source or newly executed tests. Verify them against the additional source history and implementation before marking complete.

- **R15/R28: independent perception authority.** Separate a perception-revision UUID from task/route `stateRevision`. Cancel, quiet and a new goal must not expire still-fresh hazard evidence. Map, session, geometry and acquisition changes rotate the perception token. Withdraw queued/started route cues by their exact cue IDs while preserving the independent hazard channel.
- **R41: clock contract.** Time queries are read-only and do not cancel the goal. Preserve the original monotonic five-second freshness cap and wall-clock/time-zone consistency checks; do not silently renew old answers.
- **R39/R40: reference delivery contract.** Preserve full source blocks and qualifiers in chunks of no more than 35 words. Retain the original 60-second deadline; interruptions cannot resume or renew expired/withdrawn reference delivery.
- **R42: debug retention/privacy contract.** DEBUG-only, opt-in launch configuration; no UI or upload. Cap each session at 8 MiB and retained data at 32 MiB, fail-stop at limits with no silent eviction. Privacy clear purges stored debug data and disables recording. The initial recorder foundation must not be called complete until these behaviors and evidence references are tested.
- **N03/T13: catalog coverage detail.** Historical final counts remain 1,629 Core and 500 repository only. Supplemental history reports 15 catalog IDs partially bound, 385 with no binding, and 397 without complete new whole-episode bindings. No arithmetic on these counts establishes 400 passes, or any current rebuilt result.

## C. Explicitly unfinished work: not recovered accomplishments

| ID | Category | Open outcome | Evidence / boundary |
| --- | --- | --- | --- |
| N01 | NOT PREVIOUSLY IMPLEMENTED | Trusted hands-free speaker identity and intended-addressee verification | Explicitly unfinished in historical status. Discussion of Apple/Siri capability is not an implemented public API. Default-untrusted barrier remains mandatory. |
| N02 | NOT PREVIOUSLY IMPLEMENTED | Long-sequence experimental mapper meeting accuracy/robustness thresholds | Historical status reports about 1.12 m 95th-percentile error over 34 m and failure; the later status still says failed. No final passing long-run evidence. |
| N03 | NOT PREVIOUSLY IMPLEMENTED | Complete 400 distinct integrated scenarios | Repeatedly incomplete in historical status. A catalog is not 400 maps, executions, passes or disappeared completed work. Every future scenario stays incomplete until its own actual-stack evidence is recorded. |
| N04 | NOT PREVIOUSLY IMPLEMENTED | All native integrations | Historical status explicitly says some are missing, not merely awaiting phone tests. Exact missing adapters must be inventoried before planning device validation. |
| N05 | NOT PREVIOUSLY IMPLEMENTED | End-to-end live iPhone safety validation and real microphone authorization validation | Historical reports distinguish cloud/trusted replay from device validation. No safe-navigation/readiness claim is established. |
| N06 | NOT PREVIOUSLY IMPLEMENTED | Validated superiority to VoiceVista/Seeing AI or other navigation apps | Historical discussion covers goals and ideas, not comparative user outcomes. Public VoiceVista/Seeing AI implementation availability is not proof of reusable private source. |
| N07 | NOT PREVIOUSLY IMPLEMENTED | Optional real-person scan calibrated collision envelope | Requirements propose later optional scanning; conservative adjustable dimensions are the rebuild baseline. Do not claim an accurate scan-derived body profile exists. |
| N08 | NOT PREVIOUSLY IMPLEMENTED | Final verified combined package/review and post-baseline push described in the transcript | Historical status says reruns/package review unfinished and latest source unavailable. Rebuild checkpoints replace waiting for this missing package. |

## D. Historical results: evidence unavailable, not rerun

| ID | Category | Historical reported result | Required treatment |
| --- | --- | --- | --- |
| T01 | TEST EVIDENCE UNAVAILABLE | Initial six-turn connected developmental failure and claimed verbatim trace  | Recreate exact available wording and preserve failure; do not invent missing turns or trace. |
| T02 | TEST EVIDENCE UNAVAILABLE | 1,086 Core / 16 Memory / 334 Node / 360 Python; 77 turns prepared; recorded-image check | Historical report only; prepared is not executed. |
| T03 | TEST EVIDENCE UNAVAILABLE | Real 100-frame/9.9-second RGB-depth blank-map replay, median ~6 cm / worst ~8 cm, five black frames  | Locate original data/ground truth or recreate with new labeled evidence; short pass never supersedes long failure. |
| T04 | TEST EVIDENCE UNAVAILABLE | 9 combined multistage tests and long 34 m mapper failure (~1.12 m p95), then 11 integrated checks  | Raw artifacts missing. Preserve synthetic vs measured distinctions and failure. |
| T05 | TEST EVIDENCE UNAVAILABLE | First two scripted conversation sequences: 24 checks  | Not fresh model-driven conversations. |
| T06 | TEST EVIDENCE UNAVAILABLE | Blocked-save hazard, killed-writer atomic recovery, 2.5 s → 43–45 ms cloud benchmark | Do not quote as current performance; rerun on specified hardware/data. |
| T07 | TEST EVIDENCE UNAVAILABLE | 1,467 Core including 11 integrated checks; clean-copy runner failures | Historical checkpoint plus real reproducibility defect. |
| T08 | TEST EVIDENCE UNAVAILABLE | 1,502 Core / 471 repo; backpack, restart, active-map deletion, malformed map; transactional map/floor repairs | Reports at different revisions; do not conflate unchanged Core and later repository reruns. |
| T09 | TEST EVIDENCE UNAVAILABLE | Three simulated transitions, 473 repository checks and completed synthetic outbound/return | Transitions alone were not a journey; later completion remains synthetic. |
| T10 | TEST EVIDENCE UNAVAILABLE | 1,538 Core; conversation 519/521 with rainbow failures; 476 repository | Preserve both failures and reported later focused fix. |
| T11 | TEST EVIDENCE UNAVAILABLE | 1,578 Core; 237 real-reference checks and six-part washer answer; five remaining harness/source-contract failures | A reference pass did not close combined-package failures. |
| T12 | TEST EVIDENCE UNAVAILABLE | 1,596 Core; ten everyday workflows exposed arithmetic/story/clock/cancellation problems | Preserve original failing cases, not easier replacements. |
| T13 | TEST EVIDENCE UNAVAILABLE | 1,629 Core / 500 repository; reviewed outputs, clock/cancellation/everyday passes; seven outdated cross-map expectations | Latest reported count, not source recovered, tests rerun or final review complete. Do not suppress valid hazards to match stale expectations. |
| T14 | TEST EVIDENCE UNAVAILABLE | Preserved documents mention 770 Core / 16 Memory / 306 Node and a later 865 Core / 308 Node | Distinct historical document checkpoints, not a loss percentage or a current baseline run. |
| T15 | TEST EVIDENCE UNAVAILABLE | Historical source/test backups and later access blocker  | Source bytes and backup accessibility remain unverified. Keep recovery and reconstruction separate. |

## E. Small reconstruction checkpoints

Implementation should use the smallest coherent diff. Every checkpoint gets a focused test before moving on, a relevant regression rerun against the final diff, an honest scope/limitations note and a verified push through the authorized workflow. The list is order of implementation, not permission to call unrun tests passed. Full-suite work is cumulative; targeted safety tests begin at checkpoint 1.

| Checkpoint | Scope | Minimum evidence to close | State |
| --- | --- | --- | --- |
| 0. Freeze recovery facts | Preserve source transcript/assessment hashes, repository identity and open ledger; inspect latest remote without overwriting it | Input checksums, baseline/current-head distinction and recoverable clean checkout. Publish documentation separately if appropriate; do not claim recovered code | OPEN; initial plan files prepared |
| 1. Seal speech authority | R02, R04, relevant R01; reject untrusted microphone task/route/cancel actions before mutation | Tests show all mutating paths reject untrusted source while explicitly trusted user input still reaches existing controls; no new speaker-verification claim | OPEN |
| 2. Preserve safety state | R01, R03, R06–R08, R28 | Deterministic code-only physical cues; quiet/cancel/task-switch keep valid hazards; no stale route cue; harmless conversation does not cancel navigation | OPEN |
| 3. Add frame identities | R09–R11, R15 | Round-trip/composed transforms, map/floor ownership, heading consistency, invalid/stale frame rejection and unresolved-transition behavior | OPEN |
| 4. Add uncertain recovery | R12–R14, R19 | Competing rooms/floors, independent-evidence confidence, restart elsewhere, tracking loss; room label/proximity cannot assert a pose | OPEN |
| 5. Join mapping safely | R16–R18, R20–R24 | Actual native-adapter contract or explicit missing-native blocker; incremental evidence, old-floor withdrawal, deletion, failed-update/failed-write atomicity, responsive hazards | OPEN |
| 6. Integrate swept collision | R25–R28 | Static/live/unknown separation, child/adult body profiles, head/shoulder/backpack collisions, sensor delay, changed dimensions and route refresh | OPEN |
| 7. Complete return flow | R05, R29–R32 | Actual-stack outbound/return, blocked return, camera restart, read-only preview, “take me back” English/Arabic and narration completion | OPEN |
| 8. Repair memory and ordinary tasks | R07–R08, R33–R37, R41, R43–R44 | Original backpack/cup/keys/correction/restart timestamp, repeated task, clock and exact harmless-answer failures reproduced and fixed | OPEN |
| 9. Restore reference/debug integration | R38–R42, R49–R51 | Real photo/label/exact-model PDF sequences, long answer delivery, source references, local debug log with no UI/upload, clean-copy portability | OPEN |
| 10. Expand integrated journeys | R45–R50, N02–N05 | Ordered map+pose+route+collision+output evidence for each scenario; real/synthetic separation; long mapper and native/device gaps remain failures/not run until proven | OPEN |
| 11. Publish handoff and remaining scope | R52–R53 | Exact changed commit, verified remote hash, commands/logs/fixture checksums, independent review, device/native checklist and explicit incomplete coverage | OPEN |

### Per-checkpoint recording template

- Checkpoint / ledger IDs:
- Base commit and final tested commit:
- Changed files and why:
- Reproducer before fix (command, exit status, log path, failure):
- Focused verification after fix (command, exit status, log path):
- Affected/full regression checks (passed / failed / not run, exact evidence):
- Test provenance: real measured / synthetic / trusted replay / live device:
- Known blockers and residual risk:
- Review evidence and any later edits requiring a rerun:
- Commit SHA; remote/branch; remote SHA readback; CI state for this exact SHA:
- Artifact checksums and reproducible instructions:

A local commit is not a push. A reported successful push is not verified remote existence until readback. A remote checkpoint is not overall completion. If publication is blocked, save the diff and logs, state the exact blocker and continue independent authorized work rather than claiming it is saved remotely.

## F. Mandatory integrated test acceptance checklist

All boxes below are open. Do not close them by copying a historical count.

- [ ] Original failing conversation steps and exact available wording are retained; missing original data is identified rather than invented.
- [ ] Real app/core map loading, position/heading, route selection, collision and output gates run together. A language-only plausible reply does not count.
- [ ] Dataset/image/depth/map/license/checksum provenance and synthetic links are explicit; held-out ground truth does not enter localization.
- [ ] Random starts/headings, wrong building/floor/room/fridge, mirrors/repeated walls and contradictory evidence are exercised.
- [ ] Empty-map incremental observation, partial map reuse, revisits and changing furniture/objects are tested without unseen future data.
- [ ] Cold start elsewhere, AR/camera restart, tracking loss/relocalization, delayed/out-of-order sensors and stale map/session evidence are tested.
- [ ] Rejected update, malformed map, active-map deletion, removed floor, database failure and killed writer preserve correct history and authority.
- [ ] No-go zones, unknown areas, dynamic obstacles, blocked return, static walls, table/door/head/shoulder/backpack swept collisions and body changes are tested.
- [ ] Untrusted nearby/recorded/overlapping speech cannot mutate a physical task; real verified hands-free input remains marked unavailable until validated.
- [ ] Quiet, harmless chat, cancellation, task switches and preview retain correct route/hazard state with no invented direction.
- [ ] Cross-world outbound and return complete with actual narration callbacks, not merely transition assertions.
- [ ] Saved item provenance, corrections, cup/keys pronouns, repeated requests, old timestamps and hazard-deferred backpack answers are tested.
- [ ] Clock is code-owned and fresh; arithmetic/story/rainbow/joke answers do not weaken movement safeguards.
- [ ] Real photographs, color/currency/OCR, labels and exact-model manuals execute actual tools, preserve qualifiers and handle unreadable/conflicting evidence.
- [ ] Debug logs remain local and developer-only, with no new UI or automatic upload; evidence references remain usable for small-model diagnosis.
- [ ] Clean-copy package includes needed fixtures and all test definitions; exact commit is reproduced on the target platform.
- [ ] Each of the future 400 scenario entries has its own input, code path, assertions, outputs and disposition. Current verified reconstruction evidence is **0/400 recorded here**; this is not a claim that historical work never ran. Supplemental historical detail reports 15 catalog IDs partially bound, 385 with no binding and 397 without complete new whole-episode bindings. These are coverage gaps, not passing executions.
- [ ] Missing native integrations are implemented and tested before being relabeled “only needs iPhone testing.”
- [ ] Live iPhone validation is separate from cloud replay and has an explicit safety-oriented review plan. No cloud count establishes safe independent use.

## Current completion statement

The initial durable reconstruction plan is written. Source implementation, test reruns, source recovery, commits and pushes require separate recorded evidence. The rebuild remains open. Current work areas are the command-authority boundary, spatial-registry foundation and DEBUG recorder foundation; none establishes full native integration. Publish this documentation checkpoint first, then small code-owned speech/physical-output guardrail checkpoints and connected spatial-state reconstruction. Reconcile the additional longer history in an additive documentation checkpoint rather than delaying initial preservation.
