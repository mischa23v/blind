# RTAB-Map hosted device-compile feasibility (read-only, not activated)

Observed 2026-10-26. Scope: exact upstream `a4e7f13522722878dea3f07e8fd082291e72eb49`, app overlay under separate review, and an ephemeral unsigned source-compile experiment. No dependency archive was downloaded or extracted here; no OS packages, libraries, models, credentials, signing identity, or workflow activation were installed/created.

## Findings

- The [pinned upstream iOS workflow](https://github.com/introlab/rtabmap/blob/a4e7f13522722878dea3f07e8fd082291e72eb49/.github/workflows/ios.yml) already supplies an official prebuilt dependency route. It uses Xcode **26.5**, not the current app runner's 27, then builds the actual pinned RTAB-Map core and iOS app.
- Official [release asset 453863469](https://api.github.com/repos/introlab/rtabmap/releases/assets/453863469): `libraries-ios-xcode26.5.zip`, **234,342,396 bytes**, SHA-256 **ec84a34adacb09a851e14dff4f351114f92aca261ad36df8906b8c2945a28747**. URL: https://github.com/introlab/rtabmap/releases/download/0.23.1/libraries-ios-xcode26.5.zip . Verify this metadata and digest before any authorized download.
- Official asset metadata has compressed size/digest only; **expanded size and content manifest are not exposed**. Binary/range inspection is unavailable through the approved GitHub text connector. Do not assume expanded size. The authorized hosted attempt must inspect the ZIP central directory and enforce an expanded-size cap **before extraction**, then record actual totals.
- The install script sets `sysroot=iphoneos` and arm64. VTK explicitly builds device arm64 with no simulator architecture. Arm64 alone does not distinguish an iPhone library from an arm64 simulator library. The first relevant target is **generic iOS device, unsigned**, not simulator tests. The successful default app simulator build excludes `BLIND_RTABMAP`.
- Cross-Xcode-26.5/27 static-library and SDK compatibility is an experiment outcome, not established by the archive name or source review. No iOS run for the exact pinned SHA appeared in the eight returned GitHub workflow records; the workflow recipe is not recorded passing evidence.
- A full source-dependency fallback is not bounded: full clones, tag-only dependency selections, unpinned libLAS default branch, no archive checksums, no explicit build-job cap, and commented-out cleanup. Avoid allowing a missing prebuilt sentinel to silently trigger those builds.

## Declared direct dependency inputs

These are the **script's expected versions**, not an independently inspected binary SBOM. The archive still requires its own header/version/library manifest on the hosted runner. Top-level licenses are not a complete transitive audit.

| Input | Script selection | Primary license evidence |
|---|---|---|
| RTAB-Map | exact a4e7f135… | [BSD-3-Clause](https://github.com/introlab/rtabmap/blob/a4e7f13522722878dea3f07e8fd082291e72eb49/LICENSE) |
| Boost | 1.88.0 CMake release tarball, no checksum | [Boost Software License 1.0](https://github.com/boostorg/boost/blob/boost-1.88.0/LICENSE_1_0.txt) |
| Eigen | 3.4.0 tarball, no checksum | [MPL2 primarily; some BSD/LGPL files](https://gitlab.com/libeigen/eigen/-/blob/3.4.0/COPYING.README); script does not set EIGEN_MPL2_ONLY |
| LZ4 | v1.10.0 tag | [Library BSD-2-Clause](https://github.com/lz4/lz4/blob/v1.10.0/lib/LICENSE); program license is separate |
| FLANN | 1.9.2 tag | [BSD-3-Clause](https://github.com/flann-lib/flann/blob/1.9.2/COPYING) |
| GTSAM | 4.2 tag | [BSD plus declared third-party licenses](https://github.com/borglab/gtsam/blob/4.2/LICENSE) |
| SuiteSparse | v7.6.1, cholmod/cxsparse/spqr | [Module-specific licenses](https://github.com/DrTimothyAldenDavis/SuiteSparse/blob/v7.6.1/LICENSE.txt), including GPL/LGPL |
| g2o | 20241228_git tag | [BSD core; LGPL csparse_extension; other exceptions](https://github.com/RainerKuemmerle/g2o/blob/20241228_git/README.md#license) |
| VTK | v9.5.0.rc1 tag | [BSD-3-Clause root](https://github.com/Kitware/VTK/blob/v9.5.0.rc1/Copyright.txt), transitive components separate |
| PCL | pcl-1.15.0 tag | [BSD-3-Clause root](https://github.com/PointCloudLibrary/pcl/blob/pcl-1.15.0/LICENSE.txt) |
| OpenCV + contrib | 4.11.0 tags | [Apache2 root](https://github.com/opencv/opencv/blob/4.11.0/LICENSE), bundled/contrib parts separate; ENABLE_NONFREE=ON is explicitly used |
| LASzip | 2.0.1 tag | [LGPL2.1 text](https://github.com/LASzip/LASzip/blob/2.0.1/COPYING) |
| libLAS | **unversioned default branch** | [BSD-3-Clause root](https://github.com/libLAS/libLAS/blob/master/LICENSE.txt), not an immutable source version |

LZ4, FLANN, GTSAM, g2o and PCL also consume versioned raw gist patches/configurations. Their full URLs are in the pinned script; they are external source inputs, not a root-license guarantee.

Additional Swift dependencies: upstream Zip resolved **2.1.1 / bd19d974e8a38cc8d3a88c90c8a107386c3b8ccf**, [MIT root](https://github.com/marmelroy/Zip/blob/bd19d974e8a38cc8d3a88c90c8a107386c3b8ccf/LICENSE); project requirement alone is a floating 2.x range, so preserve/verify its lock. App BlindMemory adds exact GRDB **7.11.1 / b83108d10f42680d78f23fe4d4d80fc88dab3212**, [MIT root](https://github.com/groue/GRDB.swift/blob/v7.11.1/LICENSE). Zip's bundled minizip and other embedded libraries still need transitive notices.

## Distribution caveat, separate from compiling

The exact pinned upstream project directly links `libspqr.a`, `libcholmod.a`, `libcxsparse.a`, `libg2o_csparse_extension.a`, and `liblaszip.a`. SPQR is GPL2-or-later. CHOLMOD contains GPL and LGPL modules; [CHOLMOD_GPL defaults ON](https://github.com/DrTimothyAldenDavis/SuiteSparse/blob/v7.6.1/CHOLMOD/CMakeLists.txt), and the script does not disable it. CXSparse/g2o csparse extension/LASzip have LGPL terms. Consequently RTAB-Map's BSD root alone is not evidence of acceptable app-binary redistribution. Preserve actual linked-component notices and obtain a proper distribution review before shipping. A bounded private compile-only experiment with no app/IPA artifact publication is distinct from a distribution approval.

## Proposed single hosted attempt — not executed

1. Dedicated manual-only workflow, explicit repository/public-source guard, read-only contents permission, no secrets or persisted checkout credentials. Require `RUNNER_ENVIRONMENT=github-hosted`, Darwin, exact installed `/Applications/Xcode_27.0.app/Contents/Developer`, iPhoneOS 27 SDK, installed CMake/Node/Python. If a tool is absent, stop; **no brew, OS install, simulator/runtime install, or alternate runner**.
2. One attempt, at most **45 minutes total**, CMake and Xcode at most **2 jobs**. Suggested policy ceilings (not measured needs): start only with >=12 GiB free; scoped work directory <=8 GiB; archive expanded sum <=4 GiB and <=100,000 entries; keep >=2 GiB free while compiling. Record actual free space and resource peaks. Stop on a cap/failure; do not retry by installing/building all dependencies.
3. Checkout the exact app commit and record it. Acquire only exact upstream SHA via shallow fetch into a disposable directory, verify HEAD, run the reviewed existing app preparation plus mapper's exact reviewed overlay. Record every overlay file SHA and patch preimage. Default app project is not regenerated or relabeled.
4. Download the single official ZIP with strict HTTPS, failure-on-HTTP-error, finite request timeout, no retries, exact byte count and the SHA above. Do not cache an unchecked archive or use a different release silently.
5. Before extraction, inspect the ZIP directory, sum uncompressed bytes/entries, reject encryption, absolute/traversal paths and escaping symlink targets. Preserve only validated internal framework links. Accept only the known direct-root or Libraries wrapper layout. Extract once into the disposable Libraries directory; no duplicate extraction/copy tree.
6. Verify the install script's skip sentinels **and** required actual static libraries/framework before allowing the core build. Sentinels: boost, eigen3, lz4.h, flann, gtsam, suitesparse/SuiteSparse_config.h, g2o, lib/vtk.framework, pcl-1.15, opencv4, laszip and liblas. Capture version headers; enumerate and hash linked libraries. Check platform load commands, not merely lipo arm64, for representative/all linked objects. Fail closed on a missing sentinel rather than entering dependency builds.
7. Apply upstream's reviewed g2o relocatable-prefix adjustment and execute only the pinned RTAB resource/prebuild + iOS-core CMake steps. Set CMAKE_BUILD_PARALLEL_LEVEL=2 and explicit --parallel 2. A guarded upstream script is acceptable only if its dependency-build branches cannot run. Avoid an unreviewed full source fallback.
8. Resolve and verify only the existing Swift dependencies (Zip and GRDB) and preserve resolved revisions. Build the **prepared RTABMapApp target** with `-sdk iphoneos -destination generic/platform=iOS -configuration Release -jobs 2 ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM= build`. No test/run/install/archive/sign/export operation. BLIND_RTABMAP overlay source must actually be in this target.
9. Preserve exit codes, exact source/asset/toolchain pins, CMake settings, architecture/platform inspection, bounded diagnostics and resource summary. Upload **metadata/log excerpts only** (suggested <=2 MiB, retention3days), never Libraries, .app, .ipa, archive, private sensor data, environment dump or credentials. Keep full first-failure logs on that ephemeral CI run for diagnosis, with honest timeout/failure classification.
10. Success means this exact source and library set compiled/linked for device SDK under Xcode27. It does **not** establish live mapping, localization accuracy, sensor-to-body calibration, simulator runtime compatibility, device installability, safety, complete license compliance, or navigation completion.

Dependency-install script SHA256: 7b6bd18c9240183a4fc873fedefee9c0a8d89c8da9f7e91218c1d2d2fd217aa1.

