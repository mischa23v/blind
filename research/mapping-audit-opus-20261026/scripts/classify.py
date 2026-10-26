import numpy as np
RES=.05
def grid(occ,free,top=1.75):
  ko=np.floor(occ/RES+1e-6).astype(int);kf=np.floor(free/RES+1e-6).astype(int)
  lo=np.minimum(ko.min(0),kf.min(0));hi=np.maximum(ko.max(0),kf.max(0))
  lo[2]=-4;hi[2]=int(round(top/RES))+1
  sh=hi-lo+1
  st=np.zeros(sh,np.int8) # 0 unknown,1 free,2 occ
  def put(k,v):
    m=(k[:,2]>=lo[2])&(k[:,2]<=hi[2]);k=k[m]-lo;st[k[:,0],k[:,1],k[:,2]]=v
  put(kf,1);put(ko,2)
  return st,lo
def columns(st,lo,top=1.75):
  z0=-lo[2];L=int(round(top/RES))  # layers 1..L
  body=st[:,:,z0+1:z0+L+1]
  sup=st[:,:,z0]==2
  obst=(body==2).any(2);unk=(body==0).any(2);below=(st[:,:,z0-2:z0]==2).any(2)
  return dict(support=sup,obstacle=obst,unknown=unk,below=below,walk=sup&~obst&~unk&~below)
if __name__=='__main__':
  st,lo=grid(np.load('m2_occ.npy'),np.load('m2_free.npy'))
  c=columns(st,lo)
  for k,v in c.items():print(k,int(v.sum()))
  print('support & no obstacle',int((c['support']&~c['obstacle']).sum()),' ... & known',int((c['support']&~c['obstacle']&~c['unknown']).sum()))
  z0=-lo[2]
  # Which layers are unknown in supported, obstacle-free columns
  m=c['support']&~c['obstacle']
  body=st[:,:,z0+1:z0+36]
  print('fraction unknown per layer (cm) in supported obstacle-free columns:')
  print({int(round((i+1)*5)):round(float((body[m][:,i]==0).mean()),3) for i in range(0,35,3)})
  np.savez('m2_grid.npz',st=st,lo=lo)
