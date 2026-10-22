# Private Saudi banknote reference adapter

This is source preparation, not a validated currency recognizer. The production
`SaudiBanknoteReferenceProfile.selected` is `nil`. No image, descriptors or weights
are bundled. There is no chosen production algorithm, money summing or authenticity
claim. A matching score is not a probability. The prior Core ML adapter is separate.

## Reused code and APIs

- Official OpenCV **4.14.0**, Apache-2.0: `SIFT::create`, `ORB::create`,
  `AKAZE::create`, `BFMatcher::knnMatch`, `findHomography`, `convexHull`,
  `perspectiveTransform`, `getPerspectiveTransform`, `warpPerspective`,
  `intersectConvexConvex`, `pointPolygonTest`, `imdecode`, `resize`, and the official
  `CGImageToMat` Apple adapter. Source: https://github.com/opencv/opencv/tree/4.14.0
  License: https://github.com/opencv/opencv/blob/4.14.0/LICENSE
- The already obtained OpenCV iOS static framework is shared with familiar-face
  code; do not introduce another runtime, download weights, or train a head.
- Local prototype port: `tools/currency-reference/reference_match.py`, originally
  SHA-256 `6f8b4d99a65a4eeb1b001aa20db35222dfa48d08bf3cb2151cb8a0f7236e6315`;
  `prepare_reference.py`, originally SHA-256
  `7ab770bb3e6f9e35d99d2fca1bafccb16c5c00dd617a776bd6c621393703e58a`.
  These hashes identify historical prototype bytes, not checksums of the currently
  reconstructed portable harness. That harness has different hashes and needs fresh
  native parity testing. These gates are experimental, not upstream accuracy evidence.
- Apple CIImage orientation, ImageIO headers and Vision rectangle proposals. The
  actor isolates the native engine and checks cancellation before/after blocking work.

## Runtime pack v2

Place a private folder named `SaudiBanknoteReferences` in the application bundle.
It contains `manifest.json` and relative PNG/JPEG images. Runtime loading requires
an immutable profile with the **exact manifest byte SHA-256**, algorithm, thresholds,
calibration/evaluation identifiers, and explicit reviewed whole-frame/Apple-device
acceptance. The bundled folder does not activate the feature. Do not publish images
or redistribute the private pack merely because its metadata mentions rights.

The project generator requires explicit `--currency-reference` and
`--opencv-framework <path-to-opencv2.framework>`. It does not require face models.
Optional `--currency-reference-pack <path-to-SaudiBanknoteReferences>` adds an
external folder resource without flattening its contents. Combining with
`--familiar-people` retains that feature's explicit model requirements and links
OpenCV once. Default builds contain none of these native resources.

Generator preflight checks framework version/layout and bounded pack inventory,
paths, symlinks and image-byte hashes, and reports the manifest-byte hash. It does
not certify framework provenance, image content, metadata review or release
approval. Runtime's strict parser, exact immutable manifest pin and approval gates
remain authoritative, including duplicate-key rejection. No profile is enabled by
generating a project or by supplying a pack.

The JSON manifest's exact top-level fields are:

- `schema_version`: integer 2.
- `reference_kind`: `private_banknote_photos`.
- `currency`: `SAR`.
- `labels`: exactly `[1,5,10,20,50,100,200,500]`, in that order.
- `references`: zero to 48 records. Empty is parseable but never usable.

Each record has exactly these fields:

- `id`, `path`, `sha256`, `label`, `side`, `issue`, `material`.
- `physical_note_id`, `capture_session_id`, `source`, `rights`.
- `verification`, with exactly `verified`, `verification_kind`, `verified_by`,
  `verified_on`, `method`. `verified` must be true; date is real YYYY-MM-DD;
  kind is `human_review` or `assistant_visual_review`. Runtime activation requires
  every record to be human-reviewed. A parser fixture's assertion is not real review.
- `boundary`, with exactly `source_size` (`[width,height]`) and
  `corners_tl_tr_br_bl` (`[[x,y],[x,y],[x,y],[x,y]]`). These are reviewed source-pixel
  coordinates in TL/TR/BR/BL order, inside the normalized original source image.
  The review must cover both denomination/issue/side/material and the actual note
  boundary, not a background, picture frame, composite sheet or guessed rectangle.

Label is one of the eight values, side is `front`/`back`, material is
`paper`/`polymer`. Nonempty metadata is at most 256 characters, with no control
characters. IDs and image hashes are unique; hashes use 64 lowercase hex digits.
Unexpected/duplicate keys (including differently escaped equivalent keys) fail.
Absolute paths, empty components, dot segments, backslashes, colon/URL paths,
percent-escaped paths and symlinks fail. Resolved files must remain within the pack.
Hashes pin bytes, **not** true labels, correct boundaries, source rights or accuracy.

The minimum activation inventory covers both sides of every denomination, plus
both sides of both paper and polymer 5. This is not complete issue coverage, and
must not be represented as a held-out physical-note or generalization test.

## Bounded actual computations

Manifest <=256 KiB; each photo <=8 MiB; source dimensions 32...4096 per side and
<=8,000,000 pixels; sum of reference bytes <=96 MiB; single-frame PNG/JPEG;
reference EXIF orientation must already be up. ImageIO headers are checked before
OpenCV decoding, then decoded size is cross-checked.

The native adapter rectifies each source image from its declared four corners with
OpenCV `getPerspectiveTransform`/`warpPerspective(INTER_LINEAR)`. Output dimensions
are average opposite-edge lengths, proportionally reduced to <=800 pixels using
round-to-even dimensions from the historical preparation contract. This has not
been newly parity-verified against the reconstructed Python. Require a non-mirrored
convex boundary, >=32-pixel edges, >=10% source area and <=3 opposite-edge ratio.
Descriptors are computed from this **prepared note**, not the entire source canvas;
only keypoints/descriptors and dimensions remain in native memory after loading.

Query orientation is normalized with CIImage; input is limited to 4096 per side
and 8 million pixels before render. The full query is retained, converted by
OpenCV's official CGImage adapter and RGB-to-gray conversion, then reduced to
<=1200 with INTER_AREA. Query pixels/descriptors remain ephemeral. They are never
written, uploaded or logged. Real camera buffers larger than this bound abstain.

SIFT uses L2; ORB/AKAZE use Hamming. Parameters mirror the Python prototype.
Shared once-only OpenCV CPU-thread configuration avoids a per-constructor global
thread-pool mutation; Mat inputs use CPU paths without changing global OpenCL state.
Features are bounded to 1800, matches query-to-reference with Lowe ratio, at most
two regions per reference, RANSAC confidence .995 and default 1500 iterations,
seed 12345 + region. Duplicate reference-feature votes count only once. The original
robust transform is retained, not non-robustly refitted. Spatial hull/grid support,
quad area/convexity/frame bounds, edge/angle/perspective distortion and median
reprojection error all gate results. Region overlap uses actual OpenCV polygons.
SIFT may retain tied responses over its nominal feature count: this adapter truncates
them in original detector order to enforce the hard bound, an explicit parity gap.

The pure Swift policy independently validates numeric/score/overlap contracts,
requires absolute support, rejects disjoint accepted regions (also same-label notes),
and compares one maximum score per denomination, including rejected geometric
competitors. Front/back of the same label do not become competing denominations.
There is no nearest-wins fallback. The experimental defaults are preserved, not
calibrated on the latest development queries. Any future threshold change is a new
frozen profile and must receive independent evaluation.

## Full-frame veto and known limits

Matching alone accepted the front of a historical 1-riyal note in an image depicting
both front and back. Therefore the actor also runs full-frame Vision rectangles:
zero => unknown; more than one => multiple. Matching still receives the whole frame.
The actual four-corner matched quadrilateral must have >=.80 polygon IoU with the
single four-corner proposal (an experimental added veto, not a validated detector
threshold). Equal axis-aligned bounding boxes are insufficient for tilted notes.

This does **not** prove that another unknown, hidden, overlapping, folded or similar
note is absent. A composite, photograph, screen or reproduction may match. Rectangle
false negatives/positives can still occur, and multiple adjacent notes may appear as
one rectangle. Nothing here proves physical presence, genuineness or legal tender.
Keep activation nil until independent whole-frame, costly-confusion, multi-note,
unknown and adult physical-phone evaluations justify a reviewed profile. No child
or independent financial-use readiness is established.

## Validation boundary

Pure Swift tests exercise synthetic policy/parser inputs only. C++ syntax checking
against the installed official 4.14 headers validates API spelling, not linking,
Objective-C/Swift bridging or native inference. Linux cannot execute the iOS static
framework. Apple SDK compilation, actual native/Python image and metric parity,
CGImage/Vision orientation/color/resize behavior, physical camera, cancellation
latency, memory/thermal behavior and VoiceOver remain required. The Apple adapter
must not be described as device-tested or parity-tested before those checks run.
