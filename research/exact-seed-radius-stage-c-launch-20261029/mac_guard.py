#!/usr/bin/env python3
"""macOS-only serial trusted-tool guard. Source prepared, native behavior unrun.

Observed limits are sampled (50 ms target, ps timeout 1 s), not kernel cgroups.
CPU includes exited-child accounting; no claim of CPU affinity or hermetic SDK.
No installs, network, automatic retry, cap expansion, or output deletion.
"""
import json,math,os,pathlib,re,resource,signal,subprocess,time

class GuardFailure(RuntimeError):pass

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
    for line in data.decode('ascii').splitlines():
        if not line.strip():continue
        fields=line.split()
        if len(fields)!=5:raise GuardFailure('ps columns changed')
        pid,ppid,pgid=(int(x) for x in fields[:3]);rss=int(fields[4])*1024
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

def output_bytes(root):
    total=count=0
    for directory,dirs,files in os.walk(root,followlinks=False):
        for name in dirs+files:
            path=pathlib.Path(directory)/name
            if path.is_symlink():raise GuardFailure('symlink in isolated output')
        for name in files:
            total+=(pathlib.Path(directory)/name).stat().st_size;count+=1
            if count>16384:raise GuardFailure('output file-count cap')
    return total

class Guard:
    def __init__(self,out,cwd):
        self.out=pathlib.Path(out);self.cwd=pathlib.Path(cwd)
        self.started=time.monotonic();self.groups=set();self.active=None
        self.seen={};self.maximumCPU=0.;self.maximumRSS=0;self.maximumOutput=0
        self.samples=0;self.records=[];self.failure=None
        self.cpuLimit=120;self.wallLimit=300;self.rssLimit=2147483648;self.outputLimit=134217728
        self.environment=child_environment(self.out,os.environ)
        for name in ['tmp','module-cache','home','cache','config']:(self.out/name).mkdir()
        for sig in [signal.SIGALRM,signal.SIGINT,signal.SIGTERM]:signal.signal(sig,self.interrupted)
        signal.setitimer(signal.ITIMER_REAL,self.wallLimit)
        self.monitor() # Fail before compiler launch if process inspection is unavailable.

    def interrupted(self,number,frame):
        self.retire();raise GuardFailure('signal/deadline '+str(number))

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

    def monitor(self):
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
        size=output_bytes(self.out)
        self.maximumCPU=max(self.maximumCPU,totalCPU);self.maximumRSS=max(self.maximumRSS,rss)
        self.maximumOutput=max(self.maximumOutput,size);self.samples+=1
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
          'commands':self.records,'failure':self.failure,'physicalAuthority':False,
          'limitations':'Polling can overshoot before kill. RSS/output are observed peaks, not a kernel quota. Trusted installed tools; not hostile daemon containment. No CPU affinity guarantee.'}
        target=self.out/'RESOURCE_RECEIPT.private.json';temporary=self.out/'RESOURCE_RECEIPT.private.tmp'
        temporary.write_text(json.dumps(record,indent=2)+'\n');temporary.replace(target)

    def run(self,args,label,maximumText=1048576):
        if not re.fullmatch(r'[a-z0-9-]{1,80}',label):raise GuardFailure('invalid command label')
        self.monitor();started=time.monotonic()
        row={'label':label,'argv':args,'exitCode':None};self.records.append(row)
        stdout=self.out/(label+'.stdout.private.txt');stderr=self.out/(label+'.stderr.private.txt')
        remaining=max(1,math.ceil(self.cpuLimit-self.maximumCPU))
        def child_limits():
            resource.setrlimit(resource.RLIMIT_CPU,(remaining,remaining))
            resource.setrlimit(resource.RLIMIT_FSIZE,(self.outputLimit,self.outputLimit))
            resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        process=None
        try:
            with stdout.open('xb') as out,stderr.open('xb') as err:
                process=subprocess.Popen(args,cwd=self.cwd,stdout=out,stderr=err,
                    start_new_session=True,preexec_fn=child_limits,env=self.environment)
                self.active=process;self.groups.add(process.pid)
                while True:
                    self.monitor()
                    code=process.poll()
                    if code is not None:break
                    time.sleep(0.05)
                row['exitCode']=code
                selected=self.monitor()
                if self.seen:
                    raise GuardFailure('command left observed live descendants')
                self.groups.discard(process.pid);self.active=None
                # Do not later signal a recycled PID from a completed command.
                self.seen={}
            if code!=0:raise GuardFailure('nonzero command: '+label)
            if stdout.stat().st_size>maximumText:raise GuardFailure('command text cap')
            return stdout.read_text()
        except BaseException as error:
            self.failure=type(error).__name__+': '+str(error)[:300]
            self.retire()
            if process is not None:row['exitCode']=process.returncode
            raise
        finally:
            row['wallSeconds']=time.monotonic()-started
            for name,path in [('stdoutBytes',stdout),('stderrBytes',stderr)]:
                if path.exists():row[name]=path.stat().st_size
            self.save()

    def finish(self):
        self.monitor();self.save();self.monitor()
