#!/usr/bin/env python3
"""Portable synthetic controls only; never runs Xcode, Swift, git or a workflow."""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('qos_comparison', HERE / 'native-qos-comparison.py')
qos = importlib.util.module_from_spec(spec); spec.loader.exec_module(qos)


def arm(n, effective=None):
    requested = ['utility', 'userInitiated', 'userInitiated', 'utility'][n]
    if effective is None: effective = [17, 25, 25, 17][n]
    return (f'NATIVE_QOS_ARM arm={n} requested={requested} effective_raw={effective} elapsed_ms=300 '
            'normal_drain=true late_ack=false worker=[wall_ms=100,cpu_us=90,pair_valid=true] '
            'build=[wall_ms=90,cpu_us=80,pair_valid=true] route=[wall_ms=-1,cpu_us=-1,pair_valid=false] '
            'stages=requestEnqueued:10;workerStarted:20;workerFinished:120 physical_authority=false')


def valid_lines():
    lines = []
    for n in range(4):
        lines += [f'NATIVE_QOS_DEADLINE arm={n} phase={phase} budget_s=10.0 met=true physical_authority=false'
                  for phase in ['source', 'query', 'normal_drain']]
        lines += [f'NATIVE_QOS_SOURCE arm={n} callback_ms=10 process_offset_ms={n*300}', arm(n)]
    return lines


def raw(lines=None):
    return ('\n'.join(valid_lines() if lines is None else lines) + '\n').encode()


class GrammarTests(unittest.TestCase):
    def test_clean_abba_is_complete_not_causality(self):
        result = qos.parse_records(raw())
        self.assertTrue(result['clean_protocol_records']); self.assertTrue(result['effective_qos_separation_observed'])
        self.assertFalse(result['qos_causality_or_fix_established']); self.assertFalse(result['physical_authority'])
        self.assertEqual(len(result['records']), 20)

    def test_equal_effective_qos_inconclusive_not_failed_protocol(self):
        lines = [line if not line.startswith('NATIVE_QOS_ARM') else arm(int(line.split('arm=')[1][0]), 17) for line in valid_lines()]
        result = qos.parse_records(raw(lines))
        self.assertTrue(result['clean_protocol_records']); self.assertFalse(result['effective_qos_separation_observed'])

    def test_unavailable_effective_qos_not_separation(self):
        result = qos.parse_records(raw().replace(b'effective_raw=25', b'effective_raw=unavailable'))
        self.assertTrue(result['clean_protocol_records']); self.assertFalse(result['effective_qos_separation_observed'])

    def test_four_arms_alone_not_clean(self):
        result = qos.parse_records(raw([arm(n) for n in range(4)]))
        self.assertTrue(result['four_arms_recorded']); self.assertFalse(result['clean_protocol_records'])

    def test_each_original_deadline_failure_preserved(self):
        for index, line in enumerate(valid_lines()):
            if line.startswith('NATIVE_QOS_DEADLINE'):
                with self.subTest(index=index):
                    lines = valid_lines(); lines[index] = line.replace('met=true', 'met=false')
                    result = qos.parse_records(raw(lines))
                    self.assertFalse(result['clean_protocol_records']); self.assertIn(lines[index], result['records'])

    def test_late_ack_does_not_erase_original_failure(self):
        lines = valid_lines()
        lines[2] = lines[2].replace('met=true', 'met=false')
        lines[4] = lines[4].replace('normal_drain=true late_ack=false', 'normal_drain=false late_ack=true')
        lines.insert(3, 'NATIVE_QOS_LATE_DRAIN arm=0 observation_s=45 acknowledged=true original_failure_preserved=true')
        result = qos.parse_records(raw(lines))
        self.assertTrue(result['late_observation_present']); self.assertFalse(result['clean_protocol_records'])

    def test_aborted_source_failure_retained_without_required_query(self):
        lines = [valid_lines()[0].replace('met=true', 'met=false'), valid_lines()[2],
                 'NATIVE_QOS_SOURCE arm=0 callback_ms=-1 process_offset_ms=0', arm(0, 'unavailable')]
        result = qos.parse_records(raw(lines))
        self.assertEqual(len(result['records']), 4); self.assertEqual(result['rejected_prefix_records'], 0)
        self.assertFalse(result['clean_protocol_records'])

    def test_out_of_order_arms_not_clean(self):
        lines = valid_lines(); lines[4], lines[9] = lines[9], lines[4]
        self.assertFalse(qos.parse_records(raw(lines))['four_arms_recorded'])

    def test_duplicate_deadline_not_clean(self):
        self.assertFalse(qos.parse_records(raw(valid_lines() + [valid_lines()[0]]))['clean_protocol_records'])

    def test_missing_source_row_not_clean(self):
        self.assertFalse(qos.parse_records(raw([x for x in valid_lines() if not x.startswith('NATIVE_QOS_SOURCE arm=2')]))['clean_protocol_records'])

    def test_missing_cpu_is_minus_one_false(self):
        result = qos.parse_records(raw([arm(0).replace('wall_ms=100,cpu_us=90,pair_valid=true', 'wall_ms=100,cpu_us=-1,pair_valid=false')]))
        self.assertEqual(result['rejected_prefix_records'], 0)

    def test_reject_bad_cpu_pairs(self):
        for pair in ['wall_ms=-1,cpu_us=90,pair_valid=true', 'wall_ms=100,cpu_us=-1,pair_valid=true',
                     'wall_ms=100,cpu_us=0,pair_valid=false', 'wall_ms=-2,cpu_us=-1,pair_valid=false']:
            with self.subTest(pair=pair):
                self.assertEqual(qos.parse_records(raw([arm(0).replace('wall_ms=100,cpu_us=90,pair_valid=true', pair)]))['rejected_prefix_records'], 1)

    def test_reject_geometry_errors_and_unknown_fields(self):
        for suffix in [' vertices=[1,2,3]', ' error=anything', ' model_text=hello', ' extra=true']:
            with self.subTest(suffix=suffix):
                self.assertEqual(qos.parse_records(raw([arm(0) + suffix]))['records'], [])

    def test_reject_bad_fixed_grammar(self):
        for before, after in [('arm=0', 'arm=4'), ('utility', 'background'), ('effective_raw=17', 'effective_raw=4294967296'),
                              ('elapsed_ms=300', 'elapsed_ms=-1'), ('physical_authority=false', 'physical_authority=true'),
                              ('requestEnqueued', 'secretStage'), ('normal_drain=true late_ack=false', 'normal_drain=true late_ack=true')]:
            with self.subTest(after=after):
                self.assertEqual(qos.parse_records(raw([arm(0).replace(before, after)]))['rejected_prefix_records'], 1)

    def test_reject_changed_budget(self):
        for before, after in [('budget_s=10.0', 'budget_s=11'), ('phase=source', 'phase=any'), ('met=true', 'met=True')]:
            self.assertEqual(qos.parse_records(raw([valid_lines()[0].replace(before, after)]))['records'], [])

    def test_reject_unknown_prefix(self):
        self.assertEqual(qos.parse_records(b'NATIVE_QOS_SECRET private\n')['rejected_prefix_records'], 1)

    def test_non_metadata_noise_ignored(self):
        result = qos.parse_records(b'private irrelevant text\n' + raw())
        self.assertTrue(result['clean_protocol_records']); self.assertNotIn('private', str(result))

    def test_non_ascii_rejected(self):
        self.assertEqual(qos.parse_records(b'NATIVE_QOS_\xff\n')['rejected_prefix_records'], 1)

    def test_line_cap_rejected(self):
        self.assertEqual(qos.parse_records(b'NATIVE_QOS_' + b'x'*qos.LINE_LIMIT)['rejected_prefix_records'], 1)

    def test_record_cap_fail_closed(self):
        result = qos.parse_records(raw([valid_lines()[0]] * 65))
        self.assertEqual(len(result['records']), 64); self.assertEqual(result['dropped_records'], 1)
        self.assertFalse(result['clean_protocol_records'])

    def test_byte_cap(self):
        with mock.patch.object(qos, 'LOG_LIMIT', 10), self.assertRaises(ValueError): qos.parse_records(b'x'*11)

    def test_empty_is_not_clean(self):
        self.assertFalse(qos.parse_records(b'')['clean_protocol_records'])


class CommandTests(unittest.TestCase):
    def test_exact_one_hosted_test_no_package_manifest_override(self):
        command = qos.command('build', '12345678-1234-1234-1234-123456789abc', Path('/tmp/out'))
        self.assertEqual([x for x in command if x.startswith('-only-testing:')], ['-only-testing:' + qos.SELECTION])
        self.assertIn('SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DEBUG BLIND_QOS_COMPARISON', command)
        self.assertIn('build-for-testing', command); self.assertNotIn('test', command)
        self.assertNotIn('-enableCodeCoverage', command)

    def test_test_without_rebuild(self):
        command = qos.command('test', '12345678-1234-1234-1234-123456789abc', Path('/tmp/out'))
        self.assertEqual(command[-1], 'test-without-building')

    def test_bad_device_or_mode_rejected(self):
        for mode, device in [('run', '12345678-1234-1234-1234-123456789abc'), ('test', '-'*36), ('test', '123;echo hello')]:
            with self.subTest(mode=mode, device=device), self.assertRaises(ValueError): qos.command(mode, device, Path('/tmp'))

    def test_bounded_file_and_symlink(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/'file'; path.write_bytes(b'abc')
            self.assertEqual(qos.read_bounded(path, 3), b'abc')
            with self.assertRaises(ValueError): qos.read_bounded(path, 2)
            link=Path(temp)/'link'; link.symlink_to(path)
            with self.assertRaises(ValueError): qos.read_bounded(link, 3)

    def test_non_apple_run_refused_without_process(self):
        with mock.patch.object(qos.sys, 'platform', 'linux'), mock.patch.object(qos.subprocess, 'Popen') as popen:
            with self.assertRaises(ValueError): qos.run('test', Path('/tmp'))
            popen.assert_not_called()

    def test_exact_identifier_normalizations_only(self):
        for identifier in [qos.CASE, qos.CASE+'()', 'BlindAssistTests/'+qos.CASE]: self.assertTrue(qos.exact_case(identifier))
        for identifier in ['Other/'+qos.CASE, qos.CASE+'Other', '']: self.assertFalse(qos.exact_case(identifier))

    def test_deadlines_are_separate_not_relaxed_acceptance(self):
        self.assertEqual((qos.BUILD_SECONDS,qos.LAUNCH_SECONDS,qos.CASE_SECONDS,qos.TEST_SECONDS), (900,120,360,480))


class CollectorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.out=Path(self.temp.name)
        self.provenance={'source_commit':'a'*40,'source_hashes':{'synthetic.swift':'b'*64},'source_verified':True}
        self.cases=[{'identifier':qos.CASE,'result':'Passed'}]
        self.native=mock.Mock()
        self.native.query.return_value=b'{}'
        self.native.cases_from.side_effect=lambda _: copy.deepcopy(self.cases)
        self.native.reconcile.side_effect=lambda cases, _: {status:sum(c['result']==status for c in cases) for status in ['Passed','Failed','Skipped','Expected Failure']}
        for mode in ['build','test']:
            self.write_command(mode)
        (self.out/'test.log').write_bytes(raw())

    def write_command(self, mode, **changes):
        value={'mode':mode,'command_exit':0,'wrapper_exit':0,'watchdog':None, **self.provenance, **changes}
        (self.out/(mode+'-command.json')).write_text(json.dumps(value))

    def collect(self, source_error=False):
        with mock.patch.object(qos,'module',return_value=self.native), mock.patch.object(qos,'source_receipt',side_effect=ValueError() if source_error else None, return_value=self.provenance), mock.patch.dict(qos.os.environ,{},clear=True), contextlib.redirect_stdout(io.StringIO()) as output:
            code=qos.collect(self.out)
        result=json.loads((self.out/'result.json').read_text())
        self.assertIn('NATIVE_QOS_RECEIPT=',output.getvalue())
        return code,result

    def test_one_pass_and_full_protocol_required(self):
        code,result=self.collect(); self.assertEqual(code,0); self.assertTrue(result['exact_test_identity_verified'])
        self.assertEqual(result['status'],'passed-isolated-diagnostic')

    def test_failed_case_still_exported(self):
        self.cases[0]['result']='Failed'; code,result=self.collect()
        self.assertEqual(code,1); self.assertEqual(result['cases'],self.cases); self.assertEqual(result['counts']['Failed'],1)

    def test_skipped_is_not_pass(self):
        self.cases[0]['result']='Skipped'; self.assertEqual(self.collect()[0],1)

    def test_zero_cases_fail(self):
        self.cases=[]; self.assertEqual(self.collect()[0],1)

    def test_duplicate_case_fails(self):
        self.cases*=2; self.assertEqual(self.collect()[0],1)

    def test_unexpected_case_not_leaked(self):
        self.cases.append({'identifier':'private arbitrary text','result':'Passed'})
        code,result=self.collect(); self.assertEqual(code,1); self.assertEqual(result['unexpected_case_count'],1)
        self.assertNotIn('private arbitrary text',json.dumps(result))

    def test_four_rows_and_xctest_pass_not_enough(self):
        (self.out/'test.log').write_bytes(raw([arm(n) for n in range(4)])); self.assertEqual(self.collect()[0],1)

    def test_failed_command_not_hidden_by_passed_xctest(self):
        self.write_command('test',command_exit=65,wrapper_exit=65)
        code,result=self.collect(); self.assertEqual(code,1); self.assertEqual(result['commands']['test']['command_exit'],65)

    def test_boolean_false_not_integer_success(self):
        self.write_command('test',command_exit=False,wrapper_exit=False); self.assertEqual(self.collect()[0],1)

    def test_watchdog_never_passes(self):
        self.write_command('test',watchdog='test-case-observation-deadline'); self.assertEqual(self.collect()[0],1)

    def test_source_mismatch_not_pass(self):
        self.write_command('test',source_commit='c'*40); self.assertEqual(self.collect()[0],1)

    def test_missing_command_retains_case_and_records(self):
        (self.out/'build-command.json').unlink(); code,result=self.collect()
        self.assertEqual(code,1); self.assertEqual(len(result['records']),20); self.assertEqual(result['cases'],self.cases)

    def test_no_test_log_retains_case(self):
        (self.out/'test.log').unlink(); code,result=self.collect()
        self.assertEqual(code,1); self.assertEqual(result['cases'],self.cases)

    def test_missing_result_preserves_timing(self):
        self.native.query.side_effect=ValueError(); code,result=self.collect()
        self.assertEqual(code,1); self.assertEqual(len(result['records']),20)

    def test_aggregate_mismatch_retains_cases(self):
        self.native.reconcile.side_effect=ValueError(); code,result=self.collect()
        self.assertEqual(code,1); self.assertEqual(result['cases'],self.cases)

    def test_missing_provenance_retains_failed_evidence(self):
        self.cases[0]['result']='Failed'; code,result=self.collect(source_error=True)
        self.assertEqual(code,1); self.assertEqual(result['cases'],self.cases); self.assertEqual(len(result['records']),20)

    def test_unknown_command_key_not_copied(self):
        self.write_command('test',secret='private text'); code,result=self.collect()
        self.assertEqual(code,1); self.assertNotIn('private text',json.dumps(result))

    def test_unknown_watchdog_not_copied(self):
        self.write_command('test',watchdog='private text'); code,result=self.collect()
        self.assertEqual(code,1); self.assertNotIn('private text',json.dumps(result))

    def test_summary_log_available_on_failure(self):
        self.cases[0]['result']='Failed'; summary=self.out/'summary'
        with mock.patch.object(qos,'module',return_value=self.native), mock.patch.object(qos,'source_receipt',return_value=self.provenance), mock.patch.dict(qos.os.environ,{'GITHUB_STEP_SUMMARY':str(summary)},clear=True), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(qos.collect(self.out),1)
        self.assertIn('NATIVE_QOS_RECEIPT=', summary.read_text())
        self.assertIn('Failed', summary.read_text())


class WatchdogTests(unittest.TestCase):
    def test_build_budget(self):
        self.assertIsNone(qos.watchdog_reason('build', 900, None, 0))
        self.assertEqual(qos.watchdog_reason('build', 900.1, None, 0), 'build-process-deadline')

    def test_launch_budget_separate_from_case(self):
        self.assertEqual(qos.watchdog_reason('test', 120.1, None, 0), 'test-launch-deadline')
        self.assertIsNone(qos.watchdog_reason('test', 120.1, 1, 0))

    def test_case_observation_budget(self):
        self.assertEqual(qos.watchdog_reason('test', 400, 360.1, 0), 'test-case-observation-deadline')
        self.assertIsNone(qos.watchdog_reason('test', 400, 360, 0))

    def test_overall_test_budget(self):
        self.assertEqual(qos.watchdog_reason('test', 480.1, 1, 0), 'test-process-deadline')

    def test_log_budget(self):
        self.assertEqual(qos.watchdog_reason('test', 1, 1, qos.LOG_LIMIT+1), 'log-budget')


class SourceControls(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.paths={
            'ios/BlindAssist.xcodeproj/project.pbxproj': 'default project without experiment flag',
            'ios/BlindAssistTests/NativeQoSComparisonTests.swift':
                '#if DEBUG && BLIND_QOS_COMPARISON && canImport(Darwin)\nfunc testIsolatedUtilityUserInitiatedABBA() {}\nowner.configureSyntheticComparisonQoS(userInitiated:true)\n#endif',
            'research/room-mesh-package-75/BlindRoomMesh/Package.swift': 'default package',
            'research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift':
                'private var comparisonQoS: DispatchQoS?\nguard let qos=locked({comparisonQoS}) else { Self.worker.async(execute:work); return }',
            'ios/BlindAssist/App.swift':'default app'}
        for name, value in self.paths.items():
            path=self.root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(value)
        self.native=mock.Mock();self.native.provenance.return_value={'actual_head':'a'*40}

    def source(self):
        with mock.patch.object(qos, 'ROOT', self.root), mock.patch.object(qos, 'module', return_value=self.native), mock.patch.dict(qos.os.environ, {'GITHUB_SHA':'a'*40}, clear=True):
            return qos.source_receipt()

    def change(self, path, value):
        (self.root/path).write_text(value)

    def test_default_hook_and_test_flag_split(self):
        result=self.source();self.assertFalse(result['package_experiment_flag_required'])
        self.assertFalse(result['default_project_experiment_flag']);self.assertEqual(len(result['source_hashes']),4)

    def test_default_project_flag_rejected(self):
        self.change('ios/BlindAssist.xcodeproj/project.pbxproj',qos.FLAG)
        with self.assertRaises(ValueError):self.source()

    def test_package_flag_rejected(self):
        self.change('research/room-mesh-package-75/BlindRoomMesh/Package.swift',qos.FLAG)
        with self.assertRaises(ValueError):self.source()

    def test_missing_test_flag_rejected(self):
        path='ios/BlindAssistTests/NativeQoSComparisonTests.swift'
        self.change(path,self.paths[path].replace(' && BLIND_QOS_COMPARISON',''))
        with self.assertRaises(ValueError):self.source()

    def test_extra_test_declaration_rejected(self):
        path='ios/BlindAssistTests/NativeQoSComparisonTests.swift'
        self.change(path,self.paths[path]+'\nfunc testOther() {}')
        with self.assertRaises(ValueError):self.source()

    def test_unexpected_app_caller_rejected(self):
        self.change('ios/BlindAssist/App.swift','owner.configureSyntheticComparisonQoS(userInitiated:true)')
        with self.assertRaises(ValueError):self.source()

    def test_package_flag_propagation_assumption_rejected(self):
        path='research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift'
        self.change(path,self.paths[path]+'\n#if BLIND_QOS_COMPARISON')
        with self.assertRaises(ValueError):self.source()

    def test_default_fallback_removed_rejected(self):
        path='research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift'
        self.change(path,self.paths[path].replace('Self.worker.async(execute:work); return','work(); return'))
        with self.assertRaises(ValueError):self.source()


if __name__ == '__main__': unittest.main()
