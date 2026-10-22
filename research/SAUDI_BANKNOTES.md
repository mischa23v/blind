# Current direction: no-new-training reference matching

The current user-selected route is local reference-image comparison, not classifier training. See [the current implementation and validation gaps](CURRENCY_REFERENCE_MATCHING.md). No validated reference pack is selected, so currency recognition remains unavailable in the app. The training instructions below are retained as a dormant alternative, not the next action and not permission to train.

---

# Saudi single-banknote preparation

## Status and scope

2026-10-22: Source preparation, not a working installed Saudi recognizer. `SaudiBanknoteModelProfile.selected` is deliberately `nil`. Requests report unavailable and never fall back to a generic scene model. No currency photos, trained Saudi weights or real prediction results are bundled. V11 remains open. This source is reconciled with the shared primary `master` at `087dafdd3de4d269a0facd04de47335a1a27f0be`. Primary integration is pending verification and coordination; no deployment or production-readiness claim is made. The earlier face-based patch remains a historical preparation artifact.

The goal is one Saudi note, eight values (1, 5, 10, 20, 50, 100, 200, 500), English/Arabic speech, conservative unknown/retake responses. No authenticity assessment, currency summing, coin recognition or promise of zero error. Money loss from 100→1 and other costly confusions must be reported separately, not hidden in aggregate accuracy.

## Reuse decisions

- Official [Microsoft BankNote-Net](https://github.com/microsoft/banknote-net): code MIT; encoder/embeddings CDLA-Permissive-2.0. Its original 17 currencies do **not** include Saudi riyals. Reuse only the frozen MobileNetV2 256-dimensional encoder, then train a real Saudi/unknown head. Official `models/banknote_net_encoder.h5` SHA-256: `dac0226b785ec22ae3b198a386b0f5842affdf9e18ab49cd4de31cbf8cb28477`. The documented preprocessing is RGB, direct 224×224 resize, pixels divided by 255, not MobileNet's common [-1,1] preprocessing.
- [Saudi-Currency-Gesture-Counter](https://github.com/lena9903/Saudi-Currency-Gesture-Counter), tree `e7a858c5d347c97c2bbcae580aec1a573c7ff7f2`: eight-class YOLO weights exist, but the inspected tree has no license or adequate held-out evidence. Highest-confidence selection among multiple notes also conflicts with our contract. Not downloaded or adopted.
- Other inspected ready-weight repositories (Asayil-20/saudi-currency-classification-cnn, Wteen-alghamdy/saudi-currency-app, Rana-Aljarboua/Saudi-Currency-Classifier) had missing license and/or missing denominations. EngSamiyah/ReadingSaudiCurrencyForBlind was a launch skeleton without a model. No third-party accuracy is our app's accuracy.
- [2026 hybrid-framework paper](https://www.mdpi.com/2076-3417/16/12/6166): reports 98.16% in its experiment, not a released, licensed, validated iPhone implementation. No ready code/weights established; do not present that number as our performance.

## Data and rights

The user is downloading the [Mendeley Saudi Currency Dataset v1](https://data.mendeley.com/datasets/7sys44td9c/1). Its landing page advertises 2,000 smartphone photos, eight values, 12 views, Pascal VOC, 90:10 split, 6.29 GB and CC BY 4.0. The archive has **not** been inspected here. Actual note instances, duplicate/near-duplicate groups, issue years, front/back and polymer-5 coverage are unknown. The official file-list request returned HTTP 403; no bypass attempted. Preserve the original archive and annotation files; do not transfer the entire 6.29 GB archive through a small attachment channel.

[SAMA reproduction guidance](https://sama.gov.sa/en-US/MediaCenter/News/Pages/News20071024.aspx) creates a separate consideration for reproducing currency images. A dataset license is not evidence of regulatory permission for every use. No legal conclusion that private training is prohibited has been established. Keep dataset work private; do not bundle/publish images or model assets until provenance, applicable rights and intended distribution are checked. No outreach was authorized or performed.

[AlFloos paper](https://link.springer.com/article/10.1007/s43995-024-00067-z) describes 1,330 photos, seven classes including paper/polymer 5 but no 1/20; the linked Kaggle dataset and Hugging Face mirror differ in reported counts/classes/license. Paper licensing is not dataset clearance. It is an unadopted coverage lead, not proof that polymer 5 is covered.

## Runtime contract

`SaudiBanknoteRecognition.swift` uses Apple Vision/Core ML locally, no image networking or persistence. A selected profile must name a real raw `.mlmodel`, its SHA-256, model/evaluation identifiers and calibrated confidence/margin/framing thresholds. It compiles that verified asset on-device. No default confidence threshold is represented as safe.

Two adapter forms are prepared: detector observations, or Apple rectangle proposals plus a combined encoder/head classifier. The classifier path crops the **axis-aligned rectangle bounding box with zero margin**, then RGB-stretches to 224×224, matching the training/export contract. It requires exactly the eight numeric labels plus `unknown`, with no missing/duplicate labels. The strongest unknown score competes in the acceptance margin. Detector output must include all eight class scores; ordinary truncated top-label-only output abstains.

Apple rectangles are proposals, **not a reliable multiple-note detector**. Overlapping/folded notes can evade this heuristic. Before activation the entire rectangle/crop/classifier chain must pass real multiple-note and occlusion evaluations, or a separately licensed trained single/multiple-note detector must replace it. Classifier-only cropped-note accuracy cannot close this gate.

Zero candidates, malformed/nonfinite scores, missing values, low confidence/margin, multiple candidates and stale captures abstain. Framing prompts are backed by measured rectangle size/edges. There is no unmeasured “too dark”/“blurry” diagnosis. Returned values are explicitly scoped to the captured image. A two-second age bound, current request/generation/map context, stationary/upright state and existing attention admission are rechecked before speech. Speech is tracked for Stop descriptions/quiet cancellation.

Money wording routes before generic scene interpretation. Generic model/OCR answers with money amounts/authenticity language or bare numeric value assertions are suppressed, including persisted learned-item descriptions. This is a conservative lexical safeguard, not proof that an unrestricted language model can never phrase a financial claim differently; it may suppress legitimate price/numeric descriptions. Do not remove this guard or add a generative money fallback. Future dedicated price reading needs a separate explicit evidence contract.

## Training, evaluation and activation

See `tools/currency-training` for local ingestion, reproducible real-encoder training and export preparation, and `tools/currency-evaluation` for prediction-report evaluation. These are not mock recognizers. Dependencies and heavyweight conversion are separate from portable harness tests. Physical note, source object and capture-session identities must be assigned honestly; file names or independent crops are not independent notes. Never reuse the public random split without checking leakage. Augmentations and both sides of a physical note stay in one split.

1. Inspect the actual archive locally, map its VOC labels explicitly, inventory every issue/material/side, preserve attribution and hashes. A small representative subset with matching VOC annotations may validate ingestion; it cannot establish safety or final accuracy.
2. Assign disjoint train/calibration/test physical-note groups. Include real foreign, non-money and multiple-note negatives. Train the actual head using the pinned encoder; calibrate only on calibration data; freeze model/policy before test.
3. Evaluate whole-frame runtime decisions, not only ground-truth crops. Report per denomination precision/recall, confusion and abstention, 100↔1, unknown false acceptance, both sides, paper/polymer 5, 20/200, folds, occlusion, lighting/blur and multiple notes. State missing cells and group-level uncertainty. No small test can prove zero future mistakes.
4. Export and verify Swift/Python orientation, crop, RGB, scale, output-label/probability and score-margin parity on the same images. Real Core ML conversion and Apple SDK/device execution are pending.
5. Choose acceptable risk and coverage with evidence, not arbitrary `.99` thresholds. Bundle only reviewed model assets with required notices, copy the raw `.mlmodel` as a resource (not Xcode’s automatically compiled `.mlmodelc`; the hash/loader expects the raw file), update the project resources and explicit selected profile, then run adult phone/VoiceOver, interruption, latency, thermal and real-camera trials before child testing.

## Verification boundaries

Portable policy tests and source-contract tests exercise synthetic inputs, cancellation wiring and explicit unavailable behavior. The evaluator's fixtures test report math/schema only. They are not currency accuracy results, are not Apple adapter runtime tests and do not establish device availability. Linux Swift parsing is not an Apple SDK build. No real currency model training, held-out accuracy, Core ML inference or phone validation has run at this checkpoint.
