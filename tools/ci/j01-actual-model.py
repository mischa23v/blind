#!/usr/bin/env python3
"""Reviewed same-job build producer/consumer; no externally supplied receipt/config."""
import hashlib,importlib.util,json,os,pathlib,re,signal,subprocess,sys,time
R=pathlib.Path(__file__).resolve().parents[2]
P=R/'research/j01-hosted-app-adapter-20261030'
sys.path.insert(0,str(P));import build_attestation as attestation
import collect_j01_metadata as metadata
BRANCH='refs/heads/codex/recovery-hazard-order-20261027'
WORKFLOW='mischa23v/blind/.github/workflows/j01-actual-model.yml@'+BRANCH
SCENARIOS=('REQ-SC02-1','REQ-SC02-3','REQ-SC02-4')
RUNTIME='com.apple.CoreSimulator.SimRuntime.iOS-27-0'
TYPE='com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max'
RUN_SECONDS=1560
CLEANUP_RESERVE=100
RUN_DEADLINE=float('inf')
class Refused(ValueError):pass
def require(ok,message):
 if not ok:raise Refused(message)
def canonical(x):return json.dumps(x,sort_keys=True,separators=(',',':'),allow_nan=False)
def write(path,value):
 with path.open('x',encoding='utf-8') as f:f.write(canonical(value)+'\n')
def context(env):
 c=attestation.ci_context(env)
 require(env.get('GITHUB_EVENT_NAME')=='push' and env.get('GITHUB_REF')==BRANCH,'exact push branch required')
 require(env.get('GITHUB_WORKFLOW_REF')==WORKFLOW and env.get('GITHUB_WORKFLOW_SHA')==c['GITHUB_SHA'],'exact reviewed workflow source required')
 require(env.get('GITHUB_JOB')=='j01-observation' and env.get('GITHUB_SERVER_URL')=='https://github.com','exact hosted job context required')
 require(env.get('RUNNER_ENVIRONMENT')=='github-hosted','standard hosted environment required')
 # Config/receipt inputs never come from an environment or caller override.
 require(not any(k.startswith('BLIND_J01_') for k in env),'external J01 override refused')
 require(not any(k in env for k in ('XCODE_XCCONFIG_FILE','OTHER_SWIFT_FLAGS','SWIFT_ACTIVE_COMPILATION_CONDITIONS','SDKROOT','TOOLCHAINS','DYLD_INSERT_LIBRARIES','PYTHONPATH','GIT_DIR','GIT_WORK_TREE','GIT_INDEX_FILE','GIT_CONFIG','GIT_CONFIG_GLOBAL','GIT_CONFIG_SYSTEM','GIT_CONFIG_PARAMETERS','GIT_CONFIG_COUNT')),'external build/loader override refused')
 return c
def root_path(env):
 c=context(env);root=attestation.no_links(env['RUNNER_TEMP'])
 require(root.is_dir(),'runner temp directory required')
 return root/('blind-j01-'+c['GITHUB_RUN_ID']+'-'+c['GITHUB_RUN_ATTEMPT'])
def emit(value):
 payload=canonical(value);require(len(payload.encode())<=65536,'bounded scalar receipt required')
 print('J01_CI_RECEIPT='+payload,flush=True)
 summary=os.environ.get('GITHUB_STEP_SUMMARY')
 if summary:
  with open(summary,'a',encoding='utf-8') as f:f.write('```json\n'+payload+'\n```\n')
def command(argv,log,seconds,cap,*,env=None,input_bytes=None,cleanup=False):
 """One owned process group. Sampled output/time bounds, never a native drain proof."""
 require(0<seconds<=900 and 0<cap<=64*1024*1024,'command budgets')
 require(input_bytes is None or type(input_bytes) is bytes and len(input_bytes)<=4096,'fixed request pipe cap')
 seconds=min(seconds,RUN_DEADLINE-time.monotonic()-(0 if cleanup else CLEANUP_RESERVE))
 require(seconds>0,'global runner budget exhausted')
 start=time.monotonic();reason='completed'
 with log.open('xb') as output:
  p=subprocess.Popen(argv,cwd=R,stdout=output,stderr=subprocess.STDOUT,stdin=subprocess.PIPE if input_bytes is not None else subprocess.DEVNULL,env=env,start_new_session=True)
  try:
   if input_bytes is not None:
    p.stdin.write(input_bytes);p.stdin.close()
   while p.poll() is None:
    if time.monotonic()-start>=seconds:reason='deadline';break
    if log.stat().st_size>cap:reason='output_cap';break
    time.sleep(.05)
  finally:
   # Stop owned descendants even if the leader exited first. This is process
   # containment, not proof of a native/model cancellation acknowledgment.
   try:os.killpg(p.pid,signal.SIGKILL)
   except ProcessLookupError:pass
   try:p.wait(timeout=3)
   except subprocess.TimeoutExpired:
    try:os.killpg(p.pid,signal.SIGKILL)
    except ProcessLookupError:pass
    p.wait(timeout=3)
   if p.stdin is not None and not p.stdin.closed:p.stdin.close()
 size=log.stat().st_size
 if size>cap:reason='output_cap'
 result={'argv':argv,'exit_code':p.returncode,'reason':reason,'wall_ms':int((time.monotonic()-start)*1000),'log_bytes':size}
 write(log.with_suffix('.command.json'),result)
 return result
def good(result):return type(result.get('exit_code')) is int and result['exit_code']==0 and result['reason']=='completed'
def tool(argv,folder,label,seconds=30,*,cleanup=False):
 log=folder/(label+'.log');result=command(['/usr/bin/xcrun','simctl',*argv],log,seconds,4*1024*1024,cleanup=cleanup)
 require(good(result),'simulator command failed')
 return attestation.stable_bytes(log,4*1024*1024)
def build_argv(folder):
 return ['/usr/bin/xcodebuild','-project','ios/BlindAssist.xcodeproj','-scheme','BlindAssist','-configuration','Debug','-jobs','2','-derivedDataPath',str(folder/'DerivedData'),'CODE_SIGNING_ALLOWED=NO','-destination','generic/platform=iOS Simulator','-parallel-testing-enabled','NO','build-for-testing']
def resolve_argv(folder):
 # Same fixed project/scheme and owned DerivedData; no caller-supplied package input.
 return build_argv(folder)[:-1]+['-resolvePackageDependencies']
def select_descriptor(products):
 paths=sorted(products.glob('*.xctestrun'));require(len(paths)==1,'one fresh descriptor required')
 return paths[0]
def create_simulator(folder,index,creation_attempted):
 # Exact installed type/runtime; never download or reuse a caller's device.
 types=json.loads(tool(['list','devicetypes','--json'],folder,'types'))
 runtimes=json.loads(tool(['list','runtimes','--json'],folder,'runtimes'))
 require(any(x.get('identifier')==TYPE for x in types.get('devicetypes',[])),'installed phone type required')
 require(any(x.get('identifier')==RUNTIME and x.get('isAvailable') is True for x in runtimes.get('runtimes',[])),'installed runtime required')
 creation_attempted()
 raw=tool(['create','Blind-J01-'+str(index),TYPE,RUNTIME],folder,'create').decode().strip()
 require(re.fullmatch('[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}',raw) is not None,'created UUID required')
 return raw

def cleanup_simulator(folder,udid):
 # Only the UUID returned by this invocation's successful create is accepted.
 result=command(['/usr/bin/xcrun','simctl','shutdown',udid],folder/'shutdown.log',30,4*1024*1024,cleanup=True)
 deleted=command(['/usr/bin/xcrun','simctl','delete',udid],folder/'delete.log',30,4*1024*1024,cleanup=True)
 if not good(deleted):return False
 devices=json.loads(tool(['list','devices','--json'],folder,'deleted-devices',cleanup=True))
 return not any(d.get('udid')==udid for group in devices.get('devices',{}).values() for d in group)
def verify_checkout(folder,label,ctx):
 # Checkout is intentionally detached at github.sha. Verify local repository
 # identity plus authenticated push ref/after, rather than inventing a branch.
 queries=[('root',['rev-parse','--show-toplevel'],str(R)),
          ('origin',['config','--local','--get','remote.origin.url'],'https://github.com/mischa23v/blind'),
          ('head',['rev-parse','HEAD'],ctx['GITHUB_SHA'])]
 for suffix,args,expected in queries:
  log=folder/(label+'-'+suffix+'.log')
  result=command(['/usr/bin/git','-C',str(R),*args],log,5,8192)
  require(good(result),'checkout identity query failed')
  actual=attestation.stable_bytes(log,8192).decode().strip()
  require(actual==expected or suffix=='origin' and actual==expected+'.git','checkout identity differs')
 event=attestation.read_json(os.environ['GITHUB_EVENT_PATH'],4*1024*1024)
 require(event.get('after')==ctx['GITHUB_SHA'] and event.get('ref')==BRANCH,'actual push ref/commit differs')
 require(event.get('repository',{}).get('full_name')=='mischa23v/blind' and event['repository'].get('private') is False,'public source repository required')

# Closed diagnostics only: neither exception text nor file/environment contents are emitted.
FAILURE_STAGES=frozenset(('dependency_preflight','dependency_resolution','checkout_before_build', 'attestation_begin', 'build_command', 'descriptor_selection', 'checkout_after_build', 'attestation_finish', 'receipt_write', 'receipt_digest', 'attestation_verify', 'script_selection', 'script_observations'))
ATTESTATION_FAILURE_CODES={
 'CI run identity':'attestation_ci_run_identity',
 'Mach-O executable required':'attestation_mach_o_executable_required',
 'actual build command did not succeed':'attestation_actual_build_command_did_not_succeed',
 'actual build-for-testing command required':'attestation_actual_build_for_testing_command_required',
 'app/test bundle shapes':'attestation_app_test_bundle_shapes',
 'artifact observation time budget':'attestation_artifact_observation_time_budget',
 'artifact outside selected build root':'attestation_artifact_outside_selected_build_root',
 'artifact path':'attestation_artifact_path',
 'begin age':'attestation_begin_age',
 'begin schema':'attestation_begin_schema',
 'bounded verification time required':'attestation_bounded_verification_time_required',
 'build begin context mismatch':'attestation_build_begin_context_mismatch',
 'build command identity':'attestation_build_command_identity',
 'build command shape':'attestation_build_command_shape',
 'build failed':'attestation_build_failed',
 'bundle byte budget':'attestation_bundle_byte_budget',
 'bundle directory required':'attestation_bundle_directory_required',
 'bundle directory symlink':'attestation_bundle_directory_symlink',
 'bundle executable mode':'attestation_bundle_executable_mode',
 'bundle executable name':'attestation_bundle_executable_name',
 'bundle file-count budget':'attestation_bundle_file_count_budget',
 'bytes changed between identity and read':'attestation_bytes_changed_between_identity_and_read',
 'combined artifact byte budget':'attestation_combined_artifact_byte_budget',
 'command shape':'attestation_command_shape',
 'directory count budget':'attestation_directory_count_budget',
 'directory width budget':'attestation_directory_width_budget',
 'duplicate JSON key':'attestation_duplicate_json_key',
 'empty bundle':'attestation_empty_bundle',
 'file changed during hashing':'attestation_file_changed_during_hashing',
 'file grew beyond cap':'attestation_file_grew_beyond_cap',
 'fresh receipt output required':'attestation_fresh_receipt_output_required',
 'host executable differs from Info.plist':'attestation_host_executable_differs_from_info_plist',
 'independently trusted receipt digest required':'attestation_independently_trusted_receipt_digest_required',
 'job identity':'attestation_job_identity',
 'one hosted test target':'attestation_one_hosted_test_target',
 'parent traversal refused':'attestation_parent_traversal_refused',
 'provenance implementation pins':'attestation_provenance_implementation_pins',
 'read budget':'attestation_read_budget',
 'receipt changed after approved digest check':'attestation_receipt_changed_after_approved_digest_check',
 'receipt content changed during parse':'attestation_receipt_content_changed_during_parse',
 'receipt digest mismatch':'attestation_receipt_digest_mismatch',
 'receipt provenance mismatch':'attestation_receipt_provenance_mismatch',
 'receipt source mismatch':'attestation_receipt_source_mismatch',
 'regular bounded descriptor required':'attestation_regular_bounded_descriptor_required',
 'regular bounded file required':'attestation_regular_bounded_file_required',
 'regular bounded file required before open':'attestation_regular_bounded_file_required_before_open',
 'regular executable descriptor required':'attestation_regular_executable_descriptor_required',
 'relative path shape':'attestation_relative_path_shape',
 'reviewed CI context required':'attestation_reviewed_ci_context_required',
 'reviewed dependency lock parser changed':'attestation_reviewed_dependency_lock_parser_changed',
 'reviewed provenance helper changed':'attestation_reviewed_provenance_helper_changed',
 'selected descriptor/app/test bytes differ from trusted build':'attestation_selected_descriptor_app_test_bytes_differ_from_trusted_build',
 'source changed across build':'attestation_source_changed_across_build',
 'source changed during artifact capture':'attestation_source_changed_during_artifact_capture',
 'source clean proof missing':'attestation_source_clean_proof_missing',
 'symlink component refused':'attestation_symlink_component_refused',
 'unsafe relative path':'attestation_unsafe_relative_path',
 'unsupported artifact placeholder':'attestation_unsupported_artifact_placeholder',
 'workflow SHA':'attestation_workflow_sha',
 'workflow identity':'attestation_workflow_identity',
}
def safe_failure(stage,error):
 code='unclassified'
 if stage in ('attestation_begin','attestation_finish','receipt_digest','attestation_verify') and type(error) is ValueError and len(error.args)==1 and type(error.args[0]) is str:
  code=ATTESTATION_FAILURE_CODES.get(error.args[0],'unclassified')
 return {'failureStage':stage if stage in FAILURE_STAGES else 'unclassified','failureCode':code}

def run():
 global RUN_DEADLINE
 require(sys.platform=='darwin','Apple host required');ctx=context(os.environ)
 require(attestation.no_links(os.environ['GITHUB_WORKSPACE'])==R,'actual checkout path required')
 RUN_DEADLINE=time.monotonic()+RUN_SECONDS
 out=root_path(os.environ);out.mkdir(mode=0o700)
 report={'schema':1,'sourceCommit':ctx['GITHUB_SHA'],'ci':ctx,'status':'incomplete','buildSucceeded':False,'scriptReceipts':[],'fullJourneyComplete':False,'runtimeLoadedBinaryVerified':False}
 stage='checkout_before_build'
 try:
  verify_checkout(out,'before-build',ctx)
  stage='dependency_preflight'
  attestation.source_provenance(R,ctx['GITHUB_SHA']) # Strict source and exact-lock validation before resolution.
  stage='dependency_resolution'
  resolution=command(resolve_argv(out),out/'resolve.log',180,16*1024*1024)
  report['resolutionCommandExit']=resolution['exit_code'];report['resolutionCommandReason']=resolution['reason']
  require(good(resolution),'fixed package resolution failed')
  # The first resolution may create the two already-allowlisted exact public
  # locks. Freeze only AFTER resolution; actual build equality remains strict.
  stage='attestation_begin'
  before=attestation.begin(R,os.environ);write(out/'begin.json',before)
  stage='build_command'
  result=command(build_argv(out),out/'build.log',900,64*1024*1024);write(out/'build-command.json',result)
  report['buildCommandExit']=result['exit_code'];report['buildCommandReason']=result['reason']
  require(good(result),'actual default build-for-testing failed')
  stage='descriptor_selection'
  products=out/'DerivedData/Build/Products';descriptor=select_descriptor(products)
  stage='checkout_after_build'
  verify_checkout(out,'after-build',ctx)
  stage='attestation_finish'
  receipt=attestation.finish(R,os.environ,before,result,products,descriptor.name)
  require(receipt['ci']==ctx and receipt['sourceCommit']==ctx['GITHUB_SHA'],'same run/job source required')
  stage='receipt_write'
  receipt_path=out/'build-receipt.json';write(receipt_path,receipt)
  # Trust comes from this reviewed authenticated CI producer executing the fixed
  # command, not from any caller's JSON/digest. Parent authenticates the real run.
  stage='receipt_digest'
  receipt_sha=attestation.digest(receipt_path,8*1024*1024)['sha256']
  stage='attestation_verify'
  proof=attestation.verify(products,descriptor.name,receipt_path,receipt_sha,ctx['GITHUB_SHA'])
  report.update(buildSucceeded=True,buildReceiptSHA256=receipt_sha,workflowSHA256=hashlib.sha256((R/'.github/workflows/j01-actual-model.yml').read_bytes()).hexdigest(),sourceAttestation=proof)
  emit({k:v for k,v in report.items() if k!='scriptReceipts'})
  stage='script_selection'
  scripts=attestation.read_json(P/'SUPPORTED.json',65536);require(type(scripts) is dict and all(scripts.get(k)==metadata.SUPPORTED[k] for k in SCENARIOS),'exact three selected scripts required')
  stage='script_observations'
  for index,scenario in enumerate(SCENARIOS):
   case=out/('case-'+str(index));case.mkdir(mode=0o700);udid=None;acquisition={'attempted':False}
   row={'scenario_id':scenario,'status':'unavailable','wrapper_exit':None,'cleanup_completed':False,'fullJourneyComplete':False}
   try:
    verify_checkout(case,'before-script',ctx)
    require(attestation.source_provenance(R,ctx['GITHUB_SHA'])==before['provenance'],'source changed before script')
    udid=create_simulator(case,index,lambda:acquisition.update(attempted=True))
    tool(['boot',udid],case,'boot',30);tool(['bootstatus',udid,'-b'],case,'bootstatus',120)
    config={'source_commit':ctx['GITHUB_SHA'],'simulator_udid':udid,'ephemeral_simulator_no_accounts':True,'xctestrun_path':str(descriptor),'xctestrun_sha256':attestation.digest(descriptor,4*1024*1024)['sha256'],'attempt_dir':str(case/'attempt'),'build_root':str(products),'build_receipt_path':str(receipt_path),'trusted_build_receipt_sha256':receipt_sha}
    config_path=case/'config.json';write(config_path,config)
    request={'schema':'instrumented-app-jsonl-v1','source_commit':ctx['GITHUB_SHA'],'scenario_id':scenario,'events':scripts[scenario],'constraints':{'physical_actions':False,'network':False,'paid_services':False}}
    env=dict(os.environ,BLIND_J01_EXECUTE_PREBUILT='1',BLIND_J01_CONFIG=str(config_path),BLIND_J01_OWNED_PARENT_PID=str(os.getpid()),PYTHONDONTWRITEBYTECODE='1')
    result=command([sys.executable,'-B',str(P/'app_adapter.py')],case/'wrapper.log',60,2*1024*1024,env=env,input_bytes=(canonical(request)+'\n').encode())
    row['wrapper_exit']=result['exit_code'];row['wrapper_reason']=result['reason']
    if good(result):
     response=attestation.read_json(case/'wrapper.log',1024*1024)
     # Collector emits only bounded closed metadata, never model/utterance text.
     row.update(metadata.collect(response,scenario,ctx['GITHUB_SHA'],receipt_sha))
    verify_checkout(case,'after-script',ctx)
    require(attestation.source_provenance(R,ctx['GITHUB_SHA'])==before['provenance'],'source changed after script')
    require(attestation.verify(products,descriptor.name,receipt_path,receipt_sha,ctx['GITHUB_SHA'])==proof,'selected bytes changed after script')
   except Exception as error:
    row.update(status='unavailable',error_type=type(error).__name__ if type(error).__name__ in ('OSError','ValueError','KeyError','TypeError','Refused','TimeoutExpired','CalledProcessError') else 'refused')
   finally:
    if udid is not None:
     try:row['cleanup_completed']=cleanup_simulator(case,udid)
     except Exception:row['cleanup_completed']=False
    else:row['cleanup_completed']=not acquisition['attempted'] # Failed/ambiguous create is NOT cleanup proof.
    row['simulator_creation_attempted']=acquisition['attempted']
   report['scriptReceipts'].append(row);emit(row)
   require(row['cleanup_completed'],'owned simulator cleanup failed; later scripts withheld')
  # Process/test success is not model success. Collector must observe an actual
  # final accepted reply and no unavailable/failing final return, without scoring semantics.
  report['status']='observed' if len(report['scriptReceipts'])==3 and all(x.get('status')=='observed' for x in report['scriptReceipts']) else 'incomplete'
 except Exception as error:
  report.update(safe_failure(stage,error))
  report.update(status='incomplete',error_type=type(error).__name__ if type(error).__name__ in ('OSError','ValueError','KeyError','TypeError','Refused','TimeoutExpired','CalledProcessError') else 'refused')
 finally:
  write(out/'RESULT.json',report);emit(report)
 return 0 if report['status']=='observed' else 1

def main():
 require(len(sys.argv)==2 and sys.argv[1] in ('run','report'),'exact mode required')
 if sys.argv[1]=='run':return run()
 out=root_path(os.environ)
 if (out/'RESULT.json').exists():emit(attestation.read_json(out/'RESULT.json',65536))
 else:emit({'schema':1,'status':'unavailable','reason':'no_terminal_runner_receipt','fullJourneyComplete':False})
 return 0
if __name__=='__main__':
 try:raise SystemExit(main())
 except Exception as error:
  print('J01_CI_REFUSED='+canonical({'status':'unavailable','error_type':type(error).__name__ if type(error).__name__ in ('OSError','ValueError','KeyError','TypeError','Refused') else 'refused'}),flush=True);raise SystemExit(1)
