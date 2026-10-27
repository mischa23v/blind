# Buffered two-arm IO comparison — actual terminal evidence

Run 40564108627, harness 1c53f27b2a3b9497bec269af1fd9a843d6fe7600,
source e9e18d15fe1fdac1ff1487b3c2a8a2e731607427. No reruns.

| Evidence | utility | userInitiated |
|---|---|---|
| Preflight / app build | passed / passed | passed / passed |
| Actual original focused XCTest | failed once | passed once, zero failures |
| Test command | 360s outer timeout, -9 | passed, exit 0 |
| Buffered snapshot | 55 retained / 0 drops / complete | 91 retained / 0 drops / complete |
| Fixture submit→worker entry | 3.438s | 0.396ms |
| Fixture prior-file open interval | ≥14.252s, right-censored at close | 0.103ms, threw, prior-read recovered |
| Fixture submit→completion | no completion by snapshot | 1.897ms |
| Actual wait elapsed (nominal timeout 10s) | 17.690s | 2.151ms |
| Unintended source changes | none | none |
| Simulator cleanup | shutdown timed out; delete 0 | shutdown 149; delete 0 |

These are **wall intervals from buffered observer boundaries**, not CPU/syscall time.
Utility's lock acquisition was ~0.67 microseconds. Its two unrelated startup opens
threw after ~4.322s and ~9.075s. Utility therefore reached actual test execution and
observer flush: this was neither an observer compile failure nor solely simulator
boot failure. The original expectation failed and XCTUnwrap found nil before the
outer command timeout. userInitiated emitted **TEST SUCCEEDED**; no failed utility
result is hidden by that pass. Only the one selected test is covered.

Both ZIP hashes were checked against GitHub artifact digests and originals retained.
Both arms have identical source/toolchain/helper provenance and distinct newly created
simulators. Local regeneration of each disposable instrumentation matches all four
actual file hashes. The declared treatment differs by exactly one queue-QoS line.
GRDB-generated metadata passed strict exact-pin checks in both arms.

## Conclusion / limits

Severe progress latency persists without synchronous live logging in utility, so that
logging was not the sole cause. The opposite result with userInitiated is actionable
support for reviewing that minimal QoS candidate for explicit user-requested loading.
It is not a proof of QoS causation: one independent fresh sample per arm does not
control host contention/cold-start conditions. Do not infer a Foundation defect,
deadlock, pure filesystem latency, general performance guarantee, broader regression
pass or physical navigation safety. Neither production code nor timers were changed.

The predeclared comparison is terminal; stop collecting and review this evidence.
No hidden rerun, new probe, storage precheck/bypass, rewrite or timeout increase was
performed. Late utility operations after snapshot close are censored, not known to
have completed or remained blocked forever. Cleanup codes alone do not explain the
selected test's behavior.
