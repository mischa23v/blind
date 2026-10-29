# Coffee tabletop retention — corrected Stage B actual result

**The camera-local native retention check passed for all three frozen regression frames.** Every retained measured endpoint reached an occupied OctoMap key with one scan vote; every key in each selected tabletop inset remained occupied; the untouched-volume control remained unknown.

This establishes the bounded native-retention checkpoint, **not recovery of the actual table corner, a registered map, collision avoidance or app readiness**. The execution owner ran the corrected source at commit `05e68926f69fa4dfd2566fb50c9e22453cd4e568`. This report independently verifies the existing receipts, source and input bytes without rerunning projection, controls or native code.

## Actual three-frame result

| Frame | Retained measured endpoints | Distinct endpoint keys | Tabletop-inset endpoints | Tabletop-inset keys | All inset keys occupied | Untouched volume |
|---|---:|---:|---:|---:|---|---|
| `frame_00290` | 623,396 | 8,582 | 5,000 | 37 | Yes | Unknown |
| `frame_00357` | 465,044 | 7,170 | 2,100 | 37 | Yes | Unknown |
| `frame_00391` | 733,572 | 8,822 | 4,000 | 20 | Yes | Unknown |

The actual process exit is zero, stderr is empty, and [STAGE_B.json](STAGE_B.json) records `completed` with exactly three frame results. Each frame starts an independent tree and inserts one scan numbered zero. For every frame, occupied-key count equals representative-ray count and distinct endpoint-key count; no hit/free conflict is reported.

Across the **three separate trees**, this is 1,822,012 retained endpoints, 24,574 endpoint-key observations and 94 tabletop-inset key observations. These totals are not unique cells in one fused map, independent sensor measurements, table dimensions or obstacle-clearance measurements. Selected inset patches do not define the table perimeter or corner.

## Independent checks

[VERIFICATION.json](VERIFICATION.json) records the detailed checks and hashes:

- Every non-native frame field exactly matches the [earlier Stage A result](../coffee-table-retention-stage-a-result-20261029/), including projected Float64 point hashes, counts, supplied intrinsics and full diagnostics. No projection, selection or floor-plane result changed to obtain this result.
- All seven files in the corrected source packet match the exact published Git blobs. The runtime source, wrapper and source-control hashes agree with their pins; the actual retained native library matches the approved rebuilt digest.
- All three original depth rasters, original transformation/calibration input and frozen evaluator selection match their recorded SHA256 identities. Receipt counts account for every original 738 × 994 pixel.
- Input counts equal native insertion counts; one scan per independent frame, nonempty tabletop sets, occupied inset keys, no floor clearing and unknown-volume controls are checked in the result.
- The completed source path enforces that every endpoint key is known and occupied and has exactly one hit-scan vote. Those assertions are evidenced by the exact source and successful frame receipts; this reviewer did not independently requery the native arrays or recreate their key hashes.

The full successful receipt SHA256 is `8f30237fde395b589af4f54464d1ca8a124634a94a77b86dba5985879b1c5fed`. The library SHA256 remains `0a044001b1455634ab881cc42fb5954362d960abf5cd851b7b6dc99b6c3eb963`.

## Default-guard correction and retained failure

The [first failed Stage B result](../coffee-table-retention-stage-b-failed001-20261029/) remains preserved byte-for-byte, SHA256 `a8ece6ca766853628ce6bfdf10e0b4be3acad2e9c4889ad01e0dfa6188e4c107`. It failed at the default-value guard before inserting the first scan; it was not replaced or relabelled successful.

The [separate corrected source](../coffee-table-retention-default-guard-source-20261029/) changed only the three default-probability comparisons from strict `1e-12` to absolute inclusive `1e-7`, matching the original native controls, plus an explanatory comment. No native default, occupancy threshold, geometry, point, frame, floor filter or resource limit changed.

The successful native result now confirms the source-predicted float-log-odds representation: hit `0.69999999724559`, miss `0.40000000284949333`, occupancy `0.5`. Their small roundtrip differences from the source decimals explain the earlier overly strict guard; they are not altered mapping parameters.

[CONTROL_STATUS.json](CONTROL_STATUS.json) keeps the different suites distinct:

- **8 Stage A controls:** passed, independently checked against the retained actual log, source names and zero exit.
- **16 original native adapter controls:** passed with zero failures/errors/skips, independently checked through the retained hash-bound receipt in the [native-build result](../coffee-octomap-build-result-20261029/).
- **7 pure-stdlib default-guard controls:** the execution owner observed all seven passing in 0.004 seconds with exit zero before publication. The reviewer verified the seven source tests/hash and saved execution summary. No raw unittest output file was retained, and none is fabricated here.

The source/first-failure documents' statements that a corrected replay was still pending describe their earlier checkpoints; this separate actual-result packet records the later completed replay.

## Bounds and unresolved evidence

The invocation retained 120 CPU seconds, 512 MiB process address space, a parent 180-second wall deadline, one CPU and bounded outputs. The receipt reports peak RSS of 173,584 KiB. Actual elapsed CPU/wall totals are not present in this receipt and are not invented here.

The input is a processed registered export, not an independently validated native-confidence stream. Positive axial depth strictly below 4 m is retained; the 378,704 range-excluded pixels remain unknown. No floor removal or synthesized tabletop was introduced. RGB-selected inset patches and fitted floors are evaluator-only. Defaults are mapping weights, not probabilities of physical safety.

These three frames were already used to discover the issue; they are regression cases, not held-out real-world accuracy data. Cross-view alignment, mesh-camera registration, camera/sensor uncertainty, synchronization and actual corner extent remain unverified. Stage C is absent. No route was rerun or accepted, and the previously rejected corner-clipping route stays rejected. There is no 90%-accuracy, localization, clearance, physical-safety or release-readiness claim.

## Next narrowly testable step — proposal only

Before combining these camera-local hits with the source mesh, verify the supplied camera-transform direction, axis convention, units, frame association and mesh-frame provenance against the retained export/source documentation. Then freeze that documented transform chain and test its alignment on independent static **non-table** scene evidence before evaluating the tabletop. If a required convention or association cannot be established, report registration as blocked rather than guess an axis flip, tune against the table, draw a tabletop or infer its corner.

This report performs none of that registration work and introduces no SLAM, mesh repair or new navigation algorithm.

## Publication boundary

The packet contains only text result evidence and review metadata. No raw RGB/depth capture, transformation file, native binary, absolute host path, environment dump or archive is included. Original failed evidence remains in its sibling packet. [PUBLICATION_MANIFEST.json](PUBLICATION_MANIFEST.json) lists every payload file with byte size and SHA256; it excludes itself. No Git staging, commit or push was performed by the reviewer.
