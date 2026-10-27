#!/usr/bin/env python3
"""Pure build-planning harness fixtures. No Apple commands or app execution."""
import importlib.util
import json
from pathlib import Path
import tempfile
from unittest.mock import patch
H=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('stage85_planning',H/'apple/ci.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
count=0
def check(value):
 global count
 assert value
 count+=1
root=Path('/source');out=Path('/scratch')
plain=m.app_build_command(root,out,'app-flag-absent')
check('-dry-run' not in plain and plain[-1]=='build')
check('SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG' in plain)
plan=m.app_build_command(root,out,'planning-baseline',planning_only=True)
check(plan[-2:]==['-dry-run','build'])
check(plan.count('-dry-run')==1)
check('-disableAutomaticPackageResolution' in plan and plan[plan.index('-jobs')+1]=='1')
check(not any(x in plan for x in ['test','install','archive','run']))
other=m.app_build_command(root,out,'planning-proposal',planning_only=True)
check([(a,b) for a,b in zip(plan,other) if a!=b]==[('/scratch/planning-baseline','/scratch/planning-proposal')])
# Refactoring must preserve the exact previously executed compile command.
old=json.loads((H/'evidence/run40571313055/app-flag-absent-build-receipt.json').read_text())['command']
old_root=Path(old[old.index('-project')+1]).parent.parent
old_out=Path(old[old.index('-derivedDataPath')+1]).parent
check(m.app_build_command(old_root,old_out,'app-flag-absent')==old)
helptext='  -dry-run               do everything except actually running the commands\n'
check(m.planning_help_line(helptext)==helptext.strip())
for text in ['', '-dry-run compile now', helptext+helptext, '--dry-run do everything except running commands']:
 try:m.planning_help_line(text)
 except ValueError:check(True)
 else:check(False)
base=dict(exitCode=65,timedOut=False,scratchCapExceeded=False,scratchScanComplete=True,
 exceptionType=None,terminationSignal=None,fileSizeLimitSignal=False)
check(m.planning_can_continue(base))
check(m.planning_can_continue(dict(base,exitCode=0)))
for key,value in [('exitCode',1),('timedOut',True),('scratchCapExceeded',True),('scratchScanComplete',False),
 ('exceptionType','OSError'),('terminationSignal','SIGXCPU'),('fileSizeLimitSignal',True)]:
 check(not m.planning_can_continue(dict(base,**{key:value})))
check(not m.planning_can_continue({}))
print(f'PASS: {count} pure planning-policy fixtures; no Apple execution')

# Exercise restoration and failure bookkeeping without launching any process.
for baseline_exit, proposal_exit, cap in [(0,0,False),(65,65,False),(65,0,True)]:
 with tempfile.TemporaryDirectory(prefix='stage85-planning-test-') as temp:
  r=Path(temp)/'repo';h=r/'research/stage';o=Path(temp)/'out';o.mkdir();h.mkdir(parents=True)
  names=['ios/BlindAssist/NavigationModel.swift','ios/BlindAssist.xcodeproj/project.pbxproj','ios/BlindAssist/MeshCandidateDiagnostics.swift']
  import hashlib
  for n in names:(r/n).parent.mkdir(parents=True,exist_ok=True);(r/n).write_text('proposal:'+n)
  (h/'SOURCE_PINS.json').write_text(json.dumps({n:hashlib.sha256(('baseline:'+n).encode()).hexdigest() for n in names[:2]}))
  calls=[]
  class Fake:
   @staticmethod
   def run(command,label,out,timeout,env=None):
    calls.append(label)
    if label=='planning-help':(out/(label+'.log')).write_text(helptext);return {}
    if label=='planning-baseline-reverse':
     for n in names[:2]:(r/n).write_text('baseline:'+n)
     (r/names[2]).unlink();return {}
    if label=='planning-proposal-restore':
     for n in names:(r/n).write_text('proposal:'+n)
     return {}
    if label.endswith('-check'):return {}
    assert label in ['planning-baseline','planning-proposal']
    rec=dict(base,exitCode=baseline_exit if label=='planning-baseline' else proposal_exit,
             scratchCapExceeded=cap and label=='planning-baseline')
    (out/(label+'-receipt.json')).write_text(json.dumps(rec))
    (out/(label+'.log')).write_text('synthetic planning log')
    if rec['exitCode'] or rec['scratchCapExceeded']:raise RuntimeError('simulated')
    return rec
  with patch.object(m,'ROOT',r),patch.object(m,'HOME',h),patch.dict(m.os.environ,{'GITHUB_SHA':'fixture'}),patch.object(m,'service_crash_diagnostics',return_value={}):
   try:m.planning_comparison(Fake,o,{},h/'candidate.patch')
   except AssertionError:check(baseline_exit!=0 or proposal_exit!=0 or cap)
   else:check(baseline_exit==proposal_exit==0 and not cap)
  check(all((r/n).read_text()=='proposal:'+n for n in names))
  result=json.loads((o/'PLANNING_COMPARISON.json').read_text())
  check(len(result['arms'])==(1 if cap else 2))
  check(calls.count('planning-baseline')==1 and calls.count('planning-proposal')==(0 if cap else 1))
  check(result['fullAppCompiled'] is False and result['automaticRetries']==0)
print(f'PASS: {count} total pure planning-policy/transaction fixtures; no Apple execution')

check(not m.planning_can_continue(dict(base,logTail='child terminated SIGXFSZ')))
with tempfile.TemporaryDirectory(prefix='stage85-gate-test-') as folder:
 o=Path(folder)
 check(not m.planning_baseline_gate(o,base,{}))
 (o/'planning-baseline.log').write_text('resource signal SIGXFSZ occurred before final tail\n'+'okay\n'*4000)
 check(not m.planning_baseline_gate(o,base,{}))
 (o/'planning-baseline.log').write_bytes(b'x'*((4<<20)+1))
 check(not m.planning_baseline_gate(o,base,{}))
 (o/'planning-baseline.log').write_text('complete, no diagnosed resource event')
 check(m.planning_baseline_gate(o,base,{}))
 check(not m.planning_baseline_gate(o,base,{'termination':{'namespace':'SIGNAL','code':25}}))

# Reverse may mutate successfully, then the shared runner may reject stage size.
for restoration_fails in [False,True]:
 with tempfile.TemporaryDirectory(prefix='stage85-reverse-failure-') as folder:
  r=Path(folder)/'repo';h=r/'research/stage';o=Path(folder)/'out';o.mkdir();h.mkdir(parents=True)
  names=['ios/BlindAssist/NavigationModel.swift','ios/BlindAssist.xcodeproj/project.pbxproj','ios/BlindAssist/MeshCandidateDiagnostics.swift']
  for n in names:(r/n).parent.mkdir(parents=True,exist_ok=True);(r/n).write_text('proposal:'+n)
  calls=[]
  class ReversePostFailure:
   @staticmethod
   def run(command,label,out,timeout,env=None):
    calls.append(label)
    if label=='planning-help':(out/(label+'.log')).write_text(helptext);return {}
    if label=='planning-baseline-reverse-check':return {}
    assert label=='planning-baseline-reverse'
    for n in names[:2]:(r/n).write_text('baseline:'+n)
    (r/names[2]).unlink()
    raise RuntimeError('shared runner post-execution scratch-cap failure')
  real_replace=m.os.replace
  def injected_replace(source,target):
   if restoration_fails and str(target).endswith('NavigationModel.swift'):
    raise PermissionError('injected atomic restore failure')
   return real_replace(source,target)
  with patch.object(m,'ROOT',r),patch.object(m,'HOME',h),patch.object(m.os,'replace',side_effect=injected_replace):
   try:m.planning_comparison(ReversePostFailure,o,{},h/'candidate.patch')
   except RuntimeError as error:check('restoration failed' in str(error) if restoration_fails else 'post-execution' in str(error))
   else:check(False)
  check('planning-baseline' not in calls and 'planning-proposal' not in calls)
  d=json.loads((o/'planning-restoration-diagnostic.json').read_text())
  check(d['restored']==(not restoration_fails))
  check((r/names[1]).read_text()=='proposal:'+names[1] and (r/names[2]).read_text()=='proposal:'+names[2])
  check(not list(r.rglob('.stage85-restore-*')))
print(f'PASS: {count} total planning/restoration/resource fixtures; no Apple execution')

for payload, accepted, complete in [(helptext.encode(),True,True),
 (b' -dry-run, -n\n Print commands, but do not execute them.\n',False,True),
 (b'no option found',False,True),(b'x'*((256<<10)+1),False,False)]:
 with tempfile.TemporaryDirectory(prefix='stage85-help-fixture-') as folder:
  o=Path(folder);calls=[]
  class HelpFake:
   @staticmethod
   def run(command,label,out,timeout,env=None):
    calls.append(command);(out/'planning-help.log').write_bytes(payload)
  option=m.planning_capability(HelpFake,o,{})
  d=json.loads((o/'planning-capability-diagnostic.json').read_text())
  check((option is not None)==accepted and d['optionAccepted']==accepted and d['helpComplete']==complete)
  check(calls==[['xcodebuild','-help']] and d['planningArmsExecuted']==0)
  check((o/'planning-help-bounded.txt').exists()==complete)
  if complete:check((o/'planning-help-bounded.txt').read_bytes()==payload)
  if b'dry-run,' in payload:check(d['relevantHelpExcerpts'][0]['text']==payload.decode().rstrip('\n'))
print(f'PASS: {count} total planning/restoration/resource/capability fixtures; no Apple execution')

# Actual-build diagnostic reuses transaction, no capability invocation or undocumented flag.
for baseline_exit, proposal_exit, cap in [(0,0,False),(65,65,False),(65,0,True)]:
 with tempfile.TemporaryDirectory(prefix='stage85-build-control-test-') as temp:
  r=Path(temp)/'repo';h=r/'research/stage';o=Path(temp)/'out';o.mkdir();h.mkdir(parents=True)
  names=['ios/BlindAssist/NavigationModel.swift','ios/BlindAssist.xcodeproj/project.pbxproj','ios/BlindAssist/MeshCandidateDiagnostics.swift']
  import hashlib
  for n in names:(r/n).parent.mkdir(parents=True,exist_ok=True);(r/n).write_text('proposal:'+n)
  (h/'SOURCE_PINS.json').write_text(json.dumps({n:hashlib.sha256(('baseline:'+n).encode()).hexdigest() for n in names[:2]}))
  calls=[]
  class Fake:
   @staticmethod
   def run(command,label,out,timeout,env=None):
    calls.append(label)
    if label=='planning-help':(out/(label+'.log')).write_text(helptext);return {}
    if label=='build-control-baseline-reverse':
     for n in names[:2]:(r/n).write_text('baseline:'+n)
     (r/names[2]).unlink();return {}
    if label=='build-control-proposal-restore':
     for n in names:(r/n).write_text('proposal:'+n)
     return {}
    if label.endswith('-check'):return {}
    assert label in ['build-control-baseline','build-control-proposal']
    check(timeout==600 and '-dry-run' not in command and command[-1]=='build')
    rec=dict(base,exitCode=baseline_exit if label=='build-control-baseline' else proposal_exit,
             scratchCapExceeded=cap and label=='build-control-baseline')
    (out/(label+'-receipt.json')).write_text(json.dumps(rec))
    (out/(label+'.log')).write_text('synthetic planning log')
    if rec['exitCode'] or rec['scratchCapExceeded']:raise RuntimeError('simulated')
    return rec
  with patch.object(m,'ROOT',r),patch.object(m,'HOME',h),patch.dict(m.os.environ,{'GITHUB_SHA':'fixture'}),patch.object(m,'service_crash_diagnostics',return_value={}):
   try:m.planning_comparison(Fake,o,{},h/'candidate.patch',actual_build=True)
   except AssertionError:check(baseline_exit!=0 or proposal_exit!=0 or cap)
   else:check(baseline_exit==proposal_exit==0 and not cap)
  check(all((r/n).read_text()=='proposal:'+n for n in names))
  result=json.loads((o/'BUILD_CONTROL.json').read_text())
  check(len(result['arms'])==(1 if cap else 2))
  check(calls.count('build-control-baseline')==1 and calls.count('build-control-proposal')==(0 if cap else 1))
  check(result['fullAppCompiled']==(baseline_exit==proposal_exit==0 and not cap) and result['automaticRetries']==0)
  check('planning-help' not in calls and result['installedPlanningOption'] is None)
  check(result['actualBuildControl'] is True and result['perCommandWallSeconds']==600)
print(f'PASS: {count} total planning/restoration/resource/capability/build-control fixtures; no Apple execution')

# Known native invocation semantics, with bounded exact-dependency exceptions.
env={'SDKROOT':'/host/MacOSX.sdk','TMPDIR':'/bounded/tmp/','DEVELOPER_DIR':'/Xcode',
     'GIT_CONFIG_COUNT':'1','GIT_CONFIG_KEY_0':'url.local.insteadOf','GIT_CONFIG_VALUE_0':'remote'}
appenv=m.app_environment(env)
check('SDKROOT' not in appenv and env['SDKROOT']=='/host/MacOSX.sdk')
check(appenv=={k:v for k,v in env.items() if k!='SDKROOT'})
check(m.app_environment(appenv)==appenv)
normalized=m.app_build_command(root,out,'build-control-baseline',normalized=True)
expected=['xcodebuild','-project','/source/ios/BlindAssist.xcodeproj','-scheme','BlindAssist',
 '-configuration','Debug','-jobs','1','-derivedDataPath','/scratch/build-control-baseline',
 'CODE_SIGNING_ALLOWED=NO','-clonedSourcePackagesDirPath','/scratch/app-source-packages',
 '-disableAutomaticPackageResolution','-destination','generic/platform=iOS Simulator','build']
check(normalized==expected)
check(not any(x.startswith(('ARCHS=','ONLY_ACTIVE_ARCH=','ENABLE_DEBUG_DYLIB=',
 'SWIFT_OPTIMIZATION_LEVEL=','SWIFT_ACTIVE_COMPILATION_CONDITIONS=','CODE_SIGNING_REQUIRED=')) for x in normalized))
check('-sdk' not in normalized and '-dry-run' not in normalized)
second=m.app_build_command(root,out,'build-control-proposal',normalized=True)
check([(a,b) for a,b in zip(normalized,second) if a!=b]==[('/scratch/build-control-baseline','/scratch/build-control-proposal')])
for kw in [dict(flag='FLAG'),dict(planning_only=True)]:
 try:m.app_build_command(root,out,'bad',normalized=True,**kw)
 except AssertionError:check(True)
 else:check(False)
check(m.app_build_command(old_root,old_out,'app-flag-absent')==old)
print(f'PASS: {count} total normalized-command/environment and previous control fixtures; no Apple execution')
