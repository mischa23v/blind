#!/usr/bin/env python3
"""Read-only packet checksum/syntax/ordered-parts validation; no scientific imports."""
from pathlib import Path
import argparse,ast,hashlib,json,re,stat
ROOT=Path(__file__).resolve().parent

def digest(p):
 h=hashlib.sha256()
 with p.open('rb')as f:
  for b in iter(lambda:f.read(1024**2),b''):h.update(b)
 return h.hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--original-root',type=Path);a=p.parse_args()
 manifest=ROOT/'MANIFEST.json';doc=json.loads(manifest.read_text());rows=doc['files'];expected={r['path']for r in rows}
 actual={str(p.relative_to(ROOT))for p in ROOT.rglob('*')if p.is_file()}
 assert actual-{'MANIFEST.json','VALIDATION.json'}==expected and len(expected)==len(rows)
 syntax=0;jsons=0;total=0
 for r in rows:
  p=ROOT/r['path'];assert not p.is_symlink() and p.stat().st_size==r['bytes'] and digest(p)==r['sha256'];total+=r['bytes'];assert r['bytes']<=12*1024**2
  if p.suffix=='.py':ast.parse(p.read_text(),filename=r['path']);syntax+=1
  if p.suffix in ('.json','.md','.jsonl','.txt','.py','.log','.ipynb') or p.name=='LICENSE':
   b=p.read_bytes();assert (b'/' + b'workspace/') not in b and (b'/opt/' + b'codex/') not in b
   for pattern in [rb'gh[pousr]_[A-Za-z0-9]{20,}',rb'github_pat_[A-Za-z0-9_]{20,}',rb'AKIA[A-Z0-9]{16}',rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',rb'https?://[^\s"<>]*(?:X-Amz-Signature=|[?&]sig=|[?&]access_token=)']:
    assert not re.search(pattern,b),r['path']
  if p.suffix in ('.json','.ipynb') and r['path']!='blind-open3d-author-baseline-10/koivu/RESULT.json':json.loads(p.read_text());jsons+=1
 assert total==doc['payloadBytes'] and total<=100*1024**2
 parts=json.loads((ROOT/'PARTS_MANIFEST.json').read_text());part_files=0
 for key,row in parts['assets'].items():
  whole=hashlib.sha256();n=0
  for i,r in enumerate(row['parts']):
   assert r['index']==i and r['bytes']<=8*1024**2
   p=ROOT/r['path'];assert p.stat().st_size==r['bytes'] and digest(p)==r['sha256'];part_files+=1
   with p.open('rb')as f:
    for b in iter(lambda:f.read(1024**2),b''):whole.update(b);n+=len(b)
  assert n==row['bytes'] and whole.hexdigest()==row['sha256']
 norm=json.loads((ROOT/'NORMALIZATION_MAP.json').read_text());originals=0
 for r in norm['files']:
  pub=ROOT/r['publicPath'];assert digest(pub)==r['publicSHA256']
  if r['runnableSourceUnchanged']:assert r['byteIdentical'] and r['originalSHA256']==r['publicSHA256']
  if a.original_root:
   original=a.original_root/r['sourcePath'].removeprefix('$WORKSPACE/');assert digest(original)==r['originalSHA256'] and original.stat().st_size==r['originalBytes'];originals+=1
   if not r['byteIdentical']:assert re.findall(rb'\b[0-9a-f]{64}\b',original.read_bytes())==re.findall(rb'\b[0-9a-f]{64}\b',pub.read_bytes())
 print(json.dumps({'success':True,'payloadFiles':len(rows),'payloadBytes':total,'manifestSHA256':digest(manifest),'pythonSyntaxFiles':syntax,'JSONDocumentsParsed':jsons,'byteExactSplitAssets':len(parts['assets']),'partFiles':part_files,'historicalOriginalsRehashed':originals,'changedPublicCopies':sum(not r['byteIdentical']for r in norm['files']),'scientificExecution':False,'rawImageDecode':False,'geometryLoaded':False,'credentialPatternScan':'no matching high-specificity pattern; not a comprehensive secret audit','normalizationMeaning':'Historical hashes retained; public normalized receipts are distinct bytes'},indent=2))
if __name__=='__main__':main()
