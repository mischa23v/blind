# Native Apple regression at 0babd78

[Run 40571313138](https://github.com/mischa23v/blind/actions/runs/40571313138) finished with failures. Source is `0babd78d14eafe8b818e3b15be1ebe84aaf04caf`, with the foreground SpatialMapIO priority candidate, unchanged original test deadlines/assertions.

- BlindCore: 1,385 total, one skipped, zero failures.
- BlindMemory: 51 total, zero failures.
- Default unsigned iOS Simulator app build: passed.
- Hosted units: xcresult summary 155 total, 148 passed, five failed test declarations, two skipped. The five declarations produced 14 parameterized model issues, not 14 additional test declarations.
- UI: 17 total, 13 passed, one failed, three skipped. The unsuppressed Dynamic Type audit still reports raw type 65536, this time on the Practice footer. Camera-after and Ask phases were not reached; the evidence exporter correctly marks this partial, not complete.

## Model failure diagnosis

All 14 pre-adapter model observations report `available` on iOS 27.0. The runner then logs UAF Code 5000: no underlying assets for `com.apple.MobileAsset.UAF.FM.Overrides`. The conversation adapter returns nil text with its generic failure status. Failing declarations: `remembersNameWithoutRecitingHistory`, `followsConversation` (five cases), `doesNotInventFloorClearance`, `suppliesNameWithoutOldHistory` (two cases), and `repliesNeverAssertUnsupportedFacts` (five model cases).

This is evidence of a model-runtime prerequisite failure on this simulator, not evidence that generated answers violate the guards. It does not establish that every error came from the same underlying exception: production catch intentionally omits error details. The public availability API alone was insufficient here. Do not suppress or skip these failures merely to turn CI green. A separate bounded synthetic capability probe with typed error classification and no user text would distinguish direct model execution failure from our adapter; actual device model acceptance remains open.

## Runtime IO regression limits

The bounded ConnectedJourneyRuntime failure extractor emitted zero failures and omitted zero. That supports no recorded runtime failure in this run. However, the workflow published only aggregate unit xcresult counts and failure windows, not the complete unit xcresult or positive test-case statuses. Therefore this evidence does NOT independently prove the specific original ten-second fixture passed. Source hashes for ConnectedJourneyRuntimeTests and CommunityTests were fetched at the exact commit and matched locally. The next CI evidence increment should emit the exact target's started/passed/failed and phase rows (or compact case statuses) without changing its assertions or deadline.

## Integrity

The UI artifact is 12766756189, 424,725 bytes, SHA-256 `d588ed9abab10f9df6dadd4159b3bbc7d2b2d8a64bad538568818a96bb8f9762`. Size, SHA and ZIP CRC verified. Images are synthetic simulator captures. Complete job log is retained locally; the publication includes only bounded relevant evidence. No source, test or workflow change was made by this verification.
