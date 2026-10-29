# Independent result review — 2026-10-29

**The one root-executed authored suite passed its scoped checks: 23 mask comparisons, 37 refusal cases, 935,940 integer oracle visits.** This reviewer did not rerun the guard, compiler or executable. Public-safe aggregate: `PUBLIC_RESULT.json`; raw full receipt, executable and absolute command paths are deliberately excluded from this publication packet.

## Exact evidence verified

Admitted/executed commit: `de10b306f58033c204ea8c781cb2076df55eb388`.

- Guard status `completed-zero-exit`; compile and comparison both exit 0; both process groups recorded retired.
- Run manifest equals the admitted commit's exact blob and recorded manifest hash. All 21 input hashes agree among manifest, before-run receipt, after-run receipt and current regular files.
- All five final payload files match recorded sizes/SHA-256; executable digest matches saved pre-comparison digest and current binary. Attempt directory contains exactly those five files plus RESULT.json.
- Comparison stdout exactly reports the expected pass/counts; comparison stderr is empty. Raw receipt SHA-256: `25d413aac645a4f5de7038f2ce952d176d941c7d97107bebe9bb9ca7aeb1fa2f`.
- Guard reports 2.814536 aggregate CPU seconds, 2.841933545 elapsed seconds, 120,164,352 bytes peak observed aggregate RSS and 107,360,256 bytes fast-exit child RSS. Retained attempt files total 705,928 bytes. All reported figures are below the admitted caps; sampled memory remains observation, not a hard peak guarantee.

## Independent count reconciliation

Mask cases: seven shapes at three radii, plus two null-center ripple radii = 23. Refusal cases: 1 apply-before-prepare + 13 invalid preparations + 3 work budgets + 20 apply mutations = 37. Second-apply/retry assertions are additional checks, not additional reported refusal cases.

There are 72 exterior seeds. Five ordinary full-grid shapes each have 64 real boundary seeds (136 total); the disconnected above-climb step adds 30 real seeds (166 total); the hole leaves 288 spans and adds four real seeds (140 total); null-center ripple adds five real seeds (141 total). The source's unconditional all-seed oracle traversal therefore performs:

`5*3*289*136 + 3*289*166 + 3*288*140 + 2*289*141 = 935940`.

This is a source/arithmetic recount, not a second candidate execution. Successful REQUIRE checks cover only the authored assertions; they do not prove omitted cases.

## Warnings and remaining boundaries

Compiler stderr preserves seven `-Wmisleading-indentation` warnings in tests.cpp lines 153, 154, 155, 156, 158, 160 and 161. These are consecutive independent mutation selectors written on one line; source review confirms they are not intended nested conditionals. They are not hidden, fixed after execution, or called a warning-free build. Comparison emitted no runtime sanitizer diagnostic; this does not prove absence of all undefined behavior or satisfy other sanitizers/platforms.

The pass is for authored single-span compact-field masks and refusals under the pinned Linux compiler/UBSan command. It is not a captured-room/profile pass, rasterizer integration result, native Apple/API adoption, route/collision/full-support validation, sensor freshness/full-body evidence, app activation or physical/child-use authority. The earlier source-review coverage gaps remain open. Published old-policy paths were not changed by this experiment.

Review actions were lightweight source/count/hash/JSON and exact git-blob inspection only. No rerun, native build, dependency installation, app edit, push or permission escalation was performed; no denial occurred. The attempt files were left unchanged. Root owns publishing the compact result checkpoint.
