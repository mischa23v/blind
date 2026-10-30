# Frozen diagnostic protocol, source-only

## Stage A — first execution admission (controls only)

Publish the prepared source/evidence packet under `<repo>/research/<packet>` and bind its exact Git HEAD. Independent review must cover `RUN_PINS.json`, `SOURCE_FREEZE.json`, source, analytic expectations and guard. Copy only publication files and source evidence, not the acquired package, room meshes, V1 history or attempted results. The package remains the separately pinned external acquisition. Preserve existing V1/history in preparation.

Prepared command shape (not run; replace only the published packet path and exact admitted commit):

```
env -i PATH=/usr/bin:/bin LC_ALL=C HOME=/nonexistent PYTHONDONTWRITEBYTECODE=1 \
  /opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12 -S \
  <repo>/research/<packet>/run_aggregate.py --admitted-source-commit <exact-published-Git-HEAD>
```

The exact work root is frozen in `RUN_PINS.json`; it must not exist. Input identity checks precede work creation; any preflight failure is a refusal, not a completed attempt. After work starts, failure/partial records and resource receipts are retained. No retries or subsequent real-room run is authorized by a successful control result. The existing managed sandbox is used unchanged; no namespace or host-security setup is requested. Stable Node permission mode is required without child/worker/addon/WASI grants, but it is not an independent hard network boundary. No network operation is requested by this trusted-official-source protocol. Permission/API compatibility remains untested, and no fallback may widen permissions. Initial errors can occur before WASM load and are not controller outcomes. See `RUNTIME_CONTRACT.md`.

## Stage B — separately frozen real-room probes, not admitted yet

`REAL_ROOM_SELECTION.json` fixes row selection from already retained logs **before any Rapier outcomes**: for each path, initial, first/middle/last translation, first turn and terminal; additionally Coffee's already known refused event 10. This selects 49 source-schedule rows (Coffee 7, Conference 7×6). At most two additional Coffee ground-follow rows are specified below. At two flag arms × two envelopes × two input arms, the ceiling is 408 nested diagnostic rows, not a route replay or room success score. Exact identities and byte hashes of materialized buffers/rows must be separately frozen and reviewed before any Stage B score.

Inputs and frames:
- Coffee full unchanged source mesh: `coffee-recovered-source/textured.obj`, SHA-256 `f10de085426143ad095fefc713b4966d22fdf08beda9ff9ead759019a0a8306a`; 51,965 source vertices / 87,370 triangles. Use the existing rigid normalization and source pose mapping, never a new scale, registration or fitted floor.
- Conference full unchanged source mesh: `conference-source-recovery/extracted-001/textured.obj`, SHA-256 `79cfd017b9c88dca840c8ec969208a93593b03f600303d70cc6777b7c55438a1`; 18,398 source vertices / 29,366 triangles. Reuse the executed registered Float32 vertex bytes (SHA-256 `50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb`) and face values (Int32 bytes SHA-256 `2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324`); VTK promoted those Float32 coordinates to Double. Explicit Uint32 reinterpretation must preserve nonnegative face values and ordinal/winding.
- Metres, +Y up, +X heading zero and positive yaw toward +Z. Record each original supplied foot/yaw/desired displacement and API Float32 conversion; quantify maximum coordinate conversion and additional exact-XYZ aliases before scoring. No geometry coordinate changes, face culling, label-based filtering, mesh cropping, epsilon welding or selected-face deletion.

Each materialized row must carry source log hash, path/event identity, original pose, unchanged desired displacement, independent VTK nominal-body/margin/raw/witness/ground/turn evidence or explicit missing/unknown state. Initial/terminal rows request zero translation and expose any depenetration only as a proposal. Translation rows use their exact existing `b-a`; if an existing row exceeds the .025 m comparator cap, report it unsupported/inadmissible rather than shorten it. Rotation rows stay unsupported, retaining the original start/end yaw and independent VTK turn enclosure evidence. Do not call a translation sweep a turn test.

Run four frozen arm/profile combinations at **identical real-room poses**. Keep exact-XYZ input separate from a labelled horizontal-projection input (same pose, input y set to zero, original delta retained); never replace upward intent silently. Do not propagate corrections or success between rows. No autostep, snap, body/margin change, 15-degree threshold relaxation or cane credit.

Additional ground-follow cases: recover the last accepted Coffee C state immediately before rejected event 10 from the pinned receipt/log, with exact source-frame mapping and heading. A zero-input row observes proposed depenetration; a separate original rejected-turn row is unsupported without a controller call. If saved state, heading or rigid mapping cannot be bound, mark unavailable; do not substitute the rejected proposed end pose, extrapolate a floor or apply corrections.

The full KCC cuboid includes the lower .002 m slice excluded by existing VTK. Both remain unchanged and this difference must appear in every comparison. The .002 m KCC offset is extra numerical clearance, not a lower exclusion or replacement horizontal margin. Compare results as source-bound diagnostic disagreement, **not identical-query parity**.

## Reporting and stopping

Retain all selected rows, including errors, initial overlaps, unknown/support/coverage cases and no-difference outcomes. Report desired/proposed XYZ, normals/witnesses, grounded as a non-authoritative diagnostic, original and imported mesh identity/mapping, Float32 differences, unsupported turns, independent hazard evidence, runtime/resources and partial-record status. No triangle-ID matching invented from KCC events. Do not turn clear KCC translation into full-support, no-step, arrival, safe-room or physical-guidance claims. Internal-edge manifold changes do not prove cast correction or hazard preservation. Existing low-obstacle/stair and swept-turn evidence is never suppressed by the controller.

Stage B remains blocked on exact mesh/probe materialization hashes, independently reviewed source-frame mapping (especially Coffee C), dedicated guarded execution admission and explicit disposition of missing independent hazard/support evidence. The current aggregate launcher intentionally cannot execute Stage B.
