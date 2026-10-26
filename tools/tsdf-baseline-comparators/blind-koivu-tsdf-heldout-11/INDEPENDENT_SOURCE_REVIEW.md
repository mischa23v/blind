# Independent source review — fixed held-out TSDF check

**Review scope:** source/provenance review only. No fixtures, image decoding, VTK imports, mesh loading or ray queries were performed by this reviewer. This note records the completed pre-execution review and the earlier independent SHA-256/byte-count recheck; it is not a result review. The subsequent run is owned by the maintainer.

## Disposition

No remaining concrete blocker for the approved fixed 29-frame same-capture held-out consistency check. This is not independent physical accuracy, obstacle recall, clearance or navigation validation.

The final freeze SHA-256 is `e138a8cd7e0fac1afd86beb446c8036d4d20558e45c578454702fbb87f295a9a`. The freeze itself and **all 39 listed source/input files** were independently rehashed before the maintainer was given clearance; every SHA-256 and byte count matched. The table below is the exact checked inventory. No original or frozen file is modified by this note.

## Reviewed final sources and addressed findings

- `evaluate.py`: `30b7fa320f9f2d369080e75e96f5f20fcdce5f2793ade3b698b51c7560b23cf2`.
- `freeze_inputs.py`: `023ede0ead11088c439843a38dc4debf5e43c51deb9087023a4f0606c10e9388`.
- `run_bounded.py`: `cf9cfaa07e750c96966618dab81df7d442f02b56eb67fed9cc7b11d47f4eabdf`.
- Reused stage-06 `reference_geometry.py`: `266026051a781f122a59187f599688e8c5eb38807984b7e607401e7b4356386d`.

Three concrete review findings were addressed before final clearance: (1) launcher and evaluator require the external expected freeze SHA before parsing, with propagation to the worker; (2) the reused geometry helper is anchored to its exact previously reviewed SHA; (3) disk accounting includes allocated file and directory blocks plus a 5 MiB outside-metadata reservation, ignoring only entries that vanish during concurrent temporary-file moves.

## Scientific and bounded-execution review

The fixed original 29-frame split is disjoint from the 265 integrated frames. Integer-centre camera rays match the chosen Open3D training convention; the old +0.5 builder is not used. Mesh queries use identity phone-map registration, nearest two-sided hits, and geometry-only far bounds. PLY vertices/triangle indices are validated; original double coordinates are checked against VTK readback with a 1e-6 m maximum permitted difference, without filtering geometry.

Every one of the scheduled 1,335,885 rays remains in the six sensor-state/mesh-hit categories. Primary paired errors are mesh minus measured sensor depth for 0 < sensor depth < 4 m; mesh predictions >=4 m are retained. Missing and out-of-domain data, range bins, edge categories and per-frame denominators remain explicit. Pooled quantiles operate on pooled samples rather than averages of frame quantiles. No FARO, confidence fabrication, world-tracking authority, pose refit or navigation is introduced.

The launcher checks source/input pins before and after each phase, confines outputs to an exclusive run directory, preserves JSON results separately from progress, and enforces the approved sampled process-tree CPU/RSS, wall, output and disk-reserve bounds. Sampled RSS is not a hard cgroup guarantee. The review does not certify the later runtime outcome or physical safety.

## Exact 39-pin inventory checked before clearance

Paths are relative to `$WORKSPACE`.

| Role | Path | Bytes | SHA-256 |
|---|---|---:|---|
| trainingFreeze | `blind-open3d-author-baseline-10/KOIVU_FROZEN.json` | 172958 | `89e4f8add800d85b772a5314f88c45dbecb1dd5536c0b61c9f5f533727f942d4` |
| protocol | `blind-open3d-author-baseline-10/HELDOUT_PROPOSAL.md` | 9752 | `909353833c2d117b75ac0669159c0a318ffb9b49281163bc4f2747c3ea10984c` |
| mesh | `blind-open3d-author-baseline-10/koivu/unfiltered-tsdf-mesh.ply` | 12538508 | `5a75ebce93a3c65928344ce486223aa17a01a2c196982fc97edff8c41dd56e2e` |
| pose | `blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json` | 239937 | `c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3` |
| testSplit | `blind-open3d-author-baseline-10/author-inputs/selected/test.txt` | 348 | `60833925e50adeade36f127ad6035e86bf17f206e7f1d8b53f1eee96731ba97d` |
| depthManifest | `blind-koivu-game-07/map/depths/DEPTH_INPUT_MANIFEST.json` | 76007 | `8795ad2625e49336031a6a826e8247b6cbcc8bb3867f7c27a640a89ee049c82c` |
| source | `blind-koivu-tsdf-heldout-11/evaluate.py` | 12757 | `30b7fa320f9f2d369080e75e96f5f20fcdce5f2793ade3b698b51c7560b23cf2` |
| source | `blind-koivu-tsdf-heldout-11/run_bounded.py` | 11642 | `cf9cfaa07e750c96966618dab81df7d442f02b56eb67fed9cc7b11d47f4eabdf` |
| source | `blind-koivu-tsdf-heldout-11/freeze_inputs.py` | 4721 | `023ede0ead11088c439843a38dc4debf5e43c51deb9087023a4f0606c10e9388` |
| source | `blind-koivu-reference-comparison-06/reference_geometry.py` | 10435 | `266026051a781f122a59187f599688e8c5eb38807984b7e607401e7b4356386d` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00011.png` | 246513 | `deaa45692897429887601de4da5c57cb351eac3ec42f78aac6fccff38e4b90f9` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00021.png` | 243972 | `4aa18a6102948815c77d89de5b8584727e459e9c094c32898b9fe37ddf6a8da5` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00031.png` | 255960 | `bbf6b34ecd977f91d33f6169b6d9a06c5255f2dde710e96e07e9604c733ec3d6` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00041.png` | 221436 | `686f6df138de34120ceb8f980a2279ce2c3e3b6a6cb71ebf551c0f6dc2789230` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00051.png` | 234117 | `f1d9ad82dc484057309421c4738967ca0150120135d54a380793ed9eca55dc4e` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00061.png` | 219290 | `825cedbcee4c387a68a623af8206e303c1a2ad1b2e0a156f3576e8382f1aa1f8` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00071.png` | 236869 | `5e970423f77fa97e0d26cc231e909b099d6b099c409dabd91e767161c2611f40` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00081.png` | 216546 | `5fa55f85ec0774c9f5fe1031fbe75e26ace5e66e6f656ff2e95e1541c2e9648e` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00091.png` | 260947 | `7abe032a5d666e1a211d5687fae86e6797ad2048e19a0ce958288913252c24fb` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00102.png` | 189939 | `48d0b76607db09674be25713acbabd34b9e6604809da4683d1cb32cac1285970` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00112.png` | 233935 | `879400d3a1427ef4749d52001f8dfb76fbba26b55aad12a9374a0c5a3d319cfa` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00122.png` | 246830 | `823c1bb77426b3dcdb9efd8294be5c28df56fab0bb9709153d09bc28425c4df4` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00132.png` | 267614 | `7374e6fea3c86a67d99624736528d86227ba8ab9e62d81e86779940d0a4be1c0` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00142.png` | 253979 | `d748c70dcee209c13397ef7b1b8ed101f9e4bced0f60483fea4207c540acde27` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00165.png` | 255048 | `2776815a9b55a014dd412467c98c8f5432c111c332b9313685c051dce04a77d2` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00176.png` | 193741 | `a105a79e5191adb66f5848ad192fbae37bfcb317e06185cf3e4398791a9eb4fa` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00187.png` | 242441 | `51dfe96bc6efb94c79c6dd0ed18d4dd6ccddd69391af1c4eadc51f49dadce098` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00197.png` | 224962 | `b5401b3524afac74e89e8ce4c38834271188367ffb9aa7191922c182ef630573` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00207.png` | 200349 | `4cffb51bf44eadf162162bbe98f1d5011ca668c19f7fca76bcf7f736f4c9ec32` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00218.png` | 248524 | `42cd3254cf202f3ae835437fc497f5475951ed7ec8f85c1772f5a18f492906aa` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00228.png` | 220731 | `8ba7cd49144c4871e2639c503cc2bd0c02344b628b393e8378bc2ae951448f43` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00238.png` | 198611 | `4268bf405f56c632e743b0f35bc8454cf62543e578176102dead5efb00263dad` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00248.png` | 194780 | `29c3f7931439cd1811bff62a18ad9202887a0e5dee516267d92d87a977f4567f` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00258.png` | 162387 | `871f11bcef39f4db4f1d075b3130fd4f6f5b5a649087e588fccfddd98fa1df8e` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00268.png` | 208411 | `952eea557385aa8c93fd9b0dc49745fb62dfeeed0728f09ee1027998d50abebf` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00278.png` | 239523 | `ddfad4ca084464f4eb4b40e29ef6d00f722b49698da2de665af434ca6a64261b` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00288.png` | 252114 | `5c7e89994265dba83e226a9ddfe2038e3d137e384c1a86bc952ed63e09b6d3dd` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00298.png` | 204160 | `65466f938fa97d351761988f02fef87314a8fbb1d1c66bca8167c16197aac7f9` |
| heldoutDepth | `blind-koivu-game-07/map/depths/frame_00308.png` | 240601 | `d9e2c836508115633aa1a15e26f94a677d35a899c55385f475a2bef8d0bd4dbc` |
