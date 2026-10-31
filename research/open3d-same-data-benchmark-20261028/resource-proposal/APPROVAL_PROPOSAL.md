# Bounded approval proposal: exact Koivu data restore + CPU Open3D replay

**Prepared 2026-10-28; no archive/wheel download, installation or native execution authorized or performed by this proposal.** Root owns user approval and publication. This is an explicit resource envelope, not a promise the experiment will complete below its limits.

## Recommended approval scope

Authorize one serial stage that restores the existing licensed public Koivu inputs, creates the exact isolated CPU Open3D 0.19.0 environment, and replays the existing author-configured 265-frame fusion once with the original 29-frame holdout unchanged. Restore the FARO mesh/registration for the subsequent same-data geometry comparison, but **do not include full FARO raycasting under the 2 GiB fusion envelope**.

- **Network:** at most **750,000,000 bytes (750 MB decimal)** across the entire stage, including metadata and retries. Known archives plus wheels total **723,560,005 bytes**; allow no unplanned dataset, model or package substitution. Abort if total transfer would exceed the cap.
- **New owned disk:** at most **3 GiB (3,221,225,472 bytes)**, including retained original archives, wheels, selected inputs, isolated installed target, installer temporary files, outputs and logs. Preserve at least **1 GiB free disk**. Never delete historical evidence or other sessions' files to make room.
- **CPU:** one worker at a time, affinity restricted to one allowed logical CPU; OMP/BLAS/MKL threads 1; **900 process-tree CPU seconds / 1,800 wall seconds total**. Within that total, restore/install/preflight has at most 300 CPU / 900 wall seconds, and fusion at most 600 CPU / 900 wall seconds. Network waits count toward wall time.
- **Memory:** restore/install abort threshold **1 GiB sampled process-tree RSS**; fusion abort threshold **2 GiB sampled process-tree RSS**. Preserve failures and stop rather than silently increasing limits, dropping frames or changing geometry parameters.
- **No Docker, CUDA, GPU, Torch, neural weights, source builds, global installation, RTAB-Map backend installation, route experiments or private uploads.** No Redwood/sample acquisition; tiny existing analytical camera-convention checks are fixtures, not dataset substitutes.

### Important memory-enforcement qualification

The current environment exposes `/proc/self/cgroup` as `0::/`, but `/sys/fs/cgroup/memory.max`, `memory.current`, `cpu.max` and the v1 memory-limit path do **not exist**. A usable hard cgroup limit is therefore **not established**. Do not tell the user that a 2 GiB cgroup is available or that sampled RSS is hard kernel containment. A watcher can abort at its threshold but may miss a brief peak.

Before any native run, review whether a conservative worker `RLIMIT_AS` cap can be added without changing the mapping algorithm. A 2 GiB address-space limit is stricter than a 2 GiB RSS threshold and may fail during otherwise modest-memory native-library mapping; that would be a retained resource/incompatibility outcome, not permission to enlarge the cap. Do not silently treat an address-space cap as equivalent to a cgroup or a whole-process-tree RAM cap. If a strict aggregate hard RAM guarantee is required, the present environment must first provide a supported enforceable boundary; otherwise keep execution pending.

Only start each compute phase if the contemporaneous host `MemAvailable` is at least 4 GiB and there is no competing local heavy job. This is a conservative admission check, not ownership of host memory or a substitute for a hard memory limit.

## Exact transfers

| Asset | Bytes | SHA-256 / source |
|---|---:|---|
| `koivu_iphone.tar.gz` | 146,575,749 | `68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518` |
| `koivu_mesh_pd.tar.gz` | 455,583,916 | `e16605f237f0850fd069fb9aca39d300eb1aa3a3b1f5f3f660cb64230a91dd26` |
| 28 pinned official PyPI wheels, including `open3d-cpu==0.19.0` | 121,400,340 | Every URL, filename, size, SHA-256 and expanded inventory is in restored `ACQUISITION_PROPOSAL.json`; Open3D wheel SHA-256 `dc935427a28cdba4ef511e9ee366b6001962b583e64231887c9b2e4cff787ee2` |
| **Known total** | **723,560,005** | Approximately 690.04 MiB; below 750 MB cap |

Both data archives are existing [public release assets](https://github.com/mischa23v/blind/releases/tag/navigation-test-data-20261026). MuSHRoom data is CC BY 4.0; engine MIT; reused DN-Splatter author algorithm Apache-2.0. Source/algorithm/dependency licenses remain separate. Allow only the existing release/official dataset and the exact official PyPI URLs. Network-tool permission remains separate from resource authorization; do not bypass a rejected transfer route.

## Archive expansion and selective extraction

The archive streams are inspected with the existing guarded helpers, no arbitrary `extractall`, no links/traversal, no duplicate or unexpected members. Compare archive hashes before extracting and retain originals afterward. Decompressed scanned bytes are **not** all written to disk.

| Archive | Previously observed decompressed stream | Proposed stream cap | Selected output |
|---|---:|---:|---|
| Phone | 191,404,544 bytes | 256 MiB | 265 training RGB files: 47,902,609 bytes; all 294 depth files: 67,180,136 bytes; original pose/calibration JSONs and 348-byte split. Overall selected phone output cap **128 MiB**, since exact original JSON byte counts are not all recovered in this resource packet. |
| FARO | 926,326,784 bytes | 1 GiB | Exactly `gt_mesh.ply` 660,550,085 bytes plus `icp_iphone.json` 449 bytes = **660,550,534 bytes**. Do not extract the 265,768,152-byte `gt_pd.ply` or unrelated Kinect registration. |

FARO archive declared file payload is **926,319,134 bytes** across four files; headers/padding explain the larger decompressed stream. Preserved historical inventory is `FARO_ARCHIVE_INVENTORY.json`. Original pose SHA-256 remains `c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3`; all depth/RGB identities and train/holdout ordering remain the shared `DATA_CONTRACT.json`, not a freshly selected subset.

## Conservative disk ledger

| Item | Maximum bytes charged |
|---|---:|
| Both retained source archives | 602,159,665 |
| Retained 28 wheels | 121,400,340 |
| Selected phone files (cap) | 134,217,728 |
| Selected FARO mesh + registration | 660,550,534 |
| Declared installed wheel payload | 368,764,121 |
| Additional installer temporary allowance | 402,653,184 (384 MiB) |
| Reconstruction + diagnostic output allowance | 201,326,592 (192 MiB) |
| Other source/metadata/log allowance | 16,777,216 (16 MiB) |
| **Conservative payload total** | **2,507,849,380 (2.336 GiB)** |

The **3 GiB allocated-disk cap** also covers filesystem block/metadata overhead beyond these declared byte counts. Installation was historically about 379,256,832 allocated bytes versus 368,764,121 declared payload bytes. No full uncompressed tar copy is created. A bounded installed target uses `pip --no-index --no-deps --no-compile --target` with only locally verified wheels; all temp/cache paths belong to this new stage. The old 900 MiB historical whole-stage cap cannot be reused for this combined restore—it was built around already-present data. Any new watcher must record this explicit new scope and cap.

## Current host evidence and feasibility

At proposal preparation:

- Free disk: **31,684,362,240 bytes**; host `MemAvailable`: **9,544,040,448 bytes**; swap: 0. These snapshots must be refreshed before launch and are not guarantees.
- Nine logical CPUs are in the affinity allowance; this stage still uses only one serial worker.
- Python 3.12.14 / x86_64; NumPy 2.3.5, Pillow 12.3.0, VTK 9.3.1 and SciPy 1.17.0 available. Open3D, OpenCV and Torch absent.
- **All 46 historically reused installed-distribution versions match exactly** (`HOST_DEPENDENCY_COMPARISON.json`). None of the 28 historical missing-wheel distributions is currently present. This makes the exact historical wheel closure a concrete candidate rather than an unbounded dependency resolution. Validate wheel metadata, platform tags and imports before proceeding; matching version strings alone do not prove binary identity.
- The three recorded NumPy module hashes were also compared with the historical fusion receipt in `HOST_NUMPY_HASH_COMPARISON.json`; preserve that result rather than assuming match.
- Historical isolated install/import completed in **95.08 wall / 10.33 CPU seconds**, sampled peak RSS **238,477,312 bytes**. Historical fusion completed all 265 frames in **67.422 wall / 105.25 process-tree CPU seconds** under a 2 GiB watcher. Its exact peak RSS was lost to the documented wrapper-report parse failure, so **completion below a hard 2 GiB limit is not proven**. Pure-CPU replay under that abort threshold is reasonable to attempt after approval, not guaranteed to pass.

## Meaningful verification without writing a new mapper

Reuse the existing native Open3D 0.19.0 `ScalableTSDFVolume` and the pinned DN-Splatter algorithm, all 265 training RGB/depth inputs, original per-frame K/poses and 29-frame exclusion list. Preserve 4 cm voxel / 20 cm SDF truncation / 4 m depth cutoff / uint16 millimetres, no resized rasters, no fit against FARO, no geometry cleanup and no new mapping algorithm.

Allowed preparation after approval is restricted to guarded materialization, reviewed path remapping, module/source/input hashing, a newly generated launch manifest and resource/reporting-only fixes. Repair the known ANSI-warning/JSON-report collision without changing geometry; save worker stdout separately and independently serialize timing/RSS even if parsing fails. Do not claim original launch-manifest hash still matches normalized public paths.

Acceptance of this stage: source/input pins valid before and after; exact 265 frames processed, held-out IDs untouched; existing analytic pose checks pass; finite nonempty native mesh/cloud retained; every frame/rejection and output hash recorded; timings, aborts and memory measurement method preserved. Compare output counts/hashes with historical evidence as a regression diagnostic, not as an independent accuracy test. Any data, import, limit, shape or hash failure stops the stage and remains visible.

## FARO scoring option: choose explicitly, do not hide in the 2 GiB stage

The historical eight-view full-FARO VTK evaluator reached **2,144,088,064 bytes sampled peak tree RSS**—only **3,395,584 bytes below 2 GiB**. Extending to 29 held-out views with output buffers under the same nominal 2 GiB cap is therefore not a credible guaranteed completion plan.

If the user wants a **single broader approval** that includes the new 29-view common-reference geometry score, propose **a 3 GiB sampled-RSS evaluator abort threshold** (fusion remains 2 GiB), **1,200 process-tree CPU seconds / 2,700 wall seconds total**, with the same **750 MB transfer / 3 GiB new disk / 1 GiB free reserve** limits. Run fusion and scoring sequentially so their memory does not overlap. Retain the cgroup/strict-hard-limit qualification above. No new downloads are needed for this add-on once the two archives and runtime have been restored.

That optional evaluator must reuse the reviewed VTK first-hit code with the same 29 excluded views, 1,335,885 fixed rays, integer pixel centres, fixed author registration and no missing-ray removal. It yields registered-reference-relative geometry discrepancies, not physical obstacle labels or a navigation-safety pass. Confirm buffer/output bounds before starting; if its cap is exceeded, stop and report incomplete rather than simplify FARO or shrink the holdout. RTAB-Map backend acquisition/build remains a separately sized later stage.

## Suggested brief approval request

“May I run the next CPU-only stage? It will download at most 750 MB of the existing public test data and pinned Open3D packages, use at most 3 GiB of new disk, and run one job at a time. Fusion stops if sampled memory exceeds 2 GiB; including the independent-reference comparison needs a 3 GiB stop threshold. The broader stage has a 45-minute wall limit. No Docker, GPU, models, private uploads or RTAB installation. This environment does not expose a hard cgroup memory cap, so those memory values are monitored stop thresholds rather than guaranteed kernel-enforced limits.”
