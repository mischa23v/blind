#!/usr/bin/env python3
"""Offline Saudi crop classifier preparation. No automatic downloads or random splits.

The only allowed encoder is Microsoft's exact pinned BankNote-Net HDF5. All
outputs are experimental until separately evaluated on real iPhone captures.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import io
import json
import math
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

LABELS = ["1", "5", "10", "20", "50", "100", "200", "500"]
SPLITS = ("train", "calibration", "test")
ENCODER_SHA256 = "dac0226b785ec22ae3b198a386b0f5842affdf9e18ab49cd4de31cbf8cb28477"
ENCODER_URL = "https://github.com/microsoft/banknote-net/blob/main/models/banknote_net_encoder.h5"
PREPROCESS = {
    "crop": "axis_aligned_bbox", "crop_margin": 0.0,
    "bbox_format": "xyxy_zero_based_half_open", "orientation": "upright_pixels",
    "input_width": 224, "input_height": 224, "color": "RGB",
    "resize": "bilinear_stretch", "vision_image_crop_and_scale": "scaleFill",
    "scale": 1.0 / 255.0, "bias": [0.0, 0.0, 0.0],
}
ALLOWED_KERAS_CLASSES = {
    "Functional", "Model", "Sequential", "InputLayer", "Conv2D",
    "DepthwiseConv2D", "BatchNormalization", "ReLU", "Activation",
    "ZeroPadding2D", "GlobalAveragePooling2D", "Dense", "Dropout", "Add",
    "Flatten", "Reshape", "AveragePooling2D", "MaxPooling2D", "Concatenate",
    "GlorotUniform", "GlorotNormal", "VarianceScaling", "RandomNormal",
    "RandomUniform", "HeNormal", "HeUniform", "Zeros", "Ones", "L1L2", "L2",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest_bytes(value):
    return hashlib.sha256(value).hexdigest()


def digest_file(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_digest(value):
    return digest_bytes(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                   allow_nan=False).encode())


def read_json(path):
    return json.loads(Path(path).read_text())


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n")


def within(root, relative):
    root = Path(root).resolve()
    p = Path(relative)
    require(not p.is_absolute(), f"Path must be relative to dataset root: {relative}")
    target = (root / p).resolve()
    require(target.is_relative_to(root), f"Path escapes dataset root: {relative}")
    require(target.is_file(), f"Missing file: {target}")
    return target


def image_size(path):
    from PIL import Image
    with Image.open(path) as im:
        require(im.getexif().get(274, 1) == 1,
                f"Normalize EXIF orientation and update boxes first: {path}")
        require(im.width > 0 and im.height > 0, f"Invalid image: {path}")
        return [im.width, im.height]


def index_voc(root, annotation_dir, images_dir, label_map):
    """Create an UNASSIGNED manifest. Never infer group IDs from filenames."""
    root = Path(root).resolve()
    annotation_dir, images_dir = Path(annotation_dir).resolve(), Path(images_dir).resolve()
    require(annotation_dir.is_relative_to(root) and images_dir.is_relative_to(root),
            "Annotation and image directories must be below dataset root")
    require(all(v in LABELS + ["unknown"] for v in label_map.values()),
            "Label map values must be exact canonical labels")
    images = defaultdict(list)
    for p in sorted(images_dir.rglob("*")):
        if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".bmp", ".webp"):
            images[p.name].append(p)
    records = []
    for annotation in sorted(annotation_dir.rglob("*.xml")):
        raw = annotation.read_bytes()
        require(len(raw) <= 2 * 1024 * 1024 and b"<!DOCTYPE" not in raw.upper()
                and b"<!ENTITY" not in raw.upper(), f"Unsafe/oversized XML: {annotation}")
        tree = ET.fromstring(raw)
        name = tree.findtext("filename", "")
        require(name and Path(name).name == name, f"VOC filename must be a basename: {annotation}")
        candidates = images.get(name, [])
        require(len(candidates) == 1, f"Missing or ambiguous image {name}: {candidates}")
        image = candidates[0]
        size = image_size(image)
        require(size == [int(tree.findtext("size/width", "0")),
                         int(tree.findtext("size/height", "0"))],
                f"VOC/image dimensions disagree: {annotation}")
        sha = digest_file(image)
        for index, obj in enumerate(tree.findall("object")):
            raw_label = obj.findtext("name", "")
            require(raw_label in label_map, f"Unmapped VOC label {raw_label!r}: {annotation}")
            box = [int(obj.findtext("bndbox/" + key, "-1"))
                   for key in ("xmin", "ymin", "xmax", "ymax")]
            # Pascal VOC is 1-based inclusive; internal boxes are 0-based half-open.
            box[0] -= 1
            box[1] -= 1
            require(0 <= box[0] < box[2] <= size[0] and
                    0 <= box[1] < box[3] <= size[1], f"Invalid VOC box: {annotation} {box}")
            rel = annotation.relative_to(root).as_posix()
            records.append({
                "id": f"{rel}#{index}", "image": image.relative_to(root).as_posix(),
                "image_sha256": sha, "image_size": size, "bbox": box,
                "label": label_map[raw_label], "annotation": rel,
                "annotation_sha256": digest_bytes(raw), "object_index": index,
                "group_id": None, "group_kind": "physical_note",
                "split": None, "negative_kind": None,
                "voc_difficult": obj.findtext("difficult", "0") == "1",
                "voc_truncated": obj.findtext("truncated", "0") == "1",
            })
    require(records, "No VOC objects found")
    labels = LABELS + (["unknown"] if any(r["label"] == "unknown" for r in records) else [])
    return {"schema_version": 1, "dataset_source": "https://doi.org/10.17632/7sys44td9c.1",
            "labels": labels, "preprocessing": PREPROCESS.copy(),
            "grouping_review": {"complete": False, "reviewer": None, "method": None},
            "records": records}


def add_unknown(manifest, root, csv_path):
    """CSV: image,group_id,split,negative_kind,physical_note_ids (pipe-separated)."""
    with Path(csv_path).open(newline="") as f:
        for row in csv.DictReader(f):
            path = within(root, row["image"])
            size = image_size(path)
            manifest["records"].append({
                "id": "negative:" + row["image"], "image": row["image"],
                "image_sha256": digest_file(path), "image_size": size,
                "bbox": [0, 0, size[0], size[1]], "label": "unknown",
                "group_id": row["group_id"], "group_kind": "negative_scene",
                "split": row["split"], "negative_kind": row["negative_kind"],
                "physical_note_ids": [v.strip() for v in row.get("physical_note_ids", "").split("|") if v.strip()],
            })
    manifest["labels"] = LABELS + ["unknown"]
    # New scenes require another leakage/group review.
    manifest["grouping_review"] = {"complete": False, "reviewer": None, "method": None}
    return manifest


def validate_manifest(manifest, root=None, verify_files=True):
    require(manifest.get("schema_version") == 1, "Unsupported manifest schema")
    require(manifest.get("labels") in (LABELS, LABELS + ["unknown"]), "Wrong label order")
    require(manifest.get("preprocessing") == PREPROCESS, "Preprocessing contract changed")
    review = manifest.get("grouping_review", {})
    require(review.get("complete") is True and review.get("reviewer") and review.get("method"),
            "A human must complete physical-note/negative-scene grouping and leakage review")
    records = manifest.get("records", [])
    require(records, "Empty manifest")
    ids, groups, images, hashes, physical_notes, physical_labels = set(), {}, {}, {}, {}, {}
    counts = {s: Counter() for s in SPLITS}
    negative_kinds = {s: set() for s in SPLITS}
    checked = {}
    for r in records:
        name = r.get("id")
        require(isinstance(name, str) and name and name not in ids, "Missing/duplicate record ID")
        ids.add(name)
        split, group = r.get("split"), r.get("group_id")
        require(split in SPLITS, f"Unassigned/invalid split: {name}")
        require(isinstance(group, str) and group.strip() and group == group.strip(),
                f"Missing physical-note/scene ID or surrounding whitespace: {name}")
        label = r.get("label")
        require(label in manifest["labels"], f"Unknown label: {name}")
        if label == "unknown":
            require(r.get("group_kind") == "negative_scene", f"Unknown must have scene group: {name}")
            require(r.get("negative_kind") in ("non_money", "foreign_currency", "partial_note", "multiple_notes", "other"),
                    f"Unknown example requires a negative_kind: {name}")
            negative_kinds[split].add(r["negative_kind"])
            note_ids = r.get("physical_note_ids", [])
            require(isinstance(note_ids, list) and all(isinstance(v, str) and v.strip() and v == v.strip() for v in note_ids)
                    and len(note_ids) == len(set(note_ids)), f"Invalid physical_note_ids: {name}")
            minimum = {"partial_note": 1, "multiple_notes": 2}.get(r["negative_kind"], 0)
            require(len(note_ids) >= minimum,
                    f"{r['negative_kind']} requires at least {minimum} physical_note_ids: {name}")
        else:
            require(r.get("group_kind") == "physical_note", f"Known note requires physical-note group: {name}")
            require(r.get("physical_note_ids", [group]) == [group],
                    f"Known-note physical_note_ids must equal its group_id: {name}")
            require(group not in physical_labels or physical_labels[group] == label,
                    f"Physical-note identity has conflicting denomination: {group}")
            physical_labels[group] = label
            note_ids = [group]
        for note_id in note_ids:
            require(note_id not in physical_notes or physical_notes[note_id] == split,
                    f"Leakage: physical note {note_id!r} is reused by full/partial/multiple-note crops across splits")
            physical_notes[note_id] = split
        sha = r.get("image_sha256", "")
        require(isinstance(sha, str) and len(sha) == 64 and
                all(c in "0123456789abcdef" for c in sha), f"Invalid image hash: {name}")
        for mapping, key, kind in ((groups, group, "physical note/scene"),
                                   (images, r.get("image"), "source image"),
                                   (hashes, sha, "identical image bytes")):
            require(key not in mapping or mapping[key] == split,
                    f"Leakage: {kind} {key!r} appears in multiple splits")
            mapping[key] = split
        size, box = r.get("image_size"), r.get("bbox")
        require(isinstance(size, list) and len(size) == 2 and
                all(isinstance(v, int) and not isinstance(v, bool) and v > 0 for v in size),
                f"Invalid image size: {name}")
        require(isinstance(box, list) and len(box) == 4 and
                all(isinstance(v, int) and not isinstance(v, bool) for v in box) and
                0 <= box[0] < box[2] <= size[0] and 0 <= box[1] < box[3] <= size[1],
                f"Invalid crop: {name}")
        require(isinstance(r.get("image"), str), f"Missing image: {name}")
        if verify_files:
            require(root is not None, "Dataset root required for file checks")
            if r["image"] not in checked:
                path = within(root, r["image"])
                checked[r["image"]] = (digest_file(path), image_size(path))
            require(checked[r["image"]] == (sha, size), f"Image bytes/size changed: {name}")
            if r.get("annotation"):
                require(digest_file(within(root, r["annotation"])) == r.get("annotation_sha256"),
                        f"Annotation bytes changed: {name}")
        counts[split][label] += 1
    for split in SPLITS:
        require(set(counts[split]) == set(manifest["labels"]),
                f"Every class must occur in {split}; counts: {dict(counts[split])}")
    unknown_ready = "unknown" in manifest["labels"] and all(
        {"non_money", "foreign_currency"} <= negative_kinds[s] for s in SPLITS)
    return {"counts": {s: dict(c) for s, c in counts.items()},
            "groups_per_split": {s: sum(v == s for v in groups.values()) for s in SPLITS},
            "unknown_category_coverage": {s: sorted(v) for s, v in negative_kinds.items()},
            "unknown_training_gate_passed": unknown_ready,
            "release_approved": False,
            "limitations": ["Grouping depends on the human review; near-duplicates are not automatically detected.",
                            "Real iPhone crop/proposal, partial-note, unknown and calibration evaluation is still required."]}


def crop_image(root, record):
    from PIL import Image
    with Image.open(within(root, record["image"])) as im:
        require(im.getexif().get(274, 1) == 1, "Unexpected image orientation")
        return im.convert("RGB").crop(tuple(record["bbox"])).resize(
            (224, 224), resample=Image.Resampling.BILINEAR)


def inspect_keras_config(value):
    """Deny executable/custom serialized layers before any Keras deserialization."""
    if isinstance(value, dict):
        if "class_name" in value:
            require(value["class_name"] in ALLOWED_KERAS_CLASSES,
                    f"Unapproved serialized Keras class: {value['class_name']}")
        if "module" in value:
            module = value["module"]
            require(module is None or (isinstance(module, str) and
                    (module == "keras" or module.startswith(("keras.", "tensorflow.keras.")))),
                    f"Unapproved Keras module: {module}")
        require(value.get("registered_name") in (None, ""), "Custom registered Keras objects are prohibited")
        if "activation" in value and isinstance(value["activation"], str):
            require(value["activation"] in {"linear", "relu", "relu6", "softmax", "sigmoid", "tanh"},
                    "Unapproved activation")
        for child in value.values():
            inspect_keras_config(child)
    elif isinstance(value, list):
        for child in value:
            inspect_keras_config(child)


def verified_encoder_bytes(path):
    path = Path(path)
    require(not path.is_symlink(), "Encoder path must not be a symlink")
    require(path.stat().st_size <= 64 * 1024 * 1024, "Encoder unexpectedly large")
    raw = path.read_bytes()
    require(digest_bytes(raw) == ENCODER_SHA256,
            "Encoder SHA-256 does not match the exact official pinned asset; no bypass is supported")
    import h5py
    with h5py.File(io.BytesIO(raw), "r") as handle:
        config = handle.attrs.get("model_config")
        require(config is not None, "Encoder has no model configuration")
        if isinstance(config, bytes):
            config = config.decode("utf-8")
        require(len(config) < 4 * 1024 * 1024, "Model configuration unexpectedly large")
        inspect_keras_config(json.loads(config))
        def check_links(group):
            for key in group:
                require(isinstance(group.get(key, getlink=True), h5py.HardLink),
                        "HDF5 external/soft links are prohibited")
                item = group[key]
                if isinstance(item, h5py.Group):
                    check_links(item)
        check_links(handle)
    return raw


def configure_tensorflow(threads=2):
    require(1 <= threads <= 8, "CPU thread cap must be 1..8")
    os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
    os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
    import tensorflow as tf
    tf.config.set_visible_devices([], "GPU")
    tf.config.threading.set_intra_op_parallelism_threads(threads)
    tf.config.threading.set_inter_op_parallelism_threads(1)
    return tf


def load_encoder(path, threads=2):
    raw = verified_encoder_bytes(path)
    import h5py
    tf = configure_tensorflow(threads)
    # Deserialize the same verified in-memory bytes, never reopen an unverified path.
    with h5py.File(io.BytesIO(raw), "r") as handle:
        encoder = tf.keras.models.load_model(handle, compile=False, custom_objects={})
    require(tuple(encoder.input_shape) == (None, 224, 224, 3), "Unexpected encoder input shape")
    require(tuple(encoder.output_shape) == (None, 256), "Unexpected encoder output shape")
    encoder.trainable = False
    return encoder


def cache_embeddings(manifest, root, encoder_path, output, batch_size=16, threads=2, max_images=3000):
    import numpy as np
    require(1 <= batch_size <= 64 and 1 <= max_images <= 100000, "Invalid resource limits")
    require(len(manifest["records"]) <= max_images, "Record count exceeds explicit max-images budget")
    summary = validate_manifest(manifest, root)
    output = Path(output)
    require(not output.exists(), "Cache destination exists; use a new directory")
    encoder = load_encoder(encoder_path, threads)
    output.mkdir(parents=True)
    parts = []
    for start in range(0, len(manifest["records"]), batch_size):
        rows = manifest["records"][start:start + batch_size]
        batch = np.stack([np.asarray(crop_image(root, r), dtype=np.float32) / 255.0 for r in rows])
        features = np.asarray(encoder(batch, training=False), dtype=np.float32)
        require(features.shape == (len(rows), 256) and np.isfinite(features).all(),
                "Encoder produced invalid embeddings")
        parts.append(features)
        print(f"Encoded {start + len(rows)}/{len(manifest['records'])}", flush=True)
    np.save(output / "embeddings.npy", np.concatenate(parts), allow_pickle=False)
    write_json(output / "manifest.json", manifest)
    write_json(output / "cache.json", {
        "schema_version": 1, "encoder_sha256": ENCODER_SHA256,
        "manifest_sha256": canonical_digest(manifest), "preprocessing": PREPROCESS,
        "embeddings_sha256": digest_file(output / "embeddings.npy"),
        "split_summary": summary,
    })


def read_cache(path):
    import numpy as np
    path = Path(path)
    meta, manifest = read_json(path / "cache.json"), read_json(path / "manifest.json")
    validate_manifest(manifest, verify_files=False)
    require(meta.get("encoder_sha256") == ENCODER_SHA256, "Cache uses a different encoder")
    require(meta.get("preprocessing") == PREPROCESS and
            meta.get("manifest_sha256") == canonical_digest(manifest), "Cache metadata changed")
    require(digest_file(path / "embeddings.npy") == meta.get("embeddings_sha256"), "Cache bytes changed")
    features = np.load(path / "embeddings.npy", allow_pickle=False)
    require(features.shape == (len(manifest["records"]), 256) and np.isfinite(features).all(),
            "Invalid embedding cache")
    return features, manifest, meta


def softmax(logits):
    import numpy as np
    values = np.asarray(logits, dtype=np.float64)
    values = np.exp(values - values.max(axis=1, keepdims=True))
    return values / values.sum(axis=1, keepdims=True)


def scores(head, features):
    import numpy as np
    mean, scale = np.array(head["mean"]), np.array(head["scale"])
    coef, intercept = np.array(head["coef"]), np.array(head["intercept"])
    return softmax(((features - mean) / scale @ coef.T + intercept) / head["temperature"])


def fit_head(features, manifest):
    """Fit scaler/head on train, temperature on calibration. Test rows are not read."""
    import numpy as np
    from scipy.optimize import minimize_scalar
    from sklearn.linear_model import LogisticRegression
    from sklearn.preprocessing import StandardScaler
    from threadpoolctl import threadpool_limits
    validate_manifest(manifest, verify_files=False)
    labels = manifest["labels"]
    train = np.array([i for i, r in enumerate(manifest["records"]) if r["split"] == "train"])
    calibration = np.array([i for i, r in enumerate(manifest["records"]) if r["split"] == "calibration"])
    y_train = np.array([labels.index(manifest["records"][i]["label"]) for i in train])
    y_cal = np.array([labels.index(manifest["records"][i]["label"]) for i in calibration])
    scaler = StandardScaler().fit(features[train])
    classifier = LogisticRegression(C=1.0, solver="lbfgs", max_iter=1000,
                                    class_weight="balanced", random_state=0)
    with threadpool_limits(limits=2):
        classifier.fit(scaler.transform(features[train]), y_train)
    require((classifier.classes_ == np.arange(len(labels))).all(), "Head label order mismatch")
    require(int(classifier.n_iter_.max()) < 1000, "Head did not converge; inspect training data")
    logits = classifier.decision_function(scaler.transform(features[calibration]))
    def nll(log_temperature):
        prob = softmax(logits / math.exp(log_temperature))
        return float(-np.log(np.clip(prob[np.arange(len(y_cal)), y_cal], 1e-15, 1)).mean())
    result = minimize_scalar(nll, bounds=(math.log(0.05), math.log(20.0)), method="bounded")
    require(result.success and math.isfinite(result.fun), "Temperature calibration failed")
    head = {"schema_version": 1, "model_kind": "banknote_net_crop_classifier",
            "labels": labels, "mean": scaler.mean_.tolist(), "scale": scaler.scale_.tolist(),
            "coef": classifier.coef_.tolist(), "intercept": classifier.intercept_.tolist(),
            "temperature": math.exp(float(result.x)), "encoder_sha256": ENCODER_SHA256,
            "preprocessing": PREPROCESS, "manifest_sha256": canonical_digest(manifest),
            "fitting_splits": {"scaler_and_head": "train", "temperature": "calibration"},
            "release_approved": False}
    return head


def validate_head(head):
    import numpy as np
    require(head.get("schema_version") == 1 and head.get("model_kind") == "banknote_net_crop_classifier",
            "Unsupported head format")
    require(head.get("encoder_sha256") == ENCODER_SHA256 and head.get("preprocessing") == PREPROCESS,
            "Head provenance/preprocessing mismatch")
    require(head.get("labels") in (LABELS, LABELS + ["unknown"]), "Head label contract mismatch")
    for key, shape in (("mean", (256,)), ("scale", (256,)),
                       ("coef", (len(head["labels"]), 256)), ("intercept", (len(head["labels"]),))):
        array = np.asarray(head.get(key), dtype=float)
        require(array.shape == shape and np.isfinite(array).all(), f"Invalid head {key}")
    require((np.asarray(head["scale"]) > 0).all(), "Scaler contains non-positive scale")
    require(isinstance(head.get("temperature"), (int, float)) and
            math.isfinite(head["temperature"]) and 0.05 <= head["temperature"] <= 20.0,
            "Invalid temperature")


def metrics(head, features, manifest, split):
    import numpy as np
    validate_head(head)
    require(split in SPLITS, "Invalid evaluation split")
    rows = [i for i, r in enumerate(manifest["records"]) if r["split"] == split]
    y = np.array([head["labels"].index(manifest["records"][i]["label"]) for i in rows])
    p = scores(head, features[rows])
    predicted = p.argmax(axis=1)
    matrix = np.zeros((len(head["labels"]), len(head["labels"])), dtype=int)
    for actual, guess in zip(y, predicted):
        matrix[actual, guess] += 1
    return {"split": split, "count": len(rows), "accuracy": float((predicted == y).mean()),
            "negative_log_likelihood": float(-np.log(np.clip(p[np.arange(len(y)), y], 1e-15, 1)).mean()),
            "multiclass_brier": float(np.square(p - np.eye(len(head["labels"]))[y]).sum(axis=1).mean()),
            "labels": head["labels"], "confusion_matrix_actual_by_predicted": matrix.tolist(),
            "per_class_recall": {label: float(matrix[i, i] / matrix[i].sum())
                                 for i, label in enumerate(head["labels"])},
            "release_approved": False,
            "scope": "Ground-truth crops only. Does not measure rectangle proposals, OOD safety or iPhone accuracy."}


def fold_head(head):
    """Fold standardization and temperature into one affine layer."""
    import numpy as np
    validate_head(head)
    coef, mean, scale = (np.asarray(head[k], dtype=np.float64) for k in ("coef", "mean", "scale"))
    weights = coef.T / scale[:, None] / head["temperature"]
    bias = (np.asarray(head["intercept"]) - (coef * (mean / scale)).sum(axis=1)) / head["temperature"]
    return weights.astype(np.float32), bias.astype(np.float32)


def export_coreml(head, encoder_path, output, allow_experimental_eight_class=False, threads=2):
    import numpy as np
    validate_head(head)
    require(head["labels"] == LABELS + ["unknown"] or allow_experimental_eight_class,
            "Eight-class export is experimental only; supply unknown data or explicit experimental flag")
    output = Path(output)
    require(output.suffix == ".mlmodel" and not output.exists(), "Choose a new .mlmodel output path")
    encoder = load_encoder(encoder_path, threads)
    import tensorflow as tf
    import coremltools as ct
    x = tf.keras.Input(shape=(224, 224, 3), name="image")
    affine = tf.keras.layers.Dense(len(head["labels"]), name="saudi_logits", trainable=False)
    logits = affine(encoder(x, training=False))
    model = tf.keras.Model(x, tf.keras.layers.Softmax(name="probabilities")(logits))
    affine.set_weights(list(fold_head(head)))
    # Numeric plumbing check is not real-image accuracy or Core ML runtime parity.
    zeros = np.zeros((1, 224, 224, 3), dtype=np.float32)
    encoded = np.asarray(encoder(zeros, training=False))
    require(np.allclose(np.asarray(model(zeros, training=False)), scores(head, encoded), atol=2e-5),
            "Fused TensorFlow head differs from reference")
    converted = ct.convert(
        model, source="tensorflow", convert_to="neuralnetwork", minimum_deployment_target=ct.target.iOS15,
        inputs=[ct.ImageType(name="image", shape=(1, 224, 224, 3), scale=1.0 / 255.0,
                             bias=[0, 0, 0], color_layout=ct.colorlayout.RGB, channel_first=False)],
        classifier_config=ct.ClassifierConfig(head["labels"], predicted_feature_name="classLabel"))
    spec = converted.get_spec()
    require(spec.WhichOneof("Type") == "neuralNetworkClassifier", "Unexpected Core ML model type")
    require(list(spec.neuralNetworkClassifier.stringClassLabels.vector) == head["labels"],
            "Exported class labels changed")
    old_probability_name = spec.description.predictedProbabilitiesName
    require(bool(old_probability_name), "Missing Core ML probability output")
    ct.utils.rename_feature(spec, old_probability_name, "probabilities")
    # A .mlmodel is a single raw file, not a .mlpackage; the app hashes it before compiling.
    final = ct.models.MLModel(spec, skip_model_load=True)
    final.short_description = "Experimental Saudi note crop classifier; not an object detector or authenticity check."
    final.user_defined_metadata["encoder_sha256"] = ENCODER_SHA256
    final.user_defined_metadata["preprocessing"] = json.dumps(PREPROCESS, sort_keys=True)
    final.user_defined_metadata["labels"] = json.dumps(head["labels"])
    final.user_defined_metadata["release_approved"] = "false"
    output.parent.mkdir(parents=True, exist_ok=True)
    final.save(str(output))
    contract = {
        "schema_version": 1, "model_kind": "banknote_net_crop_classifier",
        "file": output.name, "model_sha256": digest_file(output), "encoder_sha256": ENCODER_SHA256,
        "head_sha256": canonical_digest(head), "labels": head["labels"],
        "inputs": {"image": {"type": "RGB_image", "width": 224, "height": 224}},
        "outputs": {"classLabel": "string", "probabilities": "dictionary_string_double"},
        "preprocessing": PREPROCESS, "bounding_boxes": False, "note_count": False,
        "detector_contract_compatible": False, "release_approved": False,
        "selected_phone_profile": None, "coreml_runtime_parity_tested": False,
        "requires": ["Held-out real-image Core ML/TensorFlow probability parity on macOS or iPhone",
                     "Independent physical-note real-iPhone end-to-end testing including unknowns and partials",
                     "Approved calibrated rejection, temporal stability and rectangle-proposal policy"],
    }
    write_json(output.with_suffix(".contract.json"), contract)
    return contract


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("index-voc")
    for name in ("root", "annotations", "images", "label-map", "output"):
        p.add_argument("--" + name, required=True)
    p = sub.add_parser("add-unknown")
    for name in ("manifest", "root", "csv", "output"):
        p.add_argument("--" + name, required=True)
    p = sub.add_parser("validate")
    p.add_argument("--manifest", required=True)
    p.add_argument("--root", required=True)
    p = sub.add_parser("inspect-encoder")
    p.add_argument("--encoder", required=True)
    p = sub.add_parser("cache")
    for name in ("manifest", "root", "encoder", "output"):
        p.add_argument("--" + name, required=True)
    p.add_argument("--batch-size", type=int, default=16)
    p.add_argument("--threads", type=int, default=2)
    p.add_argument("--max-images", type=int, default=3000)
    p = sub.add_parser("train")
    p.add_argument("--cache", required=True)
    p.add_argument("--output", required=True)
    p = sub.add_parser("evaluate")
    for name in ("cache", "head", "output"):
        p.add_argument("--" + name, required=True)
    p.add_argument("--split", choices=("calibration", "test"), required=True)
    p = sub.add_parser("export-coreml")
    for name in ("head", "encoder", "output"):
        p.add_argument("--" + name, required=True)
    p.add_argument("--threads", type=int, default=2)
    p.add_argument("--allow-experimental-eight-class", action="store_true")
    args = parser.parse_args(argv)
    if args.command == "index-voc":
        write_json(args.output, index_voc(args.root, args.annotations, args.images, read_json(args.label_map)))
        print("Wrote UNASSIGNED manifest. Complete physical-note grouping and split review before training.")
    elif args.command == "add-unknown":
        write_json(args.output, add_unknown(read_json(args.manifest), args.root, args.csv))
    elif args.command == "validate":
        print(json.dumps(validate_manifest(read_json(args.manifest), args.root), indent=2))
    elif args.command == "inspect-encoder":
        verified_encoder_bytes(args.encoder)
        print("Pinned hash and serialized configuration passed. No Keras deserialization was performed.")
    elif args.command == "cache":
        cache_embeddings(read_json(args.manifest), args.root, args.encoder, args.output,
                         args.batch_size, args.threads, args.max_images)
    elif args.command == "train":
        require(not Path(args.output).exists(), "Head output exists; use a new path")
        features, manifest, meta = read_cache(args.cache)
        head = fit_head(features, manifest)
        head["embedding_cache_sha256"] = meta["embeddings_sha256"]
        head["split_summary"] = validate_manifest(manifest, verify_files=False)
        head["calibration_metrics"] = metrics(head, features, manifest, "calibration")
        write_json(args.output, head)
        print("Wrote fitted head. Test split was not used for fitting or calibration. Not release-approved.")
    elif args.command == "evaluate":
        features, manifest, meta = read_cache(args.cache)
        head = read_json(args.head)
        require(head.get("manifest_sha256") == canonical_digest(manifest) and
                head.get("embedding_cache_sha256") == meta["embeddings_sha256"], "Head/cache mismatch")
        write_json(args.output, metrics(head, features, manifest, args.split))
    elif args.command == "export-coreml":
        result = export_coreml(read_json(args.head), args.encoder, args.output,
                               args.allow_experimental_eight_class, args.threads)
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, ImportError) as exc:
        print(f"STOP: {exc}", file=sys.stderr)
        sys.exit(2)
