# Refined one-shot phase diagnostic — Apple execution pending

This reviewed harness revision is published for a new one-shot Apple diagnostic. The previous run's results and interpretation remain unchanged; no result is claimed for this revision before execution.

Copying these files into the real diagnostic directory would be a new reviewed
harness revision. It retains the source/toolchain pin, one test, 10-second wait,
assertions, `.utility` queue, 256-event limit and subprocess budgets. It is not a fix.

## New discrimination

- `drain.enter` uses a per-worker random diagnostic owner UUID. `slot.lock.before`
  and `slot.lock.acquired` capture timestamps around production lock acquisition.
  Both are printed **after unlocking**, never while holding the production lock.
  Captured uptime, not printed sequence, governs those two events. Consecutive
  owner-scoped events distinguish worker dispatch from lock acquisition before
  `job.taken` establishes the actual request token.
- A synchronous `preparing` wrapper sets/restores a diagnostic-only thread-local
  request token. Nested file/decoder events now correlate with the correct request,
  avoiding confusion with concurrent app-startup operations. The extra Foundation
  thread-dictionary access itself can perturb cold-start timing; no benchmark claim.
- File open, seek, bounded read, prior read and preview decode/validation boundaries
  distinguish blocked read/preparation from queue admission and JSON work.
- File/decoder `return` means the scope exited, including throwing; it is not a
  success marker. Actual success still requires original XCTest success.

## Generated lockfile policy

`resolution.py` reads only the exact Xcode-generated Package.resolved path, rejects
symlinks, nonregular files, sizes >64KiB, duplicate JSON keys, unknown schema,
additional packages, nonpublic/unexpected locations, version/revision mismatch.
Only public GRDB 7.11.1 at existing recorded revision
`b83108d10f42680d78f23fe4d4d80fc88dab3212` is accepted. Rejected content is never
retained; only a reason and, where bounded, byte count/hash are recorded.

The runner captures sanitized resolution records before build, after each command,
and at exit. It retains *all* post-instrumentation deltas. Only an initially absent,
exactly validated resolution file with matching hash and mode 0644 can be separately
classified as expected generated metadata. Every other delta still fails integrity.
Exact instrumented-state equality and equality except validated generated metadata
are separate fields. No blanket untracked-file exception is introduced. The current
run's unknown lockfile is not retroactively accepted.

## Checks performed

`verify.py /path/to/blind` passes Python AST, pinned-source exact anchors, four-file
scope, preserved timeout/assertion/QoS/dispatch counts, and atomic rejection of
repeat application/source drift. `verify_resolution.py` passes known-pin acceptance,
seven invalid JSON/pin/size cases and symlink rejection. Native Swift compilation
and actual Apple timing remain **not run**. Independent review required before
publishing or executing this draft.

Independent static review also passed both verification scripts and found no
blocking issue. One interpretation caveat remains: `slot.lock.before` is emitted
only after acquisition/unlock. A permanently blocked acquisition leaves
`drain.enter` without a slot timestamp pair; missing slot markers do not prove
that lock acquisition was never attempted. Avoid printing while holding or waiting
on the production lock merely to fill that gap. Apple compilation/runtime remains
unverified.
