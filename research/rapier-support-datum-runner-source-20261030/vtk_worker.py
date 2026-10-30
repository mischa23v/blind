#!/usr/bin/env python3
"""Prepared only: reuse unchanged VTK swept OBB oracle; never apply movement.
Run only under the separately reviewed published serial aggregate supervisor.
"""
import argparse, hashlib, json, math, os, pathlib, sys, time
H=pathlib.Path(__file__).resolve().parent; REPO=H.parents[1]
DATUM_SHA='d6b7e3f29e5bf0d6aaecde6f7fddf741a03cbfc12299fa17555966f9b88ebbf5'
MESH_SHA={
 'coffee.vertices.f32':'e373a1dba8872e7d9201ba9e35e3f28598fdc660842a28f7867386b1d40fb503',
 'coffee.indices.u32':'a7f7238114579bebe9951f35b2122559540d4076c3186bee767d2e8a2d096767',
 'conference.vertices.f32':'50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb',
 'conference.indices.u32':'2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324'}
SELECT=['conference:table_92_to_120:960','conference:table_120_to_200:2051','conference:table_20_to_92:1057','conference:varpu_160_to_130:966','coffee:0_to_8:630','coffee:0_to_8:1643']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--mesh-root',type=pathlib.Path,required=True);ap.add_argument('--datums',type=pathlib.Path,required=True);ap.add_argument('--output',type=pathlib.Path,required=True);ap.add_argument('--probes',type=pathlib.Path,required=True);a=ap.parse_args()
 for key in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS']:
  if os.environ.get(key)!='1':raise ValueError('Serial environment required')
 sys.dont_write_bytecode=True
 def verify():
  if sha(a.datums)!=DATUM_SHA:raise ValueError('Candidate datum identity changed')
  for n,h in MESH_SHA.items():
   if sha(a.mesh_root/n)!=h:raise ValueError('Unchanged mesh identity failed: '+n)
 verify();probes_sha=sha(a.probes);entries=json.loads(a.probes.read_text());frozen={x['probe']['id']:x for x in entries};
 if len(entries)!=24 or len(frozen)!=24:raise ValueError('Fixed 24 probe entries required')
 d=json.loads(a.datums.read_text());rows=d['results']
 if [r['originalProbe']['id']for r in rows]!=SELECT or len(rows)!=6:raise ValueError('Fixed six pose order changed')
 if any(d[k]for k in ['physicalAuthority','nativeEngineExecuted','movementApplied','originalMeshesModified']):raise ValueError('Candidate authority changed')
 a.output.mkdir(exist_ok=False);began=time.monotonic();count=0;triangles=0;payload=0;current_hits=[];summary={'schema':1,'status':'started','queries':0,'movementApplied':False,'physicalAuthority':False,'groundExemptions':False,'semanticFloorEstablished':False,'supportEstablished':False,'arrivalEstablished':False,'candidateDatumSHA256':DATUM_SHA,'sourceMeshHashes':MESH_SHA,'geometryFrame':'exact original prepared Float32 buffers promoted to Double; no new transform','allContactIDsRetained':True,'wholeTriangleHeightsNotContactPoints':True,'lowerTrimArmsMetres':[0,.002]}
 try:
  up=REPO/'research/coffee-room-journey-recovery-20261029/collision-protocol/upstream'
  for q in [up/'blind-split-candidate-game-03/source',up/'blind-split-candidate-game-03/ground-follow-v2',up/'blind-opus-reference-scoring-audit-02/source',up/'blind-koivu-reference-comparison-06']:sys.path.insert(0,str(q))
  import numpy as np
  import vtk
  from reference_geometry import ReferenceSurface,serial_vtk
  from oriented_container import BodyGeometry,sweep_enclosure
  from oriented_ground_container import GroundedReferenceContainer
  from ground_support import GroundSupport
  summary['runtime']=serial_vtk()
  # Observation hook only: unchanged all-hit oracle invokes is_ground AFTER
  # its unchanged VTK intersection/containment test. Always delegate to empty
  # component, assert False, retain ID; never change acceptance/intersections.
  class RecordingEmptyGround(GroundSupport):
   def is_ground(self,cell_id):
    result=super().is_ground(cell_id)
    if result:raise RuntimeError('Ground exemption forbidden')
    current_hits.append(int(cell_id));return result
  with (a.output/'rows.jsonl').open('x') as out:
   for scene in ['conference','coffee']:
    vertices=np.frombuffer((a.mesh_root/(scene+'.vertices.f32')).read_bytes(),dtype='<f4').reshape(-1,3)
    faces=np.frombuffer((a.mesh_root/(scene+'.indices.u32')).read_bytes(),dtype='<u4').reshape(-1,3)
    if not np.isfinite(vertices).all() or int(faces.max())>=len(vertices):raise ValueError('Invalid fixed mesh')
    pts=vtk.vtkPoints();pts.SetDataTypeToDouble();cells=vtk.vtkCellArray()
    for p in vertices:pts.InsertNextPoint(*(float(v)for v in p))
    for i,p in enumerate(vertices):
     if tuple(float(v)for v in p)!=pts.GetPoint(i):raise ValueError('Point conversion changed')
    for f in faces:
     cells.InsertNextCell(3)
     for j in f:cells.InsertCellPoint(int(j))
    mesh=vtk.vtkPolyData();mesh.SetPoints(pts);mesh.SetPolys(cells)
    if mesh.GetNumberOfCells()!=len(faces):raise ValueError('Topology changed')
    for i,f in enumerate(faces):
     cell=mesh.GetCell(i)
     if [cell.GetPointId(j)for j in range(3)]!=[int(v)for v in f]:raise ValueError('Triangle ordinal changed')
    surface=ReferenceSurface(mesh);identity=np.eye(4);identity.setflags(write=False);empty=np.array([],dtype=np.int64);empty.setflags(write=False)
    ground=RecordingEmptyGround(empty,{'classification':'unknown','groundExemptions':False},surface,mesh,int(mesh.GetMTime()),identity)
    scorers={trim:GroundedReferenceContainer(surface,identity,ground=ground,body=BodyGeometry(width=.45,depth=.30,height=1.60,horizontal_margin=.15,floor_contact_exclusion=trim))for trim in [0,.002]}
    for r in [r for r in rows if r['scene']==scene]:
     p=r['originalProbe'];yaw=p['yawRadians']
     if p['kind']=='turn' or not math.isfinite(yaw):raise ValueError('No turn allowed')
     for datum_arm in ['original','candidate']:
      start=p['foot'] if datum_arm=='original' else r['candidateFoot']
      if start is None:raise ValueError('Frozen materialized candidates must all exist; never substitute')
      if len(start)!=3 or not all(math.isfinite(v)for v in start) or start[0::2]!=p['foot'][0::2]:raise ValueError('Invalid fixed candidate')
      for input_arm in ['zero','original_xyz']:
       delta=[0,0,0]if input_arm=='zero'else p['desiredDelta'];end=[x+y for x,y in zip(start,delta)]
       if math.sqrt(sum(v*v for v in delta))>.025+1e-12:raise ValueError('Original delta bound')
       probe_id=p['id']+'|'+datum_arm+'|'+input_arm;fp=frozen[probe_id]
       if fp['scene']!=scene or fp['probe']['foot']!=start or fp['probe']['desiredDelta']!=delta or fp['probe']['yawRadians']!=yaw:raise ValueError('KCC/VTK frozen pose binding differs')
       for envelope,pad in [('body',0.),('horizontal_margin',.15)]:
        for trim in [0,.002]:
         if count>=96 or triangles>2000000 or time.monotonic()-began>170:raise RuntimeError('VTK bounded worker exhausted')
         current_hits.clear();scorer=scorers[trim];before=scorer.triangle_queries
         corners,sweep=sweep_enclosure(start,end,yaw,0.,half_forward=.15+pad,half_lateral=.225+pad,height=1.60,floor_contact_exclusion=trim)
         result=scorer.contact_corners(corners);triangles+=scorer.triangle_queries-before
         if result['groundContactCount']!=0 or len(current_hits)!=result['nonGroundContactCount']or len(set(current_hits))!=len(current_hits):raise RuntimeError('Complete no-exemption hit inventory failed')
         if bool(current_hits)!=result['contact']:raise RuntimeError('Contact result mismatch')
         contacts=[]
         for cid in current_hits:
          ids=[int(x)for x in faces[cid]];t=[[float(v)for v in vertices[j]]for j in ids];ys=[v[1]for v in t]
          contacts.append({'triangleID':cid,'originalVertexIDs':ids,'modelHeightRange':[min(ys),max(ys)],'relativeToStartFootHeightRange':[min(ys)-start[1],max(ys)-start[1]],'relativeToEndFootHeightRange':[min(ys)-end[1],max(ys)-end[1]],'heightIsWholeTriangleNotContactPoint':True})
         result.update(groundExemptions=False,groundExemption='none; empty set; no triangle suppressed',rawContactCount=len(contacts),groundClassificationSemantic=False)
         rec={'probeId':probe_id,'scene':scene,'sourceId':p['id'],'datumArm':datum_arm,'inputArm':input_arm,'envelope':envelope,'lowerTrimMetres':trim,'startFoot':start,'endFoot':end,'requestedDelta':delta,'yawRadians':yaw,'sweep':sweep,'result':result,'contacts':contacts,'movementApplied':False,'physicalAuthority':False,'support':'unknown','semanticFloor':'unknown'}
         line=json.dumps(rec,separators=(',',':'),allow_nan=False)+'\n';payload+=len(line.encode())
         if payload>10*1024**2 or triangles>2000000:raise RuntimeError('VTK evidence budget exhausted')
         out.write(line);out.flush();count+=1
    for scorer in scorers.values():scorer.check()
   if count!=96:raise RuntimeError('Incomplete fixed VTK inventory')
   summary['status']='completed_no_exemption_fixed_pose_contacts'
 except BaseException as e:
  summary['status']='failed';summary['error']=type(e).__name__+': '+str(e);raise
 finally:
  try:
   verify()
   if sha(a.probes)!=probes_sha:raise ValueError('Frozen KCC/VTK probes changed')
   summary['inputHashesAfterMatch']=True;summary['frozenProbeSHA256']=probes_sha
  except BaseException as e:summary['status']='failed';summary['postPinError']=str(e);raise
  finally:
   summary.update(queries=count,triangleTests=triangles,outputPayloadBytes=payload,wallSeconds=time.monotonic()-began)
   (a.output/'SUMMARY.json').write_text(json.dumps(summary,indent=2,allow_nan=False)+'\n')
if __name__=='__main__':main()
