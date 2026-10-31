# Observed-scene fence fixture candidate

The 8c264cf full-native run failed the final snapshot/status assertions in this test. Its preserved evidence cannot distinguish a dropped final offer (busy old worker) from an admitted final offer that finished after polling. No unsafe stale publication was established by that run.

The source does establish a test scheduling race: each invalidated old worker retains the sole slot until its main-queue delivery retires it. A fixed 100 ms sleep does not prove retirement. Subsequent offers while busy intentionally drop rather than run concurrent mutations of the accumulator. Continuous production feeds can supply another observation; this fixture supplied only one final frame.

Candidate adds an internal standard DispatchQueue injection with the unchanged serial utility default and a discardable Bool admission receipt. All admission gates, cadence, stale-work fences and queue work remain unchanged. The fixture suspends its serial queue to force invalidation before work, asserts busy offers reject, resumes and drains through queue-to-main markers, then explicitly asserts final admission. Every onChange callback is checked for forbidden stale publication, not merely final state. Actual accumulator and original 2703-point frames are retained.

Original nil/nonnull/status assertions remain. The original nominal total wait budget (100 ms + 100 ms + 1 s) is now a shared 1.2 s deadline; each drain also caps at 1 s and final polling retains 100 x 10 ms cap. No timeout or QoS increase. The shared deadline is a nominal polling budget, not a guaranteed hard elapsed-time cap: scheduler delays and a final polling sleep can overshoot. It avoids increasing the original nominal budget. A timeout still fails rather than admitting another overlapping worker.

Validation: source inspection and git diff --check pass. A bounded three-file Node source-contract run on the concurrent shared tree returned 35/41 pass, six failures (full log: source-contracts.log). Observed-scene-only returned 7/9 pass: both failures require the old inline detector.process call instead of the current processDepthHazards helper. A separate tracking-loss regex rejects the newly inserted default-off stage85 diagnostic block. These checks do not execute Swift and are not a native result; parent was informed, and no contracts were changed by this candidate. No Apple compiler available locally; native compile and exact revised-test execution remain open. Do not report this candidate as a passing fix. Parent owns review/publication. Two-file patch is candidate.patch; file hashes are MANIFEST.json.

Independent source review cleared the revised candidate: balanced queue suspension, serial-to-main FIFO marker ordering, unchanged worker/fence body, retained original assertions, and matching manifest. Callback retain cycle is cleaned by defer at test exit. Native execution remains required.

## Parent post-review checks

After the separately reviewed critical-order/source-contract repairs, all43 targeted navigation contracts pass, plus14 privacy, automatic-recovery, native-failure and synthetic handoff checks. These remain source/portable checks, not execution of the changed Swift fixture. The first failed source-contract run above is preserved as history. Exact new native fixture validation remains pending.
