#!/usr/bin/env python3
"""Exact-source/static contracts only. Never Swift compilation or native evidence."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import yaml

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
BASE = ROOT / 'research/mesh-candidate-ingress-83'


def main():
    checks = []

    def check(name, value):
        assert value, name
        checks.append(name)

    def pins(base, manifest, label):
        entries = json.loads(manifest.read_text())
        for name, digest in entries.items():
            check(label + ': ' + name, hashlib.sha256((base / name).read_bytes()).hexdigest() == digest)
        return len(entries)

    for path in [Path(__file__), HERE / 'apple/ci.py', HERE / 'tests/test_diagnostics.py']:
        ast.parse(path.read_text())
        checks.append('Python syntax: ' + str(path.relative_to(HERE)))
    source_pins = pins(ROOT, HERE / 'SOURCE_PINS.json', 'stage86 source hash')
    stage83_pins = pins(ROOT, BASE / 'SOURCE_PINS.json', 'unchanged stage83 pin')
    package_home = ROOT / 'research/room-mesh-package-75'
    native_pins = pins(package_home, package_home / 'APPLE_SOURCE_PINS.json', 'actual stage75 native pin')
    baseline = json.loads(subprocess.check_output([sys.executable, '-B', str(BASE / 'check_static.py')],
                                                 text=True, timeout=30))
    check('unchanged stage83 static checker passed 42', baseline['staticChecksPassed'] == 42)

    source = (HERE / 'Sources/OriginBoundMeshIngress.swift').read_text()
    adapter = (HERE / 'Sources/ARKitIngress.swift').read_text()
    tests = (HERE / 'tests/main.swift').read_text()
    lease_class = re.search(r'public final class ProducerLease \{(.*?)\n    \}', source, re.S)
    check('opaque immutable final lease with only inaccessible initializer',
          lease_class is not None and lease_class[1].strip() == 'fileprivate init() {}')
    check('constructor closed', 'private var stopped = true, copies = 0' in source)
    check('active lease private with no getter', 'private var activeLease: ProducerLease?' in source and
          not re.search(r'(?:public|internal) (?:var|let|func) \w*[Ll]ease', source))
    check('only reset issues a lease', source.count('ProducerLease()') == 1 and
          source.index('public func reset() throws -> ProducerLease') < source.index('let issued = ProducerLease()'))
    admission = source.split('private func admit(', 1)[1].split('    /// Call on', 1)[0]
    guard = 'guard let activeLease, activeLease === lease, !stopped else { return nil }'
    check('lease identity guard before every admission mutation', all(
        admission.index(guard) < admission.index(marker)
        for marker in ['advance()', 'time.isFinite', 'receipt = time', 'revisions[anchor] =', 'gap()']))
    check('only explicit leased custom ingest', len(re.findall(r'public func ingest\(', source)) == 1 and
          'public func ingest(lease: ProducerLease, anchorID: UUID' in source)
    check('only explicit leased removal', len(re.findall(r'public func remove\(', source)) == 1 and
          'public func remove(lease: ProducerLease, anchorID: UUID' in source)
    check('admission happens under shared lock in both paths',
          'let context: MeshSnapshot82.Context? = locked {\n            guard let c = admit(lease' in source and
          'locked {\n            guard let c = admit(lease, anchorID, receiptUptime) else { return false }' in source)
    check('reservation before synchronous copy', source.index('copies += 1') < source.index('OwnedCopy(capture(context))'))
    check('no early aggregate reservation release', source.count('copies -= 1') == 1 and
          source.index('owned.value = nil') < source.index('copies -= 1') and 'copies = 0' not in source.split('public func reset()', 1)[1])
    check('stop and terminal discard revoke leases',
          'public func stop() { locked { activeLease = nil;' in source and 'discarding = true; activeLease = nil;' in source)
    reset = source.split('public func reset() throws -> ProducerLease', 1)[1].split('public func isCurrent', 1)[0]
    check('failed reset stays closed and successful reset alone opens',
          reset.index('activeLease = nil; stopped = true') < reset.index('try runtime.reset(') <
          reset.index('let issued = ProducerLease()') < reset.index('activeLease = issued; stopped = false'))
    check('terminal reset prohibited', 'guard !discarding, advance()' in reset)
    check('predecode and install exact fences retained', source.count('epoch == context.sessionID') >= 2 and
          source.count('revisions[anchorID] == context.revision') >= 2)
    check('one existing runtime and one gap invalidation site', source.count('RoomMeshCandidateRuntime(sessionID:') == 1 and
          source.count('runtime.invalidate()') == 1)
    check('strict receipt order retained', 'time.isFinite, time >= 0, time > receipt' in source)
    check('terminal drain handshake retained', 'runtimeDiscarded, copies == 0' in source)
    check('no native pointers, session, planner or persistence in lease owner', all(
        marker not in source for marker in ['UnsafeRawPointer', 'import ARKit', 'MTLBuffer', 'ARSession()', 'FileManager', 'URLSession']))
    check('candidate remains without physical authority', 'public var physicalAuthority: Bool { false }' in source and
          'public var coverageKnown: Bool { false }' in source)
    check('ARKit seam forwards explicit lease before capture',
          'ingest(_ anchor: ARMeshAnchor, lease: ProducerLease' in adapter and
          adapter.index('ingest(lease: lease, anchorID:') < adapter.index('ARKitMeshAdapter82.capture('))
    for cap in ['200_000', '100_000', '16_000_000', '8_000_000']:
        check('unchanged ARKit logical cap ' + cap, cap in adapter)
    for marker in [
        'constructor is closed', 'discard before first reset prohibits any lease issuance',
        'stop revokes A before copy', 'delayed old add rejected at actual API',
        'delayed old update rejected at actual API', 'delayed old removal rejected at actual API',
        'rejected old add cannot retire B candidate', 'rejected old removal cannot delete or retire B',
        'old updates did not advance current revision', 'old high receipts did not poison B ordering',
        'old add did not consume revision or anchor slot', 'rejected leases did not introduce sticky gap',
        'current exact removal still reaches real runtime', 'equal current receipt rejected without invented epsilon',
        'reset issues distinct immutable capability despite semantic ABA', 'original A never revives in A-label run',
        'new lease cannot bypass old aggregate reservation', 'old admitted floor did not install in B',
        'late old gap cannot contaminate current epoch', 'terminal reset rejected before drain',
        'terminal rejects every issued lease before copy', 'terminal acknowledgement follows real reservation drain',
        'duplicate discard callers acknowledged exactly once', 'late owned capture released before acknowledgement',
        'all rejected-origin or capacity callbacks avoided capture']:
        check('fixture authored: ' + marker, marker in tests)
    check('deliberate mutable-global misuse is required ACCEPTANCE',
          'var globalLease = try misuse.reset()' in tests and 'ingest(lease: globalLease' in tests and
          'check(testKnownOldCallback(), "API cannot detect old native event rebound to new global lease")' in tests)
    check('fixture uses actual public owner; no replacement state machine',
          'import OriginBoundMeshIngress86' in tests and '@testable import MeshSnapshot82' in tests and
          '@testable import OriginBoundMeshIngress86' not in tests and 'class OriginBoundMeshIngress86' not in tests)
    check('ordering does not use sleeps or fake timestamps', 'sleep(' not in tests and 'epsilon' not in adapter)

    harness = (HERE / 'apple/ci.py').read_text()
    check('inert runner requires explicit authorized opt-in',
          "if not args.execute_authorized_apple:" in harness and "parser.error('inert by default" in harness)
    inert = subprocess.run([sys.executable, '-B', str(HERE / 'apple/ci.py')],
                           capture_output=True, text=True, timeout=10)
    check('default runner invocation actually refuses before any build',
          inert.returncode == 2 and 'inert by default' in inert.stderr and not inert.stdout)
    check('unchanged stage83 harness and real native products reused',
          'stage83.main()' in harness and 'package_runner.package_build_command(' in harness and
          "build + ['--show-bin-path']" in harness and 'package_runner.run(build' not in harness)
    check('one shared scratch accounting tree',
          "out = Path(os.environ['RUNNER_TEMP']) / 'blind-mesh-candidate-ingress-83'" in harness)
    check('actual simulator ARKit source included', "sources.append(HOME / 'Sources/ARKitIngress.swift')" in harness)
    check('negative source checked after positive signatures',
          harness.index("'stage86-host-public-signatures'") < harness.index('expected_failure=True'))
    check('negative compile failures must match relevant diagnostics',
          'assert expected_rejection(filename, tail)' in harness and len(list((HERE / 'tests').glob('*-must-not-compile.swift'))) == 4)
    diagnostics = json.loads(subprocess.check_output(
        [sys.executable, '-B', str(HERE / 'tests/test_diagnostics.py')], text=True, timeout=10))
    check('synthetic diagnostic parser accepts both initializer forms and rejects unrelated errors',
          diagnostics['diagnosticParserChecksPassed'] == 16 and diagnostics['syntheticDiagnosticsOnly'] is True)
    check('observed fixture result required; no authored pass count',
          "fixture_log.splitlines()" in harness and 'missing actual fixture completion result' in harness)
    check('stage75 failures and discard regressions remain required',
          "len(lifecycle['failureCommitChecks']) == 5" in harness and "len(lifecycle['discardChecks']) == 19" in harness)
    proposal = HERE / 'apple/workflow-proposal.yml'
    workflow = yaml.load(proposal.read_text(), Loader=yaml.BaseLoader)
    check('workflow read-only token', workflow['permissions'] == {'contents': 'read'})
    check('workflow triggers limited to guarded push and dispatch', set(workflow['on']) == {'push', 'workflow_dispatch'} and
          workflow['on']['push']['branches'] == ['codex/recovery-hazard-order-20261027'])
    check('workflow push paths limited to proposal and actual dependencies', workflow['on']['push']['paths'] == [
          'research/origin-bound-ingress-proposal-86/**', 'research/mesh-candidate-ingress-83/**',
          'research/native-mesh-decoder-81/**', 'research/arkit-mesh-adapter-82/**',
          'research/room-mesh-package-75/**', '.github/workflows/origin-bound-ingress-proposal-86.yml'])
    check('workflow has one isolated job', set(workflow['jobs']) == {'proposal'})
    job = workflow['jobs']['proposal']
    check('workflow exact public repository and branch guard', job['if'] ==
          "github.repository == 'mischa23v/blind' && github.event.repository.private == false && github.ref == 'refs/heads/codex/recovery-hazard-order-20261027'")
    check('workflow fixed Apple toolchain and 25-minute outer cap', job['runs-on'] == 'xcode-27' and
          job['timeout-minutes'] == '25' and job['env'] == {'DEVELOPER_DIR': '/Applications/Xcode_27.0.app/Contents/Developer'})
    check('workflow has no services or secondary execution surface',
          set(job) == {'if', 'runs-on', 'timeout-minutes', 'env', 'steps'} and
          set(workflow) == {'name', 'on', 'permissions', 'concurrency', 'jobs'})
    steps = job['steps']
    check('workflow exactly checkout, isolated run, bounded upload', len(steps) == 3)
    checkout, run, upload = steps
    check('workflow checkout pinned and credentials disabled',
          checkout['uses'] == 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1' and
          checkout['with'] == {'persist-credentials': 'false', 'fetch-depth': '1', 'lfs': 'false', 'submodules': 'false'})
    check('workflow 23-minute execution explicitly opts into authorized runner', run['timeout-minutes'] == '23' and
          run['run'] == 'python3 -B research/origin-bound-ingress-proposal-86/apple/ci.py --execute-authorized-apple')
    check('workflow upload pinned and retained on failure',
          upload['uses'] == 'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02' and upload['if'] == 'always()')
    expected_uploads = ['${{ runner.temp }}/blind-mesh-candidate-ingress-83/' + name for name in [
        '*-receipt.json', 'RESULT.json', 'STAGE86_RESULT.json',
        'stage86-stage75/RESULT.json', 'stage86-stage75/RUNTIME_RESULT.json']]
    check('artifact allowlist excludes input geometry, arbitrary logs and caches',
          upload['with']['path'].splitlines() == expected_uploads and
          upload['with']['retention-days'] == '3' and upload['with']['if-no-files-found'] == 'warn')
    installed = ROOT / '.github/workflows/origin-bound-ingress-proposal-86.yml'
    check('installed workflow absent or exact reviewed proposal copy',
          not installed.exists() or installed.read_bytes() == proposal.read_bytes())
    check('no other workflow silently activates stage86', all(
        p == installed or 'origin-bound-ingress-proposal-86' not in p.read_text()
        for p in (ROOT / '.github/workflows').glob('*.yml')))
    historical = HERE / 'history/pre-apple-workflow-20261027'
    check('pre-workflow source-review manifest preserved exactly',
          hashlib.sha256((historical / 'SOURCE_PINS.json').read_bytes()).hexdigest() ==
          '39a6a8788d8ed42cac850dd07660bc900211ecf01e8280ec2afe6ddd44a725d3')
    check('pre-workflow authored-unrun source-review receipt preserved exactly',
          hashlib.sha256((historical / 'STATIC_RESULT.json').read_bytes()).hexdigest() ==
          'f497a7caae757bea2c245d6d332b3600d2c764e7dfd51e5b7142ae0488981fa8')

    expected_diff = ''
    for old, new in [('Sources/MeshCandidateIngress.swift', 'Sources/OriginBoundMeshIngress.swift'),
                     ('Sources/ARKitIngress.swift', 'Sources/ARKitIngress.swift'), ('Package.swift', 'Package.swift')]:
        expected_diff += ''.join(difflib.unified_diff((BASE / old).read_text().splitlines(keepends=True),
            (HERE / new).read_text().splitlines(keepends=True), fromfile='stage83/' + old,
            tofile='stage86-proposal/' + new))
    check('complete owner/adapter/manifest review diff exact',
          (HERE / 'stage83-to-stage86-review.diff').read_text() == expected_diff)
    bridge = (ROOT / 'ios/BlindAssist/MeshCandidateDiagnostics.swift').read_text()
    check('adopted bridge remains flag-fenced default-off no-copy',
          bridge.startswith('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS') and
          'private(set) var enabled = false' in bridge and '.ingest(' not in bridge and
          'owner?.stop() // refuse stale candidate state' in bridge)
    check('proposal not imported or referenced by app', all('OriginBoundMeshIngress86' not in path.read_text() and
          'origin-bound-ingress-proposal-86' not in path.read_text() for path in
          [*(ROOT / 'ios/BlindAssist').rglob('*.swift'), ROOT / 'ios/BlindAssist.xcodeproj/project.pbxproj']))

    audit = json.loads((ROOT / 'research/live-mesh-callback-ownership-audit-20261027/SOURCE_PINS.json').read_text())
    mismatches = [dict(path=name, auditedSHA256=digest, currentSHA256=hashlib.sha256((ROOT / name).read_bytes()).hexdigest())
                  for name, digest in audit.items() if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest]
    receipt = json.loads((HERE / 'AUDIT_RECHECK.json').read_text())
    check('historical audit mismatch is preserved, never repinned green',
          receipt['auditCheckerPassed'] is False and receipt['mismatches'] == mismatches and
          len(mismatches) == 1 and mismatches[0]['path'] == 'ios/BlindAssist/NavigationModel.swift')
    check('historical audit counts are exact', receipt['matchedAuditPins'] == len(audit) - len(mismatches) and
          receipt['auditPinCount'] == len(audit))
    print(json.dumps(dict(staticChecksPassed=len(checks), checks=checks, sourcePinsMatched=source_pins,
        unchangedStage83PinsMatched=stage83_pins, nativeStage75PinsMatched=native_pins,
        unchangedStage83StaticChecksPassed=baseline['staticChecksPassed'],
        syntheticDiagnosticParserChecksPassed=diagnostics['diagnosticParserChecksPassed'], historicalAuditCheckerPassed=False,
        historicalAuditMismatches=mismatches, workflowProposalAuthored=True, workflowInstalled=installed.exists(),
        workflowLaunchedByThisCheck=False, swiftCompiled=False, swiftExecuted=False, appleHarnessExecuted=False,
        appChangedByProposal=False, appActivation=False, nativeOriginProven=False, physicalAuthority=False), indent=2))


if __name__ == '__main__':
    main()
