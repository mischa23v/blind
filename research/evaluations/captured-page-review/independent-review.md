# Independent production review

Reviewer: collaboration agent `review_parser`, read-only after parser delivery; no SDK/device test claim.

First pass found:
1. Retained/replayed source could be silently retired by ambient scene requestID rotation after readingTool became nil.
2. Single-part completion guidance incorrectly implied whole captured text completed.
3. Parent-identified pacing preservation needed to include retained idle source.

Corrections: automatic readScene guard includes retained captured source; completion wording is neutral about part/page and uses exact EN/AR commands without promising microphone authority; pacing condition includes retained source. Historical nonurgent depth/VIO branch uses playbackAllowed, not fresh-camera admission. Exact old phrase ID/text rejected before Core callback context validation.

Re-review: corrections verified; no remaining blocker found in changed production paths. Onset order, privacy clearing, historical playback and ordinary-budget guidance inspected. Documented intentional tradeoff: page retention holds automatic scene descriptions until source retirement; hazards remain independent.

This review does not establish native typechecking, audio behavior, OCR accuracy, task usefulness or participant acceptance.

## Usability refinement review

Root requested contextual Home/simple Repeat and non-dominating guidance. Reviewer inspected final changes and found no remaining blocker: no-source generic behavior preserved; urgent-monitoring branch and private no-fallback retained; early Repeat preserves original queued reading/budget wake even if optional replace:false status is denied. Guidance has one opportunity, not a delivery claim. Exact extended clothing guard assertion and inactive unrelated-lane fixtures approved; selected-photo ordering test still requires both markers and generic-cancellation order.
