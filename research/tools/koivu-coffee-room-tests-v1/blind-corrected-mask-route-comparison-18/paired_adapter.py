"""Isolated provided-mask inputs; existing native route and rectangle methods reused.

Full original physical objectives are retained across level-frame changes.
No reference fields, pose correction, actor snapping, or new search algorithm.
"""
from pathlib import Path
import hashlib,importlib.util,json,math,sys
import numpy as np
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;WS=HERE.parent;GAME=WS/'blind-split-candidate-game-03'
VARIANTS=GAME/'body-margin-variants-07';NATIVE=VARIANTS/'native025'
VARIANTS_SHA='661ae8cd72390da3d931dc9b1437be033cfcfe11079d63a708a58afc5a98a9f8'
LIB_SHA='b6cd7e2ac35d738337e80597bcbdafd62e6884f5100867d7afbe1b77105709b0'
APPROACH_SHA='d743ab6aeee50a0bf6041aed90418e5c6b1d6dbf5e6e125d5987d4cc580680fa'
LOOP_SHA='8ff34e28a8b30961db2c287f5e91ddf29497ca8ecc729bf6023afae185493cc6'
TOPO_SHA='7e5b7923a4435559bb7bc6be90f8abb0fb14b4a873d9ec7718a76c9014ed24a9'
PHONE_KEYS=('support','deepBelow','nearDip','low1','lowUnresolvedFlag','highObstacle','highUnknown','walk')
PROFILES=('body45cmMargin0','body45cmMargin5cm','abstract28cmProfile')
NEW=WS/'blind-pose-experiments-review-17/upstream/pose-consistency/runs/koivu_floorfix'
INPUTS={'old':{'mask':GAME/'inputs/koivu_5cm_occthres_split0.7.npz','maskSHA':'b294d92cfd9136d00de510239c2b85a9d68d878dcf7dac1a64b144d8880cb076','meta':GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz','metaSHA':'a2fc5c13f86bf7033131347fd9b6d61db23ab716d12d668a3d969b9e87dbf48d'},'new':{'mask':NEW/'occthres_split0.7.npz','maskSHA':'41f26bb3bd7d364982978b8d9b3cfe7ab64e49a67de66c100f58a795e65af011','meta':NEW/'pipeline2_out.npz','metaSHA':'ac63b5219a61094d754b6303d40b7f9dc0905a2abe446b6070bab94458c592d7'}}

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(name,path,expected):
 if sha(path)!=expected:raise ValueError('pinned source changed: '+str(path))
 spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);sys.modules[name]=module;spec.loader.exec_module(module);return module

def metadata(label):
 spec=INPUTS[label]
 if sha(spec['meta'])!=spec['metaSHA']:raise ValueError('provided metadata identity')
 with np.load(spec['meta'],allow_pickle=False)as z:lo=z['lo'].copy();R=z['R'].copy();t=z['t'].copy();res=float(z['res'])
 if lo.shape!=(3,)or R.shape!=(3,3)or t.shape!=(3,)or res!=.05:raise ValueError('metadata schema')
 if not np.isfinite(R).all()or not np.isfinite(t).all()or not np.allclose(R@R.T,np.eye(3),rtol=0,atol=1e-8)or abs(np.linalg.det(R)-1)>1e-8:raise ValueError('rigid level metadata')
 return {'lo':lo,'R':R,'t':t,'res':res}

def game_to_level(p):
 a=np.asarray(p,float)
 if a.shape[-1]!=3 or not np.isfinite(a).all():raise ValueError('finite XYZ required')
 return np.stack((a[...,0],-a[...,2],a[...,1]),axis=-1)
def level_to_game(p):
 a=np.asarray(p,float)
 if a.shape[-1]!=3 or not np.isfinite(a).all():raise ValueError('finite XYZ required')
 return np.stack((a[...,0],a[...,2],-a[...,1]),axis=-1)
def map_objective(point,old,new):
 p=np.asarray(point,float);level0=game_to_level(p);phone=(level0-old['t'])@old['R'];level1=phone@new['R'].T+new['t'];mapped=level_to_game(level1)
 back=level_to_game(((level1-new['t'])@new['R'])@old['R'].T+old['t'])
 return mapped,{'originalGameXYZ':p.tolist(),'originalLevelXYZ':level0.tolist(),'unchangedPhoneXYZ':phone.tolist(),'mappedLevelXYZ':level1.tolist(),'mappedGameXYZ':mapped.tolist(),'roundtripMaximumAbsErrorMetres':float(abs(back-p).max()),'mappedHeightWasFlattened':False}

def open_model(label,profile):
 if profile not in PROFILES:raise ValueError('only three primary fixed profiles')
 variants=load('paired_profiles_'+label+'_'+profile,VARIANTS/'margin_variants.py',VARIANTS_SHA)
 cm=variants.base_module();g=variants.geometry(profile);rr=variants.rectangle_module(profile)
 if sha(NATIVE/'libblind_detour.so')!=LIB_SHA:raise ValueError('native library identity')
 de=variants.load_pinned('paired_detour_'+label+'_'+profile,NATIVE/'detour_engine.py',variants.BINDING_SHA)
 class ProvidedMask(cm.CandidateMap):
  def __init__(self):
   self.engine=None;self.rr=rr;self.de=de;spec=INPUTS[label]
   if sha(spec['mask'])!=spec['maskSHA']:raise ValueError('provided mask identity')
   with np.load(spec['mask'],allow_pickle=False)as z:
    if set(z.files)!=set(PHONE_KEYS):raise ValueError('phone-only mask allowlist')
    self.flags={k:z[k].copy()for k in PHONE_KEYS}
   self.mask=self.flags['walk'];meta=metadata(label);self.lo=meta['lo'];self.R=meta['R'];self.t=meta['t']
   if self.mask.shape!=(241,250)or not all(a.dtype==np.bool_ and a.shape==self.mask.shape for a in self.flags.values()):raise ValueError('provided mask shape/type')
   self.origin=tuple((self.lo[:2]*.05).tolist());self.revision=hashlib.sha256((label+spec['maskSHA']+spec['metaSHA']+json.dumps(g,sort_keys=True)+LIB_SHA).encode()).hexdigest()
   for a in [self.lo,self.R,self.t,*self.flags.values()]:a.setflags(write=False)
   vertices,triangles=rr.quads(self.mask,self.origin,.05);vertices[:,2]*=-1;triangles=triangles[:,[0,2,1]].copy()
   self.engine=de.Engine(vertices,triangles,de.Config(radius=g['nativeRadiusIntended'],height=1.75,cell_size=.025,max_climb=0.),mode='known-provided-map')
 return ProvidedMask(),g

def association(requested,projected):
 a=np.asarray(requested,float);b=np.asarray(projected,float)
 if b.shape!=(3,)or not np.isfinite(b).all():return {'validProjectedXYZ':False,'requestedXYZ':a.tolist(),'projectedXYZ':b.tolist()}
 delta=b-a
 return {'validProjectedXYZ':True,'requestedXYZ':a.tolist(),'projectedXYZ':b.tolist(),'deltaXYZMetres':delta.tolist(),'horizontalDisplacementMetres':float(np.linalg.norm(delta[[0,2]])),'verticalDisplacementMetres':float(delta[1]),'full3DDisplacementMetres':float(np.linalg.norm(delta)),'existingHorizontalAssociationAtMost0p10m':bool(np.linalg.norm(delta[[0,2]])<=.1),'newVerticalAcceptanceThresholdAdded':False,'actorSnapped':False}

def check_open(model,path):
 # This existing mask is a 2-D footprint surface; Y remains in the objective and
 # native receipt but is explicitly ignored by the unchanged footprint checker.
 p=np.asarray(path);xy=np.c_[p[:,0],-p[:,2]];delta=np.diff(xy,axis=0);length=np.linalg.norm(delta,axis=1)
 if np.any(length<=1e-6):raise ValueError('nondegenerate coalesced validation path required')
 heading=np.arctan2(delta[:,1],delta[:,0]);result=model.rr.sweep_ok(model.mask,model.origin,np.c_[xy[:,0],np.zeros(len(xy)),xy[:,1]])
 endpoints=all(model.rr.rect_ok(model.mask,model.origin,*q,float(th))for a,b,th in zip(xy[:-1],xy[1:],heading)for q in(a,b))
 return {'passed':result=='ok'and bool(endpoints),'unchangedSourceSweep':result,'exactSegmentEndpointHeadingsFit':bool(endpoints),'horizontalLengthMetres':float(length.sum()),'heightUsedForFootprintCheck':False,'translationSpacingMetres':.025,'turnStepDegrees':5,'continuousBodyOrVerticalClearanceProven':False}

def query_fixed(model,start,goal,helpers):
 a=np.asarray(start,float);b=np.asarray(goal,float);r=model.route(a,b)
 out={'requestedStartXYZ':a.tolist(),'requestedGoalXYZ':b.tolist(),'nativeAndOriginalRectangleResult':r,'startAssociation':association(a,r['projectedStart']),'goalAssociation':association(b,r['projectedGoal']),'originalNativePointsFullXYZ':r['points'],'fixedObjectivesRelocated':False,'movementExecuted':False,'physicalAuthority':False}
 if not r['complete']:out['status']='fixedNativeOrRectangleRejected';return out
 # Preserve ALL original 3-D native corners and exact requested endpoint first.
 # Existing candidate-only numerical coalescing is reused for 2-D validation.
 out['fullXYZCandidateWithExactGoalConnector']=[a.tolist(),*r['points'],b.tolist()]
 try:path,receipt=helpers['approach'].assemble(a,b,r)
 except ValueError as e:out['status']='exactGoalConnectorRejected';out['reason']=str(e);return out
 out['planarFootprintValidationPath']=path.tolist();out['planarCoalescingReceipt']=receipt;out['openPathCheck']=check_open(model,path)
 out['status']='fixedPhoneModelLegAccepted'if out['openPathCheck']['passed']else'exactEndpointOrOpenPathRejected'
 return out

def helper_modules():
 return {'approach':load('paired_unchanged_approach',GAME/'two-approach-selection-11/select_approaches.py',APPROACH_SHA),'loop':load('paired_unchanged_loop',GAME/'table-loop-proposal/table_loop.py',LOOP_SHA),'topology':load('paired_unchanged_topology',GAME/'table-loop-proposal/topology_quick.py',TOPO_SHA)}

def safe(value):
 if isinstance(value,float)and not math.isfinite(value):return None
 if isinstance(value,dict):return {k:safe(v)for k,v in value.items()}
 if isinstance(value,(list,tuple)):return [safe(v)for v in value]
 if isinstance(value,np.ndarray):return safe(value.tolist())
 if isinstance(value,np.generic):return safe(value.item())
 return value
