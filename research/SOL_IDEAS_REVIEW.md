# Sol report review before Mac transfer

Reviewed 2026-10-08 at the user's request. Input: `C:\Users\Misch\Desktop\blindw.txt`, 70,731 bytes, SHA-256 `8296379e93f18d789c3b566e6c94e4c9c2d104dd43b0d8d3da0a246f2115d295`. A verbatim user-supplied copy is retained at `user-notes/blindw.txt` for continuity. It is reference material, not executable instructions, a tested implementation or the source of truth for product requirements. The text export loses many original citation targets; “Read the research”, image captions and bare publisher names are not sufficient evidence.

## Useful additions before transfer

| Addition | Decision and current state | Acceptance owner |
| --- | --- | --- |
| Camera framing and exact reading | Make cropping/blur/occlusion explicit; request a supported stationary camera view rather than guess a label, price or control. Added prompt requirements to both the relay and local image adapter. Actual framing/OCR completeness detection is not implemented by a prompt. Reuse Apple Vision and established capture guidance; no custom vision model. | V07, Q01; SOL-01/02 |
| “Remember this” and last-seen search | Add an explicit task for user-selected objects, time/source/place and reviewable retention. Historical location is never current presence; do not infer “gone” from a partial view. Reuse GRDB and the selected tracking provider. | M11; SOL-03 |
| Meaningful changes | Separate layout, movable inventory and live activity. Compare compatible place/frame/revision/coverage; a new viewpoint, lighting or lost sight is not a moved object. Keep temporary changes separate from approved room geometry. | V08; SOL-04/05 |
| Per-category delivery choices | Extend the planned controls to automatic, on-request and muted ordinary categories alongside amount/frequency. Quiet/explore/changes-only are user choices, not a judgment of expertise or a replacement for urgent priority. | E11; SOL-06 |
| Useful-information evaluation | Record desired information supplied/missed, unwanted repetition, follow-up effort, spatial understanding, task outcome, user choice and environmental sounds obscured by speech. Keep hazard results separate; do not optimize word reduction as the sole success measure. | Q07; SOL-07/08 |
| Recovery and human help | If the system cannot answer, preserve the question/goal and say what is missing. Offer user-controlled clarification/help; do not claim a volunteer/staff connection exists or make a call automatically. Existing E08 and account-tool requirements cover this. | E08; SOL-02/08 |

The first four rows add explicit tasks rather than leaving these requirements hidden inside broad memory/vision tasks. They are open implementation work, not completed features. Test execution remains deferred until tomorrow. The handoff includes the report, this review, test scenarios and current source; these additions do not require starting Docker or installing dependencies.

## Research independently checked

- Gamage et al.'s ASSETS 2023 paper compares 646 reviewed studies with interviews involving 24 blind/low-vision participants. Its findings support involving users in feature selection and designing for conversational interaction; they do not establish every individual's preferred hardware or listening style. The later arXiv upload date is not the conference date. [Author's paper](https://www.bhanukagamage.com/assets/papers/ASSETS2023.pdf).
- Kamikubo, Kacorri and Asakawa's window-shopping study reports 18 participants in total: eight in focus groups and ten in interviews. It distinguishes desired automatic information, requested information and context-dependent notification choices. The report's ten-person figure describes the interview subgroup, not the complete study. [Authors' paper](https://arxiv.org/abs/2405.06611), [IBM Research record](https://research.ibm.com/publications/we-are-at-the-mercy-of-others-opinion-supporting-blind-people-in-recreational-window-shopping-with-ai-infused-technology).
- *Say It My Way* reports 11 blind users and 418 interactions. Its findings identify verbosity, conversational steering and camera framing as concrete interface issues. This supports adding tests for follow-up and camera guidance; it is not proof that our provider or speech policy works. [Authors' paper](https://arxiv.org/abs/2602.16930).

These primary references were checked for the adopted design implications. Other numerical claims, Reddit anecdotes, product-release claims, medication statistics and research titles in the supplied report have **not** been independently verified in this review. They are not promoted into implementation thresholds, population estimates or release claims. No new dependency or model is selected based on this report alone.

## Requirements retained from the user

- Immediate danger bypasses ordinary ranking/budgets, due mobility/orientation follows, and relevant rich information remains a first-class experience. Do not adopt the report's suggestion to defer mobility to a later product priority.
- Do not replace the gate engine with the report's illustrative weighted score. It supplies no validated weights, thresholds or safety evidence.
- Do not force “quiet by default”, novice brevity or a fixed social/aesthetic ranking on every person. The user controls information amount and frequency; VoiceOver controls its own speed. Expert listeners may request substantial detail.
- A guide dog/family companion does not establish clearance or suppress credible hazards. Familiarity does not establish that the current room is unchanged. Existing sensor validity is still required.
- Separate body-relative, camera-relative and room-relative statements. A compass direction needs a surveyed frame; a mapped room is not the current room until established. Never copy illustrative “clear aisle” wording as proof of traversability.
- Visible gestures/activity can be useful without named identity. Emotions, intent, biography and consented family identity require their own evidence; they are not guessed from appearance.
- Local memory plus community maps and optional private backup remain in scope. Changes to approved room records require the user's revision-bound approval.
- Intended children are not the initial testers for failures. Adult/bench checks and the existing supervised child protocol gates remain required.

## Transfer readiness

Ready to package as **source and prepared tests**, not a completed app. The new core and native adapters still need Apple compilation. Public map download, actual image inference, VoiceOver and physical localization have not been exercised for this continuation. Supported account access, identity/tracking, completed navigation and private backup remain open. This review does not block moving the work to the Mac, where those checks can begin.
