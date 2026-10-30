#!/usr/bin/env python3
"""Bounded full-schedule VTK replay diagnostic. No ground exemptions or movement."""
import argparse,gzip,hashlib,importlib.util,json,math,os,pathlib,sys,time
H=pathlib.Path(__file__).resolve().parent;REPO=H.parents[1]
MESH_SHA={'coffee.vertices.f32':'e373a1dba8872e7d9201ba9e35e3f28598fdc660842a28f7867386b1d40fb503','coffee.indices.u32':'a7f7238114579bebe9951f35b2122559540d4076c3186bee767d2e8a2d096767','conference.vertices.f32':'50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb','conference.indices.u32':'2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324'}
MAX_RECORDS=29568;MAX_TRIANGLES=30000000;MAX_BYTES=64*1024**2
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def need(v,m):
 if not v:raise ValueError(m)
def encoded(x):return (json.dumps(x,separators=(',',':'),allow_nan=False)+'\n').encode()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--mesh-root',type=pathlib.Path,required=True);ap.add_argument('--height-events',type=pathlib.Path,required=True);ap.add_argument('--output',type=pathlib.Path,required=True);a=ap.parse_args()
 for k in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS']:need(os.environ.get(k)=='1','serial environment')
 sys.dont_write_bytecode=True
 def verify():
  for n,h in MESH_SHA.items():need(sha(a.mesh_root/n)==h,'unchanged mesh '+n)
 verify();height_sha=sha(a.height_events)
 sys.path.insert(0,str(H))  # Pinned local schedule dependency under isolated Python.
 spec=importlib.util.spec_from_file_location('frozen_schedule',H/'schedule_contract.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 schedules=module.load_schedules(REPO)
 # Final height row schema is verified below before importing native libraries.
 heights=[json.loads(x)for x in a.height_events.read_text().splitlines()]
 expected=[(s,e,i)for s in schedules for i,e in enumerate(s['events'])]
 need(len(heights)==len(expected)==3696,'complete native event inventory')
 for h,(s,e,i)in zip(heights,expected):
  need((h['scene'],h['name'],h['eventIndex'])==(s['scene'],s['name'],i),'height identity/order')
  need(h['kind']==e['kind'] and h['yaw']==e['yaw'] and h['dyaw']==e['dyaw'],'native heading/kind drift')
  need(type(h['valid'])is bool,'native admission must be explicit')
  need(h['originalEvent']==e and h['physicalAuthority']is False and h['movementApplied']is False,'native source/authority binding')
  need(isinstance(h['queryResult'],dict),'native query provenance')
  if not h['valid']:need(h['a']is None and h['b']is None and isinstance(h['unavailableReason'],str),'invalid height must stay unavailable')
  if h['valid']:
   for k in ('a','b'):
    p=h[k];need(len(p)==3 and all(math.isfinite(v)for v in p),'finite native foot')
    need(p[0]==e[k][0] and p[2]==e[k][2],'native arm changed horizontal route')
 a.output.mkdir(exist_ok=False);began=time.monotonic();count=queries=triangles=payload=0;current_hits=[];catalog={};summary={'status':'started','movementApplied':False,'physicalAuthority':False,'groundExemptions':False,'semanticFloorEstablished':False,'supportEstablished':False,'arrivalEstablished':False,'heightEventsSHA256':height_sha,'sourceMeshHashes':MESH_SHA,'allContactIDsRetained':True,'wholeTriangleHeightsNotContactPoints':True,'lowerTrimArmsMetres':[0,.002],'invalidNativeEventsRetained':True,'nominalBodyMetres':[.45,.30,1.60],'horizontalMarginMetres':.15}
 try:
  up=REPO/'research/coffee-room-journey-recovery-20261029/collision-protocol/upstream'
  for p in [up/'blind-split-candidate-game-03/source',up/'blind-split-candidate-game-03/ground-follow-v2',up/'blind-opus-reference-scoring-audit-02/source',up/'blind-koivu-reference-comparison-06']:sys.path.insert(0,str(p))
  import numpy as np
  import vtk
  from reference_geometry import ReferenceSurface,serial_vtk
  from oriented_container import BodyGeometry,sweep_enclosure
  from oriented_ground_container import GroundedReferenceContainer
  from ground_support import GroundSupport
  summary['runtime']=serial_vtk()
  class RecordingEmptyGround(GroundSupport):
   def is_ground(self,cell_id):
    result=super().is_ground(cell_id);need(not result,'ground exemption forbidden');current_hits.append(int(cell_id));return result
  def emit(stream,row):
   nonlocal payload,count
   b=encoded(row);payload+=len(b);need(payload<=MAX_BYTES,'uncompressed evidence byte budget');stream.write(b);count+=1
  with (a.output/'contacts.jsonl.gz').open('xb')as raw:
   with gzip.GzipFile(filename='',mode='wb',fileobj=raw,mtime=0,compresslevel=1)as out:
    for s in schedules:
     scene=s['scene'];vertices=np.frombuffer((a.mesh_root/(scene+'.vertices.f32')).read_bytes(),dtype='<f4').reshape(-1,3);faces=np.frombuffer((a.mesh_root/(scene+'.indices.u32')).read_bytes(),dtype='<u4').reshape(-1,3)
     need(np.isfinite(vertices).all() and int(faces.max())<len(vertices),'mesh finite/index domain')
     pts=vtk.vtkPoints();pts.SetDataTypeToDouble();cells=vtk.vtkCellArray()
     for p in vertices:pts.InsertNextPoint(*(float(v)for v in p))
     for i,p in enumerate(vertices):need(tuple(float(v)for v in p)==pts.GetPoint(i),'Float32 promotion changed')
     for face in faces:
      cells.InsertNextCell(3)
      for j in face:cells.InsertCellPoint(int(j))
     mesh=vtk.vtkPolyData();mesh.SetPoints(pts);mesh.SetPolys(cells);need(mesh.GetNumberOfCells()==len(faces),'topology changed')
     for i,face in enumerate(faces):need([mesh.GetCell(i).GetPointId(j)for j in range(3)]==[int(v)for v in face],'triangle ordinal changed')
     surface=ReferenceSurface(mesh);identity=np.eye(4);identity.setflags(write=False);empty=np.array([],dtype=np.int64);empty.setflags(write=False)
     ground=RecordingEmptyGround(empty,{'classification':'unknown','groundExemptions':False},surface,mesh,int(mesh.GetMTime()),identity)
     scorers={trim:GroundedReferenceContainer(surface,identity,ground=ground,body=BodyGeometry(width=.45,depth=.30,height=1.60,horizontal_margin=.15,floor_contact_exclusion=trim))for trim in [0,.002]}
     selected=[h for h in heights if h['scene']==scene and h['name']==s['name']];need(len(selected)==len(s['events']),'route height inventory')
     for i,(e,h)in enumerate(zip(s['events'],selected)):
      for arm in ('historical_xyz','native_height'):
       for envelope,pad in [('body',0.),('horizontal_margin',.15)]:
        for trim in (0.,.002):
         need(count<MAX_RECORDS and triangles<=MAX_TRIANGLES and time.monotonic()-began<=170,'VTK bounded worker exhausted')
         rec={'scene':scene,'name':s['name'],'eventIndex':i,'kind':e['kind'],'arm':arm,'envelope':envelope,'lowerTrimMetres':trim,'yaw':e['yaw'],'dyaw':e['dyaw'],'movementApplied':False,'physicalAuthority':False,'support':'unknown','semanticFloor':'unknown','nativeHeightValid':h['valid'],'nativeHeightUnavailableReason':h['unavailableReason'],'nativeHeightQueryEvidenceKey':[scene,s['name'],i]}
         if arm=='native_height' and not h['valid']:
          rec.update(status='unavailable_native_height',queryExecuted=False,contactIDs=None);emit(out,rec);continue
         start=e['a'] if arm=='historical_xyz'else h['a'];end=e['b']if arm=='historical_xyz'else h['b'];rec.update(startFoot=start,endFoot=end,originalStartFoot=e['a'],originalEndFoot=e['b'],startVerticalShiftMetres=start[1]-e['a'][1],endVerticalShiftMetres=end[1]-e['b'][1],verticalShiftCoverage={'start':{'uncoveredLowerBand':[e['a'][1]+trim,start[1]+trim]if start[1]>e['a'][1]else None,'newlyCoveredLowerBand':[start[1]+trim,e['a'][1]+trim]if start[1]<e['a'][1]else None},'end':{'uncoveredLowerBand':[e['b'][1]+trim,end[1]+trim]if end[1]>e['b'][1]else None,'newlyCoveredLowerBand':[end[1]+trim,e['b'][1]+trim]if end[1]<e['b'][1]else None},'endpointBandsOnlyNotContinuousSupport':True})
         current_hits.clear();scorer=scorers[trim];before=scorer.triangle_queries
         corners,sweep=sweep_enclosure(start,end,e['yaw'],e['dyaw'],half_forward=.15+pad,half_lateral=.225+pad,height=1.60,floor_contact_exclusion=trim)
         result=scorer.contact_corners(corners);triangles+=scorer.triangle_queries-before;queries+=1
         need(result['groundContactCount']==0 and len(current_hits)==result['nonGroundContactCount'] and len(set(current_hits))==len(current_hits) and bool(current_hits)==result['contact'],'all-hit no-exemption accounting')
         for cid in current_hits:
          key=scene+':'+str(cid)
          if key not in catalog:
           ids=[int(v)for v in faces[cid]];ys=[float(vertices[j,1])for j in ids];catalog[key]={'scene':scene,'triangleID':cid,'originalVertexIDs':ids,'modelHeightRange':[min(ys),max(ys)],'heightIsWholeTriangleNotContactPoint':True}
         result.update(groundExemptions=False,groundExemption='none; immutable empty set; no triangle suppressed',rawContactCount=len(current_hits),groundClassificationSemantic=False)
         rec.update(status='queried',queryExecuted=True,contactIDs=list(current_hits),nonGroundContactCount=len(current_hits),triangleCandidates=result['candidateTriangles'],sweep=sweep,result=result)
         emit(out,rec);need(triangles<=MAX_TRIANGLES,'triangle budget exhausted')
     for scorer in scorers.values():scorer.check()
     del scorers,ground,surface,mesh,pts,cells,vertices,faces
  need(count==MAX_RECORDS,'incomplete fixed VTK inventory');summary['status']='completed_full_route_diagnostic_only'
 except BaseException as e:summary.update(status='failed',error=type(e).__name__+': '+str(e));raise
 finally:
  try:
   verify();need(sha(a.height_events)==height_sha,'native event bytes changed');summary['inputHashesAfterMatch']=True
  finally:
   catalog_bytes=encoded({'triangles':catalog,'relativeHeightRule':'subtract each record startFoot[1] or endFoot[1] from modelHeightRange; whole triangle, not contact point'})
   need(payload+len(catalog_bytes)<=MAX_BYTES,'total uncompressed evidence budget')
   (a.output/'TRIANGLE_CATALOG.json').write_bytes(catalog_bytes);summary.update(records=count,queries=queries,triangleTests=triangles,uncompressedEvidenceBytes=payload+len(catalog_bytes),wallSeconds=time.monotonic()-began,uniqueContactTriangles=len(catalog),nativeEventProvenance='Every height row, including invalid/clamped status, is retained byte-for-byte in pinned height/events.jsonl; keyed by scene/name/eventIndex')
   (a.output/'SUMMARY.json').write_bytes(encoded(summary))
if __name__=='__main__':main()
