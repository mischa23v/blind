#!/usr/bin/env python3
"""Only the exact public GRDB pin may qualify as expected generated metadata."""
import hashlib
import json
import stat

PATH = 'ios/BlindAssist.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
REVISION = 'b83108d10f42680d78f23fe4d4d80fc88dab3212'
LOCATIONS = {'https://github.com/groue/GRDB.swift.git', 'https://github.com/groue/GRDB.swift'}

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key')
        result[key] = value
    return result


def inspect(root):
    path = root / PATH
    report = {'path': PATH, 'status': 'absent'}
    if not path.exists() and not path.is_symlink():
        return report
    # Refuse every symlink component: never follow a generated path outside source.
    relative = path.relative_to(root)
    cursor = root
    for part in relative.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            return dict(report, status='rejected', reason='symlink component')
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_size > 65536:
        return dict(report, status='rejected', reason='not regular or larger than 64 KiB')
    with path.open('rb') as stream:
        data = stream.read(65537)
    if len(data) > 65536:
        return dict(report, status='rejected', reason='grew beyond 64 KiB')
    report.update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
    try:
        value = json.loads(data, object_pairs_hook=unique_object)
        assert isinstance(value, dict) and set(value) <= {'pins', 'version', 'originHash'}
        assert type(value['version']) is int and value['version'] in (2, 3)
        if 'originHash' in value:
            assert isinstance(value['originHash'], str) and len(value['originHash']) == 64
            assert all(c in '0123456789abcdef' for c in value['originHash'])
        assert isinstance(value['pins'], list) and len(value['pins']) == 1
        pin = value['pins'][0]
        assert set(pin) == {'identity', 'kind', 'location', 'state'}
        assert pin['identity'] == 'grdb.swift' and pin['kind'] == 'remoteSourceControl'
        assert pin['location'] in LOCATIONS
        assert pin['state'] == {'revision': REVISION, 'version': '7.11.1'}
        report.update(status='validated_public_exact_pin', schema_version=value['version'], pins=[pin])
    except (ValueError, KeyError, TypeError, AssertionError):
        report.update(status='rejected', reason='schema or exact public dependency pin mismatch')
    return report
