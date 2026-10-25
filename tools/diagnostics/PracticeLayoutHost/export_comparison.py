"""Fail-closed selection of authored screenshots from xcresulttool manifests."""
import json
from pathlib import Path
import re
import shutil

MAX_TOTAL_BYTES = 24 * 1024 * 1024


def export(source: Path, destination: Path, prefix: str) -> list[str]:
    if not re.fullmatch(r'comparison-[ABC]-(?:(?:dynamicType|hitRegion)-[12]|endpoint)', prefix):
        raise ValueError('Unexpected comparison prefix')
    source = source.resolve()
    manifest = source / 'manifest.json'
    if manifest.stat().st_size > 2 * 1024 * 1024:
        raise ValueError('Oversized export manifest')
    entries = json.loads(manifest.read_text())
    if not isinstance(entries, list) or not entries:
        raise ValueError('Missing export entries')
    selected = {}
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get('attachments'), list):
            raise ValueError('Unknown export manifest schema')
        for attachment in entry['attachments']:
            if not isinstance(attachment, dict):
                raise ValueError('Unknown attachment record')
            name = attachment.get('suggestedHumanReadableName', '')
            if not isinstance(name, str):
                raise ValueError('Invalid attachment name')
            role = next((r for r in ('before', 'after') if re.fullmatch(
                re.escape(prefix + '-' + r) + r'(?:_[^/\\\r\n]+)?(?:\.png)?', name)), None)
            if role is None:
                continue
            if role in selected:
                raise ValueError('Duplicate authored screenshot: ' + role)
            filename = attachment.get('exportedFileName')
            if not isinstance(filename, str) or Path(filename).name != filename or not filename.lower().endswith('.png'):
                raise ValueError('Invalid exported PNG filename')
            path = source / filename
            if path.is_symlink() or path.resolve().parent != source:
                raise ValueError('Exported PNG escapes source')
            with path.open('rb') as stream:
                if stream.read(8) != b'\x89PNG\r\n\x1a\n':
                    raise ValueError('Invalid PNG signature')
            selected[role] = path
    if set(selected) != {'before', 'after'}:
        raise ValueError('Missing authored before/after screenshot')
    if sum(p.stat().st_size for p in selected.values()) > 16 * 1024 * 1024:
        raise ValueError('Case screenshots exceed 16 MiB')
    destination.mkdir(parents=True, exist_ok=True)
    existing = list(destination.iterdir())
    if any(not p.is_file() or p.is_symlink() or p.suffix != '.png' for p in existing):
        raise ValueError('Unexpected existing artifact')
    if len(existing) + 2 > 30 or sum(p.stat().st_size for p in existing + list(selected.values())) > MAX_TOTAL_BYTES:
        raise ValueError('Screenshot artifact exceeds 30 PNG / 24 MiB limit')
    targets = [destination / (prefix + '-' + role + '.png') for role in ('before', 'after')]
    if any(p.exists() for p in targets):
        raise ValueError('Refusing stale screenshot output')
    for role, target in zip(('before', 'after'), targets):
        shutil.copyfile(selected[role], target)
    return [p.name for p in targets]
