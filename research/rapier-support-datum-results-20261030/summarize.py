#!/usr/bin/env python3
"""Reproduce compact saved-result audit with stdlib only. No native rerun."""
import hashlib,json,math,pathlib,sys
H=pathlib.Path(__file__).resolve().parent;ROOT=H.parents[1];W=ROOT.parent
SOURCE=ROOT/'research/rapier-support-datum-runner-source-20261030';ATTEMPT=W/'rapier-support-datum-attempt-001'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,indent=2,allow_nan=False)+'\n')
def main(out):
 out.mkdir(exist_ok=False)
 # Exact existing pure-stdlib terminal checker; importing it never imports VTK.
 sys.path.insert(0,str(SOURCE));from validate_results import validate_results
 validated=validate_results(ATTEMPT,SOURCE,sha(SOURCE/'RUN_PINS.json'))
 guard=json.loads((ATTEMPT/'GUARD_RUN/RESULT.json').read_text());assert guard['status']=='completed-six-pose-diagnostic-only';assert guard['inputHashesBefore']==guard['inputHashesAfter'];assert all(x['exitCode']==0 and x['groupRetired'] for x in guard['commands'])
 paths=['GUARD_RUN/RESULT.json','probes/SUMMARY.json','probes/probe-rows.jsonl','probes/wrapper-records.jsonl','vtk/SUMMARY.json','vtk/rows.jsonl']
 raw={p:{'bytes':(ATTEMPT/p).stat().st_size,'sha256':sha(ATTEMPT/p)}for p in paths}
 kcc=[json.loads(x)for x in (ATTEMPT/'probes/probe-rows.jsonl').read_text().splitlines()];vtk=[json.loads(x)for x in (ATTEMPT/'vtk/rows.jsonl').read_text().splitlines()]
 datums=json.loads((W/'rapier-support-datum-inputs-001/CANDIDATE_DATUMS.json').read_text())['results'];triangles={};compact=[]
 for r in vtk:
  ids=[]
  for c in r['contacts']:
   key=r['scene']+':'+str(c['triangleID']);value={k:c[k]for k in ('triangleID','originalVertexIDs','modelHeightRange','heightIsWholeTriangleNotContactPoint')}
   if key in triangles:assert triangles[key]==value
   triangles[key]=value;ids.append(c['triangleID'])
  compact.append({k:r[k]for k in ('probeId','scene','sourceId','datumArm','inputArm','envelope','lowerTrimMetres','startFoot','endFoot','requestedDelta','yawRadians','movementApplied','physicalAuthority','support','semanticFloor')}|{'contactIDs':ids,'contact':bool(ids),'count':len(ids),'rawCount':r['result']['rawContactCount'],'groundCount':r['result']['groundContactCount']})
 (out/'COMPACT_VTK.jsonl').write_text(''.join(json.dumps(x,separators=(',',':'))+'\n'for x in compact));(out/'CONTACT_TRIANGLES.json').write_text(json.dumps(triangles,separators=(',',':'))+'\n')
 ck=[]
 for x in kcc:
  r=x['row'];ck.append({k:x[k]for k in ('scene','envelope','sourceProbeID','datumArm','intentArm')}|{k:r[k]for k in ('id','kind','originalFoot','originalYawRadians','requestedDelta','proposedMovement','computedGrounded','collisions','physicalAuthority','movementApplied','arrivalEstablished','proposalWasNotApplied')})
 (out/'COMPACT_KCC.jsonl').write_text(''.join(json.dumps(x,separators=(',',':'))+'\n'for x in ck))
 table=[]
 for d in datums:
  source=d['originalProbe']['id'];rec={'id':source,'shiftMetres':d['candidateVerticalShiftMetres'],'allCornersExtrapolated':all(c['extrapolated']for c in d['nominalCornerCoverage']),'envelopes':{}}
  for env in ('body','horizontal_margin'):
   vals={}
   for intent in ('zero','original_xyz'):
    pair={}
    for arm in ('original','candidate'):
     records=[r for r in vtk if (r['sourceId'],r['envelope'],r['inputArm'],r['datumArm'])==(source,env,intent,arm)]
     assert len(records)==2
     kr=next(x for x in ck if (x['sourceProbeID'],x['envelope'],x['intentArm'],x['datumArm'])==(source,env,intent,arm))
     pair[arm]={'vtk':{str(r['lowerTrimMetres']):{'count':len(r['contacts']),'wholeTriangleRelativeHeightRange':([min(c['relativeToStartFootHeightRange'][0]for c in r['contacts']),max(c['relativeToStartFootHeightRange'][1]for c in r['contacts'])]if r['contacts']else None),'whollyAbove10cmIDs':[c['triangleID']for c in r['contacts']if c['relativeToStartFootHeightRange'][0]>.1]}for r in records},'kccRequested':kr['requestedDelta'],'kccProposed':kr['proposedMovement'],'kccCollisionCount':len(kr['collisions']),'kccComputedGrounded':kr['computedGrounded']}
    for band in ('0','0.002'):
     a=set(pair['original']['vtk'][band]['whollyAbove10cmIDs']);b=set(pair['candidate']['vtk'][band]['whollyAbove10cmIDs']);pair.setdefault('highGeometryRetention',{})[band]={'originalCount':len(a),'candidateCount':len(b),'lostIDs':sorted(a-b),'note':'10cm is descriptive whole-triangle height only, not safety threshold or semantic category'}
    vals[intent]=pair
   rec['envelopes'][env]=vals
  table.append(rec)
 summary={'status':'completed_saved_result_audit_only','sourceCommit':guard['sourceCommit'],'manifestSHA256':guard['manifestSHA256'],'nativeRerun':False,'physicalAuthority':False,'movementApplied':False,'arrivalEstablished':False,'kccCalls':len(kcc),'vtkEnvelopeBandQueries':len(vtk),'all110InputHashesUnchanged':len(guard['inputHashesBefore'])==110 and guard['inputHashesBefore']==guard['inputHashesAfter'],'childGroupsRetired':all(x['groupRetired']for x in guard['commands']),'wallSeconds':guard['wallSeconds'],'aggregateCPUSeconds':guard['aggregateCPUSeconds'],'peakObservedAggregateRSS':guard['peakObservedAggregateRSS'],'rawEvidence':raw,'datumSHA256':sha(W/'rapier-support-datum-inputs-001/CANDIDATE_DATUMS.json'),'uniqueContactTriangleRecords':len(triangles),'perPose':table,'limitations':['Selected after observed outcomes, not held-out or representative.','All candidate corners extrapolate one center triangle.','No semantic floor or continuous support is established.','Whole triangle heights are not contact-point heights.','Higher contacts and low contacts are retained descriptively, neither deleted nor silently reclassified.','48 fixed KCC calls are not route movement; all proposals unapplied.','Two prior analytic down-step failures remain.']}
 write(out/'RESULTS.json',summary)
if __name__=='__main__':
 if len(sys.argv)!=2:raise SystemExit('usage: summarize.py <fresh-output-directory>')
 main(pathlib.Path(sys.argv[1]))
