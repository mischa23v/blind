#!/usr/bin/env python3
"""Bounded guard for Apple's plutil JSON view of the committed default project.

The one exception is the exact oracle flag in exclusively owned configurations
of the root project's real hosted unit-test target. No text is globally stripped.
The caller must obtain JSON using plutil from the same raw project passed here.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

INPUT_LIMIT = 2 * 1024 * 1024
NODE_LIMIT = 40000
DEPTH_LIMIT = 64
FORBIDDEN = re.compile(r'BLIND_[A-Z_]+|opencv2|\.mlmodelc|\.mlpackage')
FLAG = 'BLIND_COLLISION_ORACLE_TESTS'
FLAG_VALUE = '$(inherited) -D ' + FLAG
TARGET_TYPES = {
    'BlindAssist': 'com.apple.product-type.application',
    'BlindAssistTests': 'com.apple.product-type.bundle.unit-test',
    'BlindAssistUITests': 'com.apple.product-type.bundle.ui-testing',
}


def require(ok, code):
    if not ok:
        raise ValueError(code)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'duplicate-json-key')
        result[key] = value
    return result


def walk(value, path=()):
    pending = [(value, path)]
    seen = 0
    while pending:
        item, location = pending.pop()
        seen += 1
        require(seen <= NODE_LIMIT and len(location) <= DEPTH_LIMIT, 'json-structure-budget')
        yield location, item
        if isinstance(item, dict):
            for key, child in item.items():
                require(isinstance(key, str), 'non-string-json-key')
                require(FORBIDDEN.search(key) is None, 'forbidden-project-key')
                pending.append((child, location + (key,)))
        elif isinstance(item, list):
            pending.extend((child, location + (index,)) for index, child in enumerate(item))
        else:
            require(item is None or type(item) in (str, int, bool), 'unexpected-json-value')


def validate_project(project, raw):
    require(isinstance(raw, str) and len(raw.encode()) <= INPUT_LIMIT, 'raw-project-budget')
    require(isinstance(project, dict), 'project-object-required')
    # Validate the entire bounded tree, not just the settings being excepted.
    nodes = list(walk(project))
    objects = project.get('objects')
    require(isinstance(objects, dict) and 0 < len(objects) <= 4096, 'object-table-required')
    require(all(isinstance(k, str) and isinstance(v, dict) for k, v in objects.items()), 'invalid-object-table')
    root_id = project.get('rootObject')
    require(isinstance(root_id, str) and root_id in objects, 'missing-root-project')
    root = objects[root_id]
    require(root.get('isa') == 'PBXProject', 'root-not-project')
    require([key for key, obj in objects.items() if obj.get('isa') == 'PBXProject'] == [root_id], 'unexpected-project-object')
    target_ids = root.get('targets')
    require(isinstance(target_ids, list) and len(target_ids) == 3 and
            all(isinstance(x, str) for x in target_ids) and len(set(target_ids)) == 3, 'exact-root-targets-required')
    native_ids = {key for key, obj in objects.items() if obj.get('isa') == 'PBXNativeTarget'}
    require(set(target_ids) == native_ids, 'orphan-or-missing-native-target')
    targets = {}
    for target_id in target_ids:
        target = objects[target_id]
        name = target.get('name')
        require(name in TARGET_TYPES and name not in targets, 'unexpected-or-duplicate-target-name')
        require(target.get('productName') == name and target.get('productType') == TARGET_TYPES[name], 'target-product-identity')
        targets[name] = target_id
    unit_id = targets['BlindAssistTests']
    unit = objects[unit_id]
    owner_list = unit.get('buildConfigurationList')
    require(isinstance(owner_list, str) and owner_list in objects, 'missing-unit-configuration-list')
    configuration_list = objects[owner_list]
    require(configuration_list.get('isa') == 'XCConfigurationList', 'invalid-unit-configuration-list')
    owners = [key for key, obj in objects.items() if obj.get('buildConfigurationList') == owner_list]
    require(owners == [unit_id], 'shared-unit-configuration-list')
    config_ids = configuration_list.get('buildConfigurations')
    require(isinstance(config_ids, list) and len(config_ids) == 2 and
            all(isinstance(x, str) for x in config_ids) and len(set(config_ids)) == 2, 'exact-unit-configurations-required')
    attributes = root.get('attributes', {}).get('TargetAttributes', {})
    require(isinstance(attributes, dict) and attributes.get(unit_id, {}).get('TestTargetID') == targets['BlindAssist'], 'unit-host-target-association')
    approved = set()
    names = set()
    for config_id in config_ids:
        config = objects.get(config_id)
        require(isinstance(config, dict) and config.get('isa') == 'XCBuildConfiguration', 'invalid-unit-configuration')
        name = config.get('name')
        require(name in {'Debug', 'Release'} and name not in names, 'exact-unit-configuration-names')
        names.add(name)
        # Even orphan configuration lists must not share the privileged objects.
        references = [key for key, obj in objects.items()
                      if isinstance(obj.get('buildConfigurations'), list) and config_id in obj['buildConfigurations']]
        require(references == [owner_list], 'shared-unit-configuration')
        require('baseConfigurationReference' not in config, 'external-unit-configuration-not-reviewed')
        settings = config.get('buildSettings')
        require(isinstance(settings, dict), 'unit-build-settings-required')
        require(settings.get('OTHER_SWIFT_FLAGS') == FLAG_VALUE, 'exact-oracle-test-flag-required')
        require(settings.get('TEST_HOST') == '$(BUILT_PRODUCTS_DIR)/BlindAssist.app/BlindAssist' and
                settings.get('BUNDLE_LOADER') == '$(TEST_HOST)', 'unit-host-settings')
        approved.add(('objects', config_id, 'buildSettings', 'OTHER_SWIFT_FLAGS'))
    require(names == {'Debug', 'Release'}, 'exact-unit-configuration-names')
    for location, value in nodes:
        if location and isinstance(location[-1], str) and location[-1].startswith('OTHER_SWIFT_FLAGS'):
            require(location in approved and value == FLAG_VALUE, 'unreviewed-swift-flags')
        if isinstance(value, str) and FORBIDDEN.search(value):
            require(location in approved and value == FLAG_VALUE, 'forbidden-backend-model-or-flag')
    # Keep the former whole-file prohibition, including comments. Only the two
    # tokens proven above are admitted; backend/model strings never are.
    require(FORBIDDEN.findall(raw) == [FLAG, FLAG], 'raw-project-optional-token-mismatch')
    return {'schema': 1, 'status': 'passed', 'oracle_flag_target': 'BlindAssistTests',
            'oracle_flag_configurations': ['Debug', 'Release'], 'oracle_flag_occurrences': 2,
            'optional_backend_or_model_entries': 0, 'physical_authority': False}


def read_bounded(path):
    require(path.is_file() and not path.is_symlink(), 'regular-project-file-required')
    with path.open('rb') as stream:
        raw = stream.read(INPUT_LIMIT + 1)
    require(len(raw) <= INPUT_LIMIT, 'project-input-budget')
    return raw


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('raw_project', type=Path)
    parser.add_argument('plutil_json', type=Path)
    args = parser.parse_args(argv)
    try:
        raw = read_bounded(args.raw_project)
        converted = read_bounded(args.plutil_json)
        project = json.loads(converted, object_pairs_hook=unique_object)
        receipt = validate_project(project, raw.decode('utf-8'))
        receipt.update(raw_project_sha256=hashlib.sha256(raw).hexdigest(),
                       plutil_json_sha256=hashlib.sha256(converted).hexdigest())
    except (OSError, ValueError, TypeError, KeyError, AttributeError, RecursionError) as error:
        # Do not print project strings, settings, or arbitrary exception payloads.
        print('DEFAULT_PROJECT_GUARD=' + json.dumps({'schema': 1, 'status': 'refused',
              'error_type': type(error).__name__, 'physical_authority': False}, sort_keys=True))
        return 1
    print('DEFAULT_PROJECT_GUARD=' + json.dumps(receipt, sort_keys=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
