"""One frozen north approach, unchanged original world/scene-plane anchor."""
from pathlib import Path
import importlib.util,json,math,selectors,subprocess,sys,time
import numpy as np
HERE=Path(__file__).resolve().parent;WS=HERE.parent;GAME=WS/'blind-split-candidate-game-03'
# Load local episode before historical sys.path changes; never ambiguous module names.
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);sys.modules[name]=m;spec.loader.exec_module(m);return m
motion=load('north_frozen_episode',HERE/'episode.py')
from goal_region_map import load_plan,PLAN,PLAN_SHA
sys.path.insert(0,str(GAME/'camera-approach-executor-14'))
from ground_setup import shared_ground
from oriented_container import OrientedReferenceContainer,BodyGeometry

class ControllerProcess(motion.ControllerProcess):
 def __init__(self,out):
  self.err=(Path(out)/'controller.stderr.log').open('x');self.p=subprocess.Popen([sys.executable,str(HERE/'goal_region_controller.py')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.err,text=True,bufsize=1)
  self.selector=selectors.DefaultSelector();self.selector.register(self.p.stdout,selectors.EVENT_READ)
  try:self.initial=self.ask({'command':'initialize','planPath':str(PLAN),'planSHA256':PLAN_SHA})
  except BaseException:self.close();raise

def retain_scene_plane(ground,prior):
 coefficients=np.asarray(prior['planeCoefficientsYEqualsAXPlusBZPlusC'],float)
 if coefficients.shape!=(3,)or not np.isfinite(coefficients).all()or math.degrees(math.atan(np.linalg.norm(coefficients[:2])))>5:raise ValueError('fixed previously used scene plane')
 receipt=ground.receipt
 receipt['expandedMembershipBroadPlaneDiagnostic']=receipt['broadPlaneCoefficientsYEqualsAXPlusBZPlusC']
 receipt['expandedMembershipBroadPlaneFitDiagnostic']=receipt['broadPlaneFit']
 receipt['planeCoefficientsYEqualsAXPlusBZPlusC']=coefficients.tolist()
 receipt['supportPlanePolicy']='Exact stage14 common scene support plane retained, not refitted per north route or avatar; expanded membership broad fit is diagnostic only'
 receipt['supportPlaneSource']='camera-approach-executor-14/run-01/result/SUMMARY.json:sharedGround'
 coefficients.setflags(write=False);ground.plane_coefficients=coefficients
 return ground

def main(expected):
 motion.verify(expected);out=HERE/'run-01/result';out.mkdir(exist_ok=False);started=time.monotonic();plan=load_plan()
 runtime=motion.serial_vtk();surface,mesh_info,reader=motion.load_surface()
 with np.load(GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz',allow_pickle=False)as a:level={'R':a['R'],'t':a['t']}
 A=np.asarray(json.loads((WS/'blind-koivu-faro-acquisition-04/selected-reference/icp_iphone.json').read_text())['gt_transformation'])
 base=OrientedReferenceContainer(surface,motion.transform(level,A))
 original=json.loads((GAME/'FIRST_ROUTE.json').read_text());old=json.loads((GAME/'ground-follow-v3/run-01/result/RESULT.json').read_text());prior=json.loads((GAME/'camera-approach-executor-14/run-01/result/SUMMARY.json').read_text())
 paths=[np.vstack((original['start'],original['nativeInitialRoute']['points'],original['goal']))]
 old_south=json.loads((GAME/'two-approach-selection-11/run-01/result/body45cmMargin0-southSide.json').read_text())
 paths.append(np.vstack((old_south['start'],old_south['nativeInitialRoute']['points'],old_south['goal'])))
 paths.append(np.asarray(plan['originalFramePath']))
 initial=old['initialReferenceSupport']['probes'];seeds=[int(p['referenceCellID'])for p in initial];points=[[p['modelXZ'][0],p['modelHeightY'],p['modelXZ'][1]]for p in initial]
 def progress(row):motion.dump(out/'GROUND_SETUP_PREFLIGHT.json',row);print(json.dumps({'phase':'ground_setup_preflight',**row}),flush=True)
 try:
  phase=time.monotonic();ground=shared_ground(base,paths,seeds,points,progress);ground=retain_scene_plane(ground,prior['sharedGround']);setup=time.monotonic()-phase
 except (ValueError,RuntimeError)as e:
  result={'status':'sharedSceneGroundSetupUnavailable','reason':str(e),'details':getattr(e,'details',{}),'arrival':False,'motionExecuted':False,'actualDistanceMetres':0.,'actualBodyContactEvents':0,'marginContactEvents':0,'physicalAuthority':False,'computeSetupIsNotNavigationFailure':True}
 else:
  print(json.dumps({'phase':'shared_scene_ground_ready','groundCells':len(ground.ground_cell_ids),'wallSeconds':setup}),flush=True)
  g=plan['geometry'];scorer=OrientedReferenceContainer(surface,base.transform,BodyGeometry(width=g['width'],depth=g['depth'],height=g['height'],horizontal_margin=g['margin']))
  result=motion.episode(plan,scorer,out,ground,ControllerProcess);result['sharedGroundSetupWallSeconds']=setup
 result.update(planSHA256=PLAN_SHA,physicsFrame='original supplied game frame',correctedMapRevision=plan['mapRevision'],originalTaskGoal=plan['goal'],steeringGoalOriginalFrame=plan['steeringGoalOriginalFrame'],steeringGoalIsNotArrivalOrigin=True,worldOrReferenceNeverSelectsRoute=True,firstContactTerminates=True,runtime=runtime,referenceMesh=mesh_info,wallSeconds=time.monotonic()-started)
 motion.verify(expected);motion.dump(out/'RESULT.json',result);print(json.dumps({'phase':'terminal','status':result['status'],'arrival':result['arrival'],'distance':result['actualDistanceMetres'],'bodyContacts':result['actualBodyContactEvents'],'marginContacts':result['marginContactEvents']}),flush=True)
if __name__=='__main__':main(sys.argv[1])
