"""Exclusive, bounded extraction of the frozen phone-only depth selection."""
from pathlib import Path
import hashlib,json,os,resource,shutil,signal,sys,tarfile,time
ROOT=Path(__file__).resolve().parent
ACQ=ROOT.parents[1]/'blind-mushroom-koivu-acquisition-01'
sys.path.insert(0,str(ACQ))
from guarded_archive import checked_archive,safe_name
RESERVE=768*1024**2
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1024**2),b''):h.update(b)
 return h.hexdigest()
def main():
 start=time.monotonic();resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(90,)*2);signal.alarm(180)
 selection=json.loads((ROOT/'DEPTH_SELECTION.json').read_text());wanted={r['member']:r for r in selection['members']}
 assert len(wanted)==294 and selection['bytes']==67180136
 assert sum(r['bytes'] for r in wanted.values())==selection['bytes']
 assert shutil.disk_usage(ROOT).free>=RESERVE+selection['bytes']
 target=ROOT/'depths.partial';target.mkdir(exist_ok=False);assert not (ROOT/'depths').exists()
 rows=[];seen=set()
 with checked_archive() as stream:
  with tarfile.open(fileobj=stream,mode='r|') as archive:
   for member in archive:
    name=safe_name(member.name)
    if name not in wanted:continue
    assert name not in seen and member.isreg() and not member.issparse() and member.size==wanted[name]['bytes'];seen.add(name)
    output=target/Path(name).name;h=hashlib.sha256();count=0
    with archive.extractfile(member) as source,output.open('xb') as sink:
     for block in iter(lambda:source.read(1024**2),b''):
      count+=len(block);assert count<=member.size;sink.write(block);h.update(block)
      assert shutil.disk_usage(ROOT).free>=RESERVE
    assert count==member.size
    rows.append({**wanted[name],'file':output.name,'sha256':h.hexdigest()})
 assert seen==set(wanted)
 rows.sort(key=lambda r:r['poseIndex'])
 receipt={'archiveSHA256':selection['archiveSHA256'],'poseSHA256':selection['posesSHA256'],'selectionSHA256':sha(ROOT/'DEPTH_SELECTION.json'),'scriptSHA256':sha(Path(__file__)),'files':rows,'selectedBytes':sum(r['bytes'] for r in rows),'wallSeconds':time.monotonic()-start,'freeAfterBytes':shutil.disk_usage(ROOT).free,'nativeConfidenceAvailable':False,'nativeTrackingAvailable':False,'newDownloads':0}
 (target/'DEPTH_INPUT_MANIFEST.json').write_text(json.dumps(receipt,indent=2)+'\n');target.rename(ROOT/'depths');print(json.dumps({k:v for k,v in receipt.items() if k!='files'}))
if __name__=='__main__':main()
