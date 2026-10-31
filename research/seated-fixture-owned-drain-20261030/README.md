# Seated fixture-owned admission after real full-controller drain

Isolated follow-on to the reviewed94 source; not part of that frozen publication.
No production controller, worker, priority, dependency, workflow or deadline changes.

## Demonstrated failure and limited diagnosis

Exact source `ff0f50df695bfa48fd72697858c574fda653dc4e`, Apple run41096090593/job124202100531: diagnostics build passed, seated command exited65, and the exact21 synthetic cases were13 passed/8 failed. All4 collision-bridge cases passed. The27 failure records are not27 failing cases. The [original failed Apple job](https://github.com/mischa23v/blind/actions/runs/41096090593/job/124202100531) remains the historical failure evidence; this follow-on does not replace it.

The held-optional-render fixture is identifiable by the unique `controller_drain_wait_finished` call site in the hash-matched ff0 fixture, not by assumed print order. Owner `79FE92A0-BACE-450F-81CE-1FF3A02AD029` returned from that cleanup wait while its native build was still running. Its recorded native build interval was6078–135777ms owner-relative (129699ms wall,81426us matched-thread CPU); discard was requested13803ms and acknowledged136602ms. Four other source callbacks returned stale after14.3–112.4seconds. Metadata does not explicitly bind every random owner ID to a case, and does not establish a QoS, deadlock or computation cause.

native75's process-static serial queue means an unfinished owner can delay later source reads. The Seated fixture already waited asynchronously during cleanup, but an expired cleanup wait did not close admission across subsequent XCTestCase instances. This packet closes that demonstrated isolation hole. It does not cure the original worker delay or retroactively turn a failed deadline into a pass.

The prior reviewed86 Classification fixture repair is family-local. It does not protect Seated owners. The new normal-owner connection is also a separate path, not a fix for the eight old Seated failures.

## Narrow repair

- A small locked, test-only shared reservation is acquired before a Seated fixture backend or actual-session controller is constructed. An occupied reservation throws `previousControllerNotDrained`; the test fails rather than skips, queues new native work, retries, or waits a longer deadline.
- Release occurs only from the exact controller's `onStopped` callback, after the existing native/source/render/status/route/collision/restoration drain checks. The native-only callback does not release admission. Foreign, duplicate and old tokens cannot release another owner.
- A constructor that admitted no native work releases only its own reservation. If a real ingress was created but fixture geometry admission fails, its actual `stopAndDiscard` callback releases the reservation; an elapsed timeout cannot do so.
- Both actual-session lifecycle tests now register independent asynchronous teardown immediately after construction. Existing fixture teardowns remain; every original functional assertion and original10-second timeout is retained.
- The existing held-renderer lifecycle case now attempts a real second fixture backend after native discard but before the first renderer is released. It must receive the exact admission failure before any second native work is queued. After full controller completion, reservation succeeds. The existing confirmation case also checks foreign/duplicate/stale tokens with a local gate.

The gate is intentionally only the Seated fixture family. It does not serialize unrelated XCTest families or production callers. A permanently stuck owner keeps later same-family native cases failed; that is a truthful blocker, not a successful recovery or safe-use claim.

## Verification and integration

Portable source controls pass53 contracts and reject14 source mutations. They hash-normalize all17 original projection test bodies to the ff0 source, and preserve the backend stop/drain, source, query and timing helpers exactly. No new test identity was added; the original21 cases (and the reviewed26-case focus including5 normal-owner cases) remain unchanged. Strict collector source verification accepts this fixture.

The new native held-owner regression is authored, not executed. This Linux executor has no Swift compiler/Apple SDK; no installs, containers or Apple build were attempted. Original native worker-delay and lifecycle failures remain open pending an exact-source Apple run.

Before publication, root should compose this packet as a new additive reverse layer after reviewed94, update current integrated/bench pins, run strict source/roundtrip controls and preserve all frozen historical layers and failed receipts. No fixture outcome, timer or full-controller-drain claim may be inferred from these source controls alone.
