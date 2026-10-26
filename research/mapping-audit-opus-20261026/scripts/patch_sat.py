p='fast_container.py';s=open(p).read()
s=s.replace('import numpy as np,vtk\n','import numpy as np,vtk\nfrom vtk.util.numpy_support import vtk_to_numpy\n')
s=s.replace("""class FastGroundedContainer(GroundedReferenceContainer):
    def contact_corners(self,corners):""","""def sat_maybe(T,c,U,e,eps=1e-3):
    \"\"\"Vectorised triangle/OBB separating-axis test. Returns True where the triangle is NOT separated from the
    box inflated by eps (conservative: never drops a triangle that touches the box). T: (N,3,3), U rows = unit axes.\"\"\"
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
    def contact_corners(self,corners):""")
s=s.replace("""        closest,pcoords,weights=[0.]*3,[0.]*3,[0.]*8;sub_id,distance2=vtk.reference(0),vtk.reference(0.)
        first=None
        for cell_id in ids[~isg]:""","""        closest,pcoords,weights=[0.]*3,[0.]*3,[0.]*8;sub_id,distance2=vtk.reference(0),vtk.reference(0.)
        first=None;cand=ids[~isg]
        if len(cand):   # exact-conservative prefilter (1 mm inflated SAT); VTK still decides every survivor in original order
            Pm,Cm=self._arrays();T=Pm[Cm[cand]].astype(np.float64)
            ed=np.stack((q[1]-q[0],q[3]-q[0],q[4]-q[0]));ln=np.linalg.norm(ed,axis=1);U=ed/ln[:,None];cen=q[0]+ed.sum(0)/2
            cand=cand[sat_maybe(T,cen,U,ln/2)]
        self.satSurvivors=getattr(self,'satSurvivors',0)+len(cand)
        for cell_id in cand:""")
s=s.replace("fastPath='ground IDs removed before VTK tests; decision-equivalent',","fastPath='ground IDs removed, then 1 mm-inflated SAT prefilter, before VTK tests; decision-equivalent',")
open(p,'w').write(s);print('ok')
