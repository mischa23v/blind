# Ownership, attribution and fixture privacy review

## Recording data

CaryX AI. *Everyday Manipulation 3D (raw RGB-D).* 2026. [Dataset and attribution source](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw). Immutable revision `a285cd1249fe9762085713a1c796ab68b1810ac2`. Licensed under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/); the original dataset license notice is included as `DATASET_LICENSE`. No publisher endorsement is implied.

The selected original metadata and JPEG/LZFSE depth/confidence members are byte-identical subsets. Decoded arrays are losslessly decoded Float32LE metre depth and uint8 confidence; no upsampling, millimetre quantization or synthetic confidence was introduced. Analytical counts, audits and reports are derived outputs. Private executor path changes are limited to explicitly mapped publication copies, not sensor data.

The publisher says contributors consented to recording/open release and audio was removed. This packet includes no audio. On 2026-10-26, all sixteen included JPEGs were visually inspected from their actual pixels: household surfaces/objects and hands/forearms are visible; no faces, personal documents, addresses or readable screen contents were observed. All sixteen JPEGs report empty EXIF and image-info metadata. Both JSON metadata files contain camera calibration/relative timestamps/poses, not names, GPS coordinates or device identifiers. Original selected images are included without redaction because this scoped review found no redaction target. This is a review of these selected files only, not a guarantee about unselected source frames or a biometric anonymization claim.

The index's semantic labels are machine-generated and not ground truth. A charger cable visible in a JPEG is not a labeled, detected or scored obstacle. Publication does not broaden the experiment into navigation validation.

## Software

The application-specific source cuts and audit harnesses are included as repository source for auditability. This packet does not invent a separate license for them; the repository's applicable terms continue to govern.

LZFSE source is from [the official repository](https://github.com/lzfse/lzfse), revision `e634ca58b4821d9f3d560cdc6df5dec02ffc93fd`, BSD-3-Clause. Its original license, unchanged source files and upstream hash manifest are included under `decoder/`. `decoder/BUILD_RECEIPT.json` identifies the pre-existing decoder binary actually reused by the experiment: SHA-256 `75e52786bd0cfc5ede9e1f08f87dc752778fffe2f6c3957e318c534e5f457d61`. That binary is not redistributed. No decoder rebuild occurred for this comparison or publication.

No Record3D SDK, NumPy, Pillow, Swift compiler/runtime or compiled application library is redistributed. Format documentation links to the original authors; the dataset retains its own CC BY license independently of the app/SDK's software licensing.
