#!/usr/bin/env python3
"""Bounded source/receipt contracts, not Swift compilation or native timing proof."""
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RUNTIME = ROOT / 'research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift'
TEST = ROOT / 'ios/BlindAssistTests/ClassifiedRoomMeshTests.swift'
HELPER = ROOT / 'tools/ci/native-apple.sh'
INTEGRATED = ROOT / 'research/native-candidate-app-integration-85/integrated'
STAGES = ('requestEnqueued', 'workerStarted', 'nativeBuildBegin', 'nativeBuildEnd',
          'routeBegin', 'routeEnd', 'nativeFailure', 'completionQueued', 'completionDelivered',
          'discardRequested', 'discardWorkerStarted', 'discardReleased', 'discardCompletionDelivered')

def release(source):
    result, active, stack = [], True, []
    for line in source.splitlines():
        if line.strip() == '#if DEBUG':
            stack.append(active); active = False
        elif line.strip() == '#else':
            active = stack[-1] and not active
        elif line.strip() == '#endif':
            active = stack.pop()
        elif active:
            result.append(line)
    assert not stack
    return '\n'.join(result)

def tokens(source):
    # Keep string contents/operators, ignore comments, whitespace and redundant
    # semicolon separators. This is a lexical source comparison, not a compiler.
    pattern = r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/|[A-Za-z_]\w*|\d+(?:\.\d+)?|[^\s;]'
    return [x for x in re.findall(pattern, source) if not x.startswith(('//', '/*'))]

class Contracts(unittest.TestCase):
    def test_release_runtime_tokens_unchanged(self):
        self.assertEqual(tokens(release(RUNTIME.read_text())), tokens((HERE / 'RoomMeshCandidate.swift.before').read_text()))

    def test_debug_opt_in_is_bounded_and_content_free(self):
        source = RUNTIME.read_text()
        block = source.split('#if DEBUG', 1)[1].split('#endif', 1)[0]
        self.assertIn('captureSyntheticTestTiming: Bool', block)
        self.assertIn('if captureSyntheticTestTiming {', block)
        self.assertIn('diagnosticReceipts.count<64', block)
        self.assertIn('ProcessInfo.processInfo.systemUptime', block)
        self.assertNotRegex(release(source), r'diagnosticReceipts|diagnosticStartedAt|diagnosticReceiptID|recordDiagnosticStage|DiagnosticStageReceipt')
        self.assertNotRegex(block, r'print\(|vertices|triangles|anchorID|sessionID\s*\+')
        for stage in STAGES:
            self.assertRegex(source, r'(?:recordDiagnosticStage|diagnostic)\(\.' + stage + r'\)')
        self.assertIn('return { [weak self] stage in self?.recordDiagnosticStage(stage) }', source)
        self.assertIn('guard diagnosticStartedAt != nil else{return { _ in }}', source)
        self.assertNotIn('self.recordDiagnosticStage', source)

    def test_deadlines_remain_ten_seconds(self):
        before = (HERE / 'ClassifiedRoomMeshTests.swift.before').read_text()
        source = TEST.read_text()
        self.assertEqual(re.findall(r'fulfillment\(of: \[done\], timeout: (\d+)\)', source), ['10', '10'])
        self.assertEqual(source.count('await fulfillment('), before.count('await fulfillment('))
        self.assertNotRegex(source, r'Task\.sleep|Thread\.sleep|retry|timeout:\s*(?:20|30|60)')

    def test_only_synthetic_tests_opt_in(self):
        source = TEST.read_text()
        self.assertEqual(source.count('let runtime = try makeRuntime('), 5)
        self.assertIn('captureSyntheticTestTiming: true', source)
        self.assertNotIn('captureSyntheticTestTiming', release(source))
        self.assertIn('stage.rawValue', source)
        self.assertIn('elapsedMilliseconds', source)
        self.assertNotIn('String(describing:', source)

    def test_helper_only_adds_receipt_extraction(self):
        source = HELPER.read_text()
        start = source.index('    # Synthetic test-only receipt:')
        end = source.index("    echo 'CLASSIFIED_QUERY_STAGE_TIMING_END'", start) + len("    echo 'CLASSIFIED_QUERY_STAGE_TIMING_END'")
        inverse = source[:start] + source[end + 1:]
        self.assertEqual(inverse.rstrip(), (HERE / 'native-apple.sh.before').read_text().rstrip())
        self.assertLess(start, source.index('if (( status != 0 )); then'))
        subprocess.run(['bash', '-n', str(HELPER)], check=True)

    def test_fixed_grammar_rejects_unknown_or_private_text(self):
        source = HELPER.read_text()
        start = source.index("    echo 'CLASSIFIED_QUERY_STAGE_TIMING_BEGIN")
        end = source.index("    echo 'CLASSIFIED_QUERY_STAGE_TIMING_END'", start) + len("    echo 'CLASSIFIED_QUERY_STAGE_TIMING_END'")
        block = source[start:end]
        identifier = '00000000-0000-0000-0000-000000000001'
        line = 'CLASSIFIED_QUERY_STAGE_RECEIPT id=' + identifier + ' event=waitFinished stages='
        valid = line + ';'.join(stage + ':' + str(i) for i, stage in enumerate(STAGES))
        rejected = [line + 'privateName:12', line + 'workerStarted:12 user=private',
                    line.replace('waitFinished', 'unknown') + 'workerStarted:1',
                    line.replace(identifier, 'private-room') + 'workerStarted:1',
                    line + 'workerStarted:-1', line + 'workerStarted:nan']
        with tempfile.TemporaryDirectory() as d:
            pathlib.Path(d, 'unit.log').write_text('\n'.join(rejected + [valid] * 45) + '\n')
            script = 'set -euo pipefail\nout="$1"\ncheck() { local label=unit\n' + block + '\n}\ncheck\n'
            result = subprocess.run(['bash', '-c', script, 'check', d], check=True, capture_output=True, text=True)
        lines = result.stdout.splitlines()
        self.assertEqual(len(lines), 42)
        self.assertEqual(lines[1:-1], [valid] * 40)
        self.assertTrue(all(len(x) <= 1500 for x in lines))

    def test_integrated_pins_preserve_workflow_and_all_prior_layers(self):
        before = json.loads((HERE / 'SOURCE_PINS.json.before').read_text())
        after = json.loads((INTEGRATED / 'SOURCE_PINS.json').read_text())
        changed = ('tools/ci/native-apple.sh', 'research/native-candidate-app-integration-85/integrated/check.py')
        added = 'research/native-candidate-app-integration-85/integrated/classified-timing-ci-helper.patch'
        self.assertEqual(after['integrated']['.github/workflows/native-apple.yml'], 'ba74cd55736aa76248b885cf3c2454ba7ce2d082b0f7f040cd87ad8389e37a8e')
        for name in (*changed, added):
            self.assertEqual(after['integrated'][name], hashlib.sha256((ROOT / name).read_bytes()).hexdigest())
        recovered = json.loads(json.dumps(after))
        del recovered['integrated'][added]
        self.assertEqual(recovered.pop('beforeClassifiedTimingHelper'), {'tools/ci/native-apple.sh': before['integrated']['tools/ci/native-apple.sh']})
        for name in changed:
            recovered['integrated'][name] = before['integrated'][name]
        self.assertEqual(recovered, before)
        check = (INTEGRATED / 'check.py').read_text()
        start = check.index("    subprocess.run(['git', 'apply', '-R', str(H / 'classified-timing-ci-helper.patch')]")
        end = check.index("    subprocess.run(['git', 'apply', '-R', str(H / 'recorder-timing-ci-helper.patch')]", start)
        self.assertEqual(check[:start] + check[end:], (HERE / 'check.py.before').read_text())

    def test_all_three_helper_inverse_stages_recover_exact_hashes(self):
        manifest = json.loads((INTEGRATED / 'SOURCE_PINS.json').read_text())
        with tempfile.TemporaryDirectory() as d:
            target = pathlib.Path(d, 'tools/ci/native-apple.sh')
            target.parent.mkdir(parents=True)
            shutil.copyfile(HELPER, target)
            for patch, key in [('classified-timing-ci-helper.patch', 'beforeClassifiedTimingHelper'),
                               ('recorder-timing-ci-helper.patch', 'beforeRecorderTimingHelper'),
                               ('scene-timing-ci-helper.patch', 'beforeSceneTimingHelper')]:
                subprocess.run(['git', 'apply', '-R', str(INTEGRATED / patch)], cwd=d, check=True, timeout=15, capture_output=True)
                self.assertEqual(hashlib.sha256(target.read_bytes()).hexdigest(), manifest[key]['tools/ci/native-apple.sh'])

if __name__ == '__main__':
    unittest.main()
