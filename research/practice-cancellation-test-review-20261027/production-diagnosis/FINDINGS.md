# Practice UI failure: production-source diagnosis

Source inspected at the003788a app revision. No production source or test changed by this diagnosis. Native evidence is preserved separately under integrated/evidence/run40598054378.

## Established observations

The fresh Camera-local test synthesized Start at19.91seconds, then XCTest waited for app idle until80.27seconds and reported no idle notification. The first banner query began85.68seconds; snapshot queries retried at122.02 and153.05seconds. It failed at191.970seconds before End tap and without a90-second witness. This is not a false passing Stop result and not proof that an actual user cannot press Stop.

NavigationModel.startWatchdog schedules0.1-second main/common-mode ticks. During simulation each tick calls demoFrame, which unconditionally assigns @Published calibrationProgress, and then publish, which unconditionally assigns @Published detection. After calibration, both values can be identical across repeated generated frames. AssistantToolsView observes the entire NavigationModel, not just these fields. Other model publishers are also forwarded; therefore these two sources are demonstrable unnecessary invalidation candidates, not proof that they are the sole cause.

The test reveals Start in the third Form section, but checks the SIMULATION banner in the first section without scrolling back. The exact screenshot/scroll position at failure was not retained, so offscreen lazy-row materialization is a separate plausible issue rather than a proved cause. End remains in the third section. Changing from the long navigation flow removed neither the idle nor snapshot failure.

## Bounded proposed correction, not implemented or tested

1. In demoFrame only, assign calibrationProgress only when its new value differs. It is generated-practice presentation, not a live observation receipt.
2. In publish compute the continuity-processed nextDetection every tick, then assign detection when !simulation OR nextDetection != detection. This limits deduplication to simulation; live publication remains unchanged. Do not return early: retain all route/freshness revalidation, hazard policy, speech and timing work. Every changed hazard/distance/sector/coverage/reason publishes immediately. Detection already conforms to Equatable.
3. Show an explicit practice-only/no-live-sensors status next to the existing End practice control in its section, with a stable accessibility identifier. Keep the top status too if needed. Verify this visible status before End and its disappearance after End. Preserve actual End tap, camera-off postcondition, both90-second guards and unchanged120-second automatic expiry. This is an accessibility presentation correction, not permission to accept natural expiry.

These are two changes with distinct rationales. If applied together, a passing run would establish repaired interaction but would not isolate which change removed the original failure. Avoid claiming root-cause proof.

## Required checks

- Hosted actual-model publisher test: settled simulated frames still process but do not emit identical detection/progress publications; changing each relevant detection field emits, and live-mode semantics remain unchanged. Do not use a separate fake model as the only proof.
- Source contracts protect no early return, unchanged watchdog cadence/expiry, same detector/continuity calls, every safety/policy call, and both90-second guards. Existing exact-source pins need reviewed overlay history rather than blanket refresh.
- Existing native UI run must show active adjacent practice status, explicit End, stopped status and positive elapsed witness below90seconds. No retries, private XCTest idle bypass, longer waits, skipped assertion or larger production expiry.
- If snapshot/idle failure persists, retain failure and obtain bounded actual main-thread/performance evidence before another speculative change. The AVAudioSession warning appears elsewhere too and is not isolated causal evidence.

## Primary platform references

Apple documents that Published emits in willSet and that ObservedObject-driven views update from the observed object's published changes. Apple also notes that large sequences of short updates can keep SwiftUI active and recommends identifying unnecessary updates. These establish mechanism, not this run's root cause.

- https://developer.apple.com/documentation/combine/published
- https://developer.apple.com/documentation/swiftui/observedobject
- https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance

## Candidate implementation and remaining limits —23:33UTC

The two inline presentation guards and adjacent status are now applied locally with a separate exact reversible NavigationModel patch. No direct `$detection` or `$calibrationProgress` subscriptions were found in production ios/BlindCore/BlindMemory source; this literal audit cannot rule out every dynamic/indirect observer. Real-live detection publication remains unconditional, and no safety routine sits behind the equality guard.

Additional normal-practice tick review: `tickAutomaticRoomRecovery` excludes simulation; retry/expiry/speech paths are gated by outstanding owners; stopped observed-scene has nil snapshot so its revalidate returns; native localization has no candidate and returns; route-output revalidation acts only on a held ticket; observing detection does not announce periodically. The existing broad forwarding of child publishers and asynchronous callbacks remains, so these changes do not guarantee quiescence. All those methods and the watchdog body are byte-equal to the baseline. No broad suppression was introduced.

Two hosted Combine fixtures were authored in the already-built CommunityTests file. They verify that equal detection/progress assignments emit notifications in the platform publisher; they intentionally do not instantiate NavigationModel or prove its runtime behavior. Constructing that full model would change shared store callbacks and access private-memory/sensor dependencies, so no broad test constructor was introduced. Native compilation/execution of those fixtures is pending.

Portable validation:37 integrated exact-layer checks;5 exact baseline-method contracts with16 rejected mutations;11 original action/lifecycle plus13 cancellation/reveal/setup mutations;43 navigation contracts;12 privacy/recovery/handoff contracts;15 practice-layout/audit contracts. Zero failures/skips in these final runs. The first mutation harness draft matched the wrong earlier occurrence for two negative controls; those mutation targets were scoped to the watchdog and Camera monitor, then all16 controls rejected correctly. No production change was made to hide either harness failure.

The visible status is tested for existence and hittability before End, disappearance afterward, plus the unchanged camera-off postcondition and two90-second guards. The original top banner remains; Dynamic Type audit and its failure handling are not suppressed. No current native pass, runtime latency or actual-model notification-count claim follows from these portable checks.

Independent review found a source-evidence weakness in the prior token-only cancellation checker: dead branches, an early return or removing the reveal helper's hittability assertion could retain its tokens. Current Swift contained none of those defects. `CANCELLATION_CONTRACT.json` now freezes the exact reviewed cancellation, reveal and fail-fast setup bodies; the checker also rejects all four counterexamples. This hardens evidence without altering production or weakening the UI requirement. Actual-model subscriber coverage remains pending, not a prerequisite silently claimed complete; current runtime acceptance still requires the existing native UI test and cannot establish root-cause/performance proof alone.

The follow-up independent check also rejected a dead `continueAfterFailure = false` assignment: setup is now frozen exactly and the thirteenth cancellation mutation proves that negative fails. No production setup changed.
