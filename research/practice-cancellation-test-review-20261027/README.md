# Practice cancellation test split — source proposal only

2026-10-27 22:25 UTC. No native test executed, workflow activated, duration/timeout changed or app source modified by this increment. Timing reliability remains unverified until actual native execution is separately authorized.

## Evidence

Run40583132225/job122468622211, commit38ac458c70a236f6a75d05b572724c1996ece57a, `PRACTICE_TRACE`:

- Home-practice event synthesized at22.66s; XCTest waited for idle until83.01s and reported no idle notification.
- Companion-reply queries consumed88.46–124.81s.
- Navigation back to camera synthesized247.92s; simulation banner first queried248.95s, approximately226s after start tap.
- Line109 failed before `end-practice` was tapped. `continueAfterFailure=false` prevents the subsequent cancellation steps.
- `NavigationModel.startSimulation()` schedules an unchanged120-second timer calling `endPractice()`. Natural expiry is strongly consistent with this timing, but no timer-fire event was recorded. This is not proof of a broken stop action or failed tap.
- Practice's existing0.1s main/common-runloop watchdog publishes/demoFrames; repeated UI updates could contribute to quiescence waits. This cause is not established. The AVAudioSession main-thread warning occurs in many tests and is not uniquely causal evidence.

## Minimal proposed repair

Separate the original home-practice→companion reachability assertions into `testPracticeNavigationRemainsReachable`. Keep the original `testPracticeIsAnnouncedAndCanStop` identifier for the cancellation test, preserving existing bounded trace extraction. Each XCTest receives a fresh app launch from existing setup.

Cancellation opens camera once, requires the original camera-off state, then uses existing same-screen `start-simulation`. It requires the original active SIMULATION banner, reveals and explicitly taps existing `end-practice`, and checks the original absent-banner and Start-monitoring postconditions.

A monotonic timestamp is captured **before** synthesizing Start. It conservatively upper-bounds actual practice lifetime. Both just-before-End and after all postconditions require elapsed time below90seconds—30seconds before production's unchanged120s expiry. The interval check is not a longer timeout or an alternative success path: slow automation fails, never accepts natural expiry as proof of Stop. No mock timer, private XCTest quiescence override, alternate assertion, endpoint opt-in or retry was added.

The new reachability test does not claim verified audible speech. The cancellation test's positive timing evidence print is produced only after its explicit tap and original postconditions. A failure remains actionable evidence; no passing run is claimed from source review.

## Review correction and explicit coverage trade-off (22:37 UTC)

The smoke test is now named `testPracticeNavigationRemainsReachable`, and requires the companion reply to exist **and be hittable**. It does not prove audible announcement. The old delayed home-practice→camera→active-banner path is no longer a UI assertion; active-mode and explicit-stop assertions belong to the separate fresh camera-local test. This is a deliberate coverage split, **not identical end-to-end coverage**.

`check_source.py` plus frozen `SOURCE_CONTRACT.json` provide focused exact-source contracts: home practice synchronously calls `startSimulation()` before selecting companion; camera Start calls that same function; its approved body directly sets simulation/running before scheduling the unchanged120s expiry. Full approved-body comparison rejects inserted/deferred/dead calls, rather than accepting any occurrence of a method name. Eleven authored mutation cases cover removed, deferred, dead and reordered calls/state plus changed expiry. These narrow contracts are intentionally brittle to future source changes; review rather than regenerate expected text to conceal a change. They are not a general Swift semantic proof or a substitute for runtime UI integration.

No contract/mutation execution or native execution was performed for this revision. The cancellation test and both90s monotonic guards are unchanged. No app source, timer, helper, endpoint or workflow changes were made.

## Publication guard refinement (22:42 UTC)

The `PRACTICE_CANCEL` witness now prints only **after** the final90s assertion passes. The source checker also enforces timestamp-before-Start, active banner, pre-End90s guard, explicit End tap, original postconditions, final90s guard, then witness ordering. Eight authored mutations remove End/active-state/elapsed guards, raise the limit, move the timestamp, move the witness early or remove the stopped-banner check.

Authorized bounded Python source checks executed successfully: both source contracts pass;11 action/lifecycle mutations and8 cancellation-order mutations were rejected. No Swift/native UI test executed, no workflow enabled, and no native-pass or timing-reliability claim follows.
