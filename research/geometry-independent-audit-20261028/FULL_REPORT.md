# Geometry and navigation failure audit

**Updated 2026-10-28 17:09 UTC. The independent same-file OpenUSD comparison is complete.** This report preserves 19 supported defects and gaps and incorporates the actual comparison. It does not claim every bug is known or that navigation is ready. Fresh Open3D and RTAB-Map raw-input reconstruction comparisons have not run.

**Evidence checkpoint:** exact native source `c4ffa28c07d0a17b513d123de3bec2fd8be93eec`, tree `cd2fca12679193c11cf663a21a6aeded9d6879c7`, run `40726507227`. The final hosted case receipt records 236 cases: 223 passed, 7 failed and 6 skipped. All nine new classification ingress cases and the same-export capture case passed. The current terminal job receipt confirms native failure, with UI audit and callback evidence steps failed. The older run receipt embeds a stale in-progress job snapshot; the later job receipt supersedes that nested snapshot. The bounded terminal log independently reports 18 UI cases: 14 passed, one failed and three skipped. `testAccessibilityAuditOfCameraAndAsk` fails at line 373 for contrast. [Terminal test log](../native-path-recovery-20261028/run40726507227/terminal-failure-extract.txt). The captured issue metadata reports “Contrast failed” for a SwiftUI accessibility node, with no target element snapshot, so it does not establish the same exact target as the earlier run. [Current UI issue metadata](../native-path-recovery-20261028/run40726507227/ui-audit/full-audit-ask-issue-1-metadata.json). [Final hosted evidence](../native-path-recovery-20261028/run40726507227/final-unit-case-statuses-original.json), [terminal job receipt](../native-path-recovery-20261028/run40726507227/terminal-jobs-170921Z.json).

## Main conclusion

**Geometry must be established before path results can be trusted.** The current saved-room result cannot admit either original Apple room fixture: every one of the 18 requested route cases and 16 supplied-pose journey stages stops at `sourceGeometryMismatch`, before a usable candidate route exists. We have fixed a proven metadata decoder defect and a narrowly demonstrated synthetic collision-query defect, but neither establishes correct full-scene geometry, useful live navigation, or physical safety.

The user's observations of paths apparently crossing walls and a small displayed actor unable to pass large-looking gaps are important contradictions, not something to dismiss as conservatism. We have not yet tied those exact views to registered geometry, the effective collision envelope and the actual path samples. They remain **unverified visual findings requiring a numerical registration and swept-body audit**. We must not call them measured collisions or proven free gaps; equally, we must not claim they are harmless rendering artifacts.

This report covers the defects, integration gaps and evidence failures supported by the inspected source and retained receipts. It is **not a claim that every possible bug has been found**. The independent OpenUSD reader has now read the exact retained diagnostic files. It confirms a source-plane-versus-exported-solid/outline mismatch in our validation, rather than a demonstrated units or source-transform error in these two fixtures. The next task is a correct semantic conversion and regression test, not merely a more permissive planner.

## Evidence terms used here

- **Confirmed defect:** reproduced in retained native output or established by exact-source inspection within the stated scope.
- **Confirmed blocker with unresolved cause:** a failure is established, but its geometric explanation is not.
- **Missing integration:** a required producer, consumer or validity condition is absent from the inspected runtime path.
- **Limited evidence:** a result applies to supplied data, synthetic controls, one simulator run or source checks, not the physical system.
- **Hypothesis:** a possible explanation that has not been demonstrated.
- **False clear versus false block:** missing a real modeled obstacle is a false-clear risk; refusing unsupported input is a block, not proof the real route is impossible. The current source-bound refusal rejects valid exporter-provided solids against original planar bounds. It is an adapter-contract failure, not proof of physical blockage. Whole-room physical clearance remains unmeasured.

## Earlier complete case-level evidence and current update

| Evidence at source 9284719 | Result | What it establishes |
| --- | ---: | --- |
| BlindCore | 1,434 executed, 1 skipped, zero failures | Portable component checks, not physical accuracy |
| BlindMemory | 58 passed | Tested memory behavior |
| Default and diagnostic iOS Simulator builds | Both passed | These configurations compile |
| Hosted units | 211 passed, 7 failed, 6 skipped of 224 | Still a failing native suite |
| Collision oracle tests | 8 passed | Narrow synthetic oracle coverage |
| Classified mesh tests | 5 passed | One run met existing checks; latency remains near the deadline |
| UI | 14 passed, 1 failed, 3 skipped of 18 | Accessibility still fails |
| Original saved-room routes | 18 unsupported geometry, zero completed candidates | No successful route comparison yet |
| Supplied-pose journey stages | 16 unsupported geometry | No completed end-to-end journey or guidance replay |

The early and final native case extracts agree and are exact-source verified. Named JSON report files are semantic reserializations: hashes in their native manifests refer to original attachment bytes, not necessarily to those local reserialized bytes. This audit's own source-file hashes are in [EVIDENCE_SUMMARY.json](EVIDENCE_SUMMARY.json). [Latest native result and provenance](../native-path-recovery-20261028/run40710093281/README.md), [exact terminal status](../native-path-recovery-20261028/run40710093281/terminal-run.json).

## Follow-on publication, failed capture and verified recovery

At source `4eb0d10`, the repaired stage 75 package proof (`40721821544`) and stage 83 ingress proof (`40721821664`) complete successfully. The package receipt establishes its macOS package/public-client checks and simulator linkage; it explicitly does not establish simulator execution, app build, ARKit execution or physical authority. The ingress receipt establishes 83 real-runtime synthetic checks plus compilation of the ARKit boundary, not app activation, live buffer copying, simulator/device execution or measured latency. This closes the prior stale-pin block within those proof scopes, not navigation acceptance. [Package proof](../native-path-recovery-20261028/run40721821544/terminal-run.json), [bounded package scope](../native-path-recovery-20261028/run40721821544/bounded-proof-summary.txt), [ingress proof](../native-path-recovery-20261028/run40721821664/terminal-run.json), [bounded ingress scope](../native-path-recovery-20261028/run40721821664/bounded-proof-summary.txt).

The separate app run `40721822359` is a **terminal failure**, completed at 16:12:29 UTC. Default and diagnostic app builds pass, but the hosted test bundle fails to link because `ClassificationIngressTests.o` references unresolved `MeshBufferDecoder81` symbols. Hosted and UI testing are cancelled before execution; both summaries contain zero cases. The same-export artifact contains only `status=unverified_case_evidence`, `sourceVerified=false` and `files=[]`. Upload-step success does not mean USDZ recovery succeeded. No OpenUSD room read was attempted from that failed run. This was a native test-target integration failure, not a failed geometry comparison or a set of failing route behaviors. See P07 for the source-graph defect and recovery. [Terminal result](../native-path-recovery-20261028/run40721822359/README.md), [exact linker and zero-case evidence](../native-path-recovery-20261028/run40721822359/bounded-link-failure-lines.txt), [incomplete case evidence](../native-path-recovery-20261028/run40721822359/early-unit-case-statuses-original.json), [receipt without assets](../native-path-recovery-20261028/run40721822359/same-export-failed-receipt.json).

## Geometry and data handling findings

### G01 We selected the metadata parser from an assumed format

**Confirmed defect, repaired and natively verified.** At `6fe9d52`, the app attempted `JSONDecoder` on binary property-list bytes. The `.json` filename concealed the actual export format. Hallway2's sidecar was 707 bytes and Bedroom3's 608 bytes; both failed `metadataDecodeFailed`. This blocked all downstream geometry and route evaluation.

The repair uses the observed `bplist00` signature to select Apple's `PropertyListDecoder`, retains explicit flat JSON-object support, and rejects unsupported shapes/formats. It does not guess identities or silently rewrite names. At `43e33d4` and again `9284719`, Hallway2 maps 13 entries to 13 meshes and Bedroom3 maps 11 to 11, with zero unmatched or unknown-feature meshes.

**Code and evidence:** `SavedRoomRouteMeshAdapter.decodeMetadata(data:)`; [decoder repair](../SAVED_ROOM_ROUTE_BINARY_PLIST_FIX_2026_10_28.md); [pre-fix run](../native-path-recovery-20261028/run40698547633/README.md); [verified repaired run](../native-path-recovery-20261028/run40706611490/README.md). **Regression required:** retain real-export decoding plus malformed, oversized, wrong-root, unknown-UUID and supported-format checks. This is a serialization fix, not a geometry pass.

### G02 Our original feature-bound contract rejects exporter-provided solids

**Confirmed validation defect, not yet corrected.** `verifySourceBounds` maps imported world vertices through the source rigid inverse and checks source polygon bounds or half-dimensions with a Float32 roundoff allowance. Original RoomPlan architectural features have zero depth; Apple's exported geometry does not. Both native first-failure witnesses lie approximately 0.16 m off their source wall plane, against numeric tolerances approximately 0.0000923 m and 0.0001286 m. Official OpenUSD reads the same solids from the exact retained files.

Walls and doors have approximately 16 cm depth; the window and floors approximately 8 cm. Some wall endpoints also extend approximately 16 cm. **Both floors extend approximately 16 cm beyond the original polygon min/max on all four planar sides.** Bedroom furniture retains the original local half-dimensions. This establishes an incorrect planar-source versus export-solid/outline containment contract, not an unexplained global scale error. The mechanism generating lateral extensions is not inferred beyond their observed presence.

**A thickness-only patch or wider epsilon is insufficient:** it would also admit exporter-generated floor area as if it were measured support. The correction must distinguish original planar support/semantic regions from visual solids and preserve openings, identities, unknown coverage and obstacle evidence. No acceptance predicate was changed by this comparison.

**Evidence:** [actual same-export results](../independent-usd-reference-catalog-20261028-1514/run40726507227/RESULTS.md), [numeric comparison](../independent-usd-reference-catalog-20261028-1514/run40726507227/COMPARISON.json), [independent direct re-import](../independent-usd-reference-catalog-20261028-1514/run40726507227/INDEPENDENT_REVIEW.json). The earlier section-mesh explanation remains disproven for these exports: section descendants were not meshes. Preserve these exact failing cases as regressions rather than dropping faces, fitting scale or weakening unknown-identity rules.

### G03 We did not retain the exact failing export for an independent reader

**Confirmed historical evidence gap, now closed for the diagnostic comparison.** The production adapter deletes its temporary export. The test inventory then performs a separate export from the same original source. Equal input does not establish byte-identical exporter output. Consequently the present inventory describes diagnostic export number 2, not proven identical production export number 1.

The independent reader must receive exactly the file used by the comparison's Model I/O path. Regenerating an aesthetically similar room or feeding a separate export to another engine would not answer whether our import glue is wrong. Retain the same USDZ and metadata bytes with their hashes, original fixture hash, export options, SDK/toolchain and per-reader options. Admit only the two original public fixtures; no private room upload is needed.

**Prepared retention boundary:** the new `SavedRoomRouteMeshAppleFixtureTests/testOriginalAppleSameExportForOpenUSDComparison` owns a separate inventory and manifest (`blind.saved-room-route-same-export.v1`) binding its own retained diagnostic bytes. Join assets only to that manifest and inventory, not to the old independently executing inventory test. The first published app attempt yielded no verified cases or assets. At `c4ffa28`, the dedicated case passed and all seven exact inputs were retained and verified in artifact `12834885760`. The existing-workflow transport admits only seven exact public-fixture files after source, size and hash checks; a receipt-only failed artifact is not a successful export. Actual Apple attachment delivery is now established for these seven manifest-bound files, separately from the earlier source/synthetic checks. [Captured input manifest](../independent-usd-reference-catalog-20261028-1514/run40726507227/INPUT_MANIFEST.json). [Transport contract and verification](../public-fixture-export-workflow-20261028/README.md).

**Evidence and status:** [original inventory method](../SAVED_ROOM_ROUTE_MESH_METADATA_DIAGNOSIS_2026_10_28.md); [same-byte reference plan](../independent-usd-reference-catalog-20261028-1514/README.md). **Regression:** the collector must reject missing, altered, duplicate or incorrectly bound attachments. Same diagnostic-file agreement must not be relabeled proof of the earlier deleted production artifact or exporter determinism.

### G04 Metric source consistency is verified for two exports; physical accuracy is not

**Partial validation gap closed by actual same-file comparison.** Both stages explicitly author meters-per-unit 1 and Y-up. All 24 reference-imported feature world transforms equal original Float32 source transforms, and all 133 source-anchor pair distances are preserved exactly. The native first failed wall in each fixture agrees with OpenUSD in world matrix exactly and world bounds within 0.000000405 m (Hallway2) and 0.000000283 m (Bedroom3). These cases do not show a 100-fold scale, basis or double-parent-transform error.

The native numerical witness covers only the first failed wall in each fixture, not every native-imported vertex. The independent reviewer separately reopened both exact USDZs and recomputed all 24 reference transforms and bounds. Internal source consistency is not an independent physical survey, gap-width measurement or proof of complete coverage.

The original source fields are reproducible, but are not independent physical measurements:

| Original saved metadata | Floor dimensions as saved | Important limit |
| --- | --- | --- |
| Hallway2 | 8.322798 × 1.9074692 × 0 | Concave floor polygon; not a solid rectangular free-space certificate |
| Bedroom3 | 3.5544705 × 3.3611374 × 0 | Source bounds are not verified exported or real-room dimensions |

Original fixture SHA-256 values are `f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d` and `44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e`, respectively; this audit recomputed both. [Derived source values and hashes](EVIDENCE_SUMMARY.json).

**Comparison dimensions and remaining checks:** authored versus fallback `metersPerUnit` and `upAxis`; raw-stage versus meter-normalized coordinates; mesh-local, parent-world and mesh-world transforms; feature identity; tight vertex bounds versus authored extent/cache bounds; floor elevation, object orientation and inter-feature spacing. Convert once, never normalize to a unit cube or fit the import to the expected answer. Native witness matrices are column-major arrays, while OpenUSD Gf report matrices use row-major row-vector conventions; raw array equality is not a valid comparison. Importers may duplicate or reorder vertices, so equal vertex indices cannot establish corresponding points. Box agreement alone cannot verify door holes, topology or surface positions. **Status:** authored units/axis, all reference feature transforms/anchor spacing/furniture bounds and two native first-wall bounds have been measured. Full native per-feature vertex/topology parity, registered visual route contradictions and physical dimensions remain open.

### G05 We have not reconciled the visible actor with the actual planning envelope

**Confirmed declared-envelope difference, unverified visual mismatch.** The frozen 28 cm profile is not a 28 cm collision diameter. It declares width 0.28 m, depth 0.20 m, height 1.20 m and a retained 0.15 m margin. The circumscribed cylinder radius is `hypot(width, depth) / 2`; the planner adds the margin once.

| Diagnostic profile | Declared width × depth | Raw cylinder diameter | Effective planner diameter | Effective height |
| --- | ---: | ---: | ---: | ---: |
| Nominal | 45 × 30 cm | 54.08 cm | 84.08 cm | 175 cm |
| Wide | 70 × 50 cm | 86.02 cm | 116.02 cm | 195 cm |
| Separate width 28 addendum | 28 × 20 cm | 34.41 cm | 64.41 cm | 135 cm |

These are **declared test inputs**, not measured dimensions, calibration or a recommended human margin. The extra depth/height in the 28 cm profile were explicit assumptions. These numbers may explain why a visible unpadded actor and a planner can appear different in principle, but **they do not explain the current 18 blocked routes**: geometry admission failed before those routes were computed.

**Evidence:** [frozen protocol](../roomplan-route-diagnostic-20261028/PROTOCOL.json), [separate addendum](../roomplan-route-diagnostic-20261028/PROFILE_28CM_ADDENDUM.json), [recomputed arithmetic](EVIDENCE_SUMMARY.json). **Fix and regression:** show raw body and margin envelope separately at true scene scale; verify body center, feet, heading and mount relation; record requested/projected start and goal plus connector distances. Audit each reported wall crossing using the actual path and swept envelope. Do not shrink the body or margin until a preferred-looking route appears.

### G06 The all blocked result has been at risk of being mistaken for an impassable room

**Confirmed interpretation error to avoid.** Current reports mean “we could not admit the geometry,” not “the empty hall cannot be traversed.” `hall-missing-floor` is an intentional unknown-support case, and contained starts are negative controls; neither should be lumped into successful avoidance. Conversely, no candidate path exists in the present all-blocked receipts, so a displayed line cannot honestly be called their successful planner output.

**Evidence:** all 12 baseline, six width-addendum and 16 journey entries explicitly say `unsupported-geometry / sourceGeometryMismatch`; [route reports](../native-path-recovery-20261028/run40710093281/APPLE_ROOM_ROUTE_original-baseline_OUTCOMES.json), [journey report](../native-path-recovery-20261028/run40710093281/APPLE_SUPPLIED_POSTURE_JOURNEY_OUTCOMES.json). **Required reporting:** separate source rejection, invalid start, no path, partial route, collision, withheld movement and true arrival. Preserve the user's visual contradictions for investigation; neither an empty-looking view nor a conservative rejection resolves them.

## Collision and planner findings

### C01 The independent collision checker itself missed a modeled wall

**Confirmed synthetic false-clear defect; narrow repair verified.** The older restricted collision-mask cells pass only 2 of 10 startup controls, whereas platform-default cells pass 10 of 10 with or without the retained renderer. More importantly, the isolated startup pass did not establish mixed-scene correctness: adding a floor to the wall test made the combined query miss the wall in both sweep directions while reporting floor contact.

At `9284719`, a fixed-geometry comparison establishes the narrow distinction:

| Layout and query | Controls passed |
| --- | ---: |
| Wall only, combined | 6 of 6 |
| Wall plus floor, combined | 4 of 6 |
| Wall only, separated categories | 6 of 6 |
| Wall plus floor, separated categories | 6 of 6 |

The separated query returns wall and floor IDs without removing floor endpoint contact, and all eight collision-oracle test cases pass. **This demonstrates the mixed-category query failure and repair within this simulator witness**, not a universal SceneKit failure mechanism or reliable full-scene physical collision checking. The old speed-zero setup was not isolated by this comparison; shadows are not a demonstrated cause.

**Code and evidence:** `ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift` and its tests; [mixed-scene receipt](../native-path-recovery-20261028/run40710093281/SavedRoomCollisionMixedScene-v1.json); [startup matrix](../native-path-recovery-20261028/run40710093281/SavedRoomCollisionBackendMatrix-v1.json). **Regression:** retain bidirectional sweeps, initial/terminal overlap, contained furniture, overhead height, clear controls and mixed floor/wall behavior. Do not certify an oracle solely from isolated shapes or count the repaired oracle as a successful original-room path.

### C02 Floor contact is not full footprint support

**Confirmed evidence limit and missing support proof.** The collision reports explicitly retain `fullFootprintSupportVerified=false`. A cylinder contacting some floor does not establish support under its whole footprint, a valid foot transition, absence of a drop, or coverage along a moving body. Historical floor polygons and floor-classification labels cannot supply current support.

**Evidence:** collision receipts and `PROTOCOL.json`; [live runtime audit](../live-navigation-wiring-20261028/README.md). **Required integration and regressions:** an independent fresh support/coverage condition tied to the full intended swept body and ground region, including near-feet, sides, slopes/drops, unknown areas and stopping movement. No-hit or unobserved geometry stays unknown.

### C03 Native mesh building can consume nearly the entire callback deadline

**Confirmed latency finding, not sustained performance proof.** Earlier `6fe9d52` tests missed their unchanged 10-second callback expectations with waits of 12,702, 10,064 and 10,008 ms. At `9284719` all five classified tests pass, but one callback arrives at 9,948 ms, including 9,781 ms in native build. Across ten retained query receipts, callbacks range 55–9,948 ms, queue wait is at most 356 ms and queued-to-delivered handoff at most 1 ms. All ten retained discard-completion receipts complete in 0–80 ms after discard request.

The observed slow part is native build, not main-queue completion handoff. IDs lack scenario names, so we cannot assign these times to particular tests. A `nativeFailure` stage can be the expected result of a negative control. One passing simulator run does not resolve latency variance or actual-phone responsiveness.

**Evidence:** [earlier failure](../native-path-recovery-20261028/run40698547633/README.md), [stage receipts](../native-path-recovery-20261028/run40710093281/classified-stage-receipts.txt), [timing summary](../native-path-recovery-20261028/run40710093281/classified-timing-summary.json). **Fix status:** instrumentation is published; performance fix not established. **Regression:** retain existing deadlines and cancellation checks; profile bounded native construction without hiding timeouts through relaxed expectations; measure hazard-loop and callback delay on the actual target device separately.

## Live navigation integration findings

### L01 Existing sensing is not a connected live room navigation pipeline

**Confirmed missing integration at audited `dc32a9b`; later local work is not credited as runtime proof.** The normal foreground AR session requests scene depth and mesh reconstruction on supported hardware. It records bounded raw observations, accumulates an observed-surface preview and has a short-horizon candidate planner. It would be wrong to say there is no sensing or geometry creation.

However, `MeshCandidateDiagnostics` add/update callbacks in the audited app count events and refuse copy/ingest; the full mesh-to-native planner path is not live. The diagnostic seam is `DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS`, process-local off by default. Optional RTAB-Map requires its separate build/choice and explicitly does not claim walking guidance. A deliberate RoomPlan scan is a different mode and pauses normal phone hazard monitoring.

**Code and evidence:** `NavigationModel.swift`, `NativeARObservationAdapter.swift`, `MeshCandidateDiagnostics.swift`, `ObservedSceneRuntime.swift`, `LocalPlanner.swift`, `NativeMapping.swift`, `PlaceStore.swift`; exact-revision line references in the [live wiring audit](../live-navigation-wiring-20261028/README.md). **Fix status:** bounded nonwalking bench and ingress work is prepared, not demonstrated unfamiliar-room navigation. **Regression:** one actual native owner must show bounded owned updates/removals, explicit gaps, stale-result retirement and hazard-first behavior; no borrowed buffer may silently outlive its valid callback lifetime.

### L02 Classification was not carried through the existing ingress policy

**Confirmed source-semantic gap; opt-in adaptation published and all nine hosted fixtures now passed at c4ffa28.** ARKit classification is copied/decoded in stages 82/81, but the existing stage 83 path uses the legacy slope policy and does not forward per-face semantic roles to the classified stage 75 path. The prepared change adds explicit `.classifiedFloorOnly` opt-in: only floor label 2 becomes floor, all other or unknown labels remain obstacle roles, and absent/malformed classification records an unknown gap. It preserves geometry rather than dropping unknown faces.

**Code and evidence:** `research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift`; [frozen proposal](../mesh-classification-ingress-proposal-20261028/README.md); [candidate integration](../mesh-classification-integration-20261028/README.md). **Status:** source checks and the separate stage 83 package proof are distinct from the nine new native hosted executions, now verified in the final c4ffa28 receipt. The earlier follow-on app run failed to link, but the repaired c4ffa28 run executed and passed all nine cases. Default legacy behavior is unchanged; no existing consumer is silently switched. **Regression:** all labels, unknown replacement, floor recovery, overhead-table obstruction, transform-once and reset preservation; true classifier accuracy remains a separate device question. A floor label is not measured support.

### L03 Camera tracking does not establish body pose or current clearance

**Confirmed missing integration.** The audited production pose path retains calibration revision `unconfigured`; localization router/issuer collect candidates and withdraw physical evidence. The current camera/room-recognition path does not install the measured pose/support pair required by physical route acceptance. Camera optical axis, stored room identity and an ARKit pose cannot stand in for body heading, chest mount offset, stance, body/equipment bounds or map registration uncertainty.

The route owner validates installed map geometry and restrictions, not a fresh full scene. The delivery gate's fresh frame plus hazard state `.observing` is not complete swept-volume clearance. The hazard detector is a level-floor research prototype, and supplemental positive-observation body warnings explicitly do not prove absence of an obstacle or ground hazards.

**Evidence:** `NativeLocalizationRouter`, `NativeLocalizationIssuer`, `SpatialRouteOwner`, `SpatialRouteOutputController`, `HazardDetector`, `BodyCollisionWarning`; [exact-source runtime evidence](../live-navigation-wiring-20261028/README.md). **Required work:** measured camera-to-body/frame association and uncertainty, plus a separate fresh target-specific whole-body/head/ground coverage condition checked again at delivery. Filling in a pose issuer alone is insufficient. **Regression:** changed mount, turn/sideways motion, tracking loss, old map, moved furniture, missing near-feet/head coverage, stale callbacks and stopping distance. No physical or independent-use acceptance is claimed.

## Test validity and engineering process findings

### P01 Historical assisted benchmarks cannot establish phone navigation

**Confirmed scope limit, not invalidation of every component result.** The retained progress record reports 100 accounted attempts: 94 completed movement episodes comprising 90 arrivals, three support stops and one predicted-underbody rejection, plus five interrupted unknowns and one CPU-limited partial. It also records supplied poses, reference support/collision veto, zero-margin body, assisted source exclusions and unmeasured ground contacts. Those assumptions prevent presenting the result as phone-only accuracy, current obstacle avoidance, a table-lap test, or physical guidance.

The earlier phone-only mapper also preserved unusable floor/barrier results. Such results should trigger sensor association, metric/frame and reconstruction diagnosis, not a conclusion that the real room is impassable. The local partial checkout does not contain the full final benchmark package, so this report relies on the explicit historical status record rather than pretending to re-score its raw episodes.

**Evidence:** [PROGRESS historical 06:24 entry](../../PROGRESS.md), [TASKS mapping evidence and limitations](../../TASKS.md). **Regression and reporting:** freeze input/map/route/body hashes before evaluation; keep reference geometry out of planner correction; separate complete, stopped, rejected, partial and unknown runs; preserve failed attempts instead of rerunning them into successes. Reference-assisted success is useful only with its assumptions attached.

### P02 Source pin maintenance broke both native proof workflows before tests

**Confirmed process defect; repair verified within the follow-on package and ingress proofs.** At `9284719`, proof runs `40710093201` and `40710093419` stop before build/test on an obsolete `Bridge.swift` hash. Four stage 75 adapted sources changed after the last Apple manifest update: `Bridge.swift`, `RoomMeshCandidate.swift`, `blind_detour_exclusion.cpp` and `include/blind_detour.h`. The stage 83 nested manifest also needs the reviewed digest. This is not a native compiler or runtime failure, and DEBUG timing alone did not cause it.

**Evidence:** [pin reconciliation](../apple-source-pin-reconciliation-20261028/README.md), [room-mesh failure receipt](../native-path-recovery-20261028/run40710093201/bounded-pin-failure.json), [ingress failure receipt](../native-path-recovery-20261028/run40710093419/bounded-pin-failure.json). **Status:** the four-entry repair verifies all 55 targets without bypassing checks. At `4eb0d10`, both affected proof workflows complete successfully within the explicitly limited scopes above; the separate app hosted-case failure and absent USDZ remain open. **Regression:** check active and nested manifests against exact current bytes before publication; retain mutation rejection; do not repin historical reports green or weaken provenance checks.

### P03 Our first early evidence export passed stubs but failed in real CI

**Confirmed process defect, repaired and natively verified.** The `6fe9d52` early collector ran before `unit-summary.json` existed. Its early output was correctly incomplete; only the terminal summary allowed recovery. The original 37 structural/stub checks missed the real file dependency because a stub verified arguments rather than the real exporter/summary chain.

The repair runs the existing bounded summary exporter before the case collector. Six actual-shell/real-exporter regression cases cover missing/mismatched/failed summaries and provenance. Early and final case extracts at `43e33d4` and `9284719` are complete and semantically identical.

**Evidence:** [dependency repair](../early-native-summary-repair-20261028/README.md), [native verification](../native-path-recovery-20261028/run40706611490/README.md). **Regression:** exercise the real integration order and failure outputs, not only command arguments. Keep collection failure separate from the underlying test outcome; missing evidence is not a pass.

### P04 Passing source contracts and component counts have not closed user journeys

**Confirmed acceptance gap.** Seven hosted native failures remain, and no original-room candidate or sustained guidance/controller replay completed. The reports explicitly say camera localization, get-up kinematics, sustained controller, VoiceOver and full-footprint support were not tested. A supplied standing pose is not successful rising from bed/chair. A waypoint sink is not audible timely guidance or arrival on a phone.

Five conversation/model cases that had failed previously became skipped at `6fe9d52`; the reduced failure count was not five repairs. Likewise, a native compile, correctly discovered test, package checksum or source-contract pass does not establish that a new integration executed. The current partial local checkout also causes ordinary full-project membership equality to fail; independently verified remote inventory is useful but does not turn that local failure into a complete-checkout pass.

**Evidence:** [latest native result](../native-path-recovery-20261028/run40710093281/README.md), [journey flags](../native-path-recovery-20261028/run40710093281/APPLE_SUPPLIED_POSTURE_JOURNEY_OUTCOMES.json), [membership limits](../mesh-classification-integration-20261028/README.md). **Required gates:** source prepared → exact-source build → actual native case outcomes → controlled connected replay → measured device sensing/localization/latency → appropriately supervised physical acceptance. No component count substitutes for the next gate.

### P05 Accessibility remains a real product defect

**Confirmed native UI failures, separate from geometry.** At `6fe9d52`, Ask reports clipped “Everything in view” text. The prepared inline multiline picker repair addresses compression without shortening labels or capping Dynamic Type. At `9284719`, clipping is not the reported failure, but contrast still fails: the identified disabled `local-answer` button is labeled “Ask about the camera view.” Camera before/after evidence exists; Ask after-shot is missing because the audit failed, so extraction is incomplete.

**Code and evidence:** `DashboardView.swift`, `LaunchTests.swift:373`; [clipping repair](../ask-focus-layout-repair-20261028/README.md), [latest bounded UI evidence](../native-path-recovery-20261028/run40710093281/ui-audit/evidence.json), [identified callback metadata](../native-path-recovery-20261028/run40710093281/ui-audit/full-audit-ask-issue-1-metadata.json). **Regression:** unchanged full Camera/Ask audit, full labels, English/Arabic, largest accessibility sizes, selected state, scrolling and Ask/Stop reachability. Absence of the old clipping callback is not a comprehensive accessibility pass.

### P06 Historical reconstruction scores are not all independent held out accuracy

**Confirmed evaluation limitation, with reproducible historical geometry discrepancies.** The recovered author-configured Open3D baseline ran version 0.19.0 (the author's lock was 0.18.0), integrating 265 Koivu processed-depth views and excluding 29. It used supplied poses, 4 cm voxels, 20 cm SDF truncation, 4 m depth truncation and depth scale 1000. Those are the recorded settings, not newly tuned values. Depth scale 1000 must be judged against the actual input encoding, not criticized merely because iPhone APIs can expose meters. Original confidence/tracking are unavailable; a supplied-pose fusion is not SLAM. [Frozen inputs and parameters](evidence/open3d/KOIVU_FROZEN.json), [recovered fusion result](evidence/open3d/RECOVERED_RESULT.json).

There are two different historical scorers. One compares 29 excluded views against processed phone depth from the same capture. The other compares eight saved viewpoints against author-processed FARO-mesh rays, but **seven were integrated and only frame 21 was held out**. It has no measured-versus-edited reference mask. Their reference, evaluation domain and pixel offsets differ, so their scores must not be treated as a controlled head-to-head comparison or pooled into a single accuracy claim.

| Historical scorer and domain | Paired rays | Median absolute residual | Mean absolute residual | 95th percentile absolute residual |
| --- | ---: | ---: | ---: | ---: |
| 29 held-out same-capture phone views, 0 < observed depth < 4 m | 1,161,037 | 3.17 cm | 14.50 cm | 73.06 cm |
| Eight saved FARO-relative views, all paired rays, seven integrated | 334,223 | 3.91 cm | 27.11 cm | 198.37 cm |
| Only held-out frame 21 within that FARO-relative comparison | 40,864 | 3.62 cm | 9.01 cm | 34.15 cm |

These are axial-depth residuals in the nominal metric frame, not independent physical position, obstacle-recall or body-clearance errors. The tail values matter: a favorable median cannot establish reliable geometry everywhere. They do not, by themselves, identify an erroneous scale, pose, shadow, surface, edited reference region or runtime obstacle miss. [Original held-out report](evidence/open3d/heldout-result.json), [original saved-reference report](evidence/open3d/saved-reference-result.json).

A newly authorized arithmetic recount reused all eight published numeric arrays (6,477,426 bytes), made **zero new reconstructions and zero new raycasts**, and reproduced the historical statistics to a maximum numerical difference of approximately `4.44e-16`. For the deliberately descriptive ±10 cm bin, 10.15% of paired returns are early, 82.34% within and 7.51% late. Of all 368,520 scheduled rays, 334,223 are paired, 111 reference-only, 33,671 TSDF-only and 515 neither. No-hit categories remain separate; missing reference does not establish false geometry and missing prediction does not establish free space. These are post-hoc descriptive bins fixed before the recount, **not preregistered safety criteria, proven false-obstacle/missed-object rates or a new held-out reconstruction experiment**. [Recount protocol](evidence/open3d/RECOUNT_PROTOCOL.md), [new arithmetic result](evidence/open3d/SAVED_ARRAY_RECOUNT.json), [byte-identical evidence copy provenance](evidence/open3d/COPY_PROVENANCE.json).

The historical fusion worker itself completed, but an ANSI color-clamp warning broke the wrapper's JSON-report parsing afterward. The saved report was recovered without repeating fusion; exact peak fusion RSS was not serialized and remains unknown. This is another reporting defect, not an Open3D geometry failure. A reporting-only correction should preserve native warnings and capture resource evidence independently of stdout, with regressions for successful-with-warning, failed, truncated and interrupted output. [Preserved recovery receipt](evidence/open3d/RECOVERY_RECEIPT.json).

**Required next check:** compare compatible reconstruction pipelines using the same original bytes, pose/intrinsic conventions and frozen training/holdout protocol; retain near/far, missing-return and local high-error strata. Do not select only matching views, hide the tails, or announce a winning engine from unlike scorers. New raw-input reconstructions and absolute physical accuracy remain unestablished at this checkpoint. Open3D, the original RGB/depth/K/pose inputs and full reference mesh are not currently present in the benchmark staging environment; a usable VTK runtime and saved numeric arrays do not replace them. The [readiness plan](evidence/open3d/READINESS_REPORT.md) records exact acquisition/runtime/resource prerequisites and the [availability audit](evidence/open3d/SOURCE_AVAILABILITY_AUDIT.json) distinguishes them from completed source checks.

### P07 New test membership broke linking and blocked unrelated geometry evidence

**Confirmed native integration and process-coupling defect at `4eb0d10`.** The hosted target links stages 82/83 but omits a direct `MeshBufferDecoder81` product dependency. The new `ClassificationIngressTests` compile against stage 81 types exposed through the stage 82 API and default arguments. Native linking then reports unresolved descriptors for `ValidatedRevision` and `ClassificationDiagnostic`, plus `Limits.init(vertices:faces:inputBytes:decodedBytes:)`, from that test object. Source-only project membership and inverse checks did not establish complete native linkage.

The impact extends beyond the classification tests: the public-fixture same-export test shares the bundle, so it cannot execute or capture the independently requested USDZ. UI tests are also cancelled by the build failure. Both app builds and the isolated package/ingress proofs pass, but there are **zero executed hosted/UI cases**, not a new measured geometry regression. The collector correctly withholds assets on unverified case evidence; removing its gate would conceal the failed prerequisite.

**Code and evidence:** `tools/generate-xcode-project.mjs`, `ios/BlindAssist.xcodeproj/project.pbxproj`, `ClassificationIngressTests.swift`; [published generator](https://github.com/mischa23v/blind/blob/4eb0d10f1724bce3ef2f6e6a8ff8ae35a06b85e6/tools/generate-xcode-project.mjs), [native failure](../native-path-recovery-20261028/run40721822359/bounded-link-failure-lines.txt). **Fix status:** explicit stage 81 hosted product/link membership is published at `c4ffa28`; the exact-source rerun linked successfully and executed all nine new classification ingress tests and the dedicated export case successfully. Seven unrelated geometry-admission tests still fail; this is a verified linkage repair, not a geometry pass. [Reviewed linkage repair](../hosted-mesh-decoder-link-20261028/README.md). **Regression:** complete-checkout canonical project equality, a native test-bundle link and actual discovery/execution of the new classification and same-export cases, preserving all assertions and provenance gates. As a future evidence-reliability improvement, review whether public fixture export can be isolated from unrelated feature-test dependencies; that decoupling is not implemented here.

## Independent comparison status and required decision

**OpenUSD 26.5 read both exact diagnostic exports; the comparison was independently repeated.** Its official wheel is 28,743,527 bytes, SHA-256 `caa2447252aeada8c158faacd4d448f29cf1617aeccef5bb954734b93c8f3f62`. The earlier install receipt's `fixture_import_ran=false` describes installation only and is superseded for execution by the later run receipt. The wrapper remains reviewed glue around official USD APIs, not a new reconstruction engine. [Install receipt](../independent-usd-reference-catalog-20261028-1514/OPENUSD_INSTALL_RECEIPT.json), [execution receipt](../independent-usd-reference-catalog-20261028-1514/run40726507227/EXECUTION_RECEIPT.json), [comparison results](../independent-usd-reference-catalog-20261028-1514/run40726507227/RESULTS.md).

| Comparison question | Current answer | Remaining limit |
| --- | --- | --- |
| Exact shared diagnostic USDZ and metadata available | Verified seven-file capture | Production export number 1 was separately generated and deleted |
| USD units and axis match app interpretation | Explicit 1 meter per unit, Y-up | Not physical measurement accuracy |
| Source feature placement and anchor spacing | 24 transforms and 133 anchor distances preserved exactly | Anchor distance is not passage clearance |
| OpenUSD versus native numerical witness | Two first-wall matrices exact; bounds within 0.405 micrometers | Full native per-feature vertex parity unmeasured |
| Furniture local dimensions | Bed, chair and table match source half-dimensions | Source dimensions not independently surveyed |
| SceneKit same-file geometry agreement | Not established | Separate SDK numerical witness needed |
| Door cutouts, floor concavity and surface integrity | Not established by boxes alone | Topology and surface/clearance comparison needed |
| Viewer, actor and actual path share one metric frame | Not established | Registered render/body/path witness needed |
| Physical room and current clearance | Not established | Calibrated physical and live sensor evidence needed |

Readers agree on the sampled native geometry while that export differs from source planes. Therefore the next correction concerns the semantic contract. Do not best-fit, delete geometry, enlarge tolerance or hand-adjust scale to manufacture agreement. In particular, the approximately 16 cm floor-outline expansion cannot silently become measured support.

## Two different same data questions must remain separate

The requested independent checks have two different purposes:

1. **Same exported file through different readers.** Model I/O, OpenUSD and a separately reported SceneKit path can expose import, transform, axis, scale or scene-graph errors. They must consume the exact manifest-bound USDZ and metadata bytes. This does not reconstruct the room from raw observations and cannot validate the original scan's physical accuracy.
2. **Same original sensor observations through compatible reconstruction systems.** Existing Open3D and RTAB-Map pipelines can test whether our reconstruction choices are introducing avoidable errors. They need the same hashed RGB/depth/intrinsics/poses, explicit depth encoding and frame conventions, frozen training and held-out split, declared available confidence/tracking fields, fixed parameters and a separate scoring reference. An engine that cannot consume the dataset faithfully should be reported incompatible or blocked, not as a geometry failure. No new-input reconstruction result is currently established in this report.

Keep train-view fit separate from held-out reconstruction quality. A mixed training/held-out evaluation must disclose its exact composition rather than being called wholly independent. A library's default depth scale is not automatically wrong: test whether depth pixels are millimeters, meters or another documented encoding before choosing the conversion. Likewise, a failed installer checksum establishes an environment/provenance failure, not poor reconstruction accuracy. Do not change data, poses, holdout frames or parameters after seeing favorable scores and still call the comparison frozen.

## Work order and stopping conditions

1. **Preserve the completed same-file comparison.** Publish exact original public inputs, native manifests, official-reader reports, independent review and hashes. The retained first-failure witness now identifies the contract defect; the separately deleted production export remains outside the byte-identity claim.
2. **Extend the independent same-data comparisons where still needed.** The completed OpenUSD comparison covers all reference features and two native first-wall numerical witnesses; extend native all-feature/topology coverage without changing the inputs. Separately, run only compatible raw-input reconstruction pipelines under a frozen shared dataset/holdout protocol and report held-out metrics and incompatible/blocked cases honestly. Preserve failures rather than switching fixtures or secretly changing inputs.
3. **Fix only the demonstrated geometry defect.** Keep strict unknown-identity and privacy boundaries. If the representation is intentionally different, document a valid semantic conversion with an explicit uncertainty/error model; do not confuse generated geometry with a measurement.
4. **Validate any simplification after geometry agreement.** Preserve metric units, floor elevations, openings, low/overhead obstacles, boundaries and unknown coverage. Measure local surface displacement and topology changes against the accepted unsimplified reference. Do not optimize face count before establishing the reference or fill unknown holes for cleaner paths.
5. **Only then rerun frozen route and independent collision cases.** Keep all 18 routes and 16 stages, requested/projected endpoints, connectors, raw/margin contacts and unknown support. Investigate each visual wall/gap contradiction numerically. A no-path result is not a successful arrival.
6. **Close the separate live integration and timing gates.** Real owned mesh updates, classification, body/mount pose, current coverage and delivery revalidation must be connected and measured; historical fixtures cannot close those gates.
7. **Re-run exact-source native and accessibility acceptance.** Repair active pins and evidence ordering, preserve skips/failures, and verify the actual revised source. Keep supervised physical/child acceptance distinct; no walking authorization follows from this report.

The supported conclusion is concrete: **our source-bound validation incorrectly rejects Apple's exported solids and expanded outlines; the sampled native and independent reads agree.** That finding does not establish the cause of every older Koivu failure, prove all geometry correct or authorize physical guidance. The earlier collision oracle also had a demonstrated mixed-scene miss, and the complete live body-aware navigation chain remains unfinished. No evidence here establishes that shadows caused the failure or that the empty hallway is physically impassable.

## Appendix on the reported 92 percent study

The user's reported 92% study has **not been identified confidently**. A verified near-match, Kuribayashi et al.'s *Corridor-Walker* (2022), reports 92.9% for participants correctly labeling L- and T-intersection shapes in Task 1, with 14 blind participants and an iPhone 12 Pro. That statistic is not room-reconstruction, dimension or clearance accuracy, and this report does not assert that it is the user's intended paper. This distinction limits what the number validates; it neither discounts the viability of phone-based assistance nor excuses our confirmed integration defects. See sections 4 and 6.2.1 of the [author paper](https://wotipati.github.io/projects/other_papers/MobileHCI%2722_Corridor-Walker/MobileHCI2022_CorridorWalker.pdf) and the [official project page](https://sites.google.com/view/corridor-walkerproject/).
