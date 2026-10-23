# Companion conversation evaluation: v3

## Scope and result
A fresh runner received only a frozen input packet with fictional actor state and scripted tool facts. Twelve integrated day-to-day journeys contained60 turns. A separate evaluator graded all raw outputs against a rubric frozen before execution.

First pass:57/60 turns fully satisfied the rubric;177/180 dimension points. Two search answers omitted a useful next step. One familiar-person announcement was unqualified despite a requirement for tentative wording. No fabricated physical measurements or external sends and no unsafe movement/reaching instructions were observed. Spoken replies averaged16.66 words, with maximum35; two event turns correctly remained silent. Latency was not measured.

A single general-instruction refinement was then given to a new isolated runner with three newly authored journeys,12 new turns. Followup:12/12 met the frozen followup rubric,36/36 points. This does not erase the original failures or establish100% real-world accuracy.

## Useful behaviors exercised
- Goal retention, interruptions, changing tasks, pronoun resolution and ordinary questions with camera off.
- Last-seen object history distinguished from present location; wrong-room correction, localization failure and limited-view non-detection.
- Automatic known-person, note and shopping-list events; encounter deduplication and VoiceOver deferral.
- Food/allergen, unknown heat, reach-path and current identity uncertainty.
- Saudi notes separately verified, overlap not summed, fresh results after audio clears.
- Ambiguous held-versus-worn garment, unknown-light gray/white distinction, fresh neutral-light update.
- Explicit scan confirmation, quoted conversation rejection, scan limitations, mute with urgent hazard exception, camera resume and full session shutdown.
- Draft-only messaging with no fake completion when online actions unavailable.

## What this does not prove
The fixtures supplied correct perception facts. They cannot measure detector accuracy, false familiar matches, native camera associations, Saudi note recognition, map relocalization, battery, thermal load, interruption latency or VoiceOver on device. Tool result records are scripted, not actual executions. Current app implementation is not inferred from these responses. Cloud-model performance is not on-device-model performance.

The followup's four physical search continuations asked another person to help. This meets the frozen fallback contract where localization/reach/controller support is unavailable, but it is a product-capability limitation, not evidence that autonomous assistance is complete. A future capability-enabled journey should verify that the assistant actually uses supported search/relocalization actions rather than making adult help its default.

## Audit and provenance
Original and followup input/rubric hashes and freeze times are in their separate manifests. Raw response copies are preserved byte-for-byte, with hashes in grade files. Grades disclose rubric ambiguities rather than silently rewriting criteria. Prior v1/v2 evaluation cases were not reused. These are authored held-out-to-runner cases, not a representative sample of real users or an independently calibrated statistical benchmark.

See pass1_grade.json and followup_grade.json for all per-turn scores, failures, and raw utterances; MODEL_INSTRUCTION_REPAIR.md for the exact bounded refinement and source-policy implications.
