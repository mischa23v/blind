#!/usr/bin/env python3
"""Read-only stdlib verification; no library loading or native rerun."""
import ast,hashlib,json,pathlib,re
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
S=R/'research/coffee-octomap-observation-rays-source-20261030';B=S/'build-observation-01';C=W/'coffee-observation-ray-controls-attempt-001'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def need(v,m):
 if not v:raise ValueError(m)
def read(p):return json.loads(p.read_text())
def main():
 guard=read(B/'GUARD_RUN/RESULT.json');build=read(B/'BUILD_RECEIPT.json');control=read(C/'RESULT.json');pins=read(S/'BUILD_RUN_PINS.json')
 need(guard['sourceCommit']=='b9d58e91637932a5d74cad68118d4a9ea870eee5' and guard['status']=='completed-zero-exit','build source/status')
 need(len(guard['commands'])==1 and guard['commands'][0]['exitCode']==0 and guard['commands'][0]['groupRetired'] is True,'compile exit/retirement')
 need(guard['inputHashesBefore']==guard['inputHashesAfter']==pins['inputs'],'build input identity')
 need(guard['manifestSHA256']==sha(S/'BUILD_RUN_PINS.json')=='c38fe60ad36ee4ab5ee20dba52e8bf84a6ce9bd91f539f59e6f771ba7827b5e2','build pins')
 for n,d in pins['inputs'].items():
  p=pathlib.Path(n.replace('@SOURCE@',str(S)).replace('@BASE@',str(S.parent/'coffee-octomap-build-source-20261029')).replace('@WORK@',str(B)))
  if not p.is_absolute():p=R/p
  need(sha(p)==d,'source/toolchain changed '+n)
 for n,v in guard['finalPayloadInventory'].items():
  if n.endswith('/'):continue
  need((B/n).stat().st_size==v['bytes'] and sha(B/n)==v['sha256'],'build terminal payload')
 need(build['success'] is True and build['exitCode']==0 and build['guardReceiptSHA256']==sha(B/'GUARD_RUN/RESULT.json'),'compatibility receipt')
 need(build['librarySHA256']==guard['executableSHA256']==control['librarySHA256']==sha(B/'libblind_octomap.so')=='82afb6c94b3e0234ee371395b6f7ba17ae159987293ac357463bde43605ebc26','binary binding')
 need(build['sourceManifestSHA256']==control['sourceManifestSHA256']==sha(S/'MANIFEST.json')=='98ddf1a4cd0cadb285509389f6b7ba2ae40e94558e6e1cd19db83bb79a04a14f','source binding')
 need(control['buildReceiptSHA256']==sha(B/'BUILD_RECEIPT.json') and control['status']=='completed-controls-only','control binding/status')
 need(control['suites']==[{'name':name,'testsRun':n,'expected':n,'failures':0,'errors':0,'skipped':0,'success':True}for name,n in [('original',16),('read-only-rays',22),('observation-only-rays',10)]],'suite inventory')
 log=(C/'controls.log').read_text();observed=re.findall(r'^(test_\w+) \([^\n]+\) \.\.\. ok$',log,re.M)
 expected=[]
 for p in (S.parent/'coffee-octomap-build-source-20261029/test_octomap_engine.py',S/'test_readonly_rays.py',S/'test_observation_rays.py'):
  expected+=sorted(n.name for n in ast.walk(ast.parse(p.read_text())) if isinstance(n,ast.FunctionDef) and n.name.startswith('test_'))
 need(observed==expected and len(observed)==48 and len(re.findall(r'^OK$',log,re.M))==3,'exact named control logs')
 need(guard['aggregateCPUSeconds']<120 and guard['wallSeconds']<180 and max(guard['peakObservedAggregateRSS'],guard['peakFastExitChildRSS'])<1024**3,'build resource limits')
 need(control['cpuSeconds']<120 and control['wallSeconds']<175 and control['peakRSSKiB']*1024<512*1024**2,'control worker resources')
 need(build['physicalAuthority'] is False and control['physicalAuthority'] is False,'authority boundary')
 result={'status':'SAVED_BUILD_AND_48_CONTROLS_VERIFIED','buildSourceCommit':guard['sourceCommit'],'originalControls':16,'readonlyControls':22,'observationControls':10,'failures':0,'errors':0,'skipped':0,'librarySHA256':build['librarySHA256'],'buildCPUSeconds':guard['aggregateCPUSeconds'],'buildWallSeconds':guard['wallSeconds'],'buildPeakSampledOrWaitedRSSBytes':max(guard['peakObservedAggregateRSS'],guard['peakFastExitChildRSS']),'controlWorkerCPUSeconds':control['cpuSeconds'],'controlWorkerWallSeconds':control['wallSeconds'],'controlWorkerPeakRSSBytes':control['peakRSSKiB']*1024,'controlOuterProcessGroupReceipt':'not supplied in packet; worker metrics and root-observed terminal status are distinct','nativeRerun':False,'realHeldoutDataTested':False,'physicalAuthority':False}
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()
