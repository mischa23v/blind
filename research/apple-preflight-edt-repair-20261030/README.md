# Apple preflight and historical EDT provenance repairs

**Source-only checkpoint. No native success is claimed.** The published `7bb0532073b541fe86dd6dec579e0927ab072eab` failures remain evidence: the Apple default-project preflight rejected the deliberately test-only oracle flag before compilation; EDT refused changed native source against old pins before native execution.

## Narrow fixes

- The default-project guard now checks the actual plutil JSON target/configuration graph. Only the exact `BLIND_COLLISION_ORACLE_TESTS` value in the real hosted `BlindAssistTests` Debug/Release configurations is allowed. App/UI targets, other flags, optional backend/model strings, orphan/shared configurations and altered host associations still refuse. This does not enable the collision oracle in ordinary app or Release app builds.
- The EDT workflow now invokes the separately labelled historical source-view comparator. All 58 original inputs are verified: 55 unchanged checkout inputs and three explicitly pinned historical copies. Material current native changes are not accepted as historical code. Original controls, native requests, assertions, source pins and limits remain; results concern the historical comparator, not the current app.
- An additive outer provenance layer restores the exact failed 7bb shell, workflow and bench inputs and removes the new repair files before earlier bridge/source reversals. Original Apple/EDT failures and old baseline receipts are not overwritten.

## Checks and limits

55 portable default-project controls and 13 historical-view controls passed. Exact reversal, current input hashes, Python syntax and shell syntax were checked. These are not Swift compilation, SceneKit execution, iPhone accuracy or navigation evidence. The integrated eighteen hosted cases still retain all thirteen preceding cases. Actual optional SceneKit rendering delay remains unresolved.

No app, geometry, route, collision algorithm, test deadline, QoS, permissions or physical authority changed. Root owns publication and later Apple runs. Artifact uploads remain disabled by default for the triggered Apple and EDT lanes.
