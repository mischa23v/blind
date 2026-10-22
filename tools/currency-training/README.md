# Saudi BankNote-Net crop-classifier pipeline

## Current status: source and synthetic plumbing only

This is a real training/export implementation, not a dummy recognizer. It does
not contain a trained Saudi model, banknote photographs, a downloaded encoder,
or claimed accuracy. No real embedding extraction, Saudi training, HDF5 load,
Core ML conversion or iPhone inference has run. The 32 passing tests exercise
synthetic plumbing and must never be reported as banknote-recognition accuracy.

The existing Python environment has NumPy, Pillow, SciPy and scikit-learn. It
does **not** have TensorFlow, h5py or coremltools. No installation is performed by
this code. Dependency files separate the tested plumbing environment from a
proposed, unverified Python 3.11 encoder/conversion environment.

## What it implements

- Strict Pascal VOC ingestion with explicit source-label mapping, file hashes,
  dimension checks and 1-based-inclusive to 0-based-half-open box conversion.
- A deliberately **unassigned** manifest. No random splitting and no invented
  physical-note identity. Every note photograph/view must be assigned to its
  actual physical note, and every negative to its acquisition scene/group.
- Train, calibration and test partitions with mandatory human grouping review.
  Cross-partition physical-note/scene IDs, source-image paths and exact image
  hashes are rejected. All objects from one image stay in one partition.
- Explicit unknown/non-money/foreign-image ingestion. No automatic internet
  images, synthetic unknown-class substitutes or unlicensed image copying.
- Pinned Microsoft encoder hash, recursive serialized-object inspection,
  rejection of Lambda/TFOpLambda/custom objects and HDF5 external/soft links,
  followed by deserialization of exactly the verified in-memory bytes.
- CPU-only frozen encoding (default 2 threads, batches of 16, cap 3,000 crops).
  The 256-dimensional features are cached once with provenance hashes.
- Standardization and a small multinomial logistic head fitted on **train only**.
  Temperature calibration uses **calibration only**. No test feature participates
  in fitting, hyperparameter choice or temperature selection. Head fitting caps
  native BLAS/OpenMP thread pools at 2 and optimizer iterations at 1,000.
- Safe JSON head output, not pickle/joblib. Explicit crop-only held-out metrics.
- Actual TensorFlow composition and Core ML neural-network-classifier export to
  a single `.mlmodel` with file SHA-256 and machine-readable companion contract.
  The export code has not been exercised without its required assets/packages.

## Inputs and provenance

Dataset record: https://data.mendeley.com/datasets/7sys44td9c/1

The record advertises 2,000 images and eight denominations, with VOC labels.
Inspect the actual archive before relying on counts, raw class names, front/back
coverage, note issues or independent physical-note coverage. It does not claim
unknown/foreign/background negative-class coverage. The publisher's 90:10
photograph split is **not** accepted as evidence of independent physical notes.

Official encoder:
https://github.com/microsoft/banknote-net/blob/main/models/banknote_net_encoder.h5

Required SHA-256:
`dac0226b785ec22ae3b198a386b0f5842affdf9e18ab49cd4de31cbf8cb28477`

Hash provenance:
https://github.com/microsoft/banknote-net/blob/main/src/trusted_models.json

The script never downloads the file, accepts a replacement hash, enables unsafe
deserialization or executes a model from an arbitrary repository. If the pinned
file fails the structural allowlist, stop and inspect the discrepancy. Do not
add an unsafe-loading override. Actual HDF5 structure remains unverified here.

## Preparation after the data arrives

Run these from this directory. Paths below are placeholders, not existing assets.

1. Extract the user's dataset locally. Inspect actual images and labels. Prepare
   `labels.json` mapping each raw VOC label to an exact string denomination.
   Canonical order is `1, 5, 10, 20, 50, 100, 200, 500`, with `unknown` ninth only
   when real unknown examples have been added. Never guess a mapping from a
   class index or substitute a different denomination.

2. Create the manifest:

   ```sh
   python currency_training.py index-voc \
     --root /data/saudi \
     --annotations /data/saudi/annotations \
     --images /data/saudi/images \
     --label-map labels.json --output manifest.unassigned.json
   ```

   The importer requires one uniquely named image per XML filename and consistent
   image/XML dimensions. Duplicate basenames, unsupported orientation or unsafe
   paths stop ingestion rather than silently binding the wrong image. Inspect
   and deliberately normalize the data if those checks fail. VOC `difficult`
   and `truncated` flags are retained, not silently discarded.

3. Add licensed/authorized real negative crops if available. The CSV header is:

   ```csv
   image,group_id,split,negative_kind,physical_note_ids
   ```

   `image` is relative to the same dataset root. `group_id` groups repeated
   photographs of the same acquisition scene/item, never one unique ID per view.
   `split` is train/calibration/test. `negative_kind` is non_money,
   foreign_currency, partial_note, multiple_notes or other. `physical_note_ids`
   is an optional pipe-separated list of physical-note identities in the same
   namespace as known-note `group_id` values. It is **required** for partial_note
   (at least one ID) and multiple_notes (at least two distinct IDs). Every visible
   constituent note must be listed. A full-note crop and a partial/multiple-note
   negative containing it must stay in the same partition. IDs may also identify
   notes that occur only in negative scenes. In JSON the field is a list, not a
   pipe-separated string. The whole supplied image is the
   negative crop, so it must represent the same proposal/crop distribution that
   the phone will feed to the classifier, not merely a convenient random image.

   ```sh
   python currency_training.py add-unknown \
     --manifest manifest.unassigned.json --root /data/saudi \
     --csv unknown.csv --output manifest.grouped.json
   ```

4. Manually complete every record's `group_id` and `split`, then set
   `grouping_review.complete` to true and fill `reviewer` and `method` describing
   how physical-note and near-duplicate identities were checked. Known notes
   use `group_kind: physical_note`; unknowns use `negative_scene`.

   A single physical note photographed repeatedly cannot appear across partitions.
   If a scene contains notes whose groups link different partitions, move the
   whole connected scene/group component together. Keep augmented derivatives
   with their original. Do not infer unique notes from filenames or differing
   viewpoints. The hash guard only detects exact duplicates; near-duplicates
   and repeated physical notes require actual review.

   **If the dataset does not contain enough independent notes of every class,
   do not manufacture a split.** Obtain additional authorized captures or retain
   the task as an experiment without an independent test claim.

5. Validate all images, annotations, groups and coverage:

   ```sh
   python currency_training.py validate \
     --manifest manifest.grouped.json --root /data/saudi
   ```

   Every included class must occur in all three partitions. Nine-class negative
   coverage additionally reports whether non_money and foreign_currency examples
   exist in every partition. This is a presence check, not a sufficient sample
   size, statistical confidence or deployment-safety criterion.

## Encode, fit, evaluate and export

Use a separate compatible environment for the encoder/export phase. The existing
NumPy 2 / Python 3.12 environment is only validated for plumbing/head tests.
The proposed compatibility set in `requirements-encoder-export.txt` is not a
verified lockfile, and must be installed/validated only when authorized.

```sh
python currency_training.py inspect-encoder --encoder /models/banknote_net_encoder.h5
python currency_training.py cache \
  --manifest manifest.grouped.json --root /data/saudi \
  --encoder /models/banknote_net_encoder.h5 --output cache-v1 \
  --batch-size 16 --threads 2 --max-images 3000
python currency_training.py train --cache cache-v1 --output head-v1.json
python currency_training.py evaluate \
  --cache cache-v1 --head head-v1.json --split calibration --output calibration-v1.json
python currency_training.py evaluate \
  --cache cache-v1 --head head-v1.json --split test --output test-v1.json
python currency_training.py export-coreml \
  --head head-v1.json --encoder /models/banknote_net_encoder.h5 \
  --output SaudiCropClassifier-v1.mlmodel
```

The `train` command never evaluates test. Lock preprocessing, fit choices and
rejection policy using training/calibration before opening test results. Repeated
iteration on that test invalidates its holdout role; collect a new independent
test set instead. There is no promise of statistical independence merely because
the manifest passes validation.

Eight-class export is rejected by default. If an explicitly experimental model
is useful before negative data arrives, `--allow-experimental-eight-class` permits
only a plainly marked experimental output. It does not authorize selecting a
phone profile, publishing, deployment or calling arbitrary background a note.
Nine-class output also remains `release_approved: false`.

## Exact app contract and detector mismatch

This is a **crop classifier**, not an object detector. It returns no bounding
boxes, count, currency authentication result or note-boundary validation. Do
not wrap its scores in fabricated boxes to satisfy a detector interface.

- Input feature: `image`, RGB, 224×224.
- Crop: axis-aligned rectangle, zero margin, upright source pixels.
- Resize: stretch to 224×224 with bilinear resampling; Vision `.scaleFill`.
- Pixel scaling: 1/255 exactly, zero bias. Core ML embeds that scaling, so the
  phone supplies ordinary image pixels and must not scale them a second time.
- Outputs: `classLabel` string and `probabilities` dictionary with all canonical
  labels, ideally the eight denominations plus `unknown`.
- File format: raw `.mlmodel`, neuralNetworkClassifier, minimum iOS 15 requested.
- Companion `<model>.contract.json`: real model file SHA-256, actual label list,
  model/head provenance, crop parameters and explicit non-release flags.
- `selected_phone_profile: null`. This pipeline never changes the app profile.

Apple Vision may propose a rectangle before cropping, but a rectangle is not
proof of a banknote and exactly one proposal is not a guaranteed note count.
End-to-end tests must include cropped/partial notes, overlapping notes, paper,
screens, foreign money, no-note frames, glare, blur and camera orientations.
The classifier cannot validate note visibility or authenticity by itself.

The app and Pillow resizing implementations may differ at pixel boundaries.
Before activation, compare real held-out crops through TensorFlow and Core ML
on macOS/iPhone, then test the actual capture/proposal/crop path on-device.
Export's zero-input fused-head check is only arithmetic wiring, not device parity
or banknote recognition. Temperature calibration does not make softmax a safe
unknown detector. Select and independently evaluate abstention, score-margin,
temporal-stability and proposal-quality policies before user-facing recognition.

See `EVALUATION_HANDOFF.md` for the boundary between crop metrics and the sibling
whole-frame spoken-decision evaluator. Do not turn these crop softmax scores into
fabricated phone predictions or copy crop accuracy into a deployment report.

## Tests

```sh
python -m unittest discover -s tests -v
python -m py_compile currency_training.py tests/test_currency_training.py
```

Use an environment with `requirements-plumbing.txt` dependencies installed.

These tests create only tiny solid-color images and synthetic feature arrays.
They verify file/box/manifest plumbing, leakage barriers, cache corruption,
unsafe-object rejection, split isolation and algebraic export-head equivalence.
They do not load an encoder, convert a Core ML model or train on Saudi images.

## Rights and publication

See `THIRD_PARTY_NOTICES.md`. Keep datasets and images private in this preparation
flow. Dataset CC BY terms are not a substitute for any SAMA reproduction
permission. Do not ship banknote photos or declare legal clearance based on this
code. This pipeline does not decide whether private training needs permission.
