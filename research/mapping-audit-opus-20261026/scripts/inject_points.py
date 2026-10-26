"""Re-render the same four synthetic boxes (inj_boxes.json) into the real rays and save endpoints only."""
import numpy as np,json
boxes=json.load(open('inj_boxes.json'))
P=np.load('m2_level_points.npy').astype(np.float64);F=np.load('m2_level_frames.npy');C=np.load('m2_level_cams.npy')
O=C[F];Dv=P-O;best=np.ones(len(P))
for b in boxes:
  t0=np.zeros(len(P));t1=np.ones(len(P))
  for a in range(3):
    with np.errstate(divide='ignore',invalid='ignore'):
      ta=(b['lo'][a]-O[:,a])/Dv[:,a];tb=(b['hi'][a]-O[:,a])/Dv[:,a]
    lo_=np.minimum(ta,tb);hi_=np.maximum(ta,tb);par=Dv[:,a]==0;inside=(O[:,a]>=b['lo'][a])&(O[:,a]<=b['hi'][a])
    lo_[par]=np.where(inside[par],-np.inf,np.inf);hi_[par]=np.where(inside[par],np.inf,-np.inf)
    t0=np.maximum(t0,lo_);t1=np.minimum(t1,hi_)
  hit=(t0<=t1)&(t0<best)&(t0>0);best[hit]=t0[hit]
np.save('inj_points.npy',(O+Dv*best[:,None]).astype(np.float32));print('saved')
