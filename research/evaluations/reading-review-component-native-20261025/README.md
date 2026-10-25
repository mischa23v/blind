# Native retained-page review component result

**One native component test passed** on [run 40228398355](https://github.com/mischa23v/blind/actions/runs/40228398355), using Core checkpoint32 and a test-owned AVSpeech bridge.

- The 40-word authored source completed as two parts. Its original completed receipt remained intact.
- Previous-part review reached a real onset; repeat created a new request/selection/phrase identity before the old utterance was stopped. The actual old cancellation was rejected without changing the replacement owner.
- Repeat and next each completed through an exact native callback, followed by source/cursor clear. Queued-but-unstarted repeat was correctly rejected.
- Five real starts, four exact successful completions and one real cancellation were observed. Four requests and five phrase IDs retained the same source/revision, epoch/generation and original timestamps.
- The original fixture reconstructs exactly. Four ordinary 30-word-budget wakes honored their recorded ledger deadlines. The sequence took 248.491 seconds; the XCTest case took 248.923 seconds, separately verified from its console line.

Producer e57799d2 pins unchanged Core source 0caea7dc. Runtime: arm64 iOS 27.0 simulator, build 24A434; system-selected super-compact Samantha en-US. One test passed with zero failures or skips. The replaced-attempt receipt was an incomplete snapshot before cancellation; only the actual didCancel event establishes cancellation.

The test-only synchronous main-thread AVAudioSession warning remains disclosed. No audio-session production fix is claimed. The earlier checkpoint30 native success and its prior zero-test architecture failure remain preserved; neither was rerun unchanged.

This is **component integration**, not production NavigationModel/Feedback admission, camera/Vision acquisition, acoustic intelligibility, menu understanding, physical safety or user task completion. System voice metadata and callbacks do not prove heard audio or installed assets. Production privacy/hazard/foreground lifecycle acceptance remains separate.

Verification contains compact results and unchanged private evidence hashes. No raw internal runner paths or broad file inventory are published. This result is outside workflow-triggering probe paths, so publishing evidence does not start an unchanged run.
