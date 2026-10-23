# Optional on-device object detector resource

Status: packaging plumbing and synthetic input-contract tests. No detector artifact has been selected, downloaded, licensed, executed, or accepted by this work. The default project still has no object-detector resource. A label/category candidate is not personal-object identity, target/depth binding, present clearance, or permission to reach or move.

## Accepted input

Supply a separately reviewed local artifact outside this source repository:

- A regular file named `Detector.mlmodel`. Xcode compiles the model through its model source build phase.
- A directory named `Detector.mlmodelc`. Xcode copies only that exact compiled bundle as a folder resource.

The filename is intentional: the application loads `Detector.mlmodelc` from its bundle. Other names, `.mlpackage`, arbitrary resource folders, symlink artifacts and URL inputs are rejected. A model package can be compiled separately using Apple's tooling on a Mac, but conversion, model installation and execution are not performed by this generator.

The model must accept an image and already expose the Vision-compatible object-detection/NMS convention that yields `VNRecognizedObjectObservation` with labels and normalized boxes. Raw YOLO tensors, image classifications and arbitrary `MLMultiArray` outputs are not compatible. No guessed decoder, tensor reshaping or replacement inference runtime is included.

Primary references:

- [Apple: Recognizing Objects in Live Capture](https://developer.apple.com/documentation/vision/recognizing-objects-in-live-capture) demonstrates Vision object observations, labels and bounding boxes.
- [Apple: Core ML NMS format](https://apple.github.io/coremltools/mlmodel/Format/NonMaximumSuppression.html) specifies the NMS model's label and confidence/coordinate features.
- [Apple: object-detector Core ML export](https://apple.github.io/turicreate/docs/userguide/object_detection/export-coreml.html) distinguishes exports with and without embedded NMS.
- [Apple: MLModel](https://developer.apple.com/documentation/coreml/mlmodel) documents compiled-model loading and model descriptions.

These are interface sources, not a model selection or an accuracy/reliability endorsement.

## External review manifest

Pass `--object-detector-manifest /absolute/path/detector-review.json` together with the model. The manifest must be outside the artifact and is not copied into the app. Required shape:

```json
{
  "schema_version": 1,
  "resource_kind": "vision_object_detector",
  "artifact_name": "Detector.mlmodel",
  "artifact_sha256": "REPLACE_WITH_LOWERCASE_SHA256",
  "vision_output": "VNRecognizedObjectObservation",
  "postprocessing": "model_embedded_nms",
  "input": {
    "type": "image",
    "name": "image",
    "width": 640,
    "height": 640,
    "color_space": "RGB"
  },
  "labels": ["cup", "chair"],
  "source_url": "https://example.org/REPLACE_WITH_ACTUAL_MODEL_SOURCE",
  "source_revision": "REPLACE_WITH_PINNED_RELEASE_OR_REVISION",
  "model_license": "REPLACE_WITH_ACTUAL_WEIGHT_LICENSE_AND_REFERENCE",
  "data_license": "REPLACE_WITH_ACTUAL_TRAINING_DATA_LICENSE_AND_REFERENCE",
  "reviewed_for_bundling": true,
  "files": [
    { "path": "Detector.mlmodel", "sha256": "REPLACE_WITH_LOWERCASE_SHA256" }
  ]
}
```

The example is deliberately invalid until all placeholders and actual input/label declarations are reviewed and replaced. Do not set `reviewed_for_bundling` based on a generator pass. Code, weight and data rights are separate; retain the applicable converter/upstream code-license receipt too. A source URL may not carry credentials, query tokens or fragments. No authentication data belongs in the manifest.

For `.mlmodel`, both hashes are SHA-256 of the exact file. For `.mlmodelc`, `files` lists every regular file relative to the bundle. Its artifact hash is SHA-256 over the UTF-8 concatenation of sorted records `path + NUL + lowercase file SHA-256 + LF`. Sorting is ordinary ascending path order. The generator also computes a separate SHA-256 of the exact manifest bytes for the Xcode build settings.

Compiled files use a narrow allowlist: `coremldata.bin`, `metadata.json`, `model.mil`, `model.espresso.net`, `model.espresso.weights`, `model.espresso.shape`, `weights/weight.bin`, `weights/<number>-weight.bin`, and `analytics/coremldata.bin`, with optional enclosing `model<number>/` pipeline directories. An unrecognized compiler layout requires review rather than widening to arbitrary files. Root `coremldata.bin` is required. Every directory/member must be listed or implied by the inventory. Hidden files, images, credentials, traversal, symlinks and stray members fail preflight. Limits are 256 files, 256 MiB per file, 512 MiB total and a 256 KiB manifest; hashing is streamed in 64 KiB buffers.

The manifest is a human declaration. The Node preflight verifies its shape, selected output convention, label uniqueness, provenance fields, path confinement, inventory and hashes. It does not parse Core ML protobuf/compiled binaries or certify actual input/output semantics, license truth, training contents or absence of sensitive bytes hidden inside an artifact. Review the artifact itself. The app must still reject an unavailable model or any actual Vision result type other than object observations. Raw tensors must never silently become boxes.

## Exact invocation

```sh
node tools/generate-xcode-project.mjs \
  --object-detector /absolute/external/path/Detector.mlmodel \
  --object-detector-manifest /absolute/external/path/detector-review.json
```

Use `Detector.mlmodelc` in the same command for a reviewed compiled bundle. Keep all explicitly selected existing flags, including `--multimodal`, `--live-activity`, familiar-person backend/framework/models, and currency-reference/device-test options, when generating a combined configuration. A bare generator invocation does not preserve optional selections from a previous project.

Generation checks every input before writing the project. Failed preflight leaves the prior project untouched. It neither copies nor downloads model assets at generation time, nor includes adjacent files. Keep the reviewed external artifact immutable through the Xcode build and rerun preflight after any change; generation-time hashes alone cannot prevent subsequent filesystem changes. The active project was not regenerated in this implementation task.

## Evidence and next gate

The source tests use synthetic bytes that are not Core ML models. They cover opt-in isolation, both build-phase forms, combined configuration preservation, hashes, provenance/label/input validation, raw-output rejection, unsafe paths/symlinks/unlisted members and failed-generation preservation. They do not establish Xcode model compilation or Vision compatibility.

On the Mac, inspect the actual model metadata and licenses, build the selected exact configuration, verify the resulting `Detector.mlmodelc`, and exercise actual `VNCoreMLRequest` outputs with known positive, blank, negative and raw-output-incompatible fixtures. Then measure phone latency, orientation, false detections, duplicates, look-alikes, memory, thermal load and interruption behavior. Follow the separate supervised device/child acceptance protocol. Until those gates pass, detection candidates stay uncertain and physical guidance remains withheld.
