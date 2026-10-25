# Failed voice-enrollment deletion / restart repair (isolated)

Based on `/workspace/shared/blind-voice-enrollment-stage`. Nothing applied to that stage or main app; nothing published. Foundation-only contracts plus an iOS source proposal; no live enrollment, raw audio, model download, speaker matching or authority changes.

## Repair

A fixed, one-byte `deletion-pending-v1` marker in the existing protected, backup-excluded enrollment directory is atomically written before record removal. iOS uses complete protection and verifies protection/backup exclusion before proceeding. Generation invalidation and RAM read fencing occur before directory/marker operations; old queued saves remain rejected. No await is introduced into save/delete.

Both load and save consult the marker, including after actor recreation. Any marker contents/type blocks them. Unknown/inaccessible marker status throws rather than treating it as absent. Fresh helper setup cannot bypass this marker: successful deletion retry is required before saving a new enrollment. Every other child of the dedicated container is removed first, including hidden atomic-write orphans and nested remnants. Enumeration/removal errors propagate, and a second enumeration must confirm no other children remain before marker removal. The directory is deliberately retained. Cleanup errors propagate and never report deletion success. The existing generation's in-memory replacement override does not override this separate disk fence.

## Verification

`tests/run.sh /workspace/shared/swift-toolchain/install/swift-6.4.1-RELEASE-debian13/usr/bin/swiftc`

**71 synthetic Foundation checks passed**, comprising the original 40 plus 31 new assertions. The production Foundation marker and directory-cleanup helpers ran against tiny synthetic local files: initial absence, marker-verification failure, erase failure, new-helper/new-instance fencing, ordered retry, repeated delete, failed marker creation, actual filesystem permission denial on marker removal, inaccessible-marker lookup, unexpected marker shape, zero-byte/dangling-link markers, whole-container orphan/nested cleanup, cleanup-denied restart fencing, and enumeration denial. Test runner needs an unprivileged process for permission-denial cases. No production/private data was read or written.

The iOS actor passed syntax parsing with `swiftc -frontend -parse -target arm64-apple-ios17.0 source/ProtectedVoiceEnrollmentStore.swift`. This is **not** Apple SDK typechecking or iPhone acceptance. Foundation tests do not execute the iOS actor or its protection APIs. See `evidence/` for exact hashes, results and empty successful build/parse logs. New tests were not executed against the old source (which lacks the marker helper).

## Limits and remaining acceptance

- If directory/marker creation fails (e.g. full disk, locked protection, permissions), persistent intent was **not admitted**. The error propagates; record removal is not attempted; RAM stays fenced. A later process can still read the old record if no marker was committed. UI must truthfully report failure and require retry. No storage implementation can promise a durable write when storage rejects that write.
- Atomic writing is used for process-restart consistency; no sudden-power-loss durability/fsync guarantee is established. Interrupted atomic writes, cleanup failure, actual lock/unlock, backup flags, full disk and storage replacement require Apple/device fault-injection tests.
- Existing prior failures without a marker cannot be reconstructed retroactively. Malformed marker types fail closed and may require explicit repair; they are never interpreted as permission to load.
- One serialized store must own this directory. This is not a cross-process/multiple-store locking protocol. Parent directory replacement races and hostile filesystem mutation are not solved here.
- Caller must clear RAM records/PCM/pending work and invalidate voice evidence on deletion, lock, mute/end and route change. File deletion is not forensic flash erasure.
- Native helper UI remains responsible for visible deletion-failure/retry handling. No speaker authentication, recognition accuracy, physical-safety or release-readiness claim follows from these checks.

This closes the admitted-marker/failed-erase restart hole at source/portable-test level, not all disk-failure privacy requirements or native acceptance.

## Independent-review correction

The initial 60-check candidate removed only the selected JSON file, regressing the original whole-directory cleanup and potentially leaving atomic-write biometric remnants. That candidate is superseded. The revised helper removes every other child while retaining the marker, verifies the directory, then clears intent. The 71-check evidence covers this revision. Re-instantiation tests reset helper/RAM state; the actual iOS actor was not executed.
