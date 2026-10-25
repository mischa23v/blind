# Task-priority observation, not a scheduling repair

The buffered d75ec3 main run 40225192788 retained four runtime failures, 125 hosted passes and six model skips. Removing diagnostic stdout from callbacks did not eliminate intermittency. No prior failure is reclassified as a pass.

One retained catalog operation waited 3.064 seconds before detached execution, ran for 139 milliseconds, and resumed its MainActor owner roughly 0.117 milliseconds later. Its wait returned after 21.298 seconds despite eventual fulfillment. Another empty restore read took only microseconds and queued detached work, but no detached-begin event occurred before the three-second failure/teardown. Buffered records had zero drops; post-teardown events were explicitly uncaptured. These observations do not establish a sole cause.

## Existing scheduling

Restore and catalog preparation create inherited-priority owner tasks and immediately await explicit utility-priority detached work. Apple's [Task.value documentation](https://developer.apple.com/documentation/swift/task/value-60t02) and [TaskPriority documentation](https://developer.apple.com/documentation/swift/taskpriority) explain priority elevation when higher-priority tasks wait for a value. Therefore explicit utility priority does not prove work stays at utility priority. Scheduling semantics remain executor-dependent, not deadlines.

Restore/catalog work gates loading and map validity. Persistence is separately coalesced to one active plus one latest pending write through an IO actor, but durability gates output, so it is not entirely noncritical background work. No production task, actor, priority or IO behavior changes here.

## Test-only measurement

The existing synchronous phase collector, IO trace and wait records now append numeric `Task.currentPriority.rawValue` plus a `hasTask` boolean. `withUnsafeCurrentTask` returns only that boolean; its task handle never escapes. Apple documents that [currentPriority outside a task](https://developer.apple.com/documentation/swift/task/currentpriority) is a system approximation, which is why task presence is explicit. This is not OS-thread QoS measurement.

Immediately after the existing `done.fulfill()`, append a buffered monotonic timestamp labeled by test and wait line. This separates publication/fulfillment from the time awaiting XCTest resumes. No new task hop, polling, stdout in callbacks, virtual clock, sleep or timeout change is introduced. All original assertions, 17 test names and the three-second bound are preserved; output still flushes only after the test body.

If delayed detached-begin/end records already match the waiting task's priority, a priority-escalation-only explanation is weakened. If the priorities differ, inspect task inheritance and timing before proposing changes; a begin event can precede escalation. The measurement cannot prove scheduler fairness or physical-device response time. It will ride a normal main CI run, not an unchanged stress retry.
