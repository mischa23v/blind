#!/usr/bin/env python3
"""SOURCE ONLY: root review/admission required. Never invokes installs or retries.
Isolated-mode successor only. Original attempt001 source/manifest remain unchanged.
Same aggregate accounting, with an explicit source-bound terminal contract loader.
Historical estimated registration is diagnostic only, not camera-mesh calibration.
"""
import hashlib, json, math, os, pathlib, re, resource, signal, stat, subprocess, sys, time, types
H = pathlib.Path(__file__).resolve().parent
ROOT = H.parents[1]
CPU, WALL, RSS, OUTPUT = 120, 180, 1024**3, 64*1024**2

def file_record(fd, hashed):
    before=os.fstat(fd)
    if not stat.S_ISREG(before.st_mode): raise RuntimeError('Nonregular file refused')
    row={'bytes':before.st_size,'device':before.st_dev,'inode':before.st_ino,
         'mtimeNs':before.st_mtime_ns,'ctimeNs':before.st_ctime_ns}
    if hashed:
        if before.st_size>OUTPUT: raise RuntimeError('File exceeds output bound')
        with os.fdopen(os.dup(fd),'rb') as f: row['sha256']=hashlib.file_digest(f,'sha256').hexdigest()
        after=os.fstat(fd)
        if (before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_size,after.st_mtime_ns,after.st_ctime_ns):
            raise RuntimeError('File changed during terminal hashing')
    return row

def sha(p):
    fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode): raise RuntimeError('Nonregular pinned input')
        before=os.fstat(fd)
        with os.fdopen(os.dup(fd),'rb') as f: digest=hashlib.file_digest(f,'sha256').hexdigest()
        after=os.fstat(fd)
        if (before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_size,after.st_mtime_ns,after.st_ctime_ns):
            raise RuntimeError('Pinned input changed during hash')
        return digest
    finally: os.close(fd)

def inventory(root, active):
    """Bounded descriptor traversal. Only active ENOENT races may be skipped."""
    result={}; visits=0; total=0
    def walk(fd,prefix,depth):
        nonlocal visits,total
        if depth>8: raise RuntimeError('Output nesting cap')
        with os.scandir(fd) as entries:
            for entry in entries:
                visits+=1
                if visits>4096: raise RuntimeError('Output entry cap')
                name=entry.name; key=prefix+name
                try:
                    seen=os.stat(name,dir_fd=fd,follow_symlinks=False);mode=seen.st_mode
                    if stat.S_ISLNK(mode): raise RuntimeError('Output symlink refused: '+key)
                    if stat.S_ISDIR(mode):
                        child=os.open(name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
                        try:
                            opened=os.fstat(child)
                            if (opened.st_dev,opened.st_ino)!=(seen.st_dev,seen.st_ino):
                                raise RuntimeError('Output directory replaced: '+key)
                            result[key+'/']={'bytes':0,'device':opened.st_dev,'inode':opened.st_ino,
                                             'mtimeNs':opened.st_mtime_ns,'ctimeNs':opened.st_ctime_ns}
                            walk(child,key+'/',depth+1)
                        finally: os.close(child)
                    elif stat.S_ISREG(mode):
                        child=os.open(name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=fd)
                        try:
                            opened=os.fstat(child)
                            if (opened.st_dev,opened.st_ino)!=(seen.st_dev,seen.st_ino):
                                raise RuntimeError('Output file replaced: '+key)
                            total+=opened.st_size
                            if total>OUTPUT: raise RuntimeError('Aggregate output inventory cap')
                            result[key]=file_record(child,not active and key!='GUARD_RUN/RESULT.json')
                        finally: os.close(child)
                    else: raise RuntimeError('Output special file refused: '+key)
                except FileNotFoundError:
                    if not active: raise
    fd=os.open(root,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try: walk(fd,'',0)
    finally: os.close(fd)
    return result

def stable_inventory(root):
    first=inventory(root,False)
    if first!=inventory(root,False): raise RuntimeError('Terminal output inventory changed')
    return {name:row for name,row in first.items() if name!='GUARD_RUN/RESULT.json'}

def usage():
    r=resource.getrusage(resource.RUSAGE_CHILDREN)
    s=resource.getrusage(resource.RUSAGE_SELF)
    return r.ru_utime+r.ru_stime+s.ru_utime+s.ru_stime

def group_sample(pgid):
    cpu=rss=members=0
    for entry in pathlib.Path('/proc').iterdir():
        if not entry.name.isdecimal(): continue
        try:
            # comm may contain whitespace or parentheses; split after final ')'.
            a=(entry/'stat').read_text().rsplit(')',1)[1].split()
            if int(a[2])!=pgid: continue  # Original field 5: pgrp.
            members+=1
            cpu+=sum(int(a[i]) for i in (11,12,13,14))/os.sysconf('SC_CLK_TCK')
            rss+=int(a[21])*os.sysconf('SC_PAGE_SIZE')
        except (FileNotFoundError, ProcessLookupError): pass
    return cpu,rss,members

def kill_group(pid):
    try: os.killpg(pid,signal.SIGKILL)
    except ProcessLookupError: pass

def load_frozen_contracts(directory, contract_sha256, schedule_sha256):
    """Load only the two explicitly admitted source files, even under Python -I.

    Never trust cwd, PYTHONPATH or an already imported bare schedule_source.
    The temporary canonical import slot is restored after contracts imports it.
    """
    directory=pathlib.Path(directory).resolve()
    def read_pinned(name,digest):
        fd=os.open(directory/name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
        try:
            before=os.fstat(fd)
            if not stat.S_ISREG(before.st_mode) or before.st_size>32768:
                raise RuntimeError('Contract source must be small regular pinned file')
            with os.fdopen(os.dup(fd),'rb') as f:data=f.read(32769)
            after=os.fstat(fd)
            if (before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_size,after.st_mtime_ns,after.st_ctime_ns):
                raise RuntimeError('Contract source changed while loading')
            if hashlib.sha256(data).hexdigest()!=digest:raise RuntimeError('Contract source pin mismatch: '+name)
            return data
        finally:os.close(fd)
    scheduler=read_pinned('schedule_source.py',schedule_sha256)
    contract=read_pinned('contracts.py',contract_sha256)
    schedule_module=types.ModuleType('schedule_source');schedule_module.__file__=str(directory/'schedule_source.py')
    exec(compile(scheduler,schedule_module.__file__,'exec'),schedule_module.__dict__)
    sentinel=object();previous=sys.modules.get('schedule_source',sentinel)
    try:
        sys.modules['schedule_source']=schedule_module
        module=types.ModuleType('conference_frozen_contracts');module.__file__=str(directory/'contracts.py')
        exec(compile(contract,module.__file__,'exec'),module.__dict__)
        return module
    finally:
        if previous is sentinel:sys.modules.pop('schedule_source',None)
        else:sys.modules['schedule_source']=previous

def main():
    if len(sys.argv)!=3 or sys.argv[1]!='--admitted-source-commit':
        raise SystemExit('Requires root admission: --admitted-source-commit <exact git HEAD>')
    if sys.platform!='linux': raise SystemExit('Linux procfs required')
    os.environ['GIT_NO_LAZY_FETCH']='1'
    def interrupted(signum, frame):
        raise SystemExit('Supervisor interrupted by signal '+str(signum))
    for signum in (signal.SIGTERM,signal.SIGHUP): signal.signal(signum,interrupted)
    start=time.monotonic(); initial=usage()
    manifestBytes=(H/'SOURCE_PINS.json').read_bytes()
    manifestDigest=hashlib.sha256(manifestBytes).hexdigest()
    pins=json.loads(manifestBytes)
    def expand(value):
        return (value.replace('@WORKSPACE@',str(ROOT.parent))
                     .replace('@PROTOCOL@',str(H)).replace('@REPO@',str(ROOT)).replace('@PINS_SHA256@',manifestDigest))
    def verify_pins():
        if sha(H/'SOURCE_PINS.json')!=manifestDigest: raise RuntimeError('Run manifest changed')
        actual={}
        for name,digest in pins['inputs'].items():
            expanded=expand(name)
            p=pathlib.Path(expanded) if expanded.startswith('/') else ROOT/expanded
            actual[name]=sha(p)
            if actual[name]!=digest: raise RuntimeError('Pin mismatch: '+name)
        return actual
    beforePins=verify_pins()
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True,timeout=5).strip()
    if head!=sys.argv[2]: raise SystemExit('Admitted source commit mismatch')
    committed=subprocess.check_output(['git','show',head+':'+str((H/'SOURCE_PINS.json').relative_to(ROOT))],
                                      cwd=ROOT,timeout=5)
    if committed!=manifestBytes: raise RuntimeError('Run manifest differs from admitted commit')
    # Bind every repository source byte to the explicitly admitted commit.
    for name,digest in pins['inputs'].items():
        if name.startswith('/') or name.startswith('@WORKSPACE@'): continue
        data=subprocess.check_output(['git','show',head+':'+name],cwd=ROOT,timeout=5)
        if hashlib.sha256(data).hexdigest()!=digest:
            raise RuntimeError('Input differs from admitted commit: '+name)
    # Refuse existing attempts; preserve all native failures and partial logs.
    work=pathlib.Path(expand(pins['workRoot']))
    work.mkdir(exist_ok=False)
    out=work/'GUARD_RUN';out.mkdir(exist_ok=False)
    cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    receipt={'schema':1,'sourceCommit':head,'status':'started','commands':[],
             'limits':{'cpuSeconds':CPU,'wallSeconds':WALL,'observedRSSBytes':RSS,'outputBytes':OUTPUT},
             'cpuAffinity':[cpu], 'manifestSHA256':manifestDigest, 'pins':pins, 'inputHashesBefore':beforePins, 'physicalAuthority':False,
             'peakObservedAggregateRSS':0,'peakFastExitChildRSS':0,
             'limitations':['Observed RSS polling, not hard cgroup memory limit',
                 'Estimated historical registration is not camera-mesh calibration',
                 'Raw conservative enclosure comparison is not physical movement or exact collision',
                 'Same-mesh contacts cannot reveal tabletops absent from the mesh',
                 'No support probes or ground labels are produced; raw floor contacts above the inherited 2 mm exclusion remain',
                 'No-contact never establishes real-world clearance or navigation accuracy']}
    def write_receipt(encoded):
        # Validate before truncation; never follow even a terminally refused symlink.
        fd=os.open(out/'RESULT.json',os.O_WRONLY|os.O_CREAT|os.O_NOFOLLOW|os.O_NONBLOCK,0o600)
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode): raise RuntimeError('Receipt is not regular')
            os.ftruncate(fd,0)
            with os.fdopen(os.dup(fd),'w') as f: f.write(encoded)
        finally: os.close(fd)
    def save():
        receipt['wallSeconds']=time.monotonic()-start
        receipt['aggregateCPUSeconds']=usage()-initial
        encoded=json.dumps(receipt,indent=2)+'\n'
        if len(encoded.encode())>262144:
            write_receipt(json.dumps({'status':'failed','error':'receipt size cap',
                'sourceCommit':head,'commands':[{'label':r['label'],'exitCode':r.get('exitCode'),
                'groupRetired':r.get('groupRetired')} for r in receipt['commands']]}))
            raise RuntimeError('Receipt size cap')
        write_receipt(encoded)
    env={'PATH':'/usr/bin:/bin','LC_ALL':'C','HOME':str(out), 'TMPDIR':str(out),
         'OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1','PYTHONDONTWRITEBYTECODE':'1','PYTHONPYCACHEPREFIX':str(out/'fresh-pycache')}
    def retire(p,row):
        kill_group(p.pid)
        row['exitCode']=p.wait(timeout=2)
        deadline=min(start+WALL,time.monotonic()+2)
        while group_sample(p.pid)[2]:
            if time.monotonic()>=deadline:
                row['groupRetired']=False
                raise RuntimeError('Process group retirement not observed')
            time.sleep(.02)
        row['groupRetired']=True
    def command(args,label):
        row={'label':label,'argv':args};receipt['commands'].append(row);save()
        consumed=usage()-initial
        if consumed>=CPU or time.monotonic()-start>=WALL: raise RuntimeError('Aggregate budget exhausted')
        def limits():
            # Aggregate remaining budget is enforced by supervisor accounting.
            resource.setrlimit(resource.RLIMIT_CPU,(CPU,CPU))
            resource.setrlimit(resource.RLIMIT_FSIZE,(OUTPUT,OUTPUT))
            resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        p=None
        try:
            with (out/(label+'.stdout')).open('xb') as stdout, (out/(label+'.stderr')).open('xb') as stderr:
                p=subprocess.Popen(args,cwd=work,env=env,stdout=stdout,stderr=stderr,
                                   start_new_session=True,preexec_fn=limits)
                while True:
                    liveCPU,liveRSS,_=group_sample(p.pid)
                    selfRSS=int(pathlib.Path('/proc/self/statm').read_text().split()[1])*os.sysconf('SC_PAGE_SIZE')
                    receipt['peakObservedAggregateRSS']=max(receipt['peakObservedAggregateRSS'],liveRSS+selfRSS)
                    size=sum(f['bytes'] for f in inventory(work,True).values())
                    if usage()-initial+liveCPU>CPU: raise RuntimeError('Aggregate CPU breach')
                    if time.monotonic()-start>WALL: raise RuntimeError('Aggregate wall breach')
                    if liveRSS+selfRSS>RSS: raise RuntimeError('Observed aggregate RSS breach')
                    if size>OUTPUT: raise RuntimeError('Aggregate output breach')
                    code=p.poll()
                    if code is not None: break
                    time.sleep(.02)
                # A completed leader must not leave descendants running.
                row['exitCode']=p.wait()
                leftovers=group_sample(p.pid)[2]
                retire(p,row)
                if leftovers: raise RuntimeError('Leader exited leaving group members')
                fast=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss*1024
                receipt['peakFastExitChildRSS']=max(receipt['peakFastExitChildRSS'],fast)
                if fast>RSS or usage()-initial>CPU: raise RuntimeError('Fast-exit resource breach')
                if time.monotonic()-start>WALL: raise RuntimeError('Final aggregate wall breach')
                # Reserve 256 KiB for final JSON evidence, never silently drop it.
                terminal=stable_inventory(work)
                if sum(f['bytes'] for f in terminal.values())>OUTPUT-262144:
                    raise RuntimeError('Final output/reserved receipt breach')
                row['terminalInventory']=terminal
                if row['exitCode']!=0: raise RuntimeError(label+' nonzero exit')
        finally:
            if p is not None:
                try: retire(p,row)
                finally: save()
            else: save()
    try:
        command([expand(arg) for arg in pins['isolationControlsCommand']],'isolation-controls')
        isolation_text=(out/'isolation-controls.stderr').read_text()
        if not re.search(r'\nRan 3 tests in [^\n]+\n\nOK\n\Z',isolation_text):
            raise RuntimeError('Expected three isolated-mode source controls')
        receipt['isolationControlsExecuted']=3
        command([expand(arg) for arg in pins['sourceControlsCommand']],'source-controls')
        source_text=(out/'source-controls.stderr').read_text()
        if not re.search(r'\nRan 6 tests in [^\n]+\n\nOK\n\Z',source_text):
            raise RuntimeError('Expected six source controls with no skips')
        receipt['sourceControlsExecuted']=6
        command([expand(arg) for arg in pins['recorderSourceControlsCommand']],'recorder-source-controls')
        recorder_text=(out/'recorder-source-controls.stderr').read_text()
        if not re.search(r'\nRan 6 tests in [^\n]+\n\nOK\n\Z',recorder_text):
            raise RuntimeError('Expected six recorder-only source controls')
        receipt['recorderSourceControlsExecuted']=6
        command([expand(arg) for arg in pins['controlsCommand']],'controls')
        control_text=(out/'controls.stderr').read_text()
        if not re.search(r'\nRan 35 tests in [^\n]+\n\nOK\n\Z',control_text):
            raise RuntimeError('Expected 32 prior controls plus three additive recorder kernel controls')
        receipt['controlsExecuted']=35
        command([expand(arg) for arg in pins['comparisonCommand']],'comparison')
        actual=json.loads((work/'comparison/RECEIPT.json').read_text())
        frozen_directory=ROOT/'research/conference-body-source-20261029'
        frozen=json.loads((frozen_directory/'ROUTES.json').read_text())
        prefix='research/conference-body-source-20261029/'
        contracts=load_frozen_contracts(frozen_directory,pins['inputs'][prefix+'contracts.py'],
                                      pins['inputs'][prefix+'schedule_source.py'])
        contracts.validate_receipt(actual,frozen)
        debug=actual['hitRecorder']
        if (debug['complete'] is not True or debug['completedEvents']!=13704 or
            debug['loggedHitOccurrences']!=108582 or debug['allOldPerEventCountsMatched'] is not True or
            debug['candidateTriangles']!=8710095 or debug['oldCandidateCountStreamMatched'] is not True or
            debug['fixedIDCap']!=200000 or debug['fixedLogicalByteCap']!=8*1024**2 or
            debug['geometryOrClassificationChanged'] is not False or debug['physicalAuthority'] is not False):
            raise RuntimeError('complete bounded exact-count ID recording not established')
        if actual['sourceCountsSHA256']!=pins['inputs']['research/conference-contact-ids-source-20261030/EXPECTED_COUNTS.json'] or actual['sourcePriorContactsSHA256']!='f1b930185ee94b4b61fd8dbd2b85815ebe1d22148e34bbc3e796b010d91395be':
            raise RuntimeError('old exact per-event count source changed')
        receipt['completeHitRecorder']=debug
        receipt['comparison']={key:actual[key] for key in
            ('status','error','proposalSHA256','sourceMeshSHA256','registeredFloat32VerticesSHA256',
             'trianglesInt32SHA256','bodyWidthDepthHeightMetres','horizontalMarginMetres',
             'floorContactExclusionMetres','groundExemptedFaceCount','paths','counters',
             'physicalAuthority','continuousSupportProven','semanticFloorEstablished',
             'coverageEstablished','movementEpisode','arrivalClaimed','registrationAuthority')}
        receipt['status']='completed-zero-exit' # Raw diagnostic, never clearance or movement.
    except BaseException as error:
        receipt['status']='failed';receipt['error']=type(error).__name__+': '+str(error)
        raise
    finally:
        finalError=None
        try:
            receipt['inputHashesAfter']=verify_pins()
        except BaseException as error:
            receipt['status']='failed'
            receipt['postPinError']=type(error).__name__+': '+str(error)
            finalError=error
        if all(row.get('groupRetired') is True for row in receipt['commands']):
            try:
                receipt['finalPayloadInventory']=stable_inventory(work)
                payloadBytes=sum(row['bytes'] for row in receipt['finalPayloadInventory'].values())
                if payloadBytes>OUTPUT-262144: raise RuntimeError('Final payload/receipt reserve breach')
            except BaseException as error:
                receipt['status']='failed'
                receipt['inventoryError']=type(error).__name__+': '+str(error)
                finalError=error
        else:
            receipt['terminalInventoryStatus']='unverified: process group retirement not established'
            receipt['status']='failed'
            finalError=RuntimeError('Unverified process group retirement')
        if usage()-initial>CPU or time.monotonic()-start>WALL:
            receipt['status']='failed';receipt['resourceError']='Final evidence resource budget breach'
            finalError=RuntimeError(receipt['resourceError'])
        save()
        # Final encoding/writing is charged too; no second full pin hash.
        if usage()-initial>CPU or time.monotonic()-start>WALL:
            receipt['status']='failed';receipt['resourceError']='Final receipt resource budget breach'
            finalError=RuntimeError(receipt['resourceError']);save()
        if finalError is not None: raise finalError

if __name__=='__main__': main()
