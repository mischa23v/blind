"""Review/admit explicitly before use. Serial build + unchanged historical query code."""
import argparse, hashlib, importlib.metadata, json, os, pathlib, resource, signal, subprocess, sys, time

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--prepared',type=pathlib.Path,required=True);p.add_argument('--admit-serial-native',action='store_true');a=p.parse_args();assert a.admit_serial_native,'root admission required';w=a.prepared.resolve();receipt=w/'ADMITTED_RUN';receipt.mkdir(exist_ok=False)
 frozen=json.loads((w/'PREPARED.json').read_text())
 for path,r in frozen['sourceFiles'].items():assert digest(w/path)==r['sha256'],path
 runtime={'python':sys.version,'pythonExecutable':sys.executable,'numpyDistribution':importlib.metadata.version('numpy'),'historicalRuntimeEquality':False}
 (receipt/'RUNTIME.json').write_text(json.dumps(runtime,indent=2)+'\n')
 env=dict(os.environ,OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
 def bounds():
  resource.setrlimit(resource.RLIMIT_CPU,(120,120));resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_FSIZE,(16*1024**2,16*1024**2))
 def run(name,cmd):
  start=time.monotonic()
  with (receipt/(name+'.stdout')).open('xb') as out,(receipt/(name+'.stderr')).open('xb') as err:
   proc=subprocess.Popen(cmd,cwd=w,env=env,stdout=out,stderr=err,preexec_fn=bounds,start_new_session=True)
   timed=False
   try:rc=proc.wait(timeout=180)
   except subprocess.TimeoutExpired:
    timed=True;os.killpg(proc.pid,signal.SIGKILL);rc=proc.wait()
  result={'command':cmd,'returncode':rc,'wallSeconds':time.monotonic()-start,'timeout':timed,'perProcessAddressSpaceBytes':1024**3,'perProcessCPUSeconds':120,'aggregateKernelMemoryContainment':False}
  (receipt/(name+'.json')).write_text(json.dumps(result,indent=2)+'\n')
  assert rc==0 and not timed,name+' failed; preserved, not retried'
 run('BUILD',json.loads((w/'BUILD_COMMAND.json').read_text()))
 binary=w/'blind-tabletop-exclusion-planner-66/libblind_detour.so'
 (receipt/'BUILD_OUTPUT.json').write_text(json.dumps({'sha256':digest(binary),'bytes':binary.stat().st_size,'rebuiltNotBundled':True},indent=2)+'\n')
 run('QUERIES',[sys.executable,str(w/'blind-coffee-native-topology/run.py')])
 assert sum(p.stat().st_size for p in (w/'blind-coffee-native-topology').rglob('*') if p.is_file()) <= 2*1024**2, 'historical 2MiB query-folder output cap exceeded'
 actual=json.loads((w/'blind-coffee-native-topology/RESULT.json').read_text());old=json.loads((w/'expected/blind-coffee-native-topology/RESULT.json').read_text());nf=json.loads((w/'blind-coffee-native-topology/FROZEN.json').read_text());of=json.loads((w/'expected/blind-coffee-native-topology/FROZEN.json').read_text())
 assert nf['requestedEndpoints']==of['requestedEndpoints'] and nf['config']==of['config']
 queries=actual['queries'];assert len(queries)==72 and len({(q['start'],q['goal']) for q in queries})==72
 stable={k:actual[k]==old[k] for k in ['endpoints','queries','meshCounts','nativeMarkedExclusionSpans']}
 result={'fullSavedResultsExactlyEqual':all(stable.values()),'comparisonByField':stable,'summary':actual['summary'],'replayedFrozen72Pairs':True,'movementEpisodes':0,'physicalAuthority':False,'runtimeEqualityToHistoricalNotEstablished':True}
 (receipt/'COMPARISON.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));assert all(stable.values()),'result difference retained; no retuning'
if __name__=='__main__':main()
