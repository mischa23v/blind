"""Assemble small published primitive set; no physics execution, no mesh access."""
from pathlib import Path
import zipfile,hashlib,json,ast,re
H=Path(__file__).resolve().parent;R=H.parents[2];T=R/'research/tools';records=[]
def sha(x):return hashlib.sha256(x).hexdigest()
def write(name,raw,origin,replacements=()):
 s=raw.decode()
 for a,b in replacements:
  assert a in s,(name,a);s=s.replace(a,b)
 (H/name).write_text(s);records.append({'local':name,'origin':origin,'originalSHA256':sha(raw),'adaptedSHA256':sha(s.encode()),'replacements':[{'from':a,'to':b}for a,b in replacements]});return s
zs={}
for p in T.glob('*/*.zip'):
 z=zipfile.ZipFile(p)
 for n in z.namelist():zs.setdefault(n,(p,z))
def archive(member,name,replacements=()):
 p,z=zs[member];return write(name,z.read(member),{'archive':str(p.relative_to(R)),'member':member},replacements)
def loose(path,name,replacements=()):return write(name,(T/path).read_bytes(),{'path':str((T/path).relative_to(R))},replacements)
def extract(path,names):
 s=path.read_text();tree=ast.parse(s);nodes={x.name:x for x in tree.body if isinstance(x,(ast.FunctionDef,ast.ClassDef))};parts=[]
 for name in names:
  n=nodes[name];code='\n'.join(s.splitlines()[n.lineno-1:n.end_lineno]);parts.append(code);records.append({'extractedName':name,'origin':str(path.relative_to(R)),'verbatimSHA256':sha(code.encode())})
 return '\n\n'.join(parts)+'\n'
prefix='koivu-coffee-room-tests-v1/blind-split-candidate-game-03/'
for rel in ['source/oriented_container.py','ground-follow-v2/oriented_ground_container.py','ground-skip-v4/oriented_ground_skip_container.py','ground-vector-v5/oriented_ground_vector_container.py','ground-obb-v6/oriented_ground_obb_container.py','ground-query-tile-13/tiled_bounds.py']:
 raw=(T/prefix/rel).read_text();repl=[]
 for line in raw.splitlines():
  if line.startswith('sys.path.insert'):repl.append((line,"sys.path.insert(0,str(Path(__file__).resolve().parent))"))
 loose(prefix+rel,Path(rel).name,repl)
for rel,name in [('koivu-split-candidate-game-v1/blind-opus-reference-scoring-audit-02/source/reference_band_box.py','reference_band_box.py'),('koivu-split-candidate-game-v1/blind-koivu-reference-comparison-06/reference_geometry.py','reference_geometry.py'),('koivu-split-candidate-game-v1/blind-authored-navigation-pilot/source/impairments.py','impairments.py')]:
 raw=(T/rel).read_text();repl=[(line,"sys.path.insert(0,str(Path(__file__).resolve().parent))")for line in raw.splitlines()if line.startswith('sys.path.insert')];loose(rel,name,repl)
raw=(T/prefix/'ground-query-tile-v17/oriented_ground_tiled_container.py').read_text();repl=[]
for line in raw.splitlines():
 if line.startswith('sys.path.insert'):repl.append((line,"sys.path.insert(0,str(Path(__file__).resolve().parent))"))
repl.extend([("ROOT/'ground-obb-v6/oriented_ground_obb_container.py'","Path(__file__).resolve().parent/'oriented_ground_obb_container.py'"),("ROOT/'ground-query-tile-13/tiled_bounds.py'","Path(__file__).resolve().parent/'tiled_bounds.py'"),("7005ab752d855edfdb1295b401ea8ad9d66516a5813f716f1a7818677bb1c222",sha((H/'oriented_ground_obb_container.py').read_bytes()))])
loose(prefix+'ground-query-tile-v17/oriented_ground_tiled_container.py','oriented_ground_tiled_container.py',repl)
archive('blind-conditioned-floor-membership-59/ground_classifier_resource.py','ground_classifier_resource.py')
archive('blind-conditioned-floor-membership-59/ground_setup.py','ground_setup.py',[("sys.path.insert(0,str(GAME/'ground-query-tile-13'))","sys.path.insert(0,str(HERE))")])
p='blind-batched-observation-progress-76/'
archive(p+'local_support.py','local_support.py',[("H=Path(__file__).resolve().parent;sys.path.insert(0,str(H.parent/'blind-polycam-varpu-executor-40'));import run_north as legacy\nmotion=legacy.motion","H=Path(__file__).resolve().parent\nimport physics_primitives as motion")])
archive(p+'pose_delivery.py','pose_delivery.py',[("sys.path.insert(0,str(W/'blind-authored-navigation-pilot/source'))","sys.path.insert(0,str(H))"),("SESSION_ID='stage76-temporal-jitter-seed72000'","import os\nSESSION_ID=os.environ.get('FROZEN_EPISODE_SESSION_ID','stage84-contract-fixtures')")])
archive(p+'observation_batch.py','observation_batch.py')
archive(p+'loop_controller.py','loop_controller.py',[("sys.path.insert(0,str(WS/'blind-koivu-game-07'))","sys.path.insert(0,str(Path(__file__).resolve().parent))"),("from game_model import follow_candidate","from follower import follow_candidate")])
archive(p+'loop_episode.py','loop_episode.py',[("H=Path(__file__).resolve().parent;W=H.parent;S=W/'blind-polycam-varpu-executor-40';sys.path.insert(0,str(S));import run_north as legacy\nmotion=legacy.motion","H=Path(__file__).resolve().parent;W=H.parent\nimport physics_primitives as motion"),("sys.path.insert(0,str(H));from loop_map import PLAN,PLAN_SHA,load_plan","sys.path.insert(0,str(H));from loop_map import load_plan"),("def __init__(self,out):","def __init__(self,out,plan):"),("'planPath':str(PLAN),'planSHA256':PLAN_SHA","'planPath':plan['_path'],'planSHA256':plan['_sha']"),("controller=ControllerProcess(out)","controller=ControllerProcess(out,plan)"),("for tick in range(450):","for tick in range(plan['maximumTicks']):"),("completeFirstLegSyntheticPilot","completeOrderedPairSyntheticEpisode"),("'firstLegOnly':True","'firstLegOnly':False"),("firstLegOnly=True","firstLegOnly=False"),("One short original first-leg synthetic stress episode","One frozen ordered-pair synthetic stress episode")])
source=T/'koivu-split-candidate-game-v1/blind-split-candidate-game-03/source/run_pilot.py'
head='''"""Verbatim published primitives only; explicit imports replace historical glue."""\nfrom pathlib import Path\nimport hashlib,json,math,os,selectors,subprocess,sys,time\nimport numpy as np\nimport vtk\nfrom vtk.util.numpy_support import vtk_to_numpy\nfrom impairments import ActorFIFO,ActorProfile,ActorCommand\nfrom reference_geometry import ReferenceSurface,GeometryFailure,serial_vtk,checked_similarity\nfrom oriented_ground_tiled_container import GroundTiledReferenceContainer\nREFERENCE=Path(__file__).resolve().parent/'inputs'\ndef log(**row):print(json.dumps(row,allow_nan=False),flush=True)\n'''
head+=extract(source,['sha','ControllerProcess','support_check','contact_status'])
head+=extract(T/prefix/'ground-follow-v3/run_ground_pilot.py',['connected_support'])
head+=extract(T/'koivu-split-candidate-game-v1/blind-opus-reference-scoring-audit-02/source/score_reference.py',['transform','load_surface'])
(H/'physics_primitives.py').write_text(head)
(H/'follower.py').write_text('import math\nimport numpy as np\n'+extract(T/'koivu-offline-game-v1/game_model.py',['follow_candidate']))
archive('blind-tabletop-exclusion-loop-67/SELECTED_PLAN.json','HISTORICAL_SELECTED_PLAN.json')
(H/'ADAPTATION_RECEIPT.json').write_text(json.dumps(records,indent=2)+'\n')
print('Assembled',len(records),'published components/extractions; no native execution')
