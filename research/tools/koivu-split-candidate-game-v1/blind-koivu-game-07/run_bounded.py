"""Bounded local game launcher only; no geometry authority in this wrapper.

CONFIG.json: schemaVersion=1, protocol={path,sha256}, sources=[{path,sha256}],
inputs=[{path,sha256,modes:[game]}]. Optional bytes checks length.
Pin run_game.py and this wrapper in sources. Large-mesh entries must use only
modes:[game]; no other modes are allowed. Paths are absolute or
relative to CONFIG's directory; optional $WORKSPACE/ requires explicit absolute
WORKSPACE. No installs/downloads. Partial evidence is preserved on every failure.
"""
from pathlib import Path
import argparse,ctypes,hashlib,json,math,os,resource,shutil,signal,stat,subprocess,sys,time
ROOT=Path(__file__).resolve().parent
CAP=64*1024**2;RESERVE=768*1024**2;RSS=3*1024**3;RECEIPT_ALLOWANCE=1024**2
BUDGETS={'game':(1800.,2700.)}
MAX_FILES=10000;CHUNK=1024**2

def current_tree_usage(rootpid):
 """Reviewed stage-03 pattern: live RSS and live+waited-descendant CPU.
 This is a sampled Linux watchdog, not a hard cgroup, and has process-exit races.
 """
 entries={};page=os.sysconf('SC_PAGE_SIZE');hz=os.sysconf('SC_CLK_TCK')
 for p in Path('/proc').iterdir():
  if not p.name.isdigit():continue
  try:
   fields=(p/'stat').read_text().rsplit(')',1)[1].split()
   entries[int(p.name)]=(int(fields[1]),int(fields[21])*page,sum(int(fields[i]) for i in (11,12,13,14))/hz)
  except (OSError,ValueError,IndexError):continue
 if rootpid not in entries:raise RuntimeError('own process resource counters unavailable')
 selected={rootpid}
 while True:
  new={pid for pid,(ppid,_,_) in entries.items() if ppid in selected}
  if new<=selected:break
  selected|=new
 return sum(entries[p][1] for p in selected),sum(entries[p][2] for p in selected)

def output_bytes(path):
 total=0;count=0
 if not path.exists():return 0
 for root,dirs,files in os.walk(path,followlinks=False):
  for name in dirs:
   if (Path(root)/name).is_symlink():raise RuntimeError('output directory symlink rejected')
  for name in files:
   s=(Path(root)/name).lstat();count+=1
   if not stat.S_ISREG(s.st_mode):raise RuntimeError('output special file/symlink rejected')
   if count>MAX_FILES:raise RuntimeError('output file-count cap')
   total+=s.st_size
 return total

class Bounds:
 def __init__(self,mode,output):
  self.cpu_cap,self.wall_cap=BUDGETS[mode];self.output=output
  self.started=time.monotonic();self.cpu_start=current_tree_usage(os.getpid())[1]
  self.peak_rss=0;self.last_cpu=0.;self.peak_output=0;self.current_rss=0
  self.mode=mode;self.phase='source-input-verification-before';self.last_heartbeat=-math.inf;self.heartbeat_sequence=0
  self.heartbeat_path=output/'heartbeat.jsonl'
  with self.heartbeat_path.open('xb'):pass
 def sample(self):
  rss,cpu=current_tree_usage(os.getpid());self.current_rss=rss;self.peak_rss=max(self.peak_rss,rss)
  self.last_cpu=max(self.last_cpu,cpu-self.cpu_start);n=output_bytes(self.output);self.peak_output=max(self.peak_output,n)
  return n
 def heartbeat(self,n,free):
  now=time.monotonic()
  if now-self.last_heartbeat<2.:return
  row={'sequence':self.heartbeat_sequence,'mode':self.mode,'driverPhase':self.phase,
   'elapsedWallSeconds':now-self.started,'sampledTreeCPUSeconds':self.last_cpu,
   'sampledCurrentTreeRSSBytes':self.current_rss,'sampledPeakTreeRSSBytes':self.peak_rss,
   'outputBytesBeforeHeartbeat':n,'freeBytesBeforeHeartbeat':free,
   'sampledWatchdogOnly':True,'gameResultAuthority':False}
  data=(json.dumps(row,sort_keys=True,allow_nan=False)+'\n').encode()
  if n+len(data)>CAP:raise RuntimeError('heartbeat would exceed output cap')
  if free<RESERVE+len(data):raise RuntimeError('heartbeat would violate free reserve')
  fd=os.open(self.heartbeat_path,os.O_WRONLY|os.O_APPEND|os.O_NOFOLLOW)
  with os.fdopen(fd,'ab') as output:
   if not stat.S_ISREG(os.fstat(output.fileno()).st_mode):raise RuntimeError('heartbeat is not a regular file')
   output.write(data);output.flush()
  self.last_heartbeat=now;self.heartbeat_sequence+=1
 def check(self):
  n=self.sample();free=shutil.disk_usage(ROOT).free
  self.heartbeat(n,free)
  if self.peak_rss>RSS:raise RuntimeError('sampled process-tree RSS exceeded 3 GiB')
  if time.monotonic()-self.started>self.wall_cap:raise RuntimeError('total wall cap')
  if self.last_cpu>self.cpu_cap:raise RuntimeError('total sampled process-tree CPU cap')
  if n>CAP-RECEIPT_ALLOWANCE:raise RuntimeError('aggregate output budget minus receipt allowance exceeded')
  if free<RESERVE:raise RuntimeError(f'free reserve violated: available={free}, required={RESERVE} bytes')
 def resources(self):
  try:self.sample()
  except Exception:pass
  return {'wallSeconds':time.monotonic()-self.started,'sampledTreeCPUSeconds':self.last_cpu,'sampledPeakTreeRSSBytes':self.peak_rss,
   'peakOutputBytesBeforeReceipt':self.peak_output,'peakChildRSSKiB':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss}

def read_json(path):
 with path.open('rb') as f:data=f.read(RECEIPT_ALLOWANCE+1)
 if len(data)>RECEIPT_ALLOWANCE:raise ValueError('CONFIG JSON byte cap')
 return json.loads(data),hashlib.sha256(data).hexdigest()

def configured_path(value):
 if not isinstance(value,str) or not value:raise ValueError('pin path must be nonempty string')
 if value.startswith('$WORKSPACE/'):
  base=os.environ.get('WORKSPACE')
  if not base or not Path(base).is_absolute():raise ValueError('explicit absolute WORKSPACE required')
  value=str(Path(base)/value[len('$WORKSPACE/'):])
 if '$' in value:raise ValueError('unexpanded pin path variable')
 p=Path(value)
 return p if p.is_absolute() else ROOT/p

def verify_pin(entry,bounds):
 path=configured_path(entry['path']);expected=entry['sha256']
 if not isinstance(expected,str) or len(expected)!=64 or any(c not in '0123456789abcdef' for c in expected):raise ValueError('invalid SHA-256 pin')
 fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW)
 with os.fdopen(fd,'rb') as source:
  before=os.fstat(source.fileno())
  if not stat.S_ISREG(before.st_mode):raise ValueError('pin must name regular file')
  if 'bytes' in entry and before.st_size!=entry['bytes']:raise ValueError('pin byte count mismatch: '+str(path))
  h=hashlib.sha256();count=0;last_check=time.monotonic()
  while True:
   b=source.read(CHUNK)
   if not b:break
   h.update(b);count+=len(b)
   if time.monotonic()-last_check>.1:bounds.check();last_check=time.monotonic()
  after=os.fstat(source.fileno());at_path=os.stat(path,follow_symlinks=False)
  def identity(s):return (s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
  if identity(before)!=identity(after) or identity(before)!=identity(at_path):raise ValueError('pin file changed during hash: '+str(path))
  if h.hexdigest()!=expected or count!=before.st_size:raise ValueError('source/input hash mismatch: '+str(path))
 bounds.check()
 return {'path':str(path),'bytes':count,'sha256':expected}

def write_json(path,value):
 b=(json.dumps(value,indent=2,sort_keys=True,allow_nan=False)+'\n').encode()
 if len(b)>RECEIPT_ALLOWANCE:raise ValueError('receipt byte cap')
 if output_bytes(path.parent)+len(b)>CAP:raise RuntimeError('receipt would exceed total output cap')
 with path.open('xb') as f:f.write(b);f.flush();os.fsync(f.fileno())

def publish_no_replace(source,dest):
 libc=ctypes.CDLL(None,use_errno=True);rename=getattr(libc,'renameat2',None)
 if rename is None:raise RuntimeError('no atomic no-replace rename; partial retained')
 rename.argtypes=[ctypes.c_int,ctypes.c_char_p,ctypes.c_int,ctypes.c_char_p,ctypes.c_uint];rename.restype=ctypes.c_int
 if rename(-100,os.fsencode(source),-100,os.fsencode(dest),1)!=0:
  code=ctypes.get_errno();raise OSError(code,os.strerror(code))

def kill_group(process):
 if process is None:return
 try:os.killpg(process.pid,signal.SIGKILL)
 except ProcessLookupError:pass
 process.wait()

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--mode',required=True,choices=sorted(BUDGETS));args=parser.parse_args()
 stage=ROOT/('run-'+args.mode+'.partial');final=ROOT/('run-'+args.mode)
 if stage.exists() or stage.is_symlink() or final.exists() or final.is_symlink():raise RuntimeError('refuse existing output or failed partial overwrite')
 if shutil.disk_usage(ROOT).free<RESERVE+CAP:raise RuntimeError(f'preflight needs at least {RESERVE+CAP} free bytes including reserve and maximum new outputs')
 stage.mkdir(mode=0o700);bounds=Bounds(args.mode,stage);child=None;verified=[];after_ok=False;command=[];config_sha=None
 def timeout(signum,frame):raise TimeoutError('hard wall alarm expired')
 signal.signal(signal.SIGALRM,timeout);signal.alarm(math.ceil(bounds.wall_cap))
 try:
  bounds.check();config_path=ROOT/'CONFIG.json';config,config_sha=read_json(config_path)
  if config.get('schemaVersion')!=1:raise ValueError('CONFIG schemaVersion must be 1')
  sources=config.get('sources');inputs=config.get('inputs')
  if not isinstance(sources,list) or not isinstance(inputs,list) or not isinstance(config.get('protocol'),dict):raise ValueError('CONFIG requires sources, inputs and protocol pins')
  source_paths={configured_path(e['path']).resolve() for e in sources}
  if not {Path(__file__).resolve(),(ROOT/'run_game.py').resolve()}<=source_paths:raise ValueError('both runner and game source must be explicitly pinned')
  selected=[config['protocol']]+sources
  skipped=[]
  for e in inputs:
   modes=e.get('modes')
   if not isinstance(modes,list) or not modes or not set(modes)<=set(BUDGETS):raise ValueError('every data pin requires explicit allowed modes')
   if e.get('largeMesh') is True and modes!=['game']:raise ValueError('largeMesh may be hashed only in game mode')
   if args.mode in modes:selected.append(e)
   else:skipped.append({'path':e['path'],'modes':modes,'hashedInThisRun':False})
  selected.append({'path':str(config_path),'sha256':config_sha})
  for entry in selected:verified.append(verify_pin(entry,bounds))
  write_json(stage/'SOURCE_DATA_PINS.json',{'mode':args.mode,'configSHA256':config_sha,'verifiedBefore':verified,'modeExcludedInputs':skipped})
  env=dict(os.environ)
  for key in ['LD_PRELOAD','LD_AUDIT','DISPLAY','WAYLAND_DISPLAY']:env.pop(key,None)
  single={'OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1','NUMEXPR_NUM_THREADS':'1','VECLIB_MAXIMUM_THREADS':'1','BLIS_NUM_THREADS':'1',
   'VTK_SMP_MAX_THREADS':'1','VTK_SMP_IMPLEMENTATION_TYPE':'Sequential','CUDA_VISIBLE_DEVICES':'','HIP_VISIBLE_DEVICES':'','PYTHONDONTWRITEBYTECODE':'1'}
  env.update(single)
  for name in ['tmp','cache']: (stage/name).mkdir()
  env.update(TMPDIR=str(stage/'tmp'),XDG_CACHE_HOME=str(stage/'cache'),MPLCONFIGDIR=str(stage/'cache/matplotlib'))
  command=[sys.executable,str(ROOT/'run_game.py'),'--mode',args.mode,'--output',str(stage/'game')]
  bounds.check();remaining=max(1,int(math.floor(bounds.cpu_cap-bounds.last_cpu)))
  def child_limits():
   resource.setrlimit(resource.RLIMIT_CPU,(remaining,remaining))
   resource.setrlimit(resource.RLIMIT_FSIZE,(CAP,CAP))
   # No low RLIMIT_AS: VTK's virtual allocations need not equal physical RSS.
  with (stage/'stdout.log').open('xb') as out,(stage/'stderr.log').open('xb') as err:
   child=subprocess.Popen(command,cwd=ROOT,stdout=out,stderr=err,env=env,start_new_session=True,preexec_fn=child_limits)
   bounds.phase='child-running'
   while child.poll() is None:bounds.check();time.sleep(.04)
   bounds.check();exit_code=child.returncode;kill_group(child)
  bounds.phase='source-input-verification-after'
  # Failures may exhaust the remaining budget; in that case no post-hash claim is made.
  for entry in selected:verify_pin(entry,bounds)
  after_ok=True
  if exit_code!=0:raise RuntimeError(f'game exited {exit_code}; original logs retained')
  receipt={'status':'child completed within observed limits; game conclusions belong to its own report','mode':args.mode,'command':command,'exitCode':exit_code,
   'configSHA256':config_sha,'sourceAndInputHashesVerifiedBeforeAndAfter':True,'pins':verified,'modeExcludedInputs':skipped,
   'bounds':{'wallSeconds':bounds.wall_cap,'cpuSeconds':bounds.cpu_cap,'sampledTreeRSSBytes':RSS,'aggregateOutputBytes':CAP,'reservedFreeBytes':RESERVE,
    'childRLIMIT_AS':None,'childRLIMIT_CPUSeconds':remaining,'childRLIMIT_FSIZEBytes':CAP},
   'resources':bounds.resources(),'environmentOverrides':single,
   'heartbeat':{'file':'heartbeat.jsonl','nominalWallIntervalSeconds':2,'appendOnly':True,'timing':'Written by sampled watchdog checks, not a separate real-time timer; no game/geometry authority'},
   'enforcementLimits':'Sampled /proc tree RSS/CPU and aggregate file sizes, plus child per-process CPU and per-file size limits; NOT a cgroup, sandbox or hard aggregate quota. Sampling may overshoot and miss short-lived process peaks.',
   'wrapperGeometryOrNavigationAuthority':False,'installOrDownloadPerformed':False}
  write_json(stage/'RUN_RECEIPT.json',receipt);bounds.check();publish_no_replace(stage,final);signal.alarm(0)
  print(json.dumps({'mode':args.mode,'status':'completed','output':final.name,'resources':receipt['resources']},indent=2))
 except BaseException as error:
  kill_group(child);signal.alarm(0)
  failure={'status':'failed; partial evidence retained','mode':args.mode,'error':repr(error),'command':command,'childExitCode':None if child is None else child.returncode,
   'configSHA256':config_sha,'verifiedBefore':verified,'postHashVerificationCompleted':after_ok,'resources':bounds.resources(),
   'noSuccessClaim':True,'childProcessGroupSIGKILLOnFailure':child is not None,'hardCgroupLimit':False}
  try:write_json(stage/'FAILURE_RECEIPT.json',failure)
  except Exception:print(json.dumps(failure,indent=2),file=sys.stderr)
  raise
if __name__=='__main__':main()
