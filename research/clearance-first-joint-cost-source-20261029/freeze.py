"""Standard-library source freeze only; never imports a worker or native code."""
import hashlib
import json
import pathlib
import sys
H = pathlib.Path(__file__).resolve().parent
R = H.parents[1]


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    prior = R/'research/clearance-first-coffee-repair-source-20261029/SOURCE_PINS.json'
    old = json.loads(prior.read_text()); inputs = dict(old['inputs'])
    for name,expected in inputs.items():
        path = pathlib.Path(name.replace('@WORKSPACE@',str(R.parent)))
        if not path.is_absolute(): path = R/path
        if sha(path) != expected: raise ValueError('prior pinned input changed: '+name)
    extra = [prior,R/'research/clearance-first-coffee-repair-result-20261029/PROPOSALS.json.gz']
    extra += [H/name for name in ('joint_cost.py','fixtures.py','run_controls.py',
                                 'prepare_coffee.py','run_aggregate.py','freeze.py','README.md')]
    for path in extra: inputs[str(path.relative_to(R))] = sha(path)
    py = str(pathlib.Path(sys.executable).resolve())
    if inputs.get(py) != sha(pathlib.Path(py)): raise ValueError('Python differs from previous runtime')
    manifest = dict(old)
    manifest.update(status='SOURCE_FROZEN_AWAITING_ROOT_ADMISSION',inputs=inputs,
                    workRoot='@WORKSPACE@/coffee-clearance-comparison-attempt-003',
                    controlsCommand=[py,'-B','@PROTOCOL@/fixtures.py'],
                    comparisonCommand=[py,'@PROTOCOL@/prepare_coffee.py','--replay-root',
                        '@WORKSPACE@/coffee-native-replay-prepared-002','--canonical-paths',
                        '@PROTOCOL@/../coffee-room-journey-recovery-20261029/collision-protocol/CURRENT_PATHS_20.json',
                        '--out','@WORKSPACE@/coffee-clearance-comparison-attempt-003/comparison',
                        '--pins-sha256','@PINS_SHA256@'])
    manifest['runtimeLimitations'] += ' Two separate ranking channels, not common physical-clearance units or exact midpoint authority.'
    (H/'SOURCE_PINS.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'inputs':len(inputs),'manifestSHA256':sha(H/'SOURCE_PINS.json')}))


if __name__ == '__main__': main()
