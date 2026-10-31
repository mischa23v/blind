# Narrow local visual-claim checker — backlog and source audit

Recorded 2026-10-28. **Pending, behind navigation. No checker implemented, backend selected, model calls made, or accuracy/latency tests run.** The user's latest request adds this narrow local checker to the tracker; it does not resume hosted Jev integration or the broader deferred verifier workstream. See [Jev research](JEV_IMAGE_VERIFICATION_REVIEW.md) for the separate hosted product review.

## Intended scope

A silent, small, on-device check of **one ordinary visual claim against the same captured picture**: for example, “the refrigerator door is closed.” Not a second conversational assistant and not a replacement navigation controller. The request contains the claim, target, exact frame/request identity and capture time. A compact result distinguishes `supported`, `contradicted`, and `uncertain`; any score must have measured calibration for this task, not merely a model's self-reported confidence. “Not supported” is not automatically “false.” No cloud, private-image uploads, new model download or execution is authorized by this backlog entry.

Initial scope should be one narrowly labelled state task, such as refrigerator open/closed/not-observable. Wrong-target, occluded, ambiguous and missing-image cases must remain possible. A single check is the intended runtime operation; do not assume a multi-agent conversation or repeated resampling is needed. Whether an existing phone-local visual backend is adequate remains unmeasured.

## Current source pipeline: distinguish pixels from text

Audit baseline: app source commit `fee8c7da4e85cb279d93cdedf881b4f016b384ad` on `codex/recovery-hazard-order-20261027`. Local `LocalImageAssistant.swift` was compared byte-for-byte with that remote file; local `NavigationModel.swift` SHA-256 matched the published checkpoint (`5275400e782a88374641aa0b61d2c85b1d35f20330b58e5b2d86b7b9626b4d67`). Remote project compilation conditions were inspected directly. Line references below refer to that baseline; later edits may move them.

| Stage | Existing behavior | Source |
|---|---|---|
| Camera acquisition | Requires running camera and a recent frame; captures pixel buffer, capture time and request UUID | `ios/BlindAssist/NavigationModel.swift:2535–2538,2573–2576` |
| Pixel processing | Apple Vision OCR, human rectangles, image classification and optional bundled CoreML detector consume the pixels | `ios/BlindAssist/VisionService.swift:43–67` |
| Category agreement | Up to three frames are checked; categories need agreement in at least two | `NavigationModel.swift:2593–2608`; `BlindCore/Sources/BlindCore/VisualGrounding.swift:130–138` |
| Optional pixel language model | `Attachment(image, orientation: .right)` is supplied only under `BLIND_APPLE_MULTIMODAL`, FoundationModels import, iOS 27 and model/language availability | `ios/BlindAssist/LocalImageAssistant.swift:1285–1314` |
| Default project | Debug/Release app settings do **not** enable `BLIND_APPLE_MULTIMODAL`; defaults are inherited conditions with DEBUG only in Debug | `ios/BlindAssist.xcodeproj/project.pbxproj:139–140` |
| Default fallback | The language model receives observation JSON, selects IDs, and code renders existing observations—not freely generated visual descriptions | `NavigationModel.swift:2650–2662`; `ios/BlindAssist/SceneQuestionClient.swift:83–94`; `BlindCore/Sources/BlindCore/OnDeviceLanguage.swift:53–67`; `BlindCore/Sources/BlindCore/SceneContext.swift:50–74` |

**Therefore the default committed build sends pixels to Vision, not to the local language model.** Telling that text-only selector to look again at a photograph cannot supply image input it does not receive. A separately generated or installed build may enable the optional adapter; the user's installed version and flags were not inspected. This audit does not establish the cause of an earlier reported fridge-state error.

The unavailable-camera path also has a domain guard before ordinary conversation (`NavigationModel.swift:4354–4361`). Do not treat every spoken answer as originating from the same image backend.

## Existing protection and missing checks

- Request cancellation/UUID, goal/preferences/map revisions, people/sensor freshness and view checks exist at `NavigationModel.swift:2653–2654,2665–2684`.
- `SceneContext.swift:82–94` permits delivery only with normal tracking, observing state, current frame age at most 0.5 seconds, original capture age at most 12 seconds, camera displacement at most 0.5 m and heading change at most 30 degrees. These are view-delivery bounds, **not evidence that a refrigerator door or chair occupancy remained unchanged**.
- `VisualGrounding.swift:163–169` filters absence/ownership/direction claims and checks mentioned object categories; hedged claims can pass. Agreement that a refrigerator exists does not verify that it is open or closed. The inspected scene lane has no dedicated refrigerator-state correctness check.
- The optional image model's immediate return validation checks nonempty/bounded text (`LocalImageAssistant.swift:1319–1321`), not perceptual truth. Spatial, money and colour guards still apply downstream (`NavigationModel.swift:2686–2715`).
- Debug trace records request correlation and omits the image payload (`LocalImageAssistant.swift:1309,1334–1348`). Logging a prompt or receiving an answer alone does not prove that a backend received the intended picture.

## Separate provenance from accuracy

**Code-checkable provenance:** bind request, exact frame identity, timestamp, target and backend capability; confirm that the actual selected backend received the intended pixels, or explicitly record `text observations only`/`unavailable`. Bind the returned decision to that immutable input. Reject cancelled, superseded, expired or mismatched results. Retain only necessary local metadata, respecting image-retention policy. Do not upload or retain raw pictures merely to demonstrate delivery.

**Empirical perceptual accuracy:** whether the claim agrees with visible reality. Correct image delivery cannot prove that a model relied on pixels, recognized the target, or interpreted its state correctly. Behaviour under paired image changes provides evidence of grounding, not proof of internal reasoning. Never report a provenance pass as a correctness pass.

For asynchronous checking, any correction must identify the original answer and its captured view; it must not describe an old snapshot as the current state. The checker remains silent when there is no actionable correction. Uncertainty needs an explicit policy, not conversion to reassurance. Physical movement, clearance, object handling and hazard authorization remain with their code-owned evidence gates; a late conversational correction is not a safety mechanism.

## Future evaluation contract — not executed

Before implementation evaluation, freeze labels, scene-separated development/holdout split, backend/version, input resolution, target policy and decision thresholds. Use consented/developer-owned local images; never infer correctness from agreement with the first model.

1. **Same-image claim pairs:** true and false state claims, wrong target, partial opening, occlusion, poor lighting, blur and not-observable cases.
2. **Grounding controls:** swap an open/closed image while keeping wording fixed; change wording while keeping image fixed; omit or blank the image. Missing images must not yield a valid grounded result. Do not let paired frames leak across development/holdout splits.
3. **Accuracy:** publish counts/confusion matrix, false acceptance of wrong claims, false contradiction of correct claims, abstention/coverage and breakdown by scene/condition. Do not collapse these into one “accuracy” percentage.
4. **Calibration:** if a probability is exposed, specify what event it estimates, assess reliability and a proper score (such as Brier score) on held-out data, and show coverage/error at thresholds. If calibration is absent, label the score uncalibrated or omit it; do not promise a calibrated score merely by prompting for one.
5. **Latency/resources:** measure end-to-end frame acquisition/preprocessing/inference/decision delivery and correction delay; report cold/warm p50/p95 and sustained thermal/memory impact on the actual target phone while navigation runs. One-token output may reduce decoding, but does not establish low visual-inference latency. No sub-second result is claimed.
6. **Ownership/staleness:** wrong request/frame, cancellation, supersession, backend downgrade, delayed result and scene change must be explicitly exercised. Preserve failure records.

Acceptance thresholds require a written protocol before evaluation. Passing a refrigerator-state benchmark does not validate general scene understanding, navigation, stairs, or use with children.

## Next action when prioritized

Inventory the already available on-device pixel-capable backend, then implement the smallest provenance-bound single-claim adapter only after its scope is resumed. Navigation remains the active priority. This document is the handoff so the requirement is not lost; it is not a completed feature.
