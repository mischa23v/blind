# Explicit J01 same-job model observation lane

Source-only candidate; no Apple build, trusted build receipt, model result, audio,
physical behavior or complete journey has been observed for this layer. Requires
exact frozen NEXT40 (`70cba571bbcf7044299cc93ee7c9fa6b3f99b94b8f17c7667f49d1fe1882cc3d`)
after first74. Neither frozen packet is overwritten by this companion.

## Execution and trust boundary

Root's reviewed publication is the explicit execution point. Only a push to
`mischa23v/blind`'s `codex/recovery-hazard-order-20261027` branch affecting this
workflow, exact J01 tools/hosted fixture or either J01 research packet triggers
the new lane. The job refuses private repositories, forks and pull requests;
uses the standard public `xcode-27` runner and pinned checkout at `github.sha`;
contains no upload, cache, service, runtime/model download or account setup.
Existing normal CI selection and deadlines are unchanged. Generic default
`build-for-testing` has no new compilation flags and still passes the existing
optional-model/backend project guard.

The reviewed runner owns the producer and consumer. It verifies actual checkout
repository/ref/clean HEAD, exact workflow commit SHA, run/attempt/job identity,
and executes a fixed build argv itself, recording its actual exit. An exclusive
`RUNNER_TEMP/blind-j01-RUN-ATTEMPT` contains the fresh receipt and artifacts. No
caller config, downloaded receipt, digest override or external J01/build flags
are accepted. Computing a SHA alone is **not** authentication: trust comes from
the reviewed, authenticated workflow executing that producer. Root must verify
actual run/commit/job and preserved receipt digest before citing a result.
[GitHub documents the workflow/ref/SHA context variables](https://docs.github.com/en/actions/reference/workflows-and-actions/variables).

The attestation checks full selected app/test bundle bytes and descriptor before
and after each script, with actual source checks around it. It does not prove
which binary the OS loaded, model identity/quality or physical correctness.
The reviewed attestation verifier/docs are retained; its portable Git fixture
reads the actual current, exactly pinned helper bytes instead of an implicit
external Git HEAD, with all clean/dirty controls preserved. The wrapper gains a
separately reviewed explicit parent-owned process-group mode: it checks the
actual parent PID and exclusive session/group leadership, keeps xcodebuild in
that group, and lets the parent contain descendants even if the wrapper dies.
Standalone mode retains its separate-session cleanup. The generic
receipt still says it is untrusted until authenticated; this job supplies that
external trust boundary, not a new self-authenticating JSON claim.

## Three exact observations; failure remains failure

REQ-SC02-1, REQ-SC02-3 and REQ-SC02-4 each use a separately created empty installed
iOS 27.0 / iPhone 18 Pro Max simulator, then delete only that owned UUID. No real
capture, microphone, account, external model or physical action is requested.
The test retains its original 20-second final observation and wrapper's total
55-second deadline. A simulator/model unavailable state, native failure,
missing final reply, generation error, timeout, changed source/artifacts or
failed cleanup exits nonzero. There is no retry or substitution with authored
fallback text. Ambiguous creation cannot be relabelled successful cleanup and
withholds later scripts.

A positive `status: observed` means only that the final request has a nonempty
model return and its own exact current, settled, nontruncated accepted-display
receipt, available provider and no observed generation failure or timeout.
Earlier retired/replaced requests may lack replies and remain visible as such.
No semantic score is inferred. `fullJourneyComplete`, `model_drain_acknowledged`,
`runtimeLoadedBinaryVerified`, audio and physical acceptance remain false.
Stopping a process group and deleting a simulator is not a model-drain receipt.

## Bounds and receipts

The job caps at 35 minutes (2 portable, 3 preflight, 28 runner, 1 summary, plus
checkout reserve). The runner's sampled wall budget is 1,560 seconds including
build, with 100 seconds reserved for owned cleanup; build cap 900 seconds / 64
MiB log, each outer wrapper cap 60 seconds / 2 MiB output, simulator tool cap 30
seconds / 4 MiB output (boot observation 120 seconds). Work can be refused before
all scripts finish when the budget is consumed. These are observation/process
bounds, not hard kernel aggregate resource guarantees. Every owned command
process group is killed on exit, including when its leader exited first.

Raw authored-input/model-response/native logs remain runner-temp only and are
not printed or uploaded. Normal job logs and summary contain bounded
`J01_CI_RECEIPT=` JSON: exact scenario/event names, fixed enum categories,
booleans, counts, source/run/job and receipt digests only. A final always-step
reports missing/incomplete status after earlier failure. It does not override
the failing step. Normal logs/summaries are the evidence retrieval path; no
artifact allowance or billing settings are assumed. Public standard runner
compute is free; this is not a claim about any unrelated repository storage.

Portable checks exercise mocked producer/consumer orchestration and adversarial
metadata, not Apple execution. See CI_VALIDATION.json and TRIGGER_AUDIT.json.
