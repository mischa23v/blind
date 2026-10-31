#!/usr/bin/env python3
import json
from pathlib import Path
import tempfile
from resolution import inspect, PATH, REVISION

with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    assert inspect(root)['status'] == 'absent'
    path = root / PATH
    path.parent.mkdir(parents=True)
    valid = {'version': 3, 'originHash': 'a' * 64, 'pins': [{'identity': 'grdb.swift',
             'kind': 'remoteSourceControl', 'location': 'https://github.com/groue/GRDB.swift.git',
             'state': {'revision': REVISION, 'version': '7.11.1'}}]}
    path.write_text(json.dumps(valid))
    assert inspect(root)['status'] == 'validated_public_exact_pin'
    for case in ('private_location', 'wrong_revision', 'extra_package', 'unknown_schema', 'oversize', 'malformed', 'duplicate_keys'):
        bad = json.loads(json.dumps(valid))
        if case == 'private_location': bad['pins'][0]['location'] = 'https://example.invalid/private'
        elif case == 'wrong_revision': bad['pins'][0]['state']['revision'] = '0' * 40
        elif case == 'extra_package': bad['pins'] *= 2
        elif case == 'unknown_schema': bad['version'] = 4
        data = json.dumps(bad)
        if case == 'oversize': data = 'x' * 65537
        elif case == 'malformed': data = '{'
        elif case == 'duplicate_keys': data = data.replace('"version": 3', '"version": 4, "version": 3')
        path.write_text(data)
        result = inspect(root)
        assert result['status'] == 'rejected', case
        assert 'pins' not in result, 'Unverified fields must not be retained'
    path.unlink()
    path.symlink_to(root / 'missing')
    assert inspect(root)['status'] == 'rejected'
print('PASS: absent/known exact public pin; reject seven invalid JSON/pin/size cases and symlink without retaining unverified fields')
