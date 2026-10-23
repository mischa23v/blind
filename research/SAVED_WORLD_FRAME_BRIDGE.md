# Saved RoomPlan world-frame bridge

Source implementation, 2026-10-23. This is a native-framework adapter and evidence lifecycle gate, not new SLAM, a validated locator or authorization for physical guidance.

## Sourced API behavior

- Apple, [Explore enhancements to RoomPlan, WWDC23 session 10192](https://developer.apple.com/videos/play/wwdc2023/10192/), custom ARSession and MultiRoom segments (approximately 02:00–07:30): RoomCaptureSession can use an existing ARSession; keeping that session running preserves the common coordinate basis. Relocalizing a previous ARWorldMap aligns the new session to the saved world coordinate system. Our scan already uses RoomCaptureSession(arSession:) and stop(pauseARSession: false).
- Apple, [Managing session life cycle and tracking quality](https://developer.apple.com/documentation/arkit/managing-session-life-cycle-and-tracking-quality): loading initialWorldMap enters relocalization; normal tracking after successful reconciliation indicates the recorded map is matched. Environmental change can prevent recovery. A timeout is unresolved, not a new room.
- Apple, [ARWorldMap.anchors](https://developer.apple.com/documentation/arkit/arworldmap/anchors): anchors and transforms are saved in the world map; the anchors array may be edited before archiving. Restored anchors are available after ARKit reconciles the saved map.
- Apple, [ARWorldMap](https://developer.apple.com/documentation/arkit/arworldmap): NSSecureCoding supports local serialization; initialWorldMap resumes the saved spatial awareness. No sharing API is used here.

These are Apple platform APIs, not copied third-party implementation or weights. Pin is the public API surface available from iOS 17 (custom RoomPlan session); the exact installed Apple SDK and runtime must be recorded during the Mac/device check. No Apple upstream test suite was run. API documentation is provenance, not evidence of this app's measured localization accuracy.

## Adapter and stored provenance

New scans store a SavedWorldFrame with place UUID, immutable scan revision, SHA-256 hashes of the original room JSON and archived worldmap, capture date, coordinate convention and source. An identity ARAnchor with a revision-specific name is added to the map before archiving. The room JSON and map must both match their stored hashes. Hashes detect changed/mismatched artifacts, not a trustworthy physical scene.

RoomPlan measurements and the paired worldmap share the ARSession basis. This adapter uses that documented identity relationship, not an invented geometric fit. A stable frame ID identifies saved measurements; an independent run UUID identifies the current ephemeral session. Imported/manual IndoorNavigator map coordinates are never equated with these coordinates.

Legacy scans without this provenance remain available as preview/semantic history. They do not receive a synthetic binding by filename, place name or appearance similarity. A new supported scan creates the missing relationship.

The live gate is not persisted. It requires the expected session, an observed relocalizing-to-normal transition, mapped/extending status, the exact saved origin anchor in its unchanged identity basis, distinct fresh frames and a bounded recovery interval. A three-frame admission window is app debounce, not calibrated probability. Tracking loss, missing marker, stale frames or a new run withdraw binding. The current return value expires after 0.5 seconds without valid evidence.

PlaceStore.measuredFurnitureHistory returns dated category-labelled original RoomPlan measurements. It never labels a chair as the user's chair, proves a movable object is still there, or allows remembered geometry to prove clearance. Image-category/depth samples remain unvalidated physical evidence; the app's object-guidance gate must remain off.

## Integration and acceptance

NavigationModel creates a new run UUID, calls beginWorldMapRecovery for the exact saved place and uses its returned map as initialWorldMap. Feed every matching/recognized-place ARFrame through observeWorldMapRecovery, including limited(.relocalizing) frames before depth becomes available. Reset on actual run restart/stop/background/tracking loss, not on an unrelated dialogue-goal change. Read currentWorldFrame only with that run UUID and current uptime. Cache original furniture history by immutable frame revision, never read files in every frame callback.

Executed 11/11 SavedWorldFrameTests on Linux with the existing Swift 6.4.1 toolchain (two compiler jobs, isolated writable cache and scratch paths). They cover artifact identities, relocalization sequence, same-scene ordinary tracking rejection, anchor/mapping gaps, session changes, timing, reset and dated category records. PlaceStore passes Swift frontend syntax parsing; this does not resolve Apple APIs. Native ARKit/RoomPlan/CryptoKit integration still needs Apple SDK typechecking and real-device tests, especially same-looking rooms, changed lighting, new-day recovery, yaw/origin resets, wrong artifacts, missing anchors and drift. Unit/source checks do not validate child mobility or safe pickup.

Asset inventory for this checkout: no `.mlmodel`, compiled `.mlmodelc`, `.mlpackage`, `.onnx` or `.tflite` assets were found below `ios/`. Vision's built-in APIs remain available according to device/OS support; the optional general-object Detector model is not supplied by this bridge. No model was downloaded.
