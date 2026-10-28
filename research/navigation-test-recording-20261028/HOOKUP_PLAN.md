# Hookup design and current source status

## 1. Existing owner to screen

`NavigationModel.swift` owns `private let nativeObservations = NativeARObservationBridge()` (currently near line 302). Add an internal main-actor view factory in that class, not a new capture owner:

```swift
@MainActor func makeNavigationTestRecordingView() -> NavigationTestRecordingView {
    NavigationTestRecordingView(bridge: nativeObservations, arabic: arabic)
}
```

Then an accessible helper/diagnostic destination can call that factory. `RoomDetailView` already has the same `NavigationModel`. Do not create another bridge in the destination. Implemented after root coordination: NavigationModel factory and separate RoomDetail diagnostic destination, preserving the published preview and photo tools.

Register only `ios/BlindAssist/NavigationTestRecordingView.swift` through the canonical `tools/generate-xcode-project.mjs` and regenerate PBX. Store/bridge and existing hosted test file already belong to the project. The view never starts the camera: Start requires the existing camera session. Leaving the diagnostic screen or backgrounding stops this diagnostic; resuming never opts back in.

## 2. Read the real planned polyline without issuing another route

`SpatialRouteOwner` already exposes `route: [MapNode]`, `routeID`, `goalRevision`, `waypointIndex`, installation binding, body and obstacle revisions. `ConnectedJourneyCoordinator` owns it privately. Add a narrow **read-only diagnostic snapshot accessor** at that owner boundary and forward through `ConnectedJourneyRuntime`. Copy existing `route.map(\.position)` and existing identifiers. Do not ask the diagnostic recorder to plan, and do not connect current position to target with an invented straight line.

Do not call `ConnectedJourneyRuntime.next(now:)` merely to draw: it sets `held` and participates in output ownership. Do not scrape `connectedJourneyBeacon` speech or treat a directional cue as a full route. A snapshot accessor is the suitable seam.

Publish a new diagnostic plan on actual route/goal/binding/restriction change; empty points represent cancellation, failed plan, scope withdrawal or map deletion. Keep last known map binding only as historical context, not current localization. The current diagnostic schema stores route/goal/map revisions; body revision, obstacle revision and geometry digest should be retained too when extending the real-owner snapshot, not inferred from a label.

The recording event's monotonic receipt timestamp must be assigned under the recorder's serialization boundary. Do not send an old planning timestamp as `recordedAt` after later camera receipts; the current adapter deliberately stops on such a rejected update rather than continuing an obsolete overlay. If the planner has a distinct creation timestamp, retain it as a separate field instead of relabelling it as receipt time.

## 3. Registration: absent today, never synthesize it

`NativeLocalizationCandidate` carries original AR camera-to-world transform and owner/calibration identifiers. It does **not** provide a measured source-world-to-map transform or validated uncertainty. `NativeLocalizationIssuer.offer` explicitly remains at missing calibration; `prepareForBench` is not physical-release approval. `acceptConnectedJourneyCapture` is a distinct calibrated seam, not a conversion from arbitrary recorded camera history.

Therefore the first hooked-up screen can record and show the actual existing camera-path estimates in their raw session frame immediately. A real code-owned route can be shown independently in its map frame with `alignment: nil`. It must not overlay raw AR coordinates onto that map.

Only a reviewed registration producer may supply the source-session/frame → exact map transform with evidence ID, revision, calibration revision and validity interval. Do not substitute identity, nearest route point, saved room name, AR tracking-normal, body yaw or a manually guessed offset. On session/frame/mount/map/registration change, retire the prior association and emit a new plan context or cancellation. All raw samples remain unchanged for later diagnosis.

## 4. What this increment does not yet establish

- User-facing destination/factory are now authored. Canonical native project membership is coordinated separately.
- The read-only full-polyline owner accessor and runtime change callback are now authored, including initial Start snapshot and deduplicated cancellation/provenance. A measured registration callback remains absent; alignment is nil.
- The standalone plot has no walls/table mesh; seeing a line is not a collision test. Pairing it with matching geometry or synchronized replay remains another explicit integration.
- Private sidecar is memory-only; process exit loses it without auto-resume. Existing GRDB route history remains separate. Durable diagnostic recovery/export require further reviewed local storage work.
- Existing Apple CI must compile/run the authored nine Core + four hosted tests, followed by actual lifecycle/VoiceOver UI checks. No child walk requested.
