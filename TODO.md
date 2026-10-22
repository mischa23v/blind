## Saudi banknotes: current next steps

- Keep `SaudiBanknoteModelProfile.selected = nil` until licensed real data/model and independent end-to-end evaluation are complete. Code and tests are preparation, not a finished recognizer.
- Inspect the user's downloaded archive locally; preserve labels/attribution, establish physical-note groups and exact issue/side/material coverage, including polymer 5 and 20/200.
- Run the real training pipeline and group-disjoint evaluation, including 100↔1 and foreign/non-money/multiple-note rejection. Calibrate only before test. Do not publish photos or weights without rights review.
- Verify exported Core ML preprocessing/probabilities and the whole rectangle-proposal chain on Mac/iPhone. Add reviewed raw-model project resources and profile only after acceptance. Adult trials before child use. See [Saudi handoff](research/SAUDI_BANKNOTES.md).


# Next actions

**2026-10-22 — Mac test handoff.** Portable checks pass on the completed regression fixes, multi-photo/guided-camera/voice familiar-person flow, optional AuraFace configuration and centralized speech gate. The next gate is actual Apple compilation/runtime, not more face-model research. Follow the current top section of `MAC_HANDOFF.md`: default setup first, explicit experimental generator second, generic iOS/device build for the M1 because the checked OpenCV framework has no arm64 simulator slice. Verify native model/pixel parity, capture/import/consent/cancel/delete, short speech/VoiceOver, stale/hazard suppression and memory/thermal behavior. The completed face work now belongs on the shared primary master branch at the user’s request. Primary integration does not constitute deployment or child-ready certification.

Keep source code and metadata separate from external models, images, embeddings and benchmark output. Preserve original benchmark results; any threshold calibration uses a separate identity partition and reports held-out false names and coverage. Tentative familiar-person hints are not guardian authentication or safe-to-follow instructions. Less than 1% false naming is an aspirational engineering goal, not a demonstrated rate or reason to conceal limitations. Test on consenting adults first and verify the actual device/VoiceOver flow before supervised child-user trials. Continuous 24-hour camera/inference and battery/thermal behavior are untested.

The earlier 2026-10-09 notes below are historical.

**2026-10-09 — next session on the Mac mini.** Follow [MAC_HANDOFF](MAC_HANDOFF.md) › "Mac day — start here":
1. Build (`mac:setup`, with and without `--multimodal`) and fix compile errors until BlindCore, BlindMemory and the app pass.
2. Measure the free built-in model on the iPhone 18 Pro Max (time to first words, total) with the compact guide prompt.
3. Speak the first sentence early (streaming, per-sentence spatial check).
4. Eyes-open walk by the user; then calibrate thresholds with real rooms and objects.
5. Design pass: shorten on-screen text (VoiceOver reads every word), wording review with the brother.

TASKS.md remains the only checklist; PROGRESS.md records what happened. Older pointers are archived in [research/ARCHIVE_TRACKERS_2026-10-08.md](research/ARCHIVE_TRACKERS_2026-10-08.md).
