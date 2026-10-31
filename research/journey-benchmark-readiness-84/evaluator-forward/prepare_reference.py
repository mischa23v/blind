"""Hash and selective streaming extraction of known public evaluator-only geometry."""
from pathlib import Path,PurePosixPath
import hashlib,tarfile,json,resource,signal,shutil,time
H=Path(__file__).resolve().parent;OUT=H/'inputs';OUT.mkdir(exist_ok=True)
resource.setrlimit(resource.RLIMIT_AS,(384<<20,384<<20));resource.setrlimit(resource.RLIMIT_CPU,(180,180));resource.setrlimit(resource.RLIMIT_FSIZE,(700<<20,700<<20));signal.alarm(300);start=time.monotonic()
a=H/'koivu_mesh_pd.tar.gz';expected='e16605f237f0850fd069fb9aca39d300eb1aa3a3b1f5f3f660cb64230a91dd26'
def digest(p):
 h=hashlib.sha256()
 with p.open('rb')as f:
  while b:=f.read(1<<20):h.update(b)
 return h.hexdigest()
assert a.stat().st_size==455583916 and digest(a)==expected
assert shutil.disk_usage(H).free>4<<30
wanted={'room_datasets/koivu/gt_mesh.ply':('gt_mesh.ply',660550085,'e18db651c694046de7994237e276d88138ecef9071351281a418de9c9a279b5e'),'room_datasets/koivu/icp_iphone.json':('icp_iphone.json',449,'95b4e26d6d260bd9b06cff801648fc38c030a510cf4055af2294490cf49938d4')}
seen=set();total=0;inventory=[]
with tarfile.open(a,'r|gz')as t:
 for m in t:
  n=m.name.removeprefix('./');p=PurePosixPath(n);assert not p.is_absolute()and '..'not in p.parts and '\\'not in n and '\x00'not in n;assert n not in seen and(m.isdir()or m.isfile());seen.add(n);total+=m.size;assert len(seen)<=10000 and 0<=m.size<=700<<20 and total<=1<<30
  inventory.append({'name':n,'bytes':m.size,'regularFile':m.isfile()})
  if n in wanted:assert m.isfile()and m.size==wanted[n][1]
assert all(n in seen for n in wanted)
(H/'REFERENCE_INVENTORY.json').write_text(json.dumps({'archiveSHA256':expected,'archiveBytes':a.stat().st_size,'declaredExpandedBytes':total,'members':inventory,'selectedExtractedBytes':sum(v[1]for v in wanted.values()),'evaluatorOnly':True},indent=2)+'\n')
selected=[]
with tarfile.open(a,'r|gz')as t:
 for m in t:
  n=m.name.removeprefix('./')
  if n not in wanted:continue
  name,size,want=wanted[n];assert m.size==size;p=OUT/name;assert not p.exists(),'never overwrite';h=hashlib.sha256();count=0
  with t.extractfile(m)as src,p.open('xb')as dst:
   while b:=src.read(1<<20):
    count+=len(b);assert count<=size;h.update(b);dst.write(b)
  assert count==size and h.hexdigest()==want
  selected.append({'member':n,'bytes':count,'sha256':h.hexdigest()})
header=[]
with(OUT/'gt_mesh.ply').open('rb')as f:
 for i in range(100):
  l=f.readline(4096);assert l.endswith(b'\n');header.append(l.decode('ascii').rstrip())
  if l==b'end_header\n':break
 else:raise ValueError('bounded PLY header missing end')
r={'status':'verifiedOriginalEvaluatorMembers','evaluatorOnly':True,'sourceRoutesUnchanged':True,'archiveSHA256':expected,'selectedMembers':selected,'meshHeader':header,'nativeMeshLoaded':False,'movementEpisodes':0,'physicalAuthority':False,'wallSeconds':time.monotonic()-start,'CPUSeconds':sum(resource.getrusage(resource.RUSAGE_SELF)[:2]),'peakRSSKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'inputsBytes':sum(p.stat().st_size for p in OUT.iterdir())}
(H/'REFERENCE_ACQUISITION_RECEIPT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
