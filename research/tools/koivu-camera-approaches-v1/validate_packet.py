"""Read-only packet/decompressed-byte validator; no scientific imports or array decode."""
from pathlib import Path
import argparse,gzip,hashlib,json,re
ROOT=Path(__file__).resolve().parent
def sha(p):
 h=hashlib.sha256()
 with p.open('rb')as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--original-root',type=Path);a=p.parse_args();m=ROOT/'MANIFEST.json';d=json.loads(m.read_text());rows=d['files'];expected={r['path']for r in rows};actual={str(p.relative_to(ROOT))for p in ROOT.rglob('*')if p.is_file()}
 assert actual-{'MANIFEST.json','VALIDATION.json'}==expected and len(expected)==len(rows)
 for r in rows:
  f=ROOT/r['path'];assert not f.is_symlink()and f.stat().st_size==r['bytes']and sha(f)==r['sha256']
  if f.suffix in ('.md','.json','.jsonl','.log','.txt','.py','.cpp','.h','.sh'):
   b=f.read_bytes();assert (b'/' + b'workspace/')not in b and (b'/opt/' + b'codex/')not in b
   for pat in [rb'gh[pousr]_[A-Za-z0-9]{20,}',rb'github_pat_[A-Za-z0-9_]{20,}',rb'AKIA[A-Z0-9]{16}',rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',rb'https?://[^\s"<>]*(?:X-Amz-Signature=|[?&]sig=|[?&]access_token=)']:assert not re.search(pat,b),r['path']
  if f.suffix=='.json':json.loads(f.read_text())
 comp=json.loads((ROOT/'COMPRESSED_RESULTS.json').read_text());decompressed={}
 for r in comp['assets']:
  f=ROOT/r['storedPath'];assert sha(f)==r['gzipSHA256'];h=hashlib.sha256();n=0
  with gzip.open(f,'rb')as g:
   while b:=g.read(1048576):n+=len(b);assert n<=r['originalBytes'];h.update(b)
  assert n==r['originalBytes']and h.hexdigest()==r['originalSHA256'];decompressed[r['storedPath']]=h.hexdigest()
 mapping=json.loads((ROOT/'NORMALIZATION_MAP.json').read_text());originals=0
 by_orig={}
 for r in mapping['files']:
  public=ROOT/r['publicPath'];assert sha(public)==r['publicSHA256'];by_orig[r['originalPath'].removeprefix('$WORKSPACE/')]=r
  if r['sourceOrLicenseUnchanged']:assert r['byteIdentical']and r['originalSHA256']==r['publicSHA256']
  if r['publicPath']in decompressed:assert decompressed[r['publicPath']]==r['originalSHA256']
  if a.original_root:
   original=a.original_root/r['originalPath'].removeprefix('$WORKSPACE/');assert original.stat().st_size==r['originalBytes']and sha(original)==r['originalSHA256'];originals+=1
   if not r['byteIdentical']and not r['publicPath'].endswith('.gz'):assert re.findall(rb'\b[0-9a-f]{64}\b',original.read_bytes())==re.findall(rb'\b[0-9a-f]{64}\b',public.read_bytes())
 identities=json.loads((ROOT/'SOURCE_IDENTITY_RECHECK.json').read_text())
 for r in identities['associations']:assert by_orig[r['sourceOrEvidencePath']]['originalSHA256']==r['expectedSHA256']
 total=sum(r['bytes']for r in rows);assert total==d['payloadBytes']and total<32*1024**2
 print(json.dumps({'success':True,'payloadFiles':len(rows),'payloadBytes':total,'manifestSHA256':sha(m),'copiedOriginalsVerifiedUnchanged':originals,'historicalSourceEvidenceAssociations':len(identities['associations']),'sourceCutsByteIdentical':True,'compressedOriginalResultsVerified':len(decompressed),'compressedOriginalBytes':sum(r['originalBytes']for r in comp['assets']),'scientificExecution':False,'traceArraysDecoded':False,'geometryLoaded':False,'credentialPatternScan':'no matching high-specificity pattern; not a comprehensive audit'},indent=2))
if __name__=='__main__':main()
