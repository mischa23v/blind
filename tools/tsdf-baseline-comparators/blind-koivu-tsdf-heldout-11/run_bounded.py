"""Serial conventions then held-out evaluator watchdog; no geometry authority.

Uses the reviewed stage-06 Linux /proc tree accounting pattern. Limits are sampled,
not a cgroup guarantee. Child JSON progress is a log, never parsed as result JSON.
"""
from pathlib import Path
import argparse, hashlib, json, math, os, resource, shutil, signal, stat, subprocess, sys, time

ROOT=Path(__file__).resolve().parent
RECEIPT_ALLOWANCE=1048576
OUTSIDE_METADATA_RESERVATION=5*1048576
EXPECTED_LIMITS=dict(cpuSeconds=300,wallSeconds=450,treeRSSBytes=1610612736,
                    outputBytes=67108864,freeReserveBytes=805306368,combinedStageBytes=943718400)

def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()

def tree_usage(rootpid):
    entries={};page=os.sysconf('SC_PAGE_SIZE');hz=os.sysconf('SC_CLK_TCK')
    for p in Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            f=(p/'stat').read_text().rsplit(')',1)[1].split()
            entries[int(p.name)]=(int(f[1]),int(f[21])*page,sum(int(f[i]) for i in (11,12,13,14))/hz)
        except (OSError,ValueError,IndexError):continue
    if rootpid not in entries:raise RuntimeError('own /proc counters unavailable')
    selected={rootpid}
    while True:
        new={pid for pid,(ppid,_,_) in entries.items() if ppid in selected}
        if new<=selected:break
        selected|=new
    return sum(entries[p][1] for p in selected),sum(entries[p][2] for p in selected)

def directory_bytes(path):
    """Allocated bytes, including directory blocks; ignore only vanished entries."""
    root_stat=Path(path).lstat()
    if not stat.S_ISDIR(root_stat.st_mode):raise RuntimeError('stage root is not a directory')
    n=root_stat.st_blocks*512;count=0
    def walk_error(error):
        if not isinstance(error,FileNotFoundError):raise error
    for root,dirs,files in os.walk(path,followlinks=False,onerror=walk_error):
        for name in dirs+files:
            try:s=(Path(root)/name).lstat()
            except FileNotFoundError:continue
            count+=1
            if not (stat.S_ISREG(s.st_mode) or stat.S_ISDIR(s.st_mode)):
                raise RuntimeError('stage special file/symlink rejected')
            if count>50000:raise RuntimeError('stage entry-count cap')
            n+=s.st_blocks*512
    return n

def kill(child):
    if child is None:return
    try:os.killpg(child.pid,signal.SIGKILL)
    except ProcessLookupError:pass
    child.wait()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--frozen',type=Path,required=True)
    ap.add_argument('--frozen-sha',required=True)
    ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
    frozen=args.frozen.resolve();output=args.output.absolute()
    if output.parent.resolve()!=ROOT:raise ValueError('output must be a new immediate stage-11 subdirectory')
    if output.exists() or output.is_symlink():raise FileExistsError('no output overwrite')
    raw=frozen.read_bytes()
    if len(raw)>1048576:raise ValueError('manifest exceeds 1 MiB')
    if (len(args.frozen_sha)!=64 or any(c not in '0123456789abcdef' for c in args.frozen_sha)
            or hashlib.sha256(raw).hexdigest()!=args.frozen_sha):
        raise ValueError('externally pinned manifest SHA-256 mismatch before parse')
    spec=json.loads(raw);limits=spec['limits'];paths=spec['paths'];pins=spec['pins']
    if limits!=EXPECTED_LIMITS or spec.get('schemaVersion')!=1:raise ValueError('unapproved limits/schema')
    if Path(paths['heldoutStage']).resolve()!=ROOT or Path(paths['evaluator']).resolve()!=ROOT/'evaluate.py':
        raise ValueError('evaluator/stage path mismatch')
    base=Path(paths['baselineStage']).resolve()
    if base!=ROOT.parent/'blind-open3d-author-baseline-10':raise ValueError('baseline path mismatch')
    source_paths={Path(p['path']).resolve() for p in pins if p['role']=='source'}
    if not {Path(__file__).resolve(),ROOT/'evaluate.py',ROOT/'freeze_inputs.py'}<=source_paths:
        raise ValueError('required source pins absent')
    pins=pins+[dict(role='manifest',path=str(frozen),bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())]
    if shutil.disk_usage(ROOT).free<limits['freeReserveBytes']+limits['outputBytes']:
        raise RuntimeError('reserve plus maximum outputs unavailable')
    if directory_bytes(base)+directory_bytes(ROOT)+OUTSIDE_METADATA_RESERVATION+limits['outputBytes']>limits['combinedStageBytes']:
        raise RuntimeError('combined stage preflight cap')
    output.mkdir(mode=0o700);started=time.monotonic();cpu0=tree_usage(os.getpid())[1]
    child=None;peak_rss=0;last_cpu=0.;peak_bytes=0;phase='verify-before';completed=[];post=False;last_hb=0.
    heartbeat=output/'heartbeat.jsonl';heartbeat.touch(exist_ok=False)

    def check():
        nonlocal peak_rss,last_cpu,peak_bytes,last_hb
        rss,cpu=tree_usage(os.getpid());peak_rss=max(peak_rss,rss);last_cpu=max(last_cpu,cpu-cpu0)
        used=directory_bytes(output);peak_bytes=max(peak_bytes,used);free=shutil.disk_usage(ROOT).free
        if peak_rss>limits['treeRSSBytes']:raise RuntimeError('sampled 1.5 GiB tree RSS cap')
        if last_cpu>limits['cpuSeconds']:raise RuntimeError('total CPU cap')
        if time.monotonic()-started>limits['wallSeconds']:raise RuntimeError('total wall cap')
        if used>limits['outputBytes']-RECEIPT_ALLOWANCE:raise RuntimeError('output cap minus receipt allowance')
        if free<limits['freeReserveBytes']:raise RuntimeError('free reserve')
        # Check shared-stage growth without counting the baseline twice.
        if directory_bytes(base)+directory_bytes(ROOT)+OUTSIDE_METADATA_RESERVATION>limits['combinedStageBytes']:
            raise RuntimeError('combined allocated stage cap plus outside metadata reservation')
        if time.monotonic()-last_hb>=2:
            row=dict(phase=phase,wallSeconds=time.monotonic()-started,sampledTreeCPUSeconds=last_cpu,
                     sampledTreeRSSBytes=rss,peakTreeRSSBytes=peak_rss,outputBytes=used,freeBytes=free)
            data=(json.dumps(row,sort_keys=True)+'\n').encode()
            if used+len(data)>limits['outputBytes'] or free-len(data)<limits['freeReserveBytes']:
                raise RuntimeError('heartbeat budget')
            with heartbeat.open('ab') as f:f.write(data)
            last_hb=time.monotonic()

    def verify():
        for p in pins:
            path=Path(p['path'])
            fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW)
            with os.fdopen(fd,'rb') as f:
                a=os.fstat(f.fileno());h=hashlib.sha256()
                if not stat.S_ISREG(a.st_mode) or a.st_size!=p['bytes']:raise ValueError('pin type/size mismatch')
                for b in iter(lambda:f.read(1048576),b''):h.update(b)
                z=os.fstat(f.fileno())
            ident=lambda s:(s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
            if ident(a)!=ident(z) or ident(a)!=ident(path.stat(follow_symlinks=False)) or h.hexdigest()!=p['sha256']:
                raise ValueError('source/input pin mismatch: '+str(path))
            check()

    def write_receipt(name,obj):
        data=(json.dumps(obj,indent=2,sort_keys=True,allow_nan=False)+'\n').encode()
        if len(data)>RECEIPT_ALLOWANCE or directory_bytes(output)+len(data)>limits['outputBytes']:
            raise RuntimeError('receipt output cap')
        if shutil.disk_usage(ROOT).free-len(data)<limits['freeReserveBytes']:raise RuntimeError('receipt reserve')
        with (output/name).open('xb') as f:f.write(data)

    signal.signal(signal.SIGALRM,lambda *_:(_ for _ in ()).throw(TimeoutError('hard 450-second wall alarm')))
    signal.alarm(limits['wallSeconds'])
    try:
        verify()
        env=dict(os.environ)
        for k in ['LD_PRELOAD','LD_AUDIT','DISPLAY','WAYLAND_DISPLAY']:env.pop(k,None)
        env.update({k:'1' for k in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','NUMEXPR_NUM_THREADS',
                                   'VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS','VTK_SMP_MAX_THREADS']})
        env.update(VTK_SMP_IMPLEMENTATION_TYPE='Sequential',CUDA_VISIBLE_DEVICES='',HIP_VISIBLE_DEVICES='',PYTHONDONTWRITEBYTECODE='1')
        for mode in ['conventions','evaluate']:
            phase='verify-before-'+mode;verify();mode_dir=output/mode;mode_dir.mkdir()
            cache=mode_dir/'cache';cache.mkdir();tmp=mode_dir/'tmp';tmp.mkdir()
            env.update(TMPDIR=str(tmp),XDG_CACHE_HOME=str(cache),MPLCONFIGDIR=str(cache/'matplotlib'))
            command=[sys.executable,paths['evaluator'],'--mode',mode,'--output',str(mode_dir/'artifacts'),
                     '--frozen',str(frozen),'--frozen-sha',args.frozen_sha]
            remaining=max(1,int(math.floor(limits['cpuSeconds']-last_cpu)))
            def child_limits():
                resource.setrlimit(resource.RLIMIT_CPU,(remaining,remaining))
                resource.setrlimit(resource.RLIMIT_FSIZE,(limits['outputBytes'],limits['outputBytes']))
            with (mode_dir/'stdout.jsonl').open('xb') as out,(mode_dir/'stderr.log').open('xb') as err:
                child=subprocess.Popen(command,cwd=ROOT,stdout=out,stderr=err,env=env,
                    start_new_session=True,preexec_fn=child_limits)
                phase='running-'+mode
                while child.poll() is None:check();time.sleep(.1)
                check();code=child.returncode;kill(child);child=None
            phase='verify-after-'+mode;verify()
            if code!=0:raise RuntimeError(mode+' exited '+str(code))
            result=mode_dir/'artifacts/result.json'
            if not result.is_file():raise RuntimeError('separate result.json missing; stdout is never the result')
            if result.stat().st_size>1048576:raise RuntimeError('result JSON exceeds 1 MiB')
            parsed=json.loads(result.read_text())
            if not isinstance(parsed,dict):raise RuntimeError('result JSON is not an object')
            completed.append(dict(mode=mode,exitCode=code,resultPath=str(result),resultSHA256=digest(result)))
        phase='verify-final';verify();post=True
        receipt=dict(status='completed both serial modes; evaluator owns scientific conclusions',modes=completed,
            sourceAndInputHashesVerifiedBeforeAndAfter=True,pins=pins,limits=limits,
            resources=dict(wallSeconds=time.monotonic()-started,sampledTreeCPUSeconds=last_cpu,
                peakSampledTreeRSSBytes=peak_rss,peakOutputBytesBeforeReceipt=peak_bytes),
            enforcement='sampled /proc tree and files plus per-child CPU/per-file size limits; not a cgroup; short peaks may be missed',
            diskAccounting='allocated st_blocks*512 including directories',outsideMetadataReservationBytes=OUTSIDE_METADATA_RESERVATION,
            stdoutIsProgressOnly=True,geometryOrNavigationAuthority=False)
        write_receipt('RUN_RECEIPT.json',receipt);check();signal.alarm(0)
        print(json.dumps(dict(status='completed',output=str(output),resources=receipt['resources'])))
    except BaseException as e:
        kill(child);signal.alarm(0)
        failure=dict(status='failed; partial evidence retained',error=repr(e),phase=phase,modesCompleted=completed,
                     postHashVerificationCompleted=post,wallSeconds=time.monotonic()-started,
                     sampledTreeCPUSeconds=last_cpu,peakSampledTreeRSSBytes=peak_rss,noSuccessClaim=True)
        try:write_receipt('FAILURE_RECEIPT.json',failure)
        except Exception:print(json.dumps(failure),file=sys.stderr)
        raise

if __name__=='__main__':main()
