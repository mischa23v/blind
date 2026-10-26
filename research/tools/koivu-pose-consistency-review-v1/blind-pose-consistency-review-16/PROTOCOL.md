# Exact external arithmetic reproduction

## Scope frozen before execution

Reproduce `cause.py` and `gate_check.py` at commit
`e79385e5a626c17b87e7be708f09fdc166ef5831` against the already verified
294 Koivu processed-depth frames, original exported poses and supplied
`koivu_5cm_v2_pipeline2_out.npz`. Preserve the original Float64 projection,
integer sampling pattern plus half-pixel projection, axial-depth thresholds,
trimmed least-squares floor fitting, D1 masks and final saved vertex-column
reference proxy. This is not the active split-0.7 routing-mask reproduction.

Compile the unaltered `frame_pts` and `floor_fit` function ASTs, then execute
the unaltered gate statements beginning at `bad = ...`. Avoid the original
import side effect that would repeat and overwrite the plane result. A local
symlink redirects only the input depth directory; frame metadata is unchanged.
All input and source hashes are checked before and after execution.

Report every fit, exact fit availability and inlier counts, maximum numerical
differences from the saved planes, both the original gate's categories and its
otherwise unprinted no-fit remainder. Save all per-cell hit counts. Count zero
depths and axial-versus-Euclidean threshold membership differences separately;
these diagnostics never substitute a corrected predicate into the reproduction.

The source's final `cause.py` print uses 3 cm but its gate/README use 2.5 cm;
the independent saved-JSON recount reports both. All ten saved ICP cases are
reviewed, including omitted or failed cases, but **ICP is not executed**.

## Limits and outcome

One serial child, 120 CPU seconds / 180 wall seconds, 768 MiB sampled or waited
RSS, 8 MiB outputs, 768 MiB free-disk reserve. Preserve terminal failure and all
partial outputs. No dependency installation, raw-data alteration, point/pose
correction, fusion, model adoption, route queries or movement. Saved reference
column values are used only in the original final evaluator count; no reference
mesh is loaded and no reference value participates in fitting or tagging.

Plane residual agreement is source-arithmetic evidence, not a metric accuracy
test or proof of pose-error causation. Inconsistent/no-fit evidence stays present;
none becomes free space. Axial-range provenance and missing complete native key
history limit any inference about probabilistic occupancy. The supplied vertex
proxy cannot establish absence of reference surfaces or physical clearance.
