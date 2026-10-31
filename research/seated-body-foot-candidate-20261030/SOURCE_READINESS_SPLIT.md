# Source readiness must not wait for an optional picture

**Reviewed source correction, not natively executed yet.** Root applied the exact ten reviewed files from the isolated proposal after checking every before/after hash. The isolated proposal and earlier Apple failure evidence remain unchanged. Publication parent is `e3edd6beebc4d1f1f6d113d2792f3a0d7a59aaa9`; its relevant source matches the pinned `276b1c522bd5ff4ff26df23ba83a7728bdce3df9` before-bytes. `SOURCE_READINESS_FILES.json` records this checkpoint; the additive integrated source layer preserves historical bytes. Root owns publication and Apple execution.

## Evidence and actual correction

On Apple source561, the new source stages showed native source-worker work around one millisecond, source callbacks after roughly1.921s and0.516s, and immediate main delivery. `render_begin` appeared but `render_end` had not arrived within the original ten-second scene admission wait. Thus native source was available, but the controller stored its usable snapshot only after optional SceneKit construction. That incorrectly prevented a strict native query before a picture existed. This evidence does not prove an illegal background API, permanent render deadlock, bad geometry or a fixed SceneKit implementation.

The correction assigns the actual immutable source at its guarded callback, before optional rendering. All epoch/stopped/tracking/current-source checks remain. Query admission retains source completeness, unknown-coverage, strict expectedSource atomic gate and capture/declaration validation. After a query, a fresh exact matching post-query session/generation/revision is still required before coordinate/association receipts become available. No source/route/physical authority is fabricated.

Source-request and render ownership are separate. One active render plus one latest coalesced immutable source is bounded; replacing the pending slot releases the superseded value. A renderer can consume a current source but cannot overwrite authoritative snapshot or route metadata. Its display result rechecks epoch, owner, tracking and the exact current source revision. Retired and newly admitted sources immediately erase any old picture/bounds and show an explicit retired/pending label, even while a renderer remains held. Tracking loss retires the controller after initial tracking admission, independently of whether any picture was produced.

The optional SceneKit implementation is unchanged and remains under its existing acceptance tests. No QoS, retries, native deadlines or geometry algorithm changes are proposed. A failed or pending picture stays visibly separate; it is not reported as a working visualization.

## Ownership and diagnostic fidelity

Stop still waits for real native drain **and** source, render, status and query callback stacks. The serial render barrier remains; active render work is not declared disposed merely because native storage drained. A test-only acknowledgment method is available only for the injected backend after its real stop/discard callback; it does not clear pending display/source/query flags.

The test backend now delivers a stale refusal to an actually held completion on stop, and rejects late native results after stop, matching the production owner fence. Previously dropping that completion could leave controller `routePending` true forever in a test. No route is synthesized and no success replaces a failure.

A scalar-only recorder is retained through delayed rendering instead of retaining the backend/native owner or losing late events when its weak reference disappears. Each source request freezes its own ordinal and monotonic start time. Later source requests cannot relabel earlier queued render events. Existing record caps and closed log grammar are unchanged; no imagery, geometry or private identities are logged.

## Tests prepared

All original twelve test names and their actual SceneKit scene/route assertions remain. Their teardown now awaits full controller ownership release as well as the real backend native acknowledgment. A visual failure is still a failure; the collector still requires every selected test.

The separate thirteenth fixture, `testActualSourceAndStrictQueryCompleteWhileOptionalRenderIsHeld`, deliberately holds the existing render worker. It uses the actual owned classified floor → existing ingress → real strict native query → actual post-query source association. It asserts coordinate/endpoint metadata can complete while the optional scene is nil/render pending; no physical authority is issued. After stop, native drain alone must not finish ownership release until the held renderer is released. Missing source fails without a futile route request. All waits remain ten seconds.

The collector retains the exact twelve prior methods plus this one, strict source/log/count/command-exit checks, and the same existing class selection and diagnostic flags. CI author ran **35 lightweight collector controls** successfully. These controls do not run the new Swift fixture, native planner or SceneKit. The additive layer reverses seven previous files byte-for-byte and preserves all earlier native failures and pins. No Apple/native test was run for this proposal.

## Not claimed

This does not fix or approve the optional SceneKit rendering path, prove real-room navigation, eliminate sensor gaps, approve child testing, or grant physical guidance. The separate collision-layer proposal remains isolated and must be rebased after this correction is reviewed. Its audit should likewise consume matched source/route data independently of optional pictures.
