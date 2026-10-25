# Practice header Dynamic Type candidate repair

Base: published master `3d6330e064f7e754a5b454f79732f12f532ccb7a`.

Actual focused Apple run: https://github.com/mischa23v/blind/actions/runs/40191454900 . Job121163136138 completed with exit65. Its camera audit identified **StaticText “Practice”**, not the “Try practice (2 minutes)” button: raw audit type65536, Dynamic Type font sizes partially unsupported, LaunchTests.swift:143. The previous checkpoint repaired the button label only. The newer diagnostic identifies a distinct unchanged section header; it does not prove that the previous button fix failed, nor prove all other elements pass.

The minimal candidate modifies only that header in DashboardView.swift: explicit body semantic font with semibold weight, unlimited lines, vertical intrinsic sizing and leading multiline alignment. It preserves the Section header, bilingual text, original button repair and every audit. No Dynamic Type size restriction, hiding, minimum-scale shrinking or issue suppression is introduced. The exact root cause of the native header's partial scaling has not been demonstrated by local runtime inspection; this is a bounded candidate requiring the same unsuppressed native audit, not a proven fix.

Platform foundations: Apple SwiftUI built-in semantic fonts scale with Dynamic Type (https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text); layout uses documented fixedSize(horizontal:vertical:) (https://developer.apple.com/documentation/swiftui/view/fixedsize(horizontal:vertical:)). No dependencies added.

Validation:10 targeted Node source contracts passed, zero failures/skips, including3 new contracts with mutation rejection of each header modifier and failure of the original plain-header form. Existing simple-accessibility and native-apple-failure-regressions are unchanged. LaunchTests.swift is byte-identical to base. This checks source shape and unchanged audit gates only. Swift is unavailable in this workspace; no Apple SDK build, layout execution, VoiceOver or actual device acceptance has run here. Required next gate: publish reviewed checkpoint and run both Focused accessibility diagnostic and Native Apple SDK checks; retain every failure and inspect newly named elements without suppressing the audit.

Only proposed production change:ios/BlindAssist/DashboardView.swift. New test:tools/test/practice-header-accessibility.test.mjs. Other source files in this isolated directory are unchanged copies needed for targeted checks. Do not publish this partial directory as an entire repository.
