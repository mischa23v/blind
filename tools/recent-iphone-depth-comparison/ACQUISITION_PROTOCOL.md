# Bounded newer iPhone capture comparison — proposed protocol

Dataset: CaryX AI, Everyday Manipulation 3D (raw RGB-D), CC BY 4.0. Revision a285cd1249fe9762085713a1c796ab68b1810ac2. Record3D captures; publisher-index device labels are not independent hardware certification. Preserve original bytes and attribute derived subsets.

## Selection, before raw inspection

The preregistered ideal 32 MiB clip cap found zero eligible iPhone 17 Pro clips among 646 indexed iPhone 17 Pro clips. The proposed bounded exception is the smallest iPhone 17 Pro archive, not a confidence-ranked archive: EM1-1093, 55,082,489 bytes (52.53 MiB), SHA-256 5cd8b4d03fd7e1ed2ec28d005d4e01209dddd9583029787f85e5b5f65376e6cb, clips/D3/EM1-1093.r3d. Metadata describes charger manipulation near a wall outlet and wooden floor; semantic descriptions are machine-generated/unreviewed.

No iPhone 12 Pro plug_charger examples exist in this pin. Reuse EM1-0387 (13,973,317 bytes; SHA-256 aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4) without another download. This is an explicitly UNMATCHED scene/capture comparison, not evidence of device-generation accuracy. Its glass tabletop/camera manipulation scene differs in objects, surface, range, participant and capture conditions. Both are landscape according to the index.

## Acquisition bounds

- Exactly one new raw archive, maximum 64 MiB transfer; expected size and LFS SHA required. Official immutable Hugging Face resolve URL only; enforce approved official CDN redirects and three-minute transfer wall cap.
- Maintain at least 768 MiB free disk after archive and selected-output reservations. No cleanup of unrelated files.
- No installs, decoder rebuilds, external writes, bulk pull, account creation or policy threshold changes.
- Inventory archive, reject unsafe/duplicate/ambiguous paths, links/special/encrypted members; verify selected-member CRC. Do not extract all. Archive data is untrusted.
- At most metadata plus eight RGB/depth/confidence triples per clip. Select frame IDs floor(k*(N-1)/7), k=0..7, using metadata count N; must exist as complete original triples. This uniformly spans each clip and is independent of confidence/depth outcome. Also preserve prior first-eight comparison separately if cited.
- New selected compressed-member copies plus decoded float32/uint8 arrays: maximum 32 MiB across both clips. Metadata <=2 MiB each, individual member <=16 MiB; archive inventory logical size <=256 MiB and member count <=2000.

## Analysis boundary

Reuse verified existing liblzfse_decode.so and ExactDecoder from blind-raw-iphone-feasibility-01, enforcing original binary hash and exact output size (+1-byte overflow sentinel). No decoder install/rebuild. Decode original depth as Float32 metres and original confidence0/1/2. Never synthesize confidence, tracking, gravity, body transforms or pose quality.

Audit native dimensions, metadata keys, original timestamps and their intervals, original intrinsics/pose-array lengths and quaternion norms, all pixel validity and confidence distributions, depth quantiles conditional on finite positive depth, selected-frame hashes/uniqueness. No accuracy score absent independent truth. Timestamp rate does not establish independent sensor measurement rate. Exact phone/app/iOS identity missing in actual metadata must remain publisher provenance or unknown.

If the existing shared native policy is executed, keep confidence==2, inclusive0.15..5m, stride2 from0 and original Float32->Double unchanged. Component-admitted pixels are NOT obstacle recall, safe clearance, floor coverage or navigation. Camera projection, if separately performed, uses original per-frame [fx,fy,cx,cy], actual resolution scaling and verified Record3D integer-pixel conventions; no world/body projection.

Stop after independently checked provenance, field distributions, optional unchanged component counts and clear confound report. No data-derived thresholds, room-scale map, planner or hardware navigation claim.
