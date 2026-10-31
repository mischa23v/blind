# N04: interrupted portal recovery without a fabricated crossing

Source candidate only. This closes a concrete recovery dead end in the existing app consumer; it does **not** close N04, validate native localization, establish physical clearance, or authorize walking. Shared base is `ff0f50df695bfa48fd72697858c574fda653dc4e`; the three modified Swift files are unchanged by the reviewed post-ff0 86-file continuation (manifest `e160a0ebf31818e19cf287fc7dea2e15f9ca058ec8cf73c7b1e791af042e26eb`). Root publishes; the separate integrator owns composition/pins.

## Observed source gap

`ConnectedJourneyRuntime.accept` already arms a portal from a fresh source endpoint and requests the destination binding's existing localization owner. That is destination **intent**, not a measured crossing. `ConnectedJourneyCoordinator.withholdNativeEvidence` deliberately discards the departure receipt while retaining the current session/replay ledger and itinerary. On a subsequent fresh destination-endpoint capture, the runtime previously called `completePortal` with no departure receipt and threw `wrongLeg`; repeated destination captures could never resume the retained goal. The same dead end occurs after the existing 120-second departure lease expires. A different uniquely established destination-map node also left the old portal itinerary waiting for an endpoint that was never observed.

This diagnosis follows the actual coordinator/runtime call chain. It is not a reproduced iPhone failure: no Swift compiler or Apple runtime is available in this executor.

## Narrow repair and retained boundaries

A new coordinator retirement helper runs only inside the runtime's existing **accepted capture → unique mapped endpoint → durable active goal** branch. It requires the exact active owner binding, target binding/floor and the existing `requireEndpoint` pose/support checks. It preserves the original source/rearm path and the existing valid expected-destination association. If the departure association is absent/expired, or fresh evidence instead establishes another target-floor node, it retires only the abandoned itinerary. The runtime then reuses its existing arrival/`plan(from:)` path from that independently established current endpoint.

There is no old-pose replay, endpoint snapping, transform invention, floor flattening or new routing algorithm. Goal/revision, start/reference history, current session/replay ledger, body limits, map artifacts/restrictions and independent current-hazard veto remain unchanged. The abandoned transition creates **no** `portalEndpointsAssociated` event and does not prove which door, lift or route was traversed. An independently established final endpoint can still complete the ordinary goal through the unchanged fresh endpoint arrival gate; it cannot retroactively verify the transition.

Missing current evidence, ambiguous nodes and arbitrary mid-leg coordinates remain withheld. Restart restores intent/history only; requested localization is not accepted localization. A denied or blocked existing planner result remains a refusal, never a new shortcut.

## Existing components reused

- `ConnectedJourneyCatalog.plan` → `IndoorMap.route` and `SpatialRouteOwner.plan/next`, with their existing body, surface and conservative restriction checks. This is reuse of the application's existing implementation; it is not described as a newly adopted or independently proven upstream planner.
- Existing `SpatialLocalizationLease`/`requireEndpoint` capture, session, age, uncertainty, support and frame ownership. Their measurement producer remains a separate dependency (N02).
- Existing `RecordedRouteStore` private GRDB pagination, capture/session continuity boundaries and historical reverse previews remain unchanged. `NavigationModel.startReturn` continues to select an endpoint return goal; `startRecordedReturn` still labels raw camera breadcrumbs as history and does not promote them to current clearance.
- No dependency, release pin, license claim, map geometry, data download or current physical authority is added. Existing Recast/Detour and ARKit adapter adoption records are unchanged; this fix does not claim to execute them.

## Verification actually performed

- **30 portable source contracts passed**, including actual consumer order, exact binding/floor ownership, unchanged 120-second bound, fresh endpoint/support checks and independent hazard veto.
- **12 source mutations rejected**. The first checker attempt incorrectly accepted `<=1200` because of a substring-only `<=120` check. That checker defect was repaired by checking the following `else`; the unchanged mutation set then rejected all 12. This was a source-check failure/repair, not a native test result.
- All **20 previous hosted test methods** and the entire prior fixture prefix remain byte-for-byte unchanged. Nine relevant coordinator methods and ten runtime methods are also unchanged. Original functional assertions and native timing limits are not weakened.
- **Seven additional hosted methods authored, not compiled or run:** missing departure receipt; expired upper-floor association; independently established different node; ambiguous/mid-leg refusal; old session/stale capture plus restart; interrupted reverse return retaining the original start; explicit destination replacement during interruption.

Run the portable source check against the selected composed tree:

```sh
python3 -B tools/test/connected-portal-recovery.test.py
```

The new cases extend the already-member `ConnectedJourneyRuntimeTests.swift` hosted target, so no project membership change is needed. After composition and review, the canonical native Apple hosted lane must compile/run the exact source and preserve every failure/skip. Actual room/floor crossings, live body/heading/support/hazard evidence, blocked return, device timing and complete journeys remain open; synthetic authored inputs do not satisfy them.
