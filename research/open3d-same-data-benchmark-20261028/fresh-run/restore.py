from pathlib import Path
import sys,os,json,urllib.request,hashlib,time,shutil,tarfile
ROOT=Path(__file__).resolve().parent;sys.path.insert(0,str(ROOT/'source'));import acquire_environment as g
g.ROOT=ROOT;g.CAP=3*1024**3;g.RESERVE=1024**3;g.CPU=300;g.WALL=900;g.RSS=1024**3
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
b=g.Bounds(ROOT/'logs');transfer=0;receipt={'status':'running','transfers':[],'selected':[]}
def save():g.dump(ROOT/'RESTORE_RECEIPT.json',receipt)
def download(url,path,n,h):
 global transfer
 if path.exists():raise RuntimeError('refuse overwrite')
 if transfer+n>750000000:raise RuntimeError('network cap')
 sha=hashlib.sha256();count=0
 with urllib.request.urlopen(url,timeout=60) as r,path.open('xb') as f:
  if int(r.headers.get('Content-Length',n))!=n:raise RuntimeError('length header')
  while block:=r.read(1024**2):
   count+=len(block);transfer+=len(block)
   if count>n or transfer>750000000:raise RuntimeError('transfer cap')
   f.write(block);sha.update(block);b.check()
 if count!=n or sha.hexdigest()!=h:raise RuntimeError('hash/size mismatch '+str(path))
 receipt['transfers'].append({'name':path.name,'bytes':count,'sha256':sha.hexdigest()});save();print('verified',path.name,count,flush=True)
try:
 mem=int(next(x for x in Path('/proc/meminfo').read_text().splitlines() if x.startswith('MemAvailable:')).split()[1])*1024
 assert mem>=4*1024**3
 receipt['initialMemAvailable']=mem
 m=json.loads((ROOT.parent/'resource-proposal/ACQUISITION_PROPOSAL.json').read_text());g.check_reused(m['reusedInstalled'])
 for row in m['artifacts']:
  download(row['url'],ROOT/'wheels'/row['filename'],row['bytes'],row['sha256']);g.inspect_wheel(ROOT/'wheels'/row['filename'],row)
 for name,n,h in [('koivu_iphone.tar.gz',146575749,'68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518'),('koivu_mesh_pd.tar.gz',455583916,'e16605f237f0850fd069fb9aca39d300eb1aa3a3b1f5f3f660cb64230a91dd26')]:
  download('https://github.com/mischa23v/blind/releases/download/navigation-test-data-20261026/'+name,ROOT/'archives'/name,n,h)
 # Guarded stream extraction: exact per-frame public members; bounded metadata, no links.
 contract=json.loads((ROOT.parent/'DATA_CONTRACT.json').read_text());train=set(contract['trainingIDs']);seen=set();selected=0
 for name,limit in [('koivu_iphone.tar.gz',128*1024**2),('koivu_mesh_pd.tar.gz',660550534)]:
  subtotal=0;seen=set()
  with tarfile.open(ROOT/'archives'/name,'r|gz') as t:
   for member in t:
    p=Path(member.name)
    if p.is_absolute() or '..' in p.parts or member.issym() or member.islnk() or member.name in seen:raise RuntimeError('unsafe/duplicate member')
    seen.add(member.name)
    choose=(name.startswith('koivu_iphone') and 'long_capture' in p.parts and ((p.parent.name=='depth' and p.suffix=='.png') or (p.parent.name in ('rgb','images') and p.stem in train) or p.name in ('transformations.json','transforms.json','test.txt')))
    choose=choose or (name.startswith('koivu_mesh') and p.name in ('gt_mesh.ply','icp_iphone.json'))
    if not choose:continue
    if not member.isfile() or member.size>limit or subtotal+member.size>limit:raise RuntimeError('extraction cap')
    dest=ROOT/'inputs'/p;dest.parent.mkdir(parents=True,exist_ok=True);sha=hashlib.sha256();count=0
    with t.extractfile(member) as src,dest.open('xb') as f:
     while block:=src.read(1024**2):count+=len(block);f.write(block);sha.update(block);b.check()
    assert count==member.size;subtotal+=count
    receipt['selected'].append({'member':member.name,'bytes':count,'sha256':sha.hexdigest()})
  print('extracted',name,subtotal,flush=True);save()
 env=dict(os.environ);env.update(PYTHONDONTWRITEBYTECODE='1',PIP_NO_CACHE_DIR='1',TMPDIR=str(ROOT/'logs'),OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1')
 args=[sys.executable,'-m','pip','install','--no-index','--no-deps','--no-compile','--target',str(ROOT/'environment/target')]+[str(ROOT/'wheels'/r['filename']) for r in m['artifacts']]
 b.run(args,ROOT/'logs/install.stdout',ROOT/'logs/install.stderr',env)
 receipt.update(status='completed',transferBytes=transfer,wallSeconds=time.monotonic()-b.started,cpuSeconds=g.cpu()-b.cpu_start,peakSampledRSS=b.peak_rss,allocatedBytes=g.size(ROOT),phases=b.phases);save()
except BaseException as exc:
 receipt.update(status='failed',error=repr(exc),transferBytes=transfer,wallSeconds=time.monotonic()-b.started,cpuSeconds=g.cpu()-b.cpu_start,peakSampledRSS=b.peak_rss);save();raise
