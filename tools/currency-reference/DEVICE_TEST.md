# Saudi reference recognition: private iPhone test build

This is a functional, explicitly configured Debug test path, not a validated production money reader. No classifier or LLM was trained. It compares camera features against a hash-pinned set of Saudi reference photographs using SIFT and geometric verification. A result identifies a visible supported Saudi denomination, not the value of the whole scene, the authenticity of a note, or foreign currency.

## What is included

The private pack contains sixteen assistant-visually-reviewed paper-note references: front and back for 1, 5, 10, 20, 50, 100, 200 and 500 riyals. Physical-note/session independence is unknown. Polymer 5 and complete coverage of every issue/design are not established. Assistant review is not labeled human review. Photographs are not committed to the source repository.

Manifest SHA-256: `9325cd9d27cde2903a52743f71fcf700e430323a87b46ec2d95b32423c3468e2`.

The ordinary production profile remains unselected. An adult developer configures the test build once; there is no child-facing mode selector. The intended interaction is ask to read money, hear a short denomination if the checks pass, otherwise hear a short retake request. Explicit “try again” takes a fresh image within a bounded retry session. Unavailable/broken assets do not pretend to recognize money. Move-closer/framing instructions are based on measured evidence, not guesses.

## Prepare the private pack

Either extract the separately delivered private test pack or rebuild from the user's downloaded dataset. The dataset argument is the parent containing `Saudi Currency/`, not the folder itself. Use a new output directory outside the dataset and repository; the builder refuses overwrites and symlinks.

```sh
python3 -m venv .venv-currency
. .venv-currency/bin/activate
python -m pip install opencv-python-headless==4.14.0.94 numpy==2.3.5 Pillow==12.3.0
mkdir -p /absolute/private/device-test
python tools/currency-reference/build_device_test_pack.py \
  --dataset /absolute/path/to/extracted-dataset \
  --output /absolute/private/device-test/SaudiBanknoteReferences
```

The builder verifies all sixteen original-image hashes, dimensions and EXIF orientation, then reproduces reviewed full-frame PNG hashes. It does not crop/rectify those images: the native engine performs the reviewed corner rectification once. A decoder/version/platform difference fails the hash check rather than substituting different pixels.

## Configure on the Mac

Use the existing working Xcode, signing, OpenCV framework and face-model paths. Preserve the current face backend and all other selected generator options. Add these options to that existing generator invocation:

```sh
--currency-reference --currency-device-test \
--currency-reference-pack /absolute/private/device-test/SaudiBanknoteReferences \
--opencv-framework /absolute/path/to/opencv2.framework
```

For example, when the existing build uses AuraFace:

```sh
node tools/generate-xcode-project.mjs \
  --familiar-people --familiar-backend auraface \
  --familiar-models /absolute/path/to/models \
  --opencv-framework /absolute/path/to/opencv2.framework \
  --currency-reference --currency-device-test \
  --currency-reference-pack /absolute/private/device-test/SaudiBanknoteReferences
```

Do not run a default generator command afterward: it would discard selected optional backends. Build the Debug configuration on the physical iPhone. The generator must pin the verified manifest hash into `CURRENCY_REFERENCE_PACK_SHA256`, expand `BACurrencyDeviceTestManifestSHA256` in Info.plist, and enable `DEBUG`, `BLIND_CURRENCY_REFERENCE` and `BLIND_CURRENCY_DEVICE_TEST`. Release does not select the test profile. This document describes the coordinated generator interface; verify the generator changes are present in the checkout before running.

## Evidence and limits

A fixed SIFT comparison on all 200 publisher-test photographs returned 63 correct denominations, 137 abstentions and zero wrong denominations. This is not an independent physical-note accuracy estimate: burst families cross the published split and identities are unknown. The query pixels were not annotation-cropped. The full experiment and earlier failures remain in `DATASET_DIAGNOSTIC_20261023.md`.

All nine additional known-Saudi overlap constructions were rejected by SIFT. Three Saudi-plus-foreign composites still returned the correct visible Saudi denomination while ignoring the foreign money. Those remain failures of the earlier strict single-note scene contract, not wrong Saudi labels. Foreign-only and non-money negative testing is small; it is not proof against unknown inputs. Repeated agreement and rectangle detection are not guarantees.

Fresh pure-core tests and source contracts pass, and the actual private manifest passes the Swift parser. This cloud environment cannot build/link Apple frameworks or test camera Vision proposals, native C++ numerical parity, latency, cancellation, thermal behavior or spoken output on a real iPhone. An adult must test those with known notes before anyone relies on the output for money decisions. Do not describe this as certified, production-ready, or independently measured high accuracy.

## Attribution and redistribution

Dataset: Nazmul Ahasan Maruf, Abdullah Basuhail and AHM Adil, Saudi banknote dataset, DOI [10.17632/7sys44td9c.1](https://data.mendeley.com/datasets/7sys44td9c/1), publisher-listed CC BY 4.0. Source images were converted to bounded grayscale PNGs for this private, user-authorized device evaluation; the pack records individual source names and hashes.

The dataset license does not by itself settle banknote-reproduction requirements. [SAMA's reproduction notice](https://rulebook.sama.gov.sa/en/circular-re-techniques-identify-banknotes) refers to reproduction licensing. Public redistribution of note images or inclusion in an app-store release is not cleared by this test work. Keep the supplied reference pack private and out of the repository; obtain appropriate clearance before redistribution. No legal conclusion that private recognition evaluation is prohibited is asserted here.
