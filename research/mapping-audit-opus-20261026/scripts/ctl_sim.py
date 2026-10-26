import os,sys,json,math,numpy as np
sys.argv=['x'];sys.path.insert(0,os.environ['SCRATCH']+'/audit')
from game100 import Map,Controller,P
sys.path.insert(0,'/home/user/blind/research/tools/koivu-offline-game-v1');from impairments import ActorFIFO,ActorProfile,ActorCommand
S=os.environ['SCRATCH']+''
M=Map(S+'/runs3/koivu_coloricp','occthres_statsplit0.7.npz',S+'/recast');F=json.load(open(S+'/v3/koivu/ROUTES.json'))
for rid in range(20):
  r=F['routes'][rid];st=np.array(r['start']);yaw=r['initialYawRadians'];goal=np.array(r['goal']);c=Controller(M,goal);a=ActorFIFO(ActorProfile());reasons={};dist=0;turns=0
  for t in range(1200):
    now=100+t/15;f,tr,why,src=c.tick(t,now,{'position':st.tolist(),'yaw':yaw,'capturedAt':now});reasons[why]=reasons.get(why,0)+1
    ap=a.step(t,ActorCommand(f,tr,t,src,why));yaw+=ap.yaw_radians;st=st+ap.forward_metres*np.array([math.cos(yaw),math.sin(yaw)]);dist+=ap.forward_metres;turns+=abs(ap.yaw_radians)>0
    if why=='goalReachedByDeliveredPose':break
  print(rid,'ticks',t+1,'dist',round(dist,2),'turnTicks',turns,'err',round(float(np.linalg.norm(st-goal)),2),reasons,'pathLen',round(r['pathLengthMetres'],2),'corners',len(r['initialPath']))
