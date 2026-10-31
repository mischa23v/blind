#!/usr/bin/env python3
"""Use only on a separate clean, pinned Actions checkout; original audit runner reused."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys
from instrument import SOURCE, instrument

HERE=Path(__file__).resolve().parent

def main():
 if len(sys.argv)!=2: raise SystemExit('Supply separate disposable pinned-source checkout')
 root=Path(sys.argv[1]).resolve()
 workspace=Path(os.environ['GITHUB_WORKSPACE']).resolve()
 if root!=workspace/'pinned-camera-source': raise SystemExit('Expected dedicated checkout subdirectory')
 if HERE.is_relative_to(root): raise SystemExit('Diagnostic tools cannot live in target source checkout')
 def git(*args): return subprocess.check_output(['git','-C',str(root),*args],text=True,timeout=30).strip()
 if git('rev-parse','HEAD')!=SOURCE or git('status','--porcelain'):
  raise SystemExit('Disposable source must be clean and exactly pinned')
 output=Path(os.environ['RUNNER_TEMP'])/'blind-effective-type-provenance'
 output.mkdir(exist_ok=False)
 receipt={'schema':1,'source':SOURCE,'method':'disposable category-only app probe; no geometry reader',
          'files':instrument(root),'nativeExecutionEvidence':'See runner outcomes.json build and cases; invocation alone is not execution'}
 shutil.copyfile(HERE/'effective_trace_collector.py',root/'tools/ci/effective_trace_collector.py')
 receipt['collectorSha256']=hashlib.sha256((HERE/'effective_trace_collector.py').read_bytes()).hexdigest()
 (output/'instrumentation.json').write_text(json.dumps(receipt,indent=2)+'\n')
 env=dict(os.environ);env['GITHUB_SHA']=SOURCE
 code=subprocess.call([sys.executable,str(root/'tools/ci/camera-audit-scope-control.py')],cwd=root,env=env)
 receipt['runnerInvoked']=True;receipt['runnerExitCode']=code
 # Runner's build/cases, not invocation, establish which native stages actually ran.
 (output/'instrumentation.json').write_text(json.dumps(receipt,indent=2)+'\n')
 return code

if __name__=='__main__':sys.exit(main())
