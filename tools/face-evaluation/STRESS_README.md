# Bounded portrait stress experiment

This is an isolated research runner, not an app feature or a production acceptance test. It imports the hash checks and frozen policy from `image_smoke.py` and uses upstream OpenCV YuNet/SFace. It does not use Apple's Face ID, download assets, upload data, train a model, tune thresholds, save transformed photos, or save embeddings. All image transformations and features stay in process memory.

## Reproduction

Use the separately reviewed assets and isolated runtime described in README.md. From the repository root:

    /path/to/isolated/python tools/face-evaluation/stress_smoke.py --assets /path/to/approved-assets --output /path/outside/repository/face-stress-smoke.json

Original execution: Python 3.12.14, OpenCV 4.14.0, NumPy 2.3.5, one OpenCV thread. Exact model hashes, source URLs, credits, rights labels, source image hashes, every candidate/score/abstention, detected boxes and aggregate denominators are in the JSON report. The output must remain outside this repository. No images or model weights accompany this source.

Enrollment is the exact two original source captures used by `image_smoke.py`, with the same max-side-1024 preprocessing. Test captures are the two different-photo known probes and two other-person unknown probes, never enrollment photos. The source set contains six photos of four adults; there are only two known people and two unknown people. Public-figure training overlap is possible. Source rights caveats in README.md remain unresolved for redistribution/production; no source file is modified, and temporary inference transforms are not retained or distributed.

## Frozen matrix

Cosine threshold 0.363 and runner-up margin 0.1 remain unchanged. Detector score threshold 0.9, NMS 0.3 and topK 5000 remain unchanged. The 16 conditions were declared before this stress execution:

- Original photo.
- Gaussian blur, sigma 3, 7 and 15 pixels at baseline processing resolution.
- Pixel brightness multiplication 0.25, 0.5, 1.5 and 2, clipped to 8-bit range. These are not camera low-light/noise/exposure trials.
- Resize entire image to long side 256, 128 and 64 pixels using area interpolation. These are not measured camera distances.
- Black rectangular occlusion of the eye band (22–50% of original detected face-box height) or lower face (52–100%). These are not real-mask/glasses trials.
- In-plane rotation −20°, +20° and +45° about image centre on a fixed-size black canvas. These are synthetic roll only, never real yaw/profile/3D pose evidence.

Every condition is applied once to each of the four held-out probes: 64 correlated observations, not 64 independent people, captures or encounters. No rate estimate or confidence interval for real-world recognition is justified.

Separately, six pairwise combinations of those four portraits are placed in 512-pixel panels on a 1024×512 black canvas. A seventh declared diagnostic places one 512-pixel known portrait beside one 32-pixel unknown portrait. Every composite contains two source faces and should abstain for a single-person-scene policy. These are synthetic still composites, not crowds, live tracking, crossings or verified face-to-body association.

## Observed result, 2026-10-22

Across the matrix: 22 correct known observations, 10 known abstentions, no wrong known identities (32 known observations total). All 32 unknown observations abstained. Detection found no face in 17/64 observations; found exactly one in 47/64; no multiple-face detections in these single-portrait conditions. No detector/embedding runtime errors occurred.

Both known portraits matched in baseline, sigma-3/7 blur, brightness 0.25/0.5/1.5, long-side-256/128 and ±20° roll. Both known portraits abstained under sigma-15 blur, long-side-64, eye-band occlusion and +45° roll. At brightness ×2 and lower-face occlusion, one of two known portraits matched and one abstained. This describes only these particular transformed captures.

Six equal-panel two-face composites detected both faces and abstained. The large-known/tiny-unknown composite detected only the large face and emitted the known candidate. This is a meaningful scene-gate limitation: **one detected face is not proof that only one person is present**. It is not counted as an unknown-person misidentification because the named known portrait really is in the composite; the failure is to abstain on a multi-person scene.

Both ordinary known digital photo inputs were accepted. PAD/liveness is absent. This demonstrates the pipeline accepts image files without a liveness barrier, not a physical printed-photo/screen-replay success rate. No physical presentation-attack trial was performed.

## Supported and unsupported conclusions

Supported: the isolated upstream detector/embedding pipeline can match these separate known captures, reject these two unknown identities, abstain on certain severe synthetic degradations, and reject composites when it detects multiple faces. The results also expose missed-face scene ambiguity and lack of PAD.

Unsupported: real-world error rates; robust parent/sibling recognition; school pickup authority; identifying an authorized guardian; safety to follow someone; identifying every nearby person; real masks, yaw, shadows, camera motion or night performance; live tracking/crowds; child performance; iOS parity, on-device speed, heat or battery; spoof resistance. Neither a face match nor liveness establishes guardianship or permission.

Any app integration remains opt-in experimental and not production-ready. Larger labeled evaluation, calibration on separate identities/sessions, real phone validation, privacy/consent/deletion validation, and applicable child-use assurance remain separate gates. The stress matrix does not replace them.
