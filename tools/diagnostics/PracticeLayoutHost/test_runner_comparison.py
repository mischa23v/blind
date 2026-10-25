"""Synthetic orchestration witness; does not claim Apple compilation/runtime."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

FAKE = r'''
import json, os
from pathlib import Path
import sys
a=sys.argv[1:]
root=Path(os.environ['FAKE_ROOT'])
with (root/'commands.jsonl').open('a') as f: f.write(json.dumps([Path(sys.argv[0]).name]+a)+'\n')
if Path(sys.argv[0]).name=='xcodebuild':
    if a==['-version']: print('Xcode synthetic'); sys.exit(0)
    if 'build-for-testing' in a: sys.exit(int(os.environ.get('FAKE_BUILD_FAIL','0')))
    result=Path(a[a.index('-resultBundlePath')+1]); result.mkdir()
    name=next(v for v in a if v.startswith('-only-testing:')).rsplit('/',1)[1]
    print('COMPARISON synthetic case='+name)
    if os.environ.get('FAKE_LARGE_LOGS'):
        for i in range(100): print('COMPARISON issue '+str(i)+' '+chr(0x4e00)*3000)
    sys.exit(65 if name=='testB_HitRegion_1' else 0)
if a[:2]==['--sdk','iphonesimulator']: print('27.0-synthetic')
elif a[:3]==['simctl','list','devicetypes']: print(json.dumps({'devicetypes':[{'name':'iPhone 18 Pro Max','identifier':'synthetic-phone'}]}))
elif a[:2]==['simctl','create']: print('01234567-1234-1234-1234-0123456789AB')
elif a[:2]==['simctl','ui']:
    p=root/'category'
    if len(a)==5: p.write_text(a[-1])
    else: print(p.read_text())
elif a[:3]==['xcresulttool','export','attachments']:
    result=Path(a[a.index('--path')+1]); dest=Path(a[a.index('--output-path')+1]); dest.mkdir()
    name=result.stem; parts=name.split('_'); variant=parts[0][-1]
    kind={'DynamicType':'dynamicType','HitRegion':'hitRegion','Endpoint':'endpoint'}[parts[1]]
    prefix='comparison-'+variant+'-'+kind+('-'+parts[2] if len(parts)==3 else '')
    entries=[]
    for role in ['before','after']:
        filename=role+'.png'; (dest/filename).write_bytes(b'\x89PNG\r\n\x1a\nfixture')
        entries.append({'suggestedHumanReadableName':prefix+'-'+role+'_1_FAKE.png','exportedFileName':filename})
    (dest/'manifest.json').write_text(json.dumps([{'attachments':entries}]))
elif a[:2]==['simctl','delete']: sys.exit(int(os.environ.get('FAKE_DELETE_FAIL','0')))
'''


class RunnerTests(unittest.TestCase):
    def run_fake(self, **overrides):
        tmp = tempfile.TemporaryDirectory(); self.addCleanup(tmp.cleanup)
        root = Path(tmp.name); bindir = root / 'bin'; bindir.mkdir()
        for name in ('xcodebuild', 'xcrun'):
            p = bindir / name; p.write_text('#!' + sys.executable + '\n' + FAKE); p.chmod(0o755)
        env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ['PATH'],
                   RUNNER_TEMP=str(root), FAKE_ROOT=str(root), **overrides)
        result = subprocess.run([sys.executable, str(Path(__file__).with_name('run_comparison.py'))],
                                env=env, capture_output=True, text=True, timeout=30)
        summary = json.loads((root / 'blind-practice-comparison/artifacts/outcomes.json').read_text())
        commands = [json.loads(line) for line in (root / 'commands.jsonl').read_text().splitlines()]
        return result, summary, commands

    def test_failure_retained_and_all_fifteen_executed_once(self):
        result, summary, commands = self.run_fake()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(summary['screenshotCount'], 30)
        self.assertEqual(summary['cleanup'], 'passed')
        self.assertEqual(sum(c['status'] == 'native_failed' for c in summary['cases']), 1)
        self.assertTrue(all(c['evidence'] == 'complete' for c in summary['cases']))
        self.assertEqual(sum('build-for-testing' in c for c in commands), 1)
        self.assertEqual(sum('test-without-building' in c for c in commands), 15)

    def test_build_failure_has_fifteen_explicit_nonruns_and_cleanup(self):
        result, summary, commands = self.run_fake(FAKE_BUILD_FAIL='65')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(summary['build'], 'failed')
        self.assertEqual(summary['cleanup'], 'passed')
        self.assertTrue(all(c['status'] == 'infrastructure_not_run' for c in summary['cases']))
        self.assertFalse(any('test-without-building' in c for c in commands))

    def test_cleanup_failure_visible(self):
        result, summary, _ = self.run_fake(FAKE_DELETE_FAIL='1')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(summary['cleanup'], 'failed')

    def test_serialized_summary_bounds_and_explicit_truncation(self):
        result, summary, _ = self.run_fake(FAKE_LARGE_LOGS='1')
        self.assertEqual(result.returncode, 1)
        self.assertLessEqual(len(json.dumps(summary, indent=2).encode('utf-8')), 4 * 1024 * 1024)
        for case in summary['cases']:
            logs = case['logSummary']
            self.assertLessEqual(len(json.dumps(logs, indent=2).encode('utf-8')), 192 * 1024)
            self.assertGreater(logs['omittedMatchedLines'], 0)
            self.assertTrue(any('COMPARISON issue ' in line for line in logs['lines']))


if __name__ == '__main__':
    unittest.main()
