"""Pure-stdlib terminal audit; no native engine rerun."""
import hashlib,json,math,pathlib
from schedule_contract import load_schedules,unchanged_metadata,XZ_TOLERANCE_METRES
from vtk_contract import validate_vtk
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def need(v,m):
 if not v:raise ValueError(m)
def ok_status(v):return type(v)is int and bool(v&(1<<30))and not(v&(1<<31))and not(v&0xffffff)
def validate_results(work,source,manifest_sha):
 work=pathlib.Path(work);source=pathlib.Path(source);repo=source.parents[1];data=repo.parent/'rapier-real-room-inputs-001'
 need(sha(source/'RUN_PINS.json')==manifest_sha,'manifest changed')
 s=json.loads((work/'height/SUMMARY.json').read_text());need(s['status']=='completed_local_polygon_height_diagnostic','height worker incomplete')
 for k,v in {'movementApplied':False,'physicalAuthority':False,'supportEstablished':False,'semanticFloorEstablished':False,'arrivalEstablished':False,'inputHashesAfterMatch':True,'eventRows':3696,'footOffsetMetres':0,'xzReportingToleranceMetres':1e-6}.items():need(s.get(k)==v,'height summary '+k)
 need(s['librarySHA256']==sha(work/'libheight_follow.so'),'built native library changed')
 need(s['config']==dict(radius=.225,height=1.75,cell_size=.025,cell_height=.025,max_climb=.025,max_slope=15,max_cells=250000,max_nodes=4096),'native configuration changed')
 rows=[json.loads(x)for x in(work/'height/events.jsonl').read_text().splitlines()];need(len(rows)==3696,'height denominator')
 schedules=load_schedules(repo);offset=0;scenes=[];query_calls=0
 for route,scene_summary in zip(schedules,s['scenes']):
  need((scene_summary['scene'],scene_summary['name'])==(route['scene'],route['name']),'scene order')
  need(scene_summary['requestedStartXYZ']==route['requestedStartXYZ']and scene_summary['requestedGoalXYZ']==route['requestedGoalXYZ'],'goal identity changed')
  valid=0;failed=False;last_actual=None;first_fail=None;shifts=[]
  for i,e in enumerate(route['events']):
   h=rows[offset];offset+=1
   need((h['scene'],h['name'],h['eventIndex'])==(route['scene'],route['name'],i),'event identity')
   need(h['originalEvent']==e and h['physicalAuthority']is False and h['movementApplied']is False,'authored event/authority')
   unchanged_metadata(e,h);q=h['queryResult'];need(isinstance(q,dict),'query provenance')
   if h['valid']:
    need(not failed and h['unavailableReason']is None and q['valid']is True,'no recovery after failed association')
    need(ok_status(q['moveStatus'])and ok_status(q['heightStatus']),'native incomplete statuses accepted')
    need(q['resultRef']and q['visitedReferences']and q['resultRef']==q['visitedReferences'][-1],'active polygon state')
    for key,actual in [('a',q['previousXYZ']),('b',q['actualXYZ'])]:
     need(actual is not None and math.hypot(actual[0]-e[key][0],actual[2]-e[key][2])<=XZ_TOLERANCE_METRES,'XZ clamp accepted')
     need(h[key][1]==actual[1],'extra lift/height changed');shifts.append(h[key][1]-e[key][1])
    if last_actual is not None:need(q['previousXYZ']==last_actual,'local polygon state discontinuity')
    last_actual=q['actualXYZ'];valid+=1
   else:
    failed=True;first_fail=i if first_fail is None else first_fail
    need(h['a']is None and h['b']is None and isinstance(h['unavailableReason'],str),'invalid replaced by valid geometry')
   if q.get('queryExecuted',False):query_calls+=1
  need(scene_summary['validEvents']==valid and scene_summary['unavailableEvents']==len(route['events'])-valid and scene_summary['firstUnavailableEvent']==first_fail,'scene counts')
  scenes.append({'scene':route['scene'],'name':route['name'],'validNativeEvents':valid,'unavailableNativeEvents':len(route['events'])-valid,'minimumVerticalShiftMetres':min(shifts)if shifts else None,'maximumVerticalShiftMetres':max(shifts)if shifts else None,'physicalStartKnown':False,'arrivalEstablished':False})
 need(s['beginCalls']<=4,'bounded initial associations')
 need(offset==3696 and query_calls==s['stepCalls']and query_calls<=3696,'bounded step count')
 vtk=validate_vtk(work/'vtk',repo,data,work/'height/events.jsonl')
 return {'status':'complete_diagnostic_not_navigation_acceptance','scenes':scenes,'vtk':vtk,'stepCalls':query_calls,'physicalAuthority':False,'arrivalEstablished':False,'higherAndLowerContactsRetained':True,'uncoveredLowBandMayContainRealObjects':True}
