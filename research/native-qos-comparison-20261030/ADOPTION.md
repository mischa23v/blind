# QoS comparison and seated failure evidence — source adoption

This note records the combined source checkpoint based on `08ebe14065cfb286c7a6d99fd53b7b377c2ad287`. Its publication commit is the commit containing this note; no unobserved commit ID is asserted here. The pinned README/CI_PLAN retain the original proposal history. Root has authorized adopting this reviewed source and running the bounded diagnostic CI; **native compilation and results remain pending at this checkpoint**.

## Included

- Explicitly opted-in DEBUG scheduling comparison: fixed utility / user-initiated / user-initiated / utility order, unchanged synthetic geometry and one native serial domain. Normal nil-override and Release behavior remain unchanged.
- The original ten-second source/query/drain acceptance deadlines remain. A separate 45-second late-drain observation never converts failure to pass; the next arm requires actual discard acknowledgment. Maximum authored waits are 300 seconds, with a separate bounded CI execution watchdog.
- Both comparison arms use enforced QoS. The utility arm is not an untreated timing baseline of normal scheduling. Requested and observed QoS are separate; equal/unavailable effective QoS remains inconclusive.
- Bounded seated failure-category export before the unchanged strict **18-case** acceptance collector. No raw assertions, photos or geometry are exported. The future 21-case mapped-destination proposal is not included.

## Verification and limits

The combined 18-file source manifest is `8ee9fe6108da5257b60c5b88284f4e89724186bfbf3652188db081b043e2ef07`. There are **165 portable controls**: 61 scheduling-wrapper controls, 51 exporter controls and 53 unchanged strict-collector controls. All 158 integrated pins, three additive reversal layers and exact Xcode project regeneration passed. The outer layer restores seven existing inputs and removes eight additions before historical checks.

The final 43-workflow trigger audit found only native Apple, ingress, room-mesh and the new scheduling lane: six public-guarded standard jobs, with no ungated artifact uploads. Test-start timing is observed through stdout; buffering can produce an incomplete launch-observation timeout rather than establish when XCTest actually started.

These are source/parser/provenance checks, **not native test passes or evidence that queue stalls are fixed**. Actual e418 source/query/render/drain failures and the prior 7bb preflight failure remain recorded. No device accuracy, safe path, real-world collision clearance or physical-guidance authority is established. Physical authority remains false.
