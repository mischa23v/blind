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
MAX_BYTES = 8 * 1024 * 1024


def collect(source: Path, destination: Path, export_error=None) -> dict:
    destination.mkdir(parents=True, exist_ok=False)
    result = {'schema': 1, 'scope': 'synthetic full-app camera/ask accessibility audit',
              'nativeAuditOutcome': 'not_inferred_from_attachments', 'screenshots': [], 'errors': []}
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
                    match = re.fullmatch(r'full-audit-(camera-before|camera-after|ask-before|ask-after)(?:_[^/\\\r\n]+)?(?:\.png)?', name)
                    if not match:
                        continue
                    role = match.group(1)
                    if role in observed:
                        if len(errors) < 16: errors.append('Duplicate authored screenshot: ' + role)
                        continue
                    observed.add(role)
                    try:
                        filename = item.get('exportedFileName')
                        if not isinstance(filename, str) or Path(filename).name != filename or not filename.lower().endswith('.png'):
                            raise ValueError('Invalid exported PNG filename')
                        path = source / filename
                        if path.is_symlink() or path.resolve().parent != source:
                            raise ValueError('PNG escapes export directory')
                        with path.open('rb') as stream:
                            if stream.read(8) != b'\x89PNG\r\n\x1a\n':
                                raise ValueError('Invalid PNG signature')
                        size = path.stat().st_size
                        if total + size > MAX_BYTES:
                            raise ValueError('Authored screenshots exceed 8 MiB total')
                        target = destination / ('full-audit-' + role + '.png')
                        shutil.copyfile(path, target)
                        total += size
                        selected[role] = target.name
                    except (OSError, ValueError) as error:
                        if len(errors) < 16: errors.append(role + ': ' + str(error)[:250])
        except (OSError, ValueError, TypeError) as error:
            if len(errors) < 16: errors.append(str(error)[:300])
    phases = {}
    for phase in ('camera', 'ask'):
        wanted = {phase + '-before', phase + '-after'}
        seen = observed & wanted
        retained = set(selected) & wanted
        required = phase == 'camera' or bool(seen)
        missing = sorted(wanted - retained) if required else []
        phases[phase] = {'status': 'complete' if retained == wanted else ('missing_or_partial' if required else 'not_observed'),
                         'observedRoles': sorted(seen), 'retainedRoles': sorted(retained), 'missingRoles': missing}
    result.update(phases=phases, screenshots=[selected[role] for role in ROLES if role in selected],
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
        error = 'Missing native ui-diagnostic.xcresult; no audit phase inferred'
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
