"""Bounded pure/authored controls; no native Coffee job, build, install or retry."""
import hashlib
import json
import os
import pathlib
import resource
import subprocess
import sys
import time

H = pathlib.Path(__file__).resolve().parent
R = H.parents[1]


def main():
    if len(sys.argv) != 2: raise SystemExit('usage: run_controls.py <fresh-result.json>')
    out = pathlib.Path(sys.argv[1])
    if out.exists(): raise SystemExit('refusing existing result')
    inputs = [H/'joint_cost.py',H/'fixtures.py',H/'run_controls.py',
              R/'research/clearance-first-coffee-source-20261029/selector.py',
              R/'research/clearance-first-coffee-repair-source-20261029/manual_filter.py',
              R/'research/independent-2d-route-validator-20261029/validator.py',
              R/'research/independent-2d-route-validator-20261029/proposal_windows.py']
    def pins(): return {str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    before = pins(); start = time.monotonic()
    def limits():
        resource.setrlimit(resource.RLIMIT_CPU,(10,10))
        resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
        resource.setrlimit(resource.RLIMIT_FSIZE,(1024**2,1024**2))
        resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    env = dict(os.environ,OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',
               PYTHONDONTWRITEBYTECODE='1')
    argv = [sys.executable,'-B',str(H/'fixtures.py')]
    timed_out = False
    try:
        run = subprocess.run(argv,env=env,capture_output=True,text=True,timeout=20,preexec_fn=limits)
        code,stdout,stderr = run.returncode,run.stdout,run.stderr
    except subprocess.TimeoutExpired as error:
        timed_out = True; code = None
        def decode(value): return value.decode(errors='replace') if isinstance(value,bytes) else value or ''
        stdout,stderr = decode(error.stdout),decode(error.stderr)
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    after = pins()
    receipt = {'status':'passed' if code==0 and before==after else 'failed',
               'command':['python','-B','research/clearance-first-joint-cost-source-20261029/fixtures.py'],
               'exitCode':code,'timedOut':timed_out,'wallSeconds':time.monotonic()-start,
               'childCPUSeconds':usage.ru_utime+usage.ru_stime,'peakChildRSSKiB':usage.ru_maxrss,
               'limits':{'cpuSeconds':10,'wallSeconds':20,'addressSpaceBytes':512*1024**2},
               'sourceHashesBefore':before,'sourceHashesAfter':after,
               'stderr':stderr,'physicalAuthority':False}
    receipt['controls'] = json.loads(stdout) if code==0 else stdout
    with out.open('x') as f: json.dump(receipt,f,indent=2); f.write('\n')
    print(json.dumps({'status':receipt['status'],'result':str(out),
                      'count':receipt['controls'].get('count') if code==0 else None,
                      'wallSeconds':receipt['wallSeconds'],'peakChildRSSKiB':receipt['peakChildRSSKiB']}))
    if receipt['status'] != 'passed': raise SystemExit(1)


if __name__ == '__main__': main()
