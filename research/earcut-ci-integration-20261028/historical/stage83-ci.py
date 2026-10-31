#!/usr/bin/env python3
"""Bounded serial real-package host fixtures; actual ARKit iOS Simulator compile only."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform

HOME = Path(__file__).resolve().parent.parent
ROOT = HOME.parent.parent
PACKAGE_HOME = ROOT / 'research/room-mesh-package-75'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = load('stage81_runner', ROOT / 'research/native-mesh-decoder-81/apple/ci.py')
package_runner = load('stage75_runner', PACKAGE_HOME / 'apple/ci.py')


def verify_pins(base, manifest):
    for name, digest in json.loads(manifest.read_text()).items():
        assert hashlib.sha256((base / name).read_bytes()).hexdigest() == digest, name


def main():
    assert platform.system() == 'Darwin', 'Apple host required'
    assert os.environ['GITHUB_REPOSITORY'] == 'mischa23v/blind'
    assert os.environ['GITHUB_REF'] == runner.BRANCH
    assert runner.output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']) == os.environ['GITHUB_SHA']
    assert runner.output(['xcodebuild', '-version']).splitlines()[0] == 'Xcode 27.0'
    assert runner.output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version']) == '27.0'
    verify_pins(ROOT, HOME / 'SOURCE_PINS.json')
    verify_pins(PACKAGE_HOME, PACKAGE_HOME / 'APPLE_SOURCE_PINS.json')
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-mesh-candidate-ingress-83'
    out.mkdir(exist_ok=False)
    (out / 'tmp').mkdir()
    host_sdk = runner.output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'])
    env = package_runner.package_environment(host_sdk, out)
    package = PACKAGE_HOME / 'BlindRoomMesh'
    decoder = ROOT / 'research/native-mesh-decoder-81/Sources/MeshBufferDecoder.swift'
    snapshot = ROOT / 'research/arkit-mesh-adapter-82/Sources/MeshSnapshot.swift'
    native_snapshot = ROOT / 'research/arkit-mesh-adapter-82/Sources/ARKitMeshAdapter.swift'
    fixture_log = None
    for sdk, triple, stem in [('macosx', 'arm64-apple-macosx14.0', 'host'),
                              ('iphonesimulator', 'arm64-apple-ios17.0-simulator', 'simulator')]:
        sdkpath = runner.output(['xcrun', '--sdk', sdk, '--show-sdk-path'])
        # Same proven native SwiftPM compatibility variant; not the default SwiftBuild backend.
        build = package_runner.package_build_command(package, out, stem + '-package', triple, sdkpath)
        package_runner.run(build, stem + '-package-build', out, 300, env=env)
        bindir = Path(package_runner.output(build + ['--show-bin-path'], env=env))
        objects = sorted((bindir / 'CDetour.build').rglob('*.o')) + sorted((bindir / 'BlindRoomMesh.build').glob('*.o'))
        assert 25 <= len(objects) <= 64, 'unexpected real package object set'
        folder = out / stem
        folder.mkdir()
        base = ['xcrun', '--sdk', sdk, 'swiftc', '-target', triple, '-sdk', sdkpath,
                '-module-cache-path', str(out / (stem + '-client-cache'))]
        imports = ['-I', str(folder), '-I', str(bindir / 'Modules'),
                   '-I', str(package / 'Sources/CDetour/include')]
        libraries = ['-L', str(folder), '-Xlinker', '-rpath', '-Xlinker', str(folder)]
        # Materialize a linkable dylib from the actual SwiftPM objects, not replacement stubs.
        runner.run(base + ['-emit-library', *map(str, objects), '-lc++',
                          '-o', str(folder / 'libBlindRoomMesh.dylib')], stem + '-package-dylib', out)

        def module(name, sources, dependencies=(), testing=False):
            runner.run(base + ['-emit-library', '-emit-module', '-module-name', name,
                '-emit-module-path', str(folder / (name + '.swiftmodule')),
                *(['-enable-testing'] if testing else []), *imports, *libraries,
                *['-l' + dependency for dependency in dependencies], *map(str, sources),
                '-o', str(folder / ('lib' + name + '.dylib'))], stem + '-' + name, out)

        module('MeshBufferDecoder81', [decoder])
        module('MeshSnapshot82', [snapshot] + ([native_snapshot] if stem == 'simulator' else []),
               ['MeshBufferDecoder81'], testing=stem == 'host')
        module('MeshCandidateIngress83', [HOME / 'Sources/MeshCandidateIngress.swift'] +
               ([HOME / 'Sources/ARKitIngress.swift'] if stem == 'simulator' else []),
               ['MeshBufferDecoder81', 'MeshSnapshot82', 'BlindRoomMesh'], testing=stem == 'host')
        if stem == 'host':
            runner.run(base + [*imports, *libraries, '-lMeshBufferDecoder81', '-lMeshSnapshot82',
                '-lBlindRoomMesh', '-lMeshCandidateIngress83', str(HOME / 'tests/main.swift'),
                '-o', str(out / 'fixtures')], 'host-fixtures-compile', out)
            fixture_log = runner.run([str(out / 'fixtures')], 'host-fixtures-run', out)
            assert 'RESULT: 83 stage83 real-runtime synthetic checks passed' in fixture_log
    result = dict(commit=os.environ['GITHUB_SHA'], hostRealPackageFixtures='passed',
        actualARKitSimulatorCompile='passed', swiftPMBuildSystem=package_runner.BUILD_SYSTEM,
        defaultSwiftBuildBackendPassed=False,
        fixtureResult=[line for line in fixture_log.splitlines() if line.startswith('RESULT:')],
        appActivation=False, simulatorExecution=False, deviceExecution=False,
        copyLatencyMeasured=False, physicalAuthority=False)
    (out / 'RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
