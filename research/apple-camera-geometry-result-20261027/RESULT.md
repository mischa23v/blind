# Native geometry observed: text grows, then Practice rows leave the Form area

Run [40575028244](https://github.com/mischa23v/blind/actions/runs/40575028244), job122439031894, workflow commitdd08c55d10b7622efe0bbe5ac31410f0c471cdb0. App source pinned tofb879d235f38a3f0121b69b023e8ee14c0ded61c with the reviewed disposable instrumentation.

Artifact12768000786:2,593,549bytes; SHA-256 `309aaf1c8c11411fb6a328468d296c26e6233417f85943ad693dad9192296b2e`. ZIP CRC, relative member paths and expanded size below28MiB verified. All24 JSON/PNG files preserved. No retries were run.

## Outcomes kept separate

- 52 portable checks passed on the Apple runner.
- Actual app/test Swift build passed in417.639seconds, under the unchanged600second budget.
- Both native audit selectors failed with exit65, without timeout; owned simulator shutdown/delete passed.
- Both traces contain229 rows,75 in-audit geometry events, no overflow or unknown category, complete Camera begin/end markers and terminal flush after audit end. Their status is correctly **partial**, because some larger-size Practice geometry was never observed.
- The full audit now records Camera before/after and proceeds to Ask because the disposable `continueAfterFailure=true` lets every issue be reported. It does not suppress failures.

## Measured finding

Both scopes produce exactly identical per-role geometry/category sequences, independently checked by `recount.py` and `GEOMETRY_RECOUNT.json`.

| Role | Large observed content frame | Last enlarged frame before missing larger categories |
|---|---|---|
| Header | x40,y578.33,w65.67,h20.33 | accessibility2:x40,y944.33,w123,h39.67 |
| Button content | x40,y624.5,w181.67,h20.33 | accessibility1:x40,y808.33,w283.67,h33.67 |
| Footer content | x40,y668.67,w358,h86.33 | accessibility1:x40,y865,w344.33,h237.67 |

The measured Form bottom remains873 throughout these relevant transitions. Header's accessibility2 frame begins below that bottom. The accessibility1 footer extends from865 to1102.67, mostly beyond it. Button/footer then emit disappearance and have no geometry foraccessibility2–5; header has no geometry foraccessibility3–5. All return atLarge. The enclosing Form continues producing all12categories.

This establishes that the measured text/layout is growing and that content moves beyond the measured Form area while later row geometry is unavailable. It is stronger evidence for a visibility/materialization interaction than the prior category-only trace. It does **not** prove the complete internal cause of Apple's Dynamic Type finding, native accessibility identity replacement, glyph visibility, or an SDK false positive. The probe observes content frames, not the full accessibility row rectangles. Form overlap is not independently measured unobscured visibility.

Repeated disappear/appear events also occur at smaller transitions; their occurrence alone is not the explanation. Missing later samples remain unknown rather than zero height or inferred safe text. Existing cold largest-size tests scroll rows into view, so they measure a different condition.

## All unsuppressed findings

Both Camera scopes report three Dynamic Type(raw65536) findings: Practice header, footer and button. The previous stop-on-first-failure behavior hid later findings; this is not evidence that new font regressions were introduced.

The full test also reaches Ask and reports four contrast(raw1) findings, three with no identified element and one for `Explore a picture by touch`, plus one clipped-text(raw131072) finding on the Picker value `Everything in view`. No exemption was added. The first two issue images per destination are preserved; later issue captures are explicitly omitted by the pre-existing cap, while all five Ask findings remain in outcomes logs.

Viewed Camera-before and Ask-before screenshots. Camera's restored/default layout is readable atLarge. In Ask-before, the named Explore control lies under the floating tab area; this is a useful lead for contrast/viewport investigation, not a verified exemption. The snapshot is not a large-size clipping image. All12screenshots remain callback/before/after evidence, not images at each transient size.

## Next change, not yet implemented

Do not remove fixedSize or prescribe a smaller font: this run measures scaling, not a pinned font. A bounded next experiment could compare the same section content in a non-lazy scrolling container or separate Practice destination against the original Form while preserving semantic order, warnings, controls and unsuppressed audits. This would test the materialization hypothesis, not automatically justify shipping a redesign. Cold-state largest-size reachability and VoiceOver focus continuity would also need checking.

Ask needs its own focused layout/contrast diagnosis; do not ignore unidentified contrast issues or apply a broad disabled-control exemption. Native device/VoiceOver acceptance remains open.

### Endpoint evidence checked after this run

Revalidated artifact12605995482 from prior full-app run40209239473 (2,762,275bytes,SHA-2567e1b0d7fe24b15d336f36d28baf753eb010e70c6d890be9aee1949a6fa0cb24c) and viewed the actual largest-size footer image. The full button and header are enlarged and readable. The long footer continues below the screen; its final cane/guide-dog warning is not shown. Those prior three largest-size captures share the same scroll position. Therefore that run cannot establish complete footer-end reachability, nor prove that it is unreachable.

The current existing `recordPracticeFooterEnd` test helper explicitly scrolls within8up/8down attempts, checks the exact footer label and hittability, requires its bottom between the navigation bar and tab bar, and captures that endpoint. Its older diagnostic document marks native execution pending. A bounded run of the two current full-app endpoint selectors is the minimal next control before any production redesign or non-lazy-container comparison. It would establish actual scroll reachability and pixels without changing fonts, audit filters, identities or production scrolling behavior. The old shell helper has no per-command timeout, so reuse the newer bounded scope-runner orchestration rather than running that shell helper unchanged.
