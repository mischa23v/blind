# Private Saudi iPhone developer-test reference pack

This is a reproducible **local developer-device evaluation pack**, not a trained
model, a production-approved reference collection, or a banknote-accuracy result.
No images belong in Git or in public releases. The builder never downloads,
uploads, trains, or makes a monetary decision.

## Rebuild from the user's existing local dataset

Use Python 3.10+ on macOS/Linux and the existing pinned dependencies in
`tools/currency-reference/requirements.txt`:

- `opencv-python-headless==4.14.0.94` (runtime `cv2.__version__ == 4.14.0`)
- `numpy==2.3.5`
- `Pillow==12.3.0`

Install dependencies only into the user's authorized Python environment. Do not
install or download anything merely to run the builder. On this prepared local
workspace the already-installed dependencies are selected with
`PYTHONPATH=/workspace/shared/currency-python-deps`.

The dataset argument is the **parent containing `Saudi Currency/`**, not the inner
folder. The output parent must already exist, the final directory name must be
`SaudiBanknoteReferences`, and that directory must not exist. Use real paths with
no symlink components. The output must be separate from the dataset tree.

```sh
python tools/currency-reference/build_device_test_pack.py \
  --dataset '/absolute/path/to/extracted' \
  --output '/absolute/path/to/private-output/SaudiBanknoteReferences'
```

Exact command used in this workspace:

```sh
PYTHONPATH=/workspace/shared/currency-python-deps \
python tools/currency-reference/build_device_test_pack.py \
  --dataset /workspace/shared/currency-data-20261023/extracted \
  --output /workspace/shared/currency-device-test/SaudiBanknoteReferences
```

Output inventory is strictly `manifest.json` plus `images/` containing exactly
16 PNGs. Do not put this README, a ZIP, `.DS_Store`, receipts, or other files inside
the pack directory. The iOS project generator validates this inventory and pins
the manifest separately. This README belongs **outside** that directory.

Frozen manifest SHA-256:

`9325cd9d27cde2903a52743f71fcf700e430323a87b46ec2d95b32423c3468e2`

All 17 files together contain **15,299,295 bytes**, before ZIP compression.
The pack was built at
`/workspace/shared/currency-device-test/SaudiBanknoteReferences` in the prepared
local workspace. This is not a portable path on the user's Mac.

## Exact normalization and provenance

`device_test_reference_selection.json` contains the selected sixteen source paths,
original SHA-256 hashes, original dimensions/EXIF orientations, expected normalized
hashes/dimensions, reviewed corners, and limitations. It contains no image bytes.
Each original is checked against its frozen hash before decoding. The original
and normalized hashes must both match, or the build fails without substituting a
new photo or a differently prepared reference.

Normalization uses official OpenCV 4.14.0: grayscale decode with
`IMREAD_IGNORE_ORIENTATION`; explicit EXIF rotation 3/6/8; orientation 0/1 uses
stored pixels; full-frame maximum side 1600 with `INTER_AREA` and Python rounded
dimensions; PNG compression **3**. Compression 3 is necessary to reproduce the
reviewed PNG byte hashes; default PNG compression is not equivalent. The builder
uses bounded regular-file reads, bounded JPEG header dimensions before OpenCV
decode, one OpenCV thread, no symlink following, exclusive output creation, and
an aggregate 32 MiB pack bound.

There is **no crop or perspective warp in this builder**. The native engine alone
rectifies the note to its maximum-800 reference view using the exact reviewed
source-pixel corners. Double-warping an already rectified reference would be
incorrect. Corners were manually identified by an assistant after actual pixel
inspection, not copied from VOC annotation boxes. They are approximate visual
boundaries, not exact ground truth. The first review used canonical print order;
the second used displayed quadrilateral order. Both retain the originally
reviewed positive-winding corner sequence; no corners were relabelled or moved.

Every manifest entry says `assistant_visual_review`, never `human_review`.
Physical-note and capture-session IDs are explicitly `unknown_not_verified`.
Dataset capture-name similarities or publisher splits do not establish distinct
notes, independent sessions, front/back physical pairing, or held-out independence.
Material fields identify paper-like visual designs, not a physical-material test.

## Credits, rights and limits

Source dataset: **Saudi Currency**, Nazmul Ahasan Maruf, Abdullah Basuhail,
AHM Adil. Version 1, DOI [10.17632/7sys44td9c.1](https://doi.org/10.17632/7sys44td9c.1).
Dataset license: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
Changes: grayscale conversion, EXIF correction, bounded full-frame resize and PNG
encoding; assistant annotations added. Original photographs are not modified.
Credits and the limited evaluation purpose are also present in each manifest
entry's source/rights fields, so the strict native schema needs no extra keys.

Dataset licensing does **not** establish compliance with separate SAMA banknote
reproduction/redistribution requirements. Those requirements remain unresolved.
Keep the images private for the user's authorized device evaluation. No public
banknote-image publication or redistribution approval is claimed.

There is one selected front and back paper-design image for each of 1, 5, 10, 20,
50, 100, 200 and 500 riyals. **Polymer 5 riyals is missing.** This is not complete
issue/design/material coverage. Worn/folded notes, different backgrounds and
capture conditions, other currencies, multiple/overlapping notes, partial notes,
and confusable cases require independent acceptance testing. Nothing here proves
authenticity, current legal-tender status, banknote accuracy, reliable single-note
detection, safe financial decisions, or independent use.

## Verification performed, and what remains

The builder/security suite passed **27/27** tests on 2026-10-23, including an actual
rebuild from the sixteen pinned originals. Tests cover all orientation branches,
full-frame downsampling without perspective warp, exact hashes, strict inventory,
source/normalized corruption, oversized reads/header/decode bounds, symlinked
inputs/parents/outputs, no-overwrite behavior, and honest assistant provenance.
Synthetic tests establish plumbing, not recognition accuracy.

```sh
# Synthetic plumbing plus frozen manifest checks; no dataset needed.
python -m unittest discover -s tools/currency-reference \
  -p 'test_build_device_test_pack.py' -v

# Also rebuild the actual selected local photographs; no network access.
CURRENCY_DEVICE_TEST_DATASET='/absolute/path/to/extracted' \
python -m unittest discover -s tools/currency-reference \
  -p 'test_build_device_test_pack.py' -v
```

Independent compiled Swift 6.4.1 validation of the actual manifest passed:
16 entries; `deviceTestCoverage == true`; production `minimumCoverage == false`;
`allHumanReviewed == false`; all verification kinds are assistant visual review.
This is manifest parsing/coverage validation, **not** an Apple SDK build, native
image-decoding/feature-matching run, or an iPhone/VoiceOver result. Actual phone
validation, independent costly-confusion testing, latency and thermal behavior
remain pending. The explicit developer-test profile must remain distinct from
ordinary production approval.
