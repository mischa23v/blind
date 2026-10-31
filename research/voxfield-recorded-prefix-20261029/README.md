# Recorded three-frame prefix: engineering admission, not accuracy

2026-10-29. Read RESULT.md and INDEPENDENT_COMPLETED_REVIEW.json. Exactly three original Koivu training records were processed by B/C0/C1 using the same D1 core and N2 provider. All 36 shared-validator tests passed before engine construction; each arm received the same 1,296,420 admitted points. No mesh, reference/GT evaluation, recorded N1-vs-N2 quality comparison, full-run or physical-navigation result is included.

## Important denominators

Submitted points are not independent voxel updates. Endpoint merging, gradients and grazing behavior affect integration. All 20,783 unavailable normals kept their points; the six reason totals are 1,275,637 valid, 4,025 boundary, 3,403 missing-neighbour, 13,355 discontinuity, zero nonfinite and zero degenerate. Numerical validity is not calibrated normal confidence. The full per-frame range/reason counters and cross-tabulations are retained.

RESULT.md's “no rejected pixels or frames” means no additional validation rejection among pixels admitted by the frozen depth mask. It does not mean every raster pixel was submitted: axial depths at or beyond four metres were masked and counted. Zero-depth masking remained in the contract. More observed voxels or gradients in C1 does not establish fewer hazards, more correct support, better routes or a winning engine. The earlier small-object, N1/N2-quality, native-invalid-input and support/safety limitations remain unresolved.

## Independent publication review

The original packet checksums and independent review's matching resource/integrity/log/ELF hashes were verified. The publication reviewer recounted the 36-test pre-engine receipt and all nine saved submissions. All three per-frame raster-mask, normal-reason, range-band and range-by-reason matrix denominators agree; each arm totals 1,296,420 submitted points. No native run was repeated for publication. The completed independent review is preserved, including its 267-pin integrity check.

Only ephemeral absolute workspace prefixes in environment-specific files are replaced by <WORKSPACE_ROOT>; dual hashes are in PUBLICATION_REVIEW.json. ORIGINAL_PACKET_SHA256SUMS records pre-sanitization bytes and PUBLICATION_SHA256SUMS records published bytes. Raw depth/RGB, poses, maps, meshes, reference data and binaries are not distributed. SOURCE_INPUT_PINS.json supplies identities, not recordings or permission to redistribute them.

## Reproduction constraints

The adapter/runner is a retained Linux source record, not a self-contained checkout command. A reproduction requires lawful access to the exact input records and matching raw decoding, original per-frame intrinsics/pose manifest, existing reviewed D1 build, N2 header, dependency prefixes, and a separately reviewed local freeze. The pose/input manifest and original local execution freeze are not bundled. Do not synthesize missing calibration or invoke the placeholder script expecting unpublished paths to exist. Keep all masks, pixel order, domain gates, empty-map starts, persistent integrators and bounded resource guards unchanged when evaluating equivalent execution.

The prior voxfield-build-gate, zero-direction-candidate and numerical-normal-candidate checkpoints document dependencies and candidate changes. Official source: https://github.com/v4rl-ucy/voxfield/tree/78ee6403720e0aed87f4720c04c813bb38a3b260 ; BSD-3-Clause licence included. Third-party and recording licences remain separate. This result grants no automatic full-run/export/scoring admission.
