#!/usr/bin/env python3
"""Strict no-training reference/calibration/test experiment. Never a release gate."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict, deque
from dataclasses import asdict
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import platform
import re
import sys
import time

import numpy as np
from PIL import __version__ as pillow_version
import reference_match as rm

METRICS_PATH = Path(__file__).resolve().parents[1] / 'currency-evaluation' / 'evaluate.py'
_spec = importlib.util.spec_from_file_location('currency_decision_metrics', METRICS_PATH)
metrics_core = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(metrics_core)
SOURCE_PATHS = {'matcher': Path(rm.__file__), 'evaluator': Path(__file__),
                'shared_metrics': METRICS_PATH, 'reference_preparation': Path(__file__).with_name('prepare_reference.py')}
LOADED_SOURCE_HASHES = {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in SOURCE_PATHS.items()}

ROLES = {'reference', 'calibration', 'test'}
POSITIVE = {'clean', 'folded', 'occluded'}
NEGATIVE = {'foreign', 'non_money', 'multiple_notes', 'partial_note', 'composite', 'reproduction', 'screen'}
CONDITIONS = POSITIVE | NEGATIVE
MAX_SAMPLES = 4096
MAX_SOURCES = 8192
MAX_JSON_BYTES = 16 * 1024 * 1024
MAX_TOTAL_IMAGE_BYTES = 2 * 1024 * 1024 * 1024
UNKNOWN = {'unknown', 'unidentified', 'unspecified', 'missing', 'n/a', 'none', 'null', '?'}
CAVEATS = [
    'Python/OpenCV experiment only, not the native Apple Vision/proposal/Swift/speech pipeline.',
    'Hash and graph checks verify declared bytes and relationships, not truthful labels, rights, complete identities, or uncropped original provenance.',
    'Independent groups are connected physical-note, capture-session and source-family components conditional on accurate, complete inventory annotations.',
    'Thresholds and one method are frozen before test execution here. No local tool can prove that a person never viewed the test images or earlier results.',
    'Do not use test results to select methods or thresholds; a revised policy needs a fresh held-out dataset.',
    'Finite samples and coverage presence do not establish release readiness, authenticity, legal-tender status, single-note proof, or zero future errors.',
    'Wilson intervals are unadjusted 95% independent-group intervals, not per-frame accuracy bounds.',
    'Timing is sequential desktop wall time, not phone latency. No process timeout is implemented; interrupted runs remain marked started.',
]


def require(value, message):
    if not value:
        raise rm.InputError(message)


def text(value, name):
    require(type(value) is str and value == value.strip() and 0 < len(value) <= 512,
            name + ' must be trimmed nonempty text (at most 512 characters)')


def identifier(value, name):
    text(value, name)
    require(value.lower() not in UNKNOWN, name + ' is unknown; use identity_status=unknown, not a fabricated identity')


def string_list(value, name, identities=False):
    require(type(value) is list and len(value) <= MAX_SOURCES, name + ' must be a bounded list')
    for item in value:
        (identifier if identities else text)(item, name)
    require(len(value) == len(set(value)), name + ' contains duplicates')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def parse_json(data):
    def invalid_constant(value):
        raise rm.InputError('Nonfinite JSON number forbidden: ' + value)
    try:
        return json.loads(data,
                          object_pairs_hook=rm.strict_json_object, parse_constant=invalid_constant)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise rm.InputError('Invalid JSON document') from error


def read_json(path):
    return parse_json(rm.bounded_bytes(Path(path), MAX_JSON_BYTES))


def write_new(path, value):
    with Path(path).open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


class Components:
    """Union-find joins all identities, including every note in a mixed scene."""
    def __init__(self):
        self.parent = {}

    def root(self, value):
        self.parent.setdefault(value, value)
        while value != self.parent[value]:
            self.parent[value] = self.parent[self.parent[value]]
            value = self.parent[value]
        return value

    def join(self, values):
        leader = self.root(values[0])
        for value in values[1:]:
            self.parent[self.root(value)] = leader


def load_inventory(path, reference_path, allow_synthetic=False):
    path, reference_path = Path(path), Path(reference_path)
    inventory_bytes = rm.bounded_bytes(path, MAX_JSON_BYTES)
    reference_bytes = rm.bounded_bytes(reference_path, rm.MAX_MANIFEST_BYTES)
    manifest = parse_json(inventory_bytes)
    rm.require_fields(manifest, {'schema_version', 'dataset_id', 'data_kind', 'sources', 'samples'}, 'Inventory')
    require(type(manifest['schema_version']) is int and manifest['schema_version'] == 1, 'Unsupported inventory schema')
    identifier(manifest['dataset_id'], 'dataset_id')
    require(manifest['data_kind'] in ('real', 'synthetic'), 'data_kind must be real or synthetic')
    require(manifest['data_kind'] == 'real' or allow_synthetic, 'Synthetic data requires --allow-synthetic; harness evidence only')
    require(type(manifest['sources']) is list and 1 <= len(manifest['sources']) <= MAX_SOURCES, 'Source count exceeds bounds or is empty')
    require(type(manifest['samples']) is list and 3 <= len(manifest['samples']) <= MAX_SAMPLES, 'Sample count must be 3..4096; never silently truncate an inventory')
    root = path.resolve().parent
    sources, paths, sizes, hashes = {}, {}, {}, {}
    total_bytes = 0

    def checked_file(relative, expected):
        nonlocal total_bytes
        resolved = rm.local_path(root, relative)
        data = rm.bounded_bytes(resolved, rm.MAX_FILE_BYTES)
        rm.checked_hash(data, expected)
        if str(resolved) not in sizes:
            sizes[str(resolved)] = len(data)
            total_bytes += len(data)
            require(total_bytes <= MAX_TOTAL_IMAGE_BYTES, 'Unique declared image bytes exceed 2 GiB bound')
        hashes[str(resolved)] = digest(data)
        return resolved

    for source in manifest['sources']:
        rm.require_fields(source, {'id', 'path', 'sha256', 'parent_ids'}, 'Source')
        identifier(source['id'], 'source id')
        require(source['id'] not in sources, 'Duplicate source ID')
        string_list(source['parent_ids'], 'source parent_ids', True)
        paths['source:' + source['id']] = checked_file(source['path'], source['sha256'])
        sources[source['id']] = source
    # Acyclic provenance; each ancestor's actual bytes become part of the component.
    remaining, children = {}, defaultdict(list)
    for source in sources.values():
        require(set(source['parent_ids']) <= sources.keys(), 'Unknown source parent ID')
        remaining[source['id']] = len(source['parent_ids'])
        for parent in source['parent_ids']:
            children[parent].append(source['id'])
    queue = deque(sorted(sid for sid, count in remaining.items() if not count))
    ancestors = {}
    while queue:
        sid = queue.popleft()
        ancestors[sid] = {sid}
        for parent in sources[sid]['parent_ids']:
            ancestors[sid].update(ancestors[parent])
        require(len(ancestors[sid]) <= 256, 'Source lineage exceeds 256 ancestors')
        for child in children[sid]:
            remaining[child] -= 1
            if not remaining[child]:
                queue.append(child)
    require(len(ancestors) == len(sources), 'Cyclic source provenance forbidden')

    fields = {'id', 'path', 'sha256', 'role', 'expected', 'condition', 'side', 'variant', 'issue',
              'physical_note_ids', 'capture_session_ids', 'identity_status', 'source_id', 'image_scope',
              'source', 'rights', 'verification'}
    samples, sample_hashes, note_labels, unknown, used_sources = {}, {}, {}, [], set()
    graph = Components()
    for row in manifest['samples']:
        rm.require_fields(row, fields, 'Sample')
        sid = row['id']
        identifier(sid, 'sample id')
        require(sid not in samples, 'Duplicate sample ID')
        require(type(row['role']) is str and row['role'] in ROLES, sid + ': invalid role')
        require(type(row['condition']) is str and row['condition'] in CONDITIONS, sid + ': invalid condition')
        for field in ('side', 'variant', 'issue', 'source', 'rights'):
            text(row[field], sid + ': ' + field)
        expected = metrics_core.denomination(row['expected'], 'unknown')
        string_list(row['physical_note_ids'], sid + ': physical_note_ids', True)
        string_list(row['capture_session_ids'], sid + ': capture_session_ids', True)
        require(row['identity_status'] in ('complete', 'unknown'), sid + ': identity_status must be complete or unknown')
        require(type(row['source_id']) is str and row['source_id'] in sources, sid + ': unknown source_id')
        family = ancestors[row['source_id']]
        used_sources.update(family)
        note_count = len(row['physical_note_ids'])
        if expected == 'unknown':
            require(row['condition'] in NEGATIVE, sid + ': unknown expected label needs a negative condition')
            require(row['side'] == row['variant'] == row['issue'] == 'n/a', sid + ': negative metadata must be n/a')
            minimum_notes = 0 if row['condition'] in {'non_money', 'reproduction', 'screen'} else (2 if row['condition'] == 'multiple_notes' else 1)
        else:
            require(row['condition'] in POSITIVE, sid + ': negative/multiple/composite scenes require expected=unknown')
            require(row['side'] in ('front', 'back') and row['variant'] in ('paper', 'polymer'), sid + ': unsupported side/material')
            require(row['issue'].lower() not in UNKNOWN, sid + ': positive note issue must be identified')
            require(row['variant'] != 'polymer' or expected == 5, sid + ': polymer profile is 5 SAR only')
            require(note_count <= 1, sid + ': single-note sample lists multiple notes')
            minimum_notes = 1
            for note in row['physical_note_ids']:
                label = (expected, row['variant'], row['issue'])
                require(note not in note_labels or note_labels[note] == label, sid + ': conflicting physical-note label/issue/material')
                note_labels[note] = label
        if row['condition'] == 'non_money':
            require(note_count == 0, sid + ': non_money cannot declare physical banknotes')
        if row['identity_status'] == 'unknown' or note_count < minimum_notes or not row['capture_session_ids']:
            unknown.append(sid)
        verification = row['verification']
        rm.require_fields(verification, {'verified', 'verification_kind', 'verified_by', 'verified_on', 'method'}, 'Sample verification')
        require(verification['verified'] is True, sid + ': explicit label/provenance review required')
        for field in ('verification_kind', 'verified_by', 'verified_on', 'method'):
            text(verification[field], sid + ': verification ' + field)
        kind = verification['verification_kind']
        require(kind in ('human_review', 'assistant_visual_review', 'synthetic_fixture'), sid + ': invalid review kind')
        require((kind == 'synthetic_fixture') == (manifest['data_kind'] == 'synthetic'), sid + ': real/synthetic review mismatch')
        if row['role'] == 'reference':
            require(expected != 'unknown' and row['image_scope'] == 'reviewed_note_boundary', sid + ': invalid reference sample')
        else:
            require(row['image_scope'] == 'entire_frame', sid + ': queries must be entire frames, never handpicked crops')
            require(row['sha256'] == sources[row['source_id']]['sha256'], sid + ': query bytes must equal declared entire-frame source')
        resolved = checked_file(row['path'], row['sha256'])
        require(row['sha256'] not in sample_hashes, sid + ': duplicate sample image bytes (' + sample_hashes.get(row['sha256'], '') + ')')
        sample_hashes[row['sha256']] = sid
        paths[sid] = resolved
        tokens = ['sample:' + sid, 'image:' + row['sha256']]
        tokens += ['note:' + value for value in row['physical_note_ids']]
        tokens += ['session:' + value for value in row['capture_session_ids']]
        tokens += ['image:' + sources[value]['sha256'] for value in family]
        graph.join(tokens)
        samples[sid] = row
    require(used_sources == sources.keys(), 'Unused source records forbidden; inventory must describe the evaluated families only')
    require({row['role'] for row in samples.values()} == ROLES, 'Inventory must contain reference, calibration and test roles')
    groups = {sid: graph.root('sample:' + sid) for sid in samples}
    roles_for_group = defaultdict(set)
    for sid, group in groups.items():
        roles_for_group[group].add(samples[sid]['role'])
    require(all(len(roles) == 1 for roles in roles_for_group.values()),
            'Cross-role leakage through physical notes, capture sessions, image bytes or linked source families')

    # Reuse the official matcher manifest schema and image checks, not a parallel reference loader.
    reference_manifest, _ = rm.load_manifest(reference_path)
    expected_kind = 'synthetic_mechanics' if manifest['data_kind'] == 'synthetic' else 'private_banknote_photos'
    require(reference_manifest['reference_kind'] == expected_kind, 'Reference and inventory data kinds differ')
    reference_rows = {sid: row for sid, row in samples.items() if row['role'] == 'reference'}
    require(set(reference_rows) == {row['id'] for row in reference_manifest['references']}, 'Reference manifest must exactly match reference-role sample IDs')
    for reference in reference_manifest['references']:
        row = reference_rows[reference['id']]
        require(row['sha256'] == reference['sha256'] and row['expected'] == reference['label']
                and row['side'] == reference['side'] and row['variant'] == reference['material']
                and row['issue'] == reference['issue'], row['id'] + ': reference label/hash metadata mismatch')
        require(row['physical_note_ids'] == [reference['physical_note_id']]
                and row['capture_session_ids'] == [reference['capture_session_id']], row['id'] + ': reference identity metadata mismatch')
        require(paths[row['id']] == rm.local_path(reference_path.resolve().parent, reference['path']), row['id'] + ': reference path mismatch')
    require(digest(path.read_bytes()) == digest(inventory_bytes) and digest(reference_path.read_bytes()) == digest(reference_bytes),
            'Manifest changed during inventory validation')
    return {'manifest': manifest, 'reference_manifest': reference_manifest, 'samples': samples, 'paths': paths,
            'inventory_sha256': digest(inventory_bytes), 'reference_manifest_sha256': digest(reference_bytes),
            'groups': groups, 'unknown_identity_samples': unknown, 'image_hashes': hashes,
            'unique_image_bytes': total_bytes, 'inventory_path': path, 'reference_path': reference_path}


def bindings(inventory):
    require(digest(inventory['inventory_path'].read_bytes()) == inventory['inventory_sha256'], 'Inventory changed after validation')
    require(digest(inventory['reference_path'].read_bytes()) == inventory['reference_manifest_sha256'], 'Reference manifest changed after validation')
    current_sources = {name: digest(path.read_bytes()) for name, path in SOURCE_PATHS.items()}
    require(current_sources == LOADED_SOURCE_HASHES, 'Executable source changed after import; restart on the exact frozen bytes')
    return {'inventory_sha256': inventory['inventory_sha256'],
            'reference_manifest_sha256': inventory['reference_manifest_sha256'],
            'source_sha256': dict(LOADED_SOURCE_HASHES),
            'policy': asdict(rm.POLICY), 'algorithm_parameters': json.loads(json.dumps(rm.ALGORITHMS)),
            'runtime': {'python': platform.python_version(), 'opencv': getattr(rm.cv2, '__version__', None),
                        'numpy': np.__version__, 'pillow': pillow_version},
            'data_kind': inventory['manifest']['data_kind'], 'dataset_id': inventory['manifest']['dataset_id']}


def dataset_receipt(inventory):
    key = digest(inventory['manifest']['dataset_id'].encode())
    return inventory['inventory_path'].resolve().parent / ('.currency-holdout-' + key + '.test-started.json')


def require_independence(inventory):
    require(not inventory['unknown_identity_samples'], 'Independence unavailable: missing/unknown physical-note or capture identities for '
            + ', '.join(inventory['unknown_identity_samples']))


def coverage(rows, groups):
    cells = {}
    def cell(name, selected):
        cells[name] = {'samples': len(selected), 'independent_groups': len({groups[r['id']] for r in selected})}
    for denomination in rm.LABELS:
        for side in ('front', 'back'):
            for condition in sorted(POSITIVE):
                cell(f'SAR {denomination}/{side}/{condition}', [r for r in rows if r['expected'] == denomination and r['side'] == side and r['condition'] == condition])
    for material in ('paper', 'polymer'):
        for side in ('front', 'back'):
            for condition in sorted(POSITIVE):
                cell(f'SAR 5 {material}/{side}/{condition}', [r for r in rows if r['expected'] == 5 and r['variant'] == material and r['side'] == side and r['condition'] == condition])
    for condition in sorted(NEGATIVE):
        cell(condition, [r for r in rows if r['condition'] == condition])
    return {'minimum_presence_only_not_release_criterion': 1, 'cells': cells,
            'missing_cells': [name for name, value in cells.items() if not value['independent_groups']]}


def summarize(rows, predictions, groups):
    """Reuse existing statistical definitions; add explicit composite and cost slices."""
    adapted = [{**row, 'sample_id': row['id'], 'group_id': groups[row['id']]} for row in rows]
    labels = (*rm.LABELS, 'unknown')
    matrix = {str(label): {str(output): 0 for output in (*rm.LABELS, 'abstain')} for label in labels}
    errors, costs = [], Counter()
    for row in rows:
        output = predictions[row['id']]
        matrix[str(row['expected'])][str(output)] += 1
        if output != 'abstain' and output != row['expected']:
            errors.append({'sample_id': row['id'], 'expected': row['expected'], 'experimental_label': output, 'condition': row['condition']})
            if row['expected'] != 'unknown':
                costs[(row['expected'], output)] += 1
    per_denomination = {}
    for value in rm.LABELS:
        selected = [r for r in adapted if r['expected'] == value]
        emitted = [r for r in adapted if predictions[r['id']] == value]
        true = sum(r['expected'] == value for r in emitted)
        per_denomination[str(value)] = {
            'expected_samples': len(selected), 'experimental_labels_as_this_value': len(emitted),
            'precision': metrics_core.rate(true, len(emitted)), 'recall': metrics_core.rate(true, len(selected)),
            'abstention_rate': metrics_core.rate(sum(predictions[r['id']] == 'abstain' for r in selected), len(selected)),
            'wrong_amount_counts': {str(other): matrix[str(value)][str(other)] for other in rm.LABELS if other != value}}
    return {'overall': metrics_core.metrics(adapted, predictions, groups),
            'metric_vocabulary_note': "Shared metrics use 'spoken'; here this means experimental Python acceptance, not actual app speech.",
            'per_denomination': per_denomination,
            'by_condition': {c: metrics_core.metrics([r for r in adapted if r['condition'] == c], predictions, groups) for c in sorted(CONDITIONS)},
            'by_side': {s: metrics_core.metrics([r for r in adapted if r['side'] == s], predictions, groups) for s in ('front', 'back', 'n/a')},
            'by_variant': {v: metrics_core.metrics([r for r in adapted if r['variant'] == v], predictions, groups) for v in sorted({r['variant'] for r in adapted})},
            'by_issue': {v: metrics_core.metrics([r for r in adapted if r['issue'] == v], predictions, groups) for v in sorted({r['issue'] for r in adapted})},
            'confusion_matrix': matrix, 'wrong_decisions': errors,
            'critical_100_vs_1': {'expected_100_accepted_1': matrix['100']['1'], 'expected_1_accepted_100': matrix['1']['100']},
            'costly_confusions': [{'expected': expected, 'accepted': output, 'count': count,
                                  'absolute_error_sar_per_decision': abs(expected - output),
                                  'direction': 'overstatement' if output > expected else 'understatement'}
                                 for (expected, output), count in sorted(costs.items(), key=lambda x: (-abs(x[0][0] - x[0][1]), x[0]))]}


def run_role(inventory, role, algorithm):
    require(role in ('calibration', 'test') and algorithm in rm.ALGORITHMS, 'Invalid run role or algorithm')
    rows = [row for row in inventory['samples'].values() if row['role'] == role]
    expected_bindings = bindings(inventory)
    cases, predictions, errors = [], {}, []
    for row in rows:
        start = time.perf_counter()
        try:
            # Detect concurrent edits before and after inference; never report a mixed run as frozen.
            require(bindings(inventory) == expected_bindings, 'Run bindings changed during execution')
            # Check again immediately before inference; do not crop or choose an ROI.
            rm.checked_hash(rm.bounded_bytes(inventory['paths'][row['id']], rm.MAX_FILE_BYTES), row['sha256'])
            result = rm.run(inventory['reference_path'], inventory['paths'][row['id']], algorithm)
            require(bindings(inventory) == expected_bindings, 'Run bindings changed during execution')
            rm.checked_hash(rm.bounded_bytes(inventory['paths'][row['id']], rm.MAX_FILE_BYTES), row['sha256'])
            require(result.get('decision') in ('unknown', 'ambiguous', 'denomination_experiment'), 'Malformed matcher decision')
            label = result.get('selected_reference_label')
            if result['decision'] == 'denomination_experiment':
                metrics_core.denomination(label, 'abstain')
                require(type(label) is int, 'Accepted result requires an integer denomination')
            else:
                require(label is None, 'Abstaining result cannot carry a denomination')
                label = 'abstain'
            encoded_result = json.dumps(result, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()
            # Full per-reference candidate arrays are diagnostic, not necessary for metrics.
            # Keep per-frame decisions and an audit digest without O(samples*references) output.
            compact = {key: value for key, value in result.items()
                       if key not in {'candidates', 'coverage', 'thresholds', 'algorithm_parameters', 'disclaimer'}}
            compact['candidate_count'] = len(result.get('candidates', []))
            compact['full_result_sha256'] = digest(encoded_result)
            predictions[row['id']] = label
            cases.append({'sample_id': row['id'], 'status': 'completed', 'experimental_label': label,
                          'expected': row['expected'], 'condition': row['condition'], 'result': compact,
                          'elapsed_seconds': time.perf_counter() - start})
        except Exception as error:
            # A crashed/invalid execution is never quietly recoded as a safe abstention.
            failure = {'sample_id': row['id'], 'status': 'execution_error', 'error_type': type(error).__name__,
                       'reason': str(error)[:512], 'elapsed_seconds': time.perf_counter() - start}
            cases.append(failure)
            errors.append(failure)
    return {'algorithm': algorithm, 'role': role, 'case_count': len(rows), 'cases': cases,
            'execution_errors': errors, 'coverage': coverage(rows, inventory['groups']),
            'metrics_available': not errors,
            'metrics': summarize(rows, predictions, inventory['groups']) if not errors else None}


def base_report(inventory, kind):
    stage_scopes = {
        'inventory_validation_only': 'Inventory validation only; no calibration or held-out inference',
        'calibration_only': 'Calibration-only Python experiment; no held-out test inference',
        'frozen_before_test': 'Frozen Python policy artifact; no held-out test results',
        'held_out_test': 'Held-out Python experiment',
    }
    require(kind in stage_scopes, 'Unknown evaluation report kind')
    scope = stage_scopes[kind]
    if inventory['manifest']['data_kind'] == 'synthetic':
        scope += '; SYNTHETIC HARNESS ONLY; NOT CURRENCY ACCURACY'
    else:
        scope += ('; independence unsupported: missing or unknown identities'
                  if inventory['unknown_identity_samples']
                  else '; independence supported only by declared identities')
        scope += '; not native/device acceptance'
    return {'schema_version': 1, 'evaluation_kind': kind, 'bindings': bindings(inventory),
            'evidence_scope': scope,
            'release_approval': False, 'validated': False, 'monetary_answer': None,
            'split_sample_counts': dict(Counter(r['role'] for r in inventory['samples'].values())),
            'caveats': CAVEATS}


def calibrate(inventory):
    require_independence(inventory)
    report = base_report(inventory, 'calibration_only')
    report['test_samples_evaluated'] = 0
    report['methods'] = {method: run_role(inventory, 'calibration', method) for method in rm.ALGORITHMS}
    return report


def check_calibration_report(inventory, report):
    base_fields = set(base_report(inventory, 'calibration_only'))
    rm.require_fields(report, base_fields | {'methods', 'test_samples_evaluated'}, 'Calibration report')
    require(report['schema_version'] == 1 and type(report['schema_version']) is int, 'Malformed calibration schema')
    require(report['evaluation_kind'] == 'calibration_only' and type(report['test_samples_evaluated']) is int
            and report['test_samples_evaluated'] == 0, 'Expected calibration-only report')
    require(report['bindings'] == bindings(inventory), 'Calibration bindings changed; rerun calibration, not heldout test')
    methods = report['methods']
    require(type(methods) is dict and set(methods) == set(rm.ALGORITHMS), 'Calibration report must compare all three methods')
    rows = [row for row in inventory['samples'].values() if row['role'] == 'calibration']
    samples = {row['id']: row for row in rows}
    for algorithm, method in methods.items():
        rm.require_fields(method, {'algorithm', 'role', 'case_count', 'cases', 'execution_errors', 'coverage', 'metrics_available', 'metrics'}, 'Calibration method')
        require(method['algorithm'] == algorithm and method['role'] == 'calibration', 'Calibration method/role mismatch')
        require(type(method['case_count']) is int and method['case_count'] == len(rows), 'Calibration case count mismatch')
        require(method['metrics_available'] is True and method['execution_errors'] == [], 'Calibration execution errors must be resolved before freeze')
        require(type(method['cases']) is list and len(method['cases']) == len(rows), 'Calibration cases missing')
        predictions = {}
        for case in method['cases']:
            rm.require_fields(case, {'sample_id', 'status', 'experimental_label', 'expected', 'condition', 'result', 'elapsed_seconds'}, 'Calibration case')
            sid = case['sample_id']
            require(type(sid) is str and sid in samples and sid not in predictions, 'Calibration case identity mismatch')
            metrics_core.denomination(case['expected'], 'unknown')
            require(case['status'] == 'completed' and case['expected'] == samples[sid]['expected']
                    and case['condition'] == samples[sid]['condition'], 'Calibration case metadata mismatch')
            label = metrics_core.denomination(case['experimental_label'], 'abstain')
            require(type(case['result']) is dict, 'Calibration case result missing')
            result = case['result']
            require(result.get('decision') == 'denomination_experiment' if label != 'abstain'
                    else result.get('decision') in ('unknown', 'ambiguous'), 'Calibration decision mismatch')
            require((type(result.get('selected_reference_label')) is int if label != 'abstain' else result.get('selected_reference_label') is None)
                    and result.get('selected_reference_label') == (label if label != 'abstain' else None), 'Calibration label mismatch')
            require(type(result.get('candidate_count')) is int and result['candidate_count'] >= 0, 'Malformed calibration candidate count')
            require(type(result.get('full_result_sha256')) is str and re.fullmatch(r'[0-9a-f]{64}', result['full_result_sha256']), 'Malformed calibration result digest')
            require(type(case['elapsed_seconds']) in (int, float) and 0 <= case['elapsed_seconds'] <= sys.float_info.max
                    and math.isfinite(case['elapsed_seconds']), 'Calibration elapsed time invalid')
            predictions[sid] = label
        require(method['coverage'] == coverage(rows, inventory['groups']), 'Calibration coverage mismatch')
        require(method['metrics'] == summarize(rows, predictions, inventory['groups']), 'Calibration metrics disagree with its complete case records')


def freeze(inventory, calibration_path, algorithm, rationale, test_unseen):
    require_independence(inventory)
    require(test_unseen is True, 'Explicit unseen-test attestation required before freezing')
    require(type(algorithm) is str and algorithm in rm.ALGORITHMS, 'Choose one supported method using calibration only')
    text(rationale, 'selection rationale')
    require(not dataset_receipt(inventory).exists(), 'This dataset already has a started held-out evaluation; do not refreeze exposed test data')
    calibration_bytes = rm.bounded_bytes(Path(calibration_path), MAX_JSON_BYTES)
    calibration = parse_json(calibration_bytes)
    check_calibration_report(inventory, calibration)
    return {**base_report(inventory, 'frozen_before_test'), 'selected_algorithm': algorithm,
            'selection_rationale': rationale, 'test_unseen_attested': True,
            'frozen_at_utc': datetime.now(timezone.utc).isoformat(),
            'calibration_report_sha256': digest(calibration_bytes)}


def test_holdout(inventory, freeze_path, output_path):
    require_independence(inventory)
    freeze_bytes = rm.bounded_bytes(Path(freeze_path), MAX_JSON_BYTES)
    frozen = parse_json(freeze_bytes)
    freeze_sha256 = digest(freeze_bytes)
    rm.require_fields(frozen, set(base_report(inventory, 'frozen_before_test')) | {'selected_algorithm', 'selection_rationale', 'test_unseen_attested', 'frozen_at_utc', 'calibration_report_sha256'}, 'Frozen artifact')
    require(type(frozen['schema_version']) is int and frozen['schema_version'] == 1, 'Malformed frozen schema')
    text(frozen['selection_rationale'], 'Frozen selection rationale')
    require(type(frozen['calibration_report_sha256']) is str and re.fullmatch(r'[0-9a-f]{64}', frozen['calibration_report_sha256']), 'Malformed calibration digest')
    text(frozen['frozen_at_utc'], 'Frozen timestamp')
    require(datetime.fromisoformat(frozen['frozen_at_utc']).utcoffset() is not None, 'Frozen timestamp needs a timezone')
    require(frozen.get('evaluation_kind') == 'frozen_before_test' and frozen.get('test_unseen_attested') is True, 'Expected explicit frozen policy artifact')
    require(frozen.get('bindings') == bindings(inventory), 'Frozen source, runtime, references, inventory or thresholds changed')
    method = frozen.get('selected_algorithm')
    require(type(method) is str and method in rm.ALGORITHMS, 'Frozen algorithm invalid')
    require(not Path(output_path).exists(), 'Output exists; never overwrite previous evidence')
    # This is an audit guard, not tamper-proof proof against prior human exposure.
    receipt = Path(str(freeze_path) + '.test-started.json')
    require(Path(output_path).resolve() not in {receipt.resolve(), dataset_receipt(inventory).resolve()}, 'Output cannot replace a test-started receipt')
    write_new(dataset_receipt(inventory), {'schema_version': 1, 'dataset_id': inventory['manifest']['dataset_id'],
              'inventory_sha256': inventory['inventory_sha256'], 'freeze_sha256': freeze_sha256,
              'started_at_utc': datetime.now(timezone.utc).isoformat()})
    write_new(receipt, {'schema_version': 1, 'started_at_utc': datetime.now(timezone.utc).isoformat(),
                        'freeze_sha256': freeze_sha256, 'output': str(Path(output_path).resolve())})
    report = base_report(inventory, 'held_out_test')
    report['freeze_sha256'] = freeze_sha256
    report['selected_algorithm'] = method
    report['result'] = run_role(inventory, 'test', method)
    write_new(output_path, report)
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('validate', 'calibrate', 'freeze', 'test'))
    parser.add_argument('--inventory', required=True, type=Path)
    parser.add_argument('--references', required=True, type=Path)
    parser.add_argument('--allow-synthetic', action='store_true')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--calibration-report', type=Path)
    parser.add_argument('--algorithm', choices=tuple(rm.ALGORITHMS))
    parser.add_argument('--selection-rationale')
    parser.add_argument('--attest-test-unseen', action='store_true')
    parser.add_argument('--freeze', dest='freeze_path', type=Path)
    args = parser.parse_args(argv)
    try:
        require(not args.output.exists(), 'Output exists; preserve previous evidence')
        inventory = load_inventory(args.inventory, args.references, args.allow_synthetic)
        if args.stage == 'validate':
            report = base_report(inventory, 'inventory_validation_only')
            report.update({'independence_supported_by_declared_identities': not inventory['unknown_identity_samples'],
                           'unknown_identity_samples': inventory['unknown_identity_samples'],
                           'unique_declared_image_bytes': inventory['unique_image_bytes']})
        elif args.stage == 'calibrate':
            report = calibrate(inventory)
        elif args.stage == 'freeze':
            require(args.calibration_report and args.algorithm and args.selection_rationale, 'Freeze requires calibration report, algorithm and selection rationale')
            report = freeze(inventory, args.calibration_report, args.algorithm, args.selection_rationale, args.attest_test_unseen)
        else:
            require(args.freeze_path, 'Test requires --freeze')
            report = test_holdout(inventory, args.freeze_path, args.output)
            print(json.dumps({'evaluation_kind': report['evaluation_kind'], 'output': str(args.output), 'release_approval': False}))
            return 0 if report['result']['metrics_available'] else 3
        write_new(args.output, report)
        print(json.dumps({'evaluation_kind': report['evaluation_kind'], 'output': str(args.output), 'release_approval': False}))
        return 3 if args.stage == 'calibrate' and any(not m['metrics_available'] for m in report['methods'].values()) else 0
    except (rm.InputError, metrics_core.ValidationError, OSError, ValueError, TypeError, KeyError, RecursionError) as error:
        print('Evaluation refused: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
