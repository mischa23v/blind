from pathlib import Path
import hashlib,json,gzip
R=Path(__file__).resolve().parent
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 m=json.loads((R/'MANIFEST.json').read_text());expected={x['path']for x in m['files']}
 actual={p.relative_to(R).as_posix()for p in R.rglob('*')if p.is_file()}-{'MANIFEST.json','VALIDATION.json'}
 assert actual==expected
 for x in m['files']:
  p=R/x['path'];assert not p.is_symlink();b=p.read_bytes();assert len(b)==x['bytes']and sha(b)==x['sha256']
  assert hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==x['gitBlobSHA1']
  if p.suffix in ['.py','.md','.json','.jsonl','.log','.h','.cpp','.c','.hpp']:
   s=b.decode();assert p.name=='validate_packet.py' or not any(t in s for t in ['/workspace/','/home/agent/','/opt/codex/','ghp_','github_pat_','sk-proj-','X-Amz-Signature','?sig=','&sig='])
   if p.suffix=='.json':json.loads(s)
   if p.suffix=='.jsonl':
    for line in s.splitlines():json.loads(line)
 for x in json.loads((R/'NORMALIZATION_MAP.json').read_text())['files']:
  b=(R/x['publicPath']).read_bytes();assert sha(b)==x['publicSHA256']
  if x['byteIdentical']:assert sha(b)==x['originalSHA256']
 for x in json.loads((R/'COMPRESSED_RESULTS.json').read_text())['assets']:assert sha(gzip.decompress((R/x['storedPath']).read_bytes()))==x['originalSHA256']
 print(json.dumps({'success':True,'payloadFiles':len(expected),'payloadBytes':sum(x['bytes']for x in m['files']),'scientificExecution':False,'geometryLoaded':False}))
if __name__=='__main__':main()
