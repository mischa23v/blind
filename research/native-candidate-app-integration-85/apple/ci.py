#!/usr/bin/env python3
"""Serial actual local-package graph proof and optional compile-only app patch trial.

No simulator launch, installation, signing, runtime opt-in, or geometry capture.
The optional patch is applied only to the disposable exact-commit CI checkout.
"""
import argparse
import hashlib
import importlib.util
import json
import itertools
import os
from pathlib import Path
import platform
import re
import time
import stat
import tempfile

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


SERVICE_CRASH_MARKER = 'unexpected service error: The Xcode build system has crashed. Build again to continue.'


def resource_termination(value):
    text = json.dumps(value).upper()
    if any(marker in text for marker in ('SIGXFSZ', 'SIGXCPU', 'EXC_RESOURCE',
            'FILE SIZE LIMIT', 'CPU TIME LIMIT', 'RESOURCE LIMIT')):
        return True
    if isinstance(value, dict):
        if value.get('resourceLimitObserved') is True:
            return True
        if str(value.get('namespace', '')).upper() == 'SIGNAL' and str(value.get('code')) in ('24', '25'):
            return True # Darwin SIGXCPU / SIGXFSZ, including signal-number-only reports
        return any(resource_termination(v) for v in value.values())
    if isinstance(value, list):
        return any(resource_termination(v) for v in value)
    return False


def service_retry_allowed(receipt, diagnostics, log, log_complete):
    """Exact retry marker is necessary, not sufficient; unknown reports stay unknown."""
    if not (receipt.get('exitCode') == 65 and log_complete and
            not receipt.get('timedOut', True) and not receipt.get('scratchCapExceeded', True) and
            not receipt.get('fileSizeLimitSignal', True) and receipt.get('scratchScanComplete', False) and
            receipt.get('exceptionType') is None and receipt.get('terminationSignal') is None):
        return False
    if resource_termination(diagnostics) or resource_termination(log):
        return False
    marker_lines = 0
    for line in log.splitlines():
        if line.strip() == 'error: ' + SERVICE_CRASH_MARKER:
            marker_lines += 1
        elif re.search(r'\b(?:error|fatal)\b', line, re.IGNORECASE):
            return False # compiler/linker/other error even if the service marker coexists
    return marker_lines == 1


def service_crash_diagnostics(out, label, since):
    """Bounded summaries of this command's build-service crash reports, not raw logs."""
    directory = Path.home() / 'Library/Logs/DiagnosticReports'
    reports = []
    if not directory.is_symlink() and directory.is_dir():
        # macOS may write service reports asynchronously; absence is not no-crash proof.
        candidates = sorted((p for p in itertools.islice(directory.iterdir(), 256) if not p.is_symlink() and p.is_file() and
            p.name.startswith(('XCBBuildService', 'SWBBuildService', 'SwiftBuildService', 'XCBuildService')) and
            p.suffix in ('.ips', '.crash') and p.stat().st_mtime >= since - 5),
            key=lambda p: p.stat().st_mtime, reverse=True)[:6]
        for path in candidates:
            size = path.stat().st_size
            item = dict(name=path.name, bytes=size)
            if size > 2 << 20:
                item['read'] = 'skipped above 2 MiB diagnostic input limit'
            else:
                # O_NOFOLLOW closes the symlink-swap gap between enumeration and read.
                try:
                    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as handle:
                        raw = handle.read((2 << 20) + 1)
                    if len(raw) > 2 << 20:
                        item['read'] = 'grew above 2 MiB diagnostic input limit'
                        reports.append(item)
                        continue
                    value = raw.decode('utf-8', errors='replace')
                except OSError:
                    item['read'] = 'refused or unavailable diagnostic file; no follow'
                    reports.append(item)
                    continue
                if path.suffix == '.ips':
                    try:
                        # IPS normally has a single metadata JSON line then a JSON payload.
                        payload = json.loads(value.split('\n', 1)[1])
                        allowed = {key: payload[key] for key in
                            ('exception', 'termination', 'faultingThread') if key in payload}
                        # Classify structured numeric signals BEFORE display conversion.
                        item['resourceLimitObserved'] = resource_termination(allowed)
                        for key, value in allowed.items():
                            item[key] = str(value)[:4096]
                    except (ValueError, IndexError):
                        item['read'] = 'unparsed IPS; no raw report uploaded'
                else:
                    item['resourceLimitObserved'] = resource_termination(value)
                    item['summary'] = [line[:1024] for line in value.splitlines()
                        if line.startswith(('Exception Type:', 'Exception Codes:',
                            'Termination Reason:', 'Crashed Thread:', 'Process:'))][:8]
            reports.append(item)
    observed_limit = any(item.get('resourceLimitObserved', False) for item in reports)
    result = dict(label=label, diagnosticReports=reports,
        resourceLimitEvidence='observed' if observed_limit else 'unknown; no limit established by available reports',
        scope='first 256 directory entries; recent matching build-service reports only; absence is inconclusive')
    (out / (label + '-diagnostic.json')).write_text(json.dumps(result, indent=2) + '\n')
    return result


def app_build_command(root, out, stem, flag='', planning_only=False):
    command = ['xcodebuild', '-project', str(root / 'ios/BlindAssist.xcodeproj'),
        '-scheme', 'BlindAssist', '-configuration', 'Debug', '-sdk', 'iphonesimulator',
        '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', str(out / stem),
        '-clonedSourcePackagesDirPath', str(out / 'app-source-packages'),
        '-disableAutomaticPackageResolution', '-jobs', '1',
        'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'ARCHS=arm64',
        'ONLY_ACTIVE_ARCH=YES', 'ENABLE_DEBUG_DYLIB=NO', 'SWIFT_OPTIMIZATION_LEVEL=-Onone',
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG' + (' ' + flag if flag else '')]
    if planning_only:
        command.append('-dry-run')
    return command + ['build']


def planning_help_line(text):
    # The installed Apple tool's own help is the primary capability contract.
    lines = [line.strip() for line in text.splitlines()
        if re.match(r'^\s*-dry-run\s+', line)]
    if len(lines) != 1 or 'except' not in lines[0].lower() or 'commands' not in lines[0].lower():
        raise ValueError('installed xcodebuild did not document the expected planning-only option')
    return lines[0]


def planning_capability(runner, out, env):
    runner.run(['xcodebuild', '-help'], 'planning-help', out, 30, env=env)
    path = out / 'planning-help.log'
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as handle:
        raw = handle.read((256 << 10) + 1)
    complete = len(raw) <= 256 << 10
    if complete:
        (out / 'planning-help-bounded.txt').write_bytes(raw)
    text = raw[:256 << 10].decode('utf-8', errors='replace')
    option = None
    reason = 'help output exceeds 256 KiB bound'
    if complete:
        try:
            option = planning_help_line(text)
            reason = 'installed help documents the required planning-only behavior'
        except ValueError as error:
            reason = str(error)
    lines = text.splitlines()
    # Preserve the exact relevant text even on rejection; do not expose environment.
    excerpts = []
    for index, line in enumerate(lines):
        if 'dry-run' in line.lower() or 'dry run' in line.lower():
            excerpts.append(dict(line=index + 1, text='\n'.join(lines[index:index + 3])[:2048]))
            if len(excerpts) == 16:
                break
    result = dict(commit=os.environ.get('GITHUB_SHA'), helpComplete=complete,
        helpSHA256=hashlib.sha256(raw).hexdigest() if complete else None,
        helpBytes=len(raw), optionAccepted=option is not None, acceptedOption=option,
        reason=reason, relevantHelpExcerpts=excerpts,
        fullAppCompiled=False, planningArmsExecuted=0, appExecuted=False)
    (out / 'planning-capability-diagnostic.json').write_text(json.dumps(result, indent=2) + '\n')
    return option


def planning_can_continue(receipt):
    # A second arm is a different graph, never a retry of the failed arm.
    return (not resource_termination(receipt) and receipt.get('exitCode') in (0, 65) and receipt.get('timedOut') is False and
        receipt.get('scratchCapExceeded') is False and receipt.get('scratchScanComplete') is True and
        receipt.get('exceptionType') is None and receipt.get('terminationSignal') is None and
        receipt.get('fileSizeLimitSignal') is False)


def planning_baseline_gate(out, receipt, diagnostics):
    log_path = out / 'planning-baseline.log'
    complete = False
    data = b''
    try:
        with os.fdopen(os.open(log_path, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as handle:
            data = handle.read((4 << 20) + 1)
        complete = len(data) <= 4 << 20
    except OSError:
        pass # missing/unreadable/symlink log is unknown, never permission to continue
    observed_resource = (resource_termination(receipt) or resource_termination(diagnostics) or
        resource_termination(data[:4 << 20].decode('utf-8', errors='replace')))
    allowed = complete and not observed_resource and planning_can_continue(receipt)
    result = dict(secondArmAllowed=allowed, completeBaselineLogInspected=complete,
        inspectedLogBytes=min(len(data), 4 << 20), resourceLimitObserved=observed_resource,
        missingOrIncompleteLogStopsComparison=True)
    (out / 'planning-second-arm-gate-diagnostic.json').write_text(json.dumps(result, indent=2) + '\n')
    return allowed


def capture_proposal_sources(root, relative):
    originals = {}
    for name in relative:
        path = root / name
        with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as handle:
            metadata = os.fstat(handle.fileno())
            assert stat.S_ISREG(metadata.st_mode) and metadata.st_size <= 4 << 20
            data = handle.read((4 << 20) + 1)
            assert len(data) <= 4 << 20
        originals[name] = (data, stat.S_IMODE(metadata.st_mode))
    assert sum(len(data) for data, _ in originals.values()) <= 8 << 20
    return originals


def restore_proposal_sources(root, originals, out):
    # Cleanup only: no compiler/build command, and no limits are changed. The
    # shared runner can report a cap AFTER git already mutated the checkout, so
    # restoration cannot itself depend on that runner's stage-wide cap check.
    errors = []
    for name, (data, mode) in originals.items():
        target = root / name
        temporary = None
        try:
            fd, temporary = tempfile.mkstemp(prefix='.stage85-restore-', dir=target.parent)
            with os.fdopen(fd, 'wb') as handle:
                handle.write(data)
                handle.flush()
                os.fsync(handle.fileno())
                os.fchmod(handle.fileno(), mode)
            os.replace(temporary, target)
            temporary = None
        except OSError as error:
            errors.append(dict(path=name, errorType=type(error).__name__))
        finally:
            if temporary is not None:
                try:
                    os.unlink(temporary) # only the temporary created by this call
                except OSError as error:
                    errors.append(dict(path=name, cleanupErrorType=type(error).__name__))
    verified = {}
    for name, (data, mode) in originals.items():
        try:
            with os.fdopen(os.open(root / name, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as handle:
                actual = handle.read(len(data) + 1)
                metadata = os.fstat(handle.fileno())
            verified[name] = (actual == data and stat.S_IMODE(metadata.st_mode) == mode)
        except OSError:
            verified[name] = False
    result = dict(restored=not errors and all(verified.values()), verified=verified, errors=errors,
        boundedOriginalBytes=sum(len(data) for data, _ in originals.values()),
        scope='three owned proposal files only; atomic same-directory replacement; no build limits changed')
    (out / 'planning-restoration-diagnostic.json').write_text(json.dumps(result, indent=2) + '\n')
    if not result['restored']:
        raise RuntimeError('proposal restoration failed; inspect planning-restoration-diagnostic.json')


def planning_comparison(runner, out, env, patch, option=None):
    if option is None:
        option = planning_capability(runner, out, env)
    if option is None:
        raise ValueError('planning capability not established; inspect capability diagnostic')
    relative = ['ios/BlindAssist/NavigationModel.swift',
        'ios/BlindAssist.xcodeproj/project.pbxproj', 'ios/BlindAssist/MeshCandidateDiagnostics.swift']
    def source_state():
        return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
            if (ROOT / name).exists() else None for name in relative}
    proposed_state = source_state()
    originals = capture_proposal_sources(ROOT, relative)
    results = []
    # The patch was already applied only inside this disposable CI checkout.
    runner.run(['git', '-C', str(ROOT), 'apply', '-R', '--check', str(patch)],
        'planning-baseline-reverse-check', out, 30)
    try:
        runner.run(['git', '-C', str(ROOT), 'apply', '-R', str(patch)],
            'planning-baseline-reverse', out, 30)
        baseline = source_state()
        pins = json.loads((HOME / 'SOURCE_PINS.json').read_text())
        assert baseline[relative[0]] == pins[relative[0]] and baseline[relative[1]] == pins[relative[1]]
        assert baseline[relative[2]] is None, 'baseline retains proposed bridge'
        stem = 'planning-baseline'
        started = time.time()
        baseline_diagnostics = {}
        try:
            receipt = runner.run(app_build_command(ROOT, out, stem, planning_only=True),
                stem, out, 180, env=env)
        except RuntimeError:
            receipt = json.loads((out / (stem + '-receipt.json')).read_text())
            baseline_diagnostics = service_crash_diagnostics(out, stem + '-failure', started)
        results.append(dict(arm='unpatched', sourceHashes=baseline, receipt=receipt))
    finally:
        # Never leave the disposable checkout in a partially reversed state.
        restore_proposal_sources(ROOT, originals, out)
        assert source_state() == proposed_state, 'proposal not byte-identically restored'
    if planning_baseline_gate(out, receipt, baseline_diagnostics):
        stem = 'planning-proposal'
        started = time.time()
        try:
            receipt = runner.run(app_build_command(ROOT, out, stem, planning_only=True),
                stem, out, 180, env=env)
        except RuntimeError:
            receipt = json.loads((out / (stem + '-receipt.json')).read_text())
            service_crash_diagnostics(out, stem + '-failure', started)
        results.append(dict(arm='proposed', sourceHashes=source_state(), receipt=receipt))
    result = dict(commit=os.environ['GITHUB_SHA'], installedPlanningOption=option, arms=results,
        predeclaredSameCommandExceptDerivedDataPath=True, predeclaredSameEnvironmentAndLimits=True,
        bothArmsExecuted=len(results) == 2,
        order='unpatched then proposed; separate fresh derived directories; same runner and dependency checkout',
        automaticRetries=0, fullAppCompiled=False, appExecuted=False, simulatorExecuted=False,
        physicalAuthority=False, scope='build planning only; not compiler, linker or runtime acceptance',
        limitation='fixed order and shared resolved dependency/host caches; not a causal proof of crash mechanism')
    (out / 'PLANNING_COMPARISON.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key:value for key,value in result.items() if key != 'arms'}))
    assert len(results) == 2 and all(planning_can_continue(x['receipt']) and
        x['receipt']['exitCode'] == 0 for x in results), 'planning comparison contains failures; inspect both arm receipts'


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--app-proposal', action='store_true')
    mode.add_argument('--planning-comparison', action='store_true')
    mode.add_argument('--planning-capability', action='store_true')
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
    planning_option = None
    if args.planning_capability or args.planning_comparison:
        planning_option = planning_capability(runner, out, os.environ)
        if args.planning_capability:
            return # metadata probe only; no dependency, graph, patch or app commands
        if planning_option is None:
            raise ValueError('planning capability not established; no graph work started')
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
    if args.app_proposal or args.planning_comparison:
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
        if args.planning_comparison:
            planning_comparison(runner, out, env, patch, planning_option)
            return # never fall through to compilation or symbol checks
        # Retain the inherited 128 MiB per-file cap; a sparse CAS/cache crossing it
        # is a bounded build failure, never app acceptance or runtime-memory proof.
        for flag, stem in [('', 'app-flag-absent'), ('BLIND_MESH_CANDIDATE_DIAGNOSTICS', 'app-flag-enabled')]:
            derived = out / stem
            command = app_build_command(ROOT, out, stem, flag)
            recovered_service_crash = False
            started = time.time()
            try:
                receipts.append(runner.run(command, stem + '-build', out, 600, env=env))
            except RuntimeError:
                diagnostics = service_crash_diagnostics(out, stem + '-first-service-failure', started)
                first = json.loads((out / (stem + '-build-receipt.json')).read_text())
                # Inspect complete bounded log, not only the receipt tail: an earlier
                # compiler error must not disappear behind the final service failure.
                log_path = out / (stem + '-build.log')
                with log_path.open('rb') as handle:
                    log_bytes = handle.read((4 << 20) + 1)
                log_complete = len(log_bytes) <= 4 << 20
                allowed = service_retry_allowed(first, diagnostics,
                    log_bytes[:4 << 20].decode('utf-8', errors='replace'), log_complete)
                (out / (stem + '-retry-decision-diagnostic.json')).write_text(json.dumps(dict(
                    retryAllowed=allowed, completeLogInspected=log_complete,
                    resourceLimitEvidence=diagnostics['resourceLimitEvidence']), indent=2) + '\n')
                if not allowed:
                    raise
                recovered_service_crash = True
                receipts.append(first) # preserve first failed attempt even if retry succeeds
                started = time.time()
                try:
                    receipts.append(runner.run(command, stem + '-build-service-retry', out, 600, env=env))
                except RuntimeError:
                    service_crash_diagnostics(out, stem + '-retry-service-failure', started)
                    raise

            executable = derived / 'Build/Products/Debug-iphonesimulator/BlindAssist.app/BlindAssist'
            assert executable.is_file(), 'expected compile-only product missing'
            receipts.append(runner.run(['xcrun', 'nm', str(executable)], stem + '-symbols', out, 60))
            symbols = (out / (stem + '-symbols.log')).read_text()
            present = 'MeshCandidateDiagnostics' in symbols
            assert present == bool(flag), 'diagnostic bridge symbol compile gate mismatch'
            app_results.append(dict(configuration='Debug', diagnosticFlag=bool(flag),
                                    compiled=True, bridgeSymbolPresent=present,
                                    recoveredAfterServiceCrash=recovered_service_crash))
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
