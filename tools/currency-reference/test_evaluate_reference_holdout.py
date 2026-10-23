"""Fresh synthetic plumbing tests; not real-photo, native or currency accuracy."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
import evaluate_reference_holdout as eh


class HoldoutTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.inventory_path = self.root / 'inventory.json'
        self.reference_path = self.root / 'references.json'
        self.serial = 0
        self.inventory = {'schema_version': 1, 'dataset_id': 'synthetic-plumbing-v1', 'data_kind': 'synthetic', 'sources': [], 'samples': []}
        self.review = {'verified': True, 'verification_kind': 'synthetic_fixture', 'verified_by': 'fixture',
                       'verified_on': '2026-10-23', 'method': 'Synthetic test label, not currency evidence'}
        self.add_sample('reference', 'ref')
        self.add_sample('calibration', 'cal')
        self.add_sample('test', 'test')
        reference = self.inventory['samples'][0]
        self.references = {'schema_version': 1, 'reference_kind': 'synthetic_mechanics', 'currency': 'SAR', 'labels': eh.rm.LABELS,
                           'references': [{'id': 'ref', 'path': reference['path'], 'sha256': reference['sha256'], 'label': 1,
                                           'side': 'front', 'issue': 'fixture-v1', 'material': 'paper', 'physical_note_id': 'note-ref',
                                           'capture_session_id': 'session-ref', 'source': 'Synthetic fixture', 'rights': 'Synthetic test only',
                                           'verification': self.review.copy()}]}

    def add_sample(self, role, sid, expected=1, condition='clean', notes=None, sessions=None):
        self.serial += 1
        image_path = self.root / (sid + '.png')
        image = Image.new('RGB', (64, 64), (self.serial % 255, self.serial // 255, 17))
        image.putpixel((31, 13), (self.serial % 255, 42, 13))
        image.save(image_path)
        image_hash = eh.digest(image_path.read_bytes())
        self.inventory['sources'].append({'id': 'source-' + sid, 'path': image_path.name, 'sha256': image_hash, 'parent_ids': []})
        row = {'id': sid, 'path': image_path.name, 'sha256': image_hash, 'role': role, 'expected': expected, 'condition': condition,
               'side': 'front' if expected != 'unknown' else 'n/a', 'variant': 'paper' if expected != 'unknown' else 'n/a',
               'issue': 'fixture-v1' if expected != 'unknown' else 'n/a',
               'physical_note_ids': ['note-' + sid] if notes is None else notes,
               'capture_session_ids': ['session-' + sid] if sessions is None else sessions,
               'identity_status': 'complete', 'source_id': 'source-' + sid,
               'image_scope': 'reviewed_note_boundary' if role == 'reference' else 'entire_frame',
               'source': 'Synthetic fixture', 'rights': 'Synthetic test only', 'verification': self.review.copy()}
        self.inventory['samples'].append(row)
        return row

    def save(self):
        self.inventory_path.write_text(json.dumps(self.inventory))
        self.reference_path.write_text(json.dumps(self.references))

    def load(self):
        self.save()
        return eh.load_inventory(self.inventory_path, self.reference_path, allow_synthetic=True)

    def fake_run(self, references, query, algorithm):
        return {'decision': 'unknown', 'selected_reference_label': None, 'reason': 'Synthetic stub'}

    def use_real_metadata_scope_fixture(self):
        # Exercise real-data report wording only; these pixels remain synthetic
        # fixtures and no result from this test is real-banknote evidence.
        self.inventory['data_kind'] = 'real'
        self.references['reference_kind'] = 'private_banknote_photos'
        for row in self.inventory['samples'] + self.references['references']:
            row['verification']['verification_kind'] = 'assistant_visual_review'

    def freeze_fixture(self):
        inventory = self.load()
        with patch.object(eh.rm, 'run', self.fake_run):
            calibration = eh.calibrate(inventory)
        calibration_path = self.root / 'calibration.json'
        eh.write_new(calibration_path, calibration)
        frozen = eh.freeze(inventory, calibration_path, 'sift', 'Synthetic plumbing choice only', True)
        freeze_path = self.root / 'frozen.json'
        eh.write_new(freeze_path, frozen)
        return inventory, calibration_path, freeze_path

    def test_roundtrip_has_three_explicit_roles_and_no_training(self):
        inventory = self.load()
        self.assertEqual(set(r['role'] for r in inventory['samples'].values()), eh.ROLES)
        self.assertEqual(inventory['unknown_identity_samples'], [])
        self.assertEqual(len(set(inventory['groups'].values())), 3)

    def test_synthetic_requires_explicit_opt_in(self):
        self.save()
        with self.assertRaisesRegex(eh.rm.InputError, 'allow-synthetic'):
            eh.load_inventory(self.inventory_path, self.reference_path)

    def test_duplicate_sample_bytes_rejected_even_with_different_path(self):
        row, original = self.inventory['samples'][2], self.inventory['samples'][1]
        (self.root / row['path']).write_bytes((self.root / original['path']).read_bytes())
        row['sha256'] = self.inventory['sources'][2]['sha256'] = original['sha256']
        with self.assertRaisesRegex(eh.rm.InputError, 'duplicate sample image'):
            self.load()

    def test_actual_image_hash_checked_not_trusted_string(self):
        (self.root / 'test.png').write_bytes(b'changed after inventory')
        with self.assertRaisesRegex(eh.rm.InputError, 'SHA256 mismatch'):
            self.load()

    def test_reference_test_same_physical_note_refused(self):
        self.inventory['samples'][2]['physical_note_ids'] = ['note-ref']
        with self.assertRaisesRegex(eh.rm.InputError, 'Cross-role leakage'):
            self.load()

    def test_reference_test_same_session_refused(self):
        self.inventory['samples'][2]['capture_session_ids'] = ['session-ref']
        with self.assertRaisesRegex(eh.rm.InputError, 'Cross-role leakage'):
            self.load()

    def test_calibration_test_same_session_refused(self):
        self.inventory['samples'][2]['capture_session_ids'] = ['session-cal']
        with self.assertRaisesRegex(eh.rm.InputError, 'Cross-role leakage'):
            self.load()

    def test_derived_source_family_across_roles_refused(self):
        self.inventory['sources'][2]['parent_ids'] = ['source-ref']
        with self.assertRaisesRegex(eh.rm.InputError, 'Cross-role leakage'):
            self.load()

    def test_multinote_all_identities_link_transitively(self):
        self.add_sample('test', 'second')
        self.add_sample('test', 'bridge', 'unknown', 'multiple_notes', ['note-test', 'note-second'])
        self.add_sample('test', 'third', 'unknown', 'multiple_notes', ['note-second', 'note-third'])
        inventory = self.load()
        self.assertEqual(len({inventory['groups'][r] for r in ('test', 'second', 'bridge', 'third')}), 1)

    def test_multinote_leakage_through_second_note_refused(self):
        self.add_sample('test', 'bridge', 'unknown', 'multiple_notes', ['note-test', 'note-ref'])
        with self.assertRaisesRegex(eh.rm.InputError, 'Cross-role leakage'):
            self.load()

    def test_all_capture_sessions_in_composite_joined(self):
        self.add_sample('test', 'bridge', 'unknown', 'composite', ['note-test'], ['session-test', 'session-cal'])
        with self.assertRaisesRegex(eh.rm.InputError, 'Cross-role leakage'):
            self.load()

    def test_composite_one_physical_note_allowed_and_requires_abstention(self):
        row = self.add_sample('test', 'composite', 'unknown', 'composite', ['note-composite'])
        inventory = self.load()
        predictions = {r['id']: 'abstain' for r in inventory['samples'].values() if r['role'] == 'test'}
        predictions['composite'] = 1
        rows = [r for r in inventory['samples'].values() if r['role'] == 'test']
        result = eh.summarize(rows, predictions, inventory['groups'])
        self.assertEqual(result['by_condition']['composite']['unknown_false_acceptance_rate']['numerator'], 1)
        self.assertEqual(result['overall']['correct_spoken_count'], 0)
        row['expected'], row['side'], row['variant'], row['issue'] = 1, 'front', 'paper', 'fixture-v1'
        with self.assertRaisesRegex(eh.rm.InputError, 'negative/multiple/composite'):
            self.load()

    def test_missing_identity_does_not_fabricate_independence(self):
        self.inventory['samples'][2]['physical_note_ids'] = []
        inventory = self.load()
        self.assertEqual(inventory['unknown_identity_samples'], ['test'])
        with self.assertRaisesRegex(eh.rm.InputError, 'Independence unavailable'):
            eh.calibrate(inventory)

    def test_unknown_status_and_missing_session_block_freeze(self):
        for change in ({'identity_status': 'unknown'}, {'capture_session_ids': []}):
            with self.subTest(change=change):
                self.inventory['samples'][2].update(change)
                inventory = self.load()
                with self.assertRaisesRegex(eh.rm.InputError, 'Independence unavailable'):
                    eh.freeze(inventory, self.root / 'absent.json', 'sift', 'reason', True)

    def test_placeholder_identity_is_not_an_independent_note(self):
        self.inventory['samples'][2]['physical_note_ids'] = ['unknown']
        with self.assertRaisesRegex(eh.rm.InputError, 'is unknown'):
            self.load()

    def test_multinote_missing_second_identity_is_not_independent(self):
        self.add_sample('test', 'multiple', 'unknown', 'multiple_notes', ['known-one-only'])
        inventory = self.load()
        self.assertIn('multiple', inventory['unknown_identity_samples'])

    def test_bool_denomination_and_invalid_variant_refused(self):
        self.inventory['samples'][2]['expected'] = True
        with self.assertRaises(eh.metrics_core.ValidationError):
            self.load()
        self.inventory['samples'][2]['expected'] = 100
        self.inventory['samples'][2]['variant'] = 'polymer'
        with self.assertRaisesRegex(eh.rm.InputError, 'polymer'):
            self.load()

    def test_conflicting_physical_note_labels_refused(self):
        self.add_sample('test', 'conflict', 100, notes=['note-test'])
        with self.assertRaisesRegex(eh.rm.InputError, 'conflicting physical-note'):
            self.load()

    def test_unknown_expected_cannot_be_positive_condition(self):
        self.inventory['samples'][2]['expected'] = 'unknown'
        with self.assertRaisesRegex(eh.rm.InputError, 'negative condition'):
            self.load()

    def test_no_query_roi_or_prepared_crop_accepted(self):
        self.inventory['samples'][2]['image_scope'] = 'reviewed_note_boundary'
        with self.assertRaisesRegex(eh.rm.InputError, 'entire frames'):
            self.load()
        self.inventory['samples'][2]['image_scope'] = 'entire_frame'
        self.inventory['samples'][2]['source_id'] = 'source-cal'
        with self.assertRaisesRegex(eh.rm.InputError, 'query bytes must equal'):
            self.load()

    def test_reference_manifest_must_match_inventory(self):
        self.references['references'][0]['label'] = 100
        with self.assertRaisesRegex(eh.rm.InputError, 'reference label/hash'):
            self.load()

    def test_strict_fields_duplicate_json_keys_nonfinite_and_cycles(self):
        self.inventory['samples'][2]['unexpected'] = 'ignored?'
        with self.assertRaisesRegex(eh.rm.InputError, 'exactly'):
            self.load()
        del self.inventory['samples'][2]['unexpected']
        self.inventory['sources'][2]['parent_ids'] = ['source-test']
        with self.assertRaisesRegex(eh.rm.InputError, 'Cyclic'):
            self.load()
        for raw in ('{"a":1,"a":2}', '{"a":NaN}'):
            self.inventory_path.write_text(raw)
            with self.assertRaises(eh.rm.InputError):
                eh.read_json(self.inventory_path)

    def test_paths_missing_traversal_and_symlink_escape_refused(self):
        original = self.inventory['sources'][2]['path']
        for path in ('../outside.png', '/tmp/absolute.png', 'missing.png'):
            self.inventory['sources'][2]['path'] = path
            with self.assertRaises((eh.rm.InputError, OSError)):
                self.load()
        self.inventory['sources'][2]['path'] = original
        outside = self.root.parent / (self.root.name + '-outside.png')
        outside.write_bytes((self.root / original).read_bytes())
        self.addCleanup(outside.unlink)
        (self.root / 'escape.png').symlink_to(outside)
        self.inventory['sources'][2]['path'] = 'escape.png'
        with self.assertRaisesRegex(eh.rm.InputError, 'escapes'):
            self.load()

    def test_more_than_32_queries_are_not_truncated(self):
        for index in range(40):
            self.add_sample('test', 'extra-' + str(index))
        inventory = self.load()
        with patch.object(eh.rm, 'run', self.fake_run):
            result = eh.run_role(inventory, 'test', 'orb')
        self.assertEqual(result['case_count'], 41)
        self.assertEqual(len(result['cases']), 41)

    def test_resource_bounds_refuse_not_truncate(self):
        with patch.object(eh, 'MAX_SAMPLES', 2):
            with self.assertRaisesRegex(eh.rm.InputError, 'never silently truncate'):
                self.load()
        with patch.object(eh, 'MAX_TOTAL_IMAGE_BYTES', 1):
            with self.assertRaisesRegex(eh.rm.InputError, 'byte'):
                self.load()

    def test_calibration_runs_only_calibration_frames_for_all_methods(self):
        inventory = self.load()
        with patch.object(eh.rm, 'run', side_effect=self.fake_run) as run:
            report = eh.calibrate(inventory)
        self.assertEqual(report['test_samples_evaluated'], 0)
        self.assertEqual(run.call_count, 3)
        self.assertTrue(all(call.args[1].name == 'cal.png' for call in run.call_args_list))
        self.assertEqual({call.args[2] for call in run.call_args_list}, set(eh.rm.ALGORITHMS))

    def test_real_validation_scope_does_not_claim_independent_heldout_evidence(self):
        self.use_real_metadata_scope_fixture()
        original = copy.deepcopy(self.inventory['samples'][2])
        for index, change in enumerate(({'identity_status': 'unknown'}, {'physical_note_ids': []},
                                        {'capture_session_ids': []})):
            with self.subTest(change=change):
                self.inventory['samples'][2] = {**original, **change}
                self.save()
                output = self.root / f'validation-{index}.json'
                with patch.object(eh.rm, 'run') as run:
                    status = eh.main(['validate', '--inventory', str(self.inventory_path),
                                      '--references', str(self.reference_path), '--output', str(output)])
                self.assertEqual(status, 0)
                run.assert_not_called()
                report = eh.read_json(output)
                self.assertFalse(report['independence_supported_by_declared_identities'])
                self.assertEqual(report['unknown_identity_samples'], ['test'])
                self.assertIn('Inventory validation only', report['evidence_scope'])
                self.assertIn('no calibration or held-out inference', report['evidence_scope'])
                self.assertIn('independence unsupported', report['evidence_scope'])
                self.assertNotIn('Declared-independent', report['evidence_scope'])
                self.assertFalse(report['release_approval'])
                self.assertFalse(report['validated'])
                self.assertIsNone(report['monetary_answer'])

    def test_real_scope_distinguishes_calibration_freeze_and_heldout(self):
        self.use_real_metadata_scope_fixture()
        inventory, calibration_path, freeze_path = self.freeze_fixture()
        calibration = eh.read_json(calibration_path)
        frozen = eh.read_json(freeze_path)
        self.assertIn('Calibration-only Python experiment', calibration['evidence_scope'])
        self.assertIn('no held-out test inference', calibration['evidence_scope'])
        self.assertEqual(calibration['test_samples_evaluated'], 0)
        self.assertIn('Frozen Python policy artifact', frozen['evidence_scope'])
        self.assertIn('no held-out test results', frozen['evidence_scope'])
        with patch.object(eh.rm, 'run', self.fake_run):
            heldout = eh.test_holdout(inventory, freeze_path, self.root / 'heldout.json')
        self.assertIn('Held-out Python experiment', heldout['evidence_scope'])
        for report in (calibration, frozen, heldout):
            self.assertIn('independence supported only by declared identities', report['evidence_scope'])
            self.assertIn('not native/device acceptance', report['evidence_scope'])
            self.assertFalse(report['release_approval'])
            self.assertFalse(report['validated'])
            self.assertIsNone(report['monetary_answer'])

    def test_synthetic_scope_remains_harness_only_for_every_stage(self):
        inventory = self.load()
        for kind in ('inventory_validation_only', 'calibration_only', 'frozen_before_test', 'held_out_test'):
            with self.subTest(kind=kind):
                report = eh.base_report(inventory, kind)
                self.assertIn('SYNTHETIC HARNESS ONLY; NOT CURRENCY ACCURACY', report['evidence_scope'])
                self.assertNotIn('independence supported', report['evidence_scope'])

    def test_frozen_test_runs_only_chosen_method_once(self):
        inventory, _, freeze_path = self.freeze_fixture()
        output = self.root / 'results.json'
        with patch.object(eh.rm, 'run', side_effect=self.fake_run) as run:
            report = eh.test_holdout(inventory, freeze_path, output)
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[1].name, 'test.png')
        self.assertEqual(run.call_args.args[2], 'sift')
        self.assertFalse(report['release_approval'])
        self.assertIn('SYNTHETIC HARNESS', report['evidence_scope'])
        with self.assertRaises(FileExistsError):
            eh.test_holdout(inventory, freeze_path, self.root / 'results-second.json')

    def test_freeze_requires_attestation_and_unchanged_calibration(self):
        inventory, calibration_path, _ = self.freeze_fixture()
        with self.assertRaisesRegex(eh.rm.InputError, 'attestation'):
            eh.freeze(inventory, calibration_path, 'sift', 'reason', False)
        report = eh.read_json(calibration_path)
        report['bindings']['source_sha256']['matcher'] = '0' * 64
        calibration_path.write_text(json.dumps(report))
        with self.assertRaisesRegex(eh.rm.InputError, 'bindings changed'):
            eh.freeze(inventory, calibration_path, 'sift', 'reason', True)

    def test_changed_frozen_policy_source_and_runtime_refused(self):
        inventory, _, freeze_path = self.freeze_fixture()
        original = eh.read_json(freeze_path)
        for key in ('policy', 'source_sha256', 'runtime'):
            frozen = copy.deepcopy(original)
            frozen['bindings'][key] = {'changed': True}
            freeze_path.write_text(json.dumps(frozen))
            with self.subTest(key=key), self.assertRaisesRegex(eh.rm.InputError, 'Frozen source'):
                eh.test_holdout(inventory, freeze_path, self.root / 'output.json')

    def test_execution_errors_are_not_safe_abstentions(self):
        inventory = self.load()
        with patch.object(eh.rm, 'run', side_effect=RuntimeError('synthetic failure')):
            result = eh.run_role(inventory, 'test', 'sift')
        self.assertFalse(result['metrics_available'])
        self.assertIsNone(result['metrics'])
        self.assertEqual(len(result['execution_errors']), 1)
        self.assertEqual(result['cases'][0]['status'], 'execution_error')

    def test_malformed_matcher_acceptance_is_execution_error(self):
        inventory = self.load()
        for bad in (True, None, '1', 'abstain', 7):
            with patch.object(eh.rm, 'run', return_value={'decision': 'denomination_experiment', 'selected_reference_label': bad}):
                result = eh.run_role(inventory, 'test', 'sift')
            self.assertFalse(result['metrics_available'])

    def test_costs_abstention_foreign_nonmoney_and_slices(self):
        self.add_sample('test', 'hundred', 100, 'folded')
        self.add_sample('test', 'occluded', 5, 'occluded')
        self.add_sample('test', 'foreign', 'unknown', 'foreign')
        self.add_sample('test', 'receipt', 'unknown', 'non_money', [])
        self.add_sample('test', 'reproduction', 'unknown', 'reproduction', [])
        self.add_sample('test', 'screen', 'unknown', 'screen', [])
        inventory = self.load()
        predictions = {'test': 100, 'hundred': 1, 'occluded': 'abstain', 'foreign': 5, 'receipt': 'abstain',
                       'reproduction': 'abstain', 'screen': 'abstain'}
        rows = [r for r in inventory['samples'].values() if r['role'] == 'test']
        result = eh.summarize(rows, predictions, inventory['groups'])
        self.assertEqual(result['critical_100_vs_1'], {'expected_100_accepted_1': 1, 'expected_1_accepted_100': 1})
        self.assertEqual(result['costly_confusions'][0]['absolute_error_sar_per_decision'], 99)
        self.assertEqual(result['overall']['wrong_spoken_count'], 3)
        self.assertEqual(result['overall']['abstention_rate']['numerator'], 4)
        self.assertEqual(result['by_condition']['foreign']['unknown_false_acceptance_rate']['numerator'], 1)
        self.assertEqual(result['per_denomination']['100']['wrong_amount_counts']['1'], 1)
        self.assertEqual(result['by_condition']['non_money']['sample_count'], 1)
        self.assertTrue(eh.coverage(rows, inventory['groups'])['missing_cells'])

    def test_existing_output_never_overwritten_and_invalid_cli_is_refused(self):
        self.save()
        output = self.root / 'existing.json'
        output.write_text('preserve')
        self.assertEqual(eh.main(['validate', '--inventory', str(self.inventory_path), '--references', str(self.reference_path),
                                  '--allow-synthetic', '--output', str(output)]), 2)
        self.assertEqual(output.read_text(), 'preserve')

    def test_calibration_artifact_cannot_omit_cases_or_tamper_metrics(self):
        inventory, calibration_path, _ = self.freeze_fixture()
        original = eh.read_json(calibration_path)
        malformed = copy.deepcopy(original)
        malformed['methods'] = {name: {'metrics_available': True, 'execution_errors': []} for name in eh.rm.ALGORITHMS}
        with self.assertRaises(eh.rm.InputError):
            eh.check_calibration_report(inventory, malformed)
        malformed = copy.deepcopy(original)
        malformed['methods']['sift']['metrics']['overall']['wrong_spoken_count'] = 12
        with self.assertRaisesRegex(eh.rm.InputError, 'metrics disagree'):
            eh.check_calibration_report(inventory, malformed)
        malformed = copy.deepcopy(original)
        malformed['methods']['sift']['cases'][0]['sample_id'] = 'test'
        with self.assertRaisesRegex(eh.rm.InputError, 'case identity'):
            eh.check_calibration_report(inventory, malformed)

    def test_oversized_calibration_elapsed_integer_is_refused_cleanly(self):
        inventory, calibration_path, _ = self.freeze_fixture()
        report = eh.read_json(calibration_path)
        report['methods']['sift']['cases'][0]['elapsed_seconds'] = 10 ** 400
        with self.assertRaisesRegex(eh.rm.InputError, 'elapsed time invalid'):
            eh.check_calibration_report(inventory, report)

    def test_artifact_top_level_lists_are_cleanly_rejected(self):
        inventory, calibration_path, freeze_path = self.freeze_fixture()
        calibration_path.write_text('[]')
        with self.assertRaises(eh.rm.InputError):
            eh.freeze(inventory, calibration_path, 'sift', 'reason', True)
        freeze_path.write_text('[]')
        with self.assertRaises(eh.rm.InputError):
            eh.test_holdout(inventory, freeze_path, self.root / 'output.json')

    def test_copied_freeze_and_refreeze_cannot_reuse_exposed_dataset(self):
        inventory, calibration_path, freeze_path = self.freeze_fixture()
        copied = self.root / 'copied-freeze.json'
        copied.write_bytes(freeze_path.read_bytes())
        with patch.object(eh.rm, 'run', self.fake_run):
            eh.test_holdout(inventory, freeze_path, self.root / 'output.json')
        with self.assertRaises(FileExistsError):
            eh.test_holdout(inventory, copied, self.root / 'output-second.json')
        with self.assertRaisesRegex(eh.rm.InputError, 'already has a started'):
            eh.freeze(inventory, calibration_path, 'orb', 'reason', True)

    def test_reference_mutation_during_run_is_error_not_frozen_result(self):
        inventory = self.load()
        original = self.reference_path.read_bytes()
        def mutate(references, query, algorithm):
            self.reference_path.write_bytes(original + b' ')
            return self.fake_run(references, query, algorithm)
        with patch.object(eh.rm, 'run', side_effect=mutate):
            result = eh.run_role(inventory, 'test', 'sift')
        self.assertFalse(result['metrics_available'])
        self.assertIn('Reference manifest changed', result['execution_errors'][0]['reason'])

    def test_inventory_mutation_after_load_refuses_new_binding(self):
        inventory = self.load()
        self.inventory_path.write_bytes(self.inventory_path.read_bytes() + b' ')
        with self.assertRaisesRegex(eh.rm.InputError, 'Inventory changed'):
            eh.bindings(inventory)

    def test_test_report_error_is_retained_with_no_aggregate_metrics(self):
        inventory, _, freeze_path = self.freeze_fixture()
        output = self.root / 'error-result.json'
        with patch.object(eh.rm, 'run', side_effect=RuntimeError('Synthetic error')):
            report = eh.test_holdout(inventory, freeze_path, output)
        self.assertTrue(output.is_file())
        self.assertFalse(report['result']['metrics_available'])
        self.assertIsNone(report['result']['metrics'])
        self.assertTrue(eh.dataset_receipt(inventory).is_file())

    def test_actual_opencv_synthetic_smoke_all_methods_abstain_on_flat_frames(self):
        inventory = self.load()
        report = eh.calibrate(inventory)
        self.assertEqual(set(report['methods']), set(eh.rm.ALGORITHMS))
        for method in report['methods'].values():
            self.assertTrue(method['metrics_available'])
            self.assertEqual(method['cases'][0]['experimental_label'], 'abstain')
            self.assertEqual(method['metrics']['overall']['correct_spoken_count'], 0)


if __name__ == '__main__':
    unittest.main()
