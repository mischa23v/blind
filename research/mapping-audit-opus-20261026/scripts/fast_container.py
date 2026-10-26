"""Decision-equivalent fast path for the published GroundedReferenceContainer.

The original contact_corners runs VTK triangle/box intersection on EVERY broad-phase candidate, including the
tens of thousands of confirmed ground triangles under the body, only to report complete ground-contact counts.
The contact decision and the first non-ground triangle depend only on non-ground candidates, visited in the
original broad-phase order. This subclass removes confirmed ground IDs first (exact sorted-array membership,
same set as GroundSupport.is_ground) and stops at the first non-ground hit. Ground-contact counts are not computed.
Everything else (validation, transform, VTK primitives, result fields) is the original code path.
"""
import numpy as np,vtk
from vtk.util.numpy_support import vtk_to_numpy
from oriented_ground_container import GroundedReferenceContainer
from oriented_container import GeometryFailure

def sat_maybe(T,c,U,e,eps=1e-3):
    """Vectorised triangle/OBB separating-axis test. Returns True where the triangle is NOT separated from the
    box inflated by eps (conservative: never drops a triangle that touches the box). T: (N,3,3), U rows = unit axes."""
    V=T-c;keep=np.ones(len(T),bool)
    for k in range(3):
        p=V@U[k];keep&=~((p.min(1)>e[k]+eps)|(p.max(1)<-e[k]-eps))
    E=[V[:,1]-V[:,0],V[:,2]-V[:,1],V[:,0]-V[:,2]];n=np.cross(E[0],E[1])
    def axis(a):
        nrm=np.linalg.norm(a,axis=1);ok=nrm>1e-12;p=np.einsum('nij,nj->ni',V,a);r=sum(e[m]*np.abs(a@U[m]) for m in range(3))
        return ~(ok&((p.min(1)>r+eps*nrm)|(p.max(1)<-r-eps*nrm)))
    keep&=axis(n)
    for k in range(3):
        for j in range(3):keep&=axis(np.cross(np.broadcast_to(U[k],E[j].shape),E[j]))
    return keep

class FastGroundedContainer(GroundedReferenceContainer):
    def _arrays(self):
        if not hasattr(self,'_P'):
            self._P=vtk_to_numpy(self.mesh.GetPoints().GetData());self._C=vtk_to_numpy(self.mesh.GetPolys().GetConnectivityArray()).reshape(-1,3)
        return self._P,self._C
    def contact_corners(self,corners):
        self.check()
        corners=np.asarray(corners,dtype=float)
        if corners.shape!=(8,3) or not np.isfinite(corners).all():raise ValueError('finite eight-corner hexahedron required')
        edges=np.column_stack((corners[1]-corners[0],corners[3]-corners[0],corners[4]-corners[0]));lengths=np.linalg.norm(edges,axis=0)
        if np.any(lengths<=0) or not np.isfinite(lengths).all():raise ValueError('positive OBB extents required')
        unit=edges/lengths
        if not np.allclose(unit.T@unit,np.eye(3),atol=1e-10,rtol=0) or np.linalg.det(unit)<=0:raise ValueError('proper orthogonal OBB required')
        v0=corners[0];x,y,z=edges.T
        if not np.allclose(corners,np.asarray([v0,v0+x,v0+x+y,v0+y,v0+z,v0+x+z,v0+x+y+z,v0+y+z]),atol=1e-10,rtol=0):raise ValueError('VTK OBB corner order mismatch')
        q=corners@self.transform[:3,:3].T+self.transform[:3,3]
        if not np.isfinite(q).all():raise GeometryFailure('nonfinite transformed OBB')
        for i,p in enumerate(q):self.box.GetPoints().SetPoint(i,p)
        self.box.GetPoints().Modified()
        bounds=np.column_stack((q.min(axis=0),q.max(axis=0))).reshape(-1)
        if not getattr(self,'_replay',False):
            # Tiled pre-pass (<=0.25 unit tiles, union of IDs; set-identical to one call on VTK 9.7.1 for all 120 checked
            # boxes, TILE_EQUIVALENCE_VTK971.json). Sorted order: ANY non-ground positive replays the original native order.
            ids=self._tiled(bounds);self.box_queries+=1;self.check()
            if len(ids)>self.maximum_candidate_cells:raise GeometryFailure('reference broad-phase candidate cap; not scored clear')
            pre=self._decide(ids,q,len(ids))
            if not pre['contact']:self.tiledNegative=getattr(self,'tiledNegative',0)+1;return pre
            self.tiledReplay=getattr(self,'tiledReplay',0)+1;self._replay=True
            try:return self.contact_corners(corners)
            finally:self._replay=False
        self.ids.Reset();self.surface.locator.FindCellsWithinBounds(bounds,self.ids);self.box_queries+=1;self.check()
        count=self.ids.GetNumberOfIds()
        if count>self.maximum_candidate_cells:raise GeometryFailure('reference broad-phase candidate cap; not scored clear')
        ids=np.fromiter((self.ids.GetId(i) for i in range(count)),dtype=np.int64,count=count)
        return self._decide(ids,q,count)
    def _tiled(self,b,ts=.25):
        import math
        n=[max(1,math.ceil((b[2*a+1]-b[2*a])/ts)) for a in range(3)];E=[np.linspace(b[2*a],b[2*a+1],n[a]+1) for a in range(3)];out=[]
        for i in range(n[0]):
            for j in range(n[1]):
                for k in range(n[2]):
                    self.ids.Reset();self.surface.locator.FindCellsWithinBounds([E[0][i],E[0][i+1],E[1][j],E[1][j+1],E[2][k],E[2][k+1]],self.ids)
                    c=self.ids.GetNumberOfIds();out.append(np.fromiter((self.ids.GetId(x) for x in range(c)),np.int64,c))
        self.check();return np.unique(np.concatenate(out)) if out else np.zeros(0,np.int64)
    def _decide(self,ids,q,count):
        g=self._ground.ground_cell_ids;pos=np.searchsorted(g,ids);isg=(pos<len(g))&(g[np.minimum(pos,len(g)-1)]==ids)
        closest,pcoords,weights=[0.]*3,[0.]*3,[0.]*8;sub_id,distance2=vtk.reference(0),vtk.reference(0.)
        first=None;cand=ids[~isg]
        if len(cand):   # exact-conservative prefilter (1 mm inflated SAT); VTK still decides every survivor in original order
            Pm,Cm=self._arrays();T=Pm[Cm[cand]].astype(np.float64)
            ed=np.stack((q[1]-q[0],q[3]-q[0],q[4]-q[0]));ln=np.linalg.norm(ed,axis=1);U=ed/ln[:,None];cen=q[0]+ed.sum(0)/2
            cand=cand[sat_maybe(T,cen,U,ln/2)]
        self.satSurvivors=getattr(self,'satSurvivors',0)+len(cand)
        for cell_id in cand:
            cell_id=int(cell_id)
            if not 0<=cell_id<self.mesh.GetNumberOfCells():raise GeometryFailure('invalid reference broad-phase cell ID')
            self.mesh.GetCell(cell_id,self.cell)
            if self.cell.GetCellType()!=vtk.VTK_TRIANGLE or self.cell.GetNumberOfPoints()!=3:raise GeometryFailure('reference cell is not a triangle')
            self.triangle_queries+=1
            intersects=self.cell.IntersectWithCell(self.box)
            if intersects not in (0,1):raise GeometryFailure('invalid VTK cell intersection status')
            reason='boundaryIntersection' if intersects else None
            if not intersects:
                for vertex in range(3):
                    inside=self.box.EvaluatePosition(self.cell.GetPoints().GetPoint(vertex),closest,sub_id,pcoords,distance2,weights)
                    if inside not in (0,1):raise GeometryFailure('invalid VTK hexahedron containment status')
                    if inside:reason='containedTriangleVertex';break
            if reason is not None:first=self._oriented_result(True,count,cell_id,reason);break
        self.check()
        result=first if first is not None else self._oriented_result(False,count,None,'noNonGroundReferenceSurfaceContact')
        result.update(groundContactCount=None,nonGroundContactCount=None if first is None else 1,groundContactEvent=None,
            groundCandidatesSkipped=int(isg.sum()),fastPath='ground IDs removed, then 1 mm-inflated SAT prefilter, before VTK tests; decision-equivalent',
            groundExemption='confirmed immutable original face-ID component only',lowHeightAloneExcluded=False,groundComponentDoesNotEstablishSemanticFloor=True)
        return result
