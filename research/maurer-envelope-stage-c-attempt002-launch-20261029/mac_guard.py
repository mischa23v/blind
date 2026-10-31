#!/usr/bin/env python3
"""macOS-only serial trusted-tool guard. Source prepared, native behavior unrun.

Observed limits are sampled (50 ms target, ps timeout 1 s), not kernel cgroups.
CPU includes exited-child accounting; no claim of CPU affinity or hermetic SDK.
No installs, network, automatic retry, cap expansion, or output deletion.
"""
import json,math,os,pathlib,re,resource,signal,stat,subprocess,sys,time

class GuardFailure(RuntimeError):
    def __init__(self,message,metadata=None):
        super().__init__(message);self.safe_metadata=metadata or {}

def failure_event(error,stage,index=None):
    # Fixed scalar metadata only: never copy exception text, paths, argv or env.
    meta=getattr(error,'safe_metadata',{})
    system_error=error if isinstance(error,OSError) else error.__cause__
    errno=system_error.errno if isinstance(system_error,OSError) else None
    return {'reasonCode':controlled_reason(error),'stage':stage,'guardCommandIndex':index,
      'metadata':{'outputScope':meta.get('outputScope') if meta.get('outputScope') in {'module-cache','owned-output'} else None,
      'entryKind':meta.get('entryKind') if meta.get('entryKind') in {'file','directory','symlink','other','unknown'} else None,
      'errno':errno if type(errno) is int and 0<=errno<=4095 else None}}

def remember_failure(owner,error,stage,secondary=False):
    rows=getattr(owner,'records',[]);event=failure_event(error,stage,rows[-1]['index'] if rows else None)
    if getattr(owner,'firstFailure',None) is None:owner.firstFailure=event
    elif secondary:
        if not hasattr(owner,'secondaryFailures'):owner.secondaryFailures={}
        owner.secondaryFailures.setdefault(stage,event)
    return owner.firstFailure


def safe_command_label(label):
    return isinstance(label,str) and re.fullmatch(r'[A-Za-z0-9-]{1,80}',label) is not None

def controlled_reason(error):
    message=str(error)
    prefixes=[('invalid command label','COMMAND_LABEL_REFUSED'),('nonzero command:','COMMAND_EXIT_NONZERO'),
      ('aggregate CPU cap','CPU_LIMIT'),('aggregate wall cap','WALL_LIMIT'),('signal/deadline 14','WALL_LIMIT'),
      ('observed process-family RSS cap','RSS_LIMIT'),('observed aggregate output cap','OUTPUT_LIMIT'),
      ('process-family observation unavailable','PROCESS_OBSERVATION_UNAVAILABLE'),('command left observed live descendants','DESCENDANTS_REMAIN'),
      ('child retirement not confirmed','RETIREMENT_UNCONFIRMED'),('command text cap','COMMAND_TEXT_LIMIT'),
      ('copied build input changed','GENERATED_SOURCE_CHANGED'),('selected tool alias changed','TOOL_SELECTION_CHANGED'),
      ('tool executable changed','TOOL_EXECUTABLE_CHANGED'),('runtime source/input mismatch','SOURCE_PIN_MISMATCH'),
      ('manifest pin mismatch','SOURCE_PIN_MISMATCH'),('result input digest','RESULT_INPUT_DIGEST_MISMATCH'),
      ('route acceptance false:','ROUTE_ACCEPTANCE_FAILED'),('result success status','ROUTE_ACCEPTANCE_FAILED'),
      ('terminal export reserve unavailable','EXPORT_RESERVE_UNAVAILABLE'),('terminal aggregate output cap','OUTPUT_LIMIT'),
      ('public aggregate encoded-byte cap','PUBLIC_EXPORT_LIMIT'),
      ('unexpected ps stderr','PS_STDERR'),('invalid ps CPU field','PS_CPU_FORMAT'),
      ('invalid ps CPU range','PS_CPU_RANGE'),('nonfinite CPU','PS_CPU_NONFINITE'),
      ('ps output cap','PS_TEXT_LIMIT'),('ps columns changed','PS_COLUMNS'),
      ('invalid ps identity','PS_IDENTITY'),('ps row cap','PS_ROW_LIMIT'),
      ('guard missing from ps','PS_GUARD_MISSING'),('process-family traversal failed','PS_FAMILY'),
      ('output file-count cap','OUTPUT_FILE_COUNT_LIMIT'),('output entry-count cap','OUTPUT_ENTRY_COUNT_LIMIT'),
      ('output directory depth cap','OUTPUT_DEPTH_LIMIT'),('output symlink scope','OUTPUT_LINK_SCOPE'),
      ('output symlink name','OUTPUT_LINK_NAME'),('output symlink target escape','OUTPUT_LINK_ESCAPE'),
      ('output symlink target type','OUTPUT_LINK_TARGET_TYPE'),('output symlink changed','OUTPUT_LINK_CHANGED'),
      ('output unsupported entry','OUTPUT_ENTRY_TYPE'),('output scan unavailable','OUTPUT_SCAN_UNAVAILABLE'),
      ('output entry disappeared','OUTPUT_ENTRY_DISAPPEARED'),('output root not directory','OUTPUT_ROOT_TYPE'),
      ('terminal aggregate size did not stabilize','EXPORT_SIZE_UNSTABLE'),
      ('owned output changed during terminal export','EXPORT_OUTPUT_CHANGED')]
    for prefix,code in prefixes:
        if message.startswith(prefix):return code
    if message.startswith('signal/deadline '):return 'INTERRUPTED'
    if isinstance(error,subprocess.TimeoutExpired):return 'SUBPROCESS_TIMEOUT'
    if isinstance(error,json.JSONDecodeError):return 'JSON_DECODE_FAILED'
    if isinstance(error,OSError):return 'FILESYSTEM_ERROR'
    return 'VALIDATION_REFUSED' if isinstance(error,GuardFailure) else 'LAUNCHER_EXCEPTION'

def child_environment(out,parent):
    # Never forward arbitrary compiler/include/linker/loader or SDK overrides.
    # GitHub's tracking identity is deliberately retained for outer-job cleanup.
    home=str(pathlib.Path(out)/'home')
    env={'PATH':'/usr/bin:/bin:/usr/sbin:/sbin','HOME':home,'CFFIXED_USER_HOME':home,
      'LC_ALL':'C','LANG':'C','OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1',
      'VECLIB_MAXIMUM_THREADS':'1','TMPDIR':str(pathlib.Path(out)/'tmp'),
      'CLANG_MODULE_CACHE_PATH':str(pathlib.Path(out)/'module-cache'),
      'SWIFT_MODULECACHE_PATH':str(pathlib.Path(out)/'module-cache'),
      'XDG_CACHE_HOME':str(pathlib.Path(out)/'cache'),'XDG_CONFIG_HOME':str(pathlib.Path(out)/'config'),
      'GIT_CONFIG_NOSYSTEM':'1','GIT_CONFIG_GLOBAL':'/dev/null'}
    if parent.get('RUNNER_TRACKING_ID'):env['RUNNER_TRACKING_ID']=parent['RUNNER_TRACKING_ID']
    return env

def parse_cpu(value):
    if not re.fullmatch(r'(?:\d+-)?\d+:\d{2}(?::\d{2})?(?:\.\d+)?',value):
        raise GuardFailure('invalid ps CPU field')
    days=0
    if '-' in value:
        d,value=value.split('-',1);days=int(d)
    parts=[float(x) for x in value.split(':')]
    if len(parts)==2:
        if days or parts[-1]>=60:raise GuardFailure('invalid ps CPU range')
        result=parts[0]*60+parts[1]
    else:
        if parts[-1]>=60 or parts[-2]>=60:raise GuardFailure('invalid ps CPU range')
        result=days*86400+parts[0]*3600+parts[1]*60+parts[2]
    if not math.isfinite(result):raise GuardFailure('nonfinite CPU')
    return result

def parse_ps(data):
    if len(data)>1048576:raise GuardFailure('ps output cap')
    rows={}
    try:lines=data.decode('ascii').splitlines()
    except UnicodeDecodeError:raise GuardFailure('ps columns changed')
    for line in lines:
        if not line.strip():continue
        fields=line.split()
        if len(fields)!=5:raise GuardFailure('ps columns changed')
        try:pid,ppid,pgid=(int(x) for x in fields[:3]);rss=int(fields[4])*1024
        except ValueError:raise GuardFailure('invalid ps identity')
        if pid<0 or ppid<0 or pgid<0 or rss<0 or pid in rows:raise GuardFailure('invalid ps identity')
        rows[pid]={'pid':pid,'ppid':ppid,'pgid':pgid,'cpu':parse_cpu(fields[3]),'rss':rss}
    if len(rows)>16384:raise GuardFailure('ps row cap')
    return rows

def family(rows,owner,groups):
    selected={owner}|{pid for pid,r in rows.items() if r['pgid'] in groups}
    for _ in range(len(rows)+1):
        more={pid for pid,r in rows.items() if r['ppid'] in selected}
        expanded=selected|more
        if expanded==selected:return {pid:rows[pid] for pid in selected if pid in rows}
        selected=expanded
    raise GuardFailure('process-family traversal failed')

def _output_snapshot(root, sampled=False):
    """No-follow owned-tree accounting; only LLVM file-lock links are admitted.

    The explicit compiler cache is output/module-cache. Links must be *.lock ->
    same-directory <same name>-<8 lowercase hex>, as LLVM createUniquePath emits.
    During active-tool sampling, ENOENT is a permitted enumeration/stat race;
    unknown entries, directory/chain links and escapes remain refusals. Count
    link inode bytes, not the target through the link. This is sampled accounting
    for trusted compilers, not containment of malicious filesystem writers.
    """
    root=pathlib.Path(root).absolute();total=files_seen=entries_seen=0;identity=[]
    def stamp(path,info):
        identity.append((str(path),info.st_dev,info.st_ino,info.st_mode,info.st_size,info.st_mtime_ns,info.st_ctime_ns))
    def fail(message,scope='owned-output',kind='unknown'):
        raise GuardFailure(message,{'outputScope':scope,'entryKind':kind})
    def scan_error(error):
        if sampled and isinstance(error,FileNotFoundError):return
        raise GuardFailure('output scan unavailable') from error
    try:
        root_info=root.lstat()
        if not stat.S_ISDIR(root_info.st_mode):fail('output root not directory')
        stamp('.',root_info)
        for directory,dirs,files,fd in os.fwalk(root,follow_symlinks=False,onerror=scan_error):
            relative=pathlib.Path(directory).relative_to(root)
            scope='module-cache' if relative.parts and relative.parts[0]=='module-cache' else 'owned-output'
            if len(relative.parts)>32:fail('output directory depth cap',scope,'directory')
            for name in dirs+files:
                entries_seen+=1
                if entries_seen>32768:fail('output entry-count cap',scope)
                try:info=os.stat(name,dir_fd=fd,follow_symlinks=False)
                except FileNotFoundError:
                    if sampled:continue
                    fail('output entry disappeared',scope)
                stamp(relative/name,info)
                mode=info.st_mode
                if stat.S_ISDIR(mode):continue
                files_seen+=1
                if files_seen>16384:fail('output file-count cap',scope,'file')
                if stat.S_ISREG(mode):total+=info.st_size;continue
                if not stat.S_ISLNK(mode):fail('output unsupported entry',scope,'other')
                if scope!='module-cache':fail('output symlink scope',scope,'symlink')
                if not name.endswith('.lock') or len(name)>255:fail('output symlink name',scope,'symlink')
                try:target=os.readlink(name,dir_fd=fd)
                except FileNotFoundError:
                    if sampled:continue
                    fail('output entry disappeared',scope,'symlink')
                # Lexical same-directory comparison: never resolve/traverse target.
                candidate=pathlib.Path(target)
                leaf=candidate.name
                if (len(target)>4096 or not re.fullmatch(re.escape(name)+r'-[0-9a-f]{8}',leaf)
                    or (candidate.is_absolute() and candidate.parent!=pathlib.Path(directory))
                    or (not candidate.is_absolute() and target!=leaf)):
                    fail('output symlink target escape',scope,'symlink')
                try:
                    target_info=os.stat(leaf,dir_fd=fd,follow_symlinks=False)
                    if not stat.S_ISREG(target_info.st_mode):fail('output symlink target type',scope,'symlink')
                except FileNotFoundError:pass # Permitted dangling same-directory file lock, never followed.
                try:after=os.stat(name,dir_fd=fd,follow_symlinks=False)
                except FileNotFoundError:
                    if sampled:continue
                    fail('output entry disappeared',scope,'symlink')
                if (after.st_dev,after.st_ino,after.st_mode,after.st_size)!=(info.st_dev,info.st_ino,info.st_mode,info.st_size):
                    fail('output symlink changed',scope,'symlink')
                total+=info.st_size
        after_root=root.lstat()
        if (after_root.st_dev,after_root.st_ino,after_root.st_mode)!=(root_info.st_dev,root_info.st_ino,root_info.st_mode):
            fail('owned output changed during terminal export')
    except OSError as error:raise GuardFailure('output scan unavailable') from error
    return total,tuple(sorted(identity))

def output_bytes(root, sampled=False):
    """Sample active tools once; otherwise require two identical strict snapshots.

    This is not atomic accounting: transient files between samples can be missed.
    ENOENT alone is tolerated while active, not permissions or malformed links.
    Terminal snapshots compare bounded metadata, not file-content hashes.
    """
    first=_output_snapshot(root,sampled)
    if not sampled and first!=_output_snapshot(root,False):
        raise GuardFailure('owned output changed during terminal export')
    return first[0]

class Guard:
    def __init__(self,out,cwd):
        self.out=pathlib.Path(out);self.cwd=pathlib.Path(cwd)
        self.started=time.monotonic();self.groups=set();self.active=None
        self.seen={};self.maximumCPU=0.;self.maximumRSS=0;self.maximumOutput=0
        self.samples=0;self.records=[];self.failure=None
        self.firstFailure=None;self.secondaryFailures={};self.lastValidSample=None
        self.cpuLimit=120;self.wallLimit=300;self.rssLimit=2147483648;self.outputLimit=134217728
        self.environment=child_environment(self.out,os.environ)
        for name in ['tmp','module-cache','home','cache','config']:(self.out/name).mkdir()
        for sig in [signal.SIGALRM,signal.SIGINT,signal.SIGTERM]:signal.signal(sig,self.interrupted)
        signal.setitimer(signal.ITIMER_REAL,self.wallLimit)
        # Caller observes immediately after assignment, so init failures are exportable.

    def interrupted(self,number,frame):
        error=GuardFailure('signal/deadline '+str(number));remember_failure(self,error,'interrupt')
        try:self.retire()
        except BaseException as cleanup:remember_failure(self,cleanup,'retirement',secondary=True)
        raise error

    def retire(self):
        for pg in self.groups:
            try:os.killpg(pg,signal.SIGKILL)
            except ProcessLookupError:pass
        # Compilers are trusted non-daemon tools. Any observed escaped descendants
        # are also retired; this is not containment against hostile daemonization.
        for pid,pgid in self.seen.items():
            try:
                if os.getpgid(pid)==pgid:os.kill(pid,signal.SIGKILL)
            except ProcessLookupError:pass
        if self.active is not None:
            try:self.active.wait(timeout=2)
            except subprocess.TimeoutExpired:raise GuardFailure('child retirement not confirmed')
            # Reaped child is no longer an active writer; keep groups for the
            # next observation to detect any surviving owned descendants.
            self.active=None

    def monitor(self):
        try:return self._observe()
        except BaseException as error:
            remember_failure(self,error,'guard-monitor');raise

    def _observe(self):
        try:
            snapshot=subprocess.run(['/bin/ps','-AS','-o','pid=,ppid=,pgid=,time=,rss='],
                stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=1,check=True,
                env={'PATH':'/usr/bin:/bin','LC_ALL':'C','LANG':'C'})
        except (OSError,subprocess.SubprocessError) as error:
            raise GuardFailure('process-family observation unavailable') from error
        if snapshot.stderr:raise GuardFailure('unexpected ps stderr')
        rows=parse_ps(snapshot.stdout)
        if os.getpid() not in rows or rows[os.getpid()]['rss']<=0:raise GuardFailure('guard missing from ps')
        selected=family(rows,os.getpid(),self.groups)
        # Exclude the guard's own group (including the short-lived ps monitor).
        # Retain current observations only, not exited/recyclable historical PIDs.
        self.seen={pid:r['pgid'] for pid,r in selected.items() if r['pgid']!=os.getpgrp()}
        own=resource.getrusage(resource.RUSAGE_SELF);kids=resource.getrusage(resource.RUSAGE_CHILDREN)
        # ps -S rolls exited children into parents. A changing process snapshot
        # can conservatively double-count a child transition; keep the maximum.
        totalCPU=max(own.ru_utime+own.ru_stime+kids.ru_utime+kids.ru_stime,
                     sum(x['cpu'] for x in selected.values()))
        rss=max(sum(x['rss'] for x in selected.values()),own.ru_maxrss,kids.ru_maxrss)
        self.maximumCPU=max(self.maximumCPU,totalCPU);self.maximumRSS=max(self.maximumRSS,rss)
        if self.active is None and self.seen:raise GuardFailure('command left observed live descendants')
        size=output_bytes(self.out,sampled=self.active is not None)
        self.maximumOutput=max(self.maximumOutput,size);self.samples+=1
        self.lastValidSample={'sampleIndex':self.samples,'wallSeconds':time.monotonic()-self.started,
          'observedAggregateCPUSeconds':self.maximumCPU,'observedPeakRSSBytes':self.maximumRSS,
          'observedPeakOutputBytes':self.maximumOutput,'completeTerminalObservation':False,'capComplianceEstablished':False}
        if time.monotonic()-self.started>=self.wallLimit:raise GuardFailure('aggregate wall cap')
        if self.maximumCPU>self.cpuLimit:raise GuardFailure('aggregate CPU cap')
        if self.maximumRSS>self.rssLimit:raise GuardFailure('observed process-family RSS cap')
        if self.maximumOutput>self.outputLimit:raise GuardFailure('observed aggregate output cap')
        return selected

    def save(self):
        record={'schema':1,'wallSeconds':time.monotonic()-self.started,'observedAggregateCPUSeconds':self.maximumCPU,
          'observedPeakFamilyRSSBytes':self.maximumRSS,'observedPeakOutputBytes':self.maximumOutput,
          'samples':self.samples,'pollTargetSeconds':0.05,'psTimeoutSeconds':1,
          'limits':{'CPUSeconds':self.cpuLimit,'wallSeconds':self.wallLimit,'observedRSSBytes':self.rssLimit,'observedOutputBytes':self.outputLimit},
          'commands':self.records,'failure':self.failure,'firstFailure':self.firstFailure,
          'secondaryFailures':self.secondaryFailures,'lastValidSample':self.lastValidSample,'physicalAuthority':False,
          'limitations':'Polling can overshoot before kill. RSS/output are observed peaks, not a kernel quota. Trusted installed tools; not hostile daemon containment. No CPU affinity guarantee.'}
        target=self.out/'RESOURCE_RECEIPT.private.json';temporary=self.out/'RESOURCE_RECEIPT.private.tmp'
        temporary.write_text(json.dumps(record,indent=2)+'\n');temporary.replace(target)

    def run(self,args,label,maximumText=1048576):
        started=time.monotonic()
        row={'index':len(self.records)+1,'label':label,'argv':args,'exitCode':None,
             'processStarted':False,'processCompleted':False,'reasonCode':None}
        self.records.append(row);stdout=stderr=process=None
        try:
            if not safe_command_label(label):raise GuardFailure('invalid command label')
            self.monitor()
            stdout=self.out/(label+'.stdout.private.txt');stderr=self.out/(label+'.stderr.private.txt')
            remaining=max(1,math.ceil(self.cpuLimit-self.maximumCPU))
            def child_limits():
                resource.setrlimit(resource.RLIMIT_CPU,(remaining,remaining))
                resource.setrlimit(resource.RLIMIT_FSIZE,(self.outputLimit,self.outputLimit))
                resource.setrlimit(resource.RLIMIT_CORE,(0,0))
            with stdout.open('xb') as out,stderr.open('xb') as err:
                process=subprocess.Popen(args,cwd=self.cwd,stdout=out,stderr=err,
                    start_new_session=True,preexec_fn=child_limits,env=self.environment)
                row['processStarted']=True
                self.active=process;self.groups.add(process.pid)
                while True:
                    self.monitor()
                    code=process.poll()
                    if code is not None:break
                    time.sleep(0.05)
                row['exitCode']=code;row['processCompleted']=True
                if code!=0:remember_failure(self,GuardFailure('nonzero command: '+label),'guard-command')
                try:
                    selected=self.monitor()
                    if self.seen:raise GuardFailure('command left observed live descendants')
                except BaseException as cleanup:
                    remember_failure(self,cleanup,'command-finalization',secondary=True);raise
                self.groups.discard(process.pid);self.active=None
                # Do not later signal a recycled PID from a completed command.
                self.seen={}
            if code!=0:raise GuardFailure('nonzero command: '+label)
            if stdout.stat().st_size>maximumText:raise GuardFailure('command text cap')
            return stdout.read_text()
        except BaseException as error:
            remember_failure(self,error,'guard-command')
            row['reasonCode']=controlled_reason(error)
            self.failure=type(error).__name__+': '+str(error)[:300]
            try:self.retire()
            except BaseException as cleanup:remember_failure(self,cleanup,'retirement',secondary=True)
            if process is not None:
                row['exitCode']=process.returncode;row['processCompleted']=process.returncode is not None
            raise
        finally:
            already_failing=sys.exc_info()[0] is not None
            row['wallSeconds']=time.monotonic()-started
            try:
                for name,path in [('stdoutBytes',stdout),('stderrBytes',stderr)]:
                    if path is not None and path.exists():row[name]=path.stat().st_size
                self.save()
            except BaseException as cleanup:
                remember_failure(self,cleanup,'command-finalization',secondary=True)
                if not already_failing:raise

    def finish(self):
        if self.active is not None:raise GuardFailure('child retirement not confirmed')
        self.monitor();self.save();self.monitor()
