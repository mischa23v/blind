#!/usr/bin/env python3
"""Saved-data/stdlib recount only. Never reruns the failed aggregate or geometry."""
import collections, gzip, hashlib, json, pathlib, re, struct, sys

H=pathlib.Path(__file__).resolve().parent
REPO=H.parents[1];WORKSPACE=REPO.parent
ATTEMPT=WORKSPACE/'conference-body-comparison-attempt-001'
SOURCE=REPO/'research/conference-body-source-20261029'
ORIGINAL_MANIFEST='ed735949ea0d21bf0fbf64754980a61d67d8b8095193b11d5ba72920dc8d6dc9'

def read(p):return json.loads(p.read_text())
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
    guard=read(ATTEMPT/'GUARD_RUN/RESULT.json');receipt=read(ATTEMPT/'comparison/RECEIPT.json')
    assert guard['status']=='failed' and guard['error']=="ModuleNotFoundError: No module named 'contracts'"
    assert guard['sourceCommit']=='c204b0e63e4c7444c02ea8ccf50e347693a15684'
    assert guard['manifestSHA256']==receipt['pinsSHA256']==ORIGINAL_MANIFEST
    pins=guard['pins']['inputs']
    assert len(pins)==32 and guard['inputHashesBefore']==guard['inputHashesAfter']==pins
    assert hashlib.sha256((json.dumps(guard['pins'],indent=2)+'\n').encode()).hexdigest()==ORIGINAL_MANIFEST
    for name,digest in pins.items():
        p=pathlib.Path(name.replace('@WORKSPACE@',str(WORKSPACE)))
        if not p.is_absolute():p=REPO/p
        assert sha(p)==digest,name
    assert [r['label'] for r in guard['commands']]==['source-controls','controls','comparison']
    assert all(r['exitCode']==0 and r['groupRetired'] is True for r in guard['commands'])
    assert not any(k in guard for k in ('postPinError','inventoryError','resourceError'))
    for label,count in [('source-controls',6),('controls',32)]:
        assert re.search(r'\nRan '+str(count)+r' tests in [^\n]+\n\nOK\n\Z',(ATTEMPT/'GUARD_RUN'/f'{label}.stderr').read_text())
    inventoryFiles=payload=0
    for name,record in guard['finalPayloadInventory'].items():
        if name.endswith('/'):continue
        p=ATTEMPT/name
        assert p.stat().st_size==record['bytes'] and sha(p)==record['sha256'],name
        inventoryFiles+=1;payload+=record['bytes']
    assert inventoryFiles==8 and payload==1141964
    frozen=read(SOURCE/'ROUTES.json')
    # This scheduler source is still byte-identical to the executed source pin.
    sys.path.insert(0,str(SOURCE));from schedule_source import make_schedule
    schedules={row['name']:make_schedule(row['chain']) for row in frozen['paths']}
    for row in frozen['paths']:
        encoded=(json.dumps(schedules[row['name']],separators=(',',':'),allow_nan=False)+'\n').encode()
        assert hashlib.sha256(encoded).hexdigest()==row['scheduleSHA256']
    reg=read(REPO/'research/conference-replay-input-inventory-20261029/evidence/REGISTRATION_RESULT.json')
    q=reg['rotationOBJToLevel'];t=reg['translationOBJToLevel'];ys=[];faces=[];vb=bytearray();tb=bytearray()
    for line in (WORKSPACE/'conference-source-recovery/extracted-001/textured.obj').open():
        f=line.split()
        if f and f[0]=='v':
            xyz=list(map(float,f[1:]));level=[sum(xyz[k]*q[j][k] for k in range(3))+t[j] for j in range(3)]
            data=struct.pack('<fff',level[0],level[2],-level[1]);vb.extend(data);ys.append(struct.unpack('<fff',data)[1])
        elif f and f[0]=='f':
            face=[int(v.split('/')[0])-1 for v in f[1:]];faces.append(face);tb.extend(struct.pack('<iii',*face))
    assert hashlib.sha256(vb).hexdigest()==receipt['registeredFloat32VerticesSHA256']
    assert hashlib.sha256(tb).hexdigest()==receipt['trianglesInt32SHA256']
    names=[r['name'] for r in frozen['paths']];modeNames=('actualBody','horizontalMargin')
    counts={name:{mode:collections.Counter() for mode in modeNames} for name in names}
    ranges={};examples={};first={};nextEvent={name:0 for name in names};order=[];logical=0
    def witness(row,c):
        return {'eventZeroBased':row['event'],'kind':row['authoredIncrement']['kind'],
            'originalFaceID':c['firstReferenceCellID'],'rawOverlapOccurrencesInQuery':c['rawContactCount'],
            'wholeTriangleAboveStartFootMetres':c['firstTriangleHeightRelativeToStartFootRange'],
            'wholeTriangleAboveEndFootMetres':c['firstWitnessWholeTriangleHeightRelativeToEndFootRange']}
    with gzip.open(ATTEMPT/'comparison/CONTACTS.jsonl.gz','rt') as stream:
        for line in stream:
            logical+=len(line.encode());row=json.loads(line);name=row['path'];event=row['event']
            if not order or order[-1]!=name:order.append(name)
            assert event==nextEvent[name];nextEvent[name]+=1
            assert row['authoredIncrement']==schedules[name]['events'][event]
            contacts=row['contacts']
            assert contacts['bodyDimensionsWidthDepthHeight']==[.45,.30,1.6]
            assert contacts['horizontalMarginMetres']==.15 and contacts['marginExtendsVerticalHeight'] is False
            for mode in modeNames:
                c=contacts[mode];n=counts[name][mode]
                assert c['groundContactCount']==0 and c['groundContactFaceIDsFirst16']==[] and c['groundContactFaceIDsTruncated'] is False
                assert c['rawContactCount']==c['nonGroundContactCount'] and c['contact']==bool(c['rawContactCount'])
                assert c['completeCandidateContactCounts'] is True and c['physicalAuthority'] is False
                assert c['sweep']['floorContactExclusionMetres']==.002
                n['queries']+=1;n['rawOverlapOccurrences']+=c['rawContactCount'];n['candidateTriangles']+=c['candidateTriangles']
                if not c['contact']:continue
                n['contactEvents']+=1;n['kind_'+row['authoredIncrement']['kind']]+=1
                height=[min(ys[i] for i in faces[c['firstReferenceCellID']]),max(ys[i] for i in faces[c['firstReferenceCellID']])]
                assert height==c['firstTriangleModelHeightRange']
                relative=[v-row['authoredIncrement']['a'][1] for v in height]
                assert relative==c['firstTriangleHeightRelativeToStartFootRange']
                assert [v-row['authoredIncrement']['b'][1] for v in height]==c['firstWitnessWholeTriangleHeightRelativeToEndFootRange']
                near=all(abs(v)<=.025 for v in relative);high=relative[0]>=.5
                assert near==c['firstWitnessWithin25mmOfStartFootPlane']
                n['firstWitnessWithin25mm']+=near;n['firstWitnessEntirelyAtLeast500mmAboveStartFoot']+=high
                n['otherOrMixedFirstWitnessRange']+=not(near or high)
                n['multiHitEvents']+=c['rawContactCount']>1;n['unidentifiedOtherOverlapOccurrences']+=c['rawContactCount']-1
                key=(name,mode);first.setdefault(key,witness(row,c))
                if high:examples.setdefault(key,witness(row,c))
                if key not in ranges:ranges[key]=relative.copy()
                else:ranges[key]=[min(ranges[key][0],relative[0]),max(ranges[key][1],relative[1])]
    assert order==names and sum(nextEvent.values())==13704 and logical==receipt['outputLogicalBytes']==41413079
    assert receipt['status']=='rawDiagnosticCompleted' and receipt['error'] is None
    assert all(receipt[k] is False for k in ('physicalAuthority','continuousSupportProven','semanticFloorEstablished','coverageEstablished','movementEpisode','arrivalClaimed','validatedCameraMeshAlignment'))
    results=[]
    for source,actual in zip(frozen['paths'],receipt['paths']):
        name=source['name'];assert actual['name']==name and actual['status']=='rawDiagnosticComplete'
        assert nextEvent[name]==actual['completedEvents']==source['eventCount']==actual['scheduledEvents']
        assert source['scheduleSHA256']==actual['scheduleSHA256']
        modes={}
        for mode in modeNames:
            n=counts[name][mode]
            assert n['contactEvents']==actual['contactEvents'][mode]
            assert n['firstWitnessWithin25mm']==actual['firstWitnessNearFootBandEvents'][mode]
            modes[mode]={'counts':dict(n),'firstWitnessRangeEnvelopeMetres':ranges.get((name,mode)),
                'firstContactWitness':first.get((name,mode)),'firstAtLeast500mmWitness':examples.get((name,mode))}
        results.append({'name':name,'completedEvents':nextEvent[name],'modes':modes})
    totals={mode:sum((counts[name][mode] for name in names),collections.Counter()) for mode in modeNames}
    assert sum(t['queries'] for t in totals.values())==receipt['counters']['boxes']==27408
    assert sum(t['candidateTriangles'] for t in totals.values())==receipt['counters']['triangles']==8710095
    assert receipt['counters']['rays']==0 and receipt['groundExemptedFaceCount']==0
    report={'schema':1,'status':'worker-complete-aggregate-failed-preserved','sourceCommit':guard['sourceCommit'],
        'executedManifestSHA256':ORIGINAL_MANIFEST,'aggregateStatus':guard['status'],'aggregateError':guard['error'],
        'workerStatus':receipt['status'],'workerError':None,
        'verification':{'frozenInputPinsBeforeAfterMatch':32,'commandsExitedZeroAndRetired':3,'sourceControlsPassed':6,'kernelControlsPassed':32,
            'terminalPayloadFilesVerified':inventoryFiles,'terminalPayloadBytesExcludingGuardReceipt':payload,
            'allSevenSchedulesExactlyRecounted':True,'registeredMeshAndEveryFirstWitnessHeightReproducedWithStdlib':True,
            'currentFrozenInputsMatch':32,'executedSourceUnmodified':True},
        'aggregateResources':{'cpuSeconds':guard['aggregateCPUSeconds'],'wallSeconds':guard['wallSeconds'],
            'peakObservedRSSBytes':guard['peakObservedAggregateRSS'],'limits':guard['limits']},
        'workerQueries':receipt['counters'],'events':13704,'logicalContactLogBytes':logical,
        'totals':{k:dict(v) for k,v in totals.items()},'paths':results,
        'witnessScope':{'nonGroundWitnessIDsPerContactQuery':1,'allHitIdentitiesLogged':False,'groundIDsFirst16AlwaysEmpty':True,
            'wholeTriangleHeightNotContactPoint':True,'locatorFirstNotEarliestContact':True,
            'nearFootBandMetres':[-.025,.025],'higherWitnessLowerBoundMetres':.5,
            'bandsAreReportingOnlyNotSemanticFloorOrExemptions':True},
        'physicalAuthority':False,'movementEpisode':False,'arrivalClaimed':False,
        'evidenceDigests':{name:sha(ATTEMPT/name) for name in ('GUARD_RUN/RESULT.json','comparison/RECEIPT.json','comparison/CONTACTS.jsonl.gz')},
        'limits':['The aggregate failure is preserved; recounting does not turn it into a successful original aggregate.',
            'Raw overlap occurrences repeat across events and envelopes; they are not unique physical obstacles or impacts.',
            'Unknown other-hit identities/heights cannot inherit the first witness classification.',
            'Nominal-body first witnesses being low does not establish that all nominal-body hits were low.',
            'Margin volumes include nominal bodies; body/margin counts cannot be added as independent physical impacts.',
            'Historical estimated registration, authored foot/yaw, conservative sweeps and 2 mm lower trim are not actual body pose or complete floor/support evidence.',
            'Missing mesh surfaces and present-world obstacles remain unknown; no route or child-use safety certification.']}
    (H/'PUBLIC_SAFE_RESULT.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    print(json.dumps({'eventsRecounted':13704,'aggregateFailurePreserved':True,'nativeRerun':False,'bodyContactEvents':totals['actualBody']['contactEvents'],'marginContactEvents':totals['horizontalMargin']['contactEvents']}))

if __name__=='__main__':main()
