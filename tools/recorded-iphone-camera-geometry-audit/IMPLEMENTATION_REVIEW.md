# Independent implementation review — camera-relative audit

2026-10-26. Read-only review against protocol SHA-256 `c464922f1fa4799d83f9eef5da6fb0158a62df134777ff7218181aa6f196cfaf`. This reviewer has not compiled, run the harness, processed capture arrays, generated points or rendered diagnostics.

## Reviewed implementation properties

- Swift decodes original little-endian depth bits as Float and keeps original UInt8 confidence. It calls the existing shared admission, resolution-scaling and camera-point functions. Per-frame Float intrinsic coefficients are supplied; no global-K substitution, portrait conversion, normalized ray or replacement forward projector is present.
- Manifest fields contain image/depth dimensions, four intrinsics, two original data paths, frame ID and an unused-for-geometry timestamp. No pose, initPose, world/gravity/tracking/body/mount/floor/map/goal input is forwarded. No Observation, detector or navigator is constructed.
- Five hand-computed golden probes are consistent with the reviewed protocol, including anisotropic focal lengths and unequal x/y resolution ratios. Runtime checks cover finite calibration, fixed dimensions, exact depth promotion, pixel bounds, finite XYZ, negative Z, inverse residuals and reconciliation with the original eight scalar-admission counts. These checks remain numerical consistency, not external geometric accuracy.
- Plotting uses original arrays and the actual returned camera points only. Original Float32 data is explicitly promoted to Float64 for independent admission/range comparisons. Unsampled/rejected/admitted pixels are separated, invalid depth is masked rather than filled, display clipping is labeled/countable, and each point cloud stays separate. Common display bounds do not register or merge frames.
- The driver retains partial/failure artifacts and refuses existing run directories. It checks actual loaded paths for the two application libraries and records source/input hashes before and after. Derived files and module-cache growth share an aggregate output allowance.

## Findings and corrections during review

1. **Resolved:** initial driver only recorded current hashes for the source-data receipt and several modules/binaries. It now anchors the frozen stage-02 pin receipt, original selection receipt, Core object/module and recorded module; the field audit, policy module and support binary are checked against the anchored prior receipt. Selected RGB hashes/sizes are checked against original extraction entries before the unchanged copy claim.
2. **Resolved:** plotting now explicitly promotes Float32 depth to Float64 for threshold comparisons. This removes reliance on NumPy scalar-promotion behavior. No actual mismatch was demonstrated for the existing 0.15–5.0 interval or these frames; this was contract hardening, not a recorded-data defect.
3. **Outstanding at this snapshot:** `RUSAGE_CHILDREN` counts reaped children, not still-running compiler/plot processes. The aggregate CPU watchdog must include active descendants; per-process `RLIMIT_CPU` is not an aggregate process-tree budget. The protocol promises a total 60 CPU-second allowance. RSS is already explicitly labeled sampled, not a hard memory reservation.
4. **Requested hardening:** scrub inherited `LD_PRELOAD`/`LD_AUDIT` and arbitrary loader search paths from authoritative subprocesses. Checking two `ldd` paths alone does not rule out preload interposition. Keep required installed Swift runtime paths explicit.
5. **Small attribution improvement:** link directly to the pinned dataset and CC BY 4.0 license in the original-image attribution file.

## Snapshot source hashes

- `CameraGeometryAudit.swift`: `731f81982e94e8ff9a1fe984465bf97cc86ffd71846fed064af30d1908946db1`.
- `run_geometry_audit.py`: `0b8e1c44d118c070fab2e07fd6df47ebd9e58a759330a9efbacea5fed883672c`.
- `plot_camera_diagnostics.py`: `65b9ab7c636dcfc8fe2f2f1e098f69613577e59225051829d6c5b052859c36fa`.

No geometry, original-confidence, camera-axis or physical-authority blocker remains in the inspected Swift/plot sources. Final approval of the runner is pending the resource-accounting correction and final source hash review. This is not a result or safety certificate.

## Final source re-review — 2026-10-26 03:29 UTC

The final driver now samples live process-tree CPU including each currently visible process's own and already-waited-descendant ticks. The Linux stat field indexing is correct by inspection. It retains process-group termination and per-process CPU limits, and explicitly identifies sampling/tick/process-exit limitations rather than claiming a hard cgroup quota. Live child work is no longer systematically invisible until reaping.

The child environment removes `LD_PRELOAD` and `LD_AUDIT`; `LD_LIBRARY_PATH` contains only the two intended application-library directories, without inherited paths. The original-image attribution includes the pinned dataset and CC BY 4.0 URLs. I also checked that the five newly anchored local receipt/Core/module hashes match their declared constants. No compile, resource workload, numeric probe or recorded-frame processing was executed by this reviewer.

**All review blockers are resolved for this explicitly scoped, one-pass camera-relative diagnostic.** The code may proceed under the maintainer's existing conditional authorization after confirming these exact final hashes; any subsequent source change requires re-review. This approval does not predict compile/runtime success or confer physical authority. Preserve failed runs and the existing numeric thresholds rather than tuning to a desired result.

Final reviewed source hashes:

- `CameraGeometryAudit.swift`: **`731f81982e94e8ff9a1fe984465bf97cc86ffd71846fed064af30d1908946db1`**.
- `run_geometry_audit.py`: **`17f4c0ede8395c5570fb2b439439928ef4bd91a464e16c40d1b4f325fab7c897`**.
- `plot_camera_diagnostics.py`: **`65b9ab7c636dcfc8fe2f2f1e098f69613577e59225051829d6c5b052859c36fa`**.
- Governing protocol: **`c464922f1fa4799d83f9eef5da6fb0158a62df134777ff7218181aa6f196cfaf`** (unchanged).

## Result-claim inspection — 2026-10-26 03:32 UTC

The owner executed the approved audit. I inspected its existing receipt, result JSON, distribution report, loader/plot logs and frame-0 scatter; I did not rerun geometry or process original capture arrays. The three reviewed implementation hashes remain unchanged.

- Receipt: `run/GEOMETRY_RECEIPT.json`, SHA-256 **`54423440e787d89b0402cc657a118af74a9934fa300536fe17e2f80a08507bed`**.
- Geometry result: `713874c29475a19e1924d248d0952adc0db6f9dd9cab90d023576c5bd5067ea6`.
- Distribution report: `a885a786469c303faa5a319087ef417505aee05ecdfe3a29f1fdd05def4f67d2`.

The recorded outcome is consistent with the preregistered numerical claims: exactly eight frames, 98,304 attempted stride pixels, 31,648 admissions and projected points, five zero-error golden probes, maximum pixel round-trip residual `2.842170943040401e-14` pixels and depth residual zero. Every frame's projected count equals its prior scalar-admission count. The loader log resolves the intended application libraries. The driver reports its before/after source/input hash checks passed; this review independently rechecked the three implementation source hashes, not every capture byte.

The receipt records 12.11 sampled process-tree CPU seconds, 11.8345 wall seconds, 287,064,064 bytes sampled peak tree RSS and 6,010,181 newly written bytes **before the receipt itself**. These are execution observations, not hard-quota guarantees or phone/device timing measurements. A later presentation-only addendum is not included in those numbers.

The original frame-0 scatter has visibly clipped bottom X/Y axis labels. Its points and numerical evidence are present, but it is not a finished readable presentation. The plot log also preserves Fontconfig cache warnings. Preserve the original outputs, warnings and receipt; a separately identified presentation-only label repair from the same hashed CSV does not justify rerunning or changing geometry evidence.

No result wording inspected claims physical accuracy, obstacle recall, body clearance or navigation success. The near-zero round trip is internal arithmetic consistency, not independently measured geometry accuracy. Eight correlated tabletop frames are not eight walking trials or a zero-collision benchmark.
