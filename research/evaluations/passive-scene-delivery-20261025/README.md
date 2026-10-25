# Passive automatic scene delivery increment

## Result and scope

Candidate only; no shared source changed or pushed. Base native NavigationModel is the checkpoint25 proposal, with SHA256 in evidence/native-base.sha256. New policy uses bounded normalized independent observation content and real completion callbacks; this is not a semantic recognizer, scene equivalence, perceptual accuracy or physical authority.

Production changes: new Core PassiveSceneDelivery; native scene admission/completion/cancellation integration. Regression files: PassiveSceneDeliveryTests.swift and passive-scene-delivery.test.mjs. Automatic scene dedup moves from admission-time companion key/revision to one pending and one completed evidence signature. All companion budget, rate, quiet, focus, priority and existing scene freshness/pose gates remain. Explicit requested answers/repeats and independent warnings never consult the new policy.

## Actual source provenance

Native readScene calls VisionService.inspect(capturedImage). VisionService.swift lines45–70 constructs .text from VNRecognizeTextRequest top candidate string, .people from filtered VNDetectHumanRectanglesRequest count, and .object from VNClassifyImageRequest identifier. SceneContext filters this evidence for freshness/confidence and bounded detail. Wearable .range additions are excluded from novelty signatures. confirmedObjects uses VisualGrounding.agreedObjects over the initial Vision grounding plus later VisionService.groundingFrame outputs (classification/optional detector). No LocalImageAssistant model result or model-generated metadata is used: its describe call happens after the signature and pre-generation suppression check.

Normalization is canonical Unicode, lowercasing, whitespace collapsing and sorted exact set membership. Numbers, punctuation, negation and different content remain distinct. This does not suppress arbitrary synonyms/paraphrases in OCR/detector labels, nor detect changes absent from these sensors. Empty independent evidence is not permission to infer freshness from answer wording. Confirmed labels retain the existing grounding criteria; this repair neither improves nor certifies recognition accuracy.

## Ownership and completion

Owner includes assistant session, camera frame session, perception generation, room identity/visit count, map/alignment and preferences revisions. Individual capture timestamp/ID is not content novelty. Exact current owner is checked before model generation and before pending narration reservation. Completion is keyed by narration UUID; only completed/current-owner events commit. Rejection, cancellation and ambiguous completion stay retryable under normal budgets/rate limits. Old callbacks cannot consume a successor. State is bounded to one signature and one pending record, with bounded input counts/bytes. A→B→A is admitted when genuinely different observed content was completed between A occurrences.

## Verification and limits

- Original exact native revision expression reproduced a failure: two authored answer paraphrases with zero observations mint unequal nonempty revisions. evidence/baseline-empty-evidence.log retains expected exit1; this is source-expression reproduction, not a live model/audio run.
- Focused XCTest runs use actual policy, exact SceneObservation declaration, and actual CompanionAttention/AssistantPreferences/NarrationBudget/SpeechPriority/SpeechDeliveryLedger/NarrationDelivery source copies. Final log is evidence/swift-final-test.log. Source manifest lists copies.
- Native exact-block projection executes actual scope getter and generation/dispatch/cancel/completion blocks with stub containers: 12 assertions pass. Not UIKit/ARKit/audio execution.
- Three source integration contracts pass; native Swift syntax parse passes. Neither is Apple typecheck.
- Initial test attempt failed writing default /home/agent/.cache/clang (read-only filesystem). Original failure retained. Rerun configured compiler/SPM outputs to owned scratch; no permissions escalation or protected-path reads.
- Independent reviewer found no blocking defect; actual Apple SDK build and runtime, plus final merged-source full Core/Node aggregates remain required.

Do not claim tracker/whole feature complete or native readiness. No calibration, detector thresholds, physical gates, voice authority, assets or network paths changed.

Final focused result: 8 XCTest methods / 0 failures, including actual CompanionAttention + SpeechDeliveryLedger composition: interrupted attempt → normal rate-gated retry → completed attempt → same-evidence suppression, with explicit requested answer and independent hazard bypass. The initial composition fixture used nonexistent enum case `.cancelled`; corrected test-only to real `.interrupted`, retaining original compiler failure. Production hashes did not change. Native projection count corrected to 12 and rerun; three Node contracts and native parse remain passing.

## Full portable aggregate and diagnostic-only successor

Frozen executable checkpoint25 plus the four passive source/test files passed 1,257 Core tests and 444 serial Swift-enabled Node checks (zero failures/skips). Exact before/after validation manifests are identical. Subsequent public head 7980bd1649810c6e89f1cbd90674cf27355c8ad6 adds seven isolated accessibility diagnostic/test/evidence paths, not production behavior. They were overlaid only after that aggregate terminated.

The affected final projection initially exposed one outdated source-contract assertion that rejected every continue-on-error entry. The actual workflow deliberately continues only its layout recorder, always runs the unsuppressed audit, then explicitly fails if layout did not succeed. The fifth proposal file narrows that assertion without changing workflow behavior: job/audit continue-on-error remain forbidden, layout-only continuation plus final always()/exit1 are required, and missing screenshots remain errors. Six negative mutations cover removed final guard, exit0, broadened job/audit continuation, missing always audit and artifact warning substitution. Original failing 15/16 projection receipt remains retained. Corrected final projection passes 16 affected Node checks, zero skips, plus 10 exporter tests. No second full aggregate is claimed for these test-only successor changes; all Core and app production source hashes are unchanged from the frozen aggregate.

Publication must use the latest parent tree and preserve its unrelated diagnostic/voice files. No shared source or remote publication was performed by this task. Owned inactive build/cache outputs were deleted only after aggregate exit0; full logs and subordinate execution receipts retained.
