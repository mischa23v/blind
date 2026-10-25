# Synthetic Practice layout comparison

This isolated app has no production target dependency, packages, model, permissions,
user storage or network path. It is not a usability test for blind users and does
not change the original full-app accessibility audit.

## Fixed experiment

One owned iPhone 18 Pro Max / iOS 27.0 simulator; one build; no retries. Each of A,
B and C receives two independent Dynamic Type audits and two independent hit-region
audits at Large, plus one layout/endpoint test at accessibility XXXL: 15 cases.
Failures are retained; separate invocations allow subsequent cases to run after a
failure. Each case captures exactly two named screenshots, including an after image
via `defer`. The callback always returns false. Continuing after XCTest failures
is for evidence collection, not suppression. Missing evidence is an error.

- **A:** stock SwiftUI Form/Section/Text/Button.
- **B:** Form with the static English Practice button/header/footer and exact text
  modifiers copied from `ios/BlindAssist/DashboardView.swift`, Git blob
  `d3695f783f5c62b88ea78a746917b7f2d5d2c743`. The button action is inert.
- **C:** B's same text views and button in a padded, leading VStack/ScrollView.
  It deliberately has no Section/Form semantics, row insets, row backgrounds or
  virtualization. Automatic button style is left automatic in all three: its
  contextual rendering can differ. No minimum hit size is added to make C pass.

All three share NavigationStack/title, dark scheme, gold tint, English locale,
left-to-right layout and identifiers. Additional identifiers on the header/footer
are diagnostic-only and identical across variants. This minimal host omits the
app's TabView, other sections and model-driven status. Consequently a pass cannot
exclude a full-app surrounding-layout or timing problem.

Both the test runner and host check the requested category. The host fails a
precondition on category mismatch; native compilation checks all audit APIs against
the installed SDK before any case runs. Endpoint checks require only the bottom of
the full warning to enter the visible region, not that the entire tall footer fit.
The bounded gestures move only upward, avoiding the previous probe's reversal to
the top. The bottom boundary excludes 34 points for the specified phone's home
indicator; screenshots are required to corroborate this geometric proxy.

## Interpretation and evidence

The audit logs public compact/detailed descriptions, type and optional element,
with bounded strings; captures include frames, existence, hittability, labels and
a bounded synthetic hierarchy. Exact outcomes, runner/SDK metadata and named PNGs
are retained. A stock Form failure suggests container/platform behavior but does
not establish a false positive. B-only failure narrows the copied styling; a C
difference is not permission to rewrite the production layout. Endpoint failure is
a failed bounded probe, not proof that a human cannot reach the text. Two repeated
cases measure limited reproducibility, not all content sizes or devices.

No native result is claimed until this diagnostic compiles and executes in CI.
Visual font and hit-region evidence complements, never replaces, the higher-priority
nonvisual goal-usefulness work and supervised VoiceOver validation.

Public API references: [audit issue descriptions](https://developer.apple.com/documentation/xcuiautomation/xcuiaccessibilityauditissue)
and [audit types](https://developer.apple.com/documentation/xcuiautomation/xcuiaccessibilityaudittype).

Artifact limits: 30 authored PNGs totaling at most 24 MiB, plus at most 4 MiB of
outcome JSON, keeping the download below the connector's 32 MiB limit. Individual
log summaries are capped at 192 KiB serialized; audit descriptions are prioritized
and omissions/truncation are explicit. Oversized/missing screenshots fail evidence
validation rather than being silently accepted.

## Native result: c683ea3

[Run 40223169463](https://github.com/mischa23v/blind/actions/runs/40223169463)
compiled with Xcode 27.0 (27A266a), iOS simulator SDK 27.0, and passed all 15 fixed
cases without retries: 12 unsuppressed audits and three accessibility-XXXL endpoint
checks. All 30 named PNGs were retained, with zero omitted or truncated diagnostic
log lines; owned-simulator shutdown/deletion passed. The artifact ZIP SHA256 is
`06c58daddf4bc72fc3b36cd2bc02df6d8b26b69e22c3d8cdca284c067ba89e20`.

All 14 byte-distinct screenshots were visually inspected (the other 16 are
byte-identical). Every endpoint-after image shows the final cane/guide-dog warning.
For B, the copied footer grows from 100.33 to 883.33 points high and its endpoint
becomes visible after two bounded upward gestures. This supports scaling and
endpoint reachability **in the isolated host only**. The full-app audit remains a
separate unresolved result: its surrounding sections, TabView, state, navigation
and full audit scope differ. The experiment does not establish an SDK false
positive or justify changing production styles, suppressing the audit, or claiming
whole-app accessibility. Exact outcomes and all 30 PNG hashes are recorded in
`research/rebuild-evidence/practice-layout-comparison/native-result-c683ea3.json`.
