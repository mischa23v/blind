"""Bounded process-tree wrapper reusing the earlier reviewed game watchdog."""
from pathlib import Path
import hashlib,json,os,resource,shutil,signal,subprocess,sys,time
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;WS=ROOT.parent
sys.path.insert(0,str(WS/'blind-koivu-game-07'))
from run_bounded import current_tree_usage,output_bytes,kill_group
CPU=600;WALL=900;RSS=3*1024**3;OUTPUT=64*1024**2;RESERVE=768*1024**2
def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb')as f:
        while b:=f.read(1024**2):h.update(b)
    return h.hexdigest()
def verify(expected):
    if sha(HERE/'FROZEN.json')!=expected:raise ValueError('manifest changed')
    for p,h in json.loads((HERE/'FROZEN.json').read_text())['files'].items():
        if sha(WS/p)!=h:raise ValueError('source/input changed: '+p)
def main(expected):
    out=HERE/'run-01';out.mkdir(exist_ok=False);child=None;failure=None;code=None;start=time.monotonic();initial_cpu=current_tree_usage(os.getpid())[1];peak=0;cpu=0
    try:
        if shutil.disk_usage(ROOT).free<RESERVE+OUTPUT:raise RuntimeError('disk reserve preflight')
        verify(expected)
        def limits():
            resource.setrlimit(resource.RLIMIT_CPU,(CPU,CPU));resource.setrlimit(resource.RLIMIT_FSIZE,(OUTPUT,OUTPUT));os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
        env=dict(os.environ,OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',VTK_SMP_IMPLEMENTATION_TYPE='Sequential',VTK_SMP_MAX_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
        with (out/'stdout.log').open('x')as so,(out/'stderr.log').open('x')as se,(out/'heartbeat.jsonl').open('x')as hb:
            child=subprocess.Popen([sys.executable,str(HERE/'compare_reference.py'),expected],stdout=so,stderr=se,env=env,start_new_session=True,preexec_fn=limits)
            while child.poll()is None:
                current,spent=current_tree_usage(os.getpid());peak=max(peak,current);cpu=max(cpu,spent-initial_cpu);wall=time.monotonic()-start
                hb.write(json.dumps({'wallSeconds':wall,'CPUSeconds':cpu,'treeRSSBytes':current,'peakTreeRSSBytes':peak})+'\n');hb.flush()
                if peak>RSS or cpu>CPU or wall>WALL or output_bytes(out)>OUTPUT-65536 or shutil.disk_usage(ROOT).free<RESERVE:raise RuntimeError('sampled process-tree/output budget')
                time.sleep(.1)
            code=child.wait();kill_group(child)
        verify(expected)
        if code!=0:raise RuntimeError('comparison child failed; retain original logs')
    except BaseException as e:failure=repr(e)
    finally:
        if child is not None:kill_group(child);code=child.returncode
        current,spent=current_tree_usage(os.getpid());peak=max(peak,current,resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss*1024);cpu=max(cpu,spent-initial_cpu);wall=time.monotonic()-start
        if peak>RSS or cpu>CPU or wall>WALL or output_bytes(out)>OUTPUT-65536 or shutil.disk_usage(ROOT).free<RESERVE:failure='terminal process-tree/output budget'
        receipt={'success':code==0 and failure is None,'failure':failure,'exitCode':code,'frozenManifestSHA256':expected,'wallSeconds':wall,'sampledTreeCPUSeconds':cpu,'peakSampledOrWaitedTreeRSSBytes':peak,'budgets':{'CPUSeconds':CPU,'wallSeconds':WALL,'RSSBytes':RSS,'outputBytes':OUTPUT,'reserveBytes':RESERVE},'sampledNotCgroup':True,'comparisonOutcomeOwnedByResult':True,'physicalAuthority':False}
        (out/'RUN_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
    if not receipt['success']:raise SystemExit(1)
if __name__=='__main__':main(sys.argv[1])
