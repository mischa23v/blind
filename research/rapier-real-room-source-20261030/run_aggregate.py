#!/usr/bin/env python3
"""Prepared real-room diagnostic aggregate launcher. No execution until published/reviewed/admitted.
Reuses conference guard helpers and process-group accounting. No RLIMIT_AS for V8.
"""
import hashlib, json, math, os, pathlib, resource, signal, stat, subprocess, sys, time
from guard_helpers import sha, inventory, stable_inventory, usage, group_sample, kill_group
H=pathlib.Path(__file__).resolve().parent
ROOT=H.parents[1]  # Publication contract: <repo>/research/<this packet>.
CPU,WALL,RSS,OUTPUT=120,180,1024**3,16*1024**2
NODE_HEAP_MIB=256

def main():
    if len(sys.argv)!=3 or sys.argv[1]!='--admitted-source-commit':
        raise SystemExit('Requires published source admission: --admitted-source-commit <exact git HEAD>')
    if sys.platform!='linux': raise SystemExit('Linux procfs required for existing aggregate accounting')
    started=time.monotonic();initial=usage()
    for sig in (signal.SIGTERM,signal.SIGHUP):
        signal.signal(sig,lambda s,_f: (_ for _ in ()).throw(SystemExit('Supervisor interrupted: '+str(s))))
    manifestBytes=(H/'RUN_PINS.json').read_bytes();manifestSHA=hashlib.sha256(manifestBytes).hexdigest()
    pins=json.loads(manifestBytes)
    if pins['protocol']!='rapier-real-room-fixed-probes-v1-managed-sandbox': raise RuntimeError('Wrong real-room protocol')
    if pins['limits']!={'cpuSeconds':CPU,'wallSeconds':WALL,'observedRSSBytes':RSS,
                       'outputBytes':OUTPUT,'nodeOldSpaceMiB':NODE_HEAP_MIB,'controllerCalls':328}:
        raise RuntimeError('Frozen limits changed')
    def expand(s):
        return s.replace('@WORKSPACE@',str(ROOT.parent)).replace('@SOURCE@',str(H)).replace('@REPO@',str(ROOT))
    def verify():
        if sha(H/'RUN_PINS.json')!=manifestSHA: raise RuntimeError('Run manifest changed')
        found={}
        for key,digest in pins['inputs'].items():
            name=expand(key);p=pathlib.Path(name)
            if not p.is_absolute():p=ROOT/p
            found[key]=sha(p)
            if found[key]!=digest:raise RuntimeError('Pinned input mismatch: '+key)
        return found
    before=verify()
    gitEnv={'PATH':'/usr/bin:/bin','LC_ALL':'C','HOME':'/nonexistent','GIT_NO_LAZY_FETCH':'1',
            'GIT_TERMINAL_PROMPT':'0','GIT_CONFIG_NOSYSTEM':'1','GIT_CONFIG_GLOBAL':'/dev/null',
            'GIT_OPTIONAL_LOCKS':'0','GIT_PAGER':'cat'}
    def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,env=gitEnv,timeout=5)
    head=git('rev-parse','HEAD').decode().strip()
    if head!=sys.argv[2]:raise RuntimeError('Admitted source commit mismatch')
    relative=H.relative_to(ROOT)
    if git('show',head+':'+str(relative/'RUN_PINS.json'))!=manifestBytes:
        raise RuntimeError('Manifest differs from admitted commit')
    for name,digest in pins['publishedSourceFiles'].items():
        local=H/name
        if sha(local)!=digest or hashlib.sha256(git('show',head+':'+str(relative/name))).hexdigest()!=digest:
            raise RuntimeError('Source differs from admitted commit: '+name)
    ref=pins['reuseSource']
    if sha(ROOT/ref['path'])!=ref['sha256'] or hashlib.sha256(git('show',head+':'+ref['path'])).hexdigest()!=ref['sha256']:
        raise RuntimeError('Reused supervisor source identity changed')
    work=pathlib.Path(expand(pins['workRoot']));work.mkdir(exist_ok=False)
    out=work/'GUARD_RUN';out.mkdir(exist_ok=False)
    cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    receipt={'schema':1,'scope':'fixed_real_room_probes_only','status':'started','sourceCommit':head,
             'manifestSHA256':manifestSHA,'inputHashesBefore':before,'commands':[],
             'limits':pins['limits'],'cpuAffinity':[cpu],'peakObservedAggregateRSS':0,'peakFastExitChildRSS':0,
             'physicalAuthority':False,'realRoomQueries':0,'rlimitASApplied':False,
             'runtimeContract':'managed_sandbox_trusted_official_source',
             'independentlyAirGapped':False,'namespaceSetupRequested':False,'hostSecuritySettingsChanged':False,
             'limitations':['Observed RSS polling is not a hard cgroup memory bound',
               'Node old-space heap cap does not include WASM/native/external memory',
               'Uses existing managed sandbox and trusted official source; not independently air-gapped',
               'Node permissions prevent unintended operations; not a hostile-code security boundary',
               'Same-mesh fixed probes do not establish source-room support, hazards, arrival or physical clearance']}
    def save():
        receipt['wallSeconds']=time.monotonic()-started;receipt['aggregateCPUSeconds']=usage()-initial
        b=(json.dumps(receipt,indent=2)+'\n').encode()
        if len(b)>262144:raise RuntimeError('Receipt size cap')
        fd=os.open(out/'RESULT.json',os.O_WRONLY|os.O_CREAT|os.O_NOFOLLOW|os.O_NONBLOCK,0o600)
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode):raise RuntimeError('Nonregular receipt refused')
            os.ftruncate(fd,0)
            with os.fdopen(os.dup(fd),'wb') as f:f.write(b)
        finally:os.close(fd)
    def retire(p,row):
        kill_group(p.pid);row['exitCode']=p.wait(timeout=2)
        deadline=min(started+WALL,time.monotonic()+2)
        while group_sample(p.pid)[2]:
            if time.monotonic()>=deadline:row['groupRetired']=False;raise RuntimeError('Process group retirement unconfirmed')
            time.sleep(.02)
        row['groupRetired']=True
    env={'PATH':'/usr/bin:/bin','LC_ALL':'C','HOME':str(out),'TMPDIR':str(out),
         'UV_THREADPOOL_SIZE':'1','OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1',
         'PYTHONDONTWRITEBYTECODE':'1','PYTHONPYCACHEPREFIX':str(out/'fresh-pycache')}
    packageRoot=expand(pins['packageRoot']);dataRoot=expand(pins['dataRoot'])
    args=[pins['nodeExecutable'],
          '--permission','--allow-fs-read='+str(H),'--allow-fs-read='+packageRoot,'--allow-fs-read='+dataRoot,
          '--allow-fs-write='+str(work),
          '--max-old-space-size=256','--max-semi-space-size=8','--v8-pool-size=1',
          str(H/'room_worker.mjs'),'--package-root',packageRoot,'--data-root',dataRoot,'--output',str(work/'probes'),
          '--runtime-contract','managed_sandbox_trusted_official_source','--pins-sha256',manifestSHA]
    row={'label':'real-room-fixed-probes','argv':args,'childEnvironmentKeys':sorted(env),
         'runtimeContract':'managed_sandbox_trusted_official_source',
         'networkAccessRequestedByProtocol':False,'independentlyAirGapped':False};receipt['commands'].append(row);save()
    p=None;failure=None
    try:
        if usage()-initial>=CPU or time.monotonic()-started>=WALL:raise RuntimeError('Prelaunch aggregate budget exhausted')
        def limits():
            resource.setrlimit(resource.RLIMIT_CPU,(CPU,CPU))
            resource.setrlimit(resource.RLIMIT_FSIZE,(OUTPUT,OUTPUT))
            resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        with (out/'probes.stdout').open('xb') as stdout,(out/'probes.stderr').open('xb') as stderr:
            p=subprocess.Popen(args,cwd=work,env=env,stdout=stdout,stderr=stderr,
                               start_new_session=True,preexec_fn=limits)
            while True:
                liveCPU,liveRSS,_=group_sample(p.pid)
                selfRSS=int(pathlib.Path('/proc/self/statm').read_text().split()[1])*os.sysconf('SC_PAGE_SIZE')
                receipt['peakObservedAggregateRSS']=max(receipt['peakObservedAggregateRSS'],liveRSS+selfRSS)
                size=sum(v['bytes'] for v in inventory(work,True).values())
                if usage()-initial+liveCPU>CPU:raise RuntimeError('Aggregate CPU breach')
                if time.monotonic()-started>WALL:raise RuntimeError('Aggregate wall breach')
                if liveRSS+selfRSS>RSS:raise RuntimeError('Observed aggregate RSS breach')
                if size>OUTPUT:raise RuntimeError('Aggregate output breach')
                if p.poll() is not None:break
                time.sleep(.02)
            row['exitCode']=p.wait();leftovers=group_sample(p.pid)[2];retire(p,row)
            if leftovers:raise RuntimeError('Leader exited with process-group descendants')
            fast=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss*1024
            receipt['peakFastExitChildRSS']=fast
            if fast>RSS or usage()-initial>CPU or time.monotonic()-started>WALL:
                raise RuntimeError('Final/fast-exit resource breach')
            terminal=stable_inventory(work)
            if sum(v['bytes'] for v in terminal.values())>OUTPUT-262144:raise RuntimeError('Payload/receipt reserve breach')
            row['terminalInventory']=terminal
            if row['exitCode'] not in (0,1):raise RuntimeError('Unexpected worker exit; no retry or permission widening')
        if row['exitCode']!=0:raise RuntimeError('Room worker failed; partial result retained')
        summary=json.loads((work/'probes/SUMMARY.json').read_text())
        expected={'scope':'fixed_real_room_probes_only','status':'completed_diagnostic_proposals_not_movement',
                  'wrapperCount':16,'probeCount':408,'controllerCalls':328,'unsupportedTurns':80,
                  'allSelectedRowsRetained':True,'wasmInitialized':True,'wrapperVersion':'0.21.0',
                  'physicalAuthority':False,'movementApplied':False,'arrivalEstablished':False,
                  'analyticControlsHadTwoKnownFailures':True,'computedGroundedIsNotSupport':True,
                  'runtimeContract':'managed_sandbox_trusted_official_source','nodePermissionsChecked':True,
                  'independentlyAirGapped':False,'namespaceSetupRequested':False,'hostSecuritySettingsChanged':False,
                  'networkAccessRequestedByProtocol':False,'rlimitASApplied':False,'independentHazardOraclePassed':False}
        for k,v in expected.items():
            if summary.get(k)!=v:raise RuntimeError('Worker terminal contract mismatch: '+k)
        if summary['pinsSHA256']!=manifestSHA:raise RuntimeError('Worker manifest identity mismatch')
        wrappers=[json.loads(x) for x in (work/'probes/wrapper-records.jsonl').read_text().splitlines()]
        probes=[json.loads(x) for x in (work/'probes/probe-rows.jsonl').read_text().splitlines()]
        expectedWrappers=[];expectedProbes=[];original={}
        for scene in ['coffee','conference']:
            data=json.loads((pathlib.Path(dataRoot)/(scene+'.probes.json')).read_text())
            original.update({x['id']:x for x in data})
            for envelope in ['body','horizontal_margin']:
                for arm in ['raw_trimesh','two_sided_internal_edges']:
                    for inputArm in ['exact_xyz','horizontal_projection']:
                        expectedWrappers.append((scene,arm,envelope,inputArm))
                        expectedProbes.extend((scene,arm,envelope,inputArm,x['id']) for x in data)
        if [(x['scene'],x['arm'],x['envelope'],x['inputArm']) for x in wrappers]!=expectedWrappers:
            raise RuntimeError('Wrapper inventory/order mismatch')
        if [(x['scene'],x['arm'],x['envelope'],x['inputArm'],x['row']['id']) for x in probes]!=expectedProbes:
            raise RuntimeError('Probe inventory/order mismatch')
        if sum(x['row']['controllerCalled'] for x in probes)!=328:raise RuntimeError('Controller inventory')
        for x in probes:
            r=x['row'];src=original[r['id']]
            if r['originalFoot']!=src['foot'] or r['originalYawRadians']!=src['yawRadians'] or r['originalDesiredDelta']!=src['desiredDelta']:
                raise RuntimeError('Original pose/input changed')
            if r['independentEvidence']!=src['independentEvidence']:raise RuntimeError('Independent VTK evidence changed')
            if r['physicalAuthority'] is not False or r['movementApplied'] is not False or r['arrivalEstablished'] is not False:
                raise RuntimeError('Physical authority acquired')
            if r['support']!='unknown' or r['semanticFloor']!='unknown' or not r.get('queryBandDifference'):
                raise RuntimeError('Support or lower-band distinction lost')
            if r['kind']=='turn':
                if r['status']!='unsupported_rotation' or r['controllerCalled'] is not False or r['proposedMovement'] is not None:
                    raise RuntimeError('Rotation unsupported contract')
            else:
                if r['proposalWasNotApplied'] is not True or not all(math.isfinite(v) for v in r['proposedMovement']):
                    raise RuntimeError('Invalid/unretained controller proposal')
        receipt['roomSummary']=summary;receipt['status']='completed-fixed-pose-diagnostic-only'
        receipt['wrapperRecordsVerified']=16;receipt['nestedProbeRowsVerified']=408;receipt['realRoomQueries']=328
    except BaseException as error:
        failure=error;receipt['status']='failed';receipt['error']=type(error).__name__+': '+str(error)
    finally:
        if p is not None:
            try:retire(p,row)
            except BaseException as error:
                receipt['status']='failed';receipt['retirementError']=str(error);failure=failure or error
        try:receipt['inputHashesAfter']=verify()
        except BaseException as error:
            receipt['status']='failed';receipt['postPinError']=str(error);failure=failure or error
        if p is None or row.get('groupRetired') is True:
            try:
                receipt['finalPayloadInventory']=stable_inventory(work)
                if sum(v['bytes'] for v in receipt['finalPayloadInventory'].values())>OUTPUT-262144:
                    raise RuntimeError('Final payload/receipt reserve breach')
            except BaseException as error:
                receipt['status']='failed';receipt['inventoryError']=str(error);failure=failure or error
        else:receipt['status']='failed';receipt['terminalInventoryStatus']='unverified process-group retirement'
        if usage()-initial>CPU or time.monotonic()-started>WALL:
            receipt['status']='failed';receipt['resourceError']='Final evidence resource budget breach';failure=failure or RuntimeError(receipt['resourceError'])
        save()
        if usage()-initial>CPU or time.monotonic()-started>WALL:
            receipt['status']='failed';receipt['resourceError']='Final receipt resource budget breach';save()
            failure=failure or RuntimeError(receipt['resourceError'])
    if failure is not None:raise failure

if __name__=='__main__':main()
