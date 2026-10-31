#!/usr/bin/env python3
"""Static contracts only. Never reports Swift fixture execution."""
import ast
import hashlib
import json
from pathlib import Path
import re
import yaml

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent

def main():
    checks = []
    def check(name, value):
        assert value, name
        checks.append(name)
    for path in [HERE / 'apple/ci.py', Path(__file__)]:
        ast.parse(path.read_text())
        checks.append('Python syntax: ' + path.name)
    workflow = ROOT / '.github/workflows/native-mesh-decoder.yml'
    # BaseLoader preserves YAML1.2's GitHub `on` spelling rather than YAML1.1 bool conversion.
    config = yaml.load(workflow.read_text(), Loader=yaml.BaseLoader)
    check('read-only permissions', config['permissions'] == {'contents': 'read'})
    check('same review branch only', config['on']['push']['branches'] == ['codex/recovery-hazard-order-20261027'])
    check('narrow triggers', config['on']['push']['paths'] == ['research/native-mesh-decoder-81/**', '.github/workflows/native-mesh-decoder.yml'])
    job = config['jobs']['decoder']
    check('public repository and branch guard', job['if'] == "github.repository == 'mischa23v/blind' && github.event.repository.private == false && github.ref == 'refs/heads/codex/recovery-hazard-order-20261027'")
    check('bounded Apple runner', job['runs-on'] == 'xcode-27' and int(job['timeout-minutes']) == 18)
    actions = [step['uses'] for step in job['steps'] if 'uses' in step]
    check('pinned actions', all(re.fullmatch(r'actions/[a-z-]+@[a-f0-9]{40}', action) for action in actions))
    previous = (ROOT / '.github/workflows/native-room-mesh-package.yml').read_text()
    check('reuse existing action pins', all(action in previous for action in actions))
    check('credentials disabled', job['steps'][0]['with']['persist-credentials'] == 'false')
    check('short artifact retention', job['steps'][-1]['with']['retention-days'] == '3')
    source = (HERE / 'Sources/MeshBufferDecoder.swift').read_text()
    check('no runtime imports', 'import ' not in source)
    check('protected initializer', 'fileprivate init(revision:' in source)
    check('explicit no-authority outputs', 'physicalAuthority: Bool { false }' in source and 'coverageKnown: Bool { false }' in source)
    fixtures = (HERE / 'tests/main.swift').read_text()
    for marker in ['high UInt32 index not truncated', 'padded multiface classification', 'exact inclusive budgets', 'late nonfinite vertex rejects full revision', 'transform preserved bit exactly', 'transform not preapplied']:
        check('fixture authored: ' + marker, marker in fixtures)
    for name, digest in json.loads((HERE / 'SOURCE_PINS.json').read_text()).items():
        check('source hash: ' + name, hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest)
    result = {'staticChecksPassed': len(checks), 'checks': checks,
              'swiftExecutedLocally': False, 'appleExecution': 'pending',
              'runtimeActivation': False, 'physicalAuthority': False}
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
