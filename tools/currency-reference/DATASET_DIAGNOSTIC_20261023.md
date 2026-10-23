# Actual-photo diagnostic, 23 October 2026

**Not ready for reliable monetary use. The app profile stays disabled.** No training, app enablement, photo publication, or device validation was performed. This report supersedes the absence of fresh photo evidence in the older recovery notes, not their historical results.

## What was verified

The user's four-part transfer reconstructs a 6,752,380,788-byte ZIP with SHA-256 `6cc0c351a98f42bb72f4244870982dec5a589eb14249092ce0b9c0cff22fb3ea`. Every part, nested ZIP CRC and extracted file was checked. Safe extraction yielded 2,000 JPEGs, 2,000 Pascal VOC XMLs and two metadata files. Each denomination (1, 5, 10, 20, 50, 100, 200, 500) has 250 photos. All annotations contain one object. No duplicate JPEG hashes were found.

Source: [Mendeley dataset, DOI 10.17632/7sys44td9c.1](https://data.mendeley.com/datasets/7sys44td9c/1), Nazmul Ahasan Maruf, Abdullah Basuhail and AHM Adil, published 10 January 2022, stated CC BY 4.0. Dataset licensing does not by itself resolve [SAMA reproduction rules](https://rulebook.sama.gov.sa/en/circular-re-techniques-identify-banknotes). Images and reference packs are not part of this source change.

## Coverage and independence audit

- Publisher split: 1,800 train and 200 test. Forty-five filename capture families cross this split. Repeated visible serials and wear strongly indicate reused physical notes. Physical-note IDs and independent capture sessions are unknown, not invented.
- All 250 five-riyal images were visually reviewed: older paper design only, no polymer 5. This is not a complete current/legacy issue inventory.
- EXIF orientation normalization resolved all 312 raw dimension discrepancies. Every normalized full frame retains original and derivative hashes. No query annotation-box crop was used.
- Sixteen train-source references cover front/back of all eight values. Visible note corners were manually selected by an assistant from actual pixels, not VOC boxes. This is not human approval. Reference rectification uses the native-target 800-pixel maximum and mean opposite-edge dimensions. Curved/worn corners remain approximate.

## Initial fixed development comparisons (before scene veto)

The existing unvalidated thresholds were unchanged. OpenCV 4.14.0, one CPU thread, OpenCL disabled; Python grayscale decoding is not verified equivalent to Apple's camera pipeline. The initial diagnostic used four deterministically spaced publisher-test frames per value, producing 32 queries. The complete 200-frame development rerun is recorded below. These are **same-collection diagnostic cases**, not independent held-out notes. The three methods saw the same frames and references.

| Method | Correct experimental labels / 32 | Wrong labels | Abstentions | Unsafe accepts, separated composites / 9 | Unsafe accepts, overlap composites / 8 |
|---|---:|---:|---:|---:|---:|
| SIFT | 14 | 0 | 18 | 0 | 4 |
| ORB | 13 | 0 | 19 | 1 | 4 |
| AKAZE | 12 | 0 | 20 | 0 | 4 |

All methods rejected three high-confidence actual negative photos: a mug, a banana, and a hand-held USD $100 fan. They also rejected one auxiliary banknote-ceiling photo whose small notes cannot all be identified; that scene is not counted as a clean negative-accuracy sample. Provenance: [mug](https://commons.wikimedia.org/wiki/File:Mug_image.jpg), [banana](https://commons.wikimedia.org/wiki/File:Banana_in_hand.jpg); full private provenance retains foreign-photo attribution, source revisions, hashes and reproduction restrictions. No photo is redistributed here.

The 17 composite cases are explicitly synthetic arrangements of reference pixels, not independent physical photographs. The nine separated cases contain each denomination's front/back plus a 100-and-1 pair. ORB falsely accepted the separated 1-riyal front/back pair. Eight overlap cases use 100/1, 1/100, 5/5 and 20/200 with 25% and 65% overlap. **Every method accepted four overlapping scenes that should have been rejected.** A correct visible denomination in a two-note scene is still a safety failure. See the accompanying JSON for exact case-level outcomes and evidence hashes.

SIFT has the best provisional recognition count here, but there is no validated winner. Zero wrong values in 32 related photos does not establish a safe error rate. Timings include repeated cold reference loading/extraction on desktop and are not phone latency.

## Code changes and fresh checks

The Python reference preparation and geometric arithmetic were aligned more closely with the existing native implementation, with boundary regressions. A separate strict held-out runner now validates source/identity graphs, separates calibration from one frozen test method, pins inputs/code/policy, rejects unsupported independence, records execution failures separately from abstention, and reports costly confusions and missing coverage. It does not manufacture independence for this dataset or enable the app.

Fresh checks: 141 Python reference/evaluator unit tests, 37 shared metric tests, 150 Node tests, and all 467 Swift core tests passed. Swift 6.4.1 on Linux executed the 34 reference-policy tests, including 12 new secondary-scene veto tests. These are policy/plumbing checks, not banknote-accuracy observations. Apple SDK, iPhone camera/Vision and exact C++ OpenCV image-oracle validation remain unavailable. C++ feature extraction is unchanged; the Swift rejection policy is compiled and unit-tested, not device-validated.

## Rejection-only correction and complete development cohort

The new scene veto preserves all existing denomination-acceptance and score-margin thresholds. Strong partial-note evidence may reject a value, never qualify for acceptance. Supported distinct instances of the same reference, or supported noncoincident note polygons with IoU below the existing Swift 0.80 boundary-agreement threshold, cause abstention. Coincident alternative labels remain subject to the original score-margin gate. An unconditional cross-label veto was discarded because shared printed motifs caused excessive false retakes; that exploratory replay is not hidden or presented as an unseen test.

Fresh inference used all 200 publisher-test photos, with unchanged references and frozen matcher source `f8c401a855c4194842b507d1647fd0539abf2dcf2a04c4462bb2e84a08c99b65`. The 32 earlier queries are a subset, not additional independent samples. The whole cohort remains related development data, and no policy was tuned during this run.

| Method | Correct experimental labels | Wrong values | Retakes |
|---|---:|---:|---:|
| SIFT | 63 | 0 | 137 |
| ORB | 52 | 0 | 148 |
| AKAZE | 61 | 0 | 139 |

No 100↔1 confusion was observed in this cohort. That is not proof of a sufficiently low costly-error rate. The 32 individually audited queries contain 11 essentially whole-face views and 21 folded/self-occluded views; many other cohort frames also require retakes, but their side/fold labels have not all been independently adjudicated.

All three methods now reject the eight original overlap stresses in fresh inference. SIFT and AKAZE reject all nine separated composites; ORB still accepts the separated 1-riyal front/back pair. All reject the three high-confidence external negative photos and the auxiliary clutter photo.

Twelve additional synthetic challenges were prepared before the correction's source freeze: nine heavier back/front overlaps at 40/80/90% plus three SAR-with-foreign-photo collages. SIFT rejects all nine known-SAR overlap challenges but accepts the three SAR-plus-USD scenes. ORB has seven unsafe accepts and AKAZE six. Those three SIFT failures contain a 1, 100 or 500 SAR note alongside an unsupported USD fan photograph. They demonstrate the unresolved scene-level problem, not a wrong Saudi denomination. None is an independent physical multi-note photograph. SIFT is the most promising development method in these tests, not an activated or certified winner.

The scene veto cannot recover descriptors discarded inside a first projected note, see a fully hidden note, or match a foreign design absent from the reference pack. [Find-Object's BSD-licensed residual-homography approach](https://github.com/introlab/find-object/blob/0a00ade03f9f3741ba47d0179e93b97d2c98ee3d/src/FindObject.cpp#L1788-L1814) is a useful multi-instance research direction, but was not imported and does not solve unsupported currency detection. The current source already uses scene-to-reference matching, bounded secondary hypotheses and stronger geometry than several inspected example repositories. No unverified repository accuracy claims were adopted.

## Final malformed-evidence hardening

After the full inference run finished, a rejection-only numeric/structure guard was added to the Python decision entry point. It preserves legitimate geometry-less early feature failures but records corrupt/missing/nonfinite evidence as an execution error instead of silently accepting another candidate. Final matcher SHA-256 is `43f452248a06fec748d3f870a8315e9c2a968d1aef0dd55ddc782bff93790653`.

All 233 stored cases across three methods (699 decisions, 11,316 candidate records) were replayed through the final guard with no decision-payload differences. This is saved-candidate replay, not 699 new inferences or independent samples. The original full-run source hashes and report bytes remain preserved. A separate four-case fresh-inference smoke check covers a previously accepted real photo, a real retake, a known overlap and an unsupported-foreign-scene failure. No safety claim is inferred from this smoke check.

## Release blockers

1. Supported-SAR plus unsupported-USD scenes still produce unsafe accepts. The existing Apple Vision single-note gate has not been exercised on these scenes; Python matcher results cannot establish that it fixes them. Residual matching against known SAR references cannot identify an unsupported foreign design.
2. Obtain independent physical notes/capture sessions and rights-reviewed, human-audited missing designs, especially polymer 5. Do not reuse these diagnostic results as an unseen test.
3. Validate real same/different/unsupported overlapping notes, foreign notes, screens/reproductions, nonmoney, folds, occlusion, glare and low light on intended iPhones, including speech, freshness, cancellation and attention gates.
4. Review rights before distributing any reference pack. Reference matching is not authenticity checking and never sums money.

The code/evaluation improvements may be reviewed independently. The money-reading feature is not ready to enable, and this document is not approval to push or deploy.

## Seeing AI / BankNote-Net comparison

Read-only source review found no drop-in no-training Saudi recognizer:

- [Historical SeeingAI-Currency-Detection example](https://github.com/xiaoyongzhu/SeeingAI-Currency-Detection/tree/74344fcb2e0ce5ce83a8bc38a62971c24d885107) is a 2018 MobileNet training example, not the full Seeing AI app. The notebook uses US-dollar front/back classes; its 14-class implementation differs from the README's 15-class background proposal. No Saudi model, complete class-map artifact, licence or test suite was verified. No weights were loaded or copied.
- [BankNote-Net custom trainer](https://github.com/microsoft/banknote-net/blob/57a6bf549879d6c6f700b6ba26724c957f770c5d/src/train_custom.py) freezes a MobileNetV2 encoder but trains a new classifier head. Its [prediction example](https://github.com/microsoft/banknote-net/blob/57a6bf549879d6c6f700b6ba26724c957f770c5d/src/predict_custom.py) uses argmax without a single-note or unknown-scene safeguard. Published coverage does not establish a Saudi head. This does not meet the current no-new-training direction as a ready replacement.

Their varied-background, front/back and negative-example evaluation ideas are relevant; neither removes the need to reject multiple notes and validate unseen physical notes. First-result document segmentation, repeated agreement, or switching feature families alone cannot establish that no second note is present.
