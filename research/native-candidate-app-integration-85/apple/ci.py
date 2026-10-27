#!/usr/bin/env python3
"""Serial actual local-package graph proof and optional compile-only app patch trial.

No simulator launch, installation, signing, runtime opt-in, or geometry capture.
The optional patch is applied only to the disposable exact-commit CI checkout.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform

HOME = Path(__file__).resolve().parent.parent
ROOT = HOME.parent.parent
BRANCH = 'refs/heads/codex/recovery-hazard-order-20261027'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def verify_pins(base, manifest):
    for name, digest in json.loads(manifest.read_text()).items():
        assert hashlib.sha256((base / name).read_bytes()).hexdigest() == digest, name


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--app-proposal', action='store_true')
    args = parser.parse_args()
    assert platform.system() == 'Darwin', 'Apple host required'
    assert os.environ.get('GITHUB_REPOSITORY') == 'mischa23v/blind'
    assert os.environ.get('GITHUB_REF') == BRANCH
    runner = load('stage75_runner', ROOT / 'research/room-mesh-package-75/apple/ci.py')
    assert runner.output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']) == os.environ['GITHUB_SHA']
    assert not runner.output(['git', '-C', str(ROOT), 'status', '--porcelain']), 'clean disposable checkout required'
    assert runner.output(['xcodebuild', '-version']).splitlines()[0] == 'Xcode 27.0'
    assert runner.output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version']) == '27.0'
    verify_pins(ROOT, HOME / 'SOURCE_PINS.json')
    package75 = ROOT / 'research/room-mesh-package-75'
    verify_pins(package75, package75 / 'APPLE_SOURCE_PINS.json')
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-native-app-integration-85'
    out.mkdir(exist_ok=False)
    (out / 'tmp').mkdir()
    host_sdk = runner.output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'])
    env = runner.package_environment(host_sdk, out)
    package = ROOT / 'research/mesh-candidate-ingress-83'
    native_headers = package75 / 'BlindRoomMesh/Sources/CDetour/include'
    module_names = ['MeshBufferDecoder81', 'MeshSnapshot82', 'MeshCandidateIngress83', 'BlindRoomMesh']
    fixture_result = None
    receipts = []
    for sdk, triple, stem in [('macosx', 'arm64-apple-macosx14.0', 'host'),
                              ('iphonesimulator', 'arm64-apple-ios17.0-simulator', 'simulator')]:
        sdkpath = runner.output(['xcrun', '--sdk', sdk, '--show-sdk-path'])
        build = runner.package_build_command(package, out, stem + '-graph', triple, sdkpath)
        receipts.append(runner.run(build, stem + '-swiftpm-graph', out, 300, env=env))
        bindir = Path(runner.output(build + ['--show-bin-path'], env=env))
        objects = sorted((bindir / 'CDetour.build').rglob('*.o'))
        for name in module_names:
            assert (bindir / 'Modules' / (name + '.swiftmodule')).exists(), name
            module_objects = sorted((bindir / (name + '.build')).glob('*.o'))
            assert module_objects, name
            objects += module_objects
        assert 28 <= len(objects) <= 80, 'unexpected actual dependency object set'
        if stem == 'host':
            client = out / 'host-stage83-fixtures'
            command = ['xcrun', '--sdk', sdk, 'swiftc', '-sdk', sdkpath, '-target', triple,
                '-module-cache-path', str(out / 'host-client-cache'),
                '-I', str(bindir / 'Modules'), '-I', str(native_headers),
                *map(str, objects), '-lc++', str(package / 'tests/main.swift'), '-o', str(client)]
            receipts.append(runner.run(command, 'host-fixtures-link', out, 240, env=env))
            receipts.append(runner.run([str(client)], 'host-fixtures-run', out, 120, env=env))
            fixture_result = [line for line in (out / 'host-fixtures-run.log').read_text().splitlines()
                              if line.startswith('RESULT:')]
            assert len(fixture_result) == 1 and fixture_result[0].startswith(
                'RESULT: 83 stage83 real-runtime synthetic checks passed;')
    app_results = []
    if args.app_proposal:
        patch = HOME / 'app-integration.patch'
        receipts.append(runner.run(['git', '-C', str(ROOT), 'apply', '--check', str(patch)],
                                   'app-patch-check', out, 30))
        receipts.append(runner.run(['git', '-C', str(ROOT), 'apply', str(patch)],
                                   'app-patch-apply', out, 30))
        # The complete existing app needs a larger explicitly scoped scratch allowance.
        # This remains stage-end accounting, NOT a live disk quota or an RSS guarantee.
        runner.SCRATCH_CAP = 2 << 30
        # Clean app checkout has no tracked lockfile. Seed the already-reviewed
        # exact dependency, resolve only from that lock, then verify before build.
        # Do not turn an absent lockfile into an implicit dependency upgrade.
        grdb_revision = 'b83108d10f42680d78f23fe4d4d80fc88dab3212'
        grdb_location = 'https://github.com/groue/GRDB.swift.git'
        resolved = ROOT / 'ios/BlindAssist.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
        assert not resolved.exists(), 'unexpected existing app lockfile; review before replacing'
        resolved.parent.mkdir(parents=True, exist_ok=True)
        expected_pin = dict(identity='grdb.swift', kind='remoteSourceControl',
            location=grdb_location, state=dict(revision=grdb_revision, version='7.11.1'))
        resolved.write_text(json.dumps(dict(pins=[expected_pin], version=2), indent=2) + '\n')
        # Fetch only the reviewed release snapshot, not GRDB's entire history.
        # URL rewriting is scoped to this command environment, never global config.
        seed = out / 'grdb-exact-seed.git'
        receipts.append(runner.run(['git', 'clone', '--bare', '--depth', '1',
            '--single-branch', '--branch', 'v7.11.1', grdb_location, str(seed)],
            'app-exact-dependency-seed', out, 180, env=env))
        assert runner.output(['git', '--git-dir', str(seed), 'rev-parse',
            'refs/tags/v7.11.1^{}']) == grdb_revision, 'release tag changed; refuse resolution'
        assert runner.output(['git', '--git-dir', str(seed), 'rev-parse', 'HEAD']) == grdb_revision
        assert runner.output(['git', '--git-dir', str(seed), 'rev-parse', '--is-shallow-repository']) == 'true'
        env = dict(env)
        config_index = int(env.get('GIT_CONFIG_COUNT', '0'))
        env['GIT_CONFIG_COUNT'] = str(config_index + 1)
        env['GIT_CONFIG_KEY_' + str(config_index)] = 'url.' + seed.as_uri() + '.insteadOf'
        env['GIT_CONFIG_VALUE_' + str(config_index)] = grdb_location
        resolve = ['xcodebuild', '-resolvePackageDependencies',
            '-project', str(ROOT / 'ios/BlindAssist.xcodeproj'), '-scheme', 'BlindAssist',
            '-clonedSourcePackagesDirPath', str(out / 'app-source-packages'),
            '-derivedDataPath', str(out / 'app-resolution'),
            '-onlyUsePackageVersionsFromResolvedFile']
        receipts.append(runner.run(resolve, 'app-exact-dependency-resolve', out, 300, env=env))
        pins = json.loads(resolved.read_text())['pins']
        assert pins == [expected_pin], 'dependency identity/version/revision changed during resolution'
        checkout = out / 'app-source-packages/checkouts/GRDB.swift'
        assert runner.output(['git', '-C', str(checkout), 'rev-parse', 'HEAD']) == grdb_revision
        # Retain the inherited 128 MiB per-file cap; a sparse CAS/cache crossing it
        # is a bounded build failure, never app acceptance or runtime-memory proof.
        for flag, stem in [('', 'app-flag-absent'), ('BLIND_MESH_CANDIDATE_DIAGNOSTICS', 'app-flag-enabled')]:
            derived = out / stem
            command = ['xcodebuild', '-project', str(ROOT / 'ios/BlindAssist.xcodeproj'),
                '-scheme', 'BlindAssist', '-configuration', 'Debug', '-sdk', 'iphonesimulator',
                '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', str(derived),
                '-clonedSourcePackagesDirPath', str(out / 'app-source-packages'),
                '-disableAutomaticPackageResolution', '-jobs', '1',
                'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'ARCHS=arm64',
                'ONLY_ACTIVE_ARCH=YES', 'ENABLE_DEBUG_DYLIB=NO', 'SWIFT_OPTIMIZATION_LEVEL=-Onone',
                'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG' + (' ' + flag if flag else ''), 'build']
            receipts.append(runner.run(command, stem + '-build', out, 600, env=env))
            executable = derived / 'Build/Products/Debug-iphonesimulator/BlindAssist.app/BlindAssist'
            assert executable.is_file(), 'expected compile-only product missing'
            receipts.append(runner.run(['xcrun', 'nm', str(executable)], stem + '-symbols', out, 60))
            symbols = (out / (stem + '-symbols.log')).read_text()
            present = 'MeshCandidateDiagnostics' in symbols
            assert present == bool(flag), 'diagnostic bridge symbol compile gate mismatch'
            app_results.append(dict(configuration='Debug', diagnosticFlag=bool(flag),
                                    compiled=True, bridgeSymbolPresent=present))
    result = dict(commit=os.environ['GITHUB_SHA'],
        toolchain=runner.output(['xcrun', 'swiftc', '--version']),
        swiftPMBuildSystem=runner.BUILD_SYSTEM, defaultSwiftBuildBackendPassed=False,
        actualLocalPackageGraphHost='passed', actualLocalPackageGraphSimulator='passed',
        fixtureResult=fixture_result, appProposalCompile=app_results,
        appProposalApplied=args.app_proposal,
        appDependencyResolution='exact verified shallow seed' if args.app_proposal else 'not run',
        appExecuted=False, simulatorExecuted=False,
        runtimeOptInChanged=False, nativeCopyLatencyMeasured=False, deviceAcceptance='not run')
    (out / 'RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
