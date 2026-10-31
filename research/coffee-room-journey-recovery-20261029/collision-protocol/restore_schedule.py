#!/usr/bin/env python3
"""Restore only the exact pre-frozen authored schedule, no native imports."""
import gzip,hashlib,json,pathlib
ROOT=pathlib.Path(__file__).resolve().parent
meta=json.loads((ROOT/'SCHEDULE_STORAGE.json').read_text());compressed=(ROOT/meta['compressedName']).read_bytes()
if len(compressed)!=meta['compressedBytes'] or hashlib.sha256(compressed).hexdigest()!=meta['compressedSHA256']:raise RuntimeError('compressed input mismatch')
data=gzip.decompress(compressed)
if len(data)!=meta['originalBytes'] or hashlib.sha256(data).hexdigest()!=meta['originalSHA256']:raise RuntimeError('restored input mismatch')
p=ROOT/meta['originalName']
if p.exists():
 if p.read_bytes()!=data:raise RuntimeError('existing schedule differs; will not overwrite')
else:
 with p.open('xb') as f:f.write(data)
print('Exact frozen schedule available; no native code imported or run.')
