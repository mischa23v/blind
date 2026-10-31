#!/usr/bin/env python3
"""INERT proposal: explicit opt-in; reuse unchanged stage83/75 bounded Apple lane.

No workflow, installation, simulator execution, app build or live sensor input.
This runner and its Swift fixtures have not run on Apple; source checks only.
"""
import argparse
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import re
import sys

HOME = Path(__file__).resolve().parent.parent
ROOT = HOME.parent.parent
PACKAGE_HOME = ROOT / 'research/room-mesh-package-75'


def verify_pins(base, manifest):
    for name, digest in json.loads(manifest.read_text()).items():
        assert hashlib.sha256((base / name).read_bytes()).hexdigest() == digest, name


def load(path):
    spec = importlib.util.spec_from_file_location('stage83_proposal_dependency', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def expected_rejection(filename, diagnostic):
    """Accept only the intended source error, not a missing-module/cascade failure."""
    patterns = {
        'forged-lease': r"(?:'init'|'(?:\w+\.)*ProducerLease' initializer) is inaccessible due to 'fileprivate' protection level",
        'missing-lease': r"missing argument for parameter 'lease' in call",
        'missing-ingest-lease': r"missing argument for parameter 'lease' in call",
        'current-lease': r"value of type '[^']+' has no member 'currentLease'",
    }
    errors = re.findall(r'^(.+?):\d+:\d+: error: (.+)$', diagnostic, re.M)
    error_lines = [line for line in diagnostic.splitlines() if re.search(r'(?:^|: )error: ', line)]
    expected_file = filename + '-must-not-compile.swift'
    return (filename in patterns and bool(errors) and len(errors) == len(error_lines) and
            (filename != 'forged-lease' or 'ProducerLease' in diagnostic) and
            all(Path(path).name == expected_file and re.fullmatch(patterns[filename], message)
                for path, message in errors))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute-authorized-apple', action='store_true',
                        help='only after separate authorization of this exact Apple scope')
    args = parser.parse_args()
    if not args.execute_authorized_apple:
        parser.error('inert by default; Apple execution is not authorized by this proposal')
    assert platform.system() == 'Darwin', 'Apple host required'
    verify_pins(ROOT, HOME / 'SOURCE_PINS.json')
    stage83 = load(ROOT / 'research/mesh-candidate-ingress-83/apple/ci.py')
    runner, package_runner = stage83.runner, stage83.package_runner
    # Existing repository/ref/revision/Xcode/SDK guards and both nested manifests.
    # Builds real native SwiftPM products exactly ONCE per target and reruns stage83.
    # Its receipts and RESULT.json remain separate and unchanged.
    stage83.main()
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-mesh-candidate-ingress-83'
    # Keep ALL added files under the SAME 512 MiB stage-end accounted scratch tree.
    # No fresh budget to bypass an existing cap; none of these is a live RAM quota.
    package = PACKAGE_HOME / 'BlindRoomMesh'
    host_sdk = runner.output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'])
    env = package_runner.package_environment(host_sdk, out)
    fixture_result = None
    negatives = []
    stage75_result = None
    for sdk, triple, stem in [('macosx', 'arm64-apple-macosx14.0', 'host'),
                              ('iphonesimulator', 'arm64-apple-ios17.0-simulator', 'simulator')]:
        sdkpath = runner.output(['xcrun', '--sdk', sdk, '--show-sdk-path'])
        # Lookup only: reuse the exact existing build command/environment and outputs.
        build = package_runner.package_build_command(package, out, stem + '-package', triple, sdkpath)
        bindir = Path(package_runner.output(build + ['--show-bin-path'], env=env))
        inherited = out / stem
        folder = out / ('stage86-' + stem)
        folder.mkdir(exist_ok=False)
        base = ['xcrun', '--sdk', sdk, 'swiftc', '-target', triple, '-sdk', sdkpath,
                '-module-cache-path', str(out / (stem + '-client-cache'))]
        imports = ['-I', str(folder), '-I', str(inherited), '-I', str(bindir / 'Modules'),
                   '-I', str(package / 'Sources/CDetour/include')]
        libraries = ['-L', str(folder), '-L', str(inherited),
                     '-Xlinker', '-rpath', '-Xlinker', str(folder),
                     '-Xlinker', '-rpath', '-Xlinker', str(inherited)]
        links = ['-lMeshBufferDecoder81', '-lMeshSnapshot82', '-lBlindRoomMesh']
        sources = [HOME / 'Sources/OriginBoundMeshIngress.swift']
        if stem == 'simulator':
            sources.append(HOME / 'Sources/ARKitIngress.swift')
        runner.run(base + ['-emit-library', '-emit-module', '-module-name', 'OriginBoundMeshIngress86',
            '-emit-module-path', str(folder / 'OriginBoundMeshIngress86.swiftmodule'),
            *imports, *libraries, *links, *map(str, sources),
            '-o', str(folder / 'libOriginBoundMeshIngress86.dylib')], 'stage86-' + stem + '-module', out)
        if stem != 'host':
            continue  # Actual ARKit source linked; simulator NEVER launched or installed.
        runner.run(base + [*imports, '-typecheck', str(HOME / 'tests/public-client.swift')],
                   'stage86-host-public-signatures', out)
        runner.run(base + [*imports, *libraries, *links, '-lOriginBoundMeshIngress86',
            str(HOME / 'tests/main.swift'), '-o', str(folder / 'fixtures')], 'stage86-host-fixtures-compile', out)
        fixture_log = runner.run([str(folder / 'fixtures')], 'stage86-host-fixtures-run', out)
        fixture_result = [line for line in fixture_log.splitlines() if line.startswith('RESULT:')]
        assert len(fixture_result) == 1 and re.fullmatch(
            r'RESULT: [1-9][0-9]* stage86 real-runtime synthetic checks passed; no ARKit-origin or device proof',
            fixture_result[0]), 'missing actual fixture completion result'
        # A missing import/toolchain failure alone must NEVER count as API rejection.
        for filename in ['forged-lease', 'missing-lease', 'missing-ingest-lease', 'current-lease']:
            label = 'stage86-negative-' + filename
            tail = runner.run(base + [*imports, '-typecheck',
                str(HOME / ('tests/' + filename + '-must-not-compile.swift'))], label, out,
                expected_failure=True)
            assert expected_rejection(filename, tail), 'unrelated compiler failure: ' + filename
            negatives.append(filename)
        # Stage75 regressions use the SAME actual module/dylib, without a second build.
        regression = out / 'stage86-stage75'
        regression.mkdir(exist_ok=False)
        packed = ROOT / 'research/apple-candidate-ci-71/fixture/room.json.gz'
        assert hashlib.sha256(packed.read_bytes()).hexdigest() == '6ae71b8660d7ae617eee274d0bae07eccb2fa983b382dd741f18596cbe596bc1'
        with gzip.open(packed, 'rb') as stream:
            data = stream.read((8 << 20) + 1)
        assert len(data) <= 8 << 20 and hashlib.sha256(data).hexdigest() == '6cd1b3317d13c98551335b12f24ca6899553dd8bfb291f62b0d2187aa364bfdb'
        (regression / 'INPUT.json').write_bytes(data)
        common = base + [*imports, *libraries, '-lBlindRoomMesh']
        public_client = regression / 'public-client'
        package_runner.run(common + [str(PACKAGE_HOME / 'apple/public-client.swift'),
            '-o', str(public_client)], 'stage86-stage75-public-link', out)
        package_runner.run([str(public_client)], 'stage86-stage75-public-run', out, 60)
        tests = regression / 'main.swift'
        tests.write_text('@testable import BlindRoomMesh\n' + (PACKAGE_HOME / 'tests/main.swift').read_text())
        replay = regression / 'fixtures'
        package_runner.run(common + [str(tests), '-o', str(replay)], 'stage86-stage75-fixtures-link', out)
        package_runner.run([str(replay), str(regression / 'INPUT.json'), str(regression / 'RESULT.json')],
                           'stage86-stage75-fixtures-run', out, 120)
        geometry = json.loads((regression / 'RESULT.json').read_text())
        lifecycle = json.loads((regression / 'RUNTIME_RESULT.json').read_text())
        assert geometry['passed'] and len(geometry['checks']) == 55 and geometry['markedSpans'] == 636
        assert lifecycle['passed'] and len(lifecycle['checks']) == 32
        assert len(lifecycle['failureCommitChecks']) == 5 and all(lifecycle['failureCommitChecks'].values())
        assert len(lifecycle['discardChecks']) == 19 and all(lifecycle['discardChecks'].values())
        stage75_result = dict(geometryChecks=55, lifecycleChecks=32, failureCommitChecks=5, discardChecks=19)
    verify_pins(ROOT, HOME / 'SOURCE_PINS.json')
    result = dict(commit=os.environ['GITHUB_SHA'], toolchain=runner.output(['xcrun', 'swiftc', '--version']),
        sourcePinsSHA256=hashlib.sha256((HOME / 'SOURCE_PINS.json').read_bytes()).hexdigest(),
        hostRealPackageFixtures='passed', fixtureResult=fixture_result, negativeCompilerFixtures=negatives,
        unchangedStage83Result=json.loads((out / 'RESULT.json').read_text()), stage75Regressions=stage75_result,
        actualARKitSimulatorCompile='passed', swiftPMBuildSystem=package_runner.BUILD_SYSTEM,
        defaultSwiftBuildBackendPassed=False, appActivation=False, simulatorExecution=False,
        deviceExecution=False, copyLatencyMeasured=False, nativeOriginProven=False, physicalAuthority=False)
    (out / 'STAGE86_RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    sys.dont_write_bytecode = True
    main()
