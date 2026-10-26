# Genuine recorded iPhone input feasibility — bounded field audit

## Verified result, not a navigation result

The exact pinned **CaryxAI EM1-0387 iPhone 12 Pro recording** was acquired and checksum-verified. Eight original depth/confidence pairs were decoded with the official LZFSE C decoder, eight original RGB headers checked, and RGB frame 0 visually inspected. The actual content inspected is close tabletop manipulation, not a walking-room benchmark. No reconstructed mesh or synthesized confidence replaced the recording.

Across the eight 256×192 confidence maps, original counts are **114,597 low / 151,464 medium / 127,155 high**. All values were retained. The recording has 89 timestamps, poses and per-frame intrinsic entries. Actual timestamp intervals are approximately 0.066674 seconds, or 15 Hz, despite configured `fps: 30`. Frame timestamps must be used rather than inferred from that setting.

**Still unavailable/unresolved:** original ARKit tracking state, calibrated body/phone/belt extrinsics, independent obstacle/collision truth, gravity association through `initPose`, and independently verified four-coefficient ordering for `perFrameIntrinsicCoeffs`. Original coefficients are retained without projection. The full original `K` matrix is retained, but this audit does not estimate missing data or perform world projection.

No native hazard replay, localization, floor/body clearance, detection miss-rate, or A→B success was claimed or run. The existing Linux transport's hardcoded normal tracking was not used. A fixed recorded clip cannot establish that a human followed an alternative route.

## Exact provenance and resources

- Publisher: [CaryxAI Everyday Manipulation 3D](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw). Dataset license **CC BY 4.0**, retained verbatim in `DATASET_LICENSE`; attribute CaryX AI and the exact dataset/revision. Publisher says sensor entries are unmodified except removed audio. Device identity comes from the pinned publisher index, not a device-model field in the clip metadata. Machine-generated task labels are not ground truth.
- Revision `a285cd1249fe9762085713a1c796ab68b1810ac2`, file `clips/D2/EM1-0387.r3d`, **13,973,317 bytes**, SHA-256 `aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4`.
- Selected originals: **1,293,840 bytes**; decoded depth/confidence: **1,966,080 bytes**. Including retained pre-review decoded evidence, total selected/current/prior decoded files remain **5,257,412 bytes**, below the 64-MiB cap. Free disk after final audit was approximately 1.083 GB, above the 768-MiB reserve.
- Decoder: [official LZFSE C reference](https://github.com/lzfse/lzfse), pin `e634ca58b4821d9f3d560cdc6df5dec02ffc93fd`, **BSD-3-Clause** notice retained. Verified 18 source/notice files, **213,037 bytes**; no package/OS install. Four existing decoder C files compiled serially with gcc 14.2.
- Actual compile: **0.536 seconds**, peak child RSS 25,216 KiB, binary **33,328 bytes**, SHA-256 `75e52786bd0cfc5ede9e1f08f87dc752778fffe2f6c3957e318c534e5f457d61`. The 270 upstream signedness/computed-goto pedantic warnings are retained in `decoder/build.log`; no vendor source was modified.
- Final same-eight-record field audit: approximately **0.032 seconds**, peak RSS 28,124 KiB. **8/8 codec/receipt-boundary tests pass**. Rechecking the same eight records did not become sixteen independent frames or journeys.

The first download attempt stopped before reading clip bytes because the official redirect used `us.aws.cdn.hf.co`, which was outside the initial explicit host guard. Its zero-byte partial/log were preserved, the official pinned redirect was checked, then the exact host was admitted and the final hash verified. No arbitrary URL or account credential was substituted.

## Independent review and boundaries

Read-only review found no blocking defect for this exact bounded audit. It corrected unsupported coefficient-order attribution and RGB-decode wording. Final guards bind the approved clip hash, exact IDs 0…7 and an explicit source-path whitelist; validate basic `initPose`/intrinsic shape; bound allocation and decoder output; and distinguish ZIP member metadata checks from CRC checks of the selected members. The output buffer allows one detection byte beyond expected size and rejects any result not exactly the expected frame size.

The review did not rerun tests or imply a general-purpose archive security certification. Prior annotation receipts/source remain in `annotation-v1` locally; source-only publication omits raw assets and decoded data.

## Existing hardware direction

Phone-only was never the final hardware requirement. Existing `hardware/BUYING_PLAN.md` describes the **belt as core** and phone-first as a development stage. `PHONE_BELT_INPUT_PROTOCOL_REVIEW.md` records current BeltLink/protocol/WearableEvidence/firmware reuse, synchronization/extrinsic/coverage requirements, gimbal limitations under the current fixed mount model and two source-level validity/timestamp issues to resolve before map fusion. No sensor purchase or new hardware specification is implied.

## Next separately approved stage

`DATA_AUDIT_PROTOCOL.md` was written before this acquisition. Before broader perception evaluation, freeze the input/ground-truth/coverage protocol with the protocol maintainer. The narrowest possible next component test is the unchanged shared `acceptedDepth(Float, confidence)` scalar/raster gate using original Float32 metres and original confidence. Do not quantize into the old uint16-mm transport, invent tracking, infer gravity, or turn acceptance yield into obstacle recall/body clearance. Any later camera projection must first resolve original per-frame intrinsic ordering and coordinate conventions.

No new Recast/planner features, detector thresholds, sensor-fusion behavior or navigation episodes were added in this field audit.

## Reproduce the bounded audit

The scripts are designed to refuse overwriting existing captures/partial outputs. Use a fresh working directory, inspect the pinned receipts and protocol, then use existing Python/NumPy/Pillow and gcc:

```sh
python acquire_exact_inputs.py
python build_decoder.py
python select_recorded_frames.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python audit_decoded_fields.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python -m unittest -v test_decoder_contract
```

This source-only packet contains no clip, RGB/depth/confidence frame, raw full pose sequence, reconstructed mesh or compiled binary. Download limits, original license and attribution apply to any later materialization.

## Public copy note

This is a public-normalized copy; see `PUBLIC_NORMALIZATION.md` for path placeholders, original-versus-public hashes, configurable wrapper changes (where applicable), and the exact limited verification performed. Historical execution claims above describe the original pinned source cut, not a new run during publication preparation.
