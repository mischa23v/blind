#!/usr/bin/env python3
"""Read-only audit derivation. Writes only this report directory; no test/build execution."""
import collections, hashlib, json, math
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RUNS = ROOT / 'research/native-path-recovery-20261028'
def read(p):
    return json.loads(p.read_text())
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
def record(p):
    return {'path': str(p.relative_to(ROOT)), 'bytes': p.stat().st_size, 'sha256': sha(p)}
result={'schema':1,'scope':'derived from preserved exact-source native receipts and original public fixtures; not new native tests or physical measurements', 'latestCompleteCaseEvidenceSource':'c4ffa28c07d0a17b513d123de3bec2fd8be93eec','independentExactUSDZComparison':'completed on exact retained diagnostic files; two native first-wall numerical witnesses, 24 reference features','runs':[],'fixtureMetadata':[],'declaredProfiles':[],'sourceFiles':[]}
for run in ('40698547633','40706611490','40710093281','40726507227'):
    p=RUNS/('run'+run)
    d=read(p/'final-unit-case-statuses-original.json')
    assert d['complete'] and d['source_verified'] and d['aggregate_counts_match']
    counts=collections.Counter(c['result'] for c in d['cases'])
    assert all(counts.get(k,0)==v for k,v in d['counts'].items())
    assert sum(counts.values())==d['case_count']
    reports=d['routeDiagnosticEvidence']['reports']
    rs=[]
    for r in reports:
        rr=r['report']
        if 'outcomes' in rr:
            rs.append({'name':r['attachmentName'],'originalAttachmentSHA256':r['sha256'],'outcomes':len(rr['outcomes']),'outcomeCounts':dict(collections.Counter(x['outcome'] for x in rr['outcomes'])),'errorCounts':dict(collections.Counter(x.get('error','none') for x in rr['outcomes'])),'physicalAuthority':rr['physicalAuthority']})
    result['runs'].append({'id':int(run),'source':d['source_commit'],'caseCount':d['case_count'],'counts':dict(counts),'routes':rs,'sourceReceipt':record(p/'final-unit-case-statuses-original.json')})
latest=RUNS/'run40710093281'
for fn in ('APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json','SavedRoomCollisionBackendMatrix-v1.json','SavedRoomCollisionMixedScene-v1.json','classified-timing-summary.json','ui-audit/evidence.json'):
    result['sourceFiles'].append(record(latest/fn))
inv=read(latest/'APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json')
result['latestMeshInventory']=[{k:v for k,v in f.items() if k not in ('nodes','metadataEntries')} for f in inv['fixtures']]
for kind,fn in (('startupCollision','SavedRoomCollisionBackendMatrix-v1.json'),('mixedCollision','SavedRoomCollisionMixedScene-v1.json')):
    data=read(latest/fn)
    result[kind]=[{k:v for k,v in c.items() if k!='queries'} | {'controls':len(c['queries']),'passedControls':sum(q['passed'] for q in c['queries'])} for c in data['cells']]
timing=read(latest/'classified-timing-summary.json')
result['classifiedTiming']={'receiptCount':timing['receiptCount'],'unit':timing['unit'],'associationLimit':timing['associationLimit'],'minCallbackMs':min(x['callbackMs'] for x in timing['rows']),'maxCallbackMs':max(x['callbackMs'] for x in timing['rows']),'nativeBuildMeasuredReceiptCount':sum(x['nativeBuildMs'] is not None for x in timing['rows']),'maxNativeBuildMs':max(x['nativeBuildMs'] for x in timing['rows'] if x['nativeBuildMs'] is not None),'maxQueueWaitMs':max(x['queueWaitMs'] for x in timing['rows']),'maxHandoffMs':max(x['handoffMs'] for x in timing['rows']),'minDiscardCompleteMs':min(x['discardCompleteMs'] for x in timing['rows']),'maxDiscardCompleteMs':max(x['discardCompleteMs'] for x in timing['rows'])}
protocol=ROOT/'research/roomplan-route-diagnostic-20261028/PROTOCOL.json'
addendum=ROOT/'research/roomplan-route-diagnostic-20261028/PROFILE_28CM_ADDENDUM.json'
for name in ('Hallway2','Bedroom3'):
    p=ROOT/'ios/BlindAssistTests/Fixtures/RoomPlanApple'/(name+'.capturedRoom.json')
    d=read(p); assert sha(p)==read(protocol)['fixtures'][name]
    surfaces=sum((d.get(k,[]) for k in ('floors','walls','doors','windows','openings')),[])
    result['fixtureMetadata'].append({'fixture':name,'source':record(p),'featureCounts':{k:len(d.get(k,[])) for k in ('floors','walls','doors','windows','openings','objects')},'floorDimensionsAsSaved':d['floors'][0]['dimensions'],'floorPolygonCornersAsSaved':d['floors'][0]['polygonCorners'],'surfaceCount':len(surfaces),'zeroDimensionZSurfaces':sum(s['dimensions'][2]==0 for s in surfaces),'meaning':'saved source fields; not independently measured physical dimensions, inferred clearance, or exported USD bounds'})
for p in (protocol,addendum):
    result['sourceFiles'].append(record(p))
    for v in read(p)['profiles']:
        radius=math.hypot(v['width'],v['depth'])/2
        result['declaredProfiles'].append(v|{'rawCircumscribedRadius':radius,'effectivePlannerRadius':radius+v['margin'],'effectivePlannerDiameter':2*(radius+v['margin']),'effectivePlannerHeight':v['height']+v['margin'],'meaning':'preregistered diagnostic inputs and arithmetic; not measured body, exported geometry, or demonstrated blockage cause'})
follow = RUNS/'run40721822359'
if (follow/'same-export-failed-receipt.json').exists():
    p = follow/'same-export-failed-receipt.json'
    r = read(p)
    assert r['status']=='unverified_case_evidence' and r['files']==[] and r['sourceVerified'] is False
    c = read(follow/'early-unit-case-statuses-original.json')
    assert c['complete'] is False and c['source_verified'] is False
    result['followOnAppCapture']={'runID':40721822359,'source':c['source_commit'],'caseEvidenceComplete':False,'sameExportStatus':r['status'],'retainedAssets':len(r['files']),'OpenUSDFixtureReadEstablished':False,'receipt':record(p),'caseEvidence':record(follow/'early-unit-case-statuses-original.json')}
    if (follow/'terminal-run.json').exists():
        result['followOnAppCapture']['terminal']=read(follow/'terminal-run.json')
        result['followOnAppCapture']['terminalReceipt']=record(follow/'terminal-run.json')
        result['followOnAppCapture']['linkFailureReceipt']=record(follow/'bounded-link-failure-lines.txt')
        totals={}
        for line in (follow/'bounded-link-failure-lines.txt').read_text().splitlines():
            for suite in ('unit','ui'):
                marker=suite+' xcresult: '
                if marker in line:
                    totals[suite]=read_result=json.loads(line.split(marker,1)[1])
                    assert read_result['totalTestCount']==0
        assert set(totals)=={'unit','ui'}
        result['followOnAppCapture']['zeroCaseSummaries']=totals
    result['followOnProofs']=[]
    for rid in ('40721821544','40721821664'):
        terminal=read(RUNS/('run'+rid)/'terminal-run.json')
        result['followOnProofs'].append({'runID':int(rid),'source':terminal['head_sha'],'status':terminal['status'],'conclusion':terminal['conclusion'],'terminalReceipt':record(RUNS/('run'+rid)/'terminal-run.json'),'scopeReceipt':record(RUNS/('run'+rid)/'bounded-proof-summary.txt')})
comparison=ROOT/'research/independent-usd-reference-catalog-20261028-1514/run40726507227'
result['independentComparisonFiles']=[record(comparison/n) for n in ('RESULTS.md','COMPARISON.json','INPUT_MANIFEST.json','INDEPENDENT_REVIEW.json','EXECUTION_RECEIPT.json')]
result['currentNativeRunReceipt']=record(RUNS/'run40726507227/terminal-jobs-170921Z.json')
(HERE/'EVIDENCE_SUMMARY.json').write_text(json.dumps(result,indent=2)+'\n')
print('Wrote EVIDENCE_SUMMARY.json; verified 4 exact-source status receipts and 2 original fixture hashes.')
