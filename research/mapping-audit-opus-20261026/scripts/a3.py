from common import *
res={'axial':[],'range':[]}
for i in range(0,294,7):
  f=T[i];d=depth(f)
  for mode in res:
    p=world(f,d,mode)
    s=p[(p[:,2]>-1.45)&(p[:,2]<-1.10)]
    if len(s)<20000 or np.ptp(s[:,0])<1 or np.ptp(s[:,1])<1: continue
    for it in range(4):
      A=np.c_[s[:,:2],np.ones(len(s))];k=np.linalg.lstsq(A,s[:,2],rcond=None)[0];e=s[:,2]-A@k
      s=s[np.abs(e)<max(3*np.std(e),.01)]
    # quadratic term test: fit z = plane + q*(x^2+y^2) around centroid
    x=s[:,0]-s[:,0].mean();y=s[:,1]-s[:,1].mean()
    A=np.c_[x,y,np.ones(len(s)),x*x+y*y];k2=np.linalg.lstsq(A,s[:,2],rcond=None)[0];e2=s[:,2]-A@k2
    res[mode].append((i,len(s),np.std(e),np.degrees(np.arccos(1/np.sqrt(1+k[0]**2+k[1]**2))),k[2],k2[3],np.std(e2)))
for mode,r in res.items():
  r=np.array(r);print(mode,'frames',len(r),'median planar resid std %.4f'%np.median(r[:,2]),'median tilt deg %.2f'%np.median(r[:,3]),'floor z p10/50/90',np.round(np.percentile(r[:,4],[10,50,90]),3),'median curvature %.4f'%np.median(r[:,5]),'resid after quad %.4f'%np.median(r[:,6]))
