# Direct OctoMap build review — 2026-10-29

**Conclusion:** no blocking source defect found for one bounded, direct compile of this exact packet, after root publication/admission and normal execution authorization. This is source review, not a build pass or permission to bypass a denied action. The historical and superseded nested build scripts must not be run.

Reviewed packet: `research/coffee-octomap-build-source-20261029/`.
Repository HEAD when reviewed: `3a0b3f1edf4167f781a043017b2169bda69f91ef`; the packet was untracked, so this HEAD is **not** a valid admission for it.

## Verified without compiling or loading native code

- Read applicable `AGENTS.md` and continuous-companion/contextual-capability requirements.
- All 69 `BUILD_RUN_PINS.json` input hashes and every `SOURCE_CLOSURE.json` entry match current bytes, including six compiler/interpreter executables.
- All 48 vendored files, totaling 380,478 bytes, match both recorded official Git blob identities and existing tracked source bytes at `research/koivu-octomap-v2/workspaces/blind-octomap-reuse-08/`. The release is OctoMap 1.10.0, revision `007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f`; the original BSD license is retained.
- Local OctoMap includes are present; quoted `assert.h` is supplied by the existing system headers. Twelve upstream translation units plus the original adapter are explicitly listed, with no source-discovery glob at execution.
- Original adapter, wrapper and all 16 control functions are byte-identical to the tracked originals. All packet Python files parse with `ast.parse`; no packet module was imported.
- The aggregate-guard reuse hash matches the existing baseline. The diff is the direct single-compile adaptation described in the README, not a nested launcher.
- `build-restored-01` did not exist. No build, native load, controls, Stage B, installation, download, Git staging, commit or push was performed. No tool denial occurred during this review.

## Exact SHA256 identities

| File | SHA256 |
|---|---|
| `BUILD_RUN_PINS.json` | `8e1ee2a243b407f041f39e7707e1119210b53b0fa564df255ada1159164c86da` |
| `SOURCE_CLOSURE.json` | `6004052e6622d0a51706a253d6787c8f7f1257f4ab35ed1b8a066b4944ae3c53` |
| `build_restored.py` | `b3424927ed423a931639d9a1b0e475456062e39f64d6885ae05be4539c36fdcf` |
| `finalize_build_receipt.py` | `1b7df4269bc7ce8749cbe23e6cb833946ddb8ceb57e61414a51371a6a0ae0061` |
| `run_original_controls.py` | `49b9b698bc01e1e5317726b69c9c5dfa810f9150695005232e8d43b079906d36` |
| `test_octomap_engine.py` | `d1e032ae6be16dbb99255118d1776b0df14ec5c5ffc3271bb47867ed4a434fd5` |
| `octomap_adapter.cpp` | `715b3e544dff913a82ec43f49c0255297af0c3a799397faceaa66ebe97f9dff7` |
| `prepare_stage_b_binding.py` | `e0c963fc3a47fb0646844ca1f77eb552c503a30d9dcc1255b6c8957f7aac6c07` |
| Baseline `run_aggregate.py` | `0e509781d68232fac5229bed6caa08965ed606fa60e98d545c9205c6fe39034c` |

## Compile admission and exact command

Root must first publish the exact manifest/source packet, verify the intended published commit, and set `REVIEWED_PUBLISHED_HEAD` to that explicit 40-character commit. Do not substitute an unreviewed current HEAD or retry an existing attempt directory.

```sh
SOURCE=/workspace/scratch/90f3f6703064/blind/research/coffee-octomap-build-source-20261029
PYTHON=/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12
: "${REVIEWED_PUBLISHED_HEAD:?Set the exact reviewed published source commit}"
"$PYTHON" -I -B "$SOURCE/build_restored.py" --admitted-source-commit "$REVIEWED_PUBLISHED_HEAD"
```

The runner checks admitted HEAD/committed manifest and all input hashes before creating its fresh fixed directory. It runs exactly one pinned `/usr/bin/x86_64-linux-gnu-g++-14` invocation, serially and on one CPU, with the manifest's explicit arguments. Compiler environment is reduced; temporary files remain in `GUARD_RUN`. It invokes no install, CMake, ROS, OpenMP, download or native library load.

The guard charges supervisor/child CPU and wall time, observes aggregate process-group RSS/output every 20 ms, retains per-child CPU/address-space/file-size backstops, kills and observes retirement of the compiler process group, inventories outputs with no-follow descriptor traversal, and rehashes inputs afterward. Declared budgets are 120 CPU seconds, 180 wall seconds, 1 GiB **observed aggregate RSS**, 1 GiB per-child address space, and 50 MiB owned output. Observation is not an atomic cgroup-wide RSS hard cap. No failure is a pass or authorization to rerun.

## Required result gates

1. Inspect the complete successful `GUARD_RUN/RESULT.json`, exact argv/manifest, all retirement flags, final inventory, unchanged input hashes and resource totals. Check the actual final output inventory against the recorded hashes; the finalizer rechecks the library and inputs but does **not** revalidate every retained log/inventory entry.
2. Supply the independently reviewed guard-receipt SHA256:

   ```sh
   "$PYTHON" -I -B "$SOURCE/finalize_build_receipt.py" --expected-guard-receipt-sha256 "$REVIEWED_GUARD_SHA256"
   ```

   This is source-only verification and a new small receipt, not a second compile. Review its output and bind the newly produced library digest; never assume the historical `3c0a…` library digest.
3. Only after those gates, run the original controls as a separate authorized native stage. Their script enforces 30 CPU seconds and 1 GiB address space but **not** the documented 60-second wall deadline. Use a parent wall limit and single-thread numeric-library environment; disabling bytecode prevents new source-tree cache files, and disabling core dumps prevents native crash dumps:

   ```sh
   ( ulimit -c 0
     env OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
       /usr/bin/timeout --signal=TERM --kill-after=2s 60s \
       "$PYTHON" -I -B "$SOURCE/run_original_controls.py" \
       --expected-build-receipt-sha256 "$REVIEWED_BUILD_RECEIPT_SHA256" \
       --expected-library-sha256 "$REVIEWED_LIBRARY_SHA256"
   )
   ```

   Require a zero process exit and a reviewed receipt with 16 tests run, no skips, failures or errors, and all expected hashes. A timeout, crash or absent receipt is not success. NumPy is discoverable in the pinned interpreter's existing site-packages; it was not imported or installed during review.
4. Stage B binding generation and any recorded-frame native execution remain separately gated on successful controls and independent review. No claim about table geometry, registration, route clearance, localization, phone behavior or physical safety follows from this build or these controls.

This is reproducible source/command provenance for the current toolchain, not a claim of a hermetic or bit-for-bit cross-host build: system headers, startup objects and runtime libraries are not fully inventoried by the manifest. The rebuilt digest must be recorded from the actual successful run.
