#!/usr/bin/env python3
"""Compile real grid bridge helpers, consumer and exact Swift callback fragment.
No downloads; this does not build or execute the full RTAB/ARKit engine.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

def callback_fragment(patch):
    lines = patch.splitlines()
    marker = '+    // Capture-scoped local-grid stream. This is separate from rendered-camera stats.'
    index = lines.index(marker)
    result = []
    for line in lines[index:]:
        if not line.startswith('+'):
            break
        result.append(line[1:])
    text = '\n'.join(result) + '\n'
    if 'private static func copyLocalGrid' not in text or 'return .init(status: status' not in text:
        raise ValueError('Pinned callback fragment boundary changed; review the runner')
    return text

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument('--overlay', type=Path)
    parser.add_argument('--work-dir', type=Path)
    parser.add_argument('--skip-source-contracts', action='store_true')
    args = parser.parse_args()
    root = args.source_root.resolve()
    temporary = tempfile.TemporaryDirectory(prefix='blind-native-grid-') if args.work_dir is None else None
    work = Path(temporary.name) if temporary else args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    hashes = {}
    def source(path):
        candidate = args.overlay / path if args.overlay else None
        value = (candidate if candidate and candidate.is_file() else root / path).read_bytes()
        hashes[path] = hashlib.sha256(value).hexdigest()
        return value
    def write(path, value):
        target = work / path; target.parent.mkdir(parents=True, exist_ok=True)
        if target.is_symlink(): target.unlink()
        target.write_bytes(value if isinstance(value, bytes) else value.encode())
    try:
        cpp = shutil.which(os.environ.get('CXX', 'c++'))
        swift = shutil.which(os.environ.get('SWIFT', 'swift'))
        if not cpp or not swift: parser.error('Select installed C++14 and Swift5.9+ toolchains; no installation is performed')
        header = source('integration/rtabmap/BlindLocalGridBridge.hpp')
        write('Sources/BridgeFixture/include/BlindLocalGridBridge.hpp', header)
        fixtures = 'research/evaluations/rtab-local-grid/fixtures/'
        write('grid_bridge_test.cpp', source(fixtures + 'grid_bridge_test.cpp'))
        executable = work / 'grid_bridge_test'
        subprocess.run([cpp, '-std=c++14', '-pthread', '-Wall', '-Wextra', '-Werror', '-I', str(work / 'Sources/BridgeFixture/include'),
                        str(work / 'grid_bridge_test.cpp'), '-o', str(executable)], check=True)
        subprocess.run([str(executable)], check=True)
        write('Sources/BlindCore/Geometry.swift', source('BlindCore/Sources/BlindCore/Geometry.swift'))
        original = source('BlindCore/Sources/BlindCore/NativeObservation.swift').decode()
        # Exact existing matrix/error declarations; omit unrelated durable archive
        # types that depend on the entire spatial registry package. No math mock.
        write('Sources/BlindCore/NativeCameraTransform.swift', original[:original.index('public struct NativeCameraIntrinsics')])
        write('Sources/BlindCore/NativeLocalGrid.swift', source('BlindCore/Sources/BlindCore/NativeLocalGrid.swift'))
        write('Tests/GridTests/NativeLocalGridTests.swift', source('BlindCore/Tests/BlindCoreTests/NativeLocalGridTests.swift'))
        for path, target in [('BridgeFixture.h', 'Sources/BridgeFixture/include/BridgeFixture.h'),
                             ('BridgeFixture.cpp', 'Sources/BridgeFixture/BridgeFixture.cpp'),
                             ('NativeGridInteropTests.swift', 'Tests/GridTests/NativeGridInteropTests.swift')]:
            write(target, source(fixtures + path))
        fragment = callback_fragment(source('integration/rtabmap/local-grid.patch').decode())
        write('Sources/NativeRTABFixture/RTABMap.swift', 'import Foundation\nimport BlindCore\nimport BridgeFixture\n'
              '// ARKit engine shell is a fixture; callback body below is exact patch source.\n'
              'class RTABMap {\nvar native_rtabmap = UnsafeMutableRawPointer(bitPattern: 1)!\n' + fragment + '\n deinit { setBlindGridCallbackNative(native_rtabmap, nil, nil); destroyNativeApplication(native_rtabmap) }\n}\n')
        write('Package.swift', '''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "NativeGridCheck", targets: [.target(name:"BlindCore"), .target(name:"BridgeFixture",publicHeadersPath:"include"), .target(name:"NativeRTABFixture",dependencies:["BlindCore","BridgeFixture"]), .testTarget(name:"GridTests",dependencies:["BlindCore","NativeRTABFixture","BridgeFixture"])],cxxLanguageStandard:.cxx14)
''')
        environment = dict(os.environ)
        environment['CLANG_MODULE_CACHE_PATH'] = str(work / 'module-cache')
        environment['SWIFTPM_MODULECACHE_OVERRIDE'] = str(work / 'module-cache')
        subprocess.run([swift, 'test', '--package-path', str(work), '--cache-path', str(work / 'cache'), '--jobs', '2'], env=environment, check=True)
        if not args.skip_source_contracts:
            node = shutil.which('node')
            if not node: parser.error('Node required for source contracts, or choose --skip-source-contracts')
            subprocess.run([node, '--test', 'tools/test/native-local-grid.test.mjs'], cwd=root, check=True)
        print(json.dumps({'sourceSHA256': hashes, 'compiledScope': 'production C++ helper + Core consumer + exact Swift C callback; RTAB/ARKit engine is NOT executed'}, indent=2))
    finally:
        if temporary: temporary.cleanup()

if __name__ == '__main__':
    main()
