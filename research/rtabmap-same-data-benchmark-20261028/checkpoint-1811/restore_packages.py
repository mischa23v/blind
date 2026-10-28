import json,hashlib,urllib.request,subprocess,time,os,sys,shlex
from pathlib import Path
H=Path(__file__).resolve().parent; receipt=[]; start=time.monotonic(); total=0
selection=sys.argv[1] if len(sys.argv)>1 else 'SELECTED_PACKAGES'; packages=json.loads((H/('apt/'+selection+'.json')).read_text()); assert sum(int(p['Size'])for p in packages)<1536*1024**2
uris={}
for line in (H/'logs/apt-uris.log').read_text().splitlines():
 if line.startswith("'https://"):
  parts=shlex.split(line);uris[parts[1]]=parts[0]
for p in packages:
 name=p['Filename'].split('/')[-1]; dest=H/'apt/archives'/name
 url=uris.get(name,'https://snapshot.debian.org/archive/debian/20261020T000000Z/'+p['Filename'])
 if not dest.exists():
  with urllib.request.urlopen(url,timeout=60) as r, dest.open('wb') as out:
   while chunk:=r.read(1024*1024):
    total+=len(chunk); assert total<1536*1024**2
    out.write(chunk); assert out.tell()<=int(p['Size'])
 data=dest.read_bytes(); assert len(data)==int(p['Size']); assert hashlib.sha256(data).hexdigest()==p['SHA256']
 subprocess.run(['dpkg-deb','-x',str(dest),str(H/'prefix')],check=True,timeout=60)
 receipt.append({'package':p['Package'],'version':p['Version'],'url':url,'bytes':len(data),'sha256':p['SHA256'],'extractedWithoutMaintainerScripts':True})
 (H/('apt/'+selection+'_RECEIPT.json')).write_text(json.dumps({'packages':receipt,'networkBytesThisProcess':total,'elapsedSeconds':time.monotonic()-start},indent=2)+'\n')
 print(p['Package'],len(data),flush=True)
 assert time.monotonic()-start<1200
