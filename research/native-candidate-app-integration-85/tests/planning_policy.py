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
