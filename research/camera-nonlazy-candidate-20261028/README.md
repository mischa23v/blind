# Camera non-lazy container candidate — 2026-10-28

Hypothesis experiment, not a proven accessibility repair. No workflow, audit, test assertion, font, text or model behavior change. Native compilation/audit and device VoiceOver acceptance remain pending.

## Evidence

Latest uninstrumented run40645432883 on26365197 reports Camera start-simulation Button, raw65536, at(20,608.7,400,52). Earlier first findings alternated among Practice button/header/footer. The buffered diagnostic run40575028244 (reviewed at `research/apple-camera-geometry-result-20261027/RESULT.md`) measured identical sequences in both scopes: text grows, then Practice rows leave the measured Form area and later geometry disappears, while the Form continues all12categories. Both scopes flag all three Practice elements. This supports testing container materialization, not removing fixedSize, shrinking text, or declaring an SDK false positive.

## Scoped source candidate

Only `DashboardView.swift` changes: Camera monitor Form becomes ScrollView with an eager leading VStack. Existing three Section closures, content/action order, bilingual labels, conditional controls, active-practice status, disabled binding, identifiers, fonts, warning text and navigation title remain identical apart from indentation. Other destinations and model files are untouched. No forced scroll, row identity, category clamp, explicit accessibility merging/hiding or transient content substitution.

A Camera-only ButtonStyle retains native Buttons and their configuration.label, supplying minimum44×44pt targets, expanding horizontally and allowing natural vertical growth; it replaces the implicit Form row hit area. It adds visible standard-material background, existing tint and pressed/disabled feedback. Minimum height is not a cap. This style is part of the candidate and requires actual hit-region/contrast verification; source geometry is not a native audit result.

Apple documents Section grouping with regular stacks as well as lazy stacks: https://developer.apple.com/documentation/swiftui/grouping-data-with-lazy-stack-views . ScrollView with VStack is a documented scrolling composition: https://developer.apple.com/documentation/swiftui/scrollview . Existing Section closures are retained rather than introducing new accessibility grouping assumptions. Actual VoiceOver heading/group/selected control continuity remains a native/device gate.

## Provenance and verification

`DashboardView.before.swift.txt` is the exact GitHub file fetched at published8767fa0, not stale local Git HEAD; SHA256 eacafc050e66d9f2ec874db5229953bb931804b73ec118c609c6224a0a16c85e. This preserves the already-published practice-active-status addition. New source contracts compare every original Section and the entire rest-of-file against this baseline, reject a lazy/Form substitution and validate growth-capable minimum touch targets. Existing header/footer/button/audit contract tests remain unchanged.

Targeted checks and broader direct DashboardView-reader checks are retained separately. They do not typecheck SwiftUI on this Linux host; no Swift compiler is installed. Existing native pipeline must establish exact-source compilation, unchanged full Camera/Ask audit outcome and repeated start/end-practice behavior. Separate cold AX5 footer-end reachability and VoiceOver focus checks remain needed. A passing source contract is not a claim that Form recycling caused the original finding or that moving offscreen is fixed.
