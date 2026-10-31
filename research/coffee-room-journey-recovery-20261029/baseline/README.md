# Prepared independent original-Coffee-mesh replay

**Attempt001 compiled and failed before any route query; fresh attempt002 is prepared, not executed.** This is the original Polycam OBJ baseline, not older floor-fixed occupancy and not unavailable original-pose Open3D TSDF. Source recorded geometry is real; the nine query points are authored topology probes, not measured seats/doors/body locations.

## Source and frame contract

`prepare.py` pins repository c79fbd33171f78608f9eb2a1484fbc9266e3a695 and extracts exact hash-verified sources from the published Coffee ZIPs. It refuses an existing output directory, does not extract/execute the bundled native binary, restores only needed upstream source/header paths, caps upstream source at5MiB and checks **every historical BUILD_RECEIPT source SHA256**. Preparation executed:58 files,737,928 upstream bytes, all historical build source hashes matched. `PREPARATION_CHECK.json` records the available Python3.12.14/NumPy2.3.5/x86_64 runtime; equality to historical NumPy/compiler runtime is not claimed. No installs are needed if that existing runtime is retained.

Original source mesh SHA256 f10de085426143ad095fefc713b4966d22fdf08beda9ff9ead759019a0a8306a; original poses46c8d1fc5188d38179e88eff98fd42f99956fb93b570bd9483e6e92764ae7010. Source provenance/license in parent SOURCE.md.

The preserved protocol is used **verbatim**: unchanged original OBJ XYZ, candidate Y-up, no rotation/translation/scale, no Koivu registration. Candidate floorY=−1.6301633051396203 is historical mesh-derived geometry, not calibrated physical floor. The original source readiness report explicitly states missing camera-mesh rigid registration and unverified axis/sign/scale. Actual pose metadata is `camera_model=OPENCV`, `orientation_override=none`; this is not a mesh alignment instruction or proof of transform-matrix camera basis. Camera translation bounds and mesh bounds differ; a numeric comparison cannot solve registration. No transform will be guessed from these arrays. Camera poses are not consumed by the source-only route run. A future physical/semantic journey must independently establish scale, gravity/body relationship and camera-mesh alignment from source observations. The restored assets contain no seat/door semantic groups or texture pixels.

## Reproduction commands (source preparation only)

Set `REPO`, `RECOVERY`, `OUTPUT` to caller-local paths. `OUTPUT` must not already exist; ZIPs are the verified published artifacts. Run from the repository root:

```sh
python research/coffee-room-journey-recovery-20261029/baseline/prepare.py \
  --repo "$REPO" --out "$OUTPUT" \
  --evidence "$RECOVERY/coffee-evidence.zip" \
  --mesh "$RECOVERY/coffee-source-mesh.zip"
```

The historical expected FROZEN and RESULT remain under `expected/`; the unchanged original `run.py` will write only its new run's FROZEN/RESULT. Exact original72 requests are reconstructed by the unchanged source and checked against expected endpoints/config after execution. Original source hash remains pinned. Native binary is freshly rebuilt with historical compiler arguments/source hashes, not treated as byte-identical by assumption. Build output hash, Python/runtime metadata, stdout/stderr and new full-result comparison are retained separately.

## Proposed bounded admission — root review required

After the currently active native work ends, admit **one serial build, then one serial72-query replay** only. No actor movement, source reconstruction, dependency install, raw-data transfer or physical guidance. Proposed limits:120 CPU seconds per process/phase,180 seconds wall per phase,1GiB per-process address-space ceiling,16MiB per output file, original2MiB query-folder post-run limit, one OpenBLAS/OMP/MKL thread. These are **not hard aggregate process-tree RAM/disk/CPU containment**; compiler child resource usage and total disk remain a supervisor/admission concern. Actual one-CPU affinity/aggregate controls, if required, must be supplied by root's known runner, not asserted by this wrapper. Start with adequate disk reserve; no deletion to satisfy it.

**Superseded execution wrapper:** do not execute `run_admitted.py`. Its nested `start_new_session` subprocesses are incompatible with the reused process-group aggregate guard. Root's guard owner is preparing a direct serial compile → unchanged historical run → full-result comparison adapter from the now-passed heightfield guard. That separate source freeze and review supersedes the earlier per-process proposal; preparation/source inputs remain unchanged. No native command is admitted until that reviewed guard is frozen.

## Expected scope, not a claimed pass

Historical:72 directed queries;30 native-complete,20 accepted after endpoint association among five endpoints, ten complete-but-association-rejected,42 other incomplete/invalid. Radius0.225m, native height1.75m, cell/height0.025m, climb0.025m,slope15°,250,000cells/4,096nodes; association≤0.1m. No exclusions. Full-result equality is stronger than matching counts but still only a source-geometry regression. Query0 is not a seat. Queries are not movement, observed free space, support assurance or doorway exit coverage. A successful repeat enables a separately frozen full-body actor/actual-endpoint-return development case; it does not complete the user's journey.

## Latest priority

Inside-room pathfinding is the immediate goal; images are only for diagnosing a specific routing issue. Unknown door/far-side semantics do not block the frozen72 source-coordinate inside-room queries. After baseline replay, preserve accepted and rejected original endpoints and pursue full-body/turn/source-triangle collision diagnostics on unchanged paths. Do not postpone these queries for galleries or invent a seat/exit label.

## Recoverable attempt001 header-closure failure

Root's admitted first compile stopped because the historical build receipt did not enumerate `native025/blind_detour.h`; no query ran. Failed receipts/output remain unchanged in the first owned workspace. The compiler also retained upstream warnings; the missing header was the fatal error, not route geometry.

`prepare.py` now restores the exact published Coffee adapter header from the pinned c79 source (SHA256`c6270b968024d0703800160d45d4110f04f73ad3ecca50ceb0fd0de3b002dbb4`) and statically resolves every quoted include in all staged C++/header files. Fresh attempt002 contains60files/11,732,981bytes;45C++/headers,112resolved quoted includes. Standard angle/system headers remain the toolchain's responsibility; no preprocessing/compiler execution occurred during preparation. Existing algorithm, mesh, query, body and margin bytes are unchanged. Existing BUILD_COMMAND differs only by remapping paths to the new owned directory. `ATTEMPT002_SOURCE_FIX.json` records that comparison. The direct aggregate guard's separately reviewed002token/pins must be published before root admits one new serial build/query attempt; never reuse or erase the failed directory.
