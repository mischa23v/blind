"""Bounded eight-frame audit; explicit local roots, immutable input/source pins."""
from pathlib import Path
import hashlib,json,math,os,resource,shutil,signal,subprocess,sys,time,struct,zipfile,stat,urllib.request,urllib.parse,importlib.metadata

ROOT=Path(__file__).resolve().parent
CAP=900*1024**2; RESERVE=768*1024**2; CPU=600.; WALL=900.; RSS=1024*1024**2

def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest()
def dump(path,value):path.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')
def size(path):
    try:total=path.lstat().st_blocks*512
    except FileNotFoundError:return 0
    for p in path.rglob('*'):
        try:total+=p.lstat().st_blocks*512
        except FileNotFoundError:pass  # pip may move/remove an owned temporary file between samples
    return total
def current_tree_usage(rootpid):
    """Sample live tree RSS and CPU including each process's already-waited descendants.

    A child's live CPU is not in its parent's waited-child counters. Summing
    utime/stime/cutime/cstime once per currently live tree process includes active
    compiler/plot CPU without waiting for RUSAGE_CHILDREN to update. This remains
    a sampled Linux watchdog, with tick resolution and process-exit sampling races.
    """
    entries={};page=os.sysconf('SC_PAGE_SIZE');hz=os.sysconf('SC_CLK_TCK')
    for p in Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            fields=(p/'stat').read_text().rsplit(')',1)[1].split()
            entries[int(p.name)]=(int(fields[1]),int(fields[21])*page,sum(int(fields[i]) for i in (11,12,13,14))/hz)
        except (OSError,ValueError,IndexError):continue
    if rootpid not in entries:raise RuntimeError('own resource counters unavailable')
    selected={rootpid}
    while True:
        new={pid for pid,(ppid,_,_) in entries.items() if ppid in selected}
        if new<=selected:break
        selected|=new
    return sum(entries[p][1] for p in selected),sum(entries[p][2] for p in selected)

def cpu():return current_tree_usage(os.getpid())[1]

class Bounds:
    def __init__(self,cache):
        self.started=time.monotonic();self.cpu_start=cpu();self.cache=cache;self.cache_before=size(cache)
        self.root_before=size(ROOT);self.peak_rss=0;self.phases=[]
    def check(self):
        observed_rss,observed_cpu=current_tree_usage(os.getpid())
        self.peak_rss=max(self.peak_rss,observed_rss)
        if self.peak_rss>RSS:raise RuntimeError('sampled process-tree RSS cap')
        if time.monotonic()-self.started>WALL:raise RuntimeError('total wall cap')
        if observed_cpu-self.cpu_start>CPU:raise RuntimeError('total CPU cap')
        if self.new_bytes()>CAP:raise RuntimeError('new output cap')
        if shutil.disk_usage(ROOT).free<RESERVE:raise RuntimeError('free-space reserve')
    def new_bytes(self):return size(ROOT)+5*1024**2  # reserve metadata research outside this stage
    def run(self,args,stdout,stderr,env):
        self.check();remaining=max(1,int(math.floor(CPU-(cpu()-self.cpu_start))))
        def limits():resource.setrlimit(resource.RLIMIT_CPU,(remaining,remaining))
        start=time.monotonic();before=cpu()
        with stdout.open('wb') as out,stderr.open('wb') as err:
            p=subprocess.Popen(args,stdout=out,stderr=err,env=env,start_new_session=True,preexec_fn=limits)
            try:
                while p.poll() is None:self.check();time.sleep(.04)
                self.check()
            except BaseException:
                try:os.killpg(p.pid,signal.SIGKILL)
                except ProcessLookupError:pass
                p.wait();raise
        self.phases.append({'command':args,'exitCode':p.returncode,'wallSeconds':time.monotonic()-start,'cpuSeconds':cpu()-before})
        if p.returncode:raise RuntimeError('phase failed; original logs retained: '+str(stdout))


MANIFEST_SHA='7294a7febe423b4643ff86252de83d16a8b87e1cdd9d497f4a0649039be45b0b'
TRANSFER_CAP=200*1024**2

class ExactHostRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):
        u=urllib.parse.urlparse(newurl)
        if u.scheme!='https' or u.hostname!='files.pythonhosted.org' or u.username is not None or u.password is not None or u.port not in (None,443):raise ValueError('unapproved package redirect')
        return super().redirect_request(req,fp,code,msg,headers,newurl)

def check_reused(rows):
    for row in rows:
        d=importlib.metadata.distribution(row['name'])
        if d.version!=row['version'] or hashlib.sha256(d.read_text('METADATA').encode()).hexdigest()!=row['installedMetadataSHA256']:raise ValueError('reused installed distribution changed: '+row['name'])

def inspect_wheel(path,row):
    with zipfile.ZipFile(path) as z:
        members=z.infolist();seen=set();logical=0
        for v in members:
            parts=v.filename.split('/');mode=stat.S_IFMT(v.external_attr>>16)
            if v.filename.startswith('/') or any(p in ('.','..') or '\\' in p or ':' in p for p in parts) or v.filename in seen or mode not in (0,stat.S_IFREG,stat.S_IFDIR) or v.flag_bits&1:raise ValueError('unsafe wheel member')
            seen.add(v.filename);logical+=v.file_size
        if len(members)!=row['memberCount'] or logical!=row['uncompressedBytes']:raise ValueError('wheel expanded inventory differs')
        meta=[v for v in members if v.filename.endswith('.dist-info/METADATA')]
        if len(meta)!=1 or meta[0].file_size>1024**2 or hashlib.sha256(z.read(meta[0])).hexdigest()!=row['wheelMetadataSHA256']:raise ValueError('wheel metadata differs from resolution')
        return {'filename':path.name,'bytes':path.stat().st_size,'sha256':digest(path),'members':len(members),'uncompressedBytes':logical}

def main():
    manifest=ROOT.parent/'blind-established-tsdf-research-05/dependencies/ACQUISITION_PROPOSAL.json'
    if digest(manifest)!=MANIFEST_SHA:raise ValueError('frozen acquisition manifest mismatch')
    m=json.loads(manifest.read_text());rows=m['artifacts']
    if len(rows)!=28 or m['totalBytes']!=121400340 or m['uncompressedBytes']!=368764121 or len(m['reusedInstalled'])!=46:raise ValueError('approved closure mismatch')
    if m['totalBytes']+m['metadataBytes']>TRANSFER_CAP:raise ValueError('transfer cap')
    if sum(r['bytes'] for r in rows)!=m['totalBytes'] or sum(r['uncompressedBytes'] for r in rows)!=m['uncompressedBytes']:raise ValueError('manifest totals')
    for r in rows:
        u=urllib.parse.urlparse(r['url']);name=r['filename']
        if u.scheme!='https' or u.hostname!='files.pythonhosted.org' or u.username is not None or u.password is not None or u.port not in (None,443) or Path(name).name!=name or not name.endswith('.whl') or len(r['sha256'])!=64 or r['name'].lower().startswith(('torch','nvidia','tensorflow','cuda')):raise ValueError('unapproved artifact')
    check_reused(m['reusedInstalled'])
    if shutil.disk_usage(ROOT).free<RESERVE+CAP:raise RuntimeError('insufficient initial reserve plus full added-disk cap')
    out=ROOT/'environment'
    if out.exists():raise RuntimeError('refuse historical environment overwrite')
    out.mkdir();wheels=out/'wheels';wheels.mkdir();target=out/'target';temp=out/'tmp';temp.mkdir();cache=out/'cache';cache.mkdir()
    b=Bounds(cache);pins={str(manifest):MANIFEST_SHA,str(Path(__file__).resolve()):digest(__file__)};receipts=[];transferred=m['metadataBytes'];started=time.monotonic()
    def wall_timeout(signum,frame):raise TimeoutError('overall environment wall cap')
    signal.signal(signal.SIGALRM,wall_timeout);signal.alarm(int(WALL))
    try:
        b.check();opener=urllib.request.build_opener(ExactHostRedirect())
        for r in rows:
            b.check();path=wheels/r['filename'];partial=path.with_name(path.name+'.partial');count=0;sha=hashlib.sha256()
            req=urllib.request.Request(r['url'],headers={'User-Agent':'bounded-official-package-verification/1.0','Accept-Encoding':'identity'})
            with opener.open(req,timeout=30) as response,partial.open('xb') as output:
                final_url=urllib.parse.urlparse(response.geturl())
                if response.status!=200 or final_url.scheme!='https' or final_url.hostname!='files.pythonhosted.org' or final_url.username is not None or final_url.password is not None or final_url.port not in (None,443):raise ValueError('package response origin/status')
                declared=response.headers.get('Content-Length')
                if declared is None or int(declared)!=r['bytes']:raise ValueError('package declared bytes differ')
                while True:
                    b.check();chunk=response.read(min(1024**2,r['bytes']-count+1))
                    if not chunk:break
                    count+=len(chunk);transferred+=len(chunk)
                    if count>r['bytes'] or transferred>TRANSFER_CAP:raise RuntimeError('package transfer cap')
                    output.write(chunk);sha.update(chunk)
            if count!=r['bytes'] or sha.hexdigest()!=r['sha256']:raise ValueError('official package checksum mismatch')
            partial.rename(path);receipts.append(inspect_wheel(path,r));dump(out/'DOWNLOAD_PROGRESS.json',{'completed':receipts,'transferBytesIncludingPriorMetadata':transferred})
            print(json.dumps({'phase':'verified_wheel','name':r['name'],'bytes':count}),flush=True)
        check_reused(m['reusedInstalled']);b.check()
        env=dict(os.environ)
        for k in list(env):
            if k.startswith('PIP_') or k in ('PYTHONPATH','PYTHONHOME','PYTHONUSERBASE','PYTHONPYCACHEPREFIX','LD_PRELOAD','LD_AUDIT','LD_LIBRARY_PATH'):env.pop(k,None)
        home=out/'home';home.mkdir()
        env.update(HOME=str(home),XDG_CONFIG_HOME=str(home/'config'),XDG_DATA_HOME=str(home/'data'),XDG_STATE_HOME=str(home/'state'),MPLCONFIGDIR=str(cache/'matplotlib'),IPYTHONDIR=str(home/'ipython'),JUPYTER_CONFIG_DIR=str(home/'jupyter-config'),JUPYTER_DATA_DIR=str(home/'jupyter-data'),JUPYTER_RUNTIME_DIR=str(home/'jupyter-runtime'))
        env.update(PYTHONDONTWRITEBYTECODE='1',PYTHONNOUSERSITE='1',PIP_CONFIG_FILE=os.devnull,PIP_NO_INDEX='1',PIP_DISABLE_PIP_VERSION_CHECK='1',PIP_CACHE_DIR=str(cache),TMPDIR=str(temp),XDG_CACHE_HOME=str(cache),OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',OPEN3D_DISABLE_WEB_VISUALIZER='true')
        command=[sys.executable,'-m','pip','install','--no-index','--no-deps','--no-compile','--disable-pip-version-check','--target',str(target)]+[str(wheels/r['filename']) for r in rows]
        b.run(command,out/'install.stdout.log',out/'install.stderr.log',env)
        if any(temp.iterdir()):raise RuntimeError('pip left temporary staging; preserve and assess before subsequent phases')
        env['PYTHONPATH']=str(target)
        probe="""import importlib.metadata as md,json,pathlib,sys
import open3d as o3d
m=json.loads(pathlib.Path(sys.argv[1]).read_text());target=pathlib.Path(sys.argv[2]).resolve()
assert o3d.__version__=='0.19.0'
assert pathlib.Path(o3d.__file__).resolve().is_relative_to(target)
assert not o3d._build_config['BUILD_CUDA_MODULE']
for row in m['artifacts']+m['reusedInstalled']:
 assert md.version(row['name'])==row['version'], row['name']
print(json.dumps({'version':o3d.__version__,'modulePath':str(pathlib.Path(o3d.__file__).resolve()),'buildConfig':o3d._build_config,'distributionVersions':{r['name']:md.version(r['name']) for r in m['artifacts']+m['reusedInstalled']},'reconstructionExecuted':False},indent=2))
"""
        (out/'verify_import.py').write_text(probe)
        b.run([sys.executable,str(out/'verify_import.py'),str(manifest),str(target)],out/'import-result.json',out/'import.stderr.log',env)
        for p,h in pins.items():
            if digest(p)!=h:raise ValueError('source/manifest changed')
        check_reused(m['reusedInstalled'])
        for r in rows:
            if digest(wheels/r['filename'])!=r['sha256']:raise ValueError('wheel changed after install')
        b.check()
        receipt={'status':'completed','scope':'Isolated official CPU package environment only; no reconstruction/navigation run','manifestSHA256':MANIFEST_SHA,'sourceSHA256':pins[str(Path(__file__).resolve())],'wheels':receipts,'transferBytesIncludingPriorMetadata':transferred,'wallSeconds':time.monotonic()-started,'cpuSeconds':cpu()-b.cpu_start,'sampledPeakProcessTreeRSSBytes':b.peak_rss,'phases':b.phases,'freeAfterBytes':shutil.disk_usage(ROOT).free,'targetAllocatedDiskBytes':size(target),'allWorkspaceAllocatedDiskBytesBeforeReceipt':size(ROOT),'outsideMetadataReservationBytes':5*1024**2,'caps':{'transferBytes':TRANSFER_CAP,'allWorkspaceBytes':CAP,'freeReserveBytes':RESERVE,'CPUSeconds':CPU,'wallSeconds':WALL,'sampledRSSBytes':RSS},'pinsReverifiedAfter':True,'pipTempEmpty':True,'importResultSHA256':digest(out/'import-result.json')}
        dump(out/'RECEIPT.json',receipt);b.check()
        print(json.dumps({'status':'completed','target':'environment/target','wallSeconds':receipt['wallSeconds'],'targetAllocatedDiskBytes':receipt['targetAllocatedDiskBytes'],'freeAfterBytes':shutil.disk_usage(ROOT).free}),flush=True)
    except BaseException as exc:
        dump(out/'FAILURE.json',{'status':'failed','error':repr(exc),'completedWheels':receipts,'transferBytesIncludingPriorMetadata':transferred,'phases':b.phases,'wallSeconds':time.monotonic()-started,'sourcePins':pins});raise
    finally:signal.alarm(0)

if __name__=='__main__':main()
