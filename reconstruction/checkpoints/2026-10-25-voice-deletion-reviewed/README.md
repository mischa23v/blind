# Reviewed voice deletion checkpoint — SOURCE BACKUP ONLY

**Staged-only; not integrated, activated, release-ready or native-validated.** These sources must not be added to an app target or connected to capture, enrollment, speaker matching, private history or authority merely because this backup exists. No code outside this checkpoint is changed.

Reviewed revision: 71 synthetic Foundation checks passed; iOS source syntax parsing passed. No Apple SDK typecheck, actual iOS actor execution, iPhone protection/backup verification or speaker-accuracy test ran. Independent reviewer accepted the corrected source for staging after reviewing whole-container deletion and matching receipt hashes. The result log/receipt are historical evidence, not a claim that publishing this backup reran tests.

Only UTF-8 source, synthetic tests, patch and evidence are included. No audio, biometric/user records, credentials, models, binaries or compiler cache. The one-byte deletion marker contains no identity metadata. Atomic-write orphans and all other dedicated-directory children are erased before marker cleanup; deletion/enumeration errors retain the fence.

Publication baseline supplied by parent: `63dff7055f25c252da4c4c623b85fd3421716d40`. This is a backup destination, not an assertion that the stage has been integrated or Apple-compiled against that revision.

## Reproduce portable checks

Run `bash tests/run.sh /absolute/path/to/existing/swiftc` from this checkpoint. No install/download occurs. The original run used Swift 6.4.1 on Debian. Permission-denial fixtures require an unprivileged process. The runner creates ignored/non-deliverable `tmp/` outputs and rewrites local evidence; preserve this historical receipt before rerunning. Directory cleanup/re-instantiation tests exercise the production Foundation helpers, not the Apple actor.

## Limits

- If storage refuses creation of deletion intent, it cannot survive restart; erase is not attempted, RAM remains fenced, and failure must be shown with retry required.
- No power-loss/fsync durability guarantee, forensic-erasure guarantee, or cross-process/multiple-store exclusion. Exactly one serialized owner is required but host ownership is not yet integrated/enforced.
- Protected storage, lock lifecycle, backup flags and device fault injection remain open.
- Caller must clear in-memory records and pending PCM/embedding work on consent withdrawal, deletion, lock, mute/end and route change; voice evidence ownership must be invalidated.
- Never infer speaker authentication or authority from these contracts. Existing no-authority-elevation behavior remains unchanged.

See `STAGE_REPORT.md` for the repair detail and superseded 60-check candidate correction. See `APPLE_NEXT_STEP.md` for research-only compile acceptance plan. `evidence/execution-receipt.json` binds the reviewed source bytes; `backup-manifest.json` binds this backup. The original archive is intentionally not copied; individual files are small and reviewable.
