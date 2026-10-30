#!/usr/bin/env python3
"""Read-only stdlib reconciliation of completed worker evidence, NOT a native rerun.

Never rewrites or promotes the failed aggregate outcome. Rechecks source/input
bytes, exact authored record coverage, structural contact invariants, first
witness heights and receipt summaries. Does NOT recompute VTK intersections.
"""
import argparse, gzip, hashlib, importlib.util, json, math, os, pathlib, re, resource, stat, struct, sys, time
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
OLD=R/'research/conference-body-source-20261029'
ORIGINAL_MANIFEST='ed735949ea0d21bf0fbf64754980a61d67d8b8095193b11d5ba72920dc8d6dc9'
SOURCE_COMMIT='c204b0e63e4c7444c02ea8ccf50e347693a15684'
def require(condition,message):
    if not condition:raise ValueError(message)
def sha(path):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    try:
        before=os.fstat(fd);require(stat.S_ISREG(before.st_mode),'not regular: '+str(path))
        with os.fdopen(os.dup(fd),'rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
        after=os.fstat(fd)
        require((before.st_size,before.st_mtime_ns,before.st_ctime_ns)==(after.st_size,after.st_mtime_ns,after.st_ctime_ns),'changed during hash')
        return digest
    finally:os.close(fd)
def strict_json(data):
    def pairs(items):
        result={}
        for key,value in items:
            require(key not in result,'duplicate JSON key');result[key]=value
        return result
    def constant(value):raise ValueError('nonfinite JSON constant '+value)
    return json.loads(data,object_pairs_hook=pairs,parse_constant=constant)
def expand(name):
    value=name.replace('@WORKSPACE@',str(W)).replace('@REPO@',str(R))
    return pathlib.Path(value) if value.startswith('/') else R/value
def close(actual,expected,label):
    if isinstance(expected,(list,tuple)):
        require(isinstance(actual,list) and len(actual)==len(expected),label+' shape')
        for a,b in zip(actual,expected):close(a,b,label)
    else:require(isinstance(actual,(int,float)) and not isinstance(actual,bool) and math.isfinite(actual) and math.isclose(actual,expected,rel_tol=0,abs_tol=1e-12),label+' mismatch')

def registered_source(pins,contracts):
    """Independent scalar/struct arithmetic only; source topology is not altered."""
    registration=strict_json(expand(pins['registrationPath']).read_bytes())
    Q=registration['rotationOBJToLevel'];t=registration['translationOBJToLevel']
    vertices=[];faces=[];vh=hashlib.sha256();th=hashlib.sha256()
    for line in expand(pins['meshPath']).open():
        q=line.split()
        if not q:continue
        if q[0]=='v':
            require(len(q)==4,'OBJ vertex shape');p=list(map(float,q[1:]))
            level=[sum(Q[i][j]*p[j] for j in range(3))+t[i] for i in range(3)]
            raw=struct.pack('<fff',level[0],level[2],-level[1]);vh.update(raw)
            vertices.append(struct.unpack('<fff',raw))
        elif q[0]=='f':
            require(len(q)==4,'OBJ triangle shape')
            face=[int(s.split('/')[0])-1 for s in q[1:]];faces.append(face);th.update(struct.pack('<iii',*face))
    require((len(vertices),len(faces))==(18398,29366),'original mesh cardinality')
    require(vh.hexdigest()==contracts.VERTEX_SHA and th.hexdigest()==contracts.TRIANGLE_SHA,'registered source digest reproduction')
    heights=[[min(vertices[i][1] for i in f),max(vertices[i][1] for i in f)] for f in faces]
    return heights,{'verticesSHA256':vh.hexdigest(),'trianglesSHA256':th.hexdigest(),'method':'stdlib scalar rigid transform and little-endian float32/int32 packing; no native imports'}

def check_contact(record,event,kind,heights):
    r=record[kind];pad=0. if kind=='actualBody' else .15
    for key in ('physicalAuthority','physicalClearanceEstablished','measuredCoverageEstablished','closedSolidContainmentClassified','groundClassificationSemantic','groundContactEvent','groundContactFaceIDsTruncated','lowHeightAloneExcluded'):
        require(r[key] is False,'contact boundary '+key)
    require(r['closedBoundaries'] is True and r['completeCandidateContactCounts'] is True,'all-hit closed-boundary contract')
    require(r['groundContactCount']==0 and r['groundContactFaceIDsFirst16']==[],'ground exemption observed')
    candidates=r['candidateTriangles'];count=r['rawContactCount']
    require(type(candidates) is int and 0<=candidates<=29366,'candidate count')
    require(type(count) is int and 0<=count<=candidates and count==r['nonGroundContactCount'],'raw all-hit count')
    require(r['contact'] is (count>0),'boolean contact/count mismatch')
    s=r['sweep'];a,b=event['a'],event['b'];mid=event['yaw']+event['dyaw']*.5
    c=math.cos(mid);sn=math.sin(mid);dx=b[0]-a[0];dz=b[2]-a[2]
    half=[abs(dx*c+dz*sn)*.5,abs(-dx*sn+dz*c)*.5]
    radius=math.hypot(.15+pad,.225+pad);rotation=2*radius*math.sin(abs(event['dyaw'])*.25)
    for key,expected in {'midpointYawRadians':mid,'actualYawDeltaRadians':event['dyaw'],
        'cornerRadiusMetres':radius,'halfProjectedTranslationMetres':half,
        'rotationPaddingMetresPerHorizontalAxis':rotation,
        'enclosingHalfExtentsForwardLateral':[.15+pad+half[0]+rotation,.225+pad+half[1]+rotation],
        'verticalBoundsMetres':[min(a[1],b[1])+.002,max(a[1],b[1])+1.6],
        'floorContactExclusionMetres':.002}.items():close(s[key],expected,'sweep '+key)
    require(s['continuousMotionEnclosed'] is True and s['conservativeEnclosureMayOvercount'] is True,'enclosure limits')
    if not count:
        require(r['firstReferenceCellID'] is None and r['reason']=='noNonGroundReferenceSurfaceContact','no-contact witness')
        require('firstTriangleModelHeightRange' not in r,'spurious no-contact height');return candidates,None
    cid=r['firstReferenceCellID'];require(type(cid) is int and 0<=cid<len(heights),'witness source triangle ID')
    require(r['firstTriangleModelHeightRange']==heights[cid],'witness whole-triangle height differs from exact original face')
    require(r['heightRangeIsWholeTriangleNotContactPoint'] is True,'witness meaning')
    relative=[v-a[1] for v in heights[cid]];end_relative=[v-b[1] for v in heights[cid]]
    require(r['firstTriangleHeightRelativeToStartFootRange']==relative,'start-relative witness height')
    require(r['firstWitnessWholeTriangleHeightRelativeToEndFootRange']==end_relative,'end-relative witness height')
    near=all(abs(v)<=.025 for v in relative)
    require(r['firstWitnessWithin25mmOfStartFootPlane'] is near and r['firstWitnessNearFootLabelDoesNotExemptContact'] is True,'reporting-only near-foot flag')
    require(r['reason'] in ('boundaryIntersection','containedTriangleVertex'),'contact witness reason')
    return candidates,{'event':None,'kind':event['kind'],'referenceCellID':cid,
        'wholeTriangleRegisteredHeightRange':heights[cid],'wholeTriangleRelativeToStartFootRange':relative,
        'nearFoot25mmReportingBand':near}

def validate_stream(path,receipt,frozen,contracts,heights,budget_check):
    logical=events=triangles=0;rows=[];decoded=hashlib.sha256()
    with gzip.open(path,'rb') as stream:
        for source,reported in zip(frozen['paths'],receipt['paths']):
            require(source['status']!='unavailable','this exact attempt expected all seven source proposals')
            schedule=contracts.check_schedule(source)
            counts={'actualBody':0,'horizontalMargin':0};near={'actualBody':0,'horizontalMargin':0};first={}
            for n,event in enumerate(schedule['events']):
                raw=stream.readline(65537);require(raw and len(raw)<=65536 and raw.endswith(b'\n'),'missing/oversized/truncated record')
                logical+=len(raw);require(logical<=64*1024**2,'logical log cap');decoded.update(raw)
                item=strict_json(raw)
                require(item['path']==source['name'] and type(item['event']) is int and item['event']==n,'stream route/order/coverage mismatch')
                require(item['authoredIncrement']==event,'authored increment differs from frozen schedule')
                require(math.dist(event['a'],event['b'])<=.025+1e-12 and abs(event['dyaw'])<=math.pi/180+1e-12,'increment caps')
                r=item['contacts'];require(r['bodyDimensionsWidthDepthHeight']==[.45,.3,1.6] and r['horizontalMarginMetres']==.15,'body profile')
                require(r['physicalAuthority'] is False and r['marginExtendsVerticalHeight'] is False and r['actualBodyContactIsConservativeEnclosureOverlap'] is True,'record authority')
                for kind in counts:
                    candidate,witness=check_contact(r,event,kind,heights);triangles+=candidate
                    if witness is not None:
                        counts[kind]+=1;near[kind]+=witness['nearFoot25mmReportingBand'];witness['event']=n
                        if kind not in first:first[kind]=witness
                events+=1
                if events%128==0:budget_check()
            require(reported['contactEvents']==counts and reported['firstWitnessNearFootBandEvents']==near and reported['firstContactByEnvelope']==first,'receipt does not reconcile with complete stream')
            require(reported['arrivalClaimed'] is False,'arrival claim')
            rows.append({'name':source['name'],'verifiedEvents':len(schedule['events']),
                         'contactEvents':counts,'firstWitnessNearFootBandEvents':near,'firstContactByEnvelope':first})
        require(stream.read(1)==b'','extra records after all seven routes')
    require(events==13704 and receipt['counters']=={'boxes':events*2,'triangles':triangles,'rays':0},'complete counters differ')
    require(logical==receipt['outputLogicalBytes'],'logical stream bytes differ')
    return {'events':events,'boxes':events*2,'triangleCandidates':triangles,'supportRays':0,
            'logicalBytes':logical,'decodedStreamSHA256':decoded.hexdigest(),'paths':rows}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--pins-sha256',required=True);ap.add_argument('--out',type=pathlib.Path,required=True);a=ap.parse_args()
    began=time.monotonic();cpu0=time.process_time();cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_CPU,(30,30));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    require(sha(H/'POSTRUN_PINS.json')==a.pins_sha256,'postrun manifest pin')
    postpins=strict_json((H/'POSTRUN_PINS.json').read_bytes())
    def verify():
        require(sha(H/'POSTRUN_PINS.json')==a.pins_sha256,'postrun manifest changed')
        for name,digest in postpins['inputs'].items():require(sha(expand(name))==digest,'postrun input changed: '+name)
    def budget():
        require(time.monotonic()-began<60 and time.process_time()-cpu0<30,'postrun validation time bound')
        require(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024<256*1024**2,'postrun validation RSS bound')
    verify();out=a.out.resolve();out.relative_to(W);out.mkdir(exist_ok=False)
    result={'status':'started','originalAggregateOutcome':'failed','originalAggregateOutcomeUnchanged':True,
      'workerNativeRerun':False,'nativeImportsExecuted':False,'physicalAuthority':False,'physicalPass':False,
      'postrunManifestSHA256':a.pins_sha256}
    try:
        require(sha(OLD/'SOURCE_PINS.json')==ORIGINAL_MANIFEST,'original manifest changed')
        oldpins=strict_json((OLD/'SOURCE_PINS.json').read_bytes())
        attempt=expand(postpins['attemptDirectory']);guard=strict_json((attempt/'GUARD_RUN/RESULT.json').read_bytes())
        require(guard['status']=='failed' and guard['error']=="ModuleNotFoundError: No module named 'contracts'",'original failure changed')
        require(guard['sourceCommit']==SOURCE_COMMIT and guard['manifestSHA256']==ORIGINAL_MANIFEST and guard['pins']==oldpins,'original execution source binding')
        require(guard['inputHashesBefore']==guard['inputHashesAfter']==oldpins['inputs'],'original before/after input pins')
        for name,digest in oldpins['inputs'].items():require(sha(expand(name))==digest,'original input no longer unchanged: '+name)
        require([(c['label'],c['exitCode'],c['groupRetired']) for c in guard['commands']]==[('source-controls',0,True),('controls',0,True),('comparison',0,True)],'command completion/retirement')
        require(guard['sourceControlsExecuted']==6 and guard['controlsExecuted']==32,'control count evidence')
        require(guard['aggregateCPUSeconds']<120 and guard['wallSeconds']<180 and guard['peakObservedAggregateRSS']<1024**3,'original resource limits')
        require(not any(k in guard for k in ('postPinError','resourceError','inventoryError','terminalInventoryStatus')),'additional aggregate failures')
        for name,row in guard['finalPayloadInventory'].items():
            if name.endswith('/'):require((attempt/name).is_dir(),'terminal directory missing');continue
            require((attempt/name).stat().st_size==row['bytes'] and sha(attempt/name)==row['sha256'],'terminal output changed: '+name)
        for label,count in (('source-controls',6),('controls',32)):
            require(re.search(r'\nRan '+str(count)+r' tests in [^\n]+\n\nOK\n\Z',(attempt/('GUARD_RUN/'+label+'.stderr')).read_text()) is not None,'control completion text')
        spec=importlib.util.spec_from_file_location('explicit_conference_fixed_guard',H/'run_aggregate_isolated.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        prefix='research/conference-body-source-20261029/'
        contracts=module.load_frozen_contracts(OLD,oldpins['inputs'][prefix+'contracts.py'],oldpins['inputs'][prefix+'schedule_source.py'])
        frozen=strict_json((OLD/'ROUTES.json').read_bytes());receipt=strict_json((attempt/'comparison/RECEIPT.json').read_bytes())
        contracts.validate_receipt(receipt,frozen)
        require(receipt['pinsSHA256']==ORIGINAL_MANIFEST,'worker manifest binding')
        require(contracts.select_routes(strict_json(expand(oldpins['proposalPath']).read_bytes()))==frozen,'source chain choice')
        heights,registration=registered_source(oldpins,contracts)
        stream=validate_stream(attempt/'comparison/CONTACTS.jsonl.gz',receipt,frozen,contracts,heights,budget)
        require(not any(name in sys.modules for name in ('numpy','vtk','scipy')),'unexpected scientific/native import')
        verify();budget()
        result.update(status='COMPLETED_WORKER_EVIDENCE_RECONCILED_AGGREGATE_STILL_FAILED',
          originalAggregateSourceCommit=SOURCE_COMMIT,originalAggregateManifestSHA256=ORIGINAL_MANIFEST,
          originalAggregateError=guard['error'],originalGuardCPUSeconds=guard['aggregateCPUSeconds'],
          originalGuardWallSeconds=guard['wallSeconds'],workerReceiptStatus=receipt['status'],
          unchangedOriginalInputCount=len(oldpins['inputs']),originalControlsVerified=38,
          allOriginalCommandGroupsRetired=True,registeredMesh=registration,completeStream=stream,
          limitations=['Post-run stdlib reconciliation does not replace the failed aggregate run.',
            'VTK intersections were not recomputed; recorded contacts are the completed native worker evidence.',
            'Near-foot first-witness labels are not semantic floors or complete hit-height classification.',
            'Retained 2 mm lower-body exclusion can miss lower contacts; no tiny-object guarantee.',
            'No physical travel, support, arrival, registration accuracy or safe clearance is established.'])
    except BaseException as exc:
        result.update(status='POSTRUN_VALIDATION_FAILED',error=type(exc).__name__+': '+str(exc));raise
    finally:
        result.update(validationCPUSeconds=time.process_time()-cpu0,validationWallSeconds=time.monotonic()-began,
                      peakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024)
        data=json.dumps(result,indent=2,allow_nan=False)+'\n';require(len(data.encode())<262144,'validation output cap')
        (out/'VALIDATION.json').write_text(data)
    print(json.dumps({'status':result['status'],'events':result['completeStream']['events'],
                      'originalAggregateOutcome':'failed','nativeRerun':False}),flush=True)
if __name__=='__main__':main()
