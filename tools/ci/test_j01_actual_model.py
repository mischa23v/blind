import contextlib,importlib.util,io,json,os,pathlib,subprocess,sys,tempfile,unittest
from unittest import mock
P=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('j01_runner',P/'j01-actual-model.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
SHA='a'*40

def env(root='/tmp'):
 return dict(GITHUB_ACTIONS='true',GITHUB_REPOSITORY='mischa23v/blind',GITHUB_SHA=SHA,GITHUB_WORKFLOW_SHA=SHA,GITHUB_RUN_ID='123',GITHUB_RUN_ATTEMPT='1',GITHUB_JOB='j01-observation',GITHUB_WORKFLOW_REF=m.WORKFLOW,GITHUB_EVENT_NAME='push',GITHUB_REF=m.BRANCH,GITHUB_SERVER_URL='https://github.com',RUNNER_ENVIRONMENT='github-hosted',RUNNER_TEMP=root,GITHUB_WORKSPACE=str(m.R))
class Tests(unittest.TestCase):
 def setUp(self):m.RUN_DEADLINE=float('inf')
 def test_context_exact(self):self.assertEqual(m.context(env())['GITHUB_SHA'],SHA)
 def test_context_rejects_fork_pr_branch_workflow_job_sha_and_override(self):
  edits={'GITHUB_ACTIONS':'false','GITHUB_REPOSITORY':'fork/blind','GITHUB_SHA':'invalid','GITHUB_WORKFLOW_SHA':'b'*40,'GITHUB_RUN_ID':'0','GITHUB_RUN_ATTEMPT':'-1','GITHUB_JOB':'other','GITHUB_WORKFLOW_REF':m.WORKFLOW+'x','GITHUB_EVENT_NAME':'pull_request','GITHUB_REF':'refs/heads/master','GITHUB_SERVER_URL':'https://example.org','RUNNER_ENVIRONMENT':'self-hosted','BLIND_J01_CONFIG':'external','BLIND_J01_RECEIPT_SHA':'external','XCODE_XCCONFIG_FILE':'external','OTHER_SWIFT_FLAGS':'-D OTHER','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'OTHER','SDKROOT':'external','TOOLCHAINS':'external','DYLD_INSERT_LIBRARIES':'external','PYTHONPATH':'external','GIT_DIR':'external','GIT_WORK_TREE':'external','GIT_INDEX_FILE':'external','GIT_CONFIG':'external','GIT_CONFIG_GLOBAL':'external','GIT_CONFIG_SYSTEM':'external','GIT_CONFIG_PARAMETERS':'external','GIT_CONFIG_COUNT':'1'}
  for key,value in edits.items():
   with self.subTest(key=key),self.assertRaises(ValueError):m.context(dict(env(),**{key:value}))
 def test_root_exact_and_exclusive(self):
  with tempfile.TemporaryDirectory() as d:
   root=m.root_path(env(str(pathlib.Path(d).resolve(strict=True))));self.assertEqual(root.name,'blind-j01-123-1');root.mkdir()
   with self.assertRaises(FileExistsError):root.mkdir()
 def test_root_symlink_and_traversal_refused(self):
  with tempfile.TemporaryDirectory() as d:
   target=pathlib.Path(d).resolve(strict=True);(target/'link').symlink_to(target,target_is_directory=True)
   for value in (str(target/'link'),str(target/'x'/'..')):
    with self.subTest(value=value),self.assertRaises(ValueError):m.root_path(env(value))
 def test_fixed_default_build_command(self):
  result=m.build_argv(pathlib.Path('/fresh'))
  self.assertEqual(result,['/usr/bin/xcodebuild','-project','ios/BlindAssist.xcodeproj','-scheme','BlindAssist','-configuration','Debug','-jobs','2','-derivedDataPath','/fresh/DerivedData','CODE_SIGNING_ALLOWED=NO','-destination','generic/platform=iOS Simulator','-parallel-testing-enabled','NO','build-for-testing'])
  self.assertNotIn('BLIND_J01',str(result));self.assertNotIn('BLIND_FOUNDATION_MODELS',str(result))
 def test_descriptor_exact_one(self):
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d)
   with self.assertRaises(ValueError):m.select_descriptor(root)
   p=root/'one.xctestrun';p.touch();self.assertEqual(m.select_descriptor(root),p)
   (root/'two.xctestrun').touch()
   with self.assertRaises(ValueError):m.select_descriptor(root)
 def test_command_observes_nonzero_without_rewriting(self):
  with tempfile.TemporaryDirectory() as d:
   r=m.command([sys.executable,'-c','raise SystemExit(7)'],pathlib.Path(d)/'run.log',2,4096)
   self.assertEqual(r['exit_code'],7);self.assertEqual(r['reason'],'completed');self.assertFalse(m.good(r))
 def test_command_success_receipt_and_fresh_logs(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d)/'run.log';r=m.command([sys.executable,'-c','print("scalar")'],p,2,4096)
   self.assertTrue(m.good(r));self.assertEqual(json.loads(p.with_suffix('.command.json').read_text()),r)
   with self.assertRaises(FileExistsError):m.command([sys.executable,'-c','pass'],p,2,4096)
 def test_command_deadline_is_failure(self):
  with tempfile.TemporaryDirectory() as d:
   r=m.command([sys.executable,'-c','import time;time.sleep(5)'],pathlib.Path(d)/'run.log',.1,4096)
   self.assertEqual(r['reason'],'deadline');self.assertNotEqual(r['exit_code'],0);self.assertLess(r['wall_ms'],2000)
 def test_command_output_budget_is_failure(self):
  with tempfile.TemporaryDirectory() as d:
   r=m.command([sys.executable,'-c','print("x"*8192)'],pathlib.Path(d)/'run.log',2,128)
   self.assertEqual(r['reason'],'output_cap');self.assertFalse(m.good(r))
 def test_command_request_pipe_cap_before_launch(self):
  with mock.patch.object(m.subprocess,'Popen') as p:
   for data in (b'x'*4097,'not bytes'):
    with self.assertRaises(ValueError):m.command([],pathlib.Path('/unused'),1,1024,input_bytes=data)
   p.assert_not_called()
 def test_command_bounded_stdin(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d)/'run.log';r=m.command([sys.executable,'-c','import sys;print(len(sys.stdin.buffer.read()))'],p,2,128,input_bytes=b'x'*4096)
   self.assertTrue(m.good(r));self.assertEqual(p.read_text().strip(),'4096')
 def test_successful_leader_still_kills_owned_group(self):
  with tempfile.TemporaryDirectory() as d,mock.patch.object(m.os,'killpg',wraps=os.killpg) as kill:
   r=m.command([sys.executable,'-c','pass'],pathlib.Path(d)/'run.log',2,128)
   self.assertTrue(m.good(r));self.assertGreaterEqual(kill.call_count,1)
 def test_global_budget_preserves_cleanup_reserve(self):
  with mock.patch.object(m.time,'monotonic',return_value=100),mock.patch.object(m.subprocess,'Popen') as p:
   m.RUN_DEADLINE=199
   with self.assertRaises(ValueError):m.command([],pathlib.Path('/unused'),1,1024)
   p.assert_not_called()
 def test_global_cleanup_deadline_also_fails_closed(self):
  with mock.patch.object(m.time,'monotonic',return_value=100),mock.patch.object(m.subprocess,'Popen') as p:
   m.RUN_DEADLINE=99
   with self.assertRaises(ValueError):m.command([],pathlib.Path('/unused'),1,1024,cleanup=True)
   p.assert_not_called()
 def test_create_only_exact_installed_type_runtime(self):
  calls=[];mark=[];uid='12345678-1234-1234-1234-123456789012'
  def tool(args,*unused,**kwargs):
   calls.append(args)
   if args[1]=='devicetypes':return json.dumps({'devicetypes':[{'identifier':m.TYPE}]}).encode()
   if args[1]=='runtimes':return json.dumps({'runtimes':[{'identifier':m.RUNTIME,'isAvailable':True}]}).encode()
   return uid.encode()
  with mock.patch.object(m,'tool',side_effect=tool):self.assertEqual(m.create_simulator(pathlib.Path('/unused'),0,lambda:mark.append(True)),uid)
  self.assertEqual(mark,[True]);self.assertEqual(calls[-1],['create','Blind-J01-0',m.TYPE,m.RUNTIME])
 def test_missing_runtime_never_attempts_create(self):
  mark=[]
  with mock.patch.object(m,'tool',return_value=b'{}'),self.assertRaises(ValueError):m.create_simulator(pathlib.Path('/unused'),0,lambda:mark.append(True))
  self.assertEqual(mark,[])
 def test_ambiguous_create_not_cleanup_proof(self):
  mark=[];values=[json.dumps({'devicetypes':[{'identifier':m.TYPE}]}).encode(),json.dumps({'runtimes':[{'identifier':m.RUNTIME,'isAvailable':True}]}).encode(),b'not a UUID']
  with mock.patch.object(m,'tool',side_effect=values),self.assertRaises(ValueError):m.create_simulator(pathlib.Path('/unused'),0,lambda:mark.append(True))
  self.assertEqual(mark,[True])
 def test_cleanup_requires_delete_and_absence(self):
  ok={'exit_code':0,'reason':'completed'}
  for devices,expected in [({'devices':{}},True),({'devices':{'runtime':[{'udid':'owned'}]}},False)]:
   with mock.patch.object(m,'command',return_value=ok) as call,mock.patch.object(m,'tool',return_value=json.dumps(devices).encode()):
    self.assertEqual(m.cleanup_simulator(pathlib.Path('/unused'),'owned'),expected)
    self.assertTrue(all(c.kwargs['cleanup'] for c in call.call_args_list))
  with mock.patch.object(m,'command',return_value={'exit_code':1,'reason':'completed'}),mock.patch.object(m,'tool') as t:
   self.assertFalse(m.cleanup_simulator(pathlib.Path('/unused'),'owned'));t.assert_not_called()
 def test_boolean_exit_not_success(self):self.assertFalse(m.good({'exit_code':False,'reason':'completed'}))
 def test_emit_scalar_cap_and_no_artifact(self):
  with mock.patch.dict(os.environ,{},clear=True),contextlib.redirect_stdout(io.StringIO()) as output:m.emit({'status':'incomplete'})
  self.assertEqual(output.getvalue(),'J01_CI_RECEIPT={"status":"incomplete"}\n')
  with self.assertRaises(ValueError):m.emit({'x':'x'*65536})
 def test_workflow_trust_boundary_and_no_storage(self):
  s=(m.R/'.github/workflows/j01-actual-model.yml').read_text()
  for token in ("github.event_name == 'push'","github.repository == 'mischa23v/blind'","github.event.repository.private == false",m.BRANCH,'runs-on: xcode-27',"BLIND_UPLOAD_ARTIFACTS: 'false'",'ref: ${{ github.sha }}','persist-credentials: false','timeout-minutes: 35','timeout-minutes: 28'):
   self.assertIn(token,s)
  for token in ('upload-artifact','actions/cache','pull_request:','workflow_dispatch:','sudo ','curl ','wget ','services:','secrets.'):
   self.assertNotIn(token,s)
 def test_exact_scripts_and_non_success_claim(self):
  self.assertEqual(m.SCENARIOS,('REQ-SC02-1','REQ-SC02-3','REQ-SC02-4'))
  s=(P/'j01-actual-model.py').read_text()
  for token in ("metadata.collect(response,scenario,ctx['GITHUB_SHA'],receipt_sha)","all(x.get('status')=='observed'", "not acquisition['attempted']", "row['cleanup_completed']", "'fullJourneyComplete':False", "'runtimeLoadedBinaryVerified':False", "attestation.source_provenance(R,ctx['GITHUB_SHA'])==before['provenance']", "attestation.read_json(case/'wrapper.log',1024*1024)"):
   self.assertIn(token,s)
 def test_mode_does_not_accept_config_or_digest(self):
  with mock.patch.object(sys,'argv',['runner','run','--receipt','external']),self.assertRaises(ValueError):m.main()

 def simulated_run(self,*,model_available=True,wrapper_exit=0,cleanup=True,ambiguous_create=False,build_exit=0,changed_source=False,malformed_response=False,extra_scripts=False,changed_selected_script=False,attestation_error_stage=None,attestation_error=None):
  import test_collect_j01_metadata as fixtures
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d).resolve(strict=True);repo=root/'repo';repo.mkdir();packet=repo/'packet';packet.mkdir()
   scripts=json.loads(json.dumps(m.metadata.SUPPORTED))
   if extra_scripts:scripts['REQ-SC53-1']=[{'unselected':'authored future script'}]
   if changed_selected_script:scripts['REQ-SC02-1'][0]['text']='changed'
   (packet/'SUPPORTED.json').write_text(json.dumps(scripts))
   workflow=repo/'.github/workflows/j01-actual-model.yml';workflow.parent.mkdir(parents=True);workflow.write_text('reviewed fixture')
   e=env(str(root));e['GITHUB_WORKSPACE']=str(repo);ctx=m.context(e);calls=[];emitted=[]
   before={'provenance':{'actual_head':SHA,'tracked_source_clean':True}}
   def proof(*args,**kwargs):return dict(verified=True,runtimeLoadedBinaryVerified=False,sourceCommit=SHA,receiptSHA256=args[3],scope='selected prebuilt artifact bytes match independently trusted build receipt; runtime load not attested',trustBasis='external reviewed CI receipt digest, not caller source echo')
   def command(argv,log,*args,**kwargs):
    calls.append(argv)
    if argv[0]=='/usr/bin/xcodebuild':
     products=log.parent/'DerivedData/Build/Products';products.mkdir(parents=True);(products/'one.xctestrun').write_text('fixture')
     log.write_text('');return dict(argv=argv,exit_code=build_exit,reason='completed')
    request=json.loads(kwargs['input_bytes']);response=fixtures.fixture(request['scenario_id']);response['sourceAttestation']['receiptSHA256']=m.attestation.digest(log.parents[1]/'build-receipt.json')['sha256']
    if malformed_response:response['sourceAttestation']=[]
    if not model_available:response['events'][-1]['model_identity']['provider_availability_before_dispatch']='modelNotReady'
    log.write_text(json.dumps(response));return dict(argv=argv,exit_code=wrapper_exit,reason='completed')
   def create(folder,index,attempted):
    attempted()
    if ambiguous_create:raise ValueError('PRIVATE creation error')
    return '12345678-1234-1234-1234-123456789012'
   source=({'actual_head':'b'*40} if changed_source else before['provenance'])
   with contextlib.ExitStack() as stack:
    for obj,key,value in [(m,'R',repo),(m,'P',packet),(m.sys,'platform','darwin')]:stack.enter_context(mock.patch.object(obj,key,value))
    stack.enter_context(mock.patch.dict(os.environ,e,clear=True))
    for obj,key,kw in [(m,'verify_checkout',{'return_value':None}),(m,'command',{'side_effect':command}),(m,'create_simulator',{'side_effect':create}),(m,'tool',{'return_value':b'{}'}),(m,'cleanup_simulator',{'return_value':cleanup}),(m,'emit',{'side_effect':emitted.append}),(m.attestation,'begin',{'return_value':before}),(m.attestation,'finish',{'return_value':{'ci':ctx,'sourceCommit':SHA}}),(m.attestation,'verify',{'side_effect':proof}),(m.attestation,'source_provenance',{'return_value':source})]:stack.enter_context(mock.patch.object(obj,key,**kw))
    if attestation_error_stage is not None:stack.enter_context(mock.patch.object(m.attestation,attestation_error_stage,side_effect=attestation_error))
    code=m.run()
   result=json.loads((root/'blind-j01-123-1/RESULT.json').read_text())
   return code,result,calls,emitted
 def test_owned_temp_alias_does_not_relax_runtime_root_guard(self):
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d).resolve(strict=True);real=root/'real';real.mkdir()
   alias=root/'alias';alias.symlink_to(real,target_is_directory=True)
   with mock.patch.object(tempfile,'tempdir',str(alias)):
    code,r,_,_=self.simulated_run();self.assertEqual(code,0);self.assertFalse(r['fullJourneyComplete'])
    with self.assertRaises(ValueError):m.root_path(env(str(alias)))
 def test_simulated_same_job_three_script_positive_is_not_journey_success(self):
  code,r,calls,emitted=self.simulated_run();self.assertEqual(code,0);self.assertEqual(r['status'],'observed');self.assertEqual(len(calls),4);self.assertEqual(len(r['scriptReceipts']),3)
  self.assertFalse(r['fullJourneyComplete']);self.assertFalse(r['runtimeLoadedBinaryVerified']);self.assertNotIn('PRIVATE',json.dumps(emitted))
 def test_simulated_model_unavailable_preserves_nonzero(self):
  code,r,_,_=self.simulated_run(model_available=False);self.assertEqual(code,1);self.assertEqual(r['status'],'incomplete');self.assertEqual(len(r['scriptReceipts']),3)
 def test_simulated_wrapper_failure_never_becomes_model_observation(self):
  code,r,_,_=self.simulated_run(wrapper_exit=2);self.assertEqual(code,1);self.assertTrue(all(x['wrapper_exit']==2 for x in r['scriptReceipts']))
 def test_simulated_cleanup_failure_withholds_later_scripts(self):
  code,r,calls,_=self.simulated_run(cleanup=False);self.assertEqual(code,1);self.assertEqual(len(r['scriptReceipts']),1);self.assertEqual(len(calls),2)
 def test_simulated_ambiguous_creation_stops_without_false_cleanup(self):
  code,r,calls,emitted=self.simulated_run(ambiguous_create=True);self.assertEqual(code,1);self.assertEqual(len(calls),1);self.assertEqual(len(r['scriptReceipts']),1);self.assertFalse(r['scriptReceipts'][0]['cleanup_completed']);self.assertNotIn('PRIVATE',json.dumps(emitted))
 def test_simulated_build_failure_prevents_model_or_receipt_claim(self):
  code,r,calls,_=self.simulated_run(build_exit=65);self.assertEqual(code,1);self.assertEqual(len(calls),1);self.assertFalse(r['buildSucceeded']);self.assertNotIn('sourceAttestation',r);self.assertEqual(r['scriptReceipts'],[])
 def test_simulated_changed_source_never_starts_script(self):
  code,r,calls,_=self.simulated_run(changed_source=True);self.assertEqual(code,1);self.assertEqual(len(calls),1);self.assertTrue(all(x['status']=='unavailable' for x in r['scriptReceipts']))

 def test_parent_owned_mode_is_explicit_and_identity_checked(self):
  spec=importlib.util.spec_from_file_location('owned_app_adapter',m.P/'app_adapter.py');a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
  with mock.patch.dict(os.environ,{},clear=True):self.assertFalse(a.owned_parent_group())
  for marker,parent,group,session,expected in [('12',12,34,34,True),('13',12,34,34,False),('12',12,20,34,False),('12',12,34,20,False),('0',12,34,34,False),('bad',12,34,34,False)]:
   with self.subTest(marker=marker,group=group,session=session),mock.patch.dict(os.environ,{'BLIND_J01_OWNED_PARENT_PID':marker},clear=True),mock.patch.object(a.os,'getppid',return_value=parent),mock.patch.object(a.os,'getpid',return_value=34),mock.patch.object(a.os,'getpgrp',return_value=group),mock.patch.object(a.os,'getsid',return_value=session):
    if expected:self.assertTrue(a.owned_parent_group())
    else:
     with self.assertRaises(ValueError):a.owned_parent_group()
  source=(m.P/'app_adapter.py').read_text();self.assertIn('start_new_session=not owned',source);self.assertIn('if p.poll() is None:p.kill()',source);self.assertIn('os.killpg(p.pid,signal.SIGKILL)',source)
 def test_leader_exit_contains_same_group_descendant(self):
  with tempfile.TemporaryDirectory() as d:
   marker=pathlib.Path(d)/'escaped';child='import time,pathlib;time.sleep(.2);pathlib.Path('+repr(str(marker))+').write_text("escaped")'
   leader='import subprocess,sys;subprocess.Popen([sys.executable,"-c",'+repr(child)+'])'
   result=m.command([sys.executable,'-c',leader],pathlib.Path(d)/'run.log',2,128)
   self.assertTrue(m.good(result));m.time.sleep(.3);self.assertFalse(marker.exists())

 def test_actual_checkout_origin_top_level_and_push_event(self):
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d).resolve(strict=True);event=root/'event.json';event.write_text(json.dumps({'after':SHA,'ref':m.BRANCH,'repository':{'full_name':'mischa23v/blind','private':False}}))
   def query(argv,log,*args,**kwargs):
    log.write_text(str(m.R) if argv[-1]=='--show-toplevel' else 'https://github.com/mischa23v/blind.git' if argv[-1]=='remote.origin.url' else SHA)
    return {'exit_code':0,'reason':'completed'}
   with mock.patch.dict(os.environ,{'GITHUB_EVENT_PATH':str(event)}),mock.patch.object(m,'command',side_effect=query):m.verify_checkout(root,'actual',m.context(env()))
 def test_wrong_local_origin_or_push_identity_refused(self):
  for kind in ('origin','root','head','after','ref','repository','private'):
   with self.subTest(kind=kind),tempfile.TemporaryDirectory() as d:
    root=pathlib.Path(d).resolve(strict=True);event=root/'event.json';data={'after':SHA,'ref':m.BRANCH,'repository':{'full_name':'mischa23v/blind','private':False}}
    if kind in ('after','ref'):data[kind]='wrong'
    if kind=='repository':data['repository']['full_name']='fork/blind'
    if kind=='private':data['repository']['private']=True
    event.write_text(json.dumps(data))
    def query(argv,log,*args,**kwargs):
     suffix='root' if argv[-1]=='--show-toplevel' else 'origin' if argv[-1]=='remote.origin.url' else 'head'
     log.write_text('wrong' if kind==suffix else str(m.R) if suffix=='root' else 'https://github.com/mischa23v/blind' if suffix=='origin' else SHA)
     return {'exit_code':0,'reason':'completed'}
    with mock.patch.dict(os.environ,{'GITHUB_EVENT_PATH':str(event)}),mock.patch.object(m,'command',side_effect=query),self.assertRaises(ValueError):m.verify_checkout(root,'actual',m.context(env()))

 def test_nested_malformed_response_has_closed_failure_and_cleanup(self):
  code,r,_,emitted=self.simulated_run(malformed_response=True);self.assertEqual(code,1)
  self.assertTrue(all(x['error_type']=='refused' and x['cleanup_completed'] for x in r['scriptReceipts']))
  self.assertNotIn('PRIVATE',json.dumps(emitted))

 def test_additional_reviewed_scripts_never_expand_selected_three(self):
  code,r,calls,_=self.simulated_run(extra_scripts=True);self.assertEqual(code,0)
  self.assertEqual([x['scenario_id'] for x in r['scriptReceipts']],list(m.SCENARIOS));self.assertEqual(len(calls),4)
 def test_changed_original_script_is_refused_before_any_execution(self):
  code,r,calls,_=self.simulated_run(changed_selected_script=True);self.assertEqual(code,1);self.assertEqual(len(calls),1);self.assertEqual(r['scriptReceipts'],[])


 def test_closed_attestation_codes_never_echo_dynamic_error_content(self):
  for stage in m.FAILURE_STAGES:
   for error in (ValueError('/PRIVATE/path token=secret'),ValueError('symlink component refused /PRIVATE'),ValueError({'PRIVATE':'secret'}),TypeError('symlink component refused'),m.Refused('symlink component refused')):
    result=m.safe_failure(stage,error);self.assertEqual(result['failureCode'],'unclassified');self.assertNotIn('PRIVATE',json.dumps(result))
  self.assertEqual(m.safe_failure('/PRIVATE',ValueError('symlink component refused')),{'failureStage':'unclassified','failureCode':'unclassified'})
 def test_closed_attestation_codes_cover_each_fixed_guard_without_raw_output(self):
  for message,code in m.ATTESTATION_FAILURE_CODES.items():
   self.assertRegex(code,r'^attestation_[a-z0-9_]+$')
   self.assertEqual(m.safe_failure('attestation_finish',ValueError(message)),{'failureStage':'attestation_finish','failureCode':code})
  self.assertEqual(m.safe_failure('script_observations',ValueError('symlink component refused'))['failureCode'],'unclassified')
 def test_post_build_attestation_failures_stay_incomplete_without_model_calls(self):
  for stage in ('finish','verify'):
   for message in ('symlink component refused','artifact observation time budget','/PRIVATE/token secret'):
    with self.subTest(stage=stage,message=message):
     code,r,calls,emitted=self.simulated_run(attestation_error_stage=stage,attestation_error=ValueError(message))
     self.assertEqual(code,1);self.assertEqual(r['buildCommandExit'],0);self.assertFalse(r['buildSucceeded']);self.assertEqual(r['scriptReceipts'],[]);self.assertEqual(len(calls),1)
     self.assertFalse(r['runtimeLoadedBinaryVerified']);self.assertFalse(r['fullJourneyComplete']);self.assertEqual(r['failureStage'],'attestation_'+stage)
     self.assertEqual(r['failureCode'],m.ATTESTATION_FAILURE_CODES.get(message,'unclassified'));self.assertNotIn('PRIVATE',json.dumps(emitted));self.assertNotIn('secret',json.dumps(emitted))

if __name__=='__main__':unittest.main()
