#!/usr/bin/env python3
"""Export bounded authored full-app audit evidence without hiding audit failures.

Only a camera pair is mandatory: the unchanged stop-on-failure XCTest policy may
prevent the ask phase from running. A partial ask pair always fails evidence checks.
"""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROLES = ('camera-before', 'camera-after', 'ask-before', 'ask-after')
ISSUE_ROLES = tuple(f'{phase}-issue-{index}-{kind}' for phase in ('camera', 'ask') for index in (1, 2) for kind in ('screen', 'metadata'))
MAX_BYTES = 16 * 1024 * 1024


def error_description(error):
    # OSError messages can contain absolute local paths; retain only their kind.
    return type(error).__name__ if isinstance(error, OSError) else str(error)[:250]


def validate_metadata(data, role):
    phase, _, index, _ = role.split('-')
    allowed = {'schema', 'timing', 'phase', 'index', 'auditType', 'compact', 'detailed',
               'elementPresent', 'snapshotStatus', 'element', 'snapshotErrorType', 'metadataTruncated'}
    if not isinstance(data, dict) or set(data) - allowed: raise ValueError('Unknown issue metadata schema')
    if type(data.get('schema')) is not int or data['schema'] != 1 or data.get('phase') != phase or type(data.get('index')) is not int or data['index'] != int(index):
        raise ValueError('Issue metadata identity mismatch')
    if data.get('timing') != 'callback_observation_not_historical_failure_state': raise ValueError('Missing callback timing limitation')
    if type(data.get('auditType')) is not int or not 0 <= data['auditType'] < 2**64: raise ValueError('Invalid audit type')
    if any(not isinstance(data.get(key), str) for key in ('compact', 'detailed') if key in data or data.get('metadataTruncated') is not True):
        raise ValueError('Missing issue descriptions')
    if type(data.get('elementPresent')) is not bool: raise ValueError('Invalid element presence')
    if data.get('snapshotStatus') not in ('not_available', 'captured', 'failed'): raise ValueError('Invalid snapshot status')
    if 'metadataTruncated' in data and type(data['metadataTruncated']) is not bool: raise ValueError('Invalid truncation status')
    if 'snapshotErrorType' in data and not isinstance(data['snapshotErrorType'], str): raise ValueError('Invalid snapshot error type')
    if data['snapshotStatus'] == 'captured':
        if data['elementPresent'] is not True: raise ValueError('Captured snapshot without element')
        if 'element' not in data and data.get('metadataTruncated') is True: return
        element = data.get('element')
        if not isinstance(element, dict) or set(element) != {'identifier', 'label', 'elementType', 'frame', 'enabled'}:
            raise ValueError('Invalid bounded element snapshot')
        if any(not isinstance(element[key], str) for key in ('identifier', 'label', 'frame')) or type(element['enabled']) is not bool:
            raise ValueError('Invalid element snapshot fields')
        if type(element['elementType']) not in (int, str): raise ValueError('Invalid element type')
    elif 'element' in data: raise ValueError('Unexpected element without captured snapshot')


def collect(source: Path, destination: Path, export_error=None) -> dict:
    destination.mkdir(parents=True, exist_ok=False)
    result = {'schema': 1, 'scope': 'synthetic full-app camera/ask accessibility audit',
              'nativeAuditOutcome': 'not_inferred_from_attachments', 'screenshots': [], 'metadata': [], 'errors': []}
    errors = result['errors']
    observed, selected = set(), {}
    total = 0
    if export_error:
        errors.append(export_error[:300])
    else:
        try:
            source = source.resolve()
            manifest = source / 'manifest.json'
            if manifest.stat().st_size > 2 * 1024 * 1024:
                raise ValueError('Export manifest exceeds 2 MiB')
            entries = json.loads(manifest.read_text())
            if not isinstance(entries, list) or not entries:
                raise ValueError('Missing or invalid export entries')
            for entry in entries:
                if not isinstance(entry, dict) or not isinstance(entry.get('attachments'), list):
                    raise ValueError('Unknown export manifest schema')
                for item in entry['attachments']:
                    if not isinstance(item, dict):
                        raise ValueError('Unknown attachment record')
                    name = item.get('suggestedHumanReadableName', '')
                    if not isinstance(name, str):
                        raise ValueError('Invalid attachment name')
                    match = re.fullmatch(r'full-audit-((?:camera|ask)-(?:before|after|issue-[12]-(?:screen|metadata)))(?:_[^/\\\r\n]+)?(?:\.(?:png|json))?', name)
                    if not match:
                        if name.startswith('full-audit-') and len(errors) < 16: errors.append('Unexpected authored attachment name')
                        continue
                    role = match.group(1)
                    if role in observed:
                        if len(errors) < 16: errors.append('Duplicate authored attachment: ' + role)
                        continue
                    observed.add(role)
                    try:
                        metadata = role.endswith('-metadata')
                        extension = '.json' if metadata else '.png'
                        filename = item.get('exportedFileName')
                        if not isinstance(filename, str) or Path(filename).name != filename or not filename.lower().endswith(extension):
                            raise ValueError('Invalid exported attachment filename')
                        path = source / filename
                        if path.is_symlink() or path.resolve().parent != source:
                            raise ValueError('Attachment escapes export directory')
                        size = path.stat().st_size
                        if metadata:
                            if size > 16 * 1024: raise ValueError('Issue metadata exceeds 16 KiB')
                            validate_metadata(json.loads(path.read_text()), role)
                        else:
                            with path.open('rb') as stream:
                                if stream.read(8) != b'\x89PNG\r\n\x1a\n':
                                    raise ValueError('Invalid PNG signature')
                            if total + size > MAX_BYTES:
                                raise ValueError('Authored screenshots exceed 16 MiB total')
                        target = destination / ('full-audit-' + role + extension)
                        shutil.copyfile(path, target)
                        if not metadata: total += size
                        selected[role] = target.name
                    except (OSError, ValueError) as error:
                        if len(errors) < 16: errors.append(role + ': ' + error_description(error))
        except (OSError, ValueError, TypeError) as error:
            if len(errors) < 16: errors.append(error_description(error))
    phases = {}
    for phase in ('camera', 'ask'):
        wanted = {phase + '-before', phase + '-after'}
        seen = observed & wanted
        retained = set(selected) & wanted
        required = phase == 'camera' or any(role.startswith(phase + '-') for role in observed)
        missing = sorted(wanted - retained) if required else []
        phases[phase] = {'status': 'complete' if retained == wanted else ('missing_or_partial' if required else 'not_observed'),
                         'observedRoles': sorted(seen), 'retainedRoles': sorted(retained), 'missingRoles': missing}
    issues = {}
    for phase in ('camera', 'ask'):
        for index in (1, 2):
            prefix = f'{phase}-issue-{index}'
            wanted = {prefix + '-screen', prefix + '-metadata'}
            if observed & wanted:
                missing = sorted(wanted - set(selected))
                issues[prefix] = {'status': 'complete' if not missing else 'missing_or_partial', 'missingRoles': missing}
                if missing and len(errors) < 16: errors.append('Incomplete issue evidence: ' + prefix)
    result.update(phases=phases, issues=issues,
                  screenshots=[selected[role] for role in ROLES + ISSUE_ROLES if role in selected and not role.endswith('-metadata')],
                  metadata=[selected[role] for role in ISSUE_ROLES if role in selected and role.endswith('-metadata')],
                  screenshotBytes=total, evidenceComplete=not errors and all(not phase['missingRoles'] for phase in phases.values()))
    payload = json.dumps(result, indent=2) + '\n'
    if len(payload.encode('utf-8')) > 16 * 1024:
        raise ValueError('Evidence JSON exceeds 16 KiB')
    (destination / 'evidence.json').write_text(payload)
    return result


def main():
    xcresult, root = map(Path, sys.argv[1:])
    root.mkdir(parents=True, exist_ok=False)
    error = None
    if not xcresult.is_dir():
        error = 'Missing native result bundle; no audit phase inferred'
    else:
        try:
            completed = subprocess.run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(xcresult),
                                        '--output-path', str(root / 'export')],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=90)
            if completed.returncode:
                error = 'xcresulttool attachment export failed with exit ' + str(completed.returncode)
        except (OSError, subprocess.TimeoutExpired) as failure:
            error = 'xcresulttool attachment export unavailable or timed out: ' + type(failure).__name__
    status = collect(root / 'export', root / 'artifacts', error)
    print('ACCESSIBILITY_AUDIT_EVIDENCE=' + json.dumps(status))
    return 0 if status['evidenceComplete'] else 1


if __name__ == '__main__':
    sys.exit(main())
