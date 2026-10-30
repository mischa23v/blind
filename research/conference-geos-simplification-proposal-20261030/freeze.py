#!/usr/bin/env python3
"""Stdlib-only exact source manifest. Never imports GEOS/scientific/native code."""
import argparse, hashlib, json, pathlib, sys
H = pathlib.Path(__file__).resolve().parent
R = H.parents[1]
W = R.parent


def sha(path):
    with path.open('rb') as file: return hashlib.file_digest(file, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--work-root', type=pathlib.Path, required=True)
    cli_args = parser.parse_args(); work = cli_args.work_root.resolve(); work.relative_to(W)
    if work.exists(): raise ValueError('fresh diagnostic output required')
    prior_path = R / 'research/conference-replay-source-20261029/SOURCE_PINS.json'
    prior = json.loads(prior_path.read_text())
    if sha(prior_path) != 'f3d386429ae60db883d910d5145ff0538b72ea4939f4ab3ddac61af3149cd6e0':
        raise ValueError('original conference comparator manifest changed')
    inputs = dict(prior['inputs'])
    def expand(name):
        path = pathlib.Path(name.replace('@WORKSPACE@', str(W)))
        return path if path.is_absolute() else R / path
    for name, digest in inputs.items():
        if sha(expand(name)) != digest: raise ValueError('original native/source closure changed: ' + name)
    def add(path):
        key = str(path.relative_to(R)) if path.is_relative_to(R) else '@WORKSPACE@/' + str(path.relative_to(W)) if path.is_relative_to(W) else str(path)
        inputs[key] = sha(path)
    for name in ('candidate.py', 'test_candidate.py', 'runtime.py', 'contracts.py', 'run_controls.py', 'run_pair.py', 'run_aggregate.py', 'freeze.py', 'CANDIDATE_PROTOCOL.json'):
        add(H / name)
    add(prior_path)
    for name in ('schedule_source.py', 'ROUTES.json'): add(R / 'research/conference-body-source-20261029' / name)
    add(R / 'research/independent-2d-route-validator-20261029/validator.py')
    for name in ('libgeos.so.3.13.1', 'libgeos_c.so.1.19.2'): add(pathlib.Path('/usr/lib/x86_64-linux-gnu') / name)
    proposal = W / 'conference-native-comparison-attempt-002/comparison/PROPOSALS.json'
    receipt = W / 'conference-native-comparison-attempt-002/GUARD_RUN/RESULT.json'
    if sha(proposal) != '0f50fbbd52df3fa4369c0784579a93a2461b6c765b052acb2daf51d15f5f290f': raise ValueError('proposal changed')
    actual = json.loads(receipt.read_text())
    if actual['sourceCommit'] != '719ec504901639f65767b717f7f7dc817a482640' or actual['status'] != 'completed-zero-exit':
        raise ValueError('original comparator did not complete at required source')
    add(proposal); add(receipt)
    frozen = json.loads((R / 'research/conference-body-source-20261029/ROUTES.json').read_text())
    if frozen['totalEvents'] != 13704 or sum(row['eventCounts']['turn'] for row in frozen['paths']) != 12049: raise ValueError('baseline schedule changed')
    if 4 * sum(len(row['chain']) - 1 for row in frozen['paths']) != 2348: raise ValueError('native callback maximum changed')
    py = pathlib.Path(sys.executable).resolve()
    if py != pathlib.Path(prior['controlsCommand'][0]).resolve(): raise ValueError('unchanged Python runtime required')
    add(py)
    result = {'status': 'SOURCE_FROZEN_AWAITING_ROOT_ADMISSION', 'inputs': inputs,
              'proposalPath': '@WORKSPACE@/' + str(proposal.relative_to(W)),
              'meshPath': '@WORKSPACE@/conference-source-recovery/extracted-001/textured.obj',
              'registrationPath': 'research/conference-replay-input-inventory-20261029/evidence/REGISTRATION_RESULT.json',
              'targetsPath': 'research/conference-replay-input-inventory-20261029/TARGETS.json',
              'baselineRoutesPath': 'research/conference-body-source-20261029/ROUTES.json',
              'workRoot': '@WORKSPACE@/' + str(work.relative_to(W)),
              'comparisonDirectory': '@WORKSPACE@/' + str(work.relative_to(W)) + '/comparison',
              'controlsCommand': [str(py), '@PROTOCOL@/run_controls.py', '--pins', '@PROTOCOL@/SOURCE_PINS.json', '--pins-sha256', '@PINS_SHA256@'],
              'comparisonCommand': [str(py), '@PROTOCOL@/run_pair.py', '--pins', '@PROTOCOL@/SOURCE_PINS.json', '--pins-sha256', '@PINS_SHA256@'],
              'limits': {'cpuSeconds': 120, 'wallSeconds': 180, 'observedAggregateRSSBytes': 1024 ** 3, 'outputBytes': 16 * 1024 ** 2},
              'workerLimits': {'nativeSegmentCalls': 2348, 'maximumInputChainPoints': 1000, 'pairedOutputBytes': 15 * 1024 ** 2},
              'fixedToleranceMetres': .025, 'authoredControlCount': 17, 'runtimeClosureNotHermetic': True,
              'nativeRouteSearchAllowed': False, 'bodyComparisonAllowed': False, 'defaultEnabled': False,
              'independentCoverage': 'unknown', 'physicalAuthority': False, 'nativeExecuted': False}
    with (H / 'SOURCE_PINS.json').open('x') as file: json.dump(result, file, indent=2); file.write('\n')
    print(json.dumps({'manifestSHA256': sha(H / 'SOURCE_PINS.json'), 'inputCount': len(inputs), 'sourceOnly': True, 'nativeExecuted': False}))


if __name__ == '__main__': main()
