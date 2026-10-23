#!/usr/bin/env python3
"""Offline fixture integrity only. Does not run the app, any model, or sensors."""
import hashlib,json,pathlib,sys
root=pathlib.Path(__file__).resolve().parent
errors=[];json_count=0;frozen_count=0
for f in root.rglob('*.json'):
 try: obj=json.loads(f.read_text());json_count+=1
 except Exception as e: errors.append(f'{f.relative_to(root)}: {e}');continue
 if f.name.startswith('freeze_manifest'):
  for name,digest in obj.get('files',{}).items():
   target=f.parent/name
   if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest()!=digest:errors.append(f'Frozen hash mismatch: {target.relative_to(root)}')
   frozen_count+=1
manifest=root/'ARTIFACT_MANIFEST.json'
if manifest.exists():
 for name,digest in json.loads(manifest.read_text())['files'].items():
  target=root/name
  if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest()!=digest:errors.append(f'Package hash mismatch: {name}')
print(json.dumps({'integrity_pass':not errors,'json_files_read':json_count,'frozen_files_checked':frozen_count,'errors':errors,'behavioral_tests_run':0,'native_tests_run':0},indent=2))
sys.exit(bool(errors))
