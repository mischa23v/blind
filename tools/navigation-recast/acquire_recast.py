from pathlib import Path
import hashlib,json,urllib.request,concurrent.futures
PIN='9f4ce64458dfae86e1239c525ddc219c4e9e06f1'
ROOT=Path(__file__).resolve().parent
DEST=ROOT/'upstream'
CAP=20*1024*1024
PREFIX='https://api.github.com/repos/recastnavigation/recastnavigation'
def get(url,limit=CAP):
 req=urllib.request.Request(url,headers={'User-Agent':'BlindAssist-pinned-source-review','Accept':'application/vnd.github+json'})
 with urllib.request.urlopen(req,timeout=30) as r:
  b=r.read(limit+1)
  if len(b)>limit: raise RuntimeError('acquisition cap exceeded')
  return b
commit_bytes=get(PREFIX+'/git/commits/'+PIN)
commit=json.loads(commit_bytes)
assert commit['sha']==PIN
raw_tree=get(PREFIX+'/git/trees/'+commit['tree']['sha']+'?recursive=1')
tree=json.loads(raw_tree)
assert not tree.get('truncated')
wanted=[x for x in tree['tree'] if x['type']=='blob' and (x['path']=='License.txt' or any(x['path'].startswith(m+'/') for m in ['Recast','Detour','DetourCrowd']) and x['path'].endswith(('.h','.cpp')))]
expected=sum(x['size'] for x in wanted)+len(commit_bytes)+len(raw_tree)
if expected>CAP: raise RuntimeError(f'expected {expected}>cap')
DEST.mkdir(exist_ok=True)
def one(x):
 b=get('https://raw.githubusercontent.com/recastnavigation/recastnavigation/'+PIN+'/'+x['path'],limit=x['size'])
 assert len(b)==x['size']
 blob=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
 assert blob==x['sha'],x['path']
 p=DEST/x['path']; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(b)
 return {'path':x['path'],'bytes':len(b),'git_blob_sha1':blob,'sha256':hashlib.sha256(b).hexdigest()}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex: entries=list(ex.map(one,wanted))
manifest={'repository':'https://github.com/recastnavigation/recastnavigation','revision':PIN,'tree':commit['tree']['sha'],'license':'Zlib','sourceFiles':len(entries),'sourceBytes':sum(x['bytes'] for x in entries),'totalAcquisitionBytes':expected,'sourceCapBytes':CAP,'workdirCapBytes':200*1024*1024,'files':entries,'buildStatus':'not yet built'}
(ROOT/'UPSTREAM_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({k:v for k,v in manifest.items() if k!='files'},indent=2))
