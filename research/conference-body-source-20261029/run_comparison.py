#!/usr/bin/env python3
"""Prepared raw-only VTK all-hit comparison. Run ONLY under admitted aggregate guard.

Uses unchanged conservative sweep/all-hit kernels. No planner call, support probe,
ground-label construction, ground-following, contact avoidance or arrival claim.
"""
import argparse, gzip, hashlib, json, math, os, pathlib, sys, time
from contracts import (PROPOSAL_SHA,MESH_SHA,VERTEX_SHA,TRIANGLE_SHA,
                       encoded,select_routes,check_schedule,validate_receipt)
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
MAX_BOXES=55000;MAX_TRIANGLES=30000000;MAX_LOGICAL=64*1024**2

def sha(p):
    with pathlib.Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--pins',type=pathlib.Path,required=True)
    ap.add_argument('--pins-sha256',required=True);a=ap.parse_args()
    if sha(a.pins)!=a.pins_sha256:raise ValueError('admitted manifest SHA mismatch')
    pins=json.loads(a.pins.read_text())
    def expand(s):
        s=s.replace('@WORKSPACE@',str(W)).replace('@REPO@',str(R))
        return pathlib.Path(s) if s.startswith('/') else R/s
    def verify():
        if sha(a.pins)!=a.pins_sha256:raise ValueError('manifest changed')
        for name,digest in pins['inputs'].items():
            if sha(expand(name))!=digest:raise ValueError('input changed: '+name)
    verify()
    proposal=expand(pins['proposalPath']);meshpath=expand(pins['meshPath'])
    if sha(proposal)!=PROPOSAL_SHA or sha(meshpath)!=MESH_SHA:raise ValueError('wrong actual proposal/source')
    frozen=json.loads((H/'ROUTES.json').read_text())
    if select_routes(json.loads(proposal.read_text()))!=frozen:raise ValueError('frozen chain selection changed')
    out=expand(pins['comparisonDirectory']);out.mkdir(exist_ok=False)
    for key in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS'):os.environ[key]='1'
    sys.dont_write_bytecode=True
    up=R/'research/coffee-room-journey-recovery-20261029/collision-protocol/upstream'
    for path in (up/'blind-split-candidate-game-03/source',
                 up/'blind-split-candidate-game-03/ground-follow-v2',
                 up/'blind-opus-reference-scoring-audit-02/source',
                 up/'blind-koivu-reference-comparison-06'):sys.path.insert(0,str(path))
    import numpy as np
    import vtk
    from reference_geometry import ReferenceSurface,serial_vtk
    from oriented_container import BodyGeometry
    from oriented_ground_container import GroundedReferenceContainer
    from ground_support import GroundSupport
    runtime=serial_vtk();began=time.monotonic();logical=0;scorer=None
    model={'status':'started','error':None,'proposalSHA256':PROPOSAL_SHA,'sourceMeshSHA256':MESH_SHA,
           'registeredFloat32VerticesSHA256':None,'trianglesInt32SHA256':None,
           'bodyWidthDepthHeightMetres':[.45,.30,1.60],'horizontalMarginMetres':.15,
           'floorContactExclusionMetres':.002,'groundExemptedFaceCount':0,
           'registrationAuthority':'historicalEstimatedComparatorOnlyNotOfficialCameraMeshCalibration',
           'validatedCameraMeshAlignment':False,'physicalAuthority':False,
           'continuousSupportProven':False,'semanticFloorEstablished':False,
           'coverageEstablished':False,'movementEpisode':False,'arrivalClaimed':False,
           'cameraAnchorsNotBodyPose':True,'authoredYawNotMeasuredBodyHeading':True,
           'sourceTopologyPreserved':True,'rawFloorContactsAboveExclusionRetained':True,'lower2mmTrimRetained':True,
           'runtime':runtime,'pinsSHA256':a.pins_sha256,'paths':[],
           'limitations':['Continuous conservative OBB enclosures may overcount actual contact.',
             'First witness is locator order, not earliest contact, and does not describe all hit heights.',
             'Witness ranges are whole-triangle heights, never intersection-point heights.',
             'Near-foot witness band is a reporting label only, never ground/semantic classification.',
             'The inherited 2 mm lower-body exclusion can omit floor and tiny-object contacts; absence is not clearance.',
             'No support, closed-solid containment, measured coverage, camera/body alignment or arrival established.',
             'Missing surfaces cannot be recovered by same-mesh contact scoring.',
             'Observed RSS polling is not a hard memory limit; runtime metadata pins are not hermetic.']}
    for row in frozen['paths']:
        model['paths'].append({'name':row['name'],'status':'notAttempted','scheduledEvents':row['eventCount'],
          'completedEvents':0,'scheduleSHA256':row.get('scheduleSHA256'),
          'contactEvents':{'actualBody':0,'horizontalMargin':0},
          'firstWitnessNearFootBandEvents':{'actualBody':0,'horizontalMargin':0},
          'firstContactByEnvelope':{},'arrivalClaimed':False})
    def counters():
        return {'boxes':0 if scorer is None else scorer.box_queries,
                'triangles':0 if scorer is None else scorer.triangle_queries,
                'rays':0 if scorer is None else scorer.floor_ray_queries}
    def check_budget():
        c=counters()
        if c['boxes']>MAX_BOXES or c['triangles']>MAX_TRIANGLES or time.monotonic()-began>170:
            raise RuntimeError('worker budget exhausted; all pending events remain incomplete')
    def save():
        model.update(counters=counters(),wallSeconds=time.monotonic()-began,outputLogicalBytes=logical)
        data=json.dumps(model,indent=2,allow_nan=False)+'\n'
        if len(data.encode())>262144:raise RuntimeError('receipt size cap')
        (out/'RECEIPT.json').write_text(data)
    save()
    try:
        # Same OBJ parse and exact transform arithmetic as admitted scene adapter.
        original=[];faces=[]
        for line in meshpath.open():
            q=line.split()
            if not q:continue
            if q[0]=='v':
                if len(q)!=4:raise ValueError('unsupported vertex')
                p=[float(v) for v in q[1:]]
                if not all(math.isfinite(v) for v in p):raise ValueError('nonfinite source')
                original.append(p)
            elif q[0]=='f':
                if len(q)!=4:raise ValueError('nontriangle source')
                faces.append([int(v.split('/')[0])-1 for v in q[1:]])
        if (len(original),len(faces))!=(18398,29366) or min(min(f) for f in faces)<0 or max(max(f) for f in faces)>=18398:
            raise ValueError('original source cardinality/index mismatch')
        registration=json.loads(expand(pins['registrationPath']).read_text())
        if registration['scale']!=1 or not registration['acceptedForComparator'] or registration['referenceUsed']:
            raise ValueError('historical registration contract changed')
        obj=np.asarray(original,dtype=np.float64);tri=np.asarray(faces,dtype=np.int32)
        Q=np.asarray(registration['rotationOBJToLevel'],dtype=np.float64)
        translation=np.asarray(registration['translationOBJToLevel'],dtype=np.float64)
        if not np.allclose(Q@Q.T,np.eye(3),atol=1e-12,rtol=0) or abs(float(np.linalg.det(Q))-1)>1e-12:
            raise ValueError('registration is not proper rigid transform')
        level=obj@Q.T+translation;vertices=np.c_[level[:,0],level[:,2],-level[:,1]]
        registered=np.ascontiguousarray(vertices,dtype='<f4');tri=np.ascontiguousarray(tri,dtype='<i4')
        vh=hashlib.sha256(registered.tobytes()).hexdigest();th=hashlib.sha256(tri.tobytes()).hexdigest()
        if vh!=VERTEX_SHA or th!=TRIANGLE_SHA:raise ValueError('executed scene adapter byte receipt mismatch')
        model.update(registeredFloat32VerticesSHA256=vh,trianglesInt32SHA256=th,
                     vtkCoordinates='exact executed adapter float32 values promoted to float64; no additional transform')
        # Explicit original IDs, no OBJ reader welding, decimation, deletion or fill.
        points=vtk.vtkPoints();points.SetDataTypeToDouble();cells=vtk.vtkCellArray()
        for p in registered:points.InsertNextPoint(*p)
        for i,p in enumerate(registered):
            if tuple(float(v) for v in p)!=points.GetPoint(i):raise ValueError('registered point roundtrip changed')
        for f in faces:
            cells.InsertNextCell(3)
            for i in f:cells.InsertCellPoint(i)
        mesh=vtk.vtkPolyData();mesh.SetPoints(points);mesh.SetPolys(cells)
        if mesh.GetNumberOfCells()!=29366:raise ValueError('source topology changed')
        for i,f in enumerate(faces):
            cell=mesh.GetCell(i)
            if [cell.GetPointId(j) for j in range(3)]!=f:raise ValueError('original face mapping changed')
        surface=ReferenceSurface(mesh);identity=np.eye(4);identity.setflags(write=False)
        ids=np.array([],dtype=np.int64);ids.setflags(write=False)
        empty=GroundSupport(ids,{'classification':'unknown','seedComponentComputed':False},
                            surface,mesh,int(mesh.GetMTime()),identity)
        # Preserve the original Coffee lower-body exclusion exactly. No triangle
        # is ground-exempted; the explicit lower 2 mm query-band trim remains.
        scorer=GroundedReferenceContainer(surface,identity,ground=empty,
          body=BodyGeometry(width=.45,depth=.30,height=1.60,horizontal_margin=.15,floor_contact_exclusion=.002))
        with gzip.open(out/'CONTACTS.jsonl.gz','xt',encoding='utf8') as log:
            for row,summary in zip(frozen['paths'],model['paths']):
                if row['status']=='unavailable':summary['status']='unavailable';save();continue
                schedule=check_schedule(row);summary['status']='running';save()
                for n,event in enumerate(schedule['events']):
                    check_budget()
                    result=scorer.swept_contacts(event['a'],event['b'],event['yaw'],event['dyaw'])
                    check_budget()
                    for kind in ('actualBody','horizontalMargin'):
                        r=result[kind]
                        if r['groundContactCount']!=0:raise ValueError('raw-only ground exclusion violated')
                        r['rawContactCount']=r['nonGroundContactCount']
                        r['groundClassificationSemantic']=False
                        if r['contact']:
                            summary['contactEvents'][kind]+=1
                            height=r['firstTriangleModelHeightRange']
                            relative=[v-event['a'][1] for v in height]
                            r['firstWitnessWholeTriangleHeightRelativeToEndFootRange']=[v-event['b'][1] for v in height]
                            r['firstWitnessWithin25mmOfStartFootPlane']=all(abs(v)<=.025 for v in relative)
                            r['firstWitnessNearFootLabelDoesNotExemptContact']=True
                            if r['firstWitnessWithin25mmOfStartFootPlane']:summary['firstWitnessNearFootBandEvents'][kind]+=1
                            if kind not in summary['firstContactByEnvelope']:
                                summary['firstContactByEnvelope'][kind]={'event':n,'kind':event['kind'],
                                  'referenceCellID':r['firstReferenceCellID'],'wholeTriangleRegisteredHeightRange':height,
                                  'wholeTriangleRelativeToStartFootRange':relative,
                                  'nearFoot25mmReportingBand':r['firstWitnessWithin25mmOfStartFootPlane']}
                    record={'path':row['name'],'event':n,'authoredIncrement':event,'contacts':result}
                    data=encoded(record);logical+=len(data)
                    if logical>MAX_LOGICAL:raise RuntimeError('logical output cap; incomplete')
                    log.write(data.decode());log.flush()
                    summary['completedEvents']=n+1
                    if n%128==0:save()
                summary['status']='rawDiagnosticComplete';save()
                print(json.dumps({'path':row['name'],'status':summary['status'],
                                  'events':summary['completedEvents'],'contactEvents':summary['contactEvents']}),flush=True)
        model['status']='rawDiagnosticCompleted';save();validate_receipt(model,frozen)
    except BaseException as exc:
        model.update(status='incompleteUnknown',error=type(exc).__name__+': '+str(exc));save();raise
    finally:
        verify();save()
    print(json.dumps({'status':model['status'],'counters':counters()}),flush=True)

if __name__=='__main__':main()
