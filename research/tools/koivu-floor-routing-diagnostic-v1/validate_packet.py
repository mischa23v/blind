from pathlib import Path
import argparse,hashlib,json,re
ROOT=Path(__file__).resolve().parent
def sha(p):
 h=hashlib.sha256()
 with p.open('rb')as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def main():
 a=argparse.ArgumentParser();a.add_argument('--original-root',type=Path);args=a.parse_args();m=ROOT/'MANIFEST.json';d=json.loads(m.read_text());rows=d['files'];expected={r['path']for r in rows};actual={str(p.relative_to(ROOT))for p in ROOT.rglob('*')if p.is_file()}
 assert actual-{'MANIFEST.json','VALIDATION.json'}==expected and len(rows)==len(expected)
 for r in rows:
  p=ROOT/r['path'];assert not p.is_symlink()and p.stat().st_size==r['bytes']and sha(p)==r['sha256'];assert not any(x in r['path']for x in ['camera-approach-executor','two-approach-selection','ground-obb-v6','ground-vector-v5','ground-skip-v4','__pycache__'])
  if p.suffix in ('.json','.jsonl','.md','.log','.txt','.py','.cpp','.h','.sh'):
   b=p.read_bytes();assert (b'/' + b'workspace/')not in b and (b'/opt/' + b'codex/')not in b
   for pat in [rb'gh[pousr]_[A-Za-z0-9]{20,}',rb'github_pat_[A-Za-z0-9_]{20,}',rb'AKIA[A-Z0-9]{16}',rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',rb'https?://[^\s"<>]*(?:X-Amz-Signature=|[?&]sig=|[?&]access_token=)']:assert not re.search(pat,b),r['path']
  if p.suffix=='.json':json.loads(p.read_text())
 mapping=json.loads((ROOT/'NORMALIZATION_MAP.json').read_text());count=0
 for r in mapping['files']:
  p=ROOT/r['publicPath'];assert sha(p)==r['publicSHA256']
  if r['sourceOrLicenseUnchanged']:assert r['byteIdentical']and r['originalSHA256']==r['publicSHA256']
  if args.original_root:
   src=args.original_root/r['originalPath'].removeprefix('$WORKSPACE/');assert src.stat().st_size==r['originalBytes']and sha(src)==r['originalSHA256'];count+=1
   if not r['byteIdentical']:assert re.findall(rb'\b[0-9a-f]{64}\b',src.read_bytes())==re.findall(rb'\b[0-9a-f]{64}\b',p.read_bytes())
 total=sum(r['bytes']for r in rows);assert total==d['payloadBytes']and total<24*1024**2
 print(json.dumps({'success':True,'payloadFiles':len(rows),'payloadBytes':total,'manifestSHA256':sha(m),'originalsVerifiedUnchanged':count,'normalizedCopies':sum(not r['byteIdentical']for r in mapping['files']),'sourceCutsByteIdentical':True,'scientificExecution':False,'arraysDecoded':False,'geometryLoaded':False,'cameraScaleOriginalExecutablePreserved':False,'privacyReview':'Numeric abstract profiles and generated maps only; no raw photos, screenshots or private participant attributes included. High-specificity credential patterns absent, not a comprehensive audit.'},indent=2))
if __name__=='__main__':main()
