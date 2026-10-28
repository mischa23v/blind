# Ask focus text-clipping candidate — 2026-10-28

## Observed failure and exact baseline

[Native run 40698547633](https://github.com/mischa23v/blind/actions/runs/40698547633), source `6fe9d5270f23954fa59fc3509cccf23445cefa51`, failed the unchanged Camera/Ask accessibility test with **Text clipped** in Ask, identifying **Everything in view**. The [collected native report](../native-path-recovery-20261028/run40698547633/README.md#ui-finding) is the evidence; it is not a result for this repair. The bounded failure log retains the failing test location, not the underlying screenshot or complete audit extraction.

The exact label is the first option in `AssistantToolsView.assistant`'s native `Picker` in `ios/BlindAssist/DashboardView.swift`. GitHub connector reads established that this entire file is identical at the failed source and current integration baseline `e47b6c9f284dc90603dfee15f7e9295a5b3f647f`: Git blob `807bf7642aa8d16225593b81ec24317ee91de4cc`, SHA-256 `254502265265d98cee7453bb8df9b1c2ba1b8af19f37a1be551f6f4cc5cac191`.

## Narrow repair

The automatic Form picker places the selected value alongside its title. Horizontal compression is the source-based explanation being addressed, not a measured native root-cause proof. The candidate switches only this picker to native inline selection rows, giving each option its own row instead of a trailing selected value. Each of the six option labels explicitly permits unlimited lines and retains intrinsic vertical size while accepting the available width.

- All six full English/Arabic strings, selection tags, initial `surroundings` value and `$focus` binding remain unchanged.
- The native `Picker`, its **Look at** label and platform selection semantics remain. No custom action/selection implementation or replacement VoiceOver text is introduced.
- The Ask action, real `focus` parameter, camera/simulation/busy gates and RTL environment are unchanged.
- There is no fixed font/height, Dynamic Type cap, shrink-to-fit, hidden label, removed option, new audit exemption or test suppression.
- The intentionally taller control may require scrolling. Its native rendering, selected-state announcement, RTL wrapping and downstream Ask/Stop reachability still require native verification.

Reuses documented Apple SwiftUI APIs: [inline PickerStyle](https://developer.apple.com/documentation/swiftui/pickerstyle/inline), [unlimited lineLimit](https://developer.apple.com/documentation/swiftui/view/linelimit(_:)-513mb), and [axis-specific fixedSize](https://developer.apple.com/documentation/swiftui/view/fixedsize(horizontal:vertical:)). No dependency, SDK, copied upstream implementation or model was installed. These API contracts support the layout choice; they do not prove this app passes accessibility acceptance.

## Verification actually run

```sh
node --test --test-concurrency=1 tools/test/ask-focus-layout.test.mjs
python3 research/ask-focus-layout-repair-20261028/check.py
```

Seven bounded Node source/mutation checks pass: full bilingual labels and tags; multiline intrinsic-height native rows; unchanged focus/action/gates/RTL; original full Camera+Ask audit path; rejection of abbreviated labels, shrinking/capping/hiding, lost height and audit removal/exemption. These checks do **not** execute SwiftUI, accessibility, VoiceOver or an iPhone. The evidence checker verifies baseline provenance, an exact 15-line additive-only source delta, all recorded hashes, and that native audit source/helper remain unchanged.

The partial checkout lacked the affected source and audit references. Only `DashboardView.swift`, `ios/BlindAssistUITests/LaunchTests.swift` and `tools/test/helpers/full-audit-contract.mjs` were restored for this change. The latter two retain their exact baseline bytes and are **not changed publication files**. No NavigationModel, mapper, workflow, project membership, or shared tracker was edited.

## Still required; do not close H09/Q03

No `swift`, Xcode, Apple SDK or simulator is available in this container. No build, native audit, screenshot render or VoiceOver run was attempted. The source is a **candidate repair**, not a proven native pass or release-ready result.

On the published exact revision, run the existing native workflow and retain `LaunchTests.testAccessibilityAuditOfCameraAndAsk` without altering its full scope or exemptions. Verify English and Arabic at default and largest accessibility text sizes: every focus option wraps completely, selecting each option retains the selected state, full VoiceOver labels/selection remain available, returning/reopening Ask is coherent, and the Ask/Stop controls remain reachable by scrolling. Check the rest of the audit for new findings; absence of this one label's failure is not evidence that all destinations passed. This task does not authorize a new workflow, a child trial or physical-use acceptance.

`verification.json` and `SHA256SUMS.txt` bind this local checkpoint; `ask-focus-layout.patch` contains the entire production delta. Root integration owns publication, shared tracker reconciliation and exact-revision native validation.
