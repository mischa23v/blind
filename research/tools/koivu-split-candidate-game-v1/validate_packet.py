#!/usr/bin/env python3
"""Packet byte/JSON checks only; no native imports, numerical tests or array decoding."""
from pathlib import Path
import argparse,hashlib,json,re
ROOT=Path(__file__).resolve().parent

def digest(p):
 h=hashlib.sha256()
 with p.open('rb')as f:
  for b in iter(lambda:f.read(1024**2),b''):h.update(b)
 return h.hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--original-root',type=Path);a=p.parse_args();m=ROOT/'MANIFEST.json';d=json.loads(m.read_text());rows=d['files'];expected={r['path']for r in rows}
 actual={str(p.relative_to(ROOT))for p in ROOT.rglob('*')if p.is_file()}
 assert actual-{'MANIFEST.json','VALIDATION.json'}==expected and len(expected)==len(rows)
 total=0;documents=0
 for r in rows:
  p=ROOT/r['path'];assert not p.is_symlink()and p.stat().st_size==r['bytes']and digest(p)==r['sha256'];total+=r['bytes']
  assert 'ground-skip-v4'not in r['path']and '__pycache__'not in r['path']
  if p.suffix in ('.json','.jsonl','.md','.txt','.log','.py','.sh','.cpp','.h'):
   b=p.read_bytes();assert (b'/' + b'workspace/')not in b and (b'/opt/' + b'codex/')not in b
   for pattern in [rb'gh[pousr]_[A-Za-z0-9]{20,}',rb'github_pat_[A-Za-z0-9_]{20,}',rb'AKIA[A-Z0-9]{16}',rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',rb'https?://[^\s"<>]*(?:X-Amz-Signature=|[?&]sig=|[?&]access_token=)']:
    assert not re.search(pattern,b),r['path']
  if p.suffix=='.json':json.loads(p.read_text());documents+=1
 assert total==d['payloadBytes']and total<=32*1024**2
 mapping=json.loads((ROOT/'NORMALIZATION_MAP.json').read_text());originals=0;unchanged_sources=0
 for r in mapping['files']:
  public=ROOT/r['publicPath'];assert digest(public)==r['publicSHA256']
  if r['runnableSourceOrLicenseUnchanged']:assert r['byteIdentical']and r['originalSHA256']==r['publicSHA256'];unchanged_sources+=1
  if a.original_root:
   source=a.original_root/r['sourcePath'].removeprefix('$WORKSPACE/');assert source.stat().st_size==r['originalBytes']and digest(source)==r['originalSHA256'];originals+=1
   if not r['byteIdentical']:assert re.findall(rb'\b[0-9a-f]{64}\b',source.read_bytes())==re.findall(rb'\b[0-9a-f]{64}\b',public.read_bytes())
 by_public={r['publicPath']:r for r in mapping['files']};history=json.loads((ROOT/'HISTORICAL_SOURCE_MAP.json').read_text())
 for r in history['sourcePinAssociations']:assert by_public[r['preservedSourcePath']]['originalSHA256']==r['expectedOriginalSHA256']
 result=ROOT/'blind-split-candidate-game-03/ground-follow-v3/run-01/result/RESULT.json';assert digest(result)=='48521e87fcc6fc670dde77d6c8cf70b199a231f1015b20bec03e18334f4647af'
 print(json.dumps({'success':True,'payloadFiles':len(rows),'payloadBytes':total,'manifestSHA256':digest(m),'historicalOriginalsRehashed':originals,'unchangedSourcesAndLicenses':unchanged_sources,'historicalSourceAssociations':len(history['sourcePinAssociations']),'historicalAliases':sum(r['historicalPathDiffers']for r in history['sourcePinAssociations']),'publicCopiesChanged':sum(not r['byteIdentical']for r in mapping['files']),'JSONDocumentsParsed':documents,'scientificExecution':False,'fixtureExecution':False,'arraysDecoded':False,'geometryLoaded':False,'credentialPatternScan':'no high-specificity pattern match; not a comprehensive secret audit'},indent=2))
if __name__=='__main__':main()
