"""Bounded stdlib + synthetic shell checks; never invokes Swift/Xcode or CI."""
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).parent
ROOT = HERE.parents[1]
SPEC = importlib.util.spec_from_file_location('seated_timing', HERE / 'extract-seated-candidate-timing.py')
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
ID = '12345678-1234-4ABC-8DEF-123456789ABC'
PHASE = (f'SEATED_CANDIDATE_PHASE id={ID} event=happy_wait_finished '
         'elapsed_ms=10000 native_callback_ms=-1 main_held_ms=-1 '
         'stages=requestEnqueued:0;workerStarted:14;nativeBuildBegin:15')
WORKER = (f'SEATED_CANDIDATE_WORKER id={ID} worker_begin_ms=14 '
          'worker_wall_ms=1 worker_cpu_us=-1 worker_pair_valid=false '
          'build_wall_ms=0 build_cpu_us=0 build_pair_valid=true '
          'route_wall_ms=-1 route_cpu_us=-1 route_pair_valid=false records=4')
SOURCE = (f'SEATED_CANDIDATE_SOURCE id={ID} request=1 event=source_requested '
          'elapsed_ms=0 main_thread=true outcome=none')


class ExtractorTests(unittest.TestCase):
    def collect(self, text, **limits):
        emitted = []
        data = text.encode() if isinstance(text, str) else text
        summary = M.collect(io.BytesIO(data), emitted.append, **limits)
        return emitted, summary

    def reject(self, text):
        output, summary = self.collect(text + '\n')
        self.assertEqual(output, [])
        self.assertEqual(summary['status'], 'unavailable')
        self.assertEqual(summary['rejected_prefix_records'], 1)

    def test_both_records_round_trip_without_value_rewriting(self):
        output, summary = self.collect(PHASE + '\n' + WORKER + '\n')
        self.assertEqual(output, [PHASE, WORKER])
        self.assertEqual(summary['records'], {'phase': 1, 'worker': 1, 'source': 0})
        self.assertEqual(summary['test_outcome'], 'not_inferred')
        self.assertFalse(summary['physical_authority'])

    def test_all_three_closed_phase_events(self):
        for event in ['happy_wait_finished', 'rejection_wait_finished', 'drain_complete']:
            line = PHASE.replace('happy_wait_finished', event)
            self.assertEqual(self.collect(line + '\n')[0], [line])

    def test_empty_stages_and_missing_id_remain_explicit(self):
        line = PHASE.split('stages=')[0].replace(ID, 'none') + 'stages='
        self.assertEqual(self.collect(line + '\n')[0], [line])

    def test_owner_relative_worker_begin_rejects_old_queue_latency_label(self):
        self.reject(WORKER.replace('worker_begin_ms=', 'queue_ms='))

    def test_valid_worker_zero_cpu_is_preserved_not_missing(self):
        line = WORKER.replace('worker_cpu_us=-1 worker_pair_valid=false',
                              'worker_cpu_us=0 worker_pair_valid=true')
        self.assertEqual(self.collect(line + '\n')[0], [line])

    def test_missing_cpu_cannot_be_marked_valid(self):
        self.reject(WORKER.replace('worker_pair_valid=false', 'worker_pair_valid=true'))

    def test_invalid_pair_cannot_mint_zero_cpu(self):
        self.reject(WORKER.replace('worker_cpu_us=-1', 'worker_cpu_us=0'))

    def test_valid_pair_requires_wall_time(self):
        self.reject(WORKER.replace('build_wall_ms=0', 'build_wall_ms=-1'))

    def test_unknown_phase_event_rejected(self):
        self.reject(PHASE.replace('happy_wait_finished', 'secret_event'))

    def test_unknown_stage_rejected(self):
        self.reject(PHASE.replace('nativeBuildBegin', 'privateGeometry'))

    def test_malformed_uuid_rejected(self):
        self.reject(PHASE.replace(ID, '-' * 36))

    def test_none_worker_id_rejected(self):
        self.reject(WORKER.replace(ID, 'none'))

    def test_negative_other_than_missing_rejected(self):
        self.reject(PHASE.replace('native_callback_ms=-1', 'native_callback_ms=-2'))

    def test_noninteger_and_unbounded_number_rejected(self):
        self.reject(PHASE.replace('elapsed_ms=10000', 'elapsed_ms=NaN'))
        self.reject(PHASE.replace('elapsed_ms=10000', 'elapsed_ms=1.5'))
        self.reject(PHASE.replace('elapsed_ms=10000', 'elapsed_ms=' + '9' * 16))

    def test_stage_and_worker_record_limits(self):
        prefix = PHASE.split('stages=')[0]
        self.assertEqual(len(self.collect(prefix + 'stages=' + ';'.join(['routeEnd:1'] * 64) + '\n')[0]), 1)
        self.reject(prefix + 'stages=' + ';'.join(['routeEnd:1'] * 65))
        self.reject(WORKER.replace('records=4', 'records=65'))

    def test_extra_geometry_or_error_fields_rejected(self):
        self.reject(PHASE + ' geometry=1,2,3')
        self.reject(WORKER + ' error=private')

    def test_nonascii_prefix_record_rejected(self):
        self.reject(PHASE.replace('happy_wait_finished', 'private_é'))

    def test_arbitrary_nonrecords_are_not_emitted(self):
        output, summary = self.collect('private model text and geometry\n' + PHASE + '\n')
        self.assertEqual(output, [PHASE])
        self.assertEqual(summary['status'], 'observed')

    def test_records_before_long_tail_remain_available(self):
        output, _ = self.collect(PHASE + '\n' + WORKER + '\n' + 'later unrelated output\n' * 200)
        self.assertEqual(output, [PHASE, WORKER])

    def test_each_prefix_has_independent_output_cap(self):
        output, summary = self.collect((PHASE + '\n') * 3 + WORKER + '\n', record_limit=2)
        self.assertEqual(output, [PHASE, PHASE, WORKER])
        self.assertEqual(summary['dropped_valid_records'], {'phase': 1, 'worker': 0, 'source': 0})
        self.assertEqual(summary['status'], 'partial')

    def test_input_cap_never_scans_or_prints_beyond_budget(self):
        output, summary = self.collect('noise\n' * 20 + PHASE + '\n', input_limit=100)
        self.assertEqual(output, [])
        self.assertEqual(summary['input_bytes_scanned'], 100)
        self.assertTrue(summary['scan_budget_reached'])

    def test_overlong_line_cannot_smuggle_a_prefix_continuation(self):
        text = 'x' * (M.LINE_LIMIT + 1) + PHASE + '\n' + WORKER + '\n'
        self.assertEqual(self.collect(text)[0], [WORKER])
        self.reject(PHASE + 'x' * M.LINE_LIMIT)

    def test_unterminated_record_rejected(self):
        output, summary = self.collect(PHASE)
        self.assertEqual(output, [])
        self.assertTrue(summary['unterminated_input'])

    def test_empty_input_unavailable(self):
        self.assertEqual(self.collect('')[1]['status'], 'unavailable')

    def test_missing_file_reports_type_not_path(self):
        with tempfile.TemporaryDirectory() as folder:
            result = subprocess.run(['python3', '-B', str(HERE / 'extract-seated-candidate-timing.py'),
                                     str(Path(folder) / 'private-missing.log')],
                                    capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0)
        self.assertNotIn('private-missing', result.stdout)
        summary = json.loads(result.stdout.split('SEATED_CANDIDATE_TIMING_SUMMARY=', 1)[1])
        self.assertEqual(summary['status'], 'unavailable')

    def shell_result(self, code, label='diagnostics-unit', extractor_fails=False):
        # Execute only the actual run_logged function with a synthetic cat/exit
        # producer. The script's case dispatch/native commands are never sourced.
        script = (HERE / 'native-apple.sh').read_text()
        function = script[script.index('run_logged() {'):script.index('\ncase "$mode" in')]
        wrapper = ('set -euo pipefail\nout="$1"\n' + function + '\n'
                   + ('python3() { return 97; }\n' if extractor_fails else '')
                   + 'status=0\nrun_logged "$2" bash -c \'cat "$1"; exit "$2"\' '
                     'synthetic "$3" "$4" || status=$?\nexit "$status"\n')
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / 'synthetic-input.txt'
            source.write_text(PHASE + '\n' + WORKER + '\n' + SOURCE + '\n' + 'unrelated later output\n' * 200)
            return subprocess.run(['bash', '-c', wrapper, 'synthetic', folder, label, str(source), str(code)],
                                  cwd=ROOT, capture_output=True, text=True, timeout=10)

    def test_actual_shell_success_prints_both_records_before_tail(self):
        result = self.shell_result(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(PHASE, result.stdout)
        self.assertIn(WORKER, result.stdout)
        self.assertIn(SOURCE, result.stdout)

    def test_actual_shell_failure_preserves_nonzero_exit_and_records(self):
        result = self.shell_result(65)
        self.assertEqual(result.returncode, 65, result.stderr)
        self.assertIn(PHASE, result.stdout)
        self.assertIn(WORKER, result.stdout)
        self.assertIn(SOURCE, result.stdout)

    def test_extractor_failure_cannot_change_test_success_or_failure(self):
        for code in [0, 65]:
            self.assertEqual(self.shell_result(code, extractor_fails=True).returncode, code)

    def test_other_labels_do_not_activate_seated_extractor(self):
        result = self.shell_result(0, label='diagnostics-build')
        self.assertEqual(result.returncode, 0)
        self.assertNotIn('SEATED_CANDIDATE_TIMING_BEGIN', result.stdout)
        self.assertNotIn(PHASE, result.stdout)

    def test_all_ten_closed_source_events_round_trip(self):
        events = ['source_requested', 'source_native_callback', 'source_main_callback',
                  'source_controller_callback', 'render_enqueued', 'render_begin',
                  'render_end', 'display_accepted', 'display_rejected', 'source_refused']
        for event in events:
            line = SOURCE.replace('source_requested', event)
            self.assertEqual(self.collect(line + '\n')[0], [line])

    def test_all_five_source_native_stages_are_allowlisted(self):
        stages = ['sourceSnapshotEnqueued', 'sourceSnapshotWorkerStarted',
                  'sourceSnapshotWorkerFinished', 'sourceSnapshotDeliveryStarted',
                  'sourceSnapshotDeliveryFinished']
        line = PHASE.split('stages=')[0] + 'stages=' + ';'.join(name + ':1' for name in stages)
        self.assertEqual(self.collect(line + '\n')[0], [line])
        self.reject(line.replace('sourceSnapshotEnqueued', 'sourceSnapshotGeometry'))

    def test_source_outcome_and_main_thread_closed_scalars(self):
        for outcome in ['none', 'success', 'unavailable', 'stale', 'runtime_invalidLimits',
                        'runtime_budget', 'runtime_unavailable', 'runtime_stale',
                        'runtime_invalidRetainedState']:
            for main in ['true', 'false']:
                line = SOURCE.replace('outcome=none', 'outcome=' + outcome).replace('main_thread=true', 'main_thread=' + main)
                self.assertEqual(self.collect(line + '\n')[0], [line])
        self.reject(SOURCE.replace('outcome=none', 'outcome=error_details'))
        self.reject(SOURCE.replace('outcome=none', 'outcome=refused'))
        self.reject(SOURCE.replace('main_thread=true', 'main_thread=1'))

    def test_source_request_ordinal_strictly_bounded(self):
        for request in [1, 64]:
            line = SOURCE.replace('request=1', 'request=' + str(request))
            self.assertEqual(self.collect(line + '\n')[0], [line])
        for request in [0, -1, 65, '1.0']:
            self.reject(SOURCE.replace('request=1', 'request=' + str(request)))

    def test_source_missing_elapsed_and_id_remain_unknown(self):
        line = SOURCE.replace(ID, 'none').replace('elapsed_ms=0', 'elapsed_ms=-1')
        self.assertEqual(self.collect(line + '\n')[0], [line])
        self.reject(SOURCE.replace('elapsed_ms=0', 'elapsed_ms=-2'))

    def test_source_unknown_event_or_geometry_payload_is_rejected(self):
        self.reject(SOURCE.replace('source_requested', 'source_private_geometry'))
        self.reject(SOURCE + ' points=1,2,3')
        self.reject(SOURCE.replace(ID, '-' * 36))

    def test_source_retains_64_separate_from_phase_and_worker_caps(self):
        output, summary = self.collect((SOURCE + '\n') * 65 + PHASE + '\n' + WORKER + '\n')
        self.assertEqual(output, [SOURCE] * 64 + [PHASE, WORKER])
        self.assertEqual(summary['records'], {'source': 64, 'phase': 1, 'worker': 1})
        self.assertEqual(summary['dropped_valid_records'], {'source': 1, 'phase': 0, 'worker': 0})
        self.assertEqual(summary['status'], 'partial')

    def test_phase_and_worker_flood_cannot_evict_source_records(self):
        output, summary = self.collect((PHASE + '\n') * 33 + (WORKER + '\n') * 33 + SOURCE + '\n')
        self.assertEqual(output[-1], SOURCE)
        self.assertEqual(summary['records'], {'phase': 32, 'worker': 32, 'source': 1})
        self.assertEqual(summary['dropped_valid_records'], {'phase': 1, 'worker': 1, 'source': 0})

    def test_source_observation_does_not_infer_worker_or_test_success(self):
        output, summary = self.collect(SOURCE + '\n')
        self.assertEqual(output, [SOURCE])
        self.assertEqual(summary['records']['worker'], 0)
        self.assertEqual(summary['test_outcome'], 'not_inferred')
        self.assertFalse(summary['physical_authority'])


if __name__ == '__main__':
    unittest.main()
