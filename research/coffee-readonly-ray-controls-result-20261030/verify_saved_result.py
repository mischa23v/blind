#!/usr/bin/env python3
"""Read-only stdlib verification; no library loading or native rerun."""
import ast,hashlib,json,pathlib,re
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
S=R/'research/coffee-octomap-readonly-rays-v2-source-20261030';B=S/'build-readonly-02';C=W/'coffee-readonly-ray-controls-attempt-001'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def need(v,m):
 if not v:raise ValueError(m)
def read(p):return json.loads(p.read_text())
def main():
 guard=read(B/'GUARD_RUN/RESULT.json');build=read(B/'BUILD_RECEIPT.json');control=read(C/'RESULT.json');pins=read(S/'BUILD_RUN_PINS.json')
 need(guard['sourceCommit']=='e9088cf7d17c23d9486d5d380e8a2eeb9634b267' and guard['status']=='completed-zero-exit','build source/status')
 need(len(guard['commands'])==1 and guard['commands'][0]['exitCode']==0 and guard['commands'][0]['groupRetired'] is True,'compile exit/retirement')
 need(guard['inputHashesBefore']==guard['inputHashesAfter']==pins['inputs'],'build input identity')
 need(guard['manifestSHA256']==sha(S/'BUILD_RUN_PINS.json')=='f02607d610a34d61fdcc8246372789bb883ec9a6aee5eb5a78973ea3571f5121','build pins')
 for n,d in pins['inputs'].items():
  p=pathlib.Path(n.replace('@SOURCE@',str(S)).replace('@BASE@',str(S.parent/'coffee-octomap-build-source-20261029')).replace('@WORK@',str(B)))
  if not p.is_absolute():p=R/p
  need(sha(p)==d,'source/toolchain changed '+n)
 for n,v in guard['finalPayloadInventory'].items():
  if n.endswith('/'):continue
  need((B/n).stat().st_size==v['bytes'] and sha(B/n)==v['sha256'],'build terminal payload')
 need(build['success'] is True and build['exitCode']==0 and build['guardReceiptSHA256']==sha(B/'GUARD_RUN/RESULT.json'),'compatibility receipt')
 need(build['librarySHA256']==guard['executableSHA256']==control['librarySHA256']==sha(B/'libblind_octomap.so')=='fa53b4153a7c1765880eabf5f8029d87173af6ed4ecdb425ea37f5d1d799bd84','binary binding')
 need(build['sourceManifestSHA256']==control['sourceManifestSHA256']==sha(S/'MANIFEST.json')=='355fdbf503acf7f17fd6bf3e02c14a507b70208230a947452f605517d8a779d4','source binding')
 need(control['buildReceiptSHA256']==sha(B/'BUILD_RECEIPT.json') and control['status']=='completed-controls-only','control binding/status')
 need(control['suites']==[{'name':name,'testsRun':n,'expected':n,'failures':0,'errors':0,'skipped':0,'success':True}for name,n in [('original',16),('read-only-rays',22)]],'suite inventory')
 log=(C/'controls.log').read_text();observed=re.findall(r'^(test_\w+) \([^\n]+\) \.\.\. ok$',log,re.M)
 expected=[]
 for p in (S.parent/'coffee-octomap-build-source-20261029/test_octomap_engine.py',S/'test_readonly_rays.py'):
  expected+=sorted(n.name for n in ast.walk(ast.parse(p.read_text())) if isinstance(n,ast.FunctionDef) and n.name.startswith('test_'))
 need(observed==expected and len(observed)==38 and len(re.findall(r'^OK$',log,re.M))==2,'exact named control logs')
 need(guard['aggregateCPUSeconds']<120 and guard['wallSeconds']<180 and max(guard['peakObservedAggregateRSS'],guard['peakFastExitChildRSS'])<1024**3,'build resource limits')
 need(control['cpuSeconds']<120 and control['wallSeconds']<175 and control['peakRSSKiB']*1024<512*1024**2,'control worker resources')
 need(build['physicalAuthority'] is False and control['physicalAuthority'] is False,'authority boundary')
 result={'status':'SAVED_BUILD_AND_38_CONTROLS_VERIFIED','buildSourceCommit':guard['sourceCommit'],'originalControls':16,'newControls':22,'failures':0,'errors':0,'skipped':0,'librarySHA256':build['librarySHA256'],'buildCPUSeconds':guard['aggregateCPUSeconds'],'buildWallSeconds':guard['wallSeconds'],'buildPeakSampledOrWaitedRSSBytes':max(guard['peakObservedAggregateRSS'],guard['peakFastExitChildRSS']),'controlWorkerCPUSeconds':control['cpuSeconds'],'controlWorkerWallSeconds':control['wallSeconds'],'controlWorkerPeakRSSBytes':control['peakRSSKiB']*1024,'controlOuterProcessGroupReceipt':'not supplied in packet; worker metrics and root-observed terminal status are distinct','nativeRerun':False,'realHeldoutDataTested':False,'physicalAuthority':False}
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()
