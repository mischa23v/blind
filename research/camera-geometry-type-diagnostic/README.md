# Buffered Camera geometry/lifecycle diagnostic proposal

Status: proposal only,2026-10-27. Root review/publication and Apple compilation/execution pending. No production layout/font/test changes have been applied. The52 portable checks are synthetic source/parser checks, not native acceptance.

## Evidence and question

[Saved lifecycle recount](previous-category-review/NEXT_DIAGNOSTIC.md) found identical appearance transitions in both existing failed native audits. Category receipt is established; actual geometry at the failing sizes is not. This diagnostic measures that gap, without declaring Form recycling or a framework bug.

## Changes in the disposable checkout only

- Four probes: existing Practice header/button/footer and enclosing Camera Form.
- Public `onGeometryChange` observes each global frame and category; lifecycle/category callbacks record their actual order. The transform includes category so an unchanged frame at a newly evaluated category can be observed. Actor-isolated Environment values are converted to immutable String labels in body before the @Sendable transform; that transform captures those strings and the supplied proxy only.
- Appearance intervals are counters, not claims of native accessibility identity.
- No GeometryReader, extra rendered/AX element, row `.id`, font, sizing, focus, animation or scrolling change. No layout-driving state is written.
- A main-actor external buffer retains at most512 observations, one overflow record and one terminal flush record. Each serialized record is capped at2048bytes; total514×2048bytes. No print, JSON encoding or file IO in the app observation window.
- The disposable audit functions temporarily use `continueAfterFailure=true`, restoring the previous value in defer. This follows Apple's documented multi-finding audit pattern, but is explicitly an observer/control-flow difference from the original test. All original audit calls, issue filters and assertions remain unchanged. Findings still fail the native test. The diagnostic never replaces the original audit's acceptance result.
- In that defer, the test prints a terminal marker (`returned` or `threw`) and posts a fixed public Darwin notification with nil payload. Only the opted-in synthetic app (`--ui-testing` AND `--audit-geometry-type`) registers its observer. The app dispatches flushing to its main actor after receiving it. No user content is transmitted.
- Abrupt test/app termination may prevent defer/flush. Missing or out-of-order terminal evidence is incomplete, never a pass. The collector requires exactly one Camera begin/end marker and a flush timestamp after the end. It records whether the audit returned or threw separately from its native failure result.
- The first Camera audit freezes/flushed trace. Ask coverage remains the original test's conditional continuation, not a second geometry trace.

## Interpretation

A Form-frame intersection is only container overlap, not a measured unobscured viewport or proof of hittability. The global Form frame may include safe-area effects; no hidden inset assumptions are allowed. Button frame growth is not glyph measurement. Category callbacks may precede geometry; never relabel a cached old frame as a settled new-category frame. Missing geometry is unknown. Disappearance with off-container frames supports a visibility hypothesis but still does not establish why Apple's audit failed.

Portable collector rejects stale/mixed launches, extra payloads, nonfinite geometry/time, malformed categories, sequence gaps, oversized/truncated files, symlinks and unexpected events. Overflow, missing terminal markers, or missing in-audit geometry for any role/category retains a partial result. Geometry callbacks strictly between the Camera begin/end markers are counted separately; initial/pre-audit frames cannot fill sweep coverage. Each role reports observed and missing categories. A missing callback is unknown, not proof of zero size or invisibility; a terminal trace can therefore remain partial even when the audit completed. No fabricated callback is required to fill it. Native execution keeps the existing one-simulator, two-serial-selector,600second build,300second selector and45minute job budgets. No automatic reruns.

## Run and review

`python3 research/camera-geometry-type-diagnostic/verify.py <exact clean pinned source>` validates disposable transformations and parser fixtures without running Apple tools.

`workflow-proposal.yml` is not yet an active workflow. It uses an exact clean checkout at fb879d235f38a3f0121b69b023e8ee14c0ded61c and source-file hashes before instrumentation. `run.py` refuses another target path or dirty source. The reused camera scope runner retains failure status, bounded evidence export and owned-simulator cleanup.

Sources:
- Apple geometry API: https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)
- Apple audit session (continueAfterFailure and current-screen scope): https://developer.apple.com/videos/play/wwdc2023/10035/
- Apple documents the used CFNotificationName(rawValue:) initializer: https://developer.apple.com/documentation/corefoundation/cfnotificationname
- Apple audit guide: https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app

Implementation caveat: native Swift/SDK compilation remains unexecuted. Root must review the generated source and diagnostic control-flow differences before publishing or running.
