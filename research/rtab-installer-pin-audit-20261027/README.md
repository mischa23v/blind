# RTAB native failure: wrong provenance pin, not a failed compile

Read-only investigation, 2026-10-27. Inactive patch only. **No installer, native engine, native build, new dependencies, or workflow activation was executed.**

## Exact evidence

[Run 40256696185](https://github.com/mischa23v/blind/actions/runs/40256696185), job `121359966110`, stopped after 9.35 seconds with `pinned install recipe drift`. Upstream checkout and HEAD verification succeeded. The guard at `tools/ci/native-rtab-grid.py:429` precedes overlay preparation and dependency archive acquisition. Thus this run did not test native compilation or runtime feasibility.

The original runner at workflow commit `e677c185c208728b02b103247913ef03a1467c1b` has SHA-256 `90d27828cb9d8d364f75217e6ce68f99bc60ce2501237db03d14699f5c7d2183`, identical to the local source. It expects installer SHA `7b6bd18c9240183a4fc873fedefee9c0a8d89c8da9f7e91218c1d2d2fd217aa1`.

The [canonical installer at the same intended immutable revision/path](https://github.com/introlab/rtabmap/blob/a4e7f13522722878dea3f07e8fd082291e72eb49/app/ios/RTABMapApp/install_deps.sh) is 14,021 LF-only bytes: Git blob `15f670213086945451b67063fc1c2819dc877653`, SHA-256 `c1c71cc728c3f49169021b2db9b8fc3af55de27b3d12f598ec3cf28bf52fd532`. Both digests were recomputed from decoded GitHub file bytes. The existing lock and build plan explicitly identify that revision. No upstream revision, path, or dependency selection is being changed. The old hash's origin is unknown; the evidence establishes a wrong expected hash, not how it arose.

Artifact `12622253372`, `native-rtab-grid-metadata-40256696185`, is 20,227 bytes, SHA-256 `e6dfa16f39e5a0f7f7486abc33e761b3dca860ba4d8795202dd3642f7300431e`. ZIP integrity and size were checked. `failed-run-summary.json` preserves its result, not a new run. First and second pages of the 133 repository workflow records showed this single RTAB-named run at inspection time.

## Security/content review and narrowly proposed correction

The full upstream installer was read, not run. Its dependency branches contain unchecked tarball downloads, tag-based/full clones, external gist patches, an unpinned default-branch libLAS clone, and broad source builds. **Whole-installer execution remains unsafe/unvalidated for this bounded task.** The existing runner instead verifies a pinned prebuilt archive, checks sentinels/linked libraries/platforms, performs its reviewed g2o relocation, and independently reproduces only the final RTAB resource/core CMake section with capped jobs. It never executes the installer shell script. The upstream final section's selected flags match the runner's existing selections; this is a source review, not a tested build or transitive license clearance.

`proposed-pin-only.patch` changes exactly the expected hash in the runner and the matching plan. It is **not applied**. The integrity guard remains intact. No executable upstream source, trigger, timeout, archive pin, or dependency is changed. Applying it would correct provenance only, not establish a backend build pass.

Trigger review: RTAB's push trigger only matches `.github/workflows/native-rtab-grid.yml` on master. However, `tools/ci/**` matches the existing recovery-branch `native-apple.yml` trigger. Therefore this research packet holds the patch inactive; parent must review when/how to apply it without an unnecessary native run. No workflow file was edited.

## Local backend availability and the actual next blocker

In this current Linux workspace, both Python 3.12 and `/usr/bin/python3` 3.13 report no `cv2`, `open3d`, `pycolmap`, or `rtabmap` module. No `rtabmap`, `rtabmap-rgbd_dataset`, or `colmap` executable was found. Bounded workspace/shared/tmp checks found no complete installed RTAB checkout/backend. The repository's upstream directory is a source-reference packet, not a built engine.

`/usr/lib/x86_64-linux-gnu/libopencv_rgbd.so.4.10.0` does contain `cv::rgbd::RgbdOdometry`/`RgbdICPOdometry` symbols. But OpenCV C++ headers and pkg-config metadata are absent, and neither Python has bindings. A shared library with C++ ABI symbols is not an already callable, validated Python backend; fabricating ABI bindings is not a suitable shortcut. No engine was run. These are environment-specific observations, not a claim about other sessions/machines.

Published visual-localization packets explicitly exclude raw RGB/depth/poses and compiled backends; their archived OpenCV 4.14 results do not establish that backend is installed here. Original native integration consumes ARKit-supplied poses: compiling that path would not itself test independent causal RGB-D estimation.

Consequently no already usable local upstream causal RGB-D estimator was identified under the no-download/no-install/no-build constraint. Two separate scopes must not be conflated:

1. **Native compile feasibility:** after parent reviews/applies the hash correction, a separately authorized single bounded retry of the existing device-compile experiment could test the unchanged upstream core/app. Its official iOS dependency ZIP is 234,342,396 bytes; existing caps are 4 GiB expanded archive, 8 GiB work, 2 jobs, 40-minute script/45-minute job. This is not a Linux offline estimator or navigation trial. No retry has been requested or triggered here.
2. **Causal offline RGB-D experiment:** first authorize/provision one pinned upstream backend and its actual dependencies (or locate a supported pre-existing environment), then freeze a short ordered RGB-D sequence with intrinsics, depth units/alignment and validity masks. Use no exported pose as estimator input; keep reference poses in an evaluator-only process. Declare timestamps unavailable if absent, and do not turn frame indices into claimed latency/velocity. Record failures and output camera poses; camera heading is not body heading. No new install size/runtime can honestly be promised before selecting the package/environment. This is a distinct scoped proposal, not authorization to reuse a hosted build workflow for new work.

## Reproduce the lightweight provenance regression

Obtain only the canonical installer file above through an approved read route, preserve exact bytes, and run:

```
python3 research/rtab-installer-pin-audit-20261027/check.py --upstream-script /path/to/install_deps.sh
```

The script reads the file; it does not execute/import it or the native runner. `CHECK_RESULT.json`: **14 passed, 0 failed**, including blob/SHA identity, wrong-pin rejection, byte mutation rejection, exact preimages, AST equivalence except pin, unchanged workflow and guard-before-download order. These are source/provenance checks, not backend or movement tests.
