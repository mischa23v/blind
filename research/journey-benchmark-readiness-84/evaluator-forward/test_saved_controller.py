"""Replay saved stage76 delivered packets; no evaluator load, geometry queries or actor."""
from pathlib import Path
import os,json,zipfile,lzma,hashlib,copy,ast
os.environ['FROZEN_EPISODE_SESSION_ID']='stage76-temporal-jitter-seed72000'
H=Path(__file__).resolve().parent;R=H.parents[2]
import loop_controller as c
z=zipfile.ZipFile(R/'research/tools/measured-progress-and-coffee-v1/measured-progress-pilot.zip');prefix='blind-batched-observation-progress-76/';raw=z.read(prefix+'SELECTED_PLAN.json');plan=json.loads(raw);revision=hashlib.sha256(raw).hexdigest();plan.update(goal=plan['legs'][0]['originalTaskGoal'],steeringGoalOriginalFrame=plan['legs'][0]['originalTaskGoal'],originalFramePath=plan['legs'][0]['originalFramePath'],mapRevision=revision)
# Fixture injects historical source-only plan; real production load_plan remains unchanged.
# This isolates controller/map-cursor semantics, not new-plan dispatch/identity validation.
c.load_plan=lambda path,digest:copy.deepcopy(plan)
controller=c.Controller();controller.consume({'command':'initialize','planPath':'historical-fixture-only','planSHA256':revision});controller.consume({'command':'beginRun','goal':plan['goal']})
rows=[json.loads(line)for line in lzma.decompress(z.read(prefix+'pilot-temporal_jitter/result/TICK_EVIDENCE.jsonl.xz')).decode().splitlines()];keys=['forwardMetres','yawRadians','goalReached','reason','sourceCapturedAt','sourceCapturedTick','sourceGeneration','poseAgeSeconds','releasedObservationProgress','steeringFromNewestOnly','nativeCandidatePoints'];failures=[]
for row in rows:
 result=controller.consume({'command':'tick','tick':row['tick'],'now':100+row['tick']/15,'deliveredPose':row['deliveredPose'],'releasedPoses':[dict(x['packet']['pose'],deliveryMode='new')for x in row['poseDelivery']['released']]})
 for k in keys:
  if result.get(k)!=row['cue'].get(k):failures.append({'tick':row['tick'],'key':k,'actual':result.get(k),'expected':row['cue'].get(k)})
controller.close()
# Exact AST function comparison ensures published numerical predicates weren't rewritten.
def funcs(s):return {x.name:ast.dump(x,include_attributes=False)for x in ast.parse(s).body if isinstance(x,ast.FunctionDef)}
prim=funcs((H/'physics_primitives.py').read_text());source=R/'research/tools';origins=[(source/'koivu-split-candidate-game-v1/blind-split-candidate-game-03/source/run_pilot.py',['support_check','contact_status']),(source/'koivu-split-candidate-game-v1/blind-opus-reference-scoring-audit-02/source/score_reference.py',['transform','load_surface']),(source/'koivu-coffee-room-tests-v1/blind-split-candidate-game-03/ground-follow-v3/run_ground_pilot.py',['connected_support'])];checked=[]
for p,names in origins:
 original=funcs(p.read_text())
 for name in names:assert prim[name]==original[name],name;checked.append(name)
a=funcs((H/'local_support.py').read_text());b=funcs(z.read(prefix+'local_support.py').decode());assert a==b
report={'savedTicks':len(rows),'comparedFields':keys,'mismatches':failures,'numericalPrimitiveASTParity':checked,'allLocalSupportFunctionsASTParity':True,'historicalPlanSHA256':revision,'newPairRouteNotSubstituted':True,'controllerFixturePlanLoaderInjected':True,'nativeMeshLoaded':False,'movementEpisodesExecuted':0,'physicalAuthority':False}
(H/'SAVED_CONTROLLER_REPLAY.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({**report,'mismatches':len(failures)}));assert not failures
