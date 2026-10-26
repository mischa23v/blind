# Author baseline input freeze proposal

## Subsequent authorized extraction: complete

The original proposal below is preserved. After separate approval, `extract_train_rgb.py` extracted exactly its 265 training RGB files plus `test.txt` into `selected/`, totaling 47,902,957 bytes. No test RGB, depth copy or other archive member was extracted. All new file hashes are in `EXTRACTION_RECEIPT.json`; `READY_TRAIN_FRAMES.json` supplies workspace-relative RGB/depth paths in the original training-frame order. Every RGB header is JPEG, 738×994; no pixel resampling or fusion was performed. Full archive SHA-256 was checked before and after extraction; 191,404,544 decompressed bytes and 12.71 seconds stayed within the authorized limits.

Exact author `camera_utils.py` is retained in `upstream/` (7,143 bytes, SHA-256 `370bcfa4b45a0335dbd42c037368a020eae5d2533dc07877e9d7711ae5510f85`). Its AST-read, unexecuted `OPENGL_TO_OPENCV` assignment is the diagonal matrix `(1,-1,-1,1)`. Preserve that author basis conversion and supplied intrinsics; do not add an undocumented half-pixel correction.

## Original proposal-stage record

This directory contains unmodified DN-Splatter source at commit `97588b4290128ce7ba6fdbfaac3020b42b17de4c`, its Apache-2.0 license, and a proposed dataset selection. No mapper was executed and no Koivu RGB file was extracted by this step.

`SOURCE_ACQUISITION.json` pins the original source URLs, sizes and SHA-256 values. `pointcloud_utils.py` plus `LICENSE` total 21,650 bytes. `prepare_author_inputs.py` is the separately authored bounded inventory/acquisition helper; it does not import the upstream module or Open3D.

`PROPOSED_KOIVU_SELECTION.json` retains original pose order and the author's exact `test.txt` split:

- 294 supplied frame entries, 265 training IDs and 29 excluded test IDs; no missing test IDs.
- 265 proposed training RGB members total **47,902,609 bytes**; original `test.txt` adds 348 bytes: **47,902,957 bytes** proposed new payload.
- 15 additional long-capture RGB members without supplied pose entries are excluded, not assigned fabricated poses.
- Existing depths are reused from `blind-koivu-game-07/map/depths/`; the prior extraction manifest is hash-pinned, frame/size associations checked, and recorded per-depth hashes carried forward. Depth content was not redundantly rehashed in this inventory step.
- Original `transformations.json` and provided `transformations_colmap.json` have identical parsed frame lists, though their complete-file hashes differ. Both file hashes and the depth-manifest association are recorded.
- The original archive inventory has no per-RGB hashes. Proposed RGB hashes are explicitly null and must be populated from a later authorized guarded extraction. No hash is inferred from a filename.

Only `test.txt` was read into memory from the existing archive to verify its exact 348-byte hash and split. It was not extracted here. All paths in public-facing manifests are workspace-relative. This proposal is not permission to extract RGB or run integration; those steps require the separately reviewed byte/resource plan.
