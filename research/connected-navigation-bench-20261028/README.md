# Connected navigation bench integration candidate

**Implemented candidate test code, not yet compiled or executed. N00 is not complete.** No Swift executable or Apple SDK is available in this workspace. The source checks below do not substitute for native execution. Files remain here, outside the app/test target, until independent review and coordinated PBX membership. No production source/release gate changed.

## What this actually connects

`ConnectedNavigationBenchIntegrationTests.swift` constructs the actual `IndoorNavigator`, imports and persists a real `SpatialMapInstallation` through its asynchronous storage/publication path, and wires its callback into the actual `ConnectedJourneyRuntime`. It then uses the real `NativeLocalizationRouter`/issuer's retained candidate and bench pair, with matching capture/support IDs, before a **test-only** bridge calls runtime acceptance. Real code planning, ticket permission, `SpatialRouteOutputController`, fake speech/beacon callbacks and output retirement execute if the candidate native test passes. The uncertain hazard comes from the actual `HazardDetector` on a missing-tracking observation. No camera, LLM or real speech/haptic output is used.

The positive map, floor support, camera/body/error records and validator are **authored contract fixtures**, not claimed measured calibration. A test validator exists only in this candidate test source. Production still has no calibrated producer and still reports `physicalReleaseNotApproved`. A separate negative test removes support and requires rejection before runtime acceptance. No private access modifier or physical release check was relaxed.

This is a map→owner→candidate→planner→output-lifecycle integration test. It does **not** yet exercise full live NavigationModel output permission (which also checks session, actual frame freshness, mounting, quiet/scan state); its fake-sink closure is an explicitly narrower bench composition. It also does not test a doorway crossing, return journey, continuous physics or measured human motion. These remain required next cases, not implicit passes.

## Real Koivu evidence kept separate

`KoivuSourceAnchorBenchFixture.swift` and `RECORDED_INPUT_RECEIPT.json` retain the exact five original-coordinate anchors used by the frozen 20-pair source selection. The source JSON/hash is checked. Its coordinates are recorded-source metadata; its zero Y values are **not proof of a flat floor**. The dataset namespace hierarchy is explicitly authored, not real-world building/floor identification.

The corresponding test imports those actual coordinates through the same native owners, preserving the requested destination while refusing localization. It deliberately creates **no route edges, floor surface, world-map descriptor or calibration** from sparse anchors. The expected result is `importedFrameNeedsMeasuredRegistration`, not a successful route. This catches accidental promotion of data availability into navigation authority; it is not progress in Koivu collision accuracy.

Public source attribution: Xuqian Ren et al., MuSHRoom, https://zenodo.org/records/10230733 and https://zenodo.org/records/10222321, CC BY 4.0. These small coordinates come from the already published source-anchor derivative. No raw images, private scans or new downloads are included.

## Exact remaining recorded-geometry bridge

1. `RoomMeshCandidateRuntime` currently outputs candidate Recast points; its route exposes `authorizesPhysicalGuidance=false`, `actualWorldCoverageKnown=false` and `rawDepthHazardVeto=true`.
2. `NativeMapping.localGridSnapshot` currently has no consumer outside its owner. A local grid is not already an installed room hierarchy/route map.
3. `IndoorNavigator` can already publish a registered installation to `ConnectedJourneyRuntime`. However, no reviewed bridge converts the actual recorded mesh/planner/coverage artifacts to this installation **without inventing floor support or navigation edges**. That is the next substantive adapter, not another hypothetical room fixture.
4. The existing candidate-only localization issuer also has no real calibrated producer. For recorded replay, supplied poses and reference support may be used only with explicit provenance and a separate replay output sink—not relabeled live measurements. Ground-truth evaluator support must remain visibly assisted.

Thus this increment tests the existing handoff boundary and imports genuine source metadata but does not make the recorded room traversable in the app. A functional recorded-data integration must use the actual mesh/coverage/planner outputs and freeze their coordinate transforms, dimensions, revisions and exclusions. Do not wait for physical trials before implementing that; do not remove gates merely to make a test green.

## Reproduce bounded checks

`python research/connected-navigation-bench-20261028/source-check.py`

Checks source/provenance, actual owner calls, evidence identity and absence of manufactured support in the recorded fixture. `SOURCE_PINS.json` identifies the exact inspected native/Core sources. `SOURCE_CHECK_RESULT.json` explicitly marks Swift/native/recorded movement as not executed. For native adoption, review both candidate Swift files, coordinate their test membership with the PBX owner and run them through the existing approved native CI. Preserve any first compiler/runtime failure; do not silently call source checks a test pass.
