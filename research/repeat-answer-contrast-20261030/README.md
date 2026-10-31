# Repeat-answer contrast candidate — native audit still required

Base: `84eb13df3184ad9e8373255325efd3b87f6ba56a`. Failure evidence is from
[ff0 native job 124202100185](https://github.com/mischa23v/blind/actions/runs/41096090593/job/124202100185):
UI **20 = 16 passed + 1 failed + 3 skipped**. The Camera/Ask audit identifies
the disabled **Repeat answer** button in the Ask phase as `Contrast nearly passed`.
This is not the earlier Dynamic Type failure.

That button inherited `CameraControlButtonStyle`: tint foreground with 0.5
opacity when disabled. This candidate explicitly reuses the existing
`AskCameraAnswerButtonStyle`, which uses full-opacity primary text when disabled
and permits multiline Dynamic Type expansion. The actual button remains disabled
for an empty answer, and the existing `speakRequested` action is unchanged.
No other button style is changed. A stable identifier also adds the control to
the existing audit evidence and a functional disabled-state assertion.

The complete `auditFullDestination` function is byte-identical to the base.
No additional contrast exemptions, audit filters, deadlines or fabricated answers
are added. No claim is made that a source-level style change passes native contrast.

## Portable verification

`python3 -B tools/test/repeat-answer-contrast.test.py` checks the exact source
contract and rejects altered disabled gates, reverted style, changed speech action,
hidden control, added audit exemption and removed disabled-state assertion.
These checks do not render SwiftUI or execute the UI audit.

## Required native check

On the committed candidate, run the existing native Apple workflow and its full
`LaunchTests/testAccessibilityAuditOfCameraAndAsk` audit unchanged, plus
`LaunchTests/testAskControlsAndUnavailableReasonRemainReachableWithoutCamera`.
Keep any new findings. Native SwiftUI compilation, contrast, VoiceOver, and
signed-device behavior remain unverified by this packet.

The ff0 model-provider asset errors, native callback deadline failures, and
historical route contacts are separate failures and are not repaired by this UI change.
