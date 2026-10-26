"""EVALUATOR ONLY. Transform the author-registered FARO mesh vertices into the phone level frame
and compute per-5cm-column reference height statistics. Never an input to any planner map.
Vertex-based (mesh vertex spacing is mm-scale); triangles are not rasterized."""
import numpy as np,json,time
D=__import__('os').environ['KOIVU_FARO_DIR'].rstrip('/')+'/'  # extracted room_datasets/koivu/ with gt_mesh.ply, icp_iphone.json
A=np.array(json.load(open(D+'icp_iphone.json'))['gt_transformation']);Ainv=np.linalg.inv(A)
sv=np.linalg.svd(A[:3,:3],compute_uv=False);print('registration scale',sv)
fr=json.load(open('m2_frame.json'));R=np.array(fr['R']);t=np.array(fr['t']);OFF=fr['offset']
with open(D+'gt_mesh.ply','rb') as f:
  hdr=b''
  while not hdr.endswith(b'end_header\n'):hdr+=f.readline()
  nv=int([l for l in hdr.decode().split('\n') if l.startswith('element vertex')][0].split()[-1])
  V=np.fromfile(f,dtype='<f8',count=nv*6).reshape(nv,6)[:,:3]
print('vertices',len(V),'FARO bounds',V.min(0),V.max(0))
P=V@Ainv[:3,:3].T+Ainv[:3,3]            # nominal phone metres
P=P@R.T+t+[0,0,OFF]                      # level frame (floor plane at z=OFF, i.e. height h=z-OFF)
h=P[:,2]-OFF
print('phone-frame bounds',P.min(0),P.max(0))
lo=np.load('policyD.npz')['lo'];H,W=np.load('policyD.npz')['walk'].shape
i=np.floor(P[:,0]/.05).astype(int)-lo[0];j=np.floor(P[:,1]/.05).astype(int)-lo[1]
ok=(i>=0)&(i<H)&(j>=0)&(j<W);i,j,h=i[ok],j[ok],h[ok];col=i*W+j
n=np.bincount(col,minlength=H*W)
hmin=np.full(H*W,np.inf);np.minimum.at(hmin,col,h);hmax=np.full(H*W,-np.inf);np.maximum.at(hmax,col,h)
# max height of geometry in the low/body bands, floor estimate
def bandmax(a,b):
  m=(h>=a)&(h<b);out=np.full(H*W,-np.inf);np.maximum.at(out,col[m],h[m]);cnt=np.bincount(col[m],minlength=H*W);return out,cnt
low_max,low_n=bandmax(0.015,0.30)          # anything 1.5–30 cm above plane
body_max,body_n=bandmax(0.30,1.80)
fl=(h>-.06)&(h<.06);fsum=np.bincount(col[fl],weights=h[fl],minlength=H*W);fn=np.bincount(col[fl],minlength=H*W)
floor_h=np.where(fn>0,fsum/np.maximum(fn,1),np.nan)
print('reference floor height vs plane (cm) over columns with floor: p5/50/95',np.round(np.nanpercentile(floor_h*100,[5,50,95]),2))
np.savez('ref_columns.npz',n=n.reshape(H,W),hmin=hmin.reshape(H,W),hmax=hmax.reshape(H,W),low_max=low_max.reshape(H,W),low_n=low_n.reshape(H,W),body_max=body_max.reshape(H,W),body_n=body_n.reshape(H,W),floor_h=floor_h.reshape(H,W),registrationScale=sv)
