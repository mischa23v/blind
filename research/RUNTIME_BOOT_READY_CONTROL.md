# Single boot-ready simulator / cold-application control

This diagnostic is not a production repair and does not relax the existing three-second runtime assertions.

## Why this control

Two previous fixed-five experiments each retained a failing first attempt and four passing later attempts. The phase-enabled experiment at ecddcbb5b7ccac7cb6deeadeaef58b66c3112a98 (run 40214250469) failed all 17 tests on attempt one; each later attempt passed 17. Its retained phase windows show delays in MainActor entry/resumption, detached admission, and IO actor admission, not only computation. Synchronous diagnostic printing can perturb scheduling, so these are not unbiased device latency measurements.

The existing preflight only enumerates and selects an available simulator. The first test invocation delegates boot to Xcode. This control explicitly separates simulator boot/readiness from the first application/test-host launch.

## Protocol

- A fresh disposable hosted runner, the installed iOS 27.0 runtime and iPhone 18 Pro Max device type only. No assets or runtimes downloaded.
- Create one owned simulator UUID. Record its initial Shutdown state; build for testing once, then verify it is still Shutdown.
- Capture installed `xcrun simctl help bootstatus` locally. Measure `xcrun simctl bootstatus UUID -b` with a monotonic clock and a fixed 180-second infrastructure deadline. Boot failure/deadline is an infrastructure failure with zero tests run, never a fallback.
- Immediately execute the unchanged 17-test ConnectedJourneyRuntimeTests class once. No application prelaunch, warmup test, sleep, priority alteration, or timeout/assertion change. The existing test-only phase recorder stays enabled.
- Preserve first failure windows and exact xcresult counts. Missing/malformed results, skips, other-than-17 counts, nonzero test exit, extraction failure, or owned-device deletion failure cannot pass the control.
- Cleanup targets only the UUID created by this invocation. Timed-out command process groups are stopped before cleanup.
- No retry-until-green and no additional unchanged fixed-five experiments. Own concurrency, public-repository guard, manual dispatch, and automatic trigger only when this workflow or standalone script changes.

## Interpretation decided before execution

A pass would show that this single boot-ready-simulator/cold-app run satisfied the existing bounds. It would support (not prove) startup overlap as a contributor. It would not repair the prior failures, prove a unique cause, or establish cold physical-iPhone responsiveness. A failure would show that explicit simulator readiness is insufficient. Either result remains confounded by host differences, fresh-simulator state/caches, app first-launch work, and observer overhead. Boot duration must be reported separately, not hidden in a warmup.

## Authoritative command/concurrency guidance

Apple's [Xcode command-line tool reference](https://developer.apple.com/documentation/xcode/xcode-command-line-tool-reference) documents `simctl` and directs users to installed command help. The hosted control captures that help for the actual selected Xcode before using bootstatus. Apple documents [asynchronous XCTest expectations](https://developer.apple.com/documentation/xctest/asynchronous-tests-and-expectations) and the concurrency-safe [`fulfillment` alternative](https://developer.apple.com/documentation/xctest/xctwaiter/fulfillment(of:timeout:enforceorder:)-swift.method). The existing runtime tests already use async fulfillment rather than blocking main-actor waits; this control changes neither API nor bounds.

## Local evidence and pending gate

Five bounded synthetic Python tests cover the one-attempt sequence, six final-failure cases, build/boot failures, a real subprocess deadline, exact workflow trigger scope, and no warmup. They are shell/orchestration witnesses, not Apple runtime evidence. Independent review is required before publication; the single actual Apple control remains pending publication and execution.
