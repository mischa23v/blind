#!/usr/bin/env python3
"""Recount saved evidence only; standard library, no native import/query or rerun."""
import ast, collections, gzip, hashlib, json, math, pathlib, re, struct

H=pathlib.Path(__file__).resolve().parent
REPO=H.parents[1]
WORKSPACE=REPO.parent
ATTEMPT=WORKSPACE/'coffee-joint-route-body-attempt-001'
CANDIDATE=REPO/'research/coffee-room-journey-recovery-20261029/collision-protocol/joint-route-body-candidate'

def digest(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def read(path):return json.loads(path.read_text())

def main():
    guard=read(ATTEMPT/'GUARD_RUN/RESULT.json')
    receipt=read(ATTEMPT/'comparison/RECEIPT.json')
    pins=read(CANDIDATE/'JOINT_ROUTE_RUN_PINS.json')
    assert guard['status']=='completed-zero-exit' and receipt['status']=='diagnosticCompleted'
    assert guard['physicalAuthority'] is False
    assert all(receipt[key] is False for key in ('physicalAuthority','continuousSupportProven','semanticFloorEstablished','coverageEstablished','movementEpisode'))
    assert receipt['sourceContract']==pins['sourceContract']
    assert all(receipt[key]==value for key,value in guard['comparison'].items())
    assert guard['manifestSHA256']==digest(CANDIDATE/'JOINT_ROUTE_RUN_PINS.json')
    assert guard['inputHashesBefore']==guard['inputHashesAfter']==pins['inputs']==guard['pins']['inputs']
    assert len(pins['inputs'])==75
    for name,expected in pins['inputs'].items():
        path=pathlib.Path(name.replace('@WORKSPACE@',str(WORKSPACE)))
        if not path.is_absolute():path=REPO/path
        assert digest(path)==expected,name
    for command in guard['commands']:
        assert command['exitCode']==0 and command['groupRetired'] is True
    assert [c['label'] for c in guard['commands']]==['source-controls','compile','dependency-elf','wrapper-elf','controls','comparison']
    for stage in guard['nativeBoundaryChecks']:
        assert all(value==pins['inputs'][name] for name,value in stage['inputHashes'].items())
        if stage['wrapperSHA256'] is not None:assert stage['wrapperSHA256']==guard['compiledWrapperSHA256']
    inventoryFiles=0;payloadBytes=0
    for name,record in guard['finalPayloadInventory'].items():
        if name.endswith('/'):continue
        path=ATTEMPT/name
        assert path.stat().st_size==record['bytes'] and digest(path)==record['sha256'],name
        inventoryFiles+=1;payloadBytes+=record['bytes']
    for label,count in [('source-controls',6),('controls',67)]:
        text=(ATTEMPT/'GUARD_RUN'/f'{label}.stderr').read_text()
        assert re.search(r'\nRan '+str(count)+r' tests in [^\n]+\n\nOK\n\Z',text)
    schedule=read(CANDIDATE/'SCHEDULE_0_8.json')['paths'][0]
    events=schedule['events'];assert len(events)==1644 and len(schedule['chain'])==144
    rows=[json.loads(line) for line in gzip.open(ATTEMPT/'comparison/CONTACTS.jsonl.gz','rt')]
    assert len(rows)==3301
    for row in rows:
        assert row['path']==[0,8]
        assert row['routePinsSHA256']==pins['routePinsSHA256']
        assert row['routeProposalSHA256']==pins['routeProposalSHA256']
        assert row['groundAdjacencyMode']==pins['groundAdjacencyMode']
        assert row['triangleEligibilityPolicy']==pins['triangleEligibilityPolicy']
        contacts=row.get('contacts',[])
        for contact in contacts if isinstance(contacts,list) else [contacts]:
            assert contact['bodyDimensionsWidthDepthHeight']==[.45,.30,1.60]
            assert contact['horizontalMarginMetres']==.15 and contact['marginExtendsVerticalHeight'] is False
            assert contact['physicalAuthority'] is False
            for mode in ('actualBody','horizontalMargin'):
                assert contact[mode]['sweep']['floorContactExclusionMetres']==.002
                assert contact[mode]['physicalClearanceEstablished'] is False
    ground=next(r for r in rows if r['arm']=='B_initial')
    assert ground['failure'] is None and ground['probes']['hitCount']==9
    assert ground['finiteSupport']['acceptedFiniteSupportModel'] is True
    raw=(ATTEMPT/'comparison/GROUND_IDS_0_8.npy').read_bytes()
    assert raw[:8]==b'\x93NUMPY\x01\x00'
    size=struct.unpack('<H',raw[8:10])[0];header=ast.literal_eval(raw[10:10+size].decode())
    assert header=={'descr':'<i8','fortran_order':False,'shape':(4827,)}
    groundIDs=set(struct.unpack('<'+'q'*4827,raw[10+size:]))
    assert len(groundIDs)==ground['ground']['groundCellCount']==4827
    vertices=[];faces=[]
    for line in (WORKSPACE/'coffee-recovered-source/textured.obj').open():
        fields=line.split()
        if fields and fields[0]=='v':vertices.append([float(v) for v in fields[1:]])
        elif fields and fields[0]=='f':faces.append([int(v.split('/')[0])-1 for v in fields[1:]])
    def witness(event,part,contact):
        face=contact['firstReferenceCellID'];a,b,c=[vertices[i] for i in faces[face]]
        u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
        normal=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
        ny=normal[1]/math.sqrt(sum(x*x for x in normal))
        return {'eventZeroBased':event,'eventKind':events[event]['kind'],
                'segmentZeroBased':events[event]['edge'],'sweepPartZeroBased':part,
                'originalFaceID':face,'wholeTriangleHeightAboveSweepStartFootMetres':contact['firstTriangleHeightRelativeToStartFootRange'],
                'sourceFloat64SignedSlopeDegrees':math.degrees(math.acos(ny)),
                'memberOfSavedGroundComponent':face in groundIDs,
                'heightIsNotContactPoint':True,'firstIsLocatorOrderNotContactTime':True}
    arms={};byArm={}
    for arm in ('A_raw_identity','B_translated_labels_only','C_ground_follow'):
        selected=[r for r in rows if r['arm']==arm];byArm[arm]=selected
        expectedEvents=1644 if arm!='C_ground_follow' else 11
        assert [r['event'] for r in selected]==list(range(expectedEvents))
        result={'events':len(selected),'modes':{}}
        for mode in ('actualBody','horizontalMargin'):
            flat=[(r['event'],i,c[mode]) for r in selected for i,c in enumerate(r['contacts'] if isinstance(r['contacts'],list) else [r['contacts']])]
            for _,_,c in flat:
                assert c['rawContactCount']==c['groundContactCount']+c['nonGroundContactCount']
                assert c['contact']==bool(c['nonGroundContactCount']) and c['completeCandidateContactCounts'] is True
            hits=[(e,i,c) for e,i,c in flat if c['nonGroundContactCount']]
            result['modes'][mode]={
                'sweepQueries':len(flat),
                'eventsWithRawOverlaps':len({e for e,i,c in flat if c['rawContactCount']}),
                'eventsWithGroundOverlaps':len({e for e,i,c in flat if c['groundContactCount']}),
                'eventsWithNonGroundOverlaps':len({e for e,i,c in hits}),
                'sweepsWithNonGroundOverlaps':len(hits),
                'rawTriangleQueryOverlapOccurrences':sum(c['rawContactCount'] for _,_,c in flat),
                'groundTriangleQueryOverlapOccurrences':sum(c['groundContactCount'] for _,_,c in flat),
                'nonGroundTriangleQueryOverlapOccurrences':sum(c['nonGroundContactCount'] for _,_,c in flat),
                'candidateTriangleQueryOccurrences':sum(c['candidateTriangles'] for _,_,c in flat),
                'nonGroundEventKinds':dict(collections.Counter(events[e]['kind'] for e in sorted({e for e,_,_ in hits}))),
                'firstNonGroundWitness':witness(*hits[0]) if hits else None}
        arms[arm]=result
    for a,b in zip(byArm['A_raw_identity'],byArm['B_translated_labels_only']):
        assert b['rawCountsEqualIdentity'] is True
        for mode in ('actualBody','horizontalMargin'):assert a['contacts'][mode]['rawContactCount']==b['contacts'][mode]['rawContactCount']
    boxCount=sum(m['sweepQueries'] for arm in arms.values() for m in arm['modes'].values())
    triangleCount=sum(m['candidateTriangleQueryOccurrences'] for arm in arms.values() for m in arm['modes'].values())
    rayCount=9+sum(c['hitCount']+c['missingCount'] for r in byArm['C_ground_follow'] for c in r.get('support',[]))
    assert {'boxes':boxCount,'triangles':triangleCount,'rays':rayCount}==receipt['counters']==guard['comparison']['counters']
    start=next(r for r in rows if r['arm']=='C_start');state=start['adjustedLocalStart']
    distance=xz=turnY=0.;translations=acceptedTurns=0
    for row in byArm['C_ground_follow']:
        if any(c[m]['nonGroundContactCount'] for c in row['contacts'] for m in ('actualBody','horizontalMargin')):break
        if 'adjustedMidLocal' not in row:continue
        mid,end=row['adjustedMidLocal'],row['adjustedEndLocal']
        assert all(c['acceptedFiniteSupportModel'] and c['groundComponentConfirmedForAllProbes'] for c in row['support'])
        if events[row['event']]['kind']=='translate':
            distance+=math.dist(state,mid)+math.dist(mid,end)
            xz+=math.dist(state[::2],mid[::2])+math.dist(mid[::2],end[::2]);translations+=1
        else:turnY+=abs(state[1]-mid[1])+abs(mid[1]-end[1]);acceptedTurns+=1
        state=end
    c=receipt['arms'][2]
    assert translations==c['acceptedModeledTranslationIncrements']==1 and acceptedTurns==8
    assert distance==c['acceptedModeled3DDistanceMetres'] and xz==c['acceptedModeledXZDistanceMetres'] and turnY==c['acceptedTurnVerticalAdjustmentMetres']
    assert c['refusalPhase']=='proposedIncrementContact' and c['arrivalClaimed'] is False and c['completedFrozenSchedule'] is False
    assert c['physicalTravelObserved'] is False and receipt['movementEpisode'] is False
    proposals=read(WORKSPACE/'coffee-clearance-comparison-attempt-003/comparison/PROPOSALS.json')
    proposal=next(p for p in proposals['paths'] if (p['start'],p['goal'])==(0,8))['manualRepair']['clearanceGrid']
    assert proposal['requestedConnectorChainXYZ']==schedule['chain']
    manual=proposal['independentManualWindowDiagnostic'];checks=[w for segment in manual['segments'] for w in segment['windows']]
    assert len(manual['segments'])==143 and len(checks)==286 and not any(w['body_margin_contact'] for w in checks)
    report={'schema':1,'status':'diagnostic-completed-route-not-accepted','sourceCommit':guard['sourceCommit'],
        'runManifestSHA256':guard['manifestSHA256'],'routePinsSHA256':pins['routePinsSHA256'],
        'scheduleSHA256':digest(CANDIDATE/'SCHEDULE_0_8.json'),'proposalSHA256':pins['routeProposalSHA256'],
        'route':{'pair':[0,8],'points':144,'segments':143,'scheduledEvents':1644},
        'verification':{'inputPinsChecked':75,'beforeAfterAndCurrentPinsMatch':True,'commandsExitedZeroAndRetired':len(guard['commands']),
            'nativeBoundaryChecks':len(guard['nativeBoundaryChecks']),'terminalInventoryFilesVerified':inventoryFiles,'terminalPayloadBytes':payloadBytes,
            'sourceControlsPassed':6,'nativeControlsPassed':67,'all1644EventRawCountsEqualBetweenAandB':True},
        'aggregate':{'cpuSeconds':guard['aggregateCPUSeconds'],'wallSeconds':guard['wallSeconds'],'peakObservedRSSBytes':guard['peakObservedAggregateRSS'],
            'limits':guard['limits']},'recountedQueryCounters':receipt['counters'],'contactRows':len(rows),'arms':arms,
        'groundInitialization':{'supportHits':9,'allInitialSeedsRequired':True,'componentFaceCount':4827,'semanticFloorEstablished':False},
        'CProgress':{k:c[k] for k in ('events','attemptedEvents','status','refusalPhase','acceptedModeledTranslationIncrements','acceptedModeled3DDistanceMetres',
            'acceptedModeledXZDistanceMetres','acceptedTurnVerticalAdjustmentMetres','completedFrozenSchedule','arrivalClaimed','physicalTravelObserved')},
        'CAdditionalProgressScope':{'acceptedTurns':acceptedTurns,'initialVerticalCorrectionMetres':start['verticalCorrection'],
            'initialCorrectionCountsAsTravel':False,'acceptedTranslationIsOnlyTinyInitialConnector':True,'meaningfulRouteTravelEstablished':False},
        'manual2DComparison':{'savedChecks':len(checks),'contacts':0,'minimumResidualMetres':min(w['clearance_after_body_and_margin_metres'] for w in checks),
            'circleRadiusMetres':math.hypot(.225,.15)+.15,'scope':'two manual exclusions only, not measured complete tables',
            'threeDMarginBoxHalfExtentsMetres':[.30,.375],'threeDMarginBoxCornerRadiusBeforeSweepPaddingMetres':math.hypot(.30,.375),
            'identicalMarginShape':False,'identicalObstacleScope':False},
        'evidenceDigests':{name:digest(ATTEMPT/name) for name in ('GUARD_RUN/RESULT.json','comparison/RECEIPT.json','comparison/CONTACTS.jsonl.gz')},
        'limitations':['Counts are repeated triangle-query overlap occurrences, not unique obstacles or physical impacts.',
            'Margin query includes the nominal body volume; it is not a disjoint shell.',
            'Conservative swept enclosure overlaps are not exact-body time-of-impact measurements.',
            'First witness is locator order within a query, not first physical contact; whole-triangle height is not a contact point.',
            'Only first non-ground face identity per mode/sweep is logged; other hit identities/heights are not reconstructible from counts.',
            'Witness slope is source-float64 arithmetic only, not a rerun of the float32 native classifier.',
            'No semantic object/floor labels, complete support, missing-mesh coverage, physical travel, clearance or device acceptance.']}
    (H/'PUBLIC_SAFE_RESULT.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    print(json.dumps({'status':report['status'],'savedRowsRecounted':len(rows),'pinsVerified':75,'nativeRerun':False}))

if __name__=='__main__':main()
