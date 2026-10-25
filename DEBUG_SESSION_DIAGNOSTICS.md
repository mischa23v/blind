# Debug-only session diagnostics rebuild

2026-10-25. Reconstructed recorder foundation, not recovered original source and not a completed native integration. This increment adds no app UI, history tab, recording button, export, upload or production telemetry.

## What is implemented

- `BlindCore/Sources/BlindCore/DebugSessionLog.swift` exists only inside `#if DEBUG`. Release has no recorder type or implementation. A Debug build alone does not enable it: the developer must supply the exact launch argument `--blind-debug-session-log`.
- `DebugSessionLog.shared` is resolved once per process. Without the argument it is `nil`, does not resolve a log directory, and does no IO. Optional chaining at integration sites prevents evaluation of logging arguments. Within an enabled instance, disabled/stale/over-capacity admission rejects before the lazy detail closure is evaluated or text is serialized. No model, sensor or capture API is part of this class.
- Foundation JSONL files are written on one utility queue in app-private Application Support/BlindDebugSessions. No new database, third-party dependency, cryptography or inference runtime is introduced. Reused platform API: [Apple Foundation FileHandle](https://developer.apple.com/documentation/foundation/filehandle), specifically throwing write, synchronize and close. The project minimums remain Swift tools 5.9, iOS 17 and macOS 13. No Apple implementation is copied; no dependency/license changes were made. Actual SDK compatibility remains unverified here.
- Limits are 8 MiB per session, 32 MiB total retained files, 128 admitted pending events, 8 KiB UTF-8 per text field, 128 bytes per label and 64 KiB per encoded event. A 4 KiB terminal reserve is included in both byte caps. Metadata enumeration is streamed and stops before more than 512 files, including new log/marker, would be retained. Limits stop recording, never silently delete old evidence. Privacy clear is the only deletion path.
- Snapshot construction scans only a bounded UTF-8 prefix before enqueueing. JSON escaping/encoding and file writes stay off the caller. Queue admission does not wait for file IO. The small admission lock is not lock-free; latency, lock contention and working-set claims require measurement on the phone.
- Each record has an opaque session UUID, event UUID, writer-order sequence and monotonic admission timestamp. Concurrent timestamp order can differ from serialized write order. This timestamp is recorder admission, not camera capture, acoustic onset, token generation, or audible delivery time.
- Allowed event kinds separately represent user input, model request, model response chunk/final, tool call/result, output gate, unavailable capability, and speech requested/started/completed/interrupted/rejected. Internal session start/end cannot be submitted by public callers. Request/tool-call/utterance IDs must come from the originating operation. Missing IDs are literally `unbound`, never replaced by the current global request or a guessed match.
- Exact bounded text is retained with explicit `truncated` and `redacted` flags. Counters expose admission, written nonterminal records, dropped events, foreign-session callbacks, truncated/redacted fields, write errors and prior unclean markers. Rejected attempts after recording has stopped do not run the payload or increment loss counters. Returning an event ID means admitted, not durable, spoken, heard, accepted or authoritative.
- Finish stops admission, drains already-admitted work, writes a terminal record with loss counters/reason, synchronizes and closes, then removes that session's zero-byte `.open` marker. Capacity stops use the same terminal path. Partial-write/sync/close failure leaves the marker and exposes an in-memory write error. A missing terminal or surviving `.open` means incomplete/unclean, not a reconstructed successful ending. Killing iOS may prevent any terminal callback; no completeness guarantee is made.

## Privacy boundary

There is no media/biometric/binary field API, network transport, automatic uploader or share action. Never pass raw images/audio, embeddings, face templates, credentials, authentication headers, secret-bearing URLs, arbitrary tool-object dumps, hidden reasoning or private model internals. Log only already-available, intentionally selected diagnostic text at the actual boundary. Do not rerun any model/sensor to fill a log.

Conservative known-secret/media markers replace the whole bounded field and record redaction; they are defense in depth, not proof that arbitrary free text is secret-free. Callers remain responsible for excluding sensitive fields. Initial acceptance must use the developer's own non-secret synthetic inputs, not real child/family data. Any real-data diagnostic use requires an explicitly reviewed privacy decision and retention handling; launch opt-in is not permission to upload anything.

The source requests owner-only POSIX permissions, backup exclusion on Apple platforms and complete file protection on iOS. Existing-folder protection inheritance, locked/unlocked writes, device backup exclusion, simulator/device container retrieval and performance have NOT been verified. These are acceptance gates, not a claim of tested encryption or backup behavior. Protected-storage write failure stops logging rather than weakening protection. The private directory rejects symlink entries and unexpected subdirectories; removal only targets UUID-named `.jsonl`/`.open` files.

`DebugSessionLog.purgeForPrivacyClear` must be called by the existing privacy-clear flow, including launches where recording was not enabled. It immediately fences the active recorder, closes the handle and deletes owned logs asynchronously. Its completion must be checked; a failed deletion is reported, not announced as success. An explicit repeat can retry a failed purge without re-enabling recording; a duplicate while deletion is pending reports unconfirmed success as false rather than adding unbounded work. After clear there is no resume/start API. Only a new process with a fresh explicit launch opt-in may record again. Late callbacks cannot repopulate cleared files. No logs should be retained as a workaround for failed purge.

## Native integration plan, deliberately not claimed implemented

No existing production file was edited in this recorder increment. `NavigationModel`, local model wrappers, tools and speech callbacks currently do NOT call this recorder. App-level privacy clear is therefore also pending. Do not call this foundation a working end-to-end capture feature.

1. Add DEBUG-only startup ownership of `DebugSessionLog.shared` and its `sessionToken`. Keep all references under `#if DEBUG`; do not add user-facing settings or controls. A recorder session is one opted-in launch/capture, not speaker verification or a persistent conversation profile.
2. At accepted typed input and the microphone boundary, emit `userInput` with the actual source. Unverified microphone text must remain `unverifiedMicrophone`, not a verified user instruction. Capture the session token at callback creation, never fetch a new token in an old completion.
3. At each real model request, record only the bounded actual safe textual prompt/messages and actual request UUID. Record returned chunks and final content separately. Never invent unavailable internal context/tool IDs or ask the model to explain its hidden reasoning.
4. In real tool dispatch/results and output gates, record safe textual arguments/results and actual gate outcome/reason, preserving request/tool IDs. A tool result is not a successful physical action, and a passed gate is not speech completion. Mark missing capture/binding explicitly `unavailable`/`unbound` rather than backfilling.
5. At the actual speech engine/VoiceOver admission and completion/interruption callbacks, record the exact attempted text and supplied utterance ID. Do not infer `speechCompleted` from enqueueing, model completion, an empty queue or a guessed substring. Native callback paths without reliable IDs remain unbound. Completion does not prove the user heard or understood it.
6. Call `finish(session:)` for the explicit capture end. Wire the existing privacy clear to the static purge helper and propagate deletion failure, without new UI controls. Reject old callback sessions; do not silently start a second recorder within the cleared launch.

Minimal API shape after a deliberately selected safe text boundary:

```swift
#if DEBUG
if let log = DebugSessionLog.shared {
    let token = log.sessionToken // retain with this operation, not a later callback
    log.record(.outputGate, source: .outputGate, session: token,
               correlation: .init(requestID: actualRequestID)) {
        .init(text: existingSafeOutput, label: actualGateCode)
    }
}
#endif
```

The snippet is guidance, not a claim the placeholders exist or that all native sites are wired. Privacy integration uses `DebugSessionLog.purgeForPrivacyClear { success in ... }`; production callbacks must marshal any UI/state updates onto the correct actor.

## Verification and remaining gates

Executed here on Node v24.22.1:

`node --test --test-concurrency=1 tools/test/debug-session-log.test.mjs`

Result: 13/13 bounded source-contract checks passed, zero skipped. They check compile guards/launch gating, lazy admission, declared bounds, stop policy, unbound provenance, distinct speech stages, metrics, terminal/purge ordering and prepared native test coverage. They do not execute Swift IO/concurrency, compile the app or prove callback correctness.

Prepared but NOT run: 12 tests in `BlindCore/Tests/BlindCoreTests/DebugSessionLogTests.swift`, covering disabled fast path, exact UTF-8/provenance, stale token, truncation/redaction, blocked-writer queue overflow, session/retained caps, write-error/unclean markers, privacy purge, finish with a reserved but unenqueued event, and purge racing that same event.

Required next on an authorized Mac/toolchain:

`swift test --package-path BlindCore --filter DebugSessionLogTests --jobs 2`

Then compile Debug with and without launch opt-in, compile Release, wire and test actual native model/tool/gate/speech/privacy boundaries, add failure injection for synchronization/close/deletion and disk-full/device-lock, verify backup protection, measure recorder-disabled and enabled latency/thermal/memory overhead, and run a synthetic interruption/end/privacy-clear walkthrough. Subsequent checkpoint verification installed the official signature-verified Swift 6.4.1 toolchain and ran all 910 Core XCTest cases successfully, including the 12 recorder tests. The complete Node run passed 338/338 with zero skips. These Linux results exercise recorder IO and concurrency tests but do not establish Apple SDK compatibility, native callback wiring, device protection or performance. No model call or device test was run. See research/rebuild-evidence/checkpoint-01/verification.json for exact current evidence and remaining limits.
