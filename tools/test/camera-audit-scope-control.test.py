"""Synthetic orchestration witnesses, not native audit acceptance."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

FAKE = r'''
import json,os
from pathlib import Path
import sys
a=sys.argv[1:]; root=Path(os.environ['FAKE_ROOT'])
with (root/'commands.jsonl').open('a') as f: f.write(json.dumps([Path(sys.argv[0]).name]+a)+'\n')
if Path(sys.argv[0]).name=='xcodebuild':
    if a==['-version']: print('Xcode synthetic'); sys.exit(0)
    if 'build-for-testing' in a: sys.exit(int(os.environ.get('FAKE_BUILD_FAIL','0')))
    assert os.environ.get('TEST_RUNNER_BLIND_AUDIT_SCOPE_CONTROL')=='1'
    result=Path(a[a.index('-resultBundlePath')+1]); result.mkdir()
    print('ACCESSIBILITY_AUDIT=synthetic retained outcome')
    if not os.environ.get('FAKE_MISSING_GEOMETRY'):
        print('ACCESSIBILITY_AUDIT_READINESS phase=camera titleReady=true controlReady=true')
        print('ACCESSIBILITY_AUDIT_EVIDENCE phase=camera point=before category=UICTContentSizeCategoryL window=(0,0,440,956)')
        for role in ['practice','practice-header','practice-footer']:
            frame='(20,400,400,52)' if not(os.environ.get('FAKE_MISMATCH') and result.stem!='original-all') else '(20,401,400,52)'
            print('ACCESSIBILITY_AUDIT_FRAME phase=camera point=before role='+role+' exists=true frame='+frame+' hittable=true')
    sys.exit(65 if result.stem=='original-all' and not os.environ.get('FAKE_ALL_PASS') else 0)
if a[:2]==['--sdk','iphonesimulator']: print('27.1' if os.environ.get('FAKE_WRONG_SDK') else '27.0')
elif a[:3]==['simctl','list','devicetypes']: print(json.dumps({'devicetypes':[{'name':'iPhone 18 Pro Max','identifier':'fake-phone'}]}))
elif a[:2]==['simctl','create']: print('01234567-1234-1234-1234-0123456789AB')
elif a[:2]==['simctl','ui']:
    if len(a)==4: print('extra-large' if os.environ.get('FAKE_WRONG_SIZE') else 'large')
elif a[:3]==['xcresulttool','export','attachments']:
    name=Path(a[a.index('--path')+1]).stem
    dest=Path(a[a.index('--output-path')+1]); dest.mkdir()
    roles=['camera-before','camera-after']+(['ask-before','ask-after'] if name=='original-all' else [])
    if os.environ.get('FAKE_MISSING_AFTER') and name=='original-all': roles=['camera-before']
    records=[]
    for role in roles:
        p=dest/(role+'.png'); p.write_bytes(b'\x89PNG\r\n\x1a\nfixture')
        records.append({'suggestedHumanReadableName':'full-audit-'+role+'_1_FAKE.png','exportedFileName':p.name})
    (dest/'manifest.json').write_text(json.dumps([{'attachments':records}]))
elif a[:2]==['simctl','delete']: sys.exit(int(os.environ.get('FAKE_DELETE_FAIL','0')))
'''


class ScopeTests(unittest.TestCase):
    def run_fake(self, **overrides):
        tmp = tempfile.TemporaryDirectory(); self.addCleanup(tmp.cleanup)
        root = Path(tmp.name); bin_dir = root / 'bin'; bin_dir.mkdir()
        ci = root / 'tools/ci'; ci.mkdir(parents=True)
        source_ci = Path(__file__).parents[1] / 'ci'
        for name in ('camera-audit-scope-control.py', 'export-full-audit-evidence.py'):
            shutil.copyfile(source_ci / name, ci / name)
        for name in ('xcrun', 'xcodebuild'):
            p = bin_dir / name; p.write_text('#!' + sys.executable + '\n' + FAKE); p.chmod(0o755)
        env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ['PATH'],
                   RUNNER_TEMP=str(root), FAKE_ROOT=str(root), **overrides)
        run = subprocess.run([sys.executable, str(ci / 'camera-audit-scope-control.py')],
                             env=env, capture_output=True, text=True, timeout=30)
        summary = json.loads((root / 'blind-camera-audit-scope-control/artifacts/outcomes.json').read_text())
        commands = [json.loads(line) for line in (root / 'commands.jsonl').read_text().splitlines()]
        return run, summary, commands

    def test_original_failure_retained_then_typed_runs_once(self):
        run, summary, commands = self.run_fake()
        self.assertEqual(run.returncode, 1, run.stderr)
        self.assertEqual([c['nativeExitCode'] for c in summary['cases']], [65, 0])
        self.assertTrue(all(c['evidence'] == 'complete' for c in summary['cases']))
        self.assertEqual(summary['screenshotCount'], 6)
        self.assertEqual(summary['beforeCameraComparison']['status'], 'matched')
        self.assertEqual(sum('build-for-testing' in c for c in commands), 1)
        tests = [c for c in commands if 'test-without-building' in c]
        self.assertEqual(len(tests), 2)
        self.assertIn('-only-testing:BlindAssistUITests/LaunchTests/testAccessibilityAuditOfCameraAndAsk', tests[0])
        self.assertIn('-only-testing:BlindAssistUITests/CameraAuditScopeTests/testCameraDynamicTypeOnly', tests[1])
        self.assertEqual(sum(c[:3] == ['xcrun','simctl','delete'] for c in commands), 1)
        self.assertEqual(sum(c[:3] == ['xcrun','simctl','ui'] and c[-1] == 'large' for c in commands), 2)

    def test_missing_after_keeps_before_and_does_not_stop_second_case(self):
        run, summary, _ = self.run_fake(FAKE_MISSING_AFTER='1')
        self.assertEqual(run.returncode, 1)
        self.assertEqual(summary['cases'][0]['evidence'], 'failed')
        self.assertEqual(summary['cases'][0]['screenshots'], ['full-audit-camera-before.png'])
        self.assertEqual(summary['cases'][1]['status'], 'passed')
        self.assertEqual(summary['screenshotCount'], 3)
        self.assertEqual(summary['beforeCameraComparison']['status'], 'matched')

    def test_build_failure_records_both_not_run_and_cleanup(self):
        run, summary, commands = self.run_fake(FAKE_BUILD_FAIL='65')
        self.assertEqual(run.returncode, 1)
        self.assertEqual(summary['cleanup'], 'passed')
        self.assertTrue(all(c['status'] == 'infrastructure_not_run' for c in summary['cases']))
        self.assertFalse(any('test-without-building' in c for c in commands))

    def test_cleanup_failure_visible(self):
        run, summary, _ = self.run_fake(FAKE_DELETE_FAIL='1')
        self.assertEqual(run.returncode, 1); self.assertEqual(summary['cleanup'], 'failed')

    def test_large_verification_failure_prevents_native_test(self):
        run, summary, commands = self.run_fake(FAKE_WRONG_SIZE='1')
        self.assertEqual(run.returncode, 1)
        self.assertTrue(all(c['status'] == 'infrastructure_failed' for c in summary['cases']))
        self.assertFalse(any('test-without-building' in c for c in commands))

    def test_geometry_mismatch_is_inconclusive(self):
        run, summary, _ = self.run_fake(FAKE_MISMATCH='1', FAKE_ALL_PASS='1')
        self.assertEqual(run.returncode, 1)
        self.assertTrue(all(case['status'] == 'passed' for case in summary['cases']))
        self.assertEqual(summary['result'], 'failed')
        self.assertEqual(summary['beforeCameraComparison']['status'], 'inconclusive')
        self.assertEqual(summary['beforeCameraComparison']['reason'], 'before_geometry_mismatch')

    def test_missing_geometry_is_inconclusive(self):
        run, summary, _ = self.run_fake(FAKE_MISSING_GEOMETRY='1', FAKE_ALL_PASS='1')
        self.assertEqual(run.returncode, 1)
        self.assertTrue(all(case['status'] == 'passed' for case in summary['cases']))
        self.assertEqual(summary['result'], 'failed')
        self.assertEqual(summary['beforeCameraComparison']['status'], 'inconclusive')
        self.assertEqual(summary['beforeCameraComparison']['reason'], 'missing_or_nonlarge_before_geometry')

    def test_wrong_sdk_stops_before_build_and_simulator_creation(self):
        run, summary, commands = self.run_fake(FAKE_WRONG_SDK='1')
        self.assertEqual(run.returncode, 1)
        self.assertEqual(summary['simulatorSDKVersion'], '27.1')
        self.assertEqual(summary['cleanup'], 'no_owned_simulator')
        self.assertFalse(any('build-for-testing' in c for c in commands))
        self.assertFalse(any(c[:3] == ['xcrun','simctl','create'] for c in commands))


if __name__ == '__main__': unittest.main()
