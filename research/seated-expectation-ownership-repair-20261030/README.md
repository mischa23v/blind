# Seated expectation ownership and timing labels

Source repair only; no native rerun or runtime-latency fix is claimed.

## Preserved actual e418 outcome

The selected eighteen-case Apple run at `e418290ac2a70f93c4250bb094091082408f7093` executed: fourteen methods passed, four controller methods failed with twelve failure issues. All four authored independent-collision fixtures passed. That does not establish real-room navigation or device safety. The actual controller failures include source/query/render and owner-drain timeouts, plus separately identified XCTest expectation-registration errors. Those failures are not reclassified as passes.

## Harness-only correction

Four cleanup-only expectations previously created through the test-case factory were reported as unwaited at method exit, even though cleanup explicitly awaited them later. They now use standalone `XCTestExpectation`, explicitly retain `assertForOverFulfill = true`, and still have exactly one awaited teardown owner. All ten-second waits, body predicates, source/query/visual assertions and full-owner drain remain. The audit stage's progress/disposal observers are installed after a real held native result succeeds and before releasing it; a failed source admission cannot register an audit stage that never began. A failed real audit-progress or disposal wait remains a failure.

The actual Apple log is the evidence for this lifecycle behavior. [Swift XCTest's case implementation](https://github.com/swiftlang/swift-corelibs-xctest/blob/main/Sources/XCTest/Public/XCTestCase.swift) separately tracks factory-created expectations; [expectation implementation](https://github.com/swiftlang/swift-corelibs-xctest/blob/main/Sources/XCTest/Public/Asynchronous/XCTestExpectation.swift) documents explicit over-fulfillment checks. These open-source internals are explanatory, not an assertion that Darwin XCTest has identical scheduling.

## Distinct metadata events, not a performance repair

The actual native discard callback now emits `native_discard_acknowledged`. The receipt printed after a bounded controller wait emits `controller_drain_wait_finished`, whether that wait passed or failed. Neither proves full controller disposal; only the existing actual controller completion callback can do that. New code no longer emits `drain_complete`; the parser retains it solely as ambiguous legacy evidence. Missing timestamps remain unknown.

No app scheduling, queue priority, native serialization, geometry, body profile, deadline, collision algorithm or physical authority changed. The e418 native/source delays remain unresolved. An additive reversible source layer preserves the exact failed e418 fixture and original timing grammar before replaying all earlier provenance layers. The exact eighteen-case selection and original failures remain visible.

Portable checks: 47 timing-parser/synthetic-shell controls and 53 exact hosted-collector controls passed (100 total). These do not execute XCTest or repair runtime stalls. The parser replay retained the original e418 timing records and explicitly labelled legacy drain events as ambiguous.
