from pathlib import Path
import hashlib,json,resource,shutil,signal,sys,tarfile,time
ROOT=Path(__file__).resolve().parent;ACQ=ROOT.parents[2]/'blind-mushroom-koivu-acquisition-01';sys.path.insert(0,str(ACQ))
from guarded_archive import checked_archive,safe_name
resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(30,30));signal.alarm(60)
selection=json.loads((ROOT/'RGB_SELECTION.json').read_text());wanted={r['member']:r for r in selection};assert len(wanted)==3 and sum(r['bytes']for r in selection)==516128
assert shutil.disk_usage(ROOT).free>768*1024**2+516128
out=ROOT/'original-rgb';out.mkdir(exist_ok=False);rows=[]
with checked_archive() as stream:
 with tarfile.open(fileobj=stream,mode='r|')as archive:
  for member in archive:
   name=safe_name(member.name)
   if name not in wanted:continue
   assert member.isreg() and not member.issparse() and member.size==wanted[name]['bytes'];data=archive.extractfile(member).read(member.size+1);assert len(data)==member.size
   with (out/Path(name).name).open('xb')as f:f.write(data)
   rows.append({**wanted[name],'sha256':hashlib.sha256(data).hexdigest()})
assert len(rows)==3 and shutil.disk_usage(ROOT).free>=768*1024**2
(out/'EXTRACTION_RECEIPT.json').write_text(json.dumps({'archiveSHA256':'68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518','files':rows,'scriptSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'selectionSHA256':hashlib.sha256((ROOT/'RGB_SELECTION.json').read_bytes()).hexdigest(),'modifiedImages':False},indent=2)+'\n');print(json.dumps(rows))
