#!/usr/bin/env python3
"""Select only our seven Practice/Ask screenshots from the two size probes.

Manifest keys follow xcresulttool export attachments, also consumed by Chromium:
https://chromium.googlesource.com/chromium/src/+/HEAD/ios/build/bots/scripts/xcode_log_parser.py
Unknown/missing schema and absent/duplicate screenshots are explicit failures.
"""
import json
from pathlib import Path
import re
import shutil
import sys


def export(source: Path, destination: Path, size: str) -> None:
    if size not in ('large', 'accessibility-extra-extra-extra-large'):
        raise ValueError('Unexpected size')
    source = source.resolve()
    manifest = source / 'manifest.json'
    if manifest.stat().st_size > 1024 * 1024:
        raise ValueError('Oversized manifest')
    entries = json.loads(manifest.read_text())
    if not isinstance(entries, list) or not entries:
        raise ValueError('Missing test attachment entries')
    expected = ('button', 'header', 'footer', 'footer-end', 'ask-action', 'ask-reason', 'ask-reason-end')
    selected = {}
    prefix = 'practice-layout-' + size + '-'
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get('attachments'), list):
            raise ValueError('Unexpected attachment manifest schema')
        for item in entry['attachments']:
            if not isinstance(item, dict):
                raise ValueError('Unexpected attachment record')
            name = item.get('suggestedHumanReadableName', '')
            if not isinstance(name, str):
                raise ValueError('Unexpected attachment name')
            match = re.match(re.escape(prefix) + r'(ask-reason-end|ask-action|ask-reason|footer-end|button|header|footer)(?=[_. -]|$)', name)
            if not match:
                continue
            role = match.group(1)
            if role in selected:
                raise ValueError('Duplicate authored role screenshot: ' + role)
            exported = item.get('exportedFileName')
            if not isinstance(exported, str) or Path(exported).name != exported or not exported.lower().endswith('.png'):
                raise ValueError('Authored screenshot is not a flat PNG export')
            path = source / exported
            if path.is_symlink() or path.resolve().parent != source:
                raise ValueError('Screenshot path escapes export directory')
            with path.open('rb') as stream:
                if stream.read(8) != b'\x89PNG\r\n\x1a\n':
                    raise ValueError('Invalid PNG signature')
            selected[role] = path
    if set(selected) != set(expected):
        raise ValueError('Missing authored screenshots: ' + ','.join(sorted(set(expected) - set(selected))))
    if sum(p.stat().st_size for p in selected.values()) > 32 * 1024 * 1024:
        raise ValueError('Authored screenshots exceed 32 MiB bound')
    destination.mkdir(parents=True, exist_ok=True)
    for role in expected:
        target = destination / f'{size}-{role}.png'
        if target.exists():
            raise ValueError('Refusing stale/duplicate output: ' + str(target))
    for role in expected:
        shutil.copyfile(selected[role], destination / f'{size}-{role}.png')
    print(f'PRACTICE_LAYOUT exported exactly7 authored PNG screenshots for {size}')


if __name__ == '__main__':
    export(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
