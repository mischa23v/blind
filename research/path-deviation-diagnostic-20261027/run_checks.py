#!/usr/bin/env python3
"""Bounded, serial, synthetic offline checks; no installation or replay."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import subprocess
import sys
import tempfile
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
UP=ROOT/'tools/navigation-recast/upstream'

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def limit():
    resource.setrlimit(resource.RLIMIT_CPU,(60,60))
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_FSIZE,(16*1024**2,16*1024**2))

def main():
    manifest=json.loads((ROOT/'tools/navigation-recast/UPSTREAM_MANIFEST.json').read_text())
    for item in manifest['files']:
        p=UP/item['path']
        assert digest(p)==item['sha256'], 'Changed upstream source: '+item['path']
    dependencies=[UP/'Detour/Source'/n for n in ('DetourCommon.cpp','DetourAlloc.cpp','DetourAssert.cpp')]
    inputs=[HERE/n for n in ('PROTOCOL.md','diagnostic.py','detour_metrics.cpp','test_diagnostic.py','run_checks.py')]+dependencies+sorted((UP/'Detour/Include').glob('*.h'))+[UP/'License.txt']
    source_hashes={str(p.relative_to(ROOT)):digest(p) for p in inputs}
    freeze={'createdUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'upstream_revision':manifest['revision'],'upstream_license':manifest['license'],'source_sha256':source_hashes,'scope':'synthetic supplied-pose diagnostic only'}
    index=1
    while list(HERE.glob(f'ATTEMPT_{index:02d}*')) or (HERE/f'FROZEN_{index:02d}.json').exists(): index+=1
    frozen=HERE/f'FROZEN_{index:02d}.json'
    with frozen.open('x') as f: f.write(json.dumps(freeze,indent=2)+'\n')
    result={'freeze':frozen.name,'freeze_sha256':digest(frozen),'startedUTC':freeze['createdUTC'],'upstream_all_manifest_files_verified':len(manifest['files']),'stages':[],'physical_guidance':False,'real_data_executed':False}
    receipt=HERE/f'ATTEMPT_{index:02d}.json'
    result.update(passed=False,terminal=False)
    with receipt.open('x') as f: f.write(json.dumps(result,indent=2)+'\n')
    with tempfile.TemporaryDirectory(prefix='blind-deviation-') as tmp:
        lib=Path(tmp)/'detour_diagnostic.so'
        commands=[('compile',['g++','-std=c++14','-O0','-shared','-fPIC','-I'+str(UP/'Detour/Include'),str(HERE/'detour_metrics.cpp'),*[str(p) for p in dependencies],'-o',str(lib)],120),('fixtures',[sys.executable,str(HERE/'test_diagnostic.py')],30)]
        for name,command,timeout in commands:
            begin=time.monotonic()
            env=dict(os.environ,DIAGNOSTIC_LIBRARY=str(lib),PYTHONDONTWRITEBYTECODE='1')
            timed_out=False; group_kill_sent=False
            try:
                process=subprocess.Popen(command,cwd=HERE,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,preexec_fn=limit,start_new_session=True)
            except OSError as error:
                result['launch_error']={'type':type(error).__name__,'errno':error.errno}; break
            try:
                stdout,stderr=process.communicate(timeout=timeout); log=stdout+stderr; code=process.returncode
            except (subprocess.TimeoutExpired,KeyboardInterrupt) as error:
                timed_out=isinstance(error,subprocess.TimeoutExpired)
                result['interruption_type']=type(error).__name__
                try:
                    os.killpg(process.pid,signal.SIGKILL); group_kill_sent=True
                except ProcessLookupError:
                    pass
                except PermissionError:
                    pass
                try:
                    stdout,stderr=process.communicate(timeout=2); log=stdout+stderr
                except subprocess.TimeoutExpired:
                    log='Owned process-group cleanup incomplete. No retry.\n'
                log+='Bounded process deadline exceeded. No retry.\n'; code=None
            output_cap_exceeded=len(log.encode())>1024**2
            if output_cap_exceeded:
                log=log.encode()[:1024**2].decode(errors='replace'); code=None
            logname=f'ATTEMPT_{index:02d}_{name}.log';(HERE/logname).write_text(log)
            result['stages'].append({'stage':name,'exit_code':code,'wall_seconds':time.monotonic()-begin,'output_cap_exceeded':output_cap_exceeded,'timed_out':timed_out,'timeout_group_kill_sent':group_kill_sent,'cpu_cap_scope':'per process, not aggregate','log':logname,'log_sha256':digest(HERE/logname)})
            receipt.write_text(json.dumps(result,indent=2)+'\n')
            if code!=0: break
        result['sources_unchanged']=all(digest(ROOT/p)==sha for p,sha in source_hashes.items())
        result['passed']=result['sources_unchanged'] and len(result['stages'])==2 and all(s['exit_code']==0 for s in result['stages'])
    result['terminal']=True
    result['finishedUTC']=datetime.datetime.now(datetime.timezone.utc).isoformat()
    receipt.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return 0 if result['passed'] else 1
if __name__=='__main__': sys.exit(main())
