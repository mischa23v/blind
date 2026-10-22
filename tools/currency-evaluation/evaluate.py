#!/usr/bin/env python3
"""Evaluate exported Saudi-banknote decisions; never infer or fabricate predictions.

Standard-library only. See README.md for the data contract and limitations.
"""

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import sys


DENOMINATIONS = (1, 5, 10, 20, 50, 100, 200, 500)
SPLITS = {"train", "calibration", "test"}
POSITIVE_CONDITIONS = {"clean", "folded", "occluded"}
NEGATIVE_CONDITIONS = {"foreign", "non_money", "multiple_notes", "partial_note"}
CONDITIONS = POSITIVE_CONDITIONS | NEGATIVE_CONDITIONS
REQUIRED_FIELDS = {"sample_id", "group_id", "split", "expected", "condition", "side", "variant"}


class ValidationError(ValueError):
    """Input cannot support the requested evaluation."""


def require(condition, message):
    if not condition:
        raise ValidationError(message)


def denomination(value, other):
    # bool compares equal to 1 in Python: reject it explicitly.
    if type(value) is int and value in DENOMINATIONS:
        return value
    if isinstance(value, str) and value == other:
        return value
    raise ValidationError(f"Expected a supported integer denomination or {other!r}; got {value!r}")


def nonempty_string(value):
    return isinstance(value, str) and bool(value.strip()) and value == value.strip()


def read_jsonl(path):
    records = []
    with Path(path).open(encoding="utf-8") as stream:
        for number, line in enumerate(stream, 1):
            if not line.strip():
                continue
            try:
                value = json.loads(line)
            except (ValueError, TypeError) as error:
                raise ValidationError(f"{path}:{number}: invalid JSON: {error}") from error
            require(isinstance(value, dict), f"{path}:{number}: expected an object")
            records.append(value)
    require(records, f"{path}: no records")
    return records


def _identities(row):
    """Group repeated scenes and every identifiable physical note together."""
    return {"identity:" + row["group_id"]} | {
        "identity:" + identity for identity in row.get("physical_note_ids", [])
    }


def validate_manifest(records):
    require(bool(records), "Manifest is empty")
    samples = {}
    identity_splits = {}
    note_labels = {}
    hashes = {}
    found_splits = set()
    for number, row in enumerate(records, 1):
        require(isinstance(row, dict), f"Manifest row {number}: expected object")
        missing = REQUIRED_FIELDS - row.keys()
        require(not missing, f"Manifest row {number}: missing {sorted(missing)}")
        sid = row["sample_id"]
        require(nonempty_string(sid), f"Manifest row {number}: invalid sample_id")
        require(sid not in samples, f"Duplicate sample_id: {sid}")
        require(nonempty_string(row["group_id"]), f"{sid}: invalid group_id")
        require(nonempty_string(row["split"]) and row["split"] in SPLITS, f"{sid}: invalid split")
        require(nonempty_string(row["condition"]) and row["condition"] in CONDITIONS, f"{sid}: invalid condition")
        require(nonempty_string(row["side"]), f"{sid}: invalid side")
        require(nonempty_string(row["variant"]), f"{sid}: variant must be recorded")
        expected = denomination(row["expected"], "unknown")
        notes = row.get("physical_note_ids", [])
        require(isinstance(notes, list) and all(nonempty_string(v) for v in notes),
                f"{sid}: physical_note_ids must be a list of stable nonempty IDs")
        require(len(notes) == len(set(notes)), f"{sid}: duplicate physical_note_ids")
        if expected == "unknown":
            require(row["condition"] in NEGATIVE_CONDITIONS,
                    f"{sid}: unknown requires foreign, non_money, multiple_notes, or partial_note")
            require(row["side"] == "n/a" and row["variant"] == "n/a",
                    f"{sid}: negative scenes require side and variant n/a")
            if row["condition"] == "multiple_notes":
                require(len(notes) >= 2, f"{sid}: list all physical_note_ids for multiple_notes (at least two)")
            if row["condition"] == "partial_note":
                require(len(notes) >= 1, f"{sid}: list all physical_note_ids for partial_note (at least one)")
        else:
            require(row["condition"] in POSITIVE_CONDITIONS,
                    f"{sid}: a multiple/partial/foreign/non-money scene must have expected unknown")
            require(row["side"] in {"front", "back"}, f"{sid}: side must be front or back")
            require(row["variant"] != "n/a", f"{sid}: identify the note variant")
            require(len(notes) <= 1, f"{sid}: a single-note scene cannot list multiple physical notes")
            if row["variant"] == "polymer":
                require(expected == 5, f"{sid}: this evaluation profile recognizes polymer only for 5 SAR")
            for identity in _identities(row):
                label = (expected, row["variant"])
                require(identity not in note_labels or note_labels[identity] == label,
                        f"{sid}: physical-note identity has conflicting denomination/variant")
                note_labels[identity] = label
        for identity in _identities(row):
            require(identity not in identity_splits or identity_splits[identity] == row["split"],
                    f"{sid}: physical-note/group leakage across splits: {identity}")
            identity_splits[identity] = row["split"]
        image_hash = row.get("image_sha256")
        if image_hash is not None:
            require(isinstance(image_hash, str) and len(image_hash) == 64
                    and all(c in "0123456789abcdef" for c in image_hash),
                    f"{sid}: image_sha256 must be a lowercase SHA-256 digest")
            require(image_hash not in hashes, f"{sid}: duplicate image content: {hashes.get(image_hash)}")
            hashes[image_hash] = sid
        samples[sid] = row
        found_splits.add(row["split"])
    require(found_splits == SPLITS, f"Manifest must declare train, calibration and test; missing {sorted(SPLITS - found_splits)}")
    return samples


def components(rows):
    """Connected components avoid treating shared-note scenes as independent."""
    parent = {}

    def root(value):
        parent.setdefault(value, value)
        while parent[value] != value:
            parent[value] = parent[parent[value]]
            value = parent[value]
        return value

    for row in rows:
        identities = sorted(_identities(row))
        leader = root(identities[0])
        for identity in identities[1:]:
            parent[root(identity)] = leader
    return {row["sample_id"]: root(sorted(_identities(row))[0]) for row in rows}


def check_coverage(rows, group_for, min_groups=1):
    require(type(min_groups) is int and min_groups >= 1, "min_groups must be a positive integer")
    requirements = []
    for value in DENOMINATIONS:
        for side in ("front", "back"):
            for condition in sorted(POSITIVE_CONDITIONS):
                requirements.append((f"SAR {value} / {side} / {condition}",
                    lambda r, v=value, s=side, c=condition: r["expected"] == v
                    and r["side"] == s and r["condition"] == c))
    for variant in ("paper", "polymer"):
        for side in ("front", "back"):
            for condition in sorted(POSITIVE_CONDITIONS):
                requirements.append((f"SAR 5 {variant} / {side} / {condition}",
                    lambda r, v=variant, s=side, c=condition: r["expected"] == 5 and r["variant"] == v
                    and r["side"] == s and r["condition"] == c))
    for condition in sorted(NEGATIVE_CONDITIONS):
        requirements.append((condition, lambda r, c=condition: r["condition"] == c))
    coverage = {}
    for name, predicate in requirements:
        matches = [row for row in rows if predicate(row)]
        coverage[name] = {"samples": len(matches),
                          "independent_groups": len({group_for[row["sample_id"]] for row in matches})}
    missing = [name for name, counts in coverage.items() if counts["independent_groups"] < min_groups]
    require(not missing, f"Test coverage insufficient (need {min_groups} independent groups per cell): " + "; ".join(missing))
    return coverage


def wilson(successes, total):
    """Two-sided 95% Wilson interval; undefined when the denominator is zero."""
    if not total:
        return None
    z = 1.959963984540054
    p = successes / total
    denominator = 1 + z * z / total
    midpoint = (p + z * z / (2 * total)) / denominator
    radius = z * math.sqrt(p * (1 - p) / total + z * z / (4 * total * total)) / denominator
    return [max(0.0, midpoint - radius), min(1.0, midpoint + radius)]


def rate(numerator, denominator, interval=False):
    result = {"numerator": numerator, "denominator": denominator,
              "rate": numerator / denominator if denominator else None}
    if interval:
        result["wilson_95"] = wilson(numerator, denominator)
    return result


def metrics(rows, predictions, group_for):
    spoken = [row for row in rows if predictions[row["sample_id"]] != "abstain"]
    correct = [row for row in spoken if predictions[row["sample_id"]] == row["expected"]]
    positives = [row for row in rows if row["expected"] != "unknown"]
    negatives = [row for row in rows if row["expected"] == "unknown"]
    false_accepts = [row for row in negatives if predictions[row["sample_id"]] != "abstain"]
    groups = defaultdict(list)
    for row in rows:
        groups[group_for[row["sample_id"]]].append(row)
    speaking_groups = [group for group in groups.values()
                       if any(predictions[r["sample_id"]] != "abstain" for r in group)]
    error_free = sum(all(predictions[r["sample_id"]] in ("abstain", r["expected"])
                         for r in group) for group in speaking_groups)
    negative_groups = [group for group in groups.values() if any(r["expected"] == "unknown" for r in group)]
    false_accept_groups = sum(any(r["expected"] == "unknown" and predictions[r["sample_id"]] != "abstain"
                                 for r in group) for group in negative_groups)
    return {
        "sample_count": len(rows), "independent_group_count": len(groups),
        "spoken_count": len(spoken), "correct_spoken_count": len(correct),
        "wrong_spoken_count": len(spoken) - len(correct),
        "abstention_rate": rate(len(rows) - len(spoken), len(rows)),
        "spoken_decision_precision": rate(len(correct), len(spoken)),
        "positive_correct_coverage": rate(len(correct), len(positives)),
        "unknown_false_acceptance_rate": rate(len(false_accepts), len(negatives)),
        # This is intentionally NOT a confidence bound on per-frame precision.
        "error_free_spoken_group_rate": rate(error_free, len(speaking_groups), interval=True),
        "unknown_group_false_acceptance_rate": rate(false_accept_groups, len(negative_groups), interval=True),
    }


def evaluate(manifest, prediction_records, metadata, min_groups=1, allow_synthetic=False):
    require(isinstance(metadata, dict), "Run metadata must be an object")
    for name in ("model_id", "dataset_id", "decision_policy_id"):
        require(nonempty_string(metadata.get(name)), f"Metadata requires {name}")
    require(metadata.get("frozen_before_test") is True,
            "Model and decision policy must be frozen before examining test results")
    require(nonempty_string(metadata.get("data_kind")) and metadata["data_kind"] in {"real", "synthetic"},
            "Metadata data_kind must be real or synthetic")
    require(metadata["data_kind"] == "real" or allow_synthetic,
            "Synthetic records are harness-only; pass --allow-synthetic explicitly")
    samples = validate_manifest(manifest)
    test = [row for row in manifest if row["split"] == "test"]
    group_for = components(test)
    coverage = check_coverage(test, group_for, min_groups)
    predictions = {}
    for index, record in enumerate(prediction_records, 1):
        require(isinstance(record, dict), f"Prediction row {index}: expected an object")
        sid = record.get("sample_id")
        require(nonempty_string(sid), f"Prediction row {index}: invalid sample_id")
        require(sid in samples, f"Prediction refers to unknown sample: {sid}")
        require(samples[sid]["split"] == "test", f"Predictions must contain test samples only: {sid}")
        require(sid not in predictions, f"Duplicate prediction for {sid}")
        require("spoken_denomination" in record, f"{sid}: missing spoken_denomination")
        predictions[sid] = denomination(record["spoken_denomination"], "abstain")
    missing = sorted(set(row["sample_id"] for row in test) - predictions.keys())
    require(not missing, "Missing predictions; never silently drop failures: " + ", ".join(missing))
    matrix = {str(expected): {str(output): 0 for output in (*DENOMINATIONS, "abstain")}
              for expected in (*DENOMINATIONS, "unknown")}
    costly = Counter()
    errors = []
    for row in test:
        output = predictions[row["sample_id"]]
        matrix[str(row["expected"])][str(output)] += 1
        if output != "abstain" and output != row["expected"]:
            errors.append({"sample_id": row["sample_id"], "group_id": row["group_id"],
                           "expected": row["expected"], "spoken_denomination": output,
                           "condition": row["condition"], "side": row["side"], "variant": row["variant"]})
            if row["expected"] != "unknown":
                costly[(row["expected"], output)] += 1
    per_denomination = {}
    for value in DENOMINATIONS:
        expected_rows = [row for row in test if row["expected"] == value]
        emitted = [row for row in test if predictions[row["sample_id"]] == value]
        true = sum(row["expected"] == value for row in emitted)
        per_denomination[str(value)] = {
            "expected_samples": len(expected_rows), "spoken_as_this_value": len(emitted),
            "precision": rate(true, len(emitted)), "recall": rate(true, len(expected_rows)),
            "abstention_rate": rate(sum(predictions[r["sample_id"]] == "abstain" for r in expected_rows), len(expected_rows)),
            "confusions_out": {str(other): matrix[str(value)][str(other)] for other in DENOMINATIONS if other != value},
        }
    return {
        "schema_version": 1,
        "evidence_scope": "SYNTHETIC HARNESS TEST ONLY; NOT MODEL ACCURACY" if metadata["data_kind"] == "synthetic"
                          else "Imported real-prediction records; provenance asserted by provider, not independently verified",
        "release_approval": False,
        "run_metadata": metadata,
        "split_sample_counts": dict(Counter(row["split"] for row in manifest)),
        "minimum_groups_per_coverage_cell": min_groups,
        "coverage": coverage,
        "overall": metrics(test, predictions, group_for),
        "per_denomination": per_denomination,
        "by_condition": {condition: metrics([r for r in test if r["condition"] == condition], predictions, group_for)
                         for condition in sorted(CONDITIONS)},
        "by_side": {side: metrics([r for r in test if r["side"] == side], predictions, group_for)
                    for side in ("front", "back", "n/a")},
        "by_variant": {variant: metrics([r for r in test if r["variant"] == variant], predictions, group_for)
                       for variant in sorted({r["variant"] for r in test})},
        "confusion_matrix": matrix,
        "critical_100_vs_1": {"expected_100_spoken_1": matrix["100"]["1"],
                              "expected_1_spoken_100": matrix["1"]["100"]},
        "costly_confusions": [{"expected": expected, "spoken": output, "count": count,
                               "absolute_error_sar_per_decision": abs(expected - output),
                               "direction": "overstatement" if output > expected else "understatement"}
                              for (expected, output), count in sorted(costly.items(),
                                  key=lambda item: (-abs(item[0][0] - item[0][1]), item[0]))],
        "wrong_spoken_decisions": errors,
        "caveats": [
            "Finite samples cannot prove zero failure risk. Coverage presence is not evidence of adequate sample size.",
            "Wilson bounds describe independent-group rates, not per-frame precision; repeated frames are not independent trials.",
            "Group independence depends on correct identities. Shared physical notes are merged, but unrecorded shared sessions/devices may remain correlated.",
            "Intervals are separate, unadjusted 95% intervals, not simultaneous guarantees across denominations or conditions.",
            "This harness cannot verify labels, image provenance, upstream training data, frozen-policy attestations, audio playback, or live-device behavior.",
            "Do not tune thresholds on this test set. Evaluate a newly frozen policy on a fresh held-out test set.",
            "No safety/release pass threshold is provided. Review precision together with abstention and task-specific risk limits.",
        ],
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--predictions", required=True, type=Path)
    parser.add_argument("--run-metadata", required=True, type=Path)
    parser.add_argument("--min-groups", type=int, default=1)
    parser.add_argument("--allow-synthetic", action="store_true")
    parser.add_argument("--output", type=Path, help="Report JSON, otherwise stdout")
    args = parser.parse_args(argv)
    try:
        paths = (args.manifest, args.predictions, args.run_metadata)
        if args.output:
            require(args.output.resolve() not in {path.resolve() for path in paths}, "Output must not overwrite an input")
        report = evaluate(read_jsonl(args.manifest), read_jsonl(args.predictions),
                          json.loads(args.run_metadata.read_text(encoding="utf-8")),
                          args.min_groups, args.allow_synthetic)
        report["input_sha256"] = {name: hashlib.sha256(path.read_bytes()).hexdigest()
                                   for name, path in zip(("manifest", "predictions", "run_metadata"), paths)}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
        if args.output:
            args.output.write_text(encoded, encoding="utf-8")
        else:
            print(encoded, end="")
        return 0
    except (ValidationError, OSError, ValueError, TypeError) as error:
        print(f"Evaluation refused: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
