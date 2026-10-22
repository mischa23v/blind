"""Synthetic plumbing/security tests only. No banknotes, encoder or model downloads."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np
from PIL import Image

SPEC = importlib.util.spec_from_file_location("currency_training", Path(__file__).resolve().parents[1] / "currency_training.py")
ct = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ct)


def fixture(unknown=False):
    labels = ct.LABELS + (["unknown"] if unknown else [])
    records = []
    for split in ct.SPLITS:
        for label in labels:
            for sample in range(2):
                name = f"{split}/{label}/{sample}"
                records.append({
                    "id": name, "image": name + ".png", "image_sha256": ct.digest_bytes(name.encode()),
                    "image_size": [100, 50], "bbox": [0, 0, 100, 50], "label": label,
                    "group_id": name, "group_kind": "negative_scene" if label == "unknown" else "physical_note",
                    "split": split, "negative_kind": ("non_money" if sample == 0 else "foreign_currency")
                    if label == "unknown" else None,
                })
    return {"schema_version": 1, "labels": labels, "preprocessing": copy.deepcopy(ct.PREPROCESS),
            "grouping_review": {"complete": True, "reviewer": "synthetic_test", "method": "synthetic independent IDs"},
            "records": records}


def embeddings(manifest):
    rng = np.random.default_rng(12)
    x = rng.normal(0, 0.02, (len(manifest["records"]), 256))
    for i, row in enumerate(manifest["records"]):
        x[i, manifest["labels"].index(row["label"])] += 4
    return x.astype(np.float32)


class ManifestTests(unittest.TestCase):
    def test_canonical_coverage(self):
        summary = ct.validate_manifest(fixture(), verify_files=False)
        self.assertFalse(summary["unknown_training_gate_passed"])
        self.assertFalse(summary["release_approved"])
        self.assertEqual(summary["counts"]["test"]["500"], 2)

    def test_nine_class_negative_coverage(self):
        summary = ct.validate_manifest(fixture(True), verify_files=False)
        self.assertTrue(summary["unknown_training_gate_passed"])
        self.assertFalse(summary["release_approved"])

    def test_partial_requires_note_identity(self):
        m = fixture(True)
        row = next(r for r in m["records"] if r["label"] == "unknown")
        row["negative_kind"] = "partial_note"
        with self.assertRaisesRegex(ValueError, "requires at least 1 physical_note_ids"):
            ct.validate_manifest(m, verify_files=False)

    def test_multiple_requires_two_note_identities(self):
        m = fixture(True)
        row = next(r for r in m["records"] if r["label"] == "unknown")
        row["negative_kind"] = "multiple_notes"
        row["physical_note_ids"] = [m["records"][0]["group_id"]]
        with self.assertRaisesRegex(ValueError, "requires at least 2 physical_note_ids"):
            ct.validate_manifest(m, verify_files=False)

    def test_partial_cannot_leak_known_note(self):
        m = fixture(True)
        row = next(r for r in m["records"] if r["label"] == "unknown" and r["split"] == "test")
        row["negative_kind"] = "partial_note"
        row["physical_note_ids"] = [m["records"][0]["group_id"]]
        with self.assertRaisesRegex(ValueError, "reused by full/partial/multiple"):
            ct.validate_manifest(m, verify_files=False)

    def test_multiple_cannot_leak_known_note(self):
        m = fixture(True)
        row = next(r for r in m["records"] if r["label"] == "unknown" and r["split"] == "calibration")
        row["negative_kind"] = "multiple_notes"
        row["physical_note_ids"] = [m["records"][0]["group_id"], "new-note"]
        with self.assertRaisesRegex(ValueError, "reused by full/partial/multiple"):
            ct.validate_manifest(m, verify_files=False)

    def test_partial_and_multiple_same_partition_allowed(self):
        m = fixture(True)
        rows = [r for r in m["records"] if r["label"] == "unknown" and r["split"] == "train"]
        rows[0]["negative_kind"] = "partial_note"
        rows[0]["physical_note_ids"] = [m["records"][0]["group_id"]]
        rows[1]["negative_kind"] = "multiple_notes"
        rows[1]["physical_note_ids"] = [m["records"][0]["group_id"], m["records"][2]["group_id"]]
        self.assertFalse(ct.validate_manifest(m, verify_files=False)["unknown_training_gate_passed"])

    def test_unassigned_groups_block(self):
        m = fixture()
        m["records"][0]["group_id"] = None
        with self.assertRaisesRegex(ValueError, "Missing physical-note"):
            ct.validate_manifest(m, verify_files=False)

    def test_human_review_required(self):
        m = fixture()
        m["grouping_review"]["complete"] = False
        with self.assertRaisesRegex(ValueError, "human"):
            ct.validate_manifest(m, verify_files=False)

    def test_group_leakage(self):
        m = fixture()
        m["records"][16]["group_id"] = m["records"][0]["group_id"]
        with self.assertRaisesRegex(ValueError, "Leakage: physical note"):
            ct.validate_manifest(m, verify_files=False)

    def test_physical_identity_cannot_change_denomination(self):
        m = fixture()
        m["records"][2]["group_id"] = m["records"][0]["group_id"]
        with self.assertRaisesRegex(ValueError, "conflicting denomination"):
            ct.validate_manifest(m, verify_files=False)

    def test_whitespace_cannot_disguise_group_identity(self):
        m = fixture()
        m["records"][0]["group_id"] += " "
        with self.assertRaisesRegex(ValueError, "surrounding whitespace"):
            ct.validate_manifest(m, verify_files=False)

    def test_same_scene_leakage(self):
        m = fixture()
        m["records"][16]["image"] = m["records"][0]["image"]
        with self.assertRaisesRegex(ValueError, "Leakage: source image"):
            ct.validate_manifest(m, verify_files=False)

    def test_duplicate_bytes_leakage(self):
        m = fixture()
        m["records"][16]["image_sha256"] = m["records"][0]["image_sha256"]
        with self.assertRaisesRegex(ValueError, "Leakage: identical image bytes"):
            ct.validate_manifest(m, verify_files=False)

    def test_missing_class_blocks(self):
        m = fixture()
        m["records"] = [r for r in m["records"] if not (r["split"] == "test" and r["label"] == "500")]
        with self.assertRaisesRegex(ValueError, "Every class must occur in test"):
            ct.validate_manifest(m, verify_files=False)

    def test_changed_preprocessing_blocks(self):
        m = fixture()
        m["preprocessing"]["crop_margin"] = 0.1
        with self.assertRaisesRegex(ValueError, "Preprocessing"):
            ct.validate_manifest(m, verify_files=False)

    def test_path_escape(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(ValueError, "escapes"):
                ct.within(root, "../outside.jpg")


class VOCTests(unittest.TestCase):
    def make_dataset(self, root):
        root = Path(root)
        (root / "images").mkdir()
        (root / "annotations").mkdir()
        image = Image.new("RGB", (100, 50), (10, 20, 30))
        image.save(root / "images" / "note.png")
        (root / "annotations" / "note.xml").write_text(
            '<annotation><filename>note.png</filename><size><width>100</width><height>50</height></size>'
            '<object><name>five</name><bndbox><xmin>1</xmin><ymin>1</ymin><xmax>100</xmax><ymax>50</ymax>'
            '</bndbox></object></annotation>')
        return root

    def test_voc_boxes_are_converted_and_not_split(self):
        with tempfile.TemporaryDirectory() as temp:
            root = self.make_dataset(temp)
            m = ct.index_voc(root, root / "annotations", root / "images", {"five": "5"})
            r = m["records"][0]
            self.assertEqual(r["bbox"], [0, 0, 100, 50])
            self.assertIsNone(r["split"])
            self.assertIsNone(r["group_id"])
            self.assertFalse(m["grouping_review"]["complete"])
            crop = ct.crop_image(root, r)
            self.assertEqual(crop.size, (224, 224))
            self.assertEqual(crop.getpixel((0, 0)), (10, 20, 30))

    def test_unmapped_label_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            root = self.make_dataset(temp)
            with self.assertRaisesRegex(ValueError, "Unmapped VOC"):
                ct.index_voc(root, root / "annotations", root / "images", {})

    def test_xml_entities_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = self.make_dataset(temp)
            (root / "annotations" / "note.xml").write_text('<!DOCTYPE x [<!ENTITY x "bad">]><x/>')
            with self.assertRaisesRegex(ValueError, "Unsafe/oversized XML"):
                ct.index_voc(root, root / "annotations", root / "images", {"five": "5"})


class SecurityTests(unittest.TestCase):
    def test_lambda_rejected(self):
        for name in ("Lambda", "TFOpLambda", "MyCustomLayer", "__lambda__"):
            with self.subTest(name=name):
                with self.assertRaisesRegex(ValueError, "Unapproved serialized"):
                    ct.inspect_keras_config({"class_name": "Model", "config": {"layers": [{"class_name": name}]}})

    def test_custom_module_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unapproved Keras module"):
            ct.inspect_keras_config({"class_name": "Dense", "module": "attacker.layers"})

    def test_known_standard_config_allowed(self):
        ct.inspect_keras_config({"class_name": "Model", "config": {"layers": [
            {"class_name": "Dense", "config": {"activation": "relu", "kernel_initializer": {"class_name": "GlorotUniform"}}}]}})

    def test_wrong_encoder_bytes_rejected_before_h5py_import(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "encoder.h5"
            path.write_bytes(b"not a model")
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                ct.verified_encoder_bytes(path)

    def test_symlink_encoder_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "encoder.h5"
            path.write_bytes(b"not a model")
            link = Path(temp) / "link.h5"
            link.symlink_to(path)
            with self.assertRaisesRegex(ValueError, "symlink"):
                ct.verified_encoder_bytes(link)


class HeadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = fixture(True)
        cls.features = embeddings(cls.manifest)
        cls.head = ct.fit_head(cls.features, cls.manifest)

    def test_probability_and_label_contract(self):
        p = ct.scores(self.head, self.features)
        self.assertEqual(p.shape, (54, 9))
        np.testing.assert_allclose(p.sum(axis=1), 1.0, atol=1e-10)
        self.assertEqual(self.head["labels"], ct.LABELS + ["unknown"])
        self.assertFalse(self.head["release_approved"])

    def test_test_features_cannot_influence_fitting(self):
        poisoned = self.features.copy()
        for i, r in enumerate(self.manifest["records"]):
            if r["split"] == "test":
                poisoned[i] = np.nan
        head = ct.fit_head(poisoned, self.manifest)
        for key in ("mean", "scale", "coef", "intercept", "temperature"):
            np.testing.assert_array_equal(head[key], self.head[key])

    def test_calibration_cannot_change_head_or_scaler(self):
        changed = self.features.copy()
        for i, r in enumerate(self.manifest["records"]):
            if r["split"] == "calibration":
                changed[i] *= -1
        head = ct.fit_head(changed, self.manifest)
        for key in ("mean", "scale", "coef", "intercept"):
            np.testing.assert_array_equal(head[key], self.head[key])

    def test_folded_head_parity(self):
        w, b = ct.fold_head(self.head)
        np.testing.assert_allclose(ct.softmax(self.features @ w + b), ct.scores(self.head, self.features), atol=2e-5)

    def test_metrics_are_explicitly_crop_only(self):
        report = ct.metrics(self.head, self.features, self.manifest, "test")
        self.assertEqual(report["count"], 18)
        self.assertFalse(report["release_approved"])
        self.assertIn("Ground-truth crops only", report["scope"])

    def test_bad_head_scale_rejected(self):
        bad = copy.deepcopy(self.head)
        bad["scale"][0] = 0
        with self.assertRaisesRegex(ValueError, "non-positive"):
            ct.fold_head(bad)

    def test_cache_corruption_detected(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp)
            np.save(p / "embeddings.npy", self.features, allow_pickle=False)
            ct.write_json(p / "manifest.json", self.manifest)
            ct.write_json(p / "cache.json", {"encoder_sha256": ct.ENCODER_SHA256,
                "manifest_sha256": ct.canonical_digest(self.manifest), "preprocessing": ct.PREPROCESS,
                "embeddings_sha256": ct.digest_file(p / "embeddings.npy")})
            x, _, _ = ct.read_cache(p)
            np.testing.assert_array_equal(x, self.features)
            with (p / "embeddings.npy").open("ab") as f:
                f.write(b"changed")
            with self.assertRaisesRegex(ValueError, "Cache bytes changed"):
                ct.read_cache(p)


if __name__ == "__main__":
    unittest.main()
