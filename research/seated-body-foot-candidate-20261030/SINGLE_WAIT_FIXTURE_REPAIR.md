# Single-wait XCTest fixture correction

Source review found the rejection loop and held-render readiness fixture each awaited their owner-drained XCTest expectation in both the body and teardown. XCTest expectations must not be waited upon twice.

Teardown remains the sole waiter of those expectations. The body now waits on a fresh predicate observing `stopped`, set only by the existing actual full-controller `onStopped` callback. Native drain, renderer drain and all ten-second limits remain unchanged. The existing happy fixture only waited in teardown and is unchanged. No app behavior or test names changed; the exact thirteen-case collection remains intact.

This is a source correction, not a native pass. Published db2 readiness and earlier failing Apple runs remain preserved by an additive reversible provenance layer. No native build or CI execution was performed for this correction by the author.
