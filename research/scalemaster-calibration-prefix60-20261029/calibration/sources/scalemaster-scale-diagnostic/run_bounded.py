"""Guarded runner with cumulative child CPU/wall budgets. Requires root review/slot."""
import argparse,json,math,os,resource,subprocess,sys,time
from pathlib import Path

def main():
    start=time.monotonic()
    # One controller plus one child: address-space reservations sum to256MiB.
    # The controller keeps a256MiB hard ceiling so the child can set its192MiB cap.
    resource.setrlimit(resource.RLIMIT_AS,(64*2**20,256*2**20))
    resource.setrlimit(resource.RLIMIT_CPU,(30,30))
    ap=argparse.ArgumentParser();ap.add_argument('--data-root',required=True);ap.add_argument('--output-root',required=True)
    ap.add_argument('--root-reviewed-and-slot-clear',action='store_true');a=ap.parse_args()
    if not a.root_reviewed_and_slot_clear:raise SystemExit('Do not run until parent has reviewed source and released the CPU slot')
    src=Path(__file__).resolve().parent;data=Path(a.data_root).resolve();out=Path(a.output_root).resolve()
    freeze=src/'SOURCE_FREEZE.json';snapshot=json.loads(freeze.read_text())
    import hashlib
    for name,sha in snapshot['scripts_sha256'].items():
        if hashlib.sha256((src/name).read_bytes()).hexdigest()!=sha:raise SystemExit('Source freeze mismatch')
    for name,sha in snapshot['metadata_sha256'].items():
        if hashlib.sha256((data/name).read_bytes()).hexdigest()!=sha:raise SystemExit('Metadata freeze mismatch')
    if (data/'archives/Stairs_02.tar.gz').stat().st_size!=snapshot['archive']['bytes']:raise SystemExit('Archive size changed')
    if out.exists():raise SystemExit('Choose a fresh private output root; frozen selections are not overwritten')
    manifest=out/'frozen-pairs.json';images=out/'images'
    stages=[['freeze_pairs.py',str(data/'metadata/Stairs_02/odometry.csv'),str(manifest),'--source-freeze',str(freeze),'--camera-matrix',str(data/'metadata/Stairs_02/camera_matrix.csv')],
        ['diagnostic.py','--synthetic-only','--out',str(out/'synthetic-checks.json')],
        ['extract_selected.py',str(manifest),str(data/'archives/Stairs_02.tar.gz'),str(data/'metadata/Stairs_02/member-inventory.json'),str(images)],
        ['diagnostic.py','--approve-real-run','--manifest',str(manifest),'--images',str(images),'--out',str(out/'diagnostic-result.json')]]
    env=dict(os.environ)
    for k in ('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS','NUMEXPR_NUM_THREADS'):env[k]='1'
    results=[]
    for stage in stages:
        usage=resource.getrusage(resource.RUSAGE_CHILDREN);own=resource.getrusage(resource.RUSAGE_SELF)
        used=usage.ru_utime+usage.ru_stime+own.ru_utime+own.ru_stime
        cpu_left=30.-used;wall_left=45.-(time.monotonic()-start)
        if cpu_left<1 or wall_left<1:
            results.append({'stage':stage[0],'error':'Budget exhausted between stages'});break
        def limits():
            resource.setrlimit(resource.RLIMIT_CPU,(max(1,math.floor(cpu_left)),max(1,math.ceil(cpu_left))))
            resource.setrlimit(resource.RLIMIT_AS,(192*2**20,192*2**20))
            if hasattr(os,'sched_getaffinity'):os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
        cmd=[sys.executable,str(src/stage[0]),*stage[1:]]
        try:
            r=subprocess.run(cmd,env=env,preexec_fn=limits,timeout=wall_left,capture_output=True,text=True)
            results.append({'stage':stage[0],'returncode':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
        except subprocess.TimeoutExpired:
            results.append({'stage':stage[0],'error':'cumulative45s wall cap'});break
        if r.returncode:break
    usage=resource.getrusage(resource.RUSAGE_CHILDREN);own=resource.getrusage(resource.RUSAGE_SELF)
    receipt={'stages':results,'cpu_seconds':usage.ru_utime+usage.ru_stime+own.ru_utime+own.ru_stime,
        'wall_seconds':time.monotonic()-start,'max_child_rss_KiB':usage.ru_maxrss,
        'controller_max_rss_KiB':own.ru_maxrss,'sum_of_peak_RSS_upper_bound_KiB':own.ru_maxrss+usage.ru_maxrss,
        'all_stages_completed':len(results)==len(stages) and all(r.get('returncode')==0 for r in results),
        'source_freeze_sha256':hashlib.sha256(freeze.read_bytes()).hexdigest(),
        'limits':{'cumulative_controller_and_child_cpu_seconds':30,'wall_seconds':45,'child_address_space_MiB':192,'controller_address_space_MiB':64,'sum_address_space_reservations_MiB':256,'extracted_data_MiB':3}}
    out.mkdir(parents=True,exist_ok=True);(out/'execution-receipt.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt,indent=2))
    if not receipt['all_stages_completed']:raise SystemExit(1)

if __name__=='__main__':main()
