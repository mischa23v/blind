"""Frozen evaluator-only matching-height/triangle audit; no planner mutation."""
from pathlib import Path
import gc, hashlib, json, sys, time
import numpy as np
import vtk
from vtk.util.numpy_support import vtk_to_numpy
from label_contract import load_verified, masks_from_phone, select_columns
from reference_band_box import ReferenceBandBox
from reference_geometry import ReferenceSurface, GeometryFailure, serial_vtk, checked_similarity

ROOT=Path(__file__).resolve().parents[1]; WS=ROOT.parent
REFERENCE=WS/'blind-koivu-faro-acquisition-04/selected-reference'
ARTIFACT=ROOT/'artifacts/koivu_v1_pipeline_out.npz'
ARTIFACT_SHA='dfd9a7afa958fc8012e43b9fe86f72dafb97e88d4198640080c110c14941b55e'
BANDS=((.010,.015),(.015,.025),(.025,.075),(.075,.300),(.300,1.750),(1.750,1.800))
BAND_NAMES=('10to15mm','15to25mm','25to75mm','75to300mm','300to1750mm','1750to1800mm')
def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb')as f:
        while b:=f.read(1024**2):h.update(b)
    return h.hexdigest()
def dump(path,value):Path(path).write_text(json.dumps(value,indent=2,allow_nan=False)+'\n')
def log(**row):print(json.dumps(row,allow_nan=False),flush=True)
def verify(expected):
    if sha(ROOT/'FROZEN.json')!=expected:raise ValueError('frozen manifest changed')
    pins=json.loads((ROOT/'FROZEN.json').read_text())
    for path,digest in pins['files'].items():
        if sha(WS/path)!=digest:raise ValueError('pinned input/source changed: '+path)
    return pins

def transform(a,registration):
    # Helper +Y-up frame [levelX,height,-levelY]; level R/t has height zero at
    # the fitted plane, before OctoMap's +.025 grid-centre offset.
    B=np.array([[1.,0,0],[0,0,-1],[0,1,0]])
    model_to_phone=np.eye(4);model_to_phone[:3,:3]=a['R'].T@B;model_to_phone[:3,3]=-a['R'].T@a['t']
    value=registration@model_to_phone
    checked_similarity(value)
    return value

def vertices(a,registration,out):
    path=REFERENCE/'gt_mesh.ply'
    with path.open('rb')as f:
        header=b''
        while not header.endswith(b'end_header\n'):
            line=f.readline()
            if not line or len(header)+len(line)>65536:raise ValueError('bounded PLY header')
            header+=line
    lines=header.decode('ascii').splitlines()
    required=['format binary_little_endian 1.0','element vertex 8940320','element face 17801112']
    if any(x not in lines for x in required):raise ValueError('wrong reference structure')
    begin=lines.index('element vertex 8940320');end=lines.index('element face 17801112')
    if lines[begin+1:end]!=['property double '+k for k in ('x','y','z','nx','ny','nz')]:raise ValueError('unexpected vertex schema')
    raw=np.memmap(path,mode='r',dtype='<f8',offset=len(header),shape=(8940320,6))
    shape=a['walk'].shape;total=int(np.prod(shape));inverse=np.linalg.inv(registration)
    n=np.zeros(total,np.int64);band_counts=np.zeros((6,total),np.int64);float32_error=0.
    lowmax=np.full(total,-np.inf);bodymax=np.full(total,-np.inf)
    floor_n=np.zeros(total,np.int64);floor_sum=np.zeros(total)
    for start in range(0,len(raw),262144):
        p=np.asarray(raw[start:start+262144,:3])
        if not np.isfinite(p).all():raise GeometryFailure('nonfinite original vertex')
        float32_error=max(float32_error,float(np.max(np.abs(p.astype(np.float32).astype(np.float64)-p))))
        # Mirror the original scorer's floating-point +half-cell then -half-cell
        # round-trip even though the exact mathematical height is unchanged.
        p=(p@inverse[:3,:3].T+inverse[:3,3])@a['R'].T+a['t']+[0,0,.025]
        ij=np.floor(p[:,:2]/.05).astype(np.int64)-a['lo'][:2]
        inside=np.all((ij>=0)&(ij<shape),axis=1)
        ij=ij[inside];h=p[inside,2]-.025;col=ij[:,0]*shape[1]+ij[:,1]
        n+=np.bincount(col,minlength=total)
        for i,(low,high)in enumerate(BANDS):
            keep=(h>=low)&(h<high);band_counts[i]+=np.bincount(col[keep],minlength=total)
        for low,high,array in ((.015,.30,lowmax),(.30,1.80,bodymax)):
            keep=(h>=low)&(h<high);np.maximum.at(array,col[keep],h[keep])
        keep=(h>-.06)&(h<.06)
        floor_n+=np.bincount(col[keep],minlength=total);floor_sum+=np.bincount(col[keep],weights=h[keep],minlength=total)
        if start%1048576==0:log(phase='original_vertex_stream',verticesCompleted=min(start+262144,len(raw)))
    del raw,p,ij,h,col;gc.collect()
    floor_h=np.full(total,np.nan);np.divide(floor_sum,floor_n,out=floor_h,where=floor_n>0)
    values={'anyVertexCount':n.reshape(shape),'bandVertexCounts':band_counts.reshape((6,)+shape),'floorBandVertexCount':floor_n.reshape(shape),'floorBandMeanHeight':floor_h.reshape(shape),'originalLowMax':lowmax.reshape(shape),'originalBodyMax':bodymax.reshape(shape),'maximumOriginalCoordinateFloat32RoundingMetres':np.array(float32_error)}
    with np.load(ARTIFACT,allow_pickle=False)as saved:
        if not np.array_equal(values['anyVertexCount'],saved['ref_n']):raise GeometryFailure('original reference coverage recount disagrees with saved artifact')
        for new,old in [('originalLowMax','ref_low_max'),('originalBodyMax','ref_body_max'),('floorBandMeanHeight','ref_floor_h')]:
            if not np.allclose(values[new],saved[old],atol=1e-12,rtol=0,equal_nan=True):raise GeometryFailure('original reference heights disagree with saved artifact: '+old)
    np.savez_compressed(out/'REFERENCE_VERTEX_BANDS.npz',**values)
    return values

def summarize_vertices(masks,values):
    n=values['anyVertexCount'];bands=values['bandVertexCounts']>0;floor=values['floorBandVertexCount']>0
    out={}
    for name,mask in masks.items():
        covered=mask&(n>0)
        out[name]={'phoneColumns':int(mask.sum()),'originalAnyVertexCovered':int(covered.sum()),'noReferenceVertices':int((mask&(n==0)).sum()),'anyVertexButNoFloorBandVertices':int((covered&~floor).sum()),'bandPositiveColumns':{k:int((mask&bands[i]).sum())for i,k in enumerate(BAND_NAMES)},'any10to1800mmVertexColumns':int((mask&bands.any(0)).sum()),'any10to75mmVertexColumns':int((mask&bands[:3].any(0)).sum()),'noVertexIsNotFree':True,'measuredCoverageAvailable':False}
    return out

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

def run(expected):
    started=time.monotonic();verify(expected);runtime=serial_vtk();out=ROOT/'run-01/result';out.mkdir(exist_ok=False)
    if runtime['version']!='9.3.1':raise ValueError('pinned installed VTK version changed')
    receipt=json.loads((ROOT/'artifacts/koivu_v1_PIPELINE_RECEIPT.json').read_text())
    a=load_verified(ARTIFACT,ARTIFACT_SHA,receipt);masks=masks_from_phone(a);chosen,selection=select_columns(a)
    with np.load(ROOT/'SELECTED_COLUMNS.npz',allow_pickle=False)as stored:
        if not np.array_equal(chosen,stored['columns'])or not np.array_equal(a['lo'],stored['minimumKey']):raise ValueError('preselected columns changed')
    A=np.asarray(json.loads((REFERENCE/'icp_iphone.json').read_text())['gt_transformation']);A,registration=checked_similarity(A)
    model_to_reference=transform(a,A)
    values=vertices(a,A,out);vertex_summary=summarize_vertices(masks,values)
    dump(out/'VERTEX_SUMMARY.json',{'scope':'Original Float64 vertices in exact saved label frame; positive geometry only','originalSavedReferenceColumnsMatched':True,'bandsHalfOpenMetres':BANDS,'sets':vertex_summary})
    log(phase='matching_height_vertex_complete',sets=vertex_summary)
    surface,mesh_info,reader=load_surface();evaluator=ReferenceBandBox(surface,model_to_reference)
    contacts=np.zeros((len(chosen),6),bool);probe_hits=np.zeros(len(chosen),np.uint8);probe_heights=np.full((len(chosen),5),np.nan)
    with (out/'TRIANGLE_COLUMN_ROWS.jsonl').open('x')as stream:
        for row,(i,j)in enumerate(chosen):
            x=(int(i)+int(a['lo'][0]))*.05;y=(int(j)+int(a['lo'][1]))*.05
            checks=[]
            for k,(lower,upper)in enumerate(BANDS):
                check=evaluator.contact([x,lower,-y-.05],[x+.05,upper,-y]);contacts[row,k]=check['contact'];checks.append(check)
            probes=evaluator.floor_probes([x,-y-.05],[x+.05,-y],ray_top=.15,ray_bottom=-.25)
            probe_hits[row]=probes['hitCount']
            for k,p in enumerate(probes['probes']):
                if p['hit']:probe_heights[row,k]=p['modelHeightY']
            stream.write(json.dumps({'column':[int(i),int(j)],'bandChecks':checks,'floorProbes':probes},allow_nan=False)+'\n');stream.flush()
            if row%50==0:log(phase='triangle_columns',completed=row+1,total=len(chosen),triangleQueries=evaluator.triangle_queries)
    np.savez_compressed(out/'TRIANGLE_BANDS.npz',columns=chosen,contacts=contacts,floorProbeHits=probe_hits,floorProbeHeights=probe_heights)
    triangle_summary={}
    vertex_hits=values['bandVertexCounts'][:,chosen[:,0],chosen[:,1]].T>0
    for name,mask in masks.items():
        selected=mask[chosen[:,0],chosen[:,1]];count=int(selected.sum())
        triangle_summary[name]={'sampledColumns':count,'populationColumns':int(mask.sum()),'allPopulationColumnsIncluded':count==int(mask.sum()),'bandContactColumns':{key:int((selected&contacts[:,k]).sum())for k,key in enumerate(BAND_NAMES)},'anyBandContactColumns':int((selected&contacts.any(1)).sum()),'triangleContactWithoutVertexInSameHalfOpenBand':{key:int((selected&contacts[:,k]&~vertex_hits[:,k]).sum())for k,key in enumerate(BAND_NAMES)},'columnsWithAnyMissingFloorProbe':int((selected&(probe_hits<5)).sum()),'columnsWithAllFiveHits':int((selected&(probe_hits==5)).sum()),'allFiveHitsIsNotVerifiedSupport':True}
        heights=probe_heights[selected];heights=heights[np.isfinite(heights)]
        triangle_summary[name]['firstHitHeightP5P50P95Metres']=np.percentile(heights,[5,50,95]).tolist()if len(heights)else None
    summary={'scope':'Matching-height reference-relative surface audit; no live safety or false-obstacle removal claim','artifactSHA256':ARTIFACT_SHA,'originalSavedReferenceColumnsMatched':True,'runtime':runtime,'registration':registration,'modelToReference':model_to_reference.tolist(),'mesh':mesh_info,'selection':selection,'bandsMetres':BANDS,'bandNames':BAND_NAMES,'vertexBandsHalfOpen':True,'triangleBandsClosed':True,'boundaryDoubleCountingPossible':True,'overallContactCountsUseUnion':True,'vertex':vertex_summary,'triangleSample':triangle_summary,'nativeQueries':{'boxes':evaluator.box_queries,'triangles':evaluator.triangle_queries,'floorRays':evaluator.floor_ray_queries},'referenceMeasuredSupportMaskAvailable':False,'referenceCleanedCompletedAndDifferentCaptureTime':True,'registrationFittedHere':False,'planeRefittedHere':False,'FAROUsedByPlanner':False,'mapsOrBodyChanged':False,'gameEpisodes':0,'physicalAuthority':False,'seconds':time.monotonic()-started}
    summary['maximumOriginalCoordinateFloat32RoundingMetres']=float(values['maximumOriginalCoordinateFloat32RoundingMetres'])
    summary['coordinatePrecisionMeaning']='Float64 original vertices own vertex counts; unchanged VTK PLY reader uses its reported coordinate type for triangle queries. Rounding measured, not hidden or a calibrated uncertainty bound.'
    summary['nearFloorMeaning']='Positive reference geometry in a band can be floor registration or surface-height variation, not necessarily a physical obstacle. No reference band is used to erase phone evidence.'
    summary['testedHeightRangeNominalMetres']=[.010,1.800]
    summary['untestedNearFootRangeNominalMetres']=[.002,.010]
    summary['fullNearFootClearanceEstablished']=False
    verify(expected);dump(out/'SUMMARY.json',summary);log(phase='complete',summary=summary)

if __name__=='__main__':run(sys.argv[1])
