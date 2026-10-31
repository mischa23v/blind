#!/usr/bin/env python3
"""Stdlib-only pinning. Does not compile/import/execute native libraries."""
import hashlib,json,pathlib,sys
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 inputs={}
 def add(p):
  p=pathlib.Path(p)
  key='@SOURCE@/'+str(p.relative_to(H))if p.is_relative_to(H)else '@REPO@/'+str(p.relative_to(R))if p.is_relative_to(R)else '@WORKSPACE@/'+str(p.relative_to(W))if p.is_relative_to(W)else str(p)
  inputs[key]=sha(p)
 files=sorted(p for p in H.iterdir()if p.is_file()and p.name not in ['RUN_PINS.json','SOURCE_FREEZE.json'])
 for p in files:add(p)
 from schedule_contract import INPUT_SHA,load_schedules
 load_schedules(R)
 for p,d in INPUT_SHA.items():
  if sha(R/p)!=d:raise ValueError('Original schedule mismatch')
  add(R/p)
 base=W/'coffee-native-replay-prepared-002/blind-split-candidate-game-03/body-margin-variants-07/native025'
 for p in sorted((base/'upstream').rglob('*')):
  if p.is_file()and p.suffix in ('.cpp','.h'):add(p)
 for p in [base/'blind_detour.h',W/'coffee-native-replay-prepared-002/blind-tabletop-exclusion-planner-66/blind_detour_exclusion.cpp',W/'coffee-native-replay-prepared-002/blind-tabletop-exclusion-planner-66/BUILD_RECEIPT.json']:add(p)
 old=json.loads((R/'research/rapier-support-datum-runner-source-20261030/VTK_DEPENDENCIES.json').read_text())
 for name,d in old.items():
  p=pathlib.Path(name)if name.startswith('/')else R/name
  if sha(p)!=d:raise ValueError('Frozen VTK runtime changed '+name)
  add(p)
 data=W/'rapier-real-room-inputs-001'
 for scene in ['conference','coffee']:
  for suffix in ['vertices.f32','indices.u32']:add(data/(scene+'.'+suffix))
 add(data/'MATERIALIZATION.json')
 add(R/'research/conference-replay-input-inventory-20261029/evidence/REGISTRATION_RESULT.json')
 for n in ['/usr/bin/x86_64-linux-gnu-g++-14','/usr/libexec/gcc/x86_64-linux-gnu/14/cc1plus','/usr/bin/x86_64-linux-gnu-as','/usr/bin/x86_64-linux-gnu-ld.bfd']:
  add(pathlib.Path(n))
 reuse=R/'research/rapier-support-datum-runner-source-20261030/run_aggregate.py';add(reuse)
 py='/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12'
 compile_command=json.loads((H/'BUILD_COMMAND.json').read_text())
 if compile_command[0]!='/usr/bin/x86_64-linux-gnu-g++-14':raise ValueError('Absolute pinned compiler required')
 pins={'schema':1,'protocol':'detour-height-follow-v1-managed-sandbox','status':'SOURCE_ONLY_NOT_EXECUTED','limits':{'cpuSeconds':120,'wallSeconds':180,'observedRSSBytes':1024**3,'outputBytes':64*1024**2,'maximumVTKQueries':29568,'triangleCandidates':30000000,'nativeBuilds':2,'nativeBeginCalls':4,'nativeStepCalls':3696},'inputs':inputs,'publishedSourceFiles':{p.name:sha(p)for p in files},'reuseSource':{'path':str(reuse.relative_to(R)),'sha256':sha(reuse)},'workRoot':'@WORKSPACE@/detour-height-follow-attempt-001','dataRoot':'@WORKSPACE@/rapier-real-room-inputs-001','pythonExecutable':py,'compileCommand':compile_command,'heightCommand':[py,'-I','-B','@SOURCE@/native_height_worker.py','--mesh-root','@WORKSPACE@/rapier-real-room-inputs-001','--output','@WORK@/height','--library','@WORK@/libheight_follow.so','--library-sha256','@LIBRARY_SHA256@'],'vtkCommand':[py,'-I','-B','@SOURCE@/vtk_worker.py','--mesh-root','@WORKSPACE@/rapier-real-room-inputs-001','--height-events','@WORK@/height/events.jsonl','--output','@WORK@/vtk'],'runtimeClosureNotHermetic':True,'toolchainSystemHeadersNotIndividuallyPinned':True,'physicalAuthority':False,'movementApplied':False}
 (H/'RUN_PINS.json').write_text(json.dumps(pins,indent=2)+'\n')
 freeze={p.name:sha(p)for p in files};freeze['RUN_PINS.json']=sha(H/'RUN_PINS.json')
 (H/'SOURCE_FREEZE.json').write_text(json.dumps(freeze,indent=2)+'\n')
 print(json.dumps({'files':len(freeze)+1,'inputs':len(inputs),'RUN_PINS':sha(H/'RUN_PINS.json'),'SOURCE_FREEZE':sha(H/'SOURCE_FREEZE.json')}))
if __name__=='__main__':main()
