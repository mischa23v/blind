#!/usr/bin/env python3
"""Synthetic renderer tests only. Never executes or claims Apple native routes."""
import copy
import importlib.util
import json
import math
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
SPEC=importlib.util.spec_from_file_location('render_results',HERE/'render_results.py')
r=importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(r)
v=r.validator(); DOCS,UUIDS,HASHES=v.sources(r.ROOT)


def synthetic_report(label='journey'):
    report={'schema':1,'protocolSHA256':v.JOURNEY if label=='journey' else v.BASE,
            'physicalAuthority':False,'fullFootprintSupportVerified':False,'outcomes':[],'errors':[]}
    if label=='journey':
        report.update(baseline18Unchanged=True,suppliedPoseCandidateReplayOnly=True,cameraLocalizationTested=False,
                      getUpKinematicsTested=False,productionGuidanceCode=['SpatialFacts.relation','SpatialFacts.phrase','GuidanceCadence.label'],
                      sustainedControllerTested=False,VoiceOverTested=False)
    else:
        report.update(profileAddendumSHA256=v.WIDTH if label=='width28-addendum' else 'none',schedule=label,
                      currentCoverageKnown=False,scope='candidate waypoint replay; not controller/device arrival')
    schedule=r.schedule_map(DOCS,label)
    for ident in schedule:
        report['outcomes'].append(dict(zip(('journey','stage') if label=='journey' else ('pair','profile'),ident),
                                      outcome='not-run-after-aborted-stage'))
    row=report['outcomes'][0]; room,authored,stage,profile=schedule[r.identity(row,label)]
    floor=DOCS[f'RoomPlanApple/{room}.capturedRoom.json']['floors'][0]
    a=r.transform([-.6,0,0] if label=='journey' else [-3,-.45,0],floor['transform'])
    b=r.transform([-.6,1.1,0] if label=='journey' else [2.8,-.45,0],floor['transform'])
    ps=[a[0]+.05,a[1]+.025,a[2]]; pg=[b[0]+.03,b[1]+.025,b[2]]
    row.update(outcome='modeled-segment-candidate-no-contact' if label=='journey' else 'candidate-model-route-no-contact',
               sourceSHA256=v.FIXTURES[room],physicalAuthority=False,requestedStart=a,requestedGoal=b,
               projectedStart=ps,projectedGoal=pg,routePoints=[ps,pg],nativeComplete=True,nativeStatus=1073741824,
               startProjectionMetres=math.dist(a,ps),goalProjectionMetres=math.dist(b,pg),
               initialBodyContact=False,initialMarginContact=False,fullFootprintSupportVerified=False,
               bodyContact=False,marginContact=False,floorContactIDs=[],obstacleSurfaceIDs=[],furnitureBoundIDs=[],
               segments=[{'kind':k,'from':x,'to':y,'bodyContact':False,'marginContact':False} for k,x,y in
                         [('requested-start-to-projection',a,ps),('detour-segment-1',ps,pg),('projection-to-requested-goal',pg,b)]])
    if label=='journey':
        row.update(seatedFeatureID=authored['seatedFeatureID'],seatedObservationIsAuthored=True,
                   originalSuppliedStandingPoint=a,declaredHeading=[1,0,0],cameraLocalizationTested=False,
                   getUpKinematicsTested=False,expectedWithhold=False,replayPositionAfterStage=b,
                   guidanceDelivered=False,productionGuidanceReceipts=[])
    else:
        raw=math.hypot(profile['width'],profile['depth'])/2
        row.update(rawRadius=raw,rawHeight=profile['height'],effectiveRadius=raw+profile['margin'],
                   effectiveHeight=profile['height']+profile['margin'],initialFurnitureBoundIDs=[],waypointSinkDelivered=True)
        # Added native baseline contract: source support stays explicitly unknown.
        row.update(scoredChainContinuous=True,scoredChainIncludesRequestedGoal=True,
                   sourceFloorSupportAlongScoredChain='unverified-full-footprint')
        for segment in row['segments']:
            segment.update(floorContactIDs=[],fullFootprintSupportVerified=False,sourceFloorSupport='unverified-full-footprint')
    return report


def synthetic_evidence():
    entries=[]
    for test,name,label in v.SPECS:
        rep=synthetic_report(label); raw=json.dumps(rep).encode()
        entries.append({'attachmentName':name,'testIdentifier':test,'status':'collected','testResult':'Failed',
                        'bytes':len(raw),'sha256':r.digest(raw),'report':rep})
    return {'schema':1,'complete':True,'source_verified':True,'source_commit':'a'*40,'routeDiagnosticEvidence':{'schema':1,'physicalAuthority':False,
             'status':'complete','sourceSHA256':HASHES,'reports':entries}}


class GeometryTests(unittest.TestCase):
    def test_positive_coordinate_orientation_and_translation(self):
        # Explicit positive +X/+Z coordinates; no mirrored y screen convention.
        self.assertEqual(r.projected([2,100,3]),[2,3])
        t=[0,1,0,0, 0,0,1,0, 1,0,0,0, 10,20,30,1]
        self.assertEqual(r.transform([2,3,4],t),[14,22,33])
        self.assertEqual(r.transform([0,0,0],t),[10,20,30])
    def test_original_floor_concavity_and_no_extra_corners(self):
        raw=DOCS['RoomPlanApple/Hallway2.capturedRoom.json']; floor=raw['floors'][0]
        rendered=next(f for f in r.scene(raw) if f['kind']=='floors')
        expected=[r.projected(r.transform(p,floor['transform'])) for p in floor['polygonCorners']]
        self.assertEqual(rendered['topDown'],expected); self.assertEqual(len(expected),8)
        def area(p): return abs(sum(p[i][0]*p[(i+1)%len(p)][1]-p[(i+1)%len(p)][0]*p[i][1] for i in range(len(p)))/2)
        self.assertLess(area(expected),area(r.hull(expected)))
    def test_full_tilted_furniture_box_uses_height_axis(self):
        c=math.sqrt(.5)
        item={'dimensions':[2,4,6],'transform':[1,0,0,0, 0,c,c,0, 0,-c,c,0, 5,6,7,1]}
        points=r.corners(item,box=True)
        self.assertEqual(len(points),8)
        self.assertAlmostEqual(max(p[2] for p in points),7+5*c)
        self.assertAlmostEqual(min(p[1] for p in points),6-5*c)
    def test_historical_doors_no_state_inference(self):
        features=r.scene(DOCS['RoomPlanApple/Hallway2.capturedRoom.json'])
        states=[f['historicalDoorOpen'] for f in features if f['kind']=='doors']
        self.assertEqual(states.count(True),2); self.assertEqual(states.count(False),4)
    def test_expansive_geometry_not_added(self):
        for name in ('Bedroom3','Hallway2'):
            src=DOCS[f'RoomPlanApple/{name}.capturedRoom.json']; out=r.scene(src)
            self.assertEqual(len(out),sum(len(src[k]) for k in ('floors','walls','doors','windows','openings','objects')))
            for f in out:
                self.assertTrue(all(len(p)==3 for p in f['worldCorners']))
                self.assertEqual(f['heightRangeY'],[min(p[1] for p in f['worldCorners']),max(p[1] for p in f['worldCorners'])])
    def test_plot_rejects_unbounded_extent_instead_of_fitting(self):
        f=r.scene(DOCS['RoomPlanApple/Bedroom3.capturedRoom.json'])
        with self.assertRaisesRegex(r.ViewError,'plot_extent_over_budget'):
            r.bounds(f,[{'requestedGoal':[1000,0,1000]}])


class ReportTests(unittest.TestCase):
    def test_all_synthetic_schedules_pass_existing_schema(self):
        for _,_,label in v.SPECS:
            report=synthetic_report(label)
            v.validate_report(report,label,DOCS,UUIDS)
            for row in report['outcomes']: self.assertEqual(r.audit_segments(row),[])
            if label=='journey':r.audit_replay(report,DOCS)
    def test_missing_connector_is_reported_not_repaired(self):
        row=synthetic_report()['outcomes'][0]
        first=list(row['routePoints'][0]); first[0]+=.12
        row['routePoints'][0]=first; row['segments'][1]['from']=first
        before=copy.deepcopy(row)
        gaps=r.audit_segments(row)
        self.assertEqual([g['kind'] for g in gaps],['projection-to-detour-start'])
        self.assertEqual(row,before); self.assertAlmostEqual(gaps[0]['distanceMetres'],.12)
    def test_partial_route_never_bridged_to_requested_goal(self):
        row=synthetic_report()['outcomes'][0]; row['nativeComplete']=False; row['segments'].pop()
        self.assertEqual(r.audit_segments(row),[])
    def test_missing_detour_segment_is_disclosed(self):
        row=synthetic_report()['outcomes'][0]; row['segments'].pop(1)
        self.assertEqual(r.audit_segments(row)[0]['kind'],'detour-segment-1')
    def test_inconsistent_scored_chain_claim_rejected(self):
        row=synthetic_report('original-baseline')['outcomes'][0]
        row['segments'].pop(1)
        with self.assertRaisesRegex(r.ViewError,'scored_chain_claim_disagreement'):r.audit_segments(row)
    def test_inconsistent_segment_endpoints_rejected(self):
        row=synthetic_report()['outcomes'][0]; row['segments'][1]['to']=[99,0,99]
        with self.assertRaisesRegex(r.ViewError,'segment_endpoint_disagreement'):r.audit_segments(row)
    def test_reorder_and_duplicate_segments_rejected(self):
        for change in ('reverse','duplicate'):
            row=synthetic_report()['outcomes'][0]
            if change=='reverse':row['segments'].reverse()
            else:row['segments'].append(row['segments'][0])
            with self.assertRaises(r.ViewError):r.audit_segments(row)
    def test_projection_displacement_not_silently_rewritten(self):
        row=synthetic_report()['outcomes'][0]; row['startProjectionMetres']=8
        with self.assertRaisesRegex(r.ViewError,'projection_distance_disagreement'):r.audit_segments(row)
    def test_contact_flags_cannot_be_erased_or_fabricated(self):
        row=synthetic_report()['outcomes'][0]; row['segments'][0]['bodyContact']=True
        with self.assertRaisesRegex(r.ViewError,'body_contact_aggregate_disagreement'):r.audit_segments(row)
    def test_inconsistent_profile_dimension_rejected(self):
        row=synthetic_report('original-baseline')['outcomes'][0]
        profile=DOCS['RoomRouteDiagnostic/PROTOCOL.json']['profiles'][0]
        r.audit_profile(row,profile)
        row['effectiveRadius']=.01
        with self.assertRaisesRegex(r.ViewError,'profile_dimension_disagreement'):r.audit_profile(row,profile)
    def test_failed_stage_does_not_advance_replay(self):
        report=synthetic_report(); row=report['outcomes'][0]; row['outcome']='candidate-contact'
        with self.assertRaisesRegex(r.ViewError,'replay_outcome_disagreement'):r.audit_replay(report,DOCS)
        row['replayPositionAfterStage']=row['requestedStart'];r.audit_replay(report,DOCS)
    def test_interstage_gap_not_silently_joined(self):
        report=synthetic_report(); row=copy.deepcopy(report['outcomes'][0]); row['stage']=report['outcomes'][1]['stage']
        report['outcomes'][1]=row
        with self.assertRaisesRegex(r.ViewError,'journey_start_discontinuity'):r.audit_replay(report,DOCS)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.path=Path(self.tmp.name)/'synthetic-ci-evidence.json'
    def write(self,value):
        raw=json.dumps(value).encode(); self.path.write_bytes(raw); return r.digest(raw)
    def test_all_three_failed_native_statuses_preserved(self):
        docs,reports,meta=r.load_evidence(self.path,self.write(synthetic_evidence()))
        self.assertEqual(len(reports),3)
        self.assertTrue(all(x['testResult']=='Failed' for x in meta['reportInventory']))
    def test_unverified_ci_envelope_rejected(self):
        evidence=synthetic_evidence();evidence['source_verified']=False
        with self.assertRaisesRegex(r.ViewError,'unverified_ci_source_or_cases'):
            r.load_evidence(self.path,self.write(evidence))
    def test_input_hash_mismatch_rejected(self):
        self.write(synthetic_evidence())
        with self.assertRaisesRegex(r.ViewError,'evidence_hash_mismatch'):r.load_evidence(self.path,'0'*64)
    def test_inconsistent_source_hash_rejected(self):
        evidence=synthetic_evidence(); key='ios/BlindAssistTests/Fixtures/RoomPlanApple/Bedroom3.capturedRoom.json'
        evidence['routeDiagnosticEvidence']['sourceSHA256']=dict(HASHES); evidence['routeDiagnosticEvidence']['sourceSHA256'][key]='0'*64
        sha=self.write(evidence)
        with self.assertRaisesRegex(r.ViewError,'evidence_source_hash_mismatch'):r.load_evidence(self.path,sha)
    def test_report_hash_mismatch_rejected_by_existing_validator(self):
        evidence=synthetic_evidence(); evidence['routeDiagnosticEvidence']['reports'][0]['report']['outcomes'][0]['sourceSHA256']='0'*64
        sha=self.write(evidence)
        with self.assertRaises(ValueError):r.load_evidence(self.path,sha)
    def test_no_report_does_not_generate_paths(self):
        evidence=synthetic_evidence()
        for e in evidence['routeDiagnosticEvidence']['reports']:e.update(status='not_collected');e.pop('report')
        sha=self.write(evidence)
        with self.assertRaisesRegex(r.ViewError,'no_collected_reports'):r.load_evidence(self.path,sha)
    def test_missing_report_retained_as_missing(self):
        evidence=synthetic_evidence(); e=evidence['routeDiagnosticEvidence']['reports'][1]; e.update(status='not_collected');e.pop('report')
        _,reports,meta=r.load_evidence(self.path,self.write(evidence))
        self.assertEqual(len(reports),2); self.assertEqual(meta['reportInventory'][1]['collectionStatus'],'not_collected')
    def test_duplicate_report_and_private_data_rejected(self):
        evidence=synthetic_evidence(); evidence['routeDiagnosticEvidence']['reports'][1]=evidence['routeDiagnosticEvidence']['reports'][0]
        with self.assertRaises(r.ViewError):r.load_evidence(self.path,self.write(evidence))
        evidence=synthetic_evidence(); evidence['routeDiagnosticEvidence']['reports'][0]['report']['privatePhoto']='anything'
        with self.assertRaises(ValueError):r.load_evidence(self.path,self.write(evidence))
    def test_symlink_and_oversized_input_rejected(self):
        self.path.symlink_to('/etc/passwd')
        with self.assertRaisesRegex(r.ViewError,'input_not_regular_file'):r.read_bounded(self.path)
        self.path.unlink(); self.path.write_bytes(b' '*(r.LIMIT+1))
        with self.assertRaisesRegex(r.ViewError,'input_over_budget'):r.read_bounded(self.path)


class DrawingTests(unittest.TestCase):
    def test_synthetic_image_scale_exact_segments_and_no_getup_line(self):
        with tempfile.TemporaryDirectory() as d:
            row=synthetic_report()['outcomes'][0]
            features=r.scene(DOCS['RoomPlanApple/Bedroom3.capturedRoom.json'])
            profile=DOCS['RoomRouteDiagnostic/JOURNEY_ADDENDUM.json']['profile']
            stem=Path(d)/'SYNTHETIC-NOT-NATIVE'
            receipt=r.draw_one(row,'journey','Bedroom3',features,r.bounds(features,[row]),profile,stem,synthetic=True)
            svg=stem.with_suffix('.svg').read_text()
            self.assertIn('SYNTHETIC RENDERER CHECK',svg)
            self.assertEqual(svg.count('id="reported-segment-'),3)
            self.assertEqual(receipt['reportedOutcome'],row)
            self.assertTrue(receipt['syntheticRendererFixture'])
            self.assertFalse(receipt['getUpKinematicsTested'])
            self.assertEqual(receipt['pixelsPerMetre'],110)
            from PIL import Image
            with Image.open(stem.with_suffix('.png')) as image:
                self.assertGreater(image.width,900);self.assertGreater(image.height,800)
    def test_unexecuted_does_not_draw_protocol_start_or_goal(self):
        with tempfile.TemporaryDirectory() as d:
            row=synthetic_report()['outcomes'][1]
            features=r.scene(DOCS['RoomPlanApple/Bedroom3.capturedRoom.json'])
            profile=DOCS['RoomRouteDiagnostic/JOURNEY_ADDENDUM.json']['profile']
            stem=Path(d)/'SYNTHETIC-UNEXECUTED'
            receipt=r.draw_one(row,'journey','Bedroom3',features,r.bounds(features,[row]),profile,stem,synthetic=True)
            self.assertNotIn('reported-segment-',stem.with_suffix('.svg').read_text())
            self.assertNotIn('requestedStart',receipt['reportedOutcome'])


if __name__=='__main__':unittest.main(verbosity=2)
