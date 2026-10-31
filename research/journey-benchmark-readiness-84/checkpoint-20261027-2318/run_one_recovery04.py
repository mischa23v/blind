"""Attached one-episode supervisor; existing bounded runtime owns geometry subprocess."""
from pathlib import Path
import datetime,json,os,signal,subprocess,sys,time
BASE=Path(__file__).resolve().parents[1];ROOT=BASE/'evaluator-forward-recovery-04'
def main(index):
 receipt=json.loads((ROOT/'RECOVERY04_PREFLIGHT.json').read_text()); assert index in receipt['primaryForPendingEpisodeIndices']; ledger=json.loads((ROOT/'EPISODE_LEDGER.json').read_text());assert ledger[index]['status']=='notRun';assert all(x['status'] not in ('running','notRun') for x in ledger[46:index]);assert not (ROOT/'ACTIVE_RUN.lock').exists()
 def check():
  for root,entries in receipt['watches'].items():
   for n,x in entries.items():
    s=(Path(root)/n).stat()
    if s.st_size!=x['bytes'] or s.st_mtime_ns!=x['mtimeNs']:raise RuntimeError('previous producer evidence changed: '+root+'/'+n)
 check(); p=None;failure=None
 try:
  p=subprocess.Popen([sys.executable,str(ROOT/'run_bounded.py'),receipt['frozenManifestSHA256'],'episode',str(index)],env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'))
  while p.poll() is None:check();time.sleep(1)
  check()
 except BaseException as e:
  failure=repr(e)
  if p is not None and p.poll() is None:p.send_signal(signal.SIGINT);p.wait(timeout=30)
 finally:
  outcome={'episodeIndex':index,'completedUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'watchdogFailure':failure,'boundedExitCode':p.returncode if p is not None else None,'noPreviousProducerMutationObserved':failure is None}
  f=ROOT/'reviews'/f'ATTACHED_SUPERVISOR_{index:03d}.json';assert not f.exists();f.write_text(json.dumps(outcome,indent=2)+'\n');print(json.dumps(outcome),flush=True)
 if failure or p is None or p.returncode!=0:raise SystemExit(1)
if __name__=='__main__':main(int(sys.argv[1]))
