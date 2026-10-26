from common import *
import time
t0=time.time()
P=[];F=[]
for i,f in enumerate(T):
  d=depth(f);h,w=d.shape
  rr=np.arange(h);cc=np.arange(w)
  rs=rr[(rr+15)%4==2];cs=cc[(cc+15)%4==2]
  r=rays(f,block=True)[np.ix_(rs,cs)];dd=d[np.ix_(rs,cs)]
  c=np.array(f['transform_matrix']);p=(r*dd[...,None]).reshape(-1,3)@c[:3,:3].T+c[:3,3]
  P.append(p.astype(np.float32));F.append(np.full(len(p),i,np.int16))
P=np.concatenate(P);F=np.concatenate(F)
np.save('samples.npy',P);np.save('sampleframe.npy',F)
print('samples',len(P),'secs',time.time()-t0)
cams=np.array([f['transform_matrix'] for f in T])[:,:3,3];np.save('cams.npy',cams)
print('camera z range',cams[:,2].min(),cams[:,2].max(),'median',np.median(cams[:,2]))
z=P[:,2];hist,edges=np.histogram(z,bins=np.arange(-2,1.5,.01))
top=np.argsort(hist)[-5:];print('densest 1cm z bins',[(round(edges[k],2),hist[k]) for k in top])
