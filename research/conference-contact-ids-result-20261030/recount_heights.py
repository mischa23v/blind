#!/usr/bin/env python3
"""Read-only stdlib complete-ID recount. No VTK/intersection rerun or ground labels."""
import argparse, gzip, hashlib, json, math, os, pathlib, resource, stat, struct, sys, time
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
SOURCE='e9bfe8deefd7b91494aec0c77afb5787f3913712'
MANIFEST='94fb3b077aca01dc0fc35c9dcbfdbde8ad5d0eb6013f02ad2ed3a43f73bf1905'
VERTICES='50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb'
TRIANGLES='2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324'
ARMS=('actualBody','horizontalMargin');REFS=('startFoot','endFoot')
def require(condition,message):
    if not condition:raise ValueError(message)
def sha(path):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    try:
        s=os.fstat(fd);require(stat.S_ISREG(s.st_mode),'not regular')
        with os.fdopen(os.dup(fd),'rb')as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
        e=os.fstat(fd);require((s.st_size,s.st_mtime_ns,s.st_ctime_ns)==(e.st_size,e.st_mtime_ns,e.st_ctime_ns),'file changed during hash')
        return digest
    finally:os.close(fd)
def expand(name):
    name=name.replace('@WORKSPACE@',str(W)).replace('@REPO@',str(R))
    return pathlib.Path(name) if name.startswith('/') else R/name
def loads(data):
    def pairs(items):
        result={}
        for k,v in items:require(k not in result,'duplicate JSON field');result[k]=v
        return result
    def constant(value):raise ValueError('nonfinite JSON token '+value)
    return json.loads(data,object_pairs_hook=pairs,parse_constant=constant)
def emit(path,value):path.write_text(json.dumps(value,indent=2,allow_nan=False)+'\n')
def frozen_schedule(source,pins):
    name='research/conference-body-source-20261029/schedule_source.py';p=R/name
    data=p.read_bytes();require(hashlib.sha256(data).hexdigest()==pins['inputs'][name],'scheduler byte pin')
    namespace={'__name__':'exact_frozen_schedule','__file__':str(p)};exec(compile(data,str(p),'exec'),namespace)
    schedule=namespace['make_schedule'](source['chain'])
    encoded=(json.dumps(schedule,separators=(',',':'),allow_nan=False)+'\n').encode()
    require(hashlib.sha256(encoded).hexdigest()==source['scheduleSHA256'],'exact event schedule digest')
    return schedule['events']
def source_heights(pins):
    reg=loads(expand(pins['registrationPath']).read_bytes());Q=reg['rotationOBJToLevel'];t=reg['translationOBJToLevel']
    vs=[];faces=[];vhash=hashlib.sha256();fhash=hashlib.sha256()
    for line in expand(pins['meshPath']).open():
        q=line.split()
        if not q:continue
        if q[0]=='v':
            require(len(q)==4,'vertex shape');p=list(map(float,q[1:]));require(all(math.isfinite(x)for x in p),'finite source')
            v=[sum(Q[i][j]*p[j]for j in range(3))+t[i]for i in range(3)]
            data=struct.pack('<fff',v[0],v[2],-v[1]);vhash.update(data);vs.append(struct.unpack('<fff',data))
        elif q[0]=='f':
            require(len(q)==4,'triangle shape');f=[int(x.split('/')[0])-1 for x in q[1:]]
            fhash.update(struct.pack('<iii',*f));faces.append(f)
    require((len(vs),len(faces))==(18398,29366),'source cardinality')
    require(vhash.hexdigest()==VERTICES and fhash.hexdigest()==TRIANGLES,'exact executed Float32 mesh byte reproduction')
    return [[min(vs[i][1]for i in f),max(vs[i][1]for i in f)]for f in faces]
def new_reference():
    return {'events':{'contact':0,'noContact':0,'allHitsNearFoot':0,'anyNotNearFoot':0,'anyWhollyAtLeast0_5m':0},
            'occurrences':{'nearFoot25mm':0,'whollyAtLeast0_5m':0,'other':0,
                           'straddlesNearFootBoundarySubset':0,'straddles0_5mBoundarySubset':0},
            'uniqueIDs':{k:set()for k in ('nearFoot25mm','whollyAtLeast0_5m','other',
                         'straddlesNearFootBoundarySubset','straddles0_5mBoundarySubset')},
            'relativeWholeTriangleHeightLimits':[None,None]}
def new_arm():
    return {'events':0,'hitOccurrences':0,'uniqueIDs':set(),
            'registeredWholeTriangleHeightLimits':[None,None],
            'startFootHeightLimits':[None,None],'endFootHeightLimits':[None,None],
            'references':{r:new_reference()for r in REFS},
            'eventsAllHitsNearBothFootReferences':0,'eventsAnyHitNotNearAtLeastOneFootReference':0,
            'occurrencesNearBothFootReferences':0}
def bounds_update(bounds,lo,hi):
    bounds[0]=lo if bounds[0] is None else min(bounds[0],lo)
    bounds[1]=hi if bounds[1] is None else max(bounds[1],hi)
def classify(lo,hi):
    near=lo>=-.025 and hi<=.025
    high=lo>=.5
    category='nearFoot25mm' if near else 'whollyAtLeast0_5m' if high else 'other'
    near_straddle=(lo<-.025<=hi) or (lo<=.025<hi)
    high_straddle=lo<.5<=hi
    return category,near_straddle,high_straddle
def accumulate(arm,ids,event,heights):
    arm['events']+=1;arm['hitOccurrences']+=len(ids);arm['uniqueIDs'].update(ids)
    all_both=bool(ids)
    for ref,key in (('startFoot','a'),('endFoot','b')):
        foot=event[key][1];bounds_update(arm[ref+'HeightLimits'],foot,foot)
        r=arm['references'][ref]
        if not ids:r['events']['noContact']+=1;continue
        r['events']['contact']+=1;all_near=True;any_high=False
        for cid in ids:
            absolute=heights[cid];lo,hi=[x-foot for x in absolute]
            bounds_update(arm['registeredWholeTriangleHeightLimits'],*absolute)
            bounds_update(r['relativeWholeTriangleHeightLimits'],lo,hi)
            category,near_straddle,high_straddle=classify(lo,hi)
            r['occurrences'][category]+=1;r['uniqueIDs'][category].add(cid)
            all_near=all_near and category=='nearFoot25mm';any_high=any_high or category=='whollyAtLeast0_5m'
            for yes,label in ((near_straddle,'straddlesNearFootBoundarySubset'),(high_straddle,'straddles0_5mBoundarySubset')):
                if yes:r['occurrences'][label]+=1;r['uniqueIDs'][label].add(cid)
        r['events']['allHitsNearFoot' if all_near else 'anyNotNearFoot']+=1
        r['events']['anyWhollyAtLeast0_5m']+=any_high;all_both=all_both and all_near
    for cid in ids:
        if all(classify(heights[cid][0]-event[key][1],heights[cid][1]-event[key][1])[0]=='nearFoot25mm'for key in ('a','b')):
            arm['occurrencesNearBothFootReferences']+=1
    if ids:arm['eventsAllHitsNearBothFootReferences' if all_both else 'eventsAnyHitNotNearAtLeastOneFootReference']+=1
def finish_arm(arm):
    arm['uniqueFaceCount']=len(arm['uniqueIDs']);arm['uniqueIDs']=sorted(arm['uniqueIDs'])
    for r in arm['references'].values():
        r['uniqueFaceCounts']={k:len(v)for k,v in r['uniqueIDs'].items()}
        r['uniqueIDs']={k:sorted(v)for k,v in r['uniqueIDs'].items()}
        require(sum(r['occurrences'][k]for k in ('nearFoot25mm','whollyAtLeast0_5m','other'))==arm['hitOccurrences'],'exclusive band total')
        require(r['events']['allHitsNearFoot']+r['events']['anyNotNearFoot']==r['events']['contact'],'event partition')
    return arm
def finite_row(stream):
    data=stream.readline(65537);require(data and len(data)<=65536 and data.endswith(b'\n'),'missing/oversized/truncated row')
    return data,loads(data)
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--pins-sha256',required=True);ap.add_argument('--out',type=pathlib.Path,required=True);a=ap.parse_args()
    began=time.monotonic();cpu0=time.process_time();os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_CPU,(30,30));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    require(sha(H/'ANALYSIS_PINS.json')==a.pins_sha256,'analysis manifest')
    analysis=loads((H/'ANALYSIS_PINS.json').read_bytes())
    def verify():
        require(sha(H/'ANALYSIS_PINS.json')==a.pins_sha256,'analysis manifest changed')
        for n,d in analysis['inputs'].items():require(sha(expand(n))==d,'input changed: '+n)
    def budget():
        require(time.process_time()-cpu0<30 and time.monotonic()-began<60,'analysis time limit')
        require(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024<256*1024**2,'analysis observed RSS limit')
    verify();out=a.out.resolve();out.relative_to(W);out.mkdir(exist_ok=False)
    attempt=W/'conference-contact-ids-attempt-001';guard=loads((attempt/'GUARD_RUN/RESULT.json').read_bytes())
    pins=loads((R/'research/conference-contact-ids-source-20261030/SOURCE_PINS.json').read_bytes())
    require(guard['status']=='completed-zero-exit' and guard['sourceCommit']==SOURCE and guard['manifestSHA256']==MANIFEST,'actual source/status')
    require(guard['pins']==pins and guard['inputHashesBefore']==guard['inputHashesAfter']==pins['inputs'],'executed source pin equality')
    require([(x['label'],x['exitCode'],x['groupRetired'])for x in guard['commands']]==[(k,0,True)for k in ('isolation-controls','source-controls','recorder-source-controls','controls','comparison')],'five commands/retirement')
    require(guard['aggregateCPUSeconds']<120 and guard['wallSeconds']<180 and guard['peakObservedAggregateRSS']<1024**3,'actual aggregate bounds')
    for n,d in pins['inputs'].items():require(sha(expand(n))==d,'executed input no longer unchanged: '+n)
    for n,v in guard['finalPayloadInventory'].items():
        if n.endswith('/'):continue
        require((attempt/n).stat().st_size==v['bytes'] and sha(attempt/n)==v['sha256'],'terminal output identity: '+n)
    receipt=loads((attempt/'comparison/RECEIPT.json').read_bytes())
    require(receipt['status']=='rawDiagnosticCompleted' and receipt['pinsSHA256']==MANIFEST,'worker completed identity')
    for key in ('physicalAuthority','continuousSupportProven','semanticFloorEstablished','coverageEstablished','movementEpisode','arrivalClaimed','validatedCameraMeshAlignment'):
        require(receipt[key] is False,'authority boundary: '+key)
    require(receipt['bodyWidthDepthHeightMetres']==[.45,.3,1.6] and receipt['horizontalMarginMetres']==.15 and receipt['floorContactExclusionMetres']==.002,'unchanged dimensions/exclusion')
    heights=source_heights(pins)
    frozen=loads((R/'research/conference-body-source-20261029/ROUTES.json').read_bytes())
    expected=loads((R/'research/conference-contact-ids-source-20261030/EXPECTED_COUNTS.json').read_bytes())
    global_arms={k:new_arm()for k in ARMS};rows=[];events=hit_total=candidates=contact_bytes=id_bytes=0
    candidate_digest=hashlib.sha256();contact_digest=hashlib.sha256();id_digest=hashlib.sha256()
    old=W/'conference-body-comparison-attempt-001/comparison/CONTACTS.jsonl.gz'
    with gzip.open(attempt/'comparison/CONTACTS.jsonl.gz','rb')as contacts,gzip.open(attempt/'comparison/HIT_IDS.jsonl.gz','rb')as ids_stream,gzip.open(old,'rb')as old_stream:
        for route,counts_source,reported in zip(frozen['paths'],expected['paths'],receipt['paths']):
            require(route['name']==counts_source['name']==reported['name'],'ordered seven requests')
            arms={k:new_arm()for k in ARMS};schedule=frozen_schedule(route,pins);first_near={k:0 for k in ARMS};event_contacts={k:0 for k in ARMS}
            for n,event in enumerate(schedule):
                raw,c=finite_row(contacts);raw_ids,identity=finite_row(ids_stream);raw_old,old_row=finite_row(old_stream)
                require(raw==raw_old and c==old_row,'entire original per-event CONTACTS record differs')
                require(c['path']==identity['path']==route['name'] and c['event']==identity['event']==n,'complete log event order')
                require(c['authoredIncrement']==event,'exact authored increment')
                contact_bytes+=len(raw);id_bytes+=len(raw_ids);contact_digest.update(raw);id_digest.update(raw_ids)
                require(contact_bytes+id_bytes<=64*1024**2 and id_bytes<=8*1024**2,'logical output bounds')
                candidate_pair=[]
                for slot,arm in enumerate(ARMS):
                    hits=identity['actualBodyTriangleIDs' if arm=='actualBody' else 'horizontalMarginTriangleIDs'];r=c['contacts'][arm]
                    require(isinstance(hits,list) and len(hits)<=29366 and all(type(i)is int and 0<=i<29366 for i in hits),'bounded original hit IDs')
                    require(len(set(hits))==len(hits),'duplicate IDs in one query')
                    require(len(hits)==r['rawContactCount']==r['nonGroundContactCount']==counts_source['counts'][n][slot] and r['groundContactCount']==0,'old exact hit count mismatch')
                    require(type(r['candidateTriangles'])is int and len(hits)<=r['candidateTriangles']<=29366,'candidate bound')
                    require(r['contact'] is bool(hits),'contact flag mismatch')
                    candidate_pair.append(r['candidateTriangles']);hit_total+=len(hits)
                    require(hit_total<=200000,'global ID cap')
                    if hits:
                        require(hits[0]==r['firstReferenceCellID'],'first hit order mismatch')
                        require(heights[hits[0]]==r['firstTriangleModelHeightRange'],'first witness source heights mismatch')
                        relative=[v-event['a'][1]for v in heights[hits[0]]]
                        require(relative==r['firstTriangleHeightRelativeToStartFootRange'],'first witness start-relative height')
                        require([v-event['b'][1]for v in heights[hits[0]]]==r['firstWitnessWholeTriangleHeightRelativeToEndFootRange'],'first witness end-relative height')
                        near=classify(*relative)[0]=='nearFoot25mm';require(r['firstWitnessWithin25mmOfStartFootPlane'] is near,'old first-witness band')
                        first_near[arm]+=near;event_contacts[arm]+=1
                    else:require(r['firstReferenceCellID'] is None,'empty query witness')
                    accumulate(arms[arm],hits,event,heights);accumulate(global_arms[arm],hits,event,heights)
                candidate_digest.update(('%d,%d\n'%tuple(candidate_pair)).encode());candidates+=sum(candidate_pair);events+=1
                if events%128==0:budget()
            require(reported['completedEvents']==len(schedule) and reported['contactEvents']==event_contacts and reported['firstWitnessNearFootBandEvents']==first_near,'worker summary recount')
            row={'name':route['name'],'authoredEvents':len(schedule),'firstWitnessNearFootEvents':first_near,
                 'arms':{k:finish_arm(v)for k,v in arms.items()},'physicalAuthority':False}
            rows.append(row);emit(out/(route['name']+'.json'),row)
        require(contacts.read(1)==ids_stream.read(1)==old_stream.read(1)==b'','unexpected extra rows')
    require((events,hit_total,candidates)==(13704,108582,8710095),'complete aggregate recount')
    require(candidate_digest.hexdigest()==expected['candidateCountStreamSHA256']==receipt['hitRecorder']['candidateCountStreamSHA256'],'ordered per-event candidate equality')
    require(receipt['counters']=={'boxes':27408,'triangles':8710095,'rays':0},'worker counters')
    require(receipt['outputLogicalBytes']==contact_bytes and receipt['hitRecorder']['logicalBytes']==id_bytes,'logical byte counters')
    require(receipt['hitRecorder']['complete'] is True and receipt['hitRecorder']['allOldPerEventCountsMatched'] is True,'complete recorder contract')
    verify();budget();require(not any(x in sys.modules for x in ('numpy','vtk','scipy')),'native import occurred')
    totals={k:finish_arm(v)for k,v in global_arms.items()}
    summary={'status':'COMPLETE_ID_RECOUNT_AND_HEIGHT_BANDS_VERIFIED','sourceCommit':SOURCE,'sourceManifestSHA256':MANIFEST,
      'analysisManifestSHA256':a.pins_sha256,'originalAggregateStatus':'completed-zero-exit','originalEarlierBodyAggregateStatus':'failed',
      'sourcePinCount':len(pins['inputs']),'allFiveCommandsZeroAndRetired':True,'authoritativeMovementClaim':False,
      'aggregateCPUSeconds':guard['aggregateCPUSeconds'],'aggregateWallSeconds':guard['wallSeconds'],
      'aggregatePeakObservedRSSBytes':guard['peakObservedAggregateRSS'],'registeredFloat32VerticesSHA256':VERTICES,
      'trianglesInt32SHA256':TRIANGLES,'events':events,'boxes':27408,'triangleCandidates':candidates,
      'hitOccurrences':hit_total,'unionUniqueSourceFaceCount':len(set(totals['actualBody']['uniqueIDs'])|set(totals['horizontalMargin']['uniqueIDs'])),
      'oldCONTACTSRecordsByteIdentical':True,'decodedContactsSHA256':contact_digest.hexdigest(),
      'decodedIDsSHA256':id_digest.hexdigest(),'candidateCountStreamSHA256':candidate_digest.hexdigest(),
      'contactLogicalBytes':contact_bytes,'idLogicalBytes':id_bytes,'arms':totals,
      'bandDefinitions':{'nearFoot25mm':'whole triangle min>=footY-0.025 AND max<=footY+0.025, inclusive',
        'whollyAtLeast0_5m':'whole triangle min>=footY+0.5, inclusive',
        'other':'neither nearFoot25mm nor whollyAtLeast0_5m; retained, not discarded',
        'straddlesNearFootBoundarySubset':'lo<-0.025<=hi OR lo<=0.025<hi, subset counter not an exclusive fourth band',
        'straddles0_5mBoundarySubset':'lo<0.5<=hi, subset counter not an exclusive fourth band',
        'references':'calculated separately relative to authored start and end foot heights',
        'events':'no-hit events are separate, never vacuously all-near; all-hits-near and any-not-near partition contact events',
        'uniqueIDs':'source triangle IDs deduplicated across queries; a face may occur in different relative bands on different events'},
      'limitations':['Whole-triangle heights, not intersection-point heights; conservative OBB contacts may overcount exact body contact.',
        'Near-foot geometry is not a semantic floor label, an allowed contact or continuous support evidence.',
        'The retained 2 mm lower-body query exclusion can miss smaller/lower geometry; absence is not clearance.',
        'Original registration is a historical estimated comparator, not validated camera/body alignment.',
        'ID sets and repeated occurrences are different denominators; body and margin sets overlap.',
        'No native rerun; VTK intersection truth was not independently recomputed by this stdlib analysis.'],
      'nativeRerun':False,'physicalAuthority':False,'analysisCPUSeconds':time.process_time()-cpu0,
      'analysisWallSeconds':time.monotonic()-began,'analysisPeakRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024}
    emit(out/'SUMMARY.json',summary)
    print(json.dumps({'status':summary['status'],'events':events,'hitOccurrences':hit_total,
      'body':{r:totals['actualBody']['references'][r]['events']for r in REFS},
      'margin':{r:totals['horizontalMargin']['references'][r]['events']for r in REFS},
      'nativeRerun':False}),flush=True)
if __name__=='__main__':main()
