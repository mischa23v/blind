#!/usr/bin/env python3
"""Read-only stdlib recount of retained Rapier rows; never imports/runs Rapier."""
import argparse, hashlib, json, math, pathlib

def read_lines(p): return [json.loads(x) for x in p.read_text().splitlines()]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def geometric_check(fixture, envelope, arm, row, mapping):
    if row['kind']=='turn': return
    p=row['proposedMovement']; d=row['requestedDelta']; eps=.001
    def flat(): assert all(abs(a-b)<=eps for a,b in zip(p,d))
    def advance(expected, direction=(1,0,0)):
        assert row['collisions']
        assert abs(sum(a*b for a,b in zip(p,direction))-expected)<=eps
        assert abs(p[1])<=eps
    if fixture in ('flat','exact_uv_and_near_duplicate','down_step_1cm','support_gap'): flat()
    if fixture=='exact_uv_and_near_duplicate': assert mapping['vertexCount']==(9 if arm=='raw_trimesh' else 7)
    if fixture=='support_gap': assert row['computedGrounded'] is False
    if fixture=='margin_only_same_pose':
        if envelope=='body': flat(); assert not row['collisions']
        else: advance(.018)
    if fixture in ('wall_front','wall_reversed_winding','low_riser_1cm','step_10cm'): advance(.018)
    if fixture=='wall_back': advance(.018,(-1,0,0))
    if fixture=='zero_input_overlap':
        half=.15 if envelope=='body' else .30
        assert abs(abs(p[0])-(half+.002))<=eps and abs(p[1])<=eps and abs(p[2])<=eps
    if fixture=='low_ceiling': assert abs(p[1]+.022)<=eps
    if fixture=='yaw_45_diagonal_wall':
        c=math.sqrt(.5); advance(.018,(c,0,c))
        assert abs(row['queryPoseFloat32'][4]+math.sin(math.pi/8))<1e-6
        assert abs(row['queryPoseFloat32'][6]-math.cos(math.pi/8))<1e-6
    if fixture.startswith('slope_'):
        degrees=float(fixture.split('_')[1]);x,y=p[:2]; assert row['collisions']
        if row['id'].endswith('_upward_intent') or degrees<15: assert x>.012 and y>.003
        elif degrees>15: assert x<=.005 and y<=.002
        else: assert x<=.005 or (x>.012 and y>.003)

def review(attempt, source, previous):
    guard=json.loads((attempt/'GUARD_RUN/RESULT.json').read_text())
    summary=json.loads((attempt/'controls/SUMMARY.json').read_text())
    pins=json.loads((source/'RUN_PINS.json').read_text())
    wrappers=read_lines(attempt/'controls/wrapper-records.jsonl')
    probes=read_lines(attempt/'controls/probe-rows.jsonl')
    checks=read_lines(attempt/'controls/assertion-results.jsonl')
    expected=[(e,f,a) for e in ('body','horizontal_margin') for f in pins['expectedFixtureProbeIDs'] for a in ('raw_trimesh','two_sided_internal_edges')]
    key=lambda x:(x['envelope'],x['fixtureID'],x['arm'])
    assert list(map(key,wrappers))==expected==list(map(key,checks))
    assert len(wrappers)==72 and len(probes)==108 and sum(x['row']['controllerCalled'] for x in probes)==104
    assert guard['inputHashesBefore']==guard['inputHashesAfter']
    assert guard['status']=='failed' and guard['commands'][0]['groupRetired'] is True
    assert summary['allFixturesAttempted'] is True and summary['status']=='controls_failed_assertions'
    rechecked=[]
    for wrapper,check in zip(wrappers,checks):
        failed=False
        for row in wrapper['result']['results']:
            assert row['movementApplied'] is False and row['physicalAuthority'] is False and row['arrivalEstablished'] is False
            assert row['support']=='unknown' and row['semanticFloor']=='unknown'
            if row['kind']=='turn': assert row['controllerCalled'] is False and row['status']=='unsupported_rotation' and row['proposedMovement'] is None
            else:
                assert row['proposalWasNotApplied'] is True and all(math.isfinite(v) for v in row['proposedMovement'])
                try: geometric_check(wrapper['fixtureID'],wrapper['envelope'],wrapper['arm'],row,wrapper['result']['importedMapping'])
                except AssertionError: failed=True
        assert failed==(check['status']=='failed')
        rechecked.append({'fixtureID':wrapper['fixtureID'],'envelope':wrapper['envelope'],'arm':wrapper['arm'],'status':'failed' if failed else 'passed'})
    raw={(x['fixtureID'],x['envelope'],x['row']['id']):x['row'] for x in probes if x['arm']=='raw_trimesh'}
    other={(x['fixtureID'],x['envelope'],x['row']['id']):x['row'] for x in probes if x['arm']=='two_sided_internal_edges'}
    differences=[k for k in raw if raw[k]['proposedMovement']!=other[k]['proposedMovement'] or raw[k].get('computedGrounded')!=other[k].get('computedGrounded')]
    old=read_lines(previous/'controls/probe-rows.jsonl')
    assert probes[:len(old)]==old
    files={str(p.relative_to(attempt)):{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(attempt.rglob('*')) if p.is_file()}
    return {'status':'FAILED_FULL_ANALYTIC_COMPARISON_VERIFIED','sourceCommit':guard['sourceCommit'],
        'sourceManifestSHA256':sha(source/'RUN_PINS.json'),'wrapperCount':72,'nestedRows':108,'controllerCalls':104,
        'independentGeometricAssertionRechecks':rechecked,'failedWrappers':[x for x in checks if x['status']=='failed'],
        'failedRows':[x for x in probes if x['envelope']=='horizontal_margin' and x['fixtureID']=='down_step_1cm'],
        'pairedMovementOrGroundedDifferences':differences,'pairedComparisons':len(raw),'previous73RowsExactlyReproduced':True,
        'inputHashesUnchanged':True,'allFixturesAttempted':True,'realRoomQueries':0,'physicalAuthority':False,
        'rawFileInventory':files,'resourceMetrics':{k:guard[k] for k in ('wallSeconds','aggregateCPUSeconds','peakObservedAggregateRSS','peakFastExitChildRSS')},
        'scope':'Authored analytic assertions only; no accuracy percentage, room passage, missing-hazard recall or physical safety established.'}

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--attempt',type=pathlib.Path,required=True);a.add_argument('--source',type=pathlib.Path,required=True);a.add_argument('--previous',type=pathlib.Path,required=True);a.add_argument('--output',type=pathlib.Path,required=True);args=a.parse_args()
    result=review(args.attempt,args.source,args.previous)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'wrappers':72,'failed':len(result['failedWrappers']),'rawEngineExecuted':False}))
