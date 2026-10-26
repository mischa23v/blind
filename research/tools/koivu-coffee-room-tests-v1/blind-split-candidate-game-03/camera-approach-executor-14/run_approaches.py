"""One bounded six-slot approach batch; phone-only failures remain unexecuted.

Selection artifacts and source hashes must be frozen before reference loading.
Shared ground uses the original accepted scene seed, never avatar-specific fits.
"""
from pathlib import Path
import json,sys,time
import numpy as np
import vtk
from approach_controller import load_plan
from approach_process import ApproachControllerProcess
from approach_episode import episode,verify,HERE,ROOT,WS,sha,dump,load_surface,transform,serial_vtk,GroundSupport
from oriented_container import OrientedReferenceContainer,BodyGeometry

PROFILE_ORDER=('body45cmMargin0','body45cmMargin5cm','abstract28cmProfile')

from ground_setup import shared_ground

def main(expected):
    verify(expected);config=json.loads((HERE/'RUN_INPUTS.json').read_text());out=HERE/'run-01/result';out.mkdir(exist_ok=False)
    started=time.monotonic();records=[];selected=[]
    if len(config['plans'])!=6:raise ValueError('all six fixed profile/approach slots required')
    for number,item in enumerate(config['plans']):
        path=WS/item['path']
        if sha(path)!=item['sha256']:raise ValueError('selection artifact changed')
        plan=json.loads(path.read_text())
        if plan['profile']!=PROFILE_ORDER[number//2]or plan['approachID']!=('northSide','southSide')[number%2]:raise ValueError('fixed profile and approach order')
        name=plan['profile']+'-'+plan['approachID'];record={'slot':number,'profile':plan['profile'],'approachID':plan['approachID'],'planPath':item['path'],'planSHA256':item['sha256'],'phoneSelectionStatus':plan['status'],'arrival':False,'actualBodyContactEvents':0,'marginContactEvents':0,'actualDistanceMetres':0.,'physicalAuthority':False}
        records.append(record)
        if plan['status']!='selectedPhoneOnlyApproach':
            record.update(status='notExecuted:'+plan['status'],movementExecuted=False,referenceQueriesForThisSlot=0);continue
        plan=load_plan(path,item['sha256']);selected.append((number,plan,path,name))
    summary={'scope':'Two fixed camera-anchored approaches per numerical profile, not a table loop or live test','scheduledSlots':6,'phoneSelectedSlots':len(selected),'results':records,'physicalAuthority':False,'referenceUsedForSelection':False,'sourceConfidence':'missing, not fabricated','trackingState':'missing, not fabricated'}
    if selected:
        runtime=serial_vtk();surface,mesh_info,reader=load_surface()
        with np.load(ROOT/'inputs/koivu_5cm_v2_pipeline2_out.npz',allow_pickle=False)as a:level={'R':a['R'],'t':a['t']}
        A=np.asarray(json.loads((WS/'blind-koivu-faro-acquisition-04/selected-reference/icp_iphone.json').read_text())['gt_transformation'])
        base=OrientedReferenceContainer(surface,transform(level,A));old=json.loads((ROOT/'ground-follow-v3/run-01/result/RESULT.json').read_text());original=json.loads((ROOT/'FIRST_ROUTE.json').read_text())
        paths=[np.vstack((original['start'],original['nativeInitialRoute']['points'],original['goal']))]
        paths.extend(np.vstack((p['start'],p['nativeInitialRoute']['points'],p['goal']))for _,p,_,_ in selected)
        ground=None;failure=None;preflight={}
        def query_progress(row):
            nonlocal preflight
            preflight=row;dump(out/'GROUND_SETUP_PREFLIGHT.json',row)
            print(json.dumps({'phase':'ground_setup_preflight',**row}),flush=True)
        initial=old['initialReferenceSupport']['probes'];seeds=[int(x['referenceCellID'])for x in initial];points=[[x['modelXZ'][0],x['modelHeightY'],x['modelXZ'][1]]for x in initial]
        try:
            phase=time.monotonic();ground=shared_ground(base,paths,seeds,points,query_progress)
            summary['sharedGroundSetupWallSeconds']=time.monotonic()-phase;summary['sharedGround']=ground.receipt
            summary['originalSceneGroundReceipt']=old['groundComponent'];print(json.dumps({'phase':'shared_scene_ground_ready','groundCells':len(ground.ground_cell_ids)}),flush=True)
        except (RuntimeError,ValueError)as e:
            failure='sharedSceneGroundSetupUnavailable: '+str(e)
            summary['setupFailureDetails']=getattr(e,'details',{})
        summary.update(runtime=runtime,referenceMesh=mesh_info,groundSetupPreflight=preflight)
        for number,plan,path,name in selected:
            if ground is None:
                records[number].update(status=failure,movementExecuted=False,referenceSetupUnavailable=True);continue
            folder=out/name;folder.mkdir(exist_ok=False);g=plan['geometry']
            scorer=OrientedReferenceContainer(surface,base.transform,BodyGeometry(width=g['width'],depth=g['depth'],height=g['height'],horizontal_margin=g['margin']))
            def factory(output,selected_path=path):return ApproachControllerProcess(output,selected_path,WS/config['nativeDirectory'],config['nativeSHA256'])
            result=episode(plan,scorer,folder,ground,factory);result.update(planSHA256=sha(path),referencePhysicsNeverSelectsRoute=True,firstContactTerminates=True,phoneMapUnchanged=True)
            dump(folder/'RESULT.json',result);records[number].update(result)
            print(json.dumps({'phase':'approach_terminal','profile':plan['profile'],'approachID':plan['approachID'],'status':result['status'],'arrival':result['arrival'],'distance':result['actualDistanceMetres'],'bodyContacts':result['actualBodyContactEvents'],'marginContacts':result['marginContactEvents']}),flush=True)
    summary.update(arrivals=sum(r['arrival']for r in records),slotsWithActualBodyContact=sum(r['actualBodyContactEvents']>0 for r in records),slotsWithMarginContact=sum(r['marginContactEvents']>0 for r in records),slotsWithAnyContact=sum(bool(r['actualBodyContactEvents']or r['marginContactEvents'])for r in records),actualBodyContactEvents=sum(r['actualBodyContactEvents']for r in records),marginContactEvents=sum(r['marginContactEvents']for r in records),actualDistanceMetres=sum(r['actualDistanceMetres']for r in records),wallSeconds=time.monotonic()-started)
    verify(expected);dump(out/'SUMMARY.json',summary);print(json.dumps({'phase':'terminal','phoneSelectedSlots':len(selected),'arrivals':summary['arrivals'],'slotsWithAnyContact':summary['slotsWithAnyContact']}),flush=True)
if __name__=='__main__':main(sys.argv[1])
