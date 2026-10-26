"""VTK 9.7.1 equivalence + speed check of a tiled broad phase (<=0.25 reference-unit tiles, union of IDs) against a
single FindCellsWithinBounds call, on body and margin boxes sampled along all 20 frozen Koivu routes. No ground needed:
broad-phase candidate SETS must be identical."""
import sys,os,json,time,math,numpy as np
sys.argv=['x'];sys.path.insert(0,os.environ['SCRATCH']+'/audit')
import game_v3 as G,vtk
from oriented_container import sweep_enclosure
S=os.environ['SCRATCH']+''
o=np.load(S+'/runs3/koivu_coloricp/pipeline2_out.npz');A=np.array(json.load(open(S+'/data/faro/room_datasets/koivu/icp_iphone.json'))['gt_transformation'])
rd=vtk.vtkPLYReader();rd.SetFileName(S+'/data/faro/room_datasets/koivu/gt_mesh.ply');rd.Update();surf=G.ReferenceSurface(rd.GetOutput())
base=G.OrientedReferenceContainer(surf,G.transform({'R':o['R'],'t':o['t']},A));loc=surf.locator;ids=vtk.vtkIdList()
def whole(b):ids.Reset();loc.FindCellsWithinBounds(b,ids);return np.unique(np.fromiter((ids.GetId(i) for i in range(ids.GetNumberOfIds())),np.int64,ids.GetNumberOfIds()))
def tiled(b,ts=.25):
    n=[max(1,math.ceil((b[2*a+1]-b[2*a])/ts)) for a in range(3)];E=[np.linspace(b[2*a],b[2*a+1],n[a]+1) for a in range(3)];out=[]
    for i in range(n[0]):
        for j in range(n[1]):
            for k in range(n[2]):
                ids.Reset();loc.FindCellsWithinBounds([E[0][i],E[0][i+1],E[1][j],E[1][j+1],E[2][k],E[2][k+1]],ids)
                out.append(np.fromiter((ids.GetId(q) for q in range(ids.GetNumberOfIds())),np.int64,ids.GetNumberOfIds()))
    return np.unique(np.concatenate(out)) if out else np.zeros(0,np.int64)
F=json.load(open(S+'/v3/koivu/ROUTES.json'));L2G=lambda xy:np.array([xy[0],0.,-xy[1]])
rng=np.random.default_rng(5);rows=[];tw=tt=0.
for r in F['routes']:
    P=[L2G(p) for p in r['initialPath']]
    for q in range(3):
        k=rng.integers(0,len(P)-1);a=P[k]+(P[k+1]-P[k])*rng.uniform();d=P[k+1]-P[k];yaw=math.atan2(d[2],d[0])+rng.uniform(-.3,.3);b=a+.02*np.array([math.cos(yaw),0,math.sin(yaw)])
        for pad in (0.,.15):
            c,_=sweep_enclosure(a,b,yaw,rng.uniform(-.017,.017),half_forward=.15+pad,half_lateral=.225+pad,height=1.6,floor_contact_exclusion=.002)
            qq=np.asarray(c)@base.transform[:3,:3].T+base.transform[:3,3];bb=np.column_stack((qq.min(0),qq.max(0))).reshape(-1)
            t=time.perf_counter();w=whole(bb);tw+=time.perf_counter()-t;t=time.perf_counter();ti=tiled(bb);tt+=time.perf_counter()-t
            rows.append(dict(route=r['routeID'],pad=pad,n=int(len(w)),same=bool(len(w)==len(ti) and np.array_equal(w,ti)),extraInTiled=int(len(np.setdiff1d(ti,w))),missingInTiled=int(len(np.setdiff1d(w,ti)))))
same=sum(r['same'] for r in rows);print('boxes',len(rows),'identical sets',same,'whole s',round(tw,1),'tiled s',round(tt,1),'speedup',round(tw/tt,2))
bad=[r for r in rows if not r['same']];print('non-identical',bad[:5])
json.dump(dict(vtk=vtk.vtkVersion.GetVTKVersion(),boxes=len(rows),identical=same,wholeSeconds=tw,tiledSeconds=tt,rows=rows),open(S+'/v3/TILE_EQUIVALENCE_VTK971.json','w'),indent=1)
