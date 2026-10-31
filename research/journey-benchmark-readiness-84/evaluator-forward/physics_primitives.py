"""Verbatim published primitives only; explicit imports replace historical glue."""
from pathlib import Path
import hashlib,json,math,os,selectors,subprocess,sys,time
import numpy as np
import vtk
from vtk.util.numpy_support import vtk_to_numpy
from impairments import ActorFIFO,ActorProfile,ActorCommand
from reference_geometry import ReferenceSurface,GeometryFailure,serial_vtk,checked_similarity
from oriented_ground_tiled_container import GroundTiledReferenceContainer
REFERENCE=Path(__file__).resolve().parent/'inputs'
def log(**row):print(json.dumps(row,allow_nan=False),flush=True)
def sha(p):
    h=hashlib.sha256()
    with Path(p).open('rb')as f:
        while b:=f.read(1024**2):h.update(b)
    return h.hexdigest()

class ControllerProcess:
    def __init__(self,out):
        raise RuntimeError('Base transport cannot be initialized; use pair-bound stage76 ControllerProcess')
    def ask(self,row):
        self.p.stdin.write(json.dumps(row,allow_nan=False)+'\n');self.p.stdin.flush()
        if not self.selector.select(15):raise RuntimeError('controller timeout')
        line=self.p.stdout.readline()
        if not line:raise RuntimeError('controller terminated')
        result=json.loads(line)
        if result.get('physicalAuthority')is not False:raise RuntimeError('physical authority boundary')
        return result
    def close(self):
        if not self.p.stdin.closed:self.p.stdin.close()
        try:self.p.wait(timeout=3)
        except subprocess.TimeoutExpired:self.p.kill();self.p.wait()
        self.selector.close();self.p.stdout.close();self.err.close()

def support_check(row,foot=None):
    heights=[p['modelHeightY']for p in row['probes']if p['hit']]
    span=max(heights)-min(heights)if heights else None
    error=max(abs(v-(0 if foot is None else foot))for v in heights)if heights else None
    accepted=len(heights)==9 and span<=.02 and error<=(.03 if foot is None else .02)
    return {'acceptedFiniteSupportModel':bool(accepted),'hitCount':len(heights),'missingCount':9-len(heights),'spreadMetres':span,'maximumAnchorErrorMetres':error,'heightMinimum':min(heights)if heights else None,'heightMaximum':max(heights)if heights else None,'continuousSupportProven':False,'semanticFloorEstablished':False}

def contact_status(contacts):
    actual=contacts['actualBody'];margin=contacts['horizontalMargin']
    hit=actual if actual['contact']else margin
    if not hit['contact']:return None
    near=max(hit['firstTriangleHeightRelativeToStartFootRange'])<=.03
    if near:return 'firstContactTriangleNearFootAmbiguous'
    return 'referenceActualBodyContact'if actual['contact']else'referenceMarginContact'
def connected_support(row,ground,previous_y):
    result=support_check(row,previous_y)
    not_ground=[int(p['referenceCellID']) for p in row['probes']
                if p['hit'] and not ground.is_ground(int(p['referenceCellID']))]
    result.update(groundComponentConfirmedForAllProbes=not not_ground and result['hitCount']==9,
                  nonGroundProbeCellIDs=not_ground,
                  supportPolicy='nine first-hit probes on initially seeded shared-edge fixed-plane component')
    result['acceptedFiniteSupportModel']=bool(result['acceptedFiniteSupportModel'] and not not_ground)
    return result
def transform(a,registration):
    # Helper +Y-up frame [levelX,height,-levelY]; level R/t has height zero at
    # the fitted plane, before OctoMap's +.025 grid-centre offset.
    B=np.array([[1.,0,0],[0,0,-1],[0,1,0]])
    model_to_phone=np.eye(4);model_to_phone[:3,:3]=a['R'].T@B;model_to_phone[:3,3]=-a['R'].T@a['t']
    value=registration@model_to_phone
    checked_similarity(value)
    return value

def load_surface():
    log(phase='full_reference_load_start')
    reader=vtk.vtkPLYReader();errors=[];reader.AddObserver('ErrorEvent',lambda *_:errors.append('VTK PLY ErrorEvent'));reader.SetFileName(str(REFERENCE/'gt_mesh.ply'));reader.Update()
    if errors:raise GeometryFailure(';'.join(errors))
    mesh=reader.GetOutput()
    if mesh.GetNumberOfPoints()!=8940320 or mesh.GetNumberOfPolys()!=17801112 or mesh.GetNumberOfCells()!=17801112:raise GeometryFailure('original topology changed')
    coordinates=vtk_to_numpy(mesh.GetPoints().GetData())
    for start in range(0,len(coordinates),262144):
        if not np.isfinite(coordinates[start:start+262144]).all():raise GeometryFailure('nonfinite VTK vertex')
    offsets=vtk_to_numpy(mesh.GetPolys().GetOffsetsArray());connectivity=vtk_to_numpy(mesh.GetPolys().GetConnectivityArray())
    if len(offsets)!=17801113 or offsets[0]!=0 or offsets[-1]!=len(connectivity):raise GeometryFailure('invalid topology offsets')
    for start in range(0,len(offsets)-1,262144):
        if not np.all(np.diff(offsets[start:min(start+262145,len(offsets))])==3):raise GeometryFailure('nontriangle')
    for start in range(0,len(connectivity),262144):
        chunk=connectivity[start:start+262144]
        if np.any(chunk<0)or np.any(chunk>=8940320):raise GeometryFailure('invalid vertex index')
    del coordinates,offsets,connectivity,chunk
    info={'vertices':mesh.GetNumberOfPoints(),'triangles':mesh.GetNumberOfCells(),'originalPLYType':'float64','VTKPointScalarType':mesh.GetPoints().GetData().GetDataTypeAsString(),'geometryDecimated':False,'meshTransformed':False,'unusedAttributesReleased':True}
    mesh.GetPointData().Initialize();mesh.GetCellData().Initialize()
    surface=ReferenceSurface(mesh,progress=lambda row:log(**row))
    return surface,info,reader
