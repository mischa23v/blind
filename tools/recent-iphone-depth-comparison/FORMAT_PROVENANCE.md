# Record3D intrinsics provenance: resolved order, remaining geometry boundaries

2026-10-26. Read-only primary-source research plus inspection of existing authorized metadata. No new capture download, build, installation, projection, perception evaluation or app change. This note is separate from the frozen stage-01 audit packet; its historical statement that ordering was then unverified remains accurate for that stage.

## Resolution: author explicitly documents the four-value order

**`perFrameIntrinsicCoeffs[i]` is `[fx, fy, tx, ty]`; `tx` and `ty` are principal-point coordinates, commonly named `cx` and `cy`.** This is now supported by a direct Record3D-author explanation, not guessed from plausible numeric values:

- [Marek Simonik, issue 99, exact comment 2459540413](https://github.com/marek-simonik/record3d/issues/99#issuecomment-2459540413), created/updated **2024-11-06 11:50:05 UTC**, owner-authored. It connects the per-frame JSON array with the four named coefficients returned by the official USB interface and explains that `K` is constructed from the first array entry. [Public comment API](https://api.github.com/repos/marek-simonik/record3d/issues/comments/2459540413).
- The author links [official `demo-main.py`, lines 40–43](https://github.com/marek-simonik/record3d/blob/0c6e7692da100aad2d5195e307f01e75427a6a2a/demo-main.py#L40-L43), exact revision **`0c6e7692da100aad2d5195e307f01e75427a6a2a`**, which places `tx`/`ty` in the principal-point slots.
- Independently inspected current official revision **`79e6f44697150a4f036034af8fec903d11ac6f00`** retains the field order in [Record3DStructs.h](https://github.com/marek-simonik/record3d/blob/79e6f44697150a4f036034af8fec903d11ac6f00/include/record3d/Record3DStructs.h) and the same matrix construction in [demo-main.py](https://github.com/marek-simonik/record3d/blob/79e6f44697150a4f036034af8fec903d11ac6f00/demo-main.py#L40-L43). This accompanying streaming library is LGPL-2.1; no code from it is imported here, and offline admission does not require installing it.

The resulting RGB-pixel matrix is `[[fx, 0, tx], [0, fy, ty], [0, 0, 1]]`. The exact author statement is the format evidence; numerical agreement in one recording is only corroboration.

### Version and global-K caveat

[Author issue 83, comment 2134164430](https://github.com/marek-simonik/record3d/issues/83#issuecomment-2134164430), 2024-05-28, states per-frame intrinsics were implemented in **Record3D 1.10**. [Author comment 2118776349](https://github.com/marek-simonik/record3d/issues/83#issuecomment-2118776349), 2024-05-18, explains that older constant-intrinsic assumptions no longer hold. The chosen capture has no verified app-version field; presence of this schema is not a complete app-version attestation.

**Global `K` describes frame zero, not all frames.** Do not substitute it silently for the 89 original per-frame arrays. A historical public importer also uses `[fx,fy,cx,cy]` ([issue 107, contributor comment](https://github.com/marek-simonik/record3d/issues/107#issuecomment-2707202635)); it is corroborating original implementation evidence, not the authority used to resolve the format.

## Global K layout and depth/RGB association

- The pinned [CaryxAI README](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/blob/a285cd1249fe9762085713a1c796ab68b1810ac2/README.md) identifies `K` as column-major. In a conventional row-major display it is reconstructed by reshaping nine entries and transposing. The app author directly indexes `fx=K[0]`, `fy=K[4]`, `cx=K[6]`, `cy=K[7]` in [issue 94](https://github.com/marek-simonik/record3d/issues/94), consistent with that layout.
- [Author issue 76](https://github.com/marek-simonik/record3d/issues/76), 2024-01-20: intrinsics belong to the **RGB camera** and Apple aligns the depth/RGB images. [Author issue 108](https://github.com/marek-simonik/record3d/issues/108), 2025-02-24, reiterates that resolution conversion is sufficient for this association: either use RGB-resolution intrinsics with depth represented at RGB resolution, or scale all four coefficients to native depth resolution. This is format/registration guidance, not an independently measured alignment-error bound.
- For native depth pixels, use `fx_d=fx*dw/w`, `cx_d=cx*dw/w`, `fy_d=fy*dh/h`, `cy_d=cy*dh/h`, with actual frame dimensions and orientation. Do not resize confidence into extra independent observations. No extra subtraction of half the image width/height is justified after subtracting the principal point.
- The publisher README's alternative `px/(dw-1)*w` formula is not algebraically equivalent to its `dw/w` intrinsic scaling. Prefer the author-confirmed resolution-ratio convention and an explicit tested pixel convention; do not mix both.
- Apple describes the principal point relative to the image's top-left corner and intrinsic values in pixels: [ARCamera.intrinsics](https://developer.apple.com/documentation/arkit/arcamera/intrinsics). Its depth data is measured in metres: [ARDepthData.depthMap](https://developer.apple.com/documentation/arkit/ardepthdata/depthmap). Neither page supplies missing recording/body calibration.

### Existing capture corroboration, not additional evaluation

Already acquired EM1-0387 at dataset revision `a285cd1249fe9762085713a1c796ab68b1810ac2` has metadata SHA-256 `fa1cab04539609735af5282726a453ce8e8da1b63e45e372bd3a70e03303f1fa`.

Direct metadata inspection shows frame-zero coefficients `[1477.268798828125, 1477.268798828125, 956.9019775390625, 751.5174560546875]`, matching `K[0], K[4], K[6], K[7]`. RGB is 1920 x 1440 and native depth 256 x 192. This corroborates the documented order; it did not establish it. No projection or RGB-depth registration accuracy test was performed here.

## What this does not resolve

Record3D [author pose guidance](https://github.com/marek-simonik/record3d/issues/59) establishes camera-to-world, right-handed OpenGL, negative Z forward. [Author issue 27](https://github.com/marek-simonik/record3d/issues/27) explains the historical initial-orientation normalization and later `initPose` field. **The chosen recording's gravity/world association and exact `initPose` composition remain unresolved.** Its `initPose` is a 90-degree Z rotation; `poses[0]` is not identity. Do not assume the recording begins at session origin, declare that it was cropped, or blindly multiply transforms. No world projection is authorized or performed by this review.

Original tracking-state status, body-to-phone/belt calibration and independent obstacle/collision truth remain absent. Correct intrinsic ordering cannot supply any of them. Phone-plus-belt remains the intended architecture; these are evidence/integration gaps, not whole-product infeasibility.

## Prerequisites for geometric or missed-obstacle claims

1. Keep the current same-eight-frame **`acceptedDepth(Float32, actualConfidence)` yield** independent of intrinsics and pose. Report admission/rejection with original confidence, finite/range and actual sampling denominators. Yield is neither obstacle recall nor accuracy; correlated frames are not independent scenes.
2. Before image-local geometric evaluation, validate per-frame index/count association, matrix construction, actual dimensions/orientation, native depth confidence alignment, calibrated pixel mapping and edge uncertainty. Use the original per-frame array, not globally reused `K`. Keep invalid/rejected/unknown pixels separate from free space.
3. Before any world/body geometry, resolve pose/initPose conventions and independently establish time, tracking, body heading, mount/gimbal/belt transforms and uncertainty. Never replace missing tracking with `normal` or missing extrinsics with identity for an authority-bearing replay.
4. Before a miss-rate claim, preregister obstacle definition and independent labels/measurement reference, visibility/occlusion masks, depth-validity masks, relevant body/route swept volume, tolerances and denominators. Separately count outside-view, invalid/no-depth, confidence rejection, geometry errors and detector misses. A VLM class, accepted depth pixel or lack of warning is not collision truth.
5. Frame 0 is an observed close tabletop manipulation view, not a walking trial. This prerecorded stream cannot react to a controller. Keep its sensor-admission evidence separate from authored closed-loop A-to-B simulation and later synchronized phone-plus-belt hardware evaluation. No navigation-success or zero-collision claim follows from resolving this schema.

## Review outcome

The **intrinsic array-order provenance gap is resolved** by the official author and pinned demo, without code changes or numeric guesswork. This permits a later explicitly scoped geometry adapter proposal after its remaining contracts are approved; it does not expand the current admitted-depth-only evaluation scope. The stage-01 final review hashes and limited outcome remain unchanged.
