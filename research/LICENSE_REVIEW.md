# Initial dependency license review — 2026-10-02

This is an inventory of inspected source notices, not a completed distribution clearance. Publishing our own app source is a different task from redistributing complete firmware or native iOS binaries. No repository has been published and no license for the user's original project has been chosen yet. Noncommercial or private use does not automatically override dependency or service terms.

| Dependency | Evidence inspected | Status |
| --- | --- | --- |
| RTAB-Map, pinned `a4e7f13522722878dea3f07e8fd082291e72eb49` | Upstream root LICENSE in downloaded source | BSD 3-clause terms allow source/binary redistribution with notices and conditions. This does not cover every linked dependency. |
| Adafruit DRV2605 1.2.4 and installed BusIO | LICENSE files in PlatformIO libdeps | MIT notices present. |
| NimBLE-Arduino 2.3.6 | LICENSE and NOTICE in PlatformIO libdeps | Apache-2.0 plus retained upstream notices. |
| Pololu VL53L1X 1.3.1 | LICENSE in PlatformIO libdeps | BSD 3-clause/ST-derived source notices. |
| SparkFun VL53L5CX 1.0.3 | Root LICENSE.md and source headers | **Inconsistent notices:** root says MIT for code, but wrapper headers mention GNU GPL. ST driver headers separately offer BSD 3-clause or ST proprietary terms. Resolve the wrapper-header conflict before selecting a project-wide license or distributing belt binaries. |
| Recast/Detour test checkout | Upstream license, source revision recorded in GUIDANCE_AND_REUSE.md | Zlib; evaluated separately, not linked into the app. |
| 3DLite initial apartment evaluation data | Dataset source and hash in maps/REAL_SCAN_EVALUATION.md | CC BY-NC-SA 4.0; original mesh and derived grid/ray previews stay separate from app licensing and are excluded from the handoff. |
| RGB-D stair dataset v1 | Publisher license and hashes saved by tools/download-stairs.py | CC BY 4.0 data with attribution; the associated model code has different terms and was not imported. Raw and derived evaluation data are excluded from the handoff. |
| Apple SDK/frameworks/models | Used via platform APIs, not copied into the repository | Apple's developer/runtime terms remain applicable. The system model is not an open-source weight bundle we can redistribute. |
| Ajv 8.20.0 relay validation (2026-10-08) | Exact npm version, tarball integrity and dependencies in package-lock; installed license files retained under research/assistant-selected/ajv-8.20.0 | Ajv, fast-deep-equal, json-schema-traverse and require-from-string: MIT. fast-uri: BSD-3-Clause. Preserve these notices when redistributing the dependencies. Upstream suite not run here. |

The native upstream `install_deps.sh` also builds Boost, LZ4, FLANN, GTSAM, SuiteSparse, g2o, VTK, PCL, OpenCV/contrib, LASzip and libLAS. It enables static builds and OpenCV nonfree features. Several of these projects have component-specific licenses; root-level RTAB-Map BSD licensing is not enough to clear the resulting app binary. Record the exact built libraries, retain their notices, inspect SuiteSparse/g2o/other copyleft components and nonfree feature selection, and adjust the dependency configuration as appropriate before distribution. The ESP32 and nRF52840 framework/toolchain packages also require a transitive review.

The handoff packages this workspace's source and build instructions, excluding the downloaded dependency caches and firmware binaries. That keeps unreviewed third-party bundles out of the transfer artifact; it does not make all eventual builds automatically compatible with any chosen license.

Sources: [RTAB-Map license](https://github.com/introlab/rtabmap/blob/master/LICENSE), [NimBLE-Arduino](https://github.com/h2zero/NimBLE-Arduino), [SparkFun VL53L5CX](https://github.com/sparkfun/SparkFun_VL53L5CX_Arduino_Library), and the installed, version-pinned local license files. Separately, [Gemini API terms](https://ai.google.dev/gemini-api/terms) exclude under-18-directed/likely-accessed clients; that service is not selected for this children's app.
