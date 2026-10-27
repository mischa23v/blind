# Completed visual development experiments and unrun incremental design

This is a **separate supplemental archive**, not a replacement of `blind-incremental-evidence-publication-78`. Its original two ZIP groups and manifest remain unchanged. All experiments here remain offline research on the same recording, not random/live/human-navigation success or safety validation.

## Completed dense-reference v3b

80 references accept **3/8 fixed development queries**, versus 1/8 with the sparse 20-reference candidate and 0/8 combined baseline. Gates are unchanged. Both reference density and inclusion of late eligible metadata IDs changed, so density alone is not isolated. The initial v3 missing-RGB resolver failure and its source/protocol are preserved, not overwritten or represented as a successful run. V3b resolves an existing local RGB path; no input frames were dropped or downloaded.

Train-only metadata, query-intrinsics-only metadata and evaluator-only poses are separate files. The estimator writes and seals estimates before the separate scorer reads query poses. This is input/process separation, **not an OS-enforced sandbox**. Reference poses may be globally optimized; query frames are reused development cases. Coverage diagnosis opens withheld poses only post hoc, not for retrieval or parameter tuning.

Calibration audit found no demonstrated gross scale/axis/crop mismatch, but did **not** independently certify physical RGB–depth registration. The original half-resolution pixel-center convention is retained; a correction requires its own frozen experiment. Camera orientation is not body heading, and rejected poses never become route inputs.

## Completed sequence v4: no endpoint gain

One, two and five observations each accept the same **2/4 CURRENT final-camera endpoints**. All seven Lucas–Kanade tracking attempts are rejected; tracking-only accepted poses: **0**. Every accepted endpoint comes from independent current-image localization. One sequence loses and reacquires localization; it is not continuous tracking. A good earlier frame is not counted as a fresh final pose. No generalized multi-view cold-start success or impossibility result follows from this small development comparison.

## Stage79 is NOT RUN

`blind-progressive-tsdf-path-protocol-79/` is diagnostic **design only**. No new TSDF/path execution or usability result is included. Independent review and explicit preflight approval remain required. Route evaluation is not available without current-prefix support and endpoints. Do not conflate this proposal with the completed stage78 air-occupancy replay.

## Contents, constraints and reproduction

Includes immutable completed reports, protocols, source, seals, compact train/query/evaluator metadata, input hashes, results and failure logs. Raw RGB/depth, meshes, binaries, caches and stage75 blocked package/workflow are excluded. The split pose/intrinsics JSON inputs are intentionally retained to audit estimator/scorer separation; the raw source recording is not bundled. This is not a standalone runnable dataset. Original runtime paths and dependencies remain necessary. Copy variant directories before rerunning: original programs may overwrite their own outputs.

Input attribution: Xuqian Ren et al., MuSHRoom, https://zenodo.org/records/10230733 and https://zenodo.org/records/10222321, CC BY4.0 (https://creativecommons.org/licenses/by/4.0/). No raw imagery or third-party binaries are redistributed.

`memory_package.py --metadata` prints deterministic RAM-only ZIP identity. `memory_package.py visual-completed-and-design OFFSET` emits at most 120000 base64 characters. `--check` verifies frozen member hashes, ZIP CRC and repeat-build identity without writing a ZIP. Parent task alone owns external publication.
