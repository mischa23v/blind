# Native captured-text component result

**One native component test passed** on [run 40224675506](https://github.com/mischa23v/blind/actions/runs/40224675506): a 100-word authored source completed over 247.458 seconds at the ordinary 30-word budget, through five exact AVSpeech completion callbacks and four real budget wakes. All installed phrase IDs/text match callback order; original slices reconstruct the full authored fixture. The terminal completed receipt follows the last callback.

Producer e541ea1b uses unchanged Core source 96fd2d4. Runtime: arm64 iOS 27.0 simulator; selected system voice Samantha, super-compact en-US. The XCTest itself took 248.387 seconds. No failure or skip occurred.

This is **Core plus a test-owned AVSpeech bridge**, not production NavigationModel/Feedback integration, real camera/Vision acquisition, acoustic intelligibility, menu understanding or physical goal completion. System voice metadata and callbacks do not establish installed-asset provenance or heard audio. No test completion was fabricated, and elapsed time alone never completed a phrase.

The first native attempt 40223835661 failed compilation before any test or callback. Its x86_64 test target could not import the destination arm64 Core module. The reviewed correction changed only generated Debug architecture selection; the bridge, source, fixture, gates and timeout remained unchanged. That zero-test failure remains preserved.

The passing run emitted a test-only warning about synchronous main-thread AVAudioSession activation/deactivation potentially causing UI unresponsiveness. It is not suppressed or called a production fix. Further native controller/lifecycle and actual-user audio acceptance remain pending.

Verification contains compact selected results and unchanged raw-evidence hashes, not raw runner paths or a full source inventory. This result is recorded outside workflow-triggering probe paths so evidence publication does not launch an unchanged repeat.
