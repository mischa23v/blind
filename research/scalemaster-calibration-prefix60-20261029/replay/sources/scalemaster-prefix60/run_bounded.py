"""Single admitted four-stage prefix replay, sampled RSS guard; no retries."""
import argparse,hashlib,json,math,os,resource,shutil,signal,subprocess,sys,time
from pathlib import Path


def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda:f.read(2**20),b''):h.update(b)
    return h.hexdigest()


def usage_tree(root):
    entries={};page=os.sysconf('SC_PAGE_SIZE');hz=os.sysconf('SC_CLK_TCK')
    for p in Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            fields=(p/'stat').read_text().rsplit(')',1)[1].split()
            entries[int(p.name)]=(int(fields[1]),int(fields[21])*page,sum(int(fields[i]) for i in (11,12,13,14))/hz)
        except (OSError,ValueError,IndexError):continue
    if root not in entries:raise RuntimeError('Resource counters unavailable')
    selected={root}
    while True:
        children={pid for pid,(ppid,_,_) in entries.items() if ppid in selected}
        if children<=selected:break
        selected|=children
    return sum(entries[p][1] for p in selected),sum(entries[p][2] for p in selected)


def disk_bytes(root):
    return sum(p.stat().st_size for p in root.rglob('*') if p.is_file())


def main():
    start=time.monotonic();initial_cpu=usage_tree(os.getpid())[1]
    ap=argparse.ArgumentParser();ap.add_argument('--output-root',required=True);ap.add_argument('--root-reviewed-and-slot-clear',action='store_true');a=ap.parse_args()
    if not a.root_reviewed_and_slot_clear:raise SystemExit('Root source review and CPU-slot admission required')
    src=Path(__file__).resolve().parent;freeze=src/'SOURCE_FREEZE.json';frozen=json.loads(freeze.read_text())
    out=Path(a.output_root).resolve();private=Path(frozen['private_data_root'])
    if out.parent!=private or out.exists():raise SystemExit('Fresh private sibling output required')
    if shutil.disk_usage(private).free<5*2**30+256*2**20:raise SystemExit('Insufficient free reserve')
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_CPU,(60,60))
    for name,h in frozen['source_sha256'].items():
        if sha(src/name)!=h:raise SystemExit('Source freeze mismatch')
    for path,h in frozen['small_input_sha256'].items():
        if sha(path)!=h:raise SystemExit('Input pin mismatch: '+path)
    for name,row in frozen['backend_modules'].items():
        if sha(row['path'])!=row['sha256']:raise SystemExit('Backend pin mismatch: '+name)
    if Path(frozen['input_paths']['archive']).stat().st_size!=frozen['archive']['bytes']:
        raise SystemExit('Archive size differs; do not execute')
    out.mkdir();cache=out/'cache';cache.mkdir();home=out/'home';home.mkdir()
    env=dict(os.environ)
    for k in list(env):
        if k.startswith('PIP_') or k in ('PYTHONPATH','PYTHONHOME','PYTHONUSERBASE','PYTHONPYCACHEPREFIX','LD_PRELOAD','LD_AUDIT','LD_LIBRARY_PATH','OPEN3D_ML_ROOT'):env.pop(k,None)
    env.update(PYTHONPATH=frozen['environment_target'],PYTHONOPTIMIZE='0',PYTHONNOUSERSITE='1',PYTHONDONTWRITEBYTECODE='1',
               HOME=str(home),XDG_CACHE_HOME=str(cache),MPLCONFIGDIR=str(cache/'mpl'),TMPDIR=str(cache),
               OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',NUMEXPR_NUM_THREADS='1',
               OPEN3D_DISABLE_WEB_VISUALIZER='true',CUDA_VISIBLE_DEVICES='')
    stages=[['replay.py','--freeze',str(freeze),'--output-root',str(out),'--software-only'],
            ['extract_prefix.py',str(freeze),str(out)],
            ['replay.py','--freeze',str(freeze),'--output-root',str(out)],
            ['preview.py',str(out)]]
    completed=[];peak_rss=0;peak_cpu=0;reason=None;active_stage=None
    def check():
        nonlocal peak_rss,peak_cpu
        rss,cpu=usage_tree(os.getpid());cpu-=initial_cpu
        peak_rss=max(peak_rss,rss);peak_cpu=max(peak_cpu,cpu)
        # Early stop margins for sampled enforcement and receipt finalization.
        if rss>960*2**20:raise RuntimeError('sampled_RSS_stop_margin_960MiB')
        if cpu>59:raise RuntimeError('CPU_stop_margin_59s')
        if time.monotonic()-start>89:raise RuntimeError('wall_stop_margin_89s')
        if disk_bytes(out)>240*2**20:raise RuntimeError('output_stop_margin_240MiB')
        if shutil.disk_usage(private).free<5*2**30:raise RuntimeError('free_space_reserve5GiB')
    try:
        for i,args in enumerate(stages):
            active_stage={'stage':i,'script':args[0]}
            check();remaining=60-(usage_tree(os.getpid())[1]-initial_cpu)
            if remaining<3:raise RuntimeError('Insufficient remaining CPU including receipt reserve')
            def limits():
                cap=math.floor(remaining-2)
                resource.setrlimit(resource.RLIMIT_CPU,(cap,cap));resource.setrlimit(resource.RLIMIT_FSIZE,(128*2**20,128*2**20))
            with (out/f'stage{i}.stdout.log').open('xb') as stdout,(out/f'stage{i}.stderr.log').open('xb') as stderr:
                child=subprocess.Popen([sys.executable,str(src/args[0]),*args[1:]],env=env,stdout=stdout,stderr=stderr,
                                       preexec_fn=limits,start_new_session=True)
                try:
                    while child.poll() is None:check();time.sleep(.05)
                    check()
                except BaseException:
                    try:os.killpg(child.pid,signal.SIGKILL)
                    except ProcessLookupError:pass
                    child.wait();raise
            completed.append({'stage':i,'script':args[0],'exit_code':child.returncode})
            if child.returncode:raise RuntimeError('Stage failure; no retries')
            active_stage=None
        for path,h in frozen['small_input_sha256'].items():
            if sha(path)!=h:raise RuntimeError('Pinned input changed during replay')
        for name,h in frozen['source_sha256'].items():
            if sha(src/name)!=h:raise RuntimeError('Source changed during replay')
        check()
    except BaseException as error:
        reason=repr(error)
    rss,cpu=usage_tree(os.getpid());cpu-=initial_cpu
    conservative_peak=(resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss+resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)*1024
    receipt={'status':'completed' if reason is None and len(completed)==4 else 'failed_or_inconclusive',
             'stop_reason':reason,'stages':completed,'source_freeze_sha256':sha(freeze),
             'interrupted_or_failed_active_stage':active_stage,
             'wall_seconds':time.monotonic()-start,'CPU_seconds':max(cpu,peak_cpu),
             'sampled_peak_process_tree_RSS_bytes':max(rss,peak_rss),'output_bytes_before_receipt':disk_bytes(out),
             'conservative_sum_of_process_peak_RSS_bytes':conservative_peak,
             'limits':{'CPU_seconds':60,'wall_seconds':90,'RSS_bytes':2**30,'output_bytes':256*2**20,
                       'logical_CPUs':1,'extracted_bytes':32*2**20,'free_reserve_bytes':5*2**30},
             'sampling_seconds':.05,'hard_aggregate_RSS_limit_established':False,
             'memory_enforcement':'sampled RSS with960MiB early stop, not RLIMIT_AS/cgroup; possible sampling overshoot disclosed',
             'no_install_network_retry_or_publication':True}
    if receipt['CPU_seconds']>60 or receipt['wall_seconds']>90 or max(receipt['sampled_peak_process_tree_RSS_bytes'],conservative_peak)>2**30 or receipt['output_bytes_before_receipt']>256*2**20:
        receipt['status']='failed_or_inconclusive';receipt['postcheck_budget_failure']=True
    with (out/'EXECUTION_RECEIPT.json').open('x') as f:json.dump(receipt,f,indent=2)
    print(json.dumps(receipt,indent=2))
    if receipt['status']!='completed':raise SystemExit(1)


if __name__=='__main__':main()
