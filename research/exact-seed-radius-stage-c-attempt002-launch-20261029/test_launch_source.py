#!/usr/bin/env python3
"""Portable pure-function fixtures. NO Guard construction, subprocess or native work."""
import copy,hashlib,json,math,pathlib,shutil,struct,sys,tempfile,time,types,unittest
sys.dont_write_bytecode=True
from mac_guard import GuardFailure,parse_cpu,parse_ps,family,output_bytes,child_environment,safe_command_label,controlled_reason,Guard
from launch_stage_c import (resolve_argument,validate_observer,validate_result,under,verify_source_packet,
  INPUT_HASHES,CONFIGURATIONS,encode_public_aggregate,finalize_public_aggregate,verify_generated_sources,resolved_native_command,verify_tool_selections,validate_recipe_labels)
from public_aggregate import load_json,points_digest,PATH_DOMAIN,lengths,candidate_receipts,contact_counts
from failure_evidence import compiler_diagnostic_excerpt,failure_evidence,matrix_observation,GROUPS

def result_fixture():
    ids=['request-'+str(i) for i in range(25)]
    groups=['retain-six-no-contact']*6+['seek-two-clear-corners']*2+['retain-three-typed-endpoint-refusals']*3+['preserve-fourteen-original-failures']*14
    data={'schema':'blind.public-fixed-seed-radius-navigation.v1','legacyControls':25,'strictControls':25,
      'candidateRequests':25,'retainedSixNoContactCorridors':6,'completeNoContactCorners':2,
      'retainedThreeTypedRefusals':3,'preservedOtherFourteenFailures':14,'preservedUnrunJourneyStages':9,
      'rows':[{'requestID':id,'fullLayoutValidated':True,'configuration':CONFIGURATIONS[block],
               'endpointPolicy':'legacyNearestProjection' if block==0 else 'requireSuppliedXZOverPolygon'} for block in range(3) for id in ids],
      'controlChecks':[{'requestID':id,'legacyMatch':True,'strictMatch':True} for id in ids],
      'candidateAcceptanceChecks':[{'requestID':id,'group':group,'criterionPassed':True,'initialSourceContactUnchanged':True,'fullLayoutValidated':True} for id,group in zip(ids,groups)]}
    data.update(INPUT_HASHES);data['configurationOrder']=CONFIGURATIONS.copy()
    data['status']='fixed-public-fixture-seed-radius-candidate-met-declared-goals'
    for key in ['physicalAuthority','appActivation','fullFootprintSupportVerified','continuousSourceClearanceGuarantee','centerClearanceObjectiveImplemented','iOSValidated']:data[key]=False
    for key in ['all50OriginalControlsReproduced','candidateExecuted','candidateGoalsMet','allCandidateInitialContactsUnchanged','allCandidateLayoutsMatched']:data[key]=True
    return data,{'requests':[{'id':x} for x in ids]}

class LaunchSourceFixtures(unittest.TestCase):
    def test_all_31_actual_frozen_recipe_labels_are_admitted_and_casefold_unique(self):
        path=pathlib.Path(__file__).resolve().parent.parent/'exact-seed-radius-bc-preparation-20261029/prepared-stage-c-final/BUILD_RECIPE.json'
        recipe=json.loads(path.read_text());labels=validate_recipe_labels(recipe)
        self.assertEqual(labels[0],'compile-Recast-Recast');self.assertEqual(len(labels),31)
        self.assertEqual(len({x.casefold() for x in labels}),31)
        bad=copy.deepcopy(recipe);bad['commands'][1]['label']=labels[0].swapcase()
        with self.assertRaises(GuardFailure):validate_recipe_labels(bad)
    def test_safe_label_grammar_still_refuses_paths_punctuation_and_unicode(self):
        for label in ['', '../file','a/b','a b','a;cmd','a\ncmd','A'*81,'é']:
            self.assertFalse(safe_command_label(label))
        self.assertTrue(safe_command_label('compile-DetourCrowd-DetourCrowd'))
    def test_pre_spawn_refusal_records_not_started_without_subprocess(self):
        guard=types.SimpleNamespace(records=[],failure=None,retire=lambda:None,save=lambda:None)
        with self.assertRaises(GuardFailure):Guard.run(guard,['never-executed'],'../invalid')
        row=guard.records[0]
        self.assertFalse(row['processStarted']);self.assertFalse(row['processCompleted'])
        self.assertIsNone(row['exitCode']);self.assertEqual(row['reasonCode'],'COMMAND_LABEL_REFUSED')
    def test_tool_alias_driver_name_preserved_and_retarget_refused(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);(root/'clang').write_text('pinned');(root/'other').write_text('other')
            alias=root/'clang++';alias.symlink_to(root/'clang')
            selection={'clang++':{'invocationPath':str(alias),'resolvedPath':str(root/'clang')}}
            verify_tool_selections(selection)
            self.assertEqual(resolved_native_command(['/usr/bin/xcrun','clang++','-x'],{'clang++':str(alias)})[0],str(alias))
            alias.unlink();alias.symlink_to(root/'other')
            with self.assertRaises(GuardFailure):verify_tool_selections(selection)
    def test_compiler_environment_allowlist_preserves_runner_cleanup_only(self):
        parent={x:'injected' for x in ['CPATH','CPLUS_INCLUDE_PATH','LIBRARY_PATH','SDKROOT','TOOLCHAINS','DYLD_INSERT_LIBRARIES','DEVELOPER_DIR','SWIFT_EXEC','HOME','GITHUB_TOKEN']}
        parent['RUNNER_TRACKING_ID']='cleanup-id'
        env=child_environment(pathlib.Path('/owned/output'),parent)
        self.assertEqual(env['RUNNER_TRACKING_ID'],'cleanup-id');self.assertEqual(env['HOME'],'/owned/output/home')
        self.assertFalse(set(parent)-{'HOME','RUNNER_TRACKING_ID'} & set(env))
    def test_resolved_tool_is_invoked_without_reselecting_xcrun(self):
        for name in ['clang++','swiftc','ar']:
            self.assertEqual(resolved_native_command(['/usr/bin/xcrun',name,'-x'],{name:'/pinned/'+name}),['/pinned/'+name,'-x'])
        with self.assertRaises(GuardFailure):resolved_native_command(['/usr/bin/xcrun','other'],{})
    def test_copied_build_inputs_are_rehashed(self):
        source=pathlib.Path(__file__).resolve().parent.parent/'exact-seed-radius-bc-preparation-20261029/prepared-stage-c-final'
        recipe=json.loads((source/'BUILD_RECIPE.json').read_text())
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d)
            for name in recipe['generatedSources']:
                dst=root/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source/name,dst)
            verify_generated_sources(root,recipe)
            (root/'adapter-observed.cpp').write_text('wrong copied source')
            with self.assertRaises(GuardFailure):verify_generated_sources(root,recipe)
    def test_result_configuration_or_endpoint_policy_mismatch_refused(self):
        for key,value in [('configuration','other'),('endpointPolicy','legacyNearestProjection')]:
            data,requests=result_fixture();data['rows'][50][key]=value
            with self.assertRaises(GuardFailure):validate_result(data,requests)
    def test_result_frozen_input_digest_mismatch_refused(self):
        data,requests=result_fixture();data['maskInputsSHA256']='0'*64
        with self.assertRaises(GuardFailure):validate_result(data,requests)
    def test_result_wrong_success_status_refused(self):
        data,requests=result_fixture();data['status']='wrong'
        with self.assertRaises(GuardFailure):validate_result(data,requests)
    def test_public_aggregate_enforces_encoded_byte_cap(self):
        with self.assertRaises(GuardFailure):encode_public_aggregate({'value':'x'*131072})
    def terminal_fixture(self,fail):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);record={'status':'passed-fixed-source-route-matrix'}
            class FakeGuard:
                started=time.monotonic();maximumCPU=1.;maximumRSS=1000;maximumOutput=0;failure=None
                def finish(self):
                    self.maximumCPU=125. if fail else 5.
                    self.maximumOutput=output_bytes(root)
                    if fail:raise GuardFailure('aggregate CPU cap')
                def save(self):(root/'resource.json').write_text('{}')
            guard=FakeGuard()
            def save():(root/'launch.json').write_text(json.dumps(record))
            encoded,error=finalize_public_aggregate(root,{'status':record['status']},guard,record,save)
            result=json.loads(encoded)
            self.assertEqual(result['resources']['observedAggregateCPUSeconds'],125. if fail else 5.)
            self.assertEqual(result['resources']['finalOwnedOutputBytes'],output_bytes(root))
            return result,error
    def test_terminal_resource_snapshot_includes_finish_updates(self):
        result,error=self.terminal_fixture(False)
        self.assertIsNone(error);self.assertTrue(result['resources']['terminalObservationCompleted'])
    def test_terminal_cap_failure_exports_breach_not_earlier_good_snapshot(self):
        result,error=self.terminal_fixture(True)
        self.assertIsNotNone(error);self.assertTrue(result['resources']['limitBreached']['cpu'])
        self.assertEqual(result['status'],'failed-or-inconclusive')
    def test_exact_materialized_closure_needs_no_omitted_audit_bytes(self):
        here=pathlib.Path(__file__).resolve().parent
        source=here.parent/'exact-seed-radius-bc-preparation-20261029'
        original=json.loads((source/'CANDIDATE_MANIFEST.json').read_text())
        material=json.loads((here/'MATERIALIZATION_MANIFEST.json').read_text())
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d)
            shutil.copyfile(source/'CANDIDATE_MANIFEST.json',root/'CANDIDATE_MANIFEST.json')
            for name in material['files']:
                dst=root/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source/name,dst)
            self.assertFalse((root/'REMOTE_TREE.json').exists())
            self.assertEqual(len(verify_source_packet(root,original,material)['commands']),31)
            bad=copy.deepcopy(material);bad['files'].pop('SOURCE_CHECKS.json')
            with self.assertRaises(GuardFailure):verify_source_packet(root,original,bad)
    def test_cpu_seconds_and_fraction(self):
        self.assertAlmostEqual(parse_cpu('2:03.25'),123.25)
        self.assertEqual(parse_cpu('01:02:03'),3723)
        self.assertEqual(parse_cpu('1-01:02:03'),90123)
    def test_cpu_malformed_refuses(self):
        for value in ['NaN','1','2:60','1:60:00','1-0:00','-1:00','0:00 extra']:
            with self.assertRaises(GuardFailure):parse_cpu(value)
    def test_ps_units_and_child_cpu(self):
        rows=parse_ps(b' 10 1 10 0:01.25 1024\n11 10 10 0:02.00 2048\n')
        self.assertEqual(rows[10]['rss'],1048576);self.assertEqual(rows[11]['cpu'],2)
    def test_ps_malformed_and_duplicates(self):
        for value in [b'10 1 10 0:00 1\n10 1 10 0:00 1',b'1 2 3 0:00 -1',b'1 2 3 0:00',b'1 2 3 nope 10',b'x'*1048577]:
            with self.assertRaises((GuardFailure,ValueError)):parse_ps(value)
    def test_family_includes_orphaned_owned_group_and_descendants(self):
        rows=parse_ps(b'10 1 8 0:00 10\n11 10 11 0:00 10\n12 11 11 0:00 10\n13 1 11 0:00 10\n14 1 14 0:00 10\n')
        self.assertEqual(set(family(rows,10,{11})),{10,11,12,13})
    def test_family_does_not_select_unrelated_process(self):
        rows=parse_ps(b'10 1 8 0:00 10\n14 1 14 0:00 10\n')
        self.assertEqual(set(family(rows,10,set())),{10})
    def test_only_declared_command_roots(self):
        roots={'@build':pathlib.Path('/private/output')}
        self.assertEqual(resolve_argument('@build/file',roots),'/private/output/file')
        for value in ['@build/../outside','@unknown/file']:
            with self.assertRaises(GuardFailure):resolve_argument(value,roots)
    def test_input_path_escape_refused(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);(root/'file').write_text('x')
            self.assertEqual(under(root,'file'),root/'file')
            with self.assertRaises(GuardFailure):under(root,'../outside')
    def test_output_counts_tmp_and_caches(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);(root/'tmp').mkdir();(root/'module-cache').mkdir()
            (root/'tmp/a').write_bytes(b'abc');(root/'module-cache/b').write_bytes(b'12345')
            self.assertEqual(output_bytes(root),8)
    def test_output_symlink_refused(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);(root/'outside').symlink_to('/tmp')
            with self.assertRaises(GuardFailure):output_bytes(root)
    def test_observer_exact_names_not_aggregate_only(self):
        names=['fixture-'+str(i) for i in range(15)]
        tail='{"schema":1,"scope":"read-only-seed-observer","groups":15,"checks":100,"passed":100,"physicalAuthority":false}'
        text='\n'.join(['PASS observer/'+n for n in names]+[tail])
        self.assertEqual(validate_observer(text,names)['groups'],15)
        with self.assertRaises(GuardFailure):validate_observer(text.replace('fixture-0','wrong'),names)
        with self.assertRaises(GuardFailure):validate_observer(tail,names)
    def test_complete_route_summary_admitted(self):
        data,requests=result_fixture();self.assertTrue(validate_result(data,requests)['candidateGoalsMet'])
    def test_failed_control_not_hidden_by_green_aggregate(self):
        data,requests=result_fixture();data['controlChecks'][0]['legacyMatch']=False
        with self.assertRaises(GuardFailure):validate_result(data,requests)
    def test_missing_or_reordered_route_identity_refused(self):
        data,requests=result_fixture();data['rows']=copy.deepcopy(data['rows']);data['rows'][50]['requestID']='other'
        with self.assertRaises(GuardFailure):validate_result(data,requests)
    def test_candidate_collision_failure_or_new_authority_refused(self):
        data,requests=result_fixture();data['candidateAcceptanceChecks'][6]['criterionPassed']=False
        with self.assertRaises(GuardFailure):validate_result(data,requests)
        data,requests=result_fixture();data['physicalAuthority']=True
        with self.assertRaises(GuardFailure):validate_result(data,requests)

class AggregateSourceFixtures(unittest.TestCase):
    def test_maximum_259_segments_and_518_endpoints_supported(self):
        segment={'bodyContact':False,'marginContact':False,'obstacleSurfaceIDs':[],'furnitureBoundIDs':[],'floorContactIDs':[]}
        self.assertEqual(contact_counts([segment]*259)['segmentCount'],259)
        self.assertEqual(len(points_digest([[0,0,0]]*518)),64)
        with self.assertRaises(GuardFailure):contact_counts([segment]*260)
        with self.assertRaises(GuardFailure):points_digest([[0,0,0]]*519)
    def fixture(self):
        repo=pathlib.Path(__file__).resolve().parents[2]/'blind'
        request_text=(repo/'research/native-floor-import-repair-20261028/strict-endpoint-probe/REQUESTS_49A.json').read_text()
        reference_text=(repo/'research/native-floor-import-repair-20261028/native-strict-result-40791907324/RESULT.json').read_text()
        self.assertEqual(hashlib.sha256(request_text.encode()).hexdigest(),'e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51')
        self.assertEqual(hashlib.sha256(reference_text.encode()).hexdigest(),'0858272d1faca7e16268b772f0cd164652c08eb22277d36514d2eae72b803893')
        requests=load_json(request_text);reference=load_json(reference_text)
        rows=copy.deepcopy([r for r in reference['rows'] if r['endpointPolicy']=='requireSuppliedXZOverPolygon'])
        for row,request in zip(rows,requests['requests']):
            row['configuration']='stock-AND-exact-seed-radius-veto-strict-endpoints'
            row['fullLayoutValidated']=True;row['routeQueryAttempted']=not row.get('buildFailed',False)
            row['requestedStart']=copy.deepcopy(request['requestedStart'])
            row['requestedGoal']=copy.deepcopy(request['requestedGoal'])
        # Parser fixture only: labels stock reference rows as candidate-shaped
        # input. This does NOT assert that the production veto produced them.
        data={'schema':'blind.public-fixed-seed-radius-navigation.v1','candidateRequests':25,'rows':reference['rows']+rows}
        return data,requests,reference
    def test_canonical_path_encoding(self):
        expected=hashlib.sha256(PATH_DOMAIN+struct.pack('<I',1)+bytes.fromhex('0000803f0000008000000040')).hexdigest()
        self.assertEqual(points_digest([[1,-0.0,2]]),expected)
    def test_negative_zero_survives_json(self):
        p=load_json('[[-0,0,1]]');self.assertLess(math.copysign(1,p[0][0]),0)
        self.assertNotEqual(points_digest(p),points_digest([[0,0,1]]))
    def test_order_and_count_are_bound(self):
        self.assertNotEqual(points_digest([[1,2,3],[4,5,6]]),points_digest([[4,5,6],[1,2,3]]))
        self.assertNotEqual(points_digest([]),points_digest([[0,0,0]]))
    def test_nonfinite_or_nonxyz_rejected(self):
        for p in [[[1,2]],[[1,2,float('nan')]],[[True,0,0]],[[0,0,1e40]]]:
            with self.assertRaises(GuardFailure):points_digest(p)
    def test_lengths_have_declared_3d_and_xz_meaning(self):
        self.assertEqual(lengths([[0,0,0],[3,4,0]]),(5,3))
    def test_25_reference_shaped_receipts_without_coordinates(self):
        data,requests,reference=self.fixture();out=candidate_receipts(data,requests,reference)
        self.assertEqual(len(out),25);self.assertEqual(sum(x['matchesPublishedReferencePath']['strict'] is True for x in out),8)
        def visit(value):
            if isinstance(value,dict):
                self.assertFalse(set(value)&{'routePoints','requestedStart','requestedGoal','projectedStart','projectedGoal','from','to','obstacleSurfaceIDs','furnitureBoundIDs','floorContactIDs'})
                for child in value.values():visit(child)
            elif isinstance(value,list):
                for child in value:visit(child)
        visit(out)
        self.assertTrue(all(x['pathPointCount']==0 and x['orderedPathFloat32SHA256'] is None for x in out if not x['pathAvailable']))
    def test_failed_corner_contact_is_retained_not_relabelled(self):
        data,requests,reference=self.fixture();out=candidate_receipts(data,requests,reference)
        corners=[x for x in out if ':hall-corner:' in x['requestID'] and x['nativeSucceeded']]
        self.assertEqual(len(corners),2);self.assertTrue(all(x['marginContact'] is True for x in corners))
        self.assertTrue(all(x['routeContactCounts']['marginContactSegmentCount']>0 for x in corners))
    def test_wrong_body_or_endpoint_identity_refused(self):
        data,requests,reference=self.fixture();data['rows'][50]['effectiveRadius']+=0.01
        with self.assertRaises(GuardFailure):candidate_receipts(data,requests,reference)
        data,requests,reference=self.fixture();data['rows'][50]['requestedStart'][0]+=0.1
        with self.assertRaises(GuardFailure):candidate_receipts(data,requests,reference)

class Attempt002EvidenceFixtures(unittest.TestCase):
    def recipe(self):
        return json.loads((pathlib.Path(__file__).resolve().parent.parent/'exact-seed-radius-bc-preparation-20261029/prepared-stage-c-final/BUILD_RECIPE.json').read_text())
    def matrix(self):
        shaped,requests,reference=AggregateSourceFixtures().fixture()
        data,_=result_fixture();data['rows']=shaped['rows']
        for i,row in enumerate(data['rows']):
            request=requests['requests'][i%25];block=i//25
            row['configuration']=CONFIGURATIONS[block];row['requestedStart']=copy.deepcopy(request['requestedStart']);row['requestedGoal']=copy.deepcopy(request['requestedGoal']);row['fullLayoutValidated']=True
        repo=pathlib.Path(__file__).resolve().parents[2]/'blind'
        masks=load_json((repo/'research/native-floor-import-repair-20261028/edt-navigation-probe/EDT_MASK_INPUTS.json').read_text())
        ids=[r['id'] for r in requests['requests']];group={id:name for key,(name,counter,n) in GROUPS.items() for id in masks['fixedAcceptanceIDs'][key]}
        data['controlChecks']=[{'requestID':id,'legacyMatch':True,'strictMatch':True} for id in ids]
        data['candidateAcceptanceChecks']=[{'requestID':id,'group':group[id],'criterionPassed':True,'initialSourceContactUnchanged':True,'fullLayoutValidated':True} for id in ids]
        return data,requests,masks
    def test_failed_corner_counts_export_without_goals_true(self):
        data,requests,masks=self.matrix()
        for row in data['candidateAcceptanceChecks']:
            if row['group']=='seek-two-clear-corners':row['criterionPassed']=False
        data['completeNoContactCorners']=0;data['candidateGoalsMet']=False
        data['status']='fixed-public-fixture-seed-radius-candidate-failed-declared-goals'
        observed=matrix_observation(data,requests,masks)
        self.assertFalse(observed['candidateGoalsMet']);self.assertEqual(observed['completeNoContactCorners'],0)
        self.assertEqual(len(observed['candidateAcceptanceChecks']),25)
    def test_failed_control_exports_flags_without_candidate_execution(self):
        data,requests,masks=self.matrix();data['controlChecks'][0]['legacyMatch']=False
        data['all50OriginalControlsReproduced']=data['candidateExecuted']=data['candidateGoalsMet']=False
        data['allCandidateInitialContactsUnchanged']=data['allCandidateLayoutsMatched']=False
        data['candidateRequests']=0;data['rows']=data['rows'][:50];data['candidateAcceptanceChecks']=[]
        for _,counter,_ in GROUPS.values():data[counter]=0
        data['status']='original-controls-mismatch-candidate-not-executed'
        observed=matrix_observation(data,requests,masks)
        self.assertEqual(observed['candidateRequests'],0);self.assertEqual(observed['legacyControlsMatched'],24)
    def test_failed_matrix_still_rejects_wrong_input_identity(self):
        for mutation in ['digest','row','body']:
            data,requests,masks=self.matrix()
            if mutation=='digest':data['maskInputsSHA256']='0'*64
            if mutation=='row':data['rows'][0]['requestID']='other'
            if mutation=='body':data['rows'][0]['effectiveRadius']+=0.1
            with self.assertRaises(GuardFailure):matrix_observation(data,requests,masks)
    def test_inconsistent_acceptance_counters_are_not_exported(self):
        data,requests,masks=self.matrix();data['completeNoContactCorners']=1
        with self.assertRaises(GuardFailure):matrix_observation(data,requests,masks)
    def test_compiler_excerpt_excludes_snippets_paths_env_and_numeric_arrays(self):
        raw=b'/public/a.cpp:1:2: error: expected expression\n  1 | [1,2,3]\n/path/private.cpp:2:3: error: hidden\nerror: TOKEN=secret\nclang++: error: missing /Users/private/file\nerror: values [1,2,3]\nADMISSION secret\n'
        lines,truncated=compiler_diagnostic_excerpt(raw,{'/public/a.cpp':'repository/a.cpp'})
        text='\n'.join(lines);self.assertIn('repository/a.cpp:1:2: error:',text)
        for forbidden in ['secret','/Users','private.cpp','1,2,3','ADMISSION','1 |']:self.assertNotIn(forbidden,text)
        self.assertIn('[path]',text);self.assertIn('[numeric-array-withheld]',text)
    def test_compiler_excerpt_has_64k_20line_4k_bounds(self):
        raw=(b'/public/a.cpp:1:2: error: '+b'x'*1000+b'\n')*100
        lines,truncated=compiler_diagnostic_excerpt(raw,{'/public/a.cpp':'repository/a.cpp'})
        self.assertTrue(truncated);self.assertLessEqual(len(lines),20)
        self.assertLessEqual(sum(len(x)+1 for x in lines),4096);self.assertTrue(all(len(x)<=384 for x in lines))
    def evidence(self,label,phase,pins=True,started=True):
        class Fake:pass
        guard=Fake();guard.records=[{'index':7,'label':label,'processStarted':started,'processCompleted':started,'exitCode':1 if started else None,'reasonCode':'COMMAND_EXIT_NONZERO' if started else 'COMMAND_LABEL_REFUSED'}]
        record={'phase':phase,'controlledReasonCode':guard.records[0]['reasonCode']}
        for key in ['sourcePinsBefore','sourcePinsAfter','toolPinsBefore','toolPinsAfter','generatedBuildPinsBefore','generatedBuildPinsAfter']:record[key]=pins
        # Noncompiler/pin-failed branches must return before touching an absent file/root.
        return failure_evidence(record,guard,self.recipe(),{},pathlib.Path('/nonexistent-private-output'))
    def test_native_matrix_and_observer_stderr_never_read_or_exported(self):
        for label,phase in [('probe-run','route-matrix'),('observer-tests-run','observer-test')]:
            row=self.evidence(label,phase)
            self.assertEqual(row['compilerDiagnostic']['status'],'notCompilerPhase');self.assertEqual(row['compilerDiagnostic']['lines'],[])
    def test_unverified_or_unstarted_compiler_has_no_stderr_excerpt(self):
        self.assertEqual(self.evidence('compile-Recast-Recast','cxx-compile',pins=False)['compilerDiagnostic']['status'],'pinsNotVerified')
        row=self.evidence('compile-Recast-Recast','cxx-compile',started=False)
        self.assertEqual(row['recipeCommandIndex'],1);self.assertFalse(row['processStarted'])
        self.assertEqual(row['compilerDiagnostic']['status'],'notStarted')
if __name__=='__main__':unittest.main(verbosity=2)
