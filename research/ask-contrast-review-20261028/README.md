# Enabled Ask question prompt contrast candidate

## Observed evidence, not an attribution of the anonymous audit

Exact run40653113122 / source26bfa69e8fb7a9f32df6d4c581477d91e95dfaed progressed through the unchanged full Camera audit and then reported Ask contrast(raw1) with no identified element. Artifact12802326126 contains Camera before/after, Ask before/callback screenshots and metadata. The callback image was visually inspected; its SHA and reproducible pixel region are recorded in CONTRAST_MEASUREMENT.json.

The visible, enabled Your question placeholder has dominant solid glyphRGB(90,90,94) against backgroundRGB(28,28,30), measured sRGB contrast2.47834:1. This is independently poor text contrast, below even the3:1 large-text threshold. It does not identify which node triggered the native callback. Placeholder text is covered by the W3C contrast guidance: https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html . Screenshot measurements are not a guarantee of device rendering or the redesigned result.

## Minimal repair candidate

Only the question TextField initializer receives an explicit prompt Text with foregroundColor(.primary). Original bilingual title/prompt, model.assistantQuestion binding, vertical axis, accessibility label and surrounding UI remain intact. The API returns Text for the prompt: https://developer.apple.com/documentation/swiftui/textfield/init(_:text:prompt:axis:) . Goal-field prompt, disabled buttons, Picker, Form layout, camera eager layout, Rooms recording entry and all audit behavior are unchanged. No smaller font, disabled-control exemption or anonymous-finding suppression.

Baseline snapshot is exactly the fetched publishedadb8fd8 Dashboard file, including the newer Rooms recorder entry. New tests require full-file equality after reversing this one exact initializer delta. The prior Camera provenance test now also reverses only this exact independently scoped delta, keeping its full-file equality and Section checks; no generic exclusion was introduced.

Native compilation, actual new prompt contrast, typing, clear/retype, Arabic, AX5 and original full Camera/Ask audit remain pending. This candidate does not claim to fix the anonymous audit, clipped Picker value or any offscreen/under-tab contrast finding.

## Separate DescribeFocusAndStopControl timeout

The actual failure is LaunchTests.swift160: evaluating `.exists` for Question or target TextField/TextView, immediately after openSettingsPage(ask-screen). Case202.883seconds. Stop reveal and tap occur later and were not reached. Each test launches a fresh app with explicit English locale and camera/background-voice off; this is not proof of a state leak from the preceding audit. The bounded CI log omits that case's detailed action timeline and native snapshot stack, so it cannot distinguish simulator/AX-service delay from an app main-thread stall. AVAudioSession synchronous activation warnings occur in this case and other cases, including earlier runs; they are a lead, not proof of causation. No source/test timeout/query change is justified by this evidence. Preserve failure and inspect the already queued exact-source native result for recurrence; if repeated, capture the selected test's bounded action/failure diagnostics before changing behavior. This prompt-color candidate is not a timeout repair.
