# Geometry audit checkpoint: localized errors, comparator feasibility and native admission

**2026-10-28, 17:52 UTC.** This packet adds bounded technical evidence to the earlier [full audit](../geometry-independent-audit-20261028/FULL_REPORT.md) and [fresh Open3D comparison](../geometry-independent-audit-20261028/UPDATE_1732.md). It changes no reconstruction, score, geometry rule, path or workflow.

## 1. Open3D errors are localized, not uniformly bad floor geometry

The [post-hoc tail diagnostic](../open3d-same-data-benchmark-20261028/error-tail-diagnostic/README.md) studies three already evaluated views. The independent reviewer reproduced **1,155 checks exactly**. [Review receipt](../open3d-same-data-benchmark-20261028/independent-review/TAIL_REVIEW.json).

- In frame 197's explicitly selected central-floor rectangle, 5,328 paired rays have median absolute discrepancy **4.914 mm** and P95 **16.934 mm**. This narrow region can agree well while other parts of the image disagree badly. It does not establish full floor support or doorway clearance.
- In frame 228's largest 4,166-ray component, the reconstructed first hit is a median **0.398 m** away, versus **3.939 m** in the reference and **3.990 m** in recorded phone depth. This is a substantial near-surface discrepancy, not a slight floor ripple.
- Frame 228 also has a 1,689-ray component overlapping far chair silhouettes, with median reconstructed-minus-reference depth **+1.086 m**. Foreground structure differs substantially in this view.
- In the low-tail control, the coat-stand-region discrepancy already appears between recorded phone depth and FARO; the fused mesh agrees more closely with the phone. Not every residual can be blamed on fusion alone.

Of frame 228's largest component, **2,038 recorded depths are at or beyond the 4 m integration cutoff**. The withheld view cannot establish which corresponding training observations were eligible. Training-observation tracing is still a separate unfinished diagnostic and is not included here.

These are post-hoc regions and visual descriptions, not ground-truth hazard labels. The main score and all its denominators remain unchanged. No geometry is deleted, floor region promoted to clearance or route accepted. Exact public RGB hashes are included for provenance, but RGB files and RGB-bearing figures are excluded from this publication packet. The recount needs the existing arrays, raw inputs and reviewed local images; this text packet alone does not include them.

MuSHRoom data and derived numerical evidence are attributed to Xuqian Ren et al., under CC BY 4.0. [Data and software attribution](../open3d-same-data-benchmark-20261028/fresh-run/README.md#attribution-and-licenses). Original physical reference provenance/registration limits remain unchanged.

## 2. InfiniTAM has a feasible CPU path, but no executed result

The [pinned-source feasibility review](../infinitam-same-data-feasibility-20261028/README.md) identifies released CPU TSDF fusion, file poses and CPU mesh extraction. It is a possible fixed-pose comparator, not a tested improvement or stock drop-in command.

Actual integration obstacles include varying per-frame intrinsics, a GUI dependency in stock CMake configuration, and a default mesh allocation of roughly **4.5 GiB** before scene overhead. A bounded runner must use released APIs with explicit calibration/pose checks and reject allocation saturation. No InfiniTAM build, install, reconstruction or score is claimed.

The pinned upstream license restricts noncommercial use and includes commercial-product research in its definition. License applicability and any obligations need resolving before execution/adoption. This source review neither accepts terms nor contacts the licensor, and it is not legal clearance. No upstream implementation is vendored by this packet. [Source manifest](../infinitam-same-data-feasibility-20261028/SOURCE_MANIFEST.json).

## 3. The Apple candidate's CI skipped execution

The source-checked support/parity candidate was published at **12a0b64bc403db3f48a997aea868b9ad670e73fb**. Its push run **40738486723** skipped both native jobs, allocated no runner, and produced no artifacts because the existing job condition required a public repository while the repository was private. **Zero new Apple builds or native tests executed.** This is admission failure, not evidence that the new geometry passed or failed. [Dated skip observation](../native-path-recovery-20261028/run40738486723/README.md), [machine-readable receipt](../native-path-recovery-20261028/run40738486723/OBSERVED_SKIP.json).

At the preserved 17:48 checkpoint, a decision on private-repository CI admission and billing implications was pending. This packet changes neither workflow nor visibility and does not infer later authorization. Full native mesh parity, platform floor tessellation behavior, original route outcomes and body/support collision checks remain open.

## Publication scope

Only completed reports, scripts, manifests and hash receipts are included. No RGB/figures, private captures, runtime/build files, unfinished training traces, new geometry or modified baseline scores. Existing dated records remain intact. RTAB-Map work continues separately within its approved scope; no RTAB ranking or navigation-readiness conclusion follows from this packet.
