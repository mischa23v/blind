#!/usr/bin/env python3
"""SOURCE ONLY: root review/admission required. Never invokes installs or retries.
Same passed Coffee aggregate supervisor, with seven-objective comparator terminal checks.
Historical estimated registration is diagnostic only, not camera-mesh calibration.
"""
import hashlib, json, math, os, pathlib, resource, signal, stat, subprocess, sys, time
H = pathlib.Path(__file__).resolve().parent
ROOT = H.parents[1]
CPU, WALL, RSS, OUTPUT = 120, 180, 1024**3, 16*1024**2

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
                 'This comparator does not execute full-body collision or movement',
                 'Same-mesh contacts cannot reveal tabletops absent from the mesh',
                 'Nine probes are not complete-footprint support; labels are not semantic truth',
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
        command([expand(arg) for arg in pins['controlsCommand']],'controls')
        command([expand(arg) for arg in pins['comparisonCommand']],'comparison')
        actual=json.loads((work/'comparison/PROPOSALS.json').read_text())
        canonical=json.loads((ROOT/'research/conference-replay-input-inventory-20261029/TARGETS.json').read_text())['primaryPairs']
        mesh_receipt=json.loads((ROOT/'research/conference-replay-input-inventory-20261029/evidence/MESH_INPUT_RECEIPT.json').read_text())
        names=[p['name'] for p in actual['paths']]
        expected_names=['table_92_to_120','table_120_to_200','table_200_to_220','table_220_to_20','table_20_to_92','varpu_130_to_160','varpu_160_to_130']
        if names!=expected_names or names!=[p['name']for p in canonical]: raise RuntimeError('seven canonical objectives changed')
        if actual['bodyWidthDepthHeightMetres']!=[.45,.30,1.60] or actual['horizontalMarginMetres']!=.15 or actual['physicalAuthority'] is not False: raise RuntimeError('body/authority mismatch')
        if actual['proposalRadiusMetres']!=.225 or actual['proposalHeightMetres']!=1.75: raise RuntimeError('native proposal profile changed')
        if actual['nativeExclusionEnabled'] is not False or actual['movementExecuted'] is not False or actual['validatedCameraMeshAlignment'] is not False or actual['correctedOccupancyConsumed'] is not False: raise RuntimeError('unexpected geometry/movement/calibration authority')
        if actual['historicalEstimatedLevelFrameUsed'] is not True or actual['registrationAuthority']!='historicalEstimatedComparatorOnlyNotOfficialCameraMeshCalibration': raise RuntimeError('registration provenance missing')
        if actual['fullBodyValidation']!='notEstablished' or actual['floorSupport']!='unknown' or actual['manualRepairArm']!='inputUnavailableNoKoivuPhysicalExclusionContract': raise RuntimeError('unsupported validation claim')
        if actual['registeredFloat32VerticesSHA256']!=mesh_receipt['transformedFloat32VertexBytesSHA'] or actual['trianglesInt32SHA256']!=mesh_receipt['triangleBytesSHA']: raise RuntimeError('transformed source identity mismatch')
        expected_cfg={'radius':.225,'height':1.75,'cell_size':.025,'cell_height':.025,'max_climb':.025,'max_slope':15,'max_cells':250000,'max_nodes':4096}
        if actual['nativeConfig']!=expected_cfg: raise RuntimeError('native configuration changed')
        counts={'baselineCompleteAndAssociated':0,'gridProposals':0,'gridDisconnected':0,'gridUnavailable':0}
        def polyline_length(chain):
            if not isinstance(chain,list) or len(chain)<2 or len(chain)>100012: raise RuntimeError('chain cardinality')
            for p in chain:
                if not isinstance(p,list) or len(p)!=3 or not all(isinstance(x,(int,float)) and not isinstance(x,bool) and math.isfinite(x)for x in p): raise RuntimeError('invalid chain point')
            return sum(math.dist(a,b)for a,b in zip(chain[:-1],chain[1:]))
        for row,request in zip(actual['paths'],canonical):
            for key in ('requestedStartXYZ','requestedGoalXYZ','sourcePoseIndices'):
                if row[key]!=request[key]: raise RuntimeError('fixed request changed: '+row['name'])
            if row['physicalAuthority'] is not False or row['cameraAnchorsNotBodyPose'] is not True: raise RuntimeError('per-objective authority missing')
            native=row['baselineNative'];aa=row['baselineStartAssociation'];bb=row['baselineGoalAssociation']
            def association_passes(requested,projected,record):
                finite=len(projected)==3 and all(isinstance(x,(int,float)) and not isinstance(x,bool) and math.isfinite(x)for x in projected)
                if record['finite']!=finite or record['actorSnapped'] is not False: raise RuntimeError('association validity changed')
                if not finite:
                    if record['horizontalMetres'] is not None or record['verticalMetres'] is not None or record['passes10cmHorizontal'] is not False: raise RuntimeError('invalid association promoted')
                    return False
                horizontal=math.hypot(projected[0]-requested[0],projected[2]-requested[2]);vertical=projected[1]-requested[1]
                if not math.isclose(horizontal,record['horizontalMetres'],rel_tol=0,abs_tol=1e-12) or not math.isclose(vertical,record['verticalMetres'],rel_tol=0,abs_tol=1e-12): raise RuntimeError('association arithmetic mismatch')
                accepted=horizontal<=.1
                if record['passes10cmHorizontal']!=accepted: raise RuntimeError('association threshold mismatch')
                return accepted
            start_ok=association_passes(request['requestedStartXYZ'],native['projected_start'],aa)
            goal_ok=association_passes(request['requestedGoalXYZ'],native['projected_goal'],bb)
            accepted=native['complete'] is True and len(native['points'])>=2 and start_ok and goal_ok
            if row['baselineCompleteAndAssociated']!=accepted: raise RuntimeError('native acceptance mismatch')
            if accepted:
                expected_chain=[request['requestedStartXYZ']]+native['points']+[request['requestedGoalXYZ']]
                if row['baselineRequestedConnectorChainXYZ']!=expected_chain: raise RuntimeError('native full connector chain changed')
                polyline_length(expected_chain);counts['baselineCompleteAndAssociated']+=1
            elif row['baselineRequestedConnectorChainXYZ'] is not None: raise RuntimeError('partial/rejected native path received invented goal connector')
            status=row['gridStatus']
            if status=='proposalOnlyAwaitingHardValidation':
                choice=row['gridSelection']
                if choice['status']!=status or choice['physicalAuthority'] is not False or choice['hardBodyValidation']!='notEstablished' or choice['fullFootprintSupport']!='notEstablished': raise RuntimeError('grid authority mismatch')
                cap=1.5*choice['distanceGrid']['lengthMetres']+.5
                if not math.isclose(cap,choice['lengthCapMetres'],rel_tol=0,abs_tol=1e-9): raise RuntimeError('original grid detour cap changed')
                for arm in ('distanceGrid','clearanceGrid'):
                    candidate=choice[arm];points=candidate['pointsXYZ'];chain=[request['requestedStartXYZ']]+points+[request['requestedGoalXYZ']]
                    if candidate['requestedConnectorChainXYZ']!=chain: raise RuntimeError('grid requested connectors changed')
                    length=polyline_length(points);full=polyline_length(chain)
                    if not math.isclose(length,candidate['lengthMetres'],rel_tol=0,abs_tol=1e-8) or not math.isclose(full,candidate['connectorInclusiveLengthMetres'],rel_tol=0,abs_tol=1e-8): raise RuntimeError('grid length accounting mismatch')
                    if length>cap+1e-9: raise RuntimeError('grid path exceeds frozen detour cap')
                counts['gridProposals']+=1
            elif status=='disconnected':
                choice=row['gridSelection']
                if choice['status']!=status or choice['physicalAuthority'] is not False or any(k in choice for k in ('distanceGrid','clearanceGrid')): raise RuntimeError('disconnected grid promoted')
                counts['gridDisconnected']+=1
            elif status=='unavailableWholeBatchAnchorOrGraphFailure':
                if 'gridSelection' in row: raise RuntimeError('unavailable grid received candidate')
                counts['gridUnavailable']+=1
            else: raise RuntimeError('unrecognized/incomplete objective status')
        if actual['status']=='SEVEN_SOURCE_OBJECTIVES_EVALUATED_NOT_BODY_VALIDATED':
            if counts['gridUnavailable'] or counts['gridProposals']+counts['gridDisconnected']!=7: raise RuntimeError('grid evaluation incomplete')
        elif actual['status']=='SOURCE_BASELINES_RETAINED_GRID_UNAVAILABLE':
            if counts['gridUnavailable']!=7 or not actual.get('gridFailure'): raise RuntimeError('batch failure incompletely retained')
        else: raise RuntimeError('unexpected comparator terminal status')
        receipt['comparison']={'status':actual['status'],'queries':len(names),'objectives':names,**counts,
            'allSevenRequestsRetained':True,'physicalAuthority':False,'bodyOrSupportValidated':False,
            'registrationAuthority':'historical estimated comparator only; not camera-mesh calibration'}
        receipt['status']='completed-zero-exit' # Candidate comparison only, not clearance.
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
