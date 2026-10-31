# Linux serial supervisor proposal — NOT RUN

Root review and explicit admission required. This separate packet does not modify the six-file candidate freeze. Existing `/usr/bin/c++` resolves to GCC 14.2.0 (Debian 14.2.0-19); compiler existence/version and backend paths were queried, but **no compile or native payload ran**. `RUN_PINS.json` freezes command, candidate/dependency source hashes and selected installed compiler/backends/UBSan binaries. Standard library headers and other dynamic libraries remain host dependencies, not a hermetic sysroot.

## Reuse and modifications

Process-group termination, procfs RSS sum and one-core affinity patterns come from published `research/rtabmap-same-data-benchmark-20261028/completed-stage-1823/guard.py`; inspected source was not run. That guard has task-specific paths, a historical fixed deadline, no aggregate CPU budget and a larger resource allowance, so copying it unchanged would be incorrect. This minimal standard-library adapter adds robust `/proc/PID/stat` parsing, aggregate compiler+test CPU/wall accounting, source pins, unique retained output, failure receipts, per-process CPU/file-size backstops, no retry, and SIGTERM/HUP cleanup. These additions are **new unexecuted code**, not inherited validated guard behavior.

One CPU affinity is inherited by compiler descendants and test. Compiler and test execute serially. Aggregate limits: 60 CPU seconds including supervisor, 120 elapsed seconds including admission checks, 512MiB **observed aggregate RSS** including supervisor, 10MiB aggregate attempt files with 128KiB receipt reserve. RSS/output sampling is every20ms; this is not a hard kernel RSS sandbox and between-sample overshoot is possible. Child `ru_maxrss` catches some fast-exit peaks but is not simultaneous aggregate RSS proof. CPU is sampled from live process-group self+reaped-child times plus completed-child/supervisor rusage; final checks retain fast-exit evidence. Parent external SIGKILL cannot run cleanup; no hostile process escape defense is claimed.

Failure/nonzero/limit stops the whole group and prevents comparison/retry. Existing `attempt-001` is never reused. Root must archive/checkpoint failure evidence and review changed source before any later attempt. Output is local only; no network, install, app policy mutation or activation is in the runner. A zero exit would only qualify this authored subset, not Apple/native API adoption or navigation.

## Proposed invocation (DO NOT RUN before admission)

From repository root, after independently verifying exact published commit and `RUN_PINS.json`:

```
python3 research/single-span-heightfield-run-proposal-20261029/run_once.py --admitted-source-commit <exact-admitted-HEAD>
```

Root must review guard logic, frozen command, toolchain pins, candidate independent review and limit adequacy first. No automatic retry. Source defects or changed pins require a new checkpoint. No full dependency/toolchain hermeticity is claimed.

## Root-review hardening (still NOT RUN)

Active output inventory uses descriptor-relative bounded traversal (4096 entries, depth8), no-follow opens and inode checks. Only active ENOENT disappearance is tolerated; symlinks, nonregular files and every other error refuse. After group retirement, two strict hashed inventories must match. Group retirement is observed after kill/reap; unexpected members after leader exit fail rather than silently qualifying. Exact input pins are verified again on success and failure; the compiled executable SHA-256 is saved and checked after comparison. Receipt size is capped at128KiB with a minimal failure receipt on overflow. This does not protect against a malicious toolchain intentionally escaping its process group.
