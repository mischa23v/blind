from pathlib import Path
import hashlib,json,shutil,time,urllib.request
ROOT=Path(__file__).resolve().parent
def main():
 p=ROOT/'ASSET_PLAN.json';plan=json.loads(p.read_text());start=time.monotonic();total=0;results=[]
 if sum(a['bytes']for a in plan['assets'])>plan['transferCapBytes']:raise ValueError('transfer budget')
 if shutil.disk_usage(ROOT).free<plan['freeReserveBytes']+sum(a['bytes']for a in plan['assets']):raise ValueError('reserve preflight')
 try:
  for a in plan['assets']:
   target=ROOT/'upstream'/a['path'];target.parent.mkdir(parents=True,exist_ok=True)
   row=dict(a,status='partial');results.append(row);n=0;h=hashlib.sha256();g=hashlib.sha1(b'blob '+str(a['bytes']).encode()+b'\0')
   with target.open('xb')as out,urllib.request.urlopen(a['url'],timeout=30)as response:
    if response.status!=200:raise ValueError('HTTP status')
    if response.headers.get('Content-Length')not in (None,str(a['bytes'])):raise ValueError('length header')
    while True:
     chunk=response.read(min(65536,a['bytes']-n+1))
     if not chunk:break
     n+=len(chunk);total+=len(chunk)
     if n>a['bytes']or total>plan['transferCapBytes']or time.monotonic()-start>180 or shutil.disk_usage(ROOT).free<plan['freeReserveBytes']+len(chunk):raise ValueError('budget')
     out.write(chunk);h.update(chunk);g.update(chunk)
   row.update(receivedBytes=n,actualSHA256=h.hexdigest(),actualGitBlob=g.hexdigest())
   if n!=a['bytes']or h.hexdigest()!=a['sha256']or g.hexdigest()!=a['gitBlob']:raise ValueError('identity')
   row['status']='verified'
 finally:
  r={'planSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'wallSeconds':time.monotonic()-start,'receivedBytes':total,'files':results,'freeBytes':shutil.disk_usage(ROOT).free}
  (ROOT/'ASSET_ACQUISITION.json').write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps({'files':len(results),'bytes':total,'wallSeconds':r['wallSeconds'],'allVerified':all(x['status']=='verified'for x in results)}))
if __name__=='__main__':main()
