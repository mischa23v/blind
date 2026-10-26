from pathlib import Path
import hashlib,json
R=Path(__file__).resolve().parent
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 m=json.loads((R/'MANIFEST.json').read_text());expected={r['path'] for r in m['files']}
 actual={p.relative_to(R).as_posix() for p in R.rglob('*') if p.is_file()}-{'MANIFEST.json','VALIDATION.json'}
 assert actual==expected
 for r in m['files']:
  p=R/r['path'];assert not p.is_symlink();b=p.read_bytes();assert len(b)==r['bytes'] and sha(b)==r['sha256']
 for r in json.loads((R/'NORMALIZATION_MAP.json').read_text())['files']:
  b=(R/r['publicPath']).read_bytes();assert sha(b)==r['publicSHA256']
  if r['byteIdentical']:assert sha(b)==r['originalSHA256']
 print(json.dumps({'success':True,'payloadFiles':len(expected),'payloadBytes':sum(r['bytes'] for r in m['files']),'scientificExecution':False,'geometryLoaded':False}))
if __name__=='__main__':main()
