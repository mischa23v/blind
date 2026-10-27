# Navigation ordering and contract repair — 2026-10-27

These are portable **source-contract** results, not ARKit execution, Apple build,
resource measurement, live hazard coverage or physical-readiness evidence.

## Exact baseline attribution

The historical `app-integration.patch` was reversed only in a disposable copy of
NavigationModel. The recovered SHA-256 exactly matched the pinned preintegration
`6193f6c5ee09e5ac572532fff7fc4f6ea6ae31aeec1b24957eb380ed6fe07d9a`.
The original three suites passed **36/41** there, versus **35/41** on published
stage-85 NavigationModel `06305bbb…52307`.

| Original failing contract | Attribution |
| --- | --- |
| Foreground contextual work follows urgent detector | Baseline test searched declaration order after detector extraction into `processDepthHazards`, instead of checking its synchronous callsite and body. |
| Scene offer follows urgent detector | Same baseline stale assumption. |
| Adversarial urgent-detector contract | Same stale assertion prevented its mutation checks from starting. |
| Privacy/session RGB invalidation | Baseline global cardinality was stale: five valid preservation sites versus the expected three. |
| Connected-issuer retirement before throttle | Already failed baseline at the stale helper/reader ordering assertion. Stage 85 also introduced an earlier failure by putting diagnostics before the critical retirement prefix. A simple failed-test-count delta hides this additional ordering regression. |
| Room-scan cancellation prefix | Newly failed under stage 85: diagnostic stop preceded the native-observation and scan-confirmation cancellation prefix. |

The `5 !== 3` failure counted **`invalidatePerceptionWork(preserveRGBHistoryWork:
true)`**, not `.stop()` calls. Both exact versions contain the main frame's
missing-depth and tracking-loss branches, recovery's corresponding two branches,
and `publish`'s nonurgent independently fresh-RGB branch. The scene-stop/history-
deletion count was not failing. Increasing a global expected number would not
protect the privacy boundary, so the replacement validates each guarded scope
and rejects preservation outside those scopes.

## Minimal source change

[`../critical-order.patch`](../critical-order.patch) is a separate incremental
layer against published stage 85. The historical integration patch is unchanged.

- Camera stop: native observations, scan confirmation, body warning and observed
  scene retire before optional diagnostics; diagnostics still stop before pause.
- Raw frame loss: selected-localization, journey, native observation, scene, map
  and reading authority retire before diagnostics, registration and throttle.
- Interruption: body/native/scene retirement precedes diagnostics and pause.
- Session error: existing invalidations and hazard publication precede diagnostics,
  which still stop before recovery.

No session-identity, queue, geometry-copy, begin-epoch, flag, default-off or runtime
activation policy changed.

## Strengthened contracts and controls

Balanced frame/helper inspection now checks the real synchronous hazard callsite
and exact urgent/nonurgent detector assignments. Mutations remove, defer, wrap,
conditionally bypass or reorder calls and assignments. Lifecycle prefixes remain
strict; the frame contract accepts only the exact fenced diagnostic hook **after**
retirement, not an arbitrary optional prefix. Additional mutations displace or
defer diagnostics/cancellation and leak RGB preservation into privacy/session
paths or weaken depth/tracking/freshness guards.

| Source / contracts | Passed | Failed |
| --- | ---: | ---: |
| Exact preintegration / original | 36 | 5 |
| Published stage 85 / original | 35 | 6 |
| Published stage 85 / revised, negative control | 40 | 3 |
| Repaired / revised | **43** | **0** |

The negative control still rejects the original stage-85 cancellation, optional
lifecycle and raw-authority ordering. All other stale contracts are repaired
without modifying production detector or RGB-preservation behavior. Final run
has zero skips. `git diff --check` passed for the changed source and existing test
files. [RESULT.json](RESULT.json) pins the changed inputs and preserved logs.

The integrated two-layer reversal/checker and exact-commit Apple validation are
separate checks; this receipt does not claim them or claim a publication.
