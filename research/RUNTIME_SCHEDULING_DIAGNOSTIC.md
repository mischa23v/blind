# Runtime scheduling phase diagnostic

## Established prior result

Fixed-five run40211289727 at63afd5d960f87ec63a109c1a70fc8bad9b4ec39b completed all attempts: first11/17passed with6failures; next four17/17passed each; zero skips. Final job correctly failed. This is preserved, not relabelled by later success.

The retained failure windows show fake storage returning in tens of microseconds, then no publication for the unchanged3-second bound. One empty restore waited2.739s; a subsequent map preparation timed out after4.214s. Another empty restore read returned at610.908710 but remained loading after3.004s. This narrows the delay after IO but does not separate detached admission/work from main-actor resumption.

## New instrumentation

ConnectedJourneyRuntime has an internal DEBUG-only optional Sendable callback, nil by default. Only the hosted fixture sets it; all eight runtime constructions (including held reads and restored instances) do so before restore/install. Release strips the hook entirely. No global telemetry, stored payload, goal, map geometry or personal data is logged. Records contain synthetic test name, existing operation UUID, phase and monotonic process uptime.

For each operation compare:
- task-queued to task-entered: MainActor task admission.
- read-return (existing IO trace) to restore-read-resumed: resumption after the IO actor.
- detached-queued to detached-begin: detached executor admission.
- detached-begin to detached-end: decoding/catalog computation.
- detached-end to main-resumed (or main-error-resumed): return to main-owner publication.

The empty-store path is especially discriminating: its detached body immediately returns nil, so a long queued/begin or end/resume gap is not JSON work. Large nonempty fixtures may genuinely spend longer in the computation phase. Correlate operation IDs and exact timestamps rather than assuming one cause for all failures.

## Acceptance and limits

No priority, sleep, timeout, state guard, assertion, test count or retry policy changes. The stress script only adds a phase-schema marker to launch the authorized next fixed-five experiment through its exact-path trigger. It still builds once and records every attempt, failing on any failure or invalid/missing/zero/skipped result. Passing later attempts does not erase the prior failure.

26 bounded Node/source/synthetic-shell checks passed; actual changed runtime Debug/Release and hosted test source typechecked with the cached full BlindCore module on Linux. Apple execution is still required. Instrumentation uses synchronous test logging and can perturb scheduling, so it is not device-latency proof. Physical guidance/device/supervised acceptance remains open.
