#!/usr/bin/env python3
"""Bounded, dependency-free production-source Swift scene/runtime check.

Requires Python 3, a Swift 5.9+ toolchain, and Node for optional source contracts.
No downloads, credentials, Apple SDK or native RTAB libraries are used.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

CORE = ["Geometry", "HazardDetector", "Journey", "LocalPlanner", "MonitoringRecovery",
        "NavigationSurface", "ObservedScene", "ReturnTrail", "StoredTerrainAssessment"]
PACKAGE = '''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ObservedSceneCheck", products: [.library(name:"BlindCore",targets:["BlindCore"])],targets:[.target(name:"BlindCore"),.target(name:"NativeScene",dependencies:["BlindCore"]),.testTarget(name:"SceneTests",dependencies:["BlindCore","NativeScene"])])
'''

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[3])
    p.add_argument("--overlay", type=Path, help="Optional source overlay, for pre-merge verification")
    p.add_argument("--work-dir", type=Path, help="Retain a reusable build directory; otherwise use a temporary one")
    p.add_argument("--skip-source-contracts", action="store_true", help="Swift only; source contracts require a complete merged source root")
    args = p.parse_args()
    root = args.source_root.resolve()
    swift = shutil.which(os.environ.get("SWIFT", "swift"))
    if not swift:
        p.error("Swift toolchain not found; select an installed Swift 5.9+ toolchain")
    temporary = tempfile.TemporaryDirectory(prefix="blind-observed-scene-") if args.work_dir is None else None
    work = Path(temporary.name) if temporary else args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    hashes = {}
    def copy_source(relative, destination):
        source = args.overlay / relative if args.overlay and (args.overlay / relative).is_file() else root / relative
        data = source.read_bytes()
        hashes[relative] = hashlib.sha256(data).hexdigest()
        target = work / destination
        target.parent.mkdir(parents=True, exist_ok=True)
        # Never write through a stale harness symlink into production source.
        if target.is_symlink():
            target.unlink()
        target.write_bytes(data)
    try:
        for name in CORE:
            copy_source(f"BlindCore/Sources/BlindCore/{name}.swift", f"Sources/BlindCore/{name}.swift")
        copy_source("ios/BlindAssist/ObservedSceneRuntime.swift", "Sources/NativeScene/ObservedSceneRuntime.swift")
        copy_source("BlindCore/Tests/BlindCoreTests/ObservedSceneTests.swift", "Tests/SceneTests/ObservedSceneTests.swift")
        copy_source("ios/BlindAssistTests/ObservedSceneRuntimeTests.swift", "Tests/SceneTests/ObservedSceneRuntimeTests.swift")
        (work / "Package.swift").write_text(PACKAGE)
        # NavigationSurface refers to this enum in the larger map package. This
        # unused error declaration is the only shim; no planner or sensor is mocked.
        (work / "Sources/BlindCore/MapError.swift").write_text("public enum MapError: Error { case invalid, unknownNode, unreachable }\n")
        environment = dict(os.environ)
        environment["CLANG_MODULE_CACHE_PATH"] = str(work / "module-cache")
        environment["SWIFTPM_MODULECACHE_OVERRIDE"] = str(work / "module-cache")
        subprocess.run([swift, "test", "--package-path", str(work), "--cache-path", str(work / "cache"), "--jobs", "2"],
                       env=environment, check=True)
        if not args.skip_source_contracts:
            node = shutil.which("node")
            if not node:
                p.error("Node is required for source contracts, or choose --skip-source-contracts")
            subprocess.run([node, "--test", "tools/test/observed-scene.test.mjs",
                            "tools/test/spatial-review-regressions.test.mjs",
                            "tools/test/contextual-capabilities.test.mjs"], cwd=root, check=True)
        print(json.dumps({"productionSourceSHA256": hashes, "scope": "portable Core + Foundation runtime; not ARKit/RTAB/device"}, indent=2))
    finally:
        if temporary:
            temporary.cleanup()

if __name__ == "__main__":
    main()
