#!/usr/bin/env python3
"""Bounded source/fixture integrity checks. Does NOT execute Swift or prove safety."""
from pathlib import Path
import hashlib, json, shutil
root = Path(__file__).resolve().parents[2]
paths = [
    'BlindCore/Sources/BlindCore/NativeLocalizationEvidence.swift',
    'BlindCore/Sources/BlindCore/SavedWorldFrame.swift',
    'BlindCore/Sources/BlindCore/BodyHeading.swift',
    'ios/BlindAssist/NativeLocalizationIssuer.swift',
    'BlindCore/Tests/BlindCoreTests/NativeLocalizationEvidenceGateTests.swift',
]
texts = {p: (root / p).read_text() for p in paths}
test = texts[paths[-1]]
checks = {
    'ten_direct_gate_test_methods': test.count('func test') == 10,
    'fixture_validator_only_in_test_target': 'private struct FixtureValidator' in test,
    'fixture_is_explicitly_not_accuracy_evidence': 'NOT measured localization accuracy' in test,
    'same_id_changed_matrix_is_tested': 'id: c.id, matrix: altered' in test,
    'superseded_completion_preserves_newer_candidate_tested': 'testObsoleteCompletionDoesNotConsumeNewerPendingFrame' in test,
    'all_three_missing_records_have_expected_reason': all(x in test for x in ['.missingCalibration', '.missingSupport', '.missingErrorModel']),
    'release_remains_withheld_in_gate': 'reason = .physicalReleaseNotApproved' in texts[paths[0]],
    'issuer_remains_missing_calibration': '.missingCalibration' in texts[paths[3]],
    'fixture_never_calls_capture_acceptance': 'acceptRegisteredCapture(' not in test,
}
receipt = {
    'kind': 'source-integrity-only',
    'checks': checks,
    'all_source_checks_pass': all(checks.values()),
    'swift_available': shutil.which('swift') is not None,
    'swift_tests_executed_by_this_script': False,
    'physical_localization_accuracy_measured': False,
    'physical_guidance_enabled': False,
    'source_sha256': {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths},
}
print(json.dumps(receipt, indent=2))
raise SystemExit(0 if all(checks.values()) else 1)
