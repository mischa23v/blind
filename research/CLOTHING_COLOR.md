# Requested clothing colour appearance: implementation and limits

## Recovery and status

After workspace loss on 2026-10-22, ClothingColor.swift and its Swift tests were restored exactly from the intermediate GitHub tree. ClothingColorReader.swift, NavigationModel colour integration, the colour source-contract tests and this document were reconstructed from the reviewed source-writing history against the restored c4f7a26 baseline. This is source reconstruction, not a claim that lost bytes were recovered exactly. Fresh verification is recorded below; prior test counts do not establish recovery correctness.

This is an offline, requested-only, training-free **appearance estimate for a selected central patch**, not a calibrated fabric-colour instrument. It cannot certify a school uniform as white. Unknown illumination makes white/gray/cream intrinsically ambiguous. Every explicit precise-neutral/uniform request abstains, even if coloured light makes pixels look saturated. An input-level fallback prevents an unrecognized wording from eliciting an indirect model “yes, suitable”.

Voice examples: “What colour is this shirt?”, “Check the colour”, “ما لون هذا القميص”, “وش لونها”. Hold one separate item flat and close, upright in the centre, in even light. A person mask is rejected because it includes skin/hair rather than isolating a shirt. The measurement concerns only the central patch, not an entire patterned outfit. Background at centre, mask edges, inadequate coverage, substantial clipping/darkness, mixed colours and weak naming margins return uncertainty or retake guidance. There is no largest-object or whole-frame fallback.

## References and licences

- Apple Vision foreground-instance masks, already used by ItemAppearance: https://developer.apple.com/videos/play/wwdc2023/10176/ . The walkthrough documents UInt8 labels, strides, top-left buffer coordinates and instance selection. The reader normalizes orientation and renders encoded sRGB BGRA before both masking and sampling. Platform API use does not vendor a model or third-party source.
- Colour Science reference operations (BSD-3-Clause): https://github.com/colour-science/colour ; https://colour.readthedocs.io/en/latest/generated/colour.sRGB_to_XYZ.html ; https://colour.readthedocs.io/en/latest/generated/colour.XYZ_to_Lab.html . The Swift core expresses standard IEC sRGB transfer, D65 XYZ and CIELAB equations. It does not import Python or vendor upstream source. Reference documentation reviewed was 0.4.7.
- Broad candidate differences use **CIE76**, not CIEDE2000. A more elaborate difference formula cannot recover unknown illumination. Upstream mathematical tests are evidence for reference math, not this garment integration: https://github.com/colour-science/colour/blob/develop/colour/difference/tests/test_delta_e.py .
- Independent mathematical fixtures were originally generated with installed OpenCV 4.14.0 float32 RGB2Lab, using a 0.25 Lab-unit tolerance for its lookup approximations. These exact fixtures are in the recovered tests; they were not regenerated during source recovery. Conversion reference: https://docs.opencv.org/4.x/de/d25/imgproc_color_conversions.html . Colour adds no OpenCV app dependency.
- Color Thief (MIT), https://lokeshdhakar.com/projects/color-thief/ , was considered but not adopted: palette extraction is not an intrinsic fabric classifier, and the default ignores white pixels.

The broad named palette, distance/margin and coverage thresholds are **unvalidated product policy**, not a trained model, measured fabric catalogue, naming standard or probability. Muted colours may abstain. Repeated pixels cannot eliminate systematic illumination error. Do not advertise these thresholds as confidence percentages.

## Privacy, speech and stale results

No frames or samples leave the phone or are saved by this path. No LLM chooses or rewrites the colour result. Shared cancellation, request/session generation, current hazards, tracking, map revisions, fresh frames, stationary and portrait checks gate delivery. A separate close-object pose gate rejects translation of 10 cm or more and optical rotation of 5 degrees or more, including pitch. It cannot track an independently moved garment; speech explicitly refers to the sampled **captured view**, not the current garment. Requested-answer budgets still apply, with no separate speech sink. Automatic scene descriptions do not interrupt the check. Model-generated/stored common colour claims are vetoed; verbatim code-produced OCR is not rewritten.

## Verification boundaries and acceptance

Fresh recovery checks on 2026-10-22 passed: 12/12 filtered Swift colour tests built from the restored full BlindCore package, 18/18 combined colour/currency/attention source-contract tests, and parsing of the reconstructed native reader plus integrated NavigationModel. These are fresh recovery results, not carried-over historical passes. Synthetic Swift tests cover conversion references, recovered OpenCV fixtures, malformed samples, short inputs, clipping, mixed patterns, broad candidates, neutral abstention, English/Arabic command boundaries, full-axis pose and stale/future timestamps. Source-contract tests check routing and gates, not runtime Vision behavior. Native source parsing is not an iOS build. Vision execution, CoreImage pixel behavior and actual camera/fabric accuracy require an Apple SDK/device.

Before practical use:

1. Build and run the real Vision/colour pipeline on supported iPhones. Check portrait/rotation, cancellation, new requests, tracking loss and hazard arrival during inference.
2. Test target selection against contrasting backgrounds, edges, skin/hair, gloss, shadows, dark fabrics, folds and patterns. Never substitute a supplied mask for this capture test.
3. Use independently measured/labelled physical white, light-gray, ivory/cream, pale tints and washed/yellowed fabrics. Hold out garments, sessions and phones from tuning. Cover daylight, warm/cool LEDs, mixed light, distances and exposure transitions.
4. Report wrong appearance estimates, abstention frequency and retry success separately. Definite-white claims must remain absent because this version never makes one. Screen RGB swatches do not establish physical fabric accuracy.
5. Evaluate spoken centring and retry instructions with blind users after controlled sighted checks. Do not assume visual aiming or screen inspection.

Intrinsic near-neutral recognition needs a known reference under the same illumination or a validated controlled-capture method plus held-out real-device evaluation. School acceptance additionally needs the school's agreed reference. No hidden switch converts this uncertain reading into certified white.
