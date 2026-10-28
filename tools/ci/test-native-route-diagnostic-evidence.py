#!/usr/bin/env python3
"""Bounded synthetic exporter/CLI fixtures; NOT Apple path/collision execution."""
import contextlib
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj
m = module('routes', 'native-route-diagnostic-evidence.py')
u = module('statuses', 'export-native-unit-statuses.py')
DOCS, UUIDS, HASHES = m.sources(ROOT)


def report(label, executed=False):
    journey = label == 'journey'
    result = {'schema':1,'protocolSHA256':m.JOURNEY if journey else m.BASE,
              'physicalAuthority':False,'fullFootprintSupportVerified':False,'outcomes':[],'errors':[]}
    if journey:
        result.update(baseline18Unchanged=True, suppliedPoseCandidateReplayOnly=True,
                      cameraLocalizationTested=False, getUpKinematicsTested=False,
                      productionGuidanceCode=['SpatialFacts.relation','SpatialFacts.phrase','GuidanceCadence.label'],
                      sustainedControllerTested=False, VoiceOverTested=False)
        for j in DOCS['RoomRouteDiagnostic/JOURNEY_ADDENDUM.json']['journeys']:
            for s in j['stages']:
                result['outcomes'].append({'journey':j['id'],'stage':s['id'],'outcome':'not-run-after-aborted-stage'})
    else:
        result.update(profileAddendumSHA256=m.WIDTH if label == 'width28-addendum' else 'none',schedule=label,
                      currentCoverageKnown=False,scope='candidate waypoint replay; not controller/device arrival')
        profiles = DOCS['RoomRouteDiagnostic/'+ ('PROFILE_28CM_ADDENDUM.json' if label == 'width28-addendum' else 'PROTOCOL.json')]['profiles']
        for pair in DOCS['RoomRouteDiagnostic/PROTOCOL.json']['pairs']:
            for profile in profiles:
                result['outcomes'].append({'pair':pair['id'],'profile':profile['id'],'outcome':'not-run-after-aborted-stage'})
    if executed:
        row = result['outcomes'][0]
        row.update(outcome='modeled-segment-candidate-no-contact' if journey else 'candidate-model-route-no-contact',
                   sourceSHA256=m.FIXTURES['Bedroom3' if journey else 'Hallway2'],physicalAuthority=False,
                   requestedStart=[0,0,0],requestedGoal=[1,0,0],routePoints=[[0,0,0],[1,0,0]],
                   projectedStart=[0,0,0],projectedGoal=[1,0,0],nativeComplete=True,nativeStatus=1073741824,
                   startProjectionMetres=0,goalProjectionMetres=0,initialBodyContact=False,initialMarginContact=False,
                   fullFootprintSupportVerified=False,bodyContact=False,marginContact=False,floorContactIDs=[],
                   obstacleSurfaceIDs=[],furnitureBoundIDs=[],segments=[{'kind':'detour-segment-1','from':[0,0,0],
                   'to':[1,0,0],'bodyContact':False,'marginContact':False}])
        if journey:
            row.update(seatedFeatureID='45597D99-3218-4419-A2E4-2ADFA824D033',seatedObservationIsAuthored=True,
                       expectedWithhold=False,cameraLocalizationTested=False,getUpKinematicsTested=False,
                       originalSuppliedStandingPoint=[0,0,0],declaredHeading=[1,0,0],replayPositionAfterStage=[1,0,0],
                       guidanceDelivered=True,productionGuidanceReceipts=[{
                           'segmentIndex':0,'segmentKind':'detour-segment-1','from':[0,0,0],'to':[1,0,0],
                           'sector':'ahead','angleDegrees':0,'horizontalMetres':1,'syntheticSeconds':2,
                           'physicalAuthority':False,'source':'production SpatialFacts + GuidanceCadence; supplied heading',
                           'text':'TEST '+row['stage']+' detour-segment-1: ahead, 1.0 metres.'}])
        else:
            row.update(rawRadius=.27,rawHeight=1.6,effectiveRadius=.42,effectiveHeight=1.75,initialFurnitureBoundIDs=[],waypointSinkDelivered=True)
    return result


def export_fixture(directory, name, payload, suggested=None, filename='report.json'):
    directory.mkdir(parents=True, exist_ok=True)
    (directory/'manifest.json').write_text(json.dumps([{'testName':'synthetic fixture','attachments':[
        {'suggestedHumanReadableName':suggested or name,'exportedFileName':filename}]}]))
    if filename == 'report.json': (directory/filename).write_text(json.dumps(payload))


class ValidationTests(unittest.TestCase):
    def validate(self, data, label='original-baseline'):
        return m.validate_report(data,label,DOCS,UUIDS)
    def test_all_three_full_schedules_and_executed_rows(self):
        for _,_,label in m.SPECS:
            for executed in (False,True): self.assertEqual(self.validate(report(label,executed),label),report(label,executed))
    def test_protocol_source_authority_and_schema_fail_closed(self):
        for key,value in [('protocolSHA256','0'*64),('physicalAuthority',True),('privateHistory','secret'),('schema',True)]:
            r=report('original-baseline');r[key]=value
            with self.assertRaises(m.EvidenceError):self.validate(r)
        r=report('original-baseline',True);r['outcomes'][0]['sourceSHA256']='a'*64
        with self.assertRaises(m.EvidenceError):self.validate(r)
    def test_nonfinite_numbers_and_nonvectors(self):
        for bad in ([float('nan'),0,0],[float('inf'),0,0],[True,0,0],[0,0],['private',0,0],[1e100,0,0],[10**400,0,0]):
            r=report('original-baseline',True);r['outcomes'][0]['routePoints']=[bad]
            with self.assertRaises(m.EvidenceError):self.validate(r)
    def test_duplicate_key_and_nonfinite_json(self):
        for raw in ('{"a":1,"a":2}','{"a":NaN}','{"a":Infinity}'):
            with self.assertRaises(m.EvidenceError):m.decode(raw)
    def test_missing_duplicate_and_unknown_schedules(self):
        for change in ('missing','duplicate','unknown'):
            r=report('original-baseline')
            if change=='missing':r['outcomes'].pop()
            elif change=='duplicate':r['outcomes'][-1]=r['outcomes'][0]
            else:r['outcomes'][0]['pair']='my-private-bedroom'
            with self.assertRaises(m.EvidenceError):self.validate(r)
    def test_private_and_model_strings_are_rejected(self):
        for change in ('error','unknown_field','text','source','uuid'):
            r=report('journey',True);row=r['outcomes'][0]
            if change=='error':r['errors']=['/Users/private/family-camera.jpg']
            elif change=='unknown_field':row['cameraFrame']='encoded-private-frame'
            elif change=='text':row['productionGuidanceReceipts'][0]['text']='My model says go to Sarah in bedroom'
            elif change=='source':row['productionGuidanceReceipts'][0]['source']='model output'
            else:row['furnitureBoundIDs']=['00000000-0000-0000-0000-000000000000']
            with self.assertRaises(m.EvidenceError):self.validate(r,'journey')
    def test_guidance_segments_cannot_be_substituted(self):
        r=report('journey',True);r['outcomes'][0]['productionGuidanceReceipts'][0]['to']=[8,8,8]
        with self.assertRaises(m.EvidenceError):self.validate(r,'journey')
    def test_incomplete_and_conflicting_candidate_claims_rejected(self):
        for label in ('original-baseline','journey'):
            for key in ('segments','routePoints','nativeComplete','bodyContact','physicalAuthority'):
                r=report(label,True);del r['outcomes'][0][key]
                with self.assertRaises(m.EvidenceError):self.validate(r,label)
            r=report(label,True);r['outcomes'][0]['bodyContact']=True
            with self.assertRaises(m.EvidenceError):self.validate(r,label)
            r=report(label,True);r['outcomes'][0]['segments']=[]
            with self.assertRaises(m.EvidenceError):self.validate(r,label)
    def test_authored_failure_is_retained_not_relabelled_pass(self):
        r=report('original-baseline');r['outcomes'][0].update(outcome='unsupported-geometry',error='invalidMesh')
        r['errors']=['Hallway2: invalidMesh']
        self.assertEqual(self.validate(r),r)
    def test_source_digest_changed_before_collection(self):
        with patch.object(Path,'read_bytes',return_value=b'{}'):
            with self.assertRaises(m.EvidenceError):m.sources(ROOT)


class FileBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.d=Path(self.tmp.name)/'export';self.addCleanup(self.tmp.cleanup)
        self.name=m.SPECS[0][1];self.payload=report('original-baseline')
    def test_exact_and_known_exporter_suffix(self):
        for name in (self.name,self.name.removesuffix('.json')+'_1_ABCD.json',self.name+'_1_ABCD.json'):
            export_fixture(self.d,self.name,self.payload,suggested=name)
            self.assertEqual(m.decode(m.exported_report(self.d,self.name)),self.payload)
    def test_paths_never_opened(self):
        for filename in ('../private.json','/tmp/private.json','x\\private.json','report.png','..','bad\x00.json'):
            export_fixture(self.d,self.name,self.payload,filename=filename)
            with self.assertRaises(m.EvidenceError):m.exported_report(self.d,self.name)
    def test_symlink_rejected(self):
        export_fixture(self.d,self.name,self.payload)
        p=self.d/'report.json';p.unlink();p.symlink_to('/etc/passwd')
        with self.assertRaises(m.EvidenceError):m.exported_report(self.d,self.name)
    def test_unknown_attachment_never_read(self):
        for name in ('screenshot.png','camera-frame.json','audio.wav','model-output.json',self.name+'Private.json'):
            export_fixture(self.d,self.name,self.payload,suggested=name)
            (self.d/'report.json').write_bytes(b'not-readable-json')
            with self.assertRaisesRegex(m.EvidenceError,'unexpected_test_attachment'):m.exported_report(self.d,self.name)
    def test_declared_type_and_size_when_present(self):
        for key,value in [('uniformTypeIdentifier','public.png'),('payloadSize',m.LIMIT+1),('payloadSize',True)]:
            export_fixture(self.d,self.name,self.payload)
            path=self.d/'manifest.json';data=json.loads(path.read_text());data[0]['attachments'][0][key]=value;path.write_text(json.dumps(data))
            with self.assertRaises(m.EvidenceError):m.exported_report(self.d,self.name)
    def test_export_directory_symlink_rejected_without_traversal(self):
        self.d.symlink_to(self.d.parent, target_is_directory=True)
        with self.assertRaises(m.EvidenceError):m.export_size(self.d)
    def test_duplicate_empty_unsupported_and_large_manifest(self):
        export_fixture(self.d,self.name,self.payload)
        manifest=self.d/'manifest.json'; original=json.loads(manifest.read_text())
        for data in ({},[],[{'attachments':[]}],[{'attachments':original[0]['attachments']*2}]):
            manifest.write_text(json.dumps(data))
            with self.assertRaises(m.EvidenceError):m.exported_report(self.d,self.name)
        manifest.write_text(' '*65537)
        with self.assertRaises(m.EvidenceError):m.exported_report(self.d,self.name)
    def test_file_count_subdirectory_and_byte_bounds(self):
        self.d.mkdir()
        for i in range(9):(self.d/str(i)).touch()
        with self.assertRaises(m.EvidenceError):m.export_size(self.d)
        for p in self.d.iterdir():p.unlink()
        (self.d/'dir').mkdir()
        with self.assertRaises(m.EvidenceError):m.export_size(self.d)
        (self.d/'dir').rmdir();(self.d/'large').write_bytes(b'x'*(m.LIMIT+65537))
        with self.assertRaises(m.EvidenceError):m.export_size(self.d)


class CollectionTests(unittest.TestCase):
    def cases(self,status='Passed'):
        return [{'identifier':'BlindAssistTests/'+key+'()','result':status} for key,_,_ in m.SPECS]
    def exporter(self,bundle,identifier,destination):
        spec=next(s for s in m.SPECS if s[0]==m.canonical(identifier))
        export_fixture(destination,spec[1],report(spec[2],True))
    def collect(self,cases=None):
        with patch.object(m,'export_test',side_effect=self.exporter):return m.collect(ROOT,Path('unused'),self.cases() if cases is None else cases,u.query)
    def test_failed_tests_keep_full_reports_and_status(self):
        result=self.collect(self.cases('Failed'))
        self.assertEqual(result['status'],'complete');self.assertEqual(len(result['reports']),3)
        self.assertTrue(all(r['testResult']=='Failed' and r['report']['physicalAuthority'] is False for r in result['reports']))
        self.assertTrue(all(r['sha256'] and r['bytes']>0 for r in result['reports']))
    def test_unknown_prefix_and_lookalikes_do_not_export(self):
        with patch.object(m,'export_test') as tool:
            for identifier in ('Unknown/'+m.SPECS[0][0],m.SPECS[0][0]+'Extra()',m.SPECS[0][0]+'/subcase'):
                result=m.collect(ROOT,Path('unused'),[{'identifier':identifier,'result':'Passed'}],u.query)
                self.assertEqual(result['status'],'not_observed')
            tool.assert_not_called()
    def test_duplicate_and_missing_cases_explicit(self):
        cases=self.cases();result=self.collect(cases+[cases[0]])
        self.assertEqual(result['status'],'incomplete');self.assertEqual(result['reports'][0]['status'],'duplicate_test_case')
        self.assertEqual(self.collect([])['status'],'not_observed')
    def test_export_errors_are_sanitized_and_temp_cleaned(self):
        paths=[]
        def bad(*args):paths.append(args[-1].parent);raise OSError('/Users/private/family')
        with patch.object(m,'export_test',side_effect=bad):r=m.collect(ROOT,Path('unused'),self.cases(),u.query)
        self.assertNotIn('private',json.dumps(r));self.assertTrue(all(not p.exists() for p in paths))
        self.assertEqual(r['reports'][0]['status'],'attachment_export_or_schema_error')
    def test_budget_omits_reports_before_case_statuses(self):
        result={'schema':1,'complete':True,'cases':[{'identifier':'x','result':'Failed'}],
                'routeDiagnosticEvidence':{'status':'complete','reports':[{'report':{'oversized':'x'*m.LIMIT},'status':'collected'}]}}
        encoded=u.encode_evidence(result);r=json.loads(encoded)
        self.assertLessEqual(len(encoded.encode()),m.LIMIT);self.assertEqual(r['cases'],result['cases'])
        self.assertTrue(r['complete']);self.assertEqual(r['routeDiagnosticEvidence']['status'],'artifact_over_budget')
    def test_huge_integer_is_only_additive_error_not_crash(self):
        def bad(bundle,identifier,destination):
            key,name,label=next(s for s in m.SPECS if s[0]==m.canonical(identifier))
            data=report(label,True);data['outcomes'][0]['routePoints'][0][0]=10**400
            export_fixture(destination,name,data)
        with patch.object(m,'export_test',side_effect=bad):r=m.collect(ROOT,Path('unused'),self.cases(),u.query)
        self.assertEqual(r['status'],'incomplete')
        self.assertTrue(all(x['status']=='invalid_route_points' for x in r['reports']))
    def test_main_integration_keeps_exit_and_target_verdict(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);out=root/'unit-case-statuses.json';log=root/'unit.log';log.write_text('')
            cases=self.cases('Failed')
            (root/'unit-summary.json').write_text(json.dumps({'totalTestCount':3,'passedTests':0,'failedTests':3,'skippedTests':0,'expectedFailures':0}))
            raw=json.dumps({'testNodes':[{'nodeType':'Test Case','nodeIdentifier':c['identifier'],'result':c['result']} for c in cases]}).encode()
            source={'actual_head':'a'*40,'tracked_source_clean':True}
            with patch.object(sys,'argv',['exporter','unit.xcresult',str(log),str(out)]),patch.dict(os.environ,{'GITHUB_SHA':'a'*40}),\
                 patch.object(u,'provenance',return_value=source),patch.object(u,'query',return_value=raw),\
                 patch.object(u,'route_evidence',return_value=self.collect(cases)),contextlib.redirect_stdout(io.StringIO()):
                code=u.main()
            final=json.loads(out.read_text());self.assertEqual(code,0);self.assertTrue(final['complete'])
            self.assertFalse(final['target_pass_verified']);self.assertEqual(final['cases'],cases)
            self.assertEqual(final['routeDiagnosticEvidence']['reports'][0]['testResult'],'Failed')


class StubCLITests(unittest.TestCase):
    def test_owned_export_timeout_is_explicit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);stub=root/'xcrun'
            stub.write_text('#!'+sys.executable+'\nimport time;time.sleep(10)\n');stub.chmod(0o755)
            with patch.dict(os.environ,{'PATH':str(root)+os.pathsep+os.environ.get('PATH','')}),\
                 patch.object(m.time,'monotonic',side_effect=[0,31]):
                with self.assertRaisesRegex(m.EvidenceError,'attachment_export_timeout'):
                    m.export_test(Path('fixture.xcresult'),m.SPECS[0][0],root/'output')
    def test_owned_export_file_size_limit_is_enforced(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);stub=root/'xcrun'
            stub.write_text('#!'+sys.executable+'\n'+"import pathlib,sys; a=sys.argv;p=pathlib.Path(a[a.index('--output-path')+1]);p.mkdir();(p/'too-big.json').write_bytes(b'x'*2097152)\n")
            stub.chmod(0o755)
            with patch.dict(os.environ,{'PATH':str(root)+os.pathsep+os.environ.get('PATH','')}):
                with self.assertRaisesRegex(m.EvidenceError,'attachment_export_failed'):
                    m.export_test(Path('fixture.xcresult'),m.SPECS[0][0],root/'output')
            self.assertLessEqual((root/'output/too-big.json').stat().st_size,m.LIMIT)
    def test_real_subprocess_exact_test_flag_and_auto_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);stub=p/'xcrun';capture=p/'commands.jsonl';fixtures=p/'fixtures.json'
            fixtures.write_text(json.dumps({key+'()':{'name':name,'report':report(label,True)} for key,name,label in m.SPECS}))
            stub.write_text('#!'+sys.executable+'\n'+'''import json,os,pathlib,sys
args=sys.argv[1:]
assert args[:3]==['xcresulttool','export','attachments']
assert '--test-id' in args and '--only-failures' not in args
with open(os.environ['COMMANDS'],'a') as f:f.write(json.dumps(args)+'\\n')
fixture=json.load(open(os.environ['FIXTURES']))[args[args.index('--test-id')+1]]
p=pathlib.Path(args[args.index('--output-path')+1]);p.mkdir()
(p/'report.json').write_text(json.dumps(fixture['report']))
(p/'manifest.json').write_text(json.dumps([{'attachments':[{'suggestedHumanReadableName':fixture['name'],'exportedFileName':'report.json'}]}]))
''');stub.chmod(0o755)
            env={'PATH':str(p)+os.pathsep+os.environ.get('PATH',''),'COMMANDS':str(capture),'FIXTURES':str(fixtures)}
            cases=[{'identifier':key+'()','result':'Passed'} for key,_,_ in m.SPECS]
            with patch.dict(os.environ,env):result=m.collect(ROOT,Path('fixture.xcresult'),cases,u.query)
            self.assertEqual(result['status'],'complete')
            commands=[json.loads(line) for line in capture.read_text().splitlines()]
            self.assertEqual(len(commands),3)
            self.assertEqual({c[c.index('--test-id')+1] for c in commands},{c['identifier'] for c in cases})
            self.assertTrue(all(not Path(c[c.index('--output-path')+1]).exists() for c in commands))


if __name__=='__main__':unittest.main()
