from pathlib import Path
import hashlib,json
R=Path(__file__).resolve().parent
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 m=json.loads((R/'MANIFEST.json').read_text()); expected={r['path'] for r in m['files']}
 actual={p.relative_to(R).as_posix() for p in R.rglob('*') if p.is_file()}-{'MANIFEST.json','VALIDATION.json'}
 assert actual==expected
 for r in m['files']:
  p=R/r['path']; assert not p.is_symlink(); b=p.read_bytes(); assert len(b)==r['bytes'] and sha(b)==r['sha256']
 n=json.loads((R/'NORMALIZATION_MAP.json').read_text())
 for r in n['files']:
  b=(R/r['publicPath']).read_bytes(); assert sha(b)==r['publicSHA256']
  if r['byteIdentical']: assert sha(b)==r['originalSHA256']
 e=json.loads((R/'EXTERNAL_SOURCE_VERIFICATION.json').read_text())
 for r in e['files']:
  b=(R/r['path']).read_bytes(); assert len(b)==r['bytes'] and sha(b)==r['sha256']
  assert hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==r['gitBlobSHA1']
 print(json.dumps({'success':True,'payloadFiles':len(expected),'payloadBytes':sum(r['bytes'] for r in m['files']),'externalGitBlobsVerified':len(e['files']),'arrayDecoding':False,'scientificExecution':False}))
if __name__=='__main__':main()
