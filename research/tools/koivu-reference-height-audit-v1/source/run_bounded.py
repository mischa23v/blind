"""One serial evaluator pass; sampled watchdog, not a cgroup or safety gate."""
from pathlib import Path
import hashlib,json,os,resource,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1];WS=ROOT.parent
CPU=1800;WALL=2700;RSS=3*1024**3;OUTPUT=64*1024**2;RESERVE=768*1024**2
def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb')as f:
        while b:=f.read(1024**2):h.update(b)
    return h.hexdigest()
def verify(expected):
    if sha(ROOT/'FROZEN.json')!=expected:raise ValueError('manifest changed')
    for path,digest in json.loads((ROOT/'FROZEN.json').read_text())['files'].items():
        if sha(WS/path)!=digest:raise ValueError('source/input changed: '+path)
def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(CPU,CPU))
    resource.setrlimit(resource.RLIMIT_FSIZE,(OUTPUT,OUTPUT))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
def size(p):return sum(f.stat().st_size for f in p.rglob('*')if f.is_file())
def usage(pid):
    try:
        f=Path(f'/proc/{pid}/stat').read_text().rsplit(') ',1)[1].split()
        return int(f[21])*os.sysconf('SC_PAGE_SIZE')
    except FileNotFoundError:return 0
def main():
    expected=sys.argv[1];verify(expected)
    out=ROOT/'run-01';out.mkdir(exist_ok=False);start=time.monotonic();peak=0;failure=None;child=None;code=None
    before=resource.getrusage(resource.RUSAGE_CHILDREN)
    try:
        if shutil.disk_usage(ROOT).free<RESERVE+OUTPUT:raise ValueError('reserve preflight')
        with (out/'stdout.log').open('x')as so,(out/'stderr.log').open('x')as se:
            env=dict(os.environ,OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',VTK_SMP_IMPLEMENTATION_TYPE='Sequential',VTK_SMP_MAX_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
            child=subprocess.Popen([sys.executable,str(ROOT/'source/score_reference.py'),expected],stdout=so,stderr=se,env=env,preexec_fn=limits)
            with (out/'heartbeat.jsonl').open('x')as hb:
                while child.poll()is None:
                    peak=max(peak,usage(child.pid));elapsed=time.monotonic()-start;bytes_used=size(out)
                    hb.write(json.dumps({'wallSeconds':elapsed,'peakSampledRSSBytes':peak,'outputBytes':bytes_used})+'\n');hb.flush()
                    if elapsed>WALL or peak>RSS or bytes_used>OUTPUT-65536 or shutil.disk_usage(ROOT).free<RESERVE:
                        failure='observed resource budget';child.kill();break
                    time.sleep(.25)
            code=child.wait()
        verify(expected)
    except BaseException as e:failure=repr(e)
    finally:
        if child is not None and child.poll()is None:child.kill();code=child.wait()
        after=resource.getrusage(resource.RUSAGE_CHILDREN);peak=max(peak,after.ru_maxrss*1024);cpu=after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime;wall=time.monotonic()-start
        if peak>RSS or cpu>CPU or wall>WALL or size(out)>OUTPUT-65536 or shutil.disk_usage(ROOT).free<RESERVE:failure='terminal resource budget'
        receipt={'frozenManifestSHA256':expected,'exitCode':code,'success':code==0 and failure is None,'failure':failure,'wallSeconds':wall,'childCPUSeconds':cpu,'peakSampledOrWaitedRSSBytes':peak,'budgets':{'CPUSeconds':CPU,'wallSeconds':WALL,'RSSBytes':RSS,'outputBytes':OUTPUT,'freeReserveBytes':RESERVE},'sampledNotCgroupEnforcement':True,'singleWorkerNoChildProcessesExpected':True,'singleCPUAffinity':True,'fullFAROEvaluatorOnly':True,'gameEpisodes':0,'physicalAuthority':False}
        (out/'RUN_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
    if not receipt['success']:raise SystemExit(1)
if __name__=='__main__':main()
