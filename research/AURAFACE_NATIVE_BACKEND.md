# Optional AuraFace native backend

Controlled off-by-default familiar-people experiment, not authentication, liveness, relationship verification or evidence of safety. Default app includes no OpenCV/models. Enabling familiar people still selects SFace unless AuraFace is explicitly selected. Adult consent and uncertain/unknown results remain required; child reliability is unvalidated.

## Explicit selection

Keep downloaded assets outside the repository. Put the selected recognizer and YuNet in one external models directory:

```sh
node tools/generate-xcode-project.mjs --familiar-people --familiar-backend auraface --opencv-framework /absolute/path/opencv2.framework --familiar-models /absolute/path/models
```

Use `--familiar-backend sface` (or omit it) for unchanged SFace. Run the generator with no experimental arguments to restore default. Generator verifies OpenCV 4.14.0 header and both selected model hashes; only the selected recognizer is bundled. AuraFace adds `BLIND_FAMILIAR_AURAFACE` alongside `BLIND_FAMILIAR_PEOPLE`. The checked static framework has arm64 iPhone and x86_64 simulator slices, not arm64 simulator: prefer physical iPhone on M1. It is not embedded as a dynamic framework.

## Assets and rights boundary

- YuNet: `face_detection_yunet_2023mar.onnx`, SHA-256 `8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4`. [Official model and MIT notice](https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet).
- Default SFace: `face_recognition_sface_2021dec.onnx`, SHA-256 `0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79`. [Official model and Apache-2.0 notice](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface).
- AuraFace: `glintr100.onnx`, 260,694,151 bytes, SHA-256 `a7933ea5330113b01c9b60351d8f4c33003f145d8470ac5f0e52ee2effe25c60`. [Pinned official weights](https://huggingface.co/fal/AuraFace-v1/resolve/af6d057c9b0ec4071d4c49c80e3539258798b609/glintr100.onnx), revision `af6d057c9b0ec4071d4c49c80e3539258798b609`. [Official model card](https://huggingface.co/fal/AuraFace-v1/blob/af6d057c9b0ec4071d4c49c80e3539258798b609/README.md) declares Apache-2.0 and commercial-use intent. Training-data provenance is incomplete: this is not full commercial/privacy/training-rights clearance. Framework/transitive license review remains separate.

## Pipeline and evidence

One OpenCV FaceRecognizerSF supplies landmark alignment and cosine matching per backend. SFace retains uint8 BGR aligned input/128 dimensions. AuraFace converts the same 112x112 aligned BGR crop to float, subtracts 127.5, scales 1/127.5; OpenCV 4.14 `feature()` swaps RGB internally, with scale 1/mean 0. Output must be 512 finite nonzero values. Optional Vision receives original uint8 RGB before normalization. Gallery profile mismatch (backend/models/hashes/dimension) rejects stored vectors and requires fresh enrollment, never conversion or reinterpretation.

Portable reference regression, no downloads or biometric vector output:

```sh
python tools/face-evaluation/check_native_auraface_parity.py --assets /absolute/path/face-evaluation-assets
node --test tools/test/auraface-backend.test.mjs
```

2026-10-22: Four previously used ORL real photos passed under Linux OpenCV 4.14. Direct DNN versus float-input FaceRecognizerSF had max absolute feature difference 0.0 and cosine difference 6.014013820276887e-08 (assert limits 1e-5 and 1e-6). This is portable route parity, NOT executed Apple Objective-C++/CoreGraphics/channel/orientation or float-rounding validation. No new held-out accuracy claim. Existing small datasets/thresholds do not demonstrate production or child accuracy.

Prior exploratory cloud CPU inference was approximately 242 ms, not phone latency. The roughly 261 MB model adds substantial bundle/memory cost. Xcode/iPhone capture, enrollment, recognition, voice, deletion, cancellation, orientation, latency and memory remain release gates.

## Experimental decision-policy provenance (2026-10-22)

The immutable app configuration names a separate inference policy: SFace cosine threshold 0.7 / runner-up margin 0.2 (`aberdeen-calibration-20261022-sface-cosine070-margin020-v1`), or AuraFace 0.5 / 0.2 (`aberdeen-calibration-20261022-auraface-cosine050-margin020-v1`). These are dataset-calibrated starting points, not validated app accuracy. The published research baseline 0.363 / 0.1 remains available in the evaluation harness and core default reference; it is not silently replaced there.

Selection used the Aberdeen calibration split BEFORE held-out evaluation, from a predefined grid: minimize false named matches across known and unknown probes, then maximize correctly named known probes, then prefer the higher threshold and margin. On the subsequent held-out single-template protocol (10 enrolled gallery identities, 82 known probes, 193 photos from 20 unknown identities), SFace yielded 76 correct known names, 6 abstentions and no false names; AuraFace yielded 82 correct known names and no false names. No false names were observed among the 193 unknown photos for either selected policy. These finite-sample results are not a zero-error guarantee.

The app averages 3–6 enrollment examples and optionally applies Apple quality/Vision checks, unlike this single-template benchmark. These app paths, demographic generalization, child reliability and physical-device behavior remain unvalidated by that benchmark. Policy IDs identify decision provenance independently of the embedding model/hash/dimension gallery profile: changing a decision threshold need not discard compatible vectors, while changing the embedding backend still requires fresh enrollment.
