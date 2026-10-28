# Native validation blocked by repository privacy guard

**Observation snapshot: 2026-10-28 17:48 UTC.** Later authorization or reruns must be recorded separately.

The geometry-support candidate was published and remote-verified at `12a0b64bc403db3f48a997aea868b9ad670e73fb`. The resulting push workflow `40738486723` completed with both native jobs skipped. Neither job has steps or an allocated runner; there are zero artifacts. **No new Apple build or native test ran.** This is a workflow admission block, not a geometry failure, correction pass or parity result.

The observed job condition requires the named repository and review branch **and** `github.event.repository.private == false`. The repository is now private, so the public-only condition is false. This note records the observed condition; it does not infer who changed repository visibility or why. The parent has asked the user whether to adapt the private-repository CI guard and check runner billing implications. That decision was pending at the 17:48 checkpoint; this note makes no claim about subsequent authorization. No workflow, repository visibility, runner permission or billing setting is changed by this note.

## Correction status

GEO-02 is now **implemented as a reviewed diagnostic candidate**, not merely a proposal. The source-bound historical floor support representation is separated from raw exported solids, while non-floor triangles are retained. Native compilation, platform tessellation behavior, exact all-feature capture and independent triangle parity remain unverified.

Root validation retained: 32 source checks, 77 evidence collector tests, 17 same-export/extractor integration tests, nine route-contract tests, 18 canonical inventory checks, three project-mutation tests and 70 cumulative integration source checks. These are local source/portable checks, not Apple execution.

A direct combined Node run also recorded ten passes and one failure because the partial local checkout contained five app Swift files while the canonical project enumerates 65. The existing verified 65-name inventory reproduced the unchanged project separately. The failure is retained and is not turned into a full-checkout project pass. See [root validation receipt](../../roomplan-support-candidate-20261028/ROOT_VALIDATION.json).

## Open next gates

- Obtain the user's decision about the private-CI admission change and billing check; do not bypass the guard or change visibility.
- Run the exact candidate through Apple compilation and unchanged native regression cases after approved admission.
- Retain new exact same-export bytes and full all-feature witnesses; compare them with the independent reader. Older first-wall evidence does not establish the new all-feature capture.
- Only after geometry/support acceptance, rerun the frozen route/journey cases and full-body collision/support checks.
- RTAB-Map work may continue locally within its already approved budget. It does not substitute for this Apple validation.

Physical authority, navigation readiness and complete-tracker acceptance remain false/unestablished. [Observed skip and source endpoints](OBSERVED_SKIP.json).
