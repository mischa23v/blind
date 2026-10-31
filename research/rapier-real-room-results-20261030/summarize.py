"""Stdlib-only aggregation of completed immutable Rapier records; never runs engine."""
import collections,hashlib,json,math,pathlib,sys
W=pathlib.Path(__file__).resolve().parents[3]
D=W/'rapier-real-room-attempt-001'; EPS=1e-6; INPUT_EPS=1e-8
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
norm=lambda a:math.sqrt(sum(v*v for v in a))
diff=lambda a,b:norm([x-y for x,y in zip(a,b)])
rows=[json.loads(s)for s in (D/'probes/probe-rows.jsonl').read_text().splitlines()]
assert len(rows)==408 and sum(x['row']['controllerCalled']for x in rows)==328
assert all(x['row']['physicalAuthority'] is False and x['row']['movementApplied'] is False and x['row']['support']=='unknown'for x in rows)
compact=[];groups={}
for x in rows:
 r=x['row'];v=r['independentEvidence'].get('vtk',{}).get('actualBody'if x['envelope']=='body'else'horizontalMargin');z={k:x[k]for k in ('scene','arm','envelope','inputArm')};z.update(id=r['id'],kind=r['kind'],controllerCalled=r['controllerCalled'],vtkContact=None if v is None else v['contact'],vtkRawCount=None if v is None else v['rawContactCount'],vtkFirstWitnessWithin25mm=None if v is None else v.get('firstWitnessWithin25mmOfStartFootPlane'),vtkFirstTriangleHeightRange=None if v is None else v.get('firstTriangleHeightRelativeToStartFootRange'))
 if r['controllerCalled']:
  q,p=r['requestedDelta'],r['proposedMovement'];err=diff(p,q);n=norm(q);z.update(requested=q,proposed=p,errorNormMetres=err,grounded=r['computedGrounded'],collisionEvents=len(r['collisions']),zeroInput=n==0,changedBeyond1um=err>EPS,nonzeroProposed=norm(p)>EPS,alongRequestedRatio=None if n==0 else sum(a*b for a,b in zip(q,p))/(n*n))
 compact.append(z)
 key='|'.join(z[k]for k in ('scene','envelope','arm','inputArm'));g=groups.setdefault(key,collections.Counter());g['rows']+=1
 if not r['controllerCalled']:g['unsupportedTurns']+=1;continue
 g['calls']+=1;g['zeroInput'if n==0 else'nonzeroInput']+=1;g['inputAbove10nm'if n>INPUT_EPS else'inputAtMost10nm']+=1;g['inputAbove10nmUnchangedWithin1um']+=n>INPUT_EPS and err<=EPS;g['inputAbove10nmChangedBeyond1um']+=n>INPUT_EPS and err>EPS;g['inputAtMost10nmNonzeroProposalBeyond1um']+=n<=INPUT_EPS and norm(p)>EPS;g['tinyNonzeroInputAtMost10nm']+=0<n<=INPUT_EPS;g['changedBeyond1um']+=err>EPS;g['grounded']+=r['computedGrounded'];g['callsWithCollisionEvents']+=bool(r['collisions']);g['collisionEvents']+=len(r['collisions']);g['maxErrorMetres']=max(g['maxErrorMetres'],err)
 if n==0:g['zeroInputNonzeroProposal']+=norm(p)>EPS;g['maxZeroInputProposalMetres']=max(g['maxZeroInputProposalMetres'],norm(p))
 else:
  g['nonzeroInputUnchangedWithin1um']+=err<=EPS;g['nonzeroInputChangedBeyond1um']+=err>EPS;g['nonzeroInputProgressShortfallBeyond1um']+=sum(a*b for a,b in zip(q,p))/n<n-EPS
 if v is None:g['noDirectVTKComparison']+=1
 else:
  g['vtkContact']+=v['contact'];g['vtkContactAndUnchangedWithin1um']+=v['contact'] and err<=EPS;g['vtkNoContactButChangedBeyond1um']+=not v['contact'] and err>EPS;g['vtkContactFirstWitnessNearFoot']+=v['contact'] and v.get('firstWitnessWithin25mmOfStartFootPlane') is True
lookup={(x['scene'],x['envelope'],x['arm'],x['inputArm'],x['id']):x for x in compact}
comparisons={}
for mode in ['meshFlags','inputArms']:
 out={'pairs':0,'proposalDifferentExactly':0,'proposalDifferentBeyond1um':0,'groundedDifferent':0,'collisionEventCountDifferent':0,'maxProposalDifferenceMetres':0,'differences':[]}
 for x in compact:
  if not x['controllerCalled']or(mode=='meshFlags'and x['arm']!='raw_trimesh')or(mode=='inputArms'and x['inputArm']!='exact_xyz'):continue
  y=lookup[(x['scene'],x['envelope'],'two_sided_internal_edges'if mode=='meshFlags'else x['arm'],'horizontal_projection'if mode=='inputArms'else x['inputArm'],x['id'])];e=diff(x['proposed'],y['proposed']);out['pairs']+=1;out['proposalDifferentExactly']+=x['proposed']!=y['proposed'];out['proposalDifferentBeyond1um']+=e>EPS;out['groundedDifferent']+=x['grounded']!=y['grounded'];out['collisionEventCountDifferent']+=x['collisionEvents']!=y['collisionEvents'];out['maxProposalDifferenceMetres']=max(out['maxProposalDifferenceMetres'],e)
  if e>EPS:out['differences'].append({'id':x['id'],'scene':x['scene'],'envelope':x['envelope'],'arm':x['arm'],'inputArm':x['inputArm'],'differenceMetres':e})
 comparisons[mode]=out
result={'schema':1,'status':'completed_fixed_pose_diagnostic_not_movement','reportingToleranceMetres':EPS,'inputMagnitudeReportingToleranceMetres':INPUT_EPS,'exactZeroInputDefinition':'norm(actual requestedDelta) == 0; separate 10 nm input classification retained','toleranceIsNotSafetyOrAcceptanceThreshold':True,'sourceFiles':{str(p.relative_to(W)):sha(p)for p in [D/'GUARD_RUN/RESULT.json',D/'probes/SUMMARY.json',D/'probes/probe-rows.jsonl',D/'probes/wrapper-records.jsonl']},'groups':groups,'comparisons':comparisons,'physicalAuthority':False,'movementApplied':False,'support':'unknown','arrivalEstablished':False,'directVTKCaveat':'Original conservative VTK swept cuboid excludes lower 2 mm; KCC includes it plus 2 mm offset. Horizontal projection has different intent. C saved-state direct static VTK query absent; historical evidence not substituted.'}
out=pathlib.Path(sys.argv[1]);out.mkdir(exist_ok=True);(out/'RESULTS.json').write_text(json.dumps(result,indent=2)+'\n');(out/'COMPACT_PROBES.jsonl').write_text(''.join(json.dumps(x,separators=(',',':'))+'\n'for x in compact));print(json.dumps(result,indent=2))
