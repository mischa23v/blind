# Pose-consistency arithmetic checkpoint — completed stage 16

This small additive checkpoint preserves the six external repository files at commit
`e79385e5a626c17b87e7be708f09fdc166ef5831`, an exact-source arithmetic reproduction,
and independent source/saved-array reviews. It does **not** include later stage 17
work or adopt a pose correction, floor model, fusion rule or navigation policy.

## What actually completed

The bounded replay processed all **294** original processed-depth frame associations:
**252 fitted frames, 78 flagged fitted frames, and 42 no-fit frames**. The 78 gate
uses absolute centroid offset >2.5 cm **or** tilt >1.2 degrees; 174 fitted frames
are unflagged. The external script's final printed 3 cm variant flags 77, not 78.
All reproduced frame IDs and inlier counts match the saved external planes; the
largest saved plane-field difference is **6.93e-14**. This reproduces arithmetic,
not physical accuracy or a uniquely identified cause of the inconsistency.

The original D1 low-supported/not-high denominator is **574 cells**:

| Evidence group | Cells | Supplied reference vertex-proxy positives | Reference-covered cells |
|---|---:|---:|---:|
| Only flagged/inconsistent frame hits | 194 | 4 | 194 |
| Any unflagged/consistent fitted-frame hits | 65 | 7 | 65 |
| No near axial-band hits | 315 | 45 | 314 |
| No-fit hits but no consistent fitted-frame hits | 0 | 0 | 0 |

These groups were independently recounted as disjoint and exhaustive. The one
uncovered reference column is in the 315-cell group. The reference score is a
**supplied vertex-column proxy**, not continuous mesh/body clearance or a safety
label. Negative/uncovered proxy values are not proof that a hazard is absent.
D1 is not the active split0.7 routing mask. No-hit is not proven far-only native
voxel provenance. **No evidence was deleted, converted to free space or used to
modify a route.**

The replay reports 13,415,808 samples, zero zero-depth samples, and axial-versus-
Euclidean threshold-membership disagreements of 970,921 at 2 m and 474,687 at
4 m. Those sample-level counts were not independently recomputed from the saved
cell arrays. The replay preserves the source's Float64 projection and axial-range
semantics rather than quietly substituting the mapper's Float32/radial sequence.
Runtime: 10.576 s wall, 10.475 s child CPU, 80,232,448 B observed/waited peak RSS;
limits were sampled/process based, not a hard cgroup guarantee.

## Keep the external ICP failures visible

All **ten** saved external ICP cases and the exact source are retained. ICP was
**not executed in this reproduction**. The independent review identifies six
flagged fitted-frame trials, three unflagged fitted controls and one no-fit trial.
Only five of six flagged trials improve absolute centroid offset. Index 104
worsens, and index 150 has fitness zero: RMSE zero there is a no-correspondence
failure, not perfect alignment. Controls also deteriorate. The original README
showed only eight cases; this packet does not drop the other two.

Full rigid transforms and before-registration correspondence metrics are absent.
An ICP translation column is not the camera's physical displacement: for old
camera centre c, that displacement would be (Q-I)c + u. View-dependent geometry
is demonstrated; tracking drift is plausible but is not uniquely established
against depth/export/calibration and selection effects. Per-view floor fits do
not authorize clearing low objects or unknown support.

## Exact bytes, attribution and reproduction boundary

`blind-pose-consistency-review-16/` retains the original relative stage layout.
The six `upstream/` files are **byte-identical**, including their claims and all
saved cases; treat the independent reviews as the assessment, not the upstream
README alone. `SOURCE_PINS.json` and `EXTERNAL_SOURCE_VERIFICATION.json` identify
commit, official repository URL, Git blob SHA-1, SHA-256 and actual byte size.
`FETCH_MANIFEST.json` is retained as historical fetch evidence; its contentBytes
field is not a substitute for the verified actual UTF-8 byte length (notably the
README). Repository-owned code is attributed to its source, with no invented
license grant or reassignment. No external runtime code/binary is redistributed.

All executed Python sources are unchanged. Public review prose and runtime-path
receipt copies are normalized only as listed in `NORMALIZATION_MAP.json`.
Original source/data/binary/hash fields still identify historical originals.
In particular the normalized `FROZEN.json` is **not** the original launch manifest
and must not be passed off as byte-identical runnable replay evidence.

A separate reconstruction would require the original 294 processed-depth frames,
exported poses, supplied D1 metadata, matching Python/NumPy/Pillow, correct stage
layout and controlled depth symlink. These are excluded, with identities in
`EXTERNAL_DEPENDENCIES.json` and the preserved freeze. Source programs may reject
normalized manifests or missing inputs by design. Rehydration/relocation needs a
separate documented source/manifest cut and validation; no clean-machine rerun is
claimed. Independent recount scripts are preserved but were not rerun for this
publication. Packaging only checked file bytes, attribution, hashes and privacy.

Excluded: input/depth symlink; all raw RGB/depth/pose files; original map input;
installed runtime/binaries/caches; all later stage 17 code/results. No personal
profiles, private participant details or screenshots are included.

Terminal original `RESULT.json` SHA-256:
`4ee880e20500252df73496f1ee1870872e8315d7fb565a04eec701cd2e39514d`.
Original `FROZEN.json` SHA-256:
`69751728c2cb9f466ebe3c496e8cd0ea6ecbcd2de888983731130e25e993f721`.
