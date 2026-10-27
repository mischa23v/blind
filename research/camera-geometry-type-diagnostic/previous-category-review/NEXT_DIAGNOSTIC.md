# Separate dynamic layout from environment changes

2026-10-27. Source/evidence review only. No new Apple execution, production change, audit suppression, or accessibility pass.

## Newly recounted evidence

`recount.py` deterministically reads the two preserved app-effective traces from run40564108538 attempt2. `LIFECYCLE_RECOUNT.json` records their SHA-256 values, launch IDs and exact event sequences. Both have112 complete rows and reproduce the same pattern:

- Each role receives13 dynamic-change and13 legacy-change events.
- Button/footer each emit11 `appear` events: initialLarge, every sweep category from xSmall through accessibility1, then restoredLarge twice. They do not emit `appear` at accessibility2–5.
- Header emits12 `appear` events, adding accessibility2 but not accessibility3–5.
- All three still receive category-change events through accessibility5.

The app therefore responds to categories, but category receipt does not establish that a Form row remained rendered, visible, or geometrically updated. Repeated appearance is a lifecycle observation, not proof of object identity changes or row recycling. Absence of a repeated appearance event does not itself prove disappearance. Those events were not captured.

The actual Camera screen is a `Form` containing Safety, Return and Practice sections. The Practice text uses scalable body fonts, unlimited lines and vertical fixedSize. The existing largest-size endpoint test explicitly scrolls each row into view after launch; the native audit starts at Large and does not scroll during the sweep. Thus passing endpoint tests and failing rapid native sweep are different measurements, not a contradiction that justifies ignoring the failure.

## Smallest next diagnostic

Extend only the disposable, source-pinned instrumentation. Keep the exact production typography, row identity, Form, accessibility elements and original unsuppressed audit unchanged.

1. Add `onDisappear` to the existing three probes. Record a monotonically numbered appearance interval for each role in a separate diagnostic store; do not add `.id`, alter SwiftUI state, or claim intervals are native accessibility identity.
2. Add public SwiftUI `onGeometryChange(for:of:action:)` to those same nodes. Transform the proxy into an equatable sample containing global frame and the current dynamic/legacy category. Include category in the sample so an unchanged frame at a new category is observed. Record callback uptime. Do not put a GeometryReader, overlay, background view or sizing modifier into the layout.
3. Measure the Camera Form's global bounds with the same modifier. This supplies a same-coordinate container rectangle, not proof of the unobscured viewport. If no public inset/clipping rectangle is measured, call frame intersection `containerIntersection`, not `visible` or `hittable`.
4. Buffer up to512 small value records plus an explicit overflow marker in an external main-actor diagnostic store. No published/@State values, print, JSON serialization, disk IO or screenshots during the sweep. Flush only after the audit callback/terminal collection marker using the existing synthetic-only diagnostic route. If an after-marker cannot be delivered because the audit fails, preserve incomplete evidence rather than covertly logging during the measured window.
5. Preserve category and geometry event order separately. An onChange event can precede layout. Do not pair it with an old cached frame and label that frame the new category's settled geometry. Define a category as geometrically observed only when its category-tagged onGeometryChange callback occurs. Zero callbacks is unknown, not zero size.
6. Run the same matched full/typed cases once under existing budgets only after source/collector fixtures and source-pinned diff review. Both audit failures remain failures even if the diagnostic is complete.

Expected schema fields: schema, launch, seq, uptime, role, event, dynamic, legacy, appearanceInterval; geometry events additionally frame{x,y,width,height}, with finite-number checks. Scope contains synthetic UI only. Roles/events/categories are fixed allowlists; reject partial, unknown, overflow, stale launch or mismatched source hashes.

## Interpretation fixed before execution

- Frame growth and a movement outside Form bounds support a visibility/layout mechanism, not broken font scaling. Then test an actual usability change separately; do not hide the row from the audit.
- Missing geometry for a category with disappearance leaves that category unmeasured. It is not an accessibility pass.
- Persistent materialization with unchanged text geometry across multiple genuinely processed categories supports investigating text sizing/hosting. Button frame alone is not glyph size and can stay stable when text grows inside padding.
- Changing geometry without disappearance still does not establish clipping or correctness of the accessibility tree. A cold endpoint screenshot/AX snapshot can inspect that separately, with the distinction preserved.
- Do not use arbitrary fixed/scaled heights, `.id(dynamicTypeSize)`, or ignored audit findings to make CI green. They can change focus, row identity or mask the measured issue.

## Primary sources

- Apple documents `onGeometryChange` as the public geometry observation modifier: https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:). The documentation entry was verified; the text/markdown body was unavailable through this research tool. API compilation on the selected SDK remains required.
- Apple's accessibility audit session states audits inspect the current screen and do not replace assistive-technology testing: https://developer.apple.com/videos/play/wwdc2023/10035/ (Considerations,11:41).
- Apple's audit guide distinguishes clipped-text checking from other audit types: https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app. A raw65536 Dynamic Type finding is not independently a measured clipping result.

This is a proposed measurement, not a proven cause or fix. No remote run has been requested by this review.
