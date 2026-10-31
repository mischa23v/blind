"""Offline author-registered reference queries using installed VTK; no live sensor authority."""
import itertools,math,time,os,platform
from pathlib import Path
import numpy as np
import vtk

TOLERANCE=1e-7
CELLS_PER_NODE=16
MAX_BUCKETS=2097152

class GeometryFailure(RuntimeError):pass

def serial_vtk():
    vtk.vtkMultiThreader.SetGlobalMaximumNumberOfThreads(1)
    vtk.vtkMultiThreader.SetGlobalDefaultNumberOfThreads(1)
    if hasattr(vtk.vtkSMPTools,'SetBackend') and not vtk.vtkSMPTools.SetBackend('Sequential'):
        raise GeometryFailure('VTK sequential backend unavailable')
    cpu_name=next((line.split(':',1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('model name')), 'unreported')
    mem={line.split(':',1)[0]:int(line.split()[1])*1024 for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith(('MemTotal:','MemAvailable:'))}
    return {'version':vtk.vtkVersion.GetVTKVersion(),'SMPBackend':vtk.vtkSMPTools.GetBackend(),'threads':1,
        'executionMachine':{'system':platform.system(),'release':platform.release(),'machine':platform.machine(),'cpuReportedModel':cpu_name,'logicalCPUAffinityCount':len(os.sched_getaffinity(0)),'memorySnapshotBytes':mem,'CPUQuotaNotEstablished':True,'iPhoneRuntimeTest':False,'GPUUsed':False}}

def camera_rays(rows,columns,fx,fy,cx,cy):
    # Pinned author Nerfstudio/PyTorch3D screen-pixel-centre convention, not Record3D's integer example.
    values=np.asarray([fx,fy,cx,cy],dtype=np.float64)
    if not np.isfinite(values).all() or fx<=0 or fy<=0:raise GeometryFailure('invalid calibration')
    r=np.asarray(rows,dtype=np.float64);c=np.asarray(columns,dtype=np.float64)
    if not np.isfinite(r).all() or not np.isfinite(c).all() or r.shape!=c.shape:raise GeometryFailure('invalid pixel addresses')
    return np.column_stack(((c+.5-cx)/fx,-(r+.5-cy)/fy,-np.ones(r.size)))

def checked_camera(c):
    c=np.asarray(c,dtype=np.float64)
    if c.shape!=(4,4) or not np.isfinite(c).all() or np.max(np.abs(c[3]-[0,0,0,1]))>1e-10:raise GeometryFailure('invalid camera affine matrix')
    r=c[:3,:3];orth=float(np.max(np.abs(r.T@r-np.eye(3))));det=float(np.linalg.det(r))
    if orth>1e-5 or abs(det-1)>1e-5:raise GeometryFailure('camera is not a proper rigid pose')
    return c,{'rotationOrthogonalityResidual':orth,'rotationDeterminant':det}

def checked_similarity(a):
    a=np.asarray(a,dtype=np.float64)
    if a.shape!=(4,4) or not np.isfinite(a).all() or np.max(np.abs(a[3]-[0,0,0,1]))>1e-10:raise GeometryFailure('invalid registration affine matrix')
    singular=np.linalg.svd(a[:3,:3],compute_uv=False);scale=float(np.mean(singular));det=float(np.linalg.det(a[:3,:3]))
    if scale<=0 or det<=0 or float(np.max(np.abs(singular-scale)))/scale>1e-6:raise GeometryFailure('registration not positive uniform similarity')
    return a,{'singularValues':singular.tolist(),'scale':scale,'determinant':det,'scaleFittedHere':False}

class ReferenceSurface:
    def __init__(self,mesh,progress=None):
        self.progress=progress
        if mesh.GetNumberOfPoints()<3 or mesh.GetNumberOfCells()<1:raise GeometryFailure('empty mesh')
        self.mesh=mesh;self.errors=[];bounds=np.asarray(mesh.GetBounds(),dtype=float)
        if not np.isfinite(bounds).all():raise GeometryFailure('nonfinite mesh bounds')
        self.bounds=bounds;self.corners=np.asarray(list(itertools.product(bounds[0:2],bounds[2:4],bounds[4:6])))
        self.locator=vtk.vtkStaticCellLocator();self.locator.AddObserver('ErrorEvent',lambda *args:self.errors.append('VTK locator ErrorEvent'))
        self.locator.SetDataSet(mesh);self.locator.SetNumberOfCellsPerNode(CELLS_PER_NODE);self.locator.SetMaxNumberOfBuckets(MAX_BUCKETS);self.locator.AutomaticOn()
        build_start=time.monotonic()
        if self.progress:self.progress({'phase':'locator_build_start','locator':type(self.locator).__name__,'cells':mesh.GetNumberOfCells()})
        self.locator.BuildLocator()
        self.build_seconds=time.monotonic()-build_start
        if self.progress:self.progress({'phase':'locator_build_completed','locator':type(self.locator).__name__,'buildWallSeconds':self.build_seconds})
        if any(d<=0 for d in self.locator.GetDivisions()):raise GeometryFailure('static locator has invalid built divisions')
        if self.errors:raise GeometryFailure(';'.join(self.errors))
        self.t=vtk.reference(0.);self.sub=vtk.reference(0);self.cid=vtk.reference(0);self.point=[0.,0.,0.];self.pc=[0.,0.,0.];self.generic_cell=vtk.vtkGenericCell()
    def query(self,camera_to_phone,phone_to_faro,rays,label=None):
        query_start=time.monotonic()
        if self.progress:self.progress({'phase':'query_start','label':label,'scheduledRays':len(rays)})
        c,_=checked_camera(camera_to_phone);a,_=checked_similarity(phone_to_faro);m=a@c;inverse=np.linalg.inv(m)
        origin=m[:3,3];directions=np.asarray(rays,dtype=float)@m[:3,:3].T
        lengths=np.linalg.norm(directions,axis=1)
        if not np.isfinite(directions).all() or np.any(lengths<=0):raise GeometryFailure('invalid transformed ray')
        # Covers all original mesh-bounds corners; independent of tested sensor depth.
        far=float(np.max(np.linalg.norm(self.corners-origin,axis=1))+1.0)
        if not math.isfinite(far) or far<=0:raise GeometryFailure('invalid geometry-only far bound')
        ends=origin+directions*(far/lengths)[:,None]
        depths=np.full(len(rays),np.nan,dtype=np.float64);cellids=np.full(len(rays),-1,dtype=np.int64);consistency=0.
        o=origin.tolist()
        for i,end in enumerate(ends):
            if self.progress and i%4096==0:self.progress({'phase':'query_progress','label':label,'raysCompleted':i,'scheduledRays':len(rays),'queryWallSeconds':time.monotonic()-query_start})
            hit=self.locator.IntersectWithLine(o,end.tolist(),TOLERANCE,self.t,self.point,self.pc,self.sub,self.cid,self.generic_cell)
            if self.progress and i==0:self.progress({'phase':'first_native_query_completed','label':label,'intersectionStatus':int(hit),'queryWallSeconds':time.monotonic()-query_start})
            if self.errors:raise GeometryFailure(';'.join(self.errors))
            if hit not in (0,1):raise GeometryFailure('unexpected VTK intersection status')
            if hit==0:continue
            point=np.asarray(self.point,dtype=float);t=float(self.t);cell=int(self.cid)
            if not np.isfinite(point).all() or not math.isfinite(t) or not 0<=t<=1 or not 0<=cell<self.mesh.GetNumberOfCells():raise GeometryFailure('invalid VTK hit')
            axial=-float(inverse[2,:3]@point+inverse[2,3]);parameter_axial=t*far/lengths[i]
            error=abs(axial-parameter_axial);consistency=max(consistency,error)
            if not math.isfinite(axial) or axial<=0 or error>1e-6:raise GeometryFailure('invalid/contradictory axial depth')
            depths[i]=axial;cellids[i]=cell
        if self.progress:self.progress({'phase':'query_completed','label':label,'raysCompleted':len(rays),'queryWallSeconds':time.monotonic()-query_start})
        return depths,cellids,{'farEndpointDistanceFaroUnits':far,'maxHitInverseVersusParameterAxialResidual':consistency,
            'meshTransformedOrDuplicated':False,'rayTransform':'phone_to_faro @ camera_to_phone','nearestSurface':True,'twoSidedTriangleIntersection':True,'locator':'vtkStaticCellLocator first-hit overload with reused vtkGenericCell','cellsPerNode':CELLS_PER_NODE,'maxBuckets':MAX_BUCKETS,'intersectionToleranceFaroUnits':TOLERANCE}

def plane_mesh(zs,transform=None,reverse=False):
    points=vtk.vtkPoints();points.SetDataTypeToDouble();cells=vtk.vtkCellArray()
    transform=np.eye(4) if transform is None else np.asarray(transform,float)
    for z in zs:
        base=points.GetNumberOfPoints()
        for x,y in [(-5,-5),(5,-5),(5,5),(-5,5)]:
            q=transform@np.asarray([x,y,z,1.]);points.InsertNextPoint(*q[:3])
        for ids in [(0,1,2),(0,2,3)]:
            ids=ids[::-1] if reverse else ids;cells.InsertNextCell(3)
            for index in ids:cells.InsertCellPoint(base+index)
    mesh=vtk.vtkPolyData();mesh.SetPoints(points);mesh.SetPolys(cells);return mesh

def convention_tests():
    runtime=serial_vtk();results=[];rays=camera_rays(np.array([45]),np.array([60]),100.,100.,50.,40.)
    error=float(np.max(np.abs(rays[0]*2-np.asarray([.21,-.11,-2.]))))
    if error>1e-12:raise GeometryFailure('half-pixel golden failed')
    results.append({'name':'half_pixel_asymmetric_ray_golden','maxError':error})
    for reverse in [False,True]:
        surface=ReferenceSurface(plane_mesh([-2.,-4.],reverse=reverse));d,ids,meta=surface.query(np.eye(4),np.eye(4),rays)
        if abs(d[0]-2)>1e-10 or ids[0] not in (0,1):raise GeometryFailure('nearest/two-sided surface golden failed')
        results.append({'name':'first_surface_reverse_winding_'+str(reverse),'axialDepth':float(d[0]),'cellID':int(ids[0])})
    c=np.eye(4);theta=.31;c[:3,:3]=[[np.cos(theta),0,np.sin(theta)],[0,1,0],[-np.sin(theta),0,np.cos(theta)]];c[:3,3]=[.4,-.3,.2]
    a=np.eye(4);a[:3,:3]=2*np.asarray([[0,-1,0],[1,0,0],[0,0,1]]);a[:3,3]=[5,-2,1]
    surface=ReferenceSurface(plane_mesh([-2.,-4.],a@c));d,ids,meta=surface.query(c,a,rays)
    if abs(d[0]-2)>1e-10:raise GeometryFailure('translated/rotated/scaled original-mesh ray transform failed')
    direct=ReferenceSurface(plane_mesh([-2.,-4.]));dd,_,_=direct.query(np.eye(4),np.eye(4),rays)
    if abs(d[0]-dd[0])>1e-10 or np.linalg.norm(rays[0]*2)<=2:raise GeometryFailure('mesh/ray equivalence or axial/range distinction failed')
    results.append({'name':'similarity_translated_rotated_ray_vs_mesh_equivalence','axialDepth':float(d[0]),'difference':float(abs(d[0]-dd[0]))})
    ordered=ReferenceSurface(plane_mesh([-2.,-4.,-1.]));nearest,nearest_ids,_=ordered.query(np.eye(4),np.eye(4),np.asarray([[0.,0.,-1.]]))
    if abs(nearest[0]-1.)>1e-10 or nearest_ids[0] not in (4,5):raise GeometryFailure('unsorted 2/4/1-plane nearest-hit fixture failed')
    results.append({'name':'unsorted_plane_order_2_4_1','axialDepth':float(nearest[0]),'cellID':int(nearest_ids[0])})
    missing,_,_=direct.query(np.eye(4),np.eye(4),np.asarray([[100.,0.,-1.]]))
    if not np.isnan(missing[0]):raise GeometryFailure('no-hit must stay missing')
    results.append({'name':'no_hit_retained_missing','passed':True})
    return {'runtime':runtime,'tests':results,'recordedFramesEvaluated':0,'physicalAccuracyEstablished':False}
