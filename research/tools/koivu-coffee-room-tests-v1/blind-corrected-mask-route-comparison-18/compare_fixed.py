"""Fixed same-phone-space OLD/NEW objectives; maximum36 native queries, no reselection."""
from pathlib import Path
import json,sys
import numpy as np
from scipy import ndimage
from paired_adapter import *


def main(output,expected):
 freeze=HERE/'FROZEN.json'
 if sha(freeze)!=expected:raise ValueError('explicit frozen SHA before parse')
 pins=json.loads(freeze.read_text())['files']
 def verify():
  for p,h in pins.items():
   if sha(WS/p)!=h:raise ValueError('source/input changed '+p)
 verify();out=Path(output);out.mkdir(exist_ok=False)
 helpers=helper_modules();old=metadata('old');new=metadata('new');summaries=[]
 loopdir=GAME/'body-margin-variants-07/run-01/artifacts';approachdir=GAME/'two-approach-selection-11/run-01/result'
 original_target=None
 for profile in PROFILES:
  prior=json.loads((loopdir/(profile+'.json')).read_text());waypoints=prior['candidate']['waypoints']
  if len(waypoints)!=4 or [w['side']for w in waypoints]!=['north','east','south','west']:raise ValueError('fixed four-waypoint order')
  target=np.asarray(prior['candidate']['targetComponent']['sourceCellIndices'],int)
  if target.shape!=(4667,2):raise ValueError('original broad target size')
  if original_target is None:original_target=target
  elif not np.array_equal(target,original_target):raise ValueError('original targets differ')
  target_level=np.c_[(target+old['lo'][:2]+.5)*.05,np.zeros(len(target))];target_game=level_to_game(target_level)
  numer=target*len(target)-target.sum(axis=0);dist=(numer*numer).sum(axis=1);probe_index=np.lexsort((target[:,1],target[:,0],dist))[0]
  specs=[]
  for k in range(4):specs.append({'objectiveID':'loop_'+waypoints[k]['side']+'_to_'+waypoints[(k+1)%4]['side'],'kind':'loopLeg','startOldGame':waypoints[k]['point'],'goalOldGame':waypoints[(k+1)%4]['point'],'priorNativeResult':prior['candidate']['nativeLegs'][k]})
  for side in ('northSide','southSide'):
   prev=json.loads((approachdir/(profile+'-'+side+'.json')).read_text());anchors=prev['sourceAnchors']
   specs.append({'objectiveID':'approach_'+side,'kind':'rawCameraApproach','startOldGame':anchors['start']['requestedGamePoint'],'goalOldGame':anchors['goal']['requestedGamePoint'],'originalAnchorProvenance':anchors,'priorStatus':prev['status'],'noPriorCandidateAssociationRelocationUsed':True})
  for label,meta in [('old',old),('new',new)]:
   model,geometry=open_model(label,profile)
   try:
    legs=[]
    for spec in specs:
     if label=='old':start=np.asarray(spec['startOldGame'],float);goal=np.asarray(spec['goalOldGame'],float)
     else:start,_=map_objective(spec['startOldGame'],old,new);goal,_=map_objective(spec['goalOldGame'],old,new)
     _,sa=map_objective(spec['startOldGame'],old,meta);_,ga=map_objective(spec['goalOldGame'],old,meta)
     result=query_fixed(model,start,goal,helpers);result.update(objectiveID=spec['objectiveID'],kind=spec['kind'],startCoordinateProvenance=sa,goalCoordinateProvenance=ga)
     if spec['kind']=='loopLeg'and label=='old':
      fields=('complete','points','reason','nativeComplete','nativeStatus','nativeError','projectedStart','projectedGoal','sampledRectangleResult')
      result['oldHistoricalNativeParity']={k:safe(result['nativeAndOriginalRectangleResult'][k])==safe(spec['priorNativeResult'][k])for k in fields}
     if spec['kind']=='rawCameraApproach':result['originalAnchorProvenance']=spec['originalAnchorProvenance'];result['priorApproachStatus']=spec['priorStatus']
     legs.append(result);print(json.dumps({'profile':profile,'map':label,'objective':spec['objectiveID'],'status':result['status'],'nativeReason':result['nativeAndOriginalRectangleResult']['reason']}),flush=True)
    mapped_targets,_=map_objective(target_game,old,meta);target_xy=game_to_level(mapped_targets)[:,:2]
    target_ij=np.floor(target_xy/.05).astype(int)-meta['lo'][:2]
    eligibility=model.mask&(ndimage.distance_transform_edt(model.mask)*.05-.05*np.sqrt(2)/2>=geometry['nativeRadiusIntended'])
    inside=np.all((target_ij>=0)&(target_ij<np.asarray(model.mask.shape)),axis=1)
    topology={'available':bool(inside.all()),'originalPhoneSpaceTargetCentres':len(target),'uniqueMappedTargetGridCells':int(len(np.unique(target_ij,axis=0))),'targetCentreCountOutsideMap':int((~inside).sum()),'fixedOriginalProxySourceIJ':target[probe_index].tolist(),'mappedProxyXYZ':mapped_targets[probe_index].tolist(),'mappedTargetHeightRangeMetres':[float(mapped_targets[:,1].min()),float(mapped_targets[:,1].max())],'semanticTableVerified':False,'gridHoleDiagnosticIsNotPhysicalRouteProof':True}
    if inside.all():
     topology['rawWalk']=helpers['topology'].analyse(model.mask,target_ij,target_ij[probe_index]);topology['discCentres']=helpers['topology'].analyse(eligibility,target_ij,target_ij[probe_index])
    cycle={'evaluated':False,'reason':'oneOrMoreFixedLegsRejected','movementExecuted':False}
    if all(x['status']=='fixedPhoneModelLegAccepted'for x in legs[:4]):
     path=np.asarray(legs[0]['planarFootprintValidationPath']+sum([x['planarFootprintValidationPath'][1:]for x in legs[1:4]],[]))
     check,_=helpers['loop'].sampled_closed_check(model,path);wind=helpers['loop'].winding_receipt(np.c_[path[:,0],-path[:,2]],target_xy)
     cycle={'evaluated':True,'unchangedSampledClosedCheck':check,'samePhoneSpaceTargetWinding':wind,'accepted':check['passed']and wind['passed'],'validationOnlyPlanarPath':path.tolist(),'movementExecuted':False,'fullXYZOriginalNativeLegsRetained':True}
    historical=[x.get('oldHistoricalNativeParity')for x in legs[:4]if 'oldHistoricalNativeParity'in x]
    artifact={'map':label,'profile':profile,'geometry':geometry,'mapRevision':model.revision,'inputMaskSHA256':INPUTS[label]['maskSHA'],'inputMetadataSHA256':INPUTS[label]['metaSHA'],'fixedObjectiveSpecification':specs,'legs':legs,'cycle':cycle,'sameOriginalPhoneSpaceProxyTopology':topology,'oldNativeHistoryParityAllFields':all(all(x.values())for x in historical)if historical else None,'nativeQueries':6,'referenceInputsUsed':False,'physicalAuthority':False,'newWaypointOrProxySelection':False,'newNearestValidCellSearch':False,'fullXYZObjectivesPreserved':True,'verticalProjectionIsReportedNotActorSnapped':True}
    name=profile+'-'+label+'.json'
    with(out/name).open('x')as f:json.dump(safe(artifact),f,indent=2,allow_nan=False);f.write('\n')
    summaries.append({'profile':profile,'map':label,'artifact':name,'sha256':sha(out/name),'legStatuses':[{k:x[k]for k in('objectiveID','status')}for x in legs],'oldNativeHistoryParityAllFields':artifact['oldNativeHistoryParityAllFields'],'cycleAccepted':cycle.get('accepted',False)})
   finally:model.close()
 verify()
 with(out/'RESULTS.json').open('x')as f:json.dump({'scope':'Paired OLD/NEW supplied-mask checks of same original phone-space objectives','results':summaries,'nativeQueries':36,'noNewSearchAlgorithm':True,'noObjectiveReselection':True,'sourceHashesVerifiedBeforeAfter':True,'movementEpisodesExecuted':0,'physicalAuthority':False},f,indent=2);f.write('\n')
if __name__=='__main__':main(sys.argv[1],sys.argv[2])
