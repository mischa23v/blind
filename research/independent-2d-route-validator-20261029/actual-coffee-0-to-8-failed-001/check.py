"""Historical real path versus MANUAL diagnostic exclusions; not table truth."""
import ctypes as C
import hashlib
import json
from pathlib import Path
import sys
import time
sys.path.insert(0,str(Path(__file__).resolve().parent.parent))
from validator import GEOS, polygon, coords, BODY_RADIUS, MARGIN, RADIUS, GUARD
here=Path(__file__).resolve().parent
inputs=json.loads((here/'INPUT_FREEZE.json').read_text())
repo=here.parents[2]
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
for item in inputs['sources']:
 assert digest(repo/item['path'])==item['sha256'], 'source changed before run'
start=time.monotonic(); g=GEOS()
result={'scope':'historical real Coffee 0→8 path versus predeclared MANUAL_DIAGNOSTIC_EXCLUSIONS_NOT_MEASURED_TABLES',
 'physical_clearance':'unknown','live_guidance_allowed':False,'floor_body_head_projection_coverage':'unknown',
 'frame':'unchanged Coffee OBJ source XZ; historical replay, not current localization',
 'path_modified':False,'original_20_queries_modified':False,'detour_generated':False,
 'profile':{'width':.45,'depth':.30,'height':1.6,'body_radius':BODY_RADIUS,'margin':MARGIN,'sweep_radius':RADIUS,'numerical_guard':GUARD},
 'input_manifest_sha256':digest(here/'INPUT_FREEZE.json'),'geos_version':g.version,'segments':[]}
try:
 intersection=g.lib.GEOSIntersection_r; intersection.argtypes=[C.c_void_p]*3; intersection.restype=C.c_void_p
 length=g.lib.GEOSLength_r; length.argtypes=[C.c_void_p,C.c_void_p,C.POINTER(C.c_double)]; length.restype=C.c_int
 windows=[]
 for name,w in inputs['windows'].items():
  xmin,xmax,zmin,zmax=w
  windows.append((name,polygon(g,[[xmin,zmin],[xmax,zmin],[xmax,zmax],[xmin,zmax]])))
 points=[[v[0],v[2]] for v in inputs['original_path_xyz']]
 for i,(a,b) in enumerate(zip(points,points[1:])):
  line=g.geometry('LINESTRING('+coords([a,b])+')')
  segment={'index_zero_based':i,'start_xz':a,'end_xz':b,'windows':[]}
  for name,window in windows:
   d=g.distance(line,window); inter=intersection(g.ctx,line,window)
   if not inter: raise ValueError('intersection failed')
   g.owned.append(inter); size=C.c_double()
   if length(g.ctx,inter,C.byref(size))!=1: raise ValueError('length failed')
   segment['windows'].append({'id':name,'centerline_distance_metres':d,'centerline_intersection_length_metres':size.value,
    'whole_body_plus_margin_contact':d<=RADIUS+GUARD,'clearance_after_body_and_margin_metres':d-RADIUS})
  result['segments'].append(segment)
 result['manual_exclusion_status']='rejected' if any(w['whole_body_plus_margin_contact'] for s in result['segments'] for w in s['windows']) else 'no_contact_with_these_manual_windows_only'
finally: g.close()
for item in inputs['sources']: assert digest(repo/item['path'])==item['sha256'], 'source changed during run'
result['sources_unchanged']=True; result['wall_seconds']=time.monotonic()-start
(here/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
