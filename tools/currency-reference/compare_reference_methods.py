#!/usr/bin/env python3
"""Reconstructed bounded development comparator. No historical photo results rerun.

Counts diagnostic cases, not independent samples or population accuracy.
"""
from __future__ import annotations
import argparse
from dataclasses import asdict
import hashlib
import json
from pathlib import Path
import time
import reference_match as rm
MAX_QUERIES = 32

def load_queries(path):
    try:
        manifest = json.loads(rm.bounded_bytes(path, rm.MAX_MANIFEST_BYTES), object_pairs_hook=rm.strict_json_object)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise rm.InputError('Invalid query manifest JSON') from exc
    rm.require_fields(manifest, {'schema_version', 'evaluation_kind', 'independence_summary', 'queries'}, 'Query manifest')
    if type(manifest['schema_version']) is not int or manifest['schema_version'] != 1 or manifest['evaluation_kind'] != 'development_diagnostic':
        raise rm.InputError('Only development_diagnostic query manifests are supported')
    rm.text_field(manifest['independence_summary'], 'independence summary')
    if type(manifest['queries']) is not list or not 1 <= len(manifest['queries']) <= MAX_QUERIES:
        raise rm.InputError('Query count must be between 1 and 32')
    root = path.resolve().parent
    ids, loaded = set(), []
    fields = {'id', 'path', 'sha256', 'expected_label', 'must_abstain', 'case_role', 'physical_note_id',
              'capture_session_id', 'independence_from_references', 'source', 'rights', 'notes'}
    for query in manifest['queries']:
        rm.require_fields(query, fields, 'Query')
        for field in fields - {'expected_label', 'must_abstain', 'physical_note_id', 'capture_session_id'}:
            rm.text_field(query[field], field)
        if query['id'] in ids:
            raise rm.InputError('Duplicate query IDs forbidden')
        ids.add(query['id'])
        if query['expected_label'] is not None and (type(query['expected_label']) is not int or query['expected_label'] not in rm.LABELS):
            raise rm.InputError('Expected label must be supported integer or null for non-SAR negatives')
        if type(query['must_abstain']) is not bool:
            raise rm.InputError('must_abstain must be explicit boolean')
        for field in ['physical_note_id', 'capture_session_id']:
            if query[field] is not None: rm.text_field(query[field], field)
        resolved = rm.local_path(root, query['path'])
        rm.checked_hash(rm.bounded_bytes(resolved, rm.MAX_FILE_BYTES), query['sha256'])
        loaded.append((query, resolved))
    return manifest, loaded

def classify_outcome(query, result):
    label = result.get('selected_reference_label') if result['decision'] == 'denomination_experiment' else None
    if label is None: outcome = 'abstention'
    elif query['expected_label'] is None: outcome = 'negative_false_accept'
    elif label != query['expected_label']: outcome = 'wrong_label'
    else: outcome = 'correct_experimental_label'
    return {'outcome': outcome, 'policy_false_accept': bool(query['must_abstain'] and label is not None)}

def compare(reference_path, query_path):
    query_manifest, queries = load_queries(query_path)
    reference_manifest, _ = rm.load_manifest(reference_path)
    report = {'evaluation_kind': 'development_diagnostic', 'source_status': 'reconstructed_not_original',
              'validated': False, 'monetary_answer': None, 'disclaimer': rm.DISCLAIMER,
              'statistical_warning': 'Case counts are not independent samples or population accuracy.',
              'independence_summary': query_manifest['independence_summary'],
              'reference_manifest_sha256': hashlib.sha256(reference_path.read_bytes()).hexdigest(),
              'query_manifest_sha256': hashlib.sha256(query_path.read_bytes()).hexdigest(),
              'matcher_source_sha256': hashlib.sha256(Path(rm.__file__).read_bytes()).hexdigest(),
              'runner_source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'reference_records': reference_manifest['references'], 'frozen_thresholds': asdict(rm.POLICY), 'methods': {}}
    for algorithm in rm.ALGORITHMS:
        cases = []
        for query, image_path in queries:
            start = time.perf_counter()
            result = rm.run(reference_path, image_path, algorithm)
            cases.append({'query': query, 'result': result, 'elapsed_seconds': time.perf_counter() - start,
                          **classify_outcome(query, result)})
        report['methods'][algorithm] = {
            'case_count': len(cases),
            'correct_experimental_labels': sum(c['outcome'] == 'correct_experimental_label' for c in cases),
            'wrong_labels': sum(c['outcome'] == 'wrong_label' for c in cases),
            'negative_false_accepts': sum(c['outcome'] == 'negative_false_accept' for c in cases),
            'policy_false_accepts': sum(c['policy_false_accept'] for c in cases),
            'abstentions': sum(c['outcome'] == 'abstention' for c in cases),
            'elapsed_seconds_total': sum(c['elapsed_seconds'] for c in cases),
            'timing_scope': 'Sequential cold desktop calls including validation/extraction/matching; not phone latency.',
            'cases': cases}
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--references', required=True, type=Path)
    parser.add_argument('--queries', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists(): parser.error('Output exists; preserve prior evidence and choose new name')
    report = compare(args.references, args.queries)
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(report, stream, indent=2, allow_nan=False)
    for method, data in report['methods'].items():
        print(json.dumps({'algorithm': method, **{k: v for k, v in data.items() if k != 'cases'}}))
if __name__ == '__main__': main()
