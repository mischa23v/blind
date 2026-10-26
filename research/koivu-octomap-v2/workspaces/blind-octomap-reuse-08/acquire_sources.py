"""Exact selected official source blobs only; no package installation."""
from pathlib import Path,PurePosixPath
import concurrent.futures,hashlib,json,os,shutil,threading,time,urllib.request
ROOT=Path(__file__).resolve().parent;PIN='007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f';RESERVE=768*1024**2;CAP=1024**2
selection=json.loads((ROOT/'SOURCE_SELECTION.json').read_text());assert selection['pin']==PIN and len(selection['files'])==48 and selection['totalBytes']==380478
assert sum(x['size'] for x in selection['files'])==380478 and shutil.disk_usage(ROOT).free>=RESERVE+50*1024**2
out=ROOT/'sources';out.mkdir(exist_ok=False);started=time.monotonic();lock=threading.Lock();transferred=0;completed=[]
def fetch(row):
 global transferred
 p=PurePosixPath(row['path']);assert not p.is_absolute() and '..' not in p.parts and row['mode']=='100644' and row['type']=='blob' and row['size']<=128*1024
 url=f'https://raw.githubusercontent.com/OctoMap/octomap/{PIN}/{p}'
 with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'bounded-licensed-source-acquisition'}),timeout=30) as response:
  assert response.geturl()==url;data=response.read(row['size']+1)
 with lock:
  transferred+=len(data)
  assert transferred<=CAP
 assert len(data)==row['size'];git=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest();assert git==row['sha']
 dest=out/p;dest.parent.mkdir(parents=True,exist_ok=True)
 with dest.open('xb') as f:f.write(data)
 assert shutil.disk_usage(ROOT).free>=RESERVE
 receipt={'path':str(p),'bytes':len(data),'gitBlobSHA1':git,'sha256':hashlib.sha256(data).hexdigest(),'url':url}
 with lock:completed.append(receipt)
 return receipt
error=None
try:
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
  for row in pool.map(fetch,selection['files']):print(json.dumps({'downloaded':row['path'],'bytes':row['bytes']}),flush=True)
except BaseException as e:error=repr(e)
finally:
 receipt={'success':error is None and len(completed)==48,'pin':PIN,'fileCount':len(completed),'sourceBytesTransferred':transferred,'sourceByteCap':CAP,'workByteCap':50*1024**2,'freeReserveBytes':RESERVE,'freeAfterBytes':shutil.disk_usage(ROOT).free,'wallSeconds':time.monotonic()-started,'error':error,'files':sorted(completed,key=lambda x:x['path']),'scriptSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'sourceSelectionSHA256':hashlib.sha256((ROOT/'SOURCE_SELECTION.json').read_bytes()).hexdigest()}
 with (ROOT/'ACQUISITION_RECEIPT.json').open('x') as f:f.write(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({k:v for k,v in receipt.items()if k!='files'}),flush=True)
if not receipt['success']:raise SystemExit(1)
