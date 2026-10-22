"""SYNTHETIC harness unit tests only. These are NOT recognition-model tests."""

from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
import io
import json
from pathlib import Path
import tempfile
import unittest

import evaluate as ev


def synthetic_fixture():
    """Generated labels test arithmetic/validation, never an accuracy claim."""
    manifest = []
    for split in ("train", "calibration", "test"):
        for value in ev.DENOMINATIONS:
            variants = ("paper", "polymer") if value == 5 else ("paper",)
            for variant in variants:
                group = f"{split}-physical-{value}-{variant}"
                for side in ("front", "back"):
                    for condition in sorted(ev.POSITIVE_CONDITIONS):
                        manifest.append({"sample_id": f"{group}-{side}-{condition}",
                                         "group_id": group, "split": split, "expected": value,
                                         "condition": condition, "side": side, "variant": variant})
        for condition in sorted(ev.NEGATIVE_CONDITIONS):
            row = {"sample_id": f"{split}-{condition}", "group_id": f"{split}-{condition}",
                   "split": split, "expected": "unknown", "condition": condition,
                   "side": "n/a", "variant": "n/a"}
            if condition == "multiple_notes":
                row["physical_note_ids"] = [f"{split}-extra-note-1", f"{split}-extra-note-2"]
            elif condition == "partial_note":
                row["physical_note_ids"] = [f"{split}-partial-note-1"]
            manifest.append(row)
    predictions = [{"sample_id": row["sample_id"],
                    "spoken_denomination": row["expected"] if row["expected"] != "unknown" else "abstain"}
                   for row in manifest if row["split"] == "test"]
    metadata = {"model_id": "SYNTHETIC-HARNESS-ONLY", "dataset_id": "SYNTHETIC-HARNESS-ONLY",
                "decision_policy_id": "SYNTHETIC-HARNESS-ONLY", "frozen_before_test": True,
                "data_kind": "synthetic"}
    return manifest, predictions, metadata


class EvaluationTests(unittest.TestCase):
    def setUp(self):
        self.manifest, self.predictions, self.metadata = synthetic_fixture()

    def run_evaluation(self, **kwargs):
        return ev.evaluate(self.manifest, self.predictions, self.metadata,
                           allow_synthetic=True, **kwargs)

    def first_row(self, **fields):
        return next(row for row in self.manifest if row["split"] == "test"
                    and all(row.get(key) == value for key, value in fields.items()))

    def set_prediction(self, sample_id, output):
        next(row for row in self.predictions if row["sample_id"] == sample_id)["spoken_denomination"] = output

    def test_synthetic_fixture_never_claims_real_accuracy(self):
        result = self.run_evaluation()
        self.assertIn("NOT MODEL ACCURACY", result["evidence_scope"])
        self.assertFalse(result["release_approval"])
        self.assertEqual(result["overall"]["spoken_decision_precision"]["rate"], 1)
        self.assertLess(result["overall"]["error_free_spoken_group_rate"]["wilson_95"][0], 1)
        self.assertEqual(result["overall"]["unknown_false_acceptance_rate"]["rate"], 0)
        self.assertGreater(result["overall"]["unknown_group_false_acceptance_rate"]["wilson_95"][1], 0)

    def test_synthetic_requires_explicit_opt_in(self):
        with self.assertRaisesRegex(ev.ValidationError, "Synthetic"):
            ev.evaluate(self.manifest, self.predictions, self.metadata)

    def test_requires_frozen_policy(self):
        self.metadata["frozen_before_test"] = False
        with self.assertRaisesRegex(ev.ValidationError, "frozen"):
            self.run_evaluation()

    def test_requires_run_identity(self):
        del self.metadata["model_id"]
        with self.assertRaisesRegex(ev.ValidationError, "model_id"):
            self.run_evaluation()

    def test_100_to_1_and_1_to_100_counted_separately(self):
        self.set_prediction(self.first_row(expected=100)["sample_id"], 1)
        self.set_prediction(self.first_row(expected=1)["sample_id"], 100)
        result = self.run_evaluation()
        self.assertEqual(result["critical_100_vs_1"],
                         {"expected_100_spoken_1": 1, "expected_1_spoken_100": 1})
        self.assertEqual(result["per_denomination"]["100"]["confusions_out"]["1"], 1)
        self.assertEqual(result["overall"]["wrong_spoken_count"], 2)
        self.assertEqual({row["direction"] for row in result["costly_confusions"]},
                         {"overstatement", "understatement"})
        self.assertTrue(all(row["absolute_error_sar_per_decision"] == 99 for row in result["costly_confusions"]))

    def test_all_negative_categories_false_accepts_reduce_precision(self):
        for condition in ev.NEGATIVE_CONDITIONS:
            self.set_prediction(self.first_row(condition=condition)["sample_id"], 100)
        result = self.run_evaluation()
        self.assertEqual(result["overall"]["unknown_false_acceptance_rate"]["rate"], 1)
        self.assertEqual(result["confusion_matrix"]["unknown"]["100"], 4)
        self.assertEqual(result["per_denomination"]["100"]["precision"]["denominator"], 10)
        for condition in ev.NEGATIVE_CONDITIONS:
            self.assertEqual(result["by_condition"][condition]["wrong_spoken_count"], 1)

    def test_all_abstentions_do_not_report_perfect_precision(self):
        for prediction in self.predictions:
            prediction["spoken_denomination"] = "abstain"
        result = self.run_evaluation()
        self.assertIsNone(result["overall"]["spoken_decision_precision"]["rate"])
        self.assertIsNone(result["overall"]["error_free_spoken_group_rate"]["wilson_95"])
        self.assertEqual(result["overall"]["abstention_rate"]["rate"], 1)
        self.assertEqual(result["overall"]["positive_correct_coverage"]["rate"], 0)

    def test_one_group_error_affects_group_bound_once(self):
        row = self.first_row(expected=100)
        group_rows = [r for r in self.manifest if r["group_id"] == row["group_id"]]
        for item in group_rows:
            self.set_prediction(item["sample_id"], 1)
        result = self.run_evaluation()["overall"]
        self.assertEqual(result["wrong_spoken_count"], 6)
        self.assertEqual(result["error_free_spoken_group_rate"]["numerator"], 8)
        self.assertEqual(result["error_free_spoken_group_rate"]["denominator"], 9)

    def test_shared_notes_merge_multiple_scene_components(self):
        single = self.first_row(expected=100)
        multiple = self.first_row(condition="multiple_notes")
        multiple["physical_note_ids"][0] = single["group_id"]
        result = self.run_evaluation()
        self.assertEqual(result["overall"]["independent_group_count"], 12)
        self.set_prediction(multiple["sample_id"], 100)
        self.assertEqual(self.run_evaluation()["overall"]["error_free_spoken_group_rate"]["numerator"], 8)

    def test_split_leakage_on_group_is_rejected(self):
        self.first_row(expected=100)["group_id"] = "train-physical-100-paper"
        with self.assertRaisesRegex(ev.ValidationError, "leakage"):
            self.run_evaluation()

    def test_split_leakage_inside_multiple_scene_is_rejected(self):
        self.first_row(condition="multiple_notes")["physical_note_ids"][0] = "calibration-physical-1-paper"
        with self.assertRaisesRegex(ev.ValidationError, "leakage"):
            self.run_evaluation()

    def test_same_physical_note_across_different_group_names_is_rejected(self):
        self.first_row(expected=1)["physical_note_ids"] = ["train-physical-1-paper"]
        with self.assertRaisesRegex(ev.ValidationError, "leakage"):
            self.run_evaluation()

    def test_duplicate_sample_id_is_rejected(self):
        self.manifest.append(deepcopy(self.manifest[0]))
        with self.assertRaisesRegex(ev.ValidationError, "Duplicate sample_id"):
            self.run_evaluation()

    def test_duplicate_image_hash_is_rejected(self):
        self.manifest[0]["image_sha256"] = "a" * 64
        self.manifest[1]["image_sha256"] = "a" * 64
        with self.assertRaisesRegex(ev.ValidationError, "duplicate image content"):
            self.run_evaluation()

    def test_same_note_cannot_change_denomination(self):
        self.first_row(expected=100)["expected"] = 1
        with self.assertRaisesRegex(ev.ValidationError, "conflicting"):
            self.run_evaluation()

    def test_split_must_not_be_missing(self):
        self.manifest = [r for r in self.manifest if r["split"] != "calibration"]
        with self.assertRaisesRegex(ev.ValidationError, "calibration"):
            self.run_evaluation()

    def test_each_coverage_cell_is_required(self):
        # Each deletion fails, including 1/100, 20/200, paper/polymer, both sides,
        # folded/occluded, foreign/non-money/multiple/partial scenes.
        for row in [r for r in self.manifest if r["split"] == "test"]:
            with self.subTest(sample=row["sample_id"]):
                shortened = [r for r in self.manifest if r["sample_id"] != row["sample_id"]]
                with self.assertRaisesRegex(ev.ValidationError, "coverage insufficient"):
                    ev.evaluate(shortened, self.predictions, self.metadata, allow_synthetic=True)

    def test_repeated_frames_do_not_meet_more_group_coverage(self):
        original = self.first_row(expected=1)
        for index in range(10):
            row = dict(original, sample_id=f"repeat-{index}")
            self.manifest.append(row)
            self.predictions.append({"sample_id": row["sample_id"], "spoken_denomination": 1})
        with self.assertRaisesRegex(ev.ValidationError, "need 2 independent groups"):
            self.run_evaluation(min_groups=2)

    def test_invalid_minimum_is_rejected(self):
        for value in (0, -1, True, 1.5):
            with self.subTest(value=value), self.assertRaises(ev.ValidationError):
                self.run_evaluation(min_groups=value)

    def test_missing_prediction_is_not_silently_dropped(self):
        self.predictions.pop()
        with self.assertRaisesRegex(ev.ValidationError, "Missing predictions"):
            self.run_evaluation()

    def test_duplicate_prediction_is_rejected(self):
        self.predictions.append(dict(self.predictions[0]))
        with self.assertRaisesRegex(ev.ValidationError, "Duplicate prediction"):
            self.run_evaluation()

    def test_prediction_for_non_test_sample_is_rejected(self):
        self.predictions.append({"sample_id": self.manifest[0]["sample_id"], "spoken_denomination": 1})
        with self.assertRaisesRegex(ev.ValidationError, "test samples only"):
            self.run_evaluation()

    def test_unknown_prediction_id_is_rejected(self):
        self.predictions[0]["sample_id"] = "not-in-manifest"
        with self.assertRaisesRegex(ev.ValidationError, "unknown sample"):
            self.run_evaluation()

    def test_unsupported_output_and_boolean_are_rejected(self):
        for value in (True, 100.0, "100", "unknown", 2, None):
            with self.subTest(value=value):
                self.predictions[0]["spoken_denomination"] = value
                with self.assertRaises(ev.ValidationError):
                    self.run_evaluation()

    def test_malformed_manifest_categories_fail_cleanly(self):
        for field in ("split", "condition", "side", "variant", "group_id"):
            for value in ([], {}, None, True, ""):
                with self.subTest(field=field, value=value):
                    manifest = deepcopy(self.manifest)
                    manifest[0][field] = value
                    with self.assertRaises(ev.ValidationError):
                        ev.evaluate(manifest, self.predictions, self.metadata, allow_synthetic=True)

    def test_malformed_data_kind_fails_cleanly(self):
        self.metadata["data_kind"] = []
        with self.assertRaisesRegex(ev.ValidationError, "data_kind"):
            self.run_evaluation()

    def test_multiple_scene_cannot_claim_single_denomination(self):
        self.first_row(condition="multiple_notes")["expected"] = 100
        with self.assertRaisesRegex(ev.ValidationError, "expected unknown"):
            self.run_evaluation()

    def test_multiple_scene_requires_physical_identities(self):
        del self.first_row(condition="multiple_notes")["physical_note_ids"]
        with self.assertRaisesRegex(ev.ValidationError, "at least two"):
            self.run_evaluation()

    def test_partial_note_requires_unknown_not_occluded_positive(self):
        self.first_row(condition="partial_note")["expected"] = 100
        with self.assertRaisesRegex(ev.ValidationError, "expected unknown"):
            self.run_evaluation()

    def test_partial_note_requires_physical_identities(self):
        partial = self.first_row(condition="partial_note")
        for value in (None, []):
            with self.subTest(identities=value):
                if value is None:
                    partial.pop("physical_note_ids", None)
                else:
                    partial["physical_note_ids"] = value
                with self.assertRaisesRegex(ev.ValidationError, "partial_note.*at least one"):
                    self.run_evaluation()

    def test_partial_note_coverage_cannot_be_replaced_by_occluded_positive(self):
        self.manifest = [row for row in self.manifest
                         if not (row["split"] == "test" and row["condition"] == "partial_note")]
        with self.assertRaisesRegex(ev.ValidationError, "coverage insufficient.*partial_note"):
            self.run_evaluation()

    def test_partial_note_cross_split_leakage_to_positive_is_rejected(self):
        self.first_row(condition="partial_note")["physical_note_ids"] = ["train-physical-100-paper"]
        with self.assertRaisesRegex(ev.ValidationError, "leakage"):
            self.run_evaluation()

    def test_partial_note_cross_split_leakage_to_multiple_is_rejected(self):
        self.first_row(condition="partial_note")["physical_note_ids"] = ["calibration-extra-note-1"]
        with self.assertRaisesRegex(ev.ValidationError, "leakage"):
            self.run_evaluation()

    def test_partial_positive_and_multiple_share_component_identity(self):
        partial = self.first_row(condition="partial_note")
        multiple = self.first_row(condition="multiple_notes")
        single = self.first_row(expected=100)
        partial["physical_note_ids"] = [single["group_id"]]
        multiple["physical_note_ids"][0] = single["group_id"]
        result = self.run_evaluation()
        self.assertEqual(result["overall"]["independent_group_count"], 11)
        self.assertEqual(result["coverage"]["partial_note"]["independent_groups"], 1)
        self.set_prediction(partial["sample_id"], 100)
        result = self.run_evaluation()
        self.assertEqual(result["by_condition"]["partial_note"]["unknown_false_acceptance_rate"]["rate"], 1)
        self.assertEqual(result["overall"]["error_free_spoken_group_rate"]["numerator"], 8)

    def test_wilson_matches_known_values_and_empty_is_undefined(self):
        self.assertIsNone(ev.wilson(0, 0))
        self.assertAlmostEqual(ev.wilson(0, 10)[1], 0.2775328, places=6)
        self.assertAlmostEqual(ev.wilson(10, 10)[0], 0.7224672, places=6)
        self.assertAlmostEqual(ev.wilson(5, 10)[0], 0.2365931, places=6)

    def test_cli_writes_provenance_and_refuses_overwriting_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            manifest, predictions, metadata, output = [directory / name for name in
                ("manifest.jsonl", "predictions.jsonl", "metadata.json", "report.json")]
            manifest.write_text("\n".join(map(json.dumps, self.manifest)), encoding="utf-8")
            predictions.write_text("\n".join(map(json.dumps, self.predictions)), encoding="utf-8")
            metadata.write_text(json.dumps(self.metadata), encoding="utf-8")
            args = ["--manifest", str(manifest), "--predictions", str(predictions),
                    "--run-metadata", str(metadata), "--allow-synthetic", "--output", str(output)]
            self.assertEqual(ev.main(args), 0)
            report = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(len(report["input_sha256"]["manifest"]), 64)
            with redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(ev.main(args[:-1] + [str(manifest)]), 2)
            self.assertIn("must not overwrite", errors.getvalue())

    def test_cli_refusal_emits_no_metric_report(self):
        with tempfile.TemporaryDirectory() as directory:
            bad = Path(directory) / "bad.jsonl"
            bad.write_text("not json\n", encoding="utf-8")
            with redirect_stderr(io.StringIO()) as errors, redirect_stdout(io.StringIO()) as output:
                result = ev.main(["--manifest", str(bad), "--predictions", str(bad), "--run-metadata", str(bad)])
            self.assertEqual(result, 2)
            self.assertEqual(output.getvalue(), "")
            self.assertIn("Evaluation refused", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
