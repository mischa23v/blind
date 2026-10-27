#!/usr/bin/env python3
"""Serial host fixtures + actual ARKit simulator compile only. No sensor/device execution."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform

HOME = Path(__file__).resolve().parent.parent
ROOT = HOME.parent.parent
spec = importlib.util.spec_from_file_location('decoder_ci', ROOT / 'research/native-mesh-decoder-81/apple/ci.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

def main():
    assert platform.system() == 'Darwin', 'Apple host required'
    assert os.environ['GITHUB_REPOSITORY'] == 'mischa23v/blind'
    assert os.environ['GITHUB_REF'] == runner.BRANCH
    assert runner.output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']) == os.environ['GITHUB_SHA']
    assert runner.output(['xcodebuild', '-version']).splitlines()[0] == 'Xcode 27.0'
    assert runner.output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version']) == '27.0'
    for name, digest in json.loads((HOME / 'SOURCE_PINS.json').read_text()).items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-arkit-mesh-adapter-82'
    out.mkdir(exist_ok=False); (out / 'tmp').mkdir()
    decoder = ROOT / 'research/native-mesh-decoder-81/Sources/MeshBufferDecoder.swift'
    snapshot = HOME / 'Sources/MeshSnapshot.swift'
    native = HOME / 'Sources/ARKitMeshAdapter.swift'
    host_sdk = runner.output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'])
    base = ['xcrun', '--sdk', 'macosx', 'swiftc', '-sdk', host_sdk, '-module-cache-path', str(out / 'host-cache')]
    def module(base, name, sources, folder, extra=()):
        runner.run(base + ['-emit-library', '-emit-module', '-module-name', name,
            '-emit-module-path', str(folder / (name + '.swiftmodule')), *extra, *map(str, sources),
            '-o', str(folder / ('lib' + name + '.dylib'))], folder.name + '-' + name, out)
    host = out / 'host'; host.mkdir()
    module(base, 'MeshBufferDecoder81', [decoder], host)
    module(base, 'MeshSnapshot82', [snapshot], host, ['-enable-testing', '-I', str(host), '-L', str(host), '-lMeshBufferDecoder81'])
    runner.run(base + ['-I', str(host), '-L', str(host), '-lMeshBufferDecoder81', '-lMeshSnapshot82',
        '-Xlinker', '-rpath', '-Xlinker', str(host), str(HOME / 'tests/main.swift'),
        '-o', str(out / 'fixtures')], 'host-fixtures-compile', out)
    log = runner.run([str(out / 'fixtures')], 'host-fixtures-run', out)
    assert 'stage82 synthetic descriptor/snapshot checks passed' in log
    simulator = out / 'simulator'; simulator.mkdir()
    sdk = runner.output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'])
    simbase = ['xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-sdk', sdk,
        '-target', 'arm64-apple-ios17.0-simulator', '-module-cache-path', str(out / 'sim-cache')]
    module(simbase, 'MeshBufferDecoder81', [decoder], simulator)
    module(simbase, 'MeshSnapshot82', [snapshot, native], simulator,
           ['-I', str(simulator), '-L', str(simulator), '-lMeshBufferDecoder81'])
    result = dict(commit=os.environ['GITHUB_SHA'], hostSynthetic='passed', actualARKitSimulatorCompile='passed',
        fixtureResult=[line for line in log.splitlines() if line.startswith('RESULT:')],
        deviceExecution=False, copyLatencyMeasured=False, runtimeActivation=False, physicalAuthority=False)
    (out / 'RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))

if __name__ == '__main__':
    main()
