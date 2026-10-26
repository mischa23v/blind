import numpy as np,json
from scipy.spatial import cKDTree
V1=__import__('os').environ['BLIND_REPO']+'/research/koivu-phone-map-negative-result/workspaces/blind-koivu-game-07/map/run-01/map/MAP.npz'
E=__import__('os').environ['BLIND_REPO']+'/research/koivu-octomap-v2/workspaces/blind-koivu-game-07/map-v2/run-01/map/SURFACE_EVIDENCE.npz'
m=np.load(V1);e=np.load(E);sj=json.load(open(__import__('os').environ['BLIND_REPO']+'/research/koivu-octomap-v2/workspaces/blind-koivu-game-07/map-v2/run-01/map/SURFACE.json'))
ijk=m['voxelIndices'].astype(int);o=m['voxelOrigin'];yc=o[1]+(ijk[:,1]+.5)*.05
W=sj['width'];el=[i for i,c in enumerate(sj['cells']) if c['clearance'] is not None and not c['blocked']]
cx=np.array([sj['origin']['x']+(i%W+.5)*.1 for i in el]);cz=np.array([sj['origin']['z']+(i//W+.5)*.1 for i in el])
pos=e['rawObstacle']&e['rawOccupiedAny']
def nearest(mask):
  # distance from cell centre to nearest 5cm voxel square (approx via centre distance minus half-diagonal)
  vx=o[0]+(ijk[mask,0]+.5)*.05;vz=o[2]+(ijk[mask,2]+.5)*.05
  t=cKDTree(np.c_[vx,vz]);d,_=t.query(np.c_[cx,cz]);return d
dall=nearest(pos);dnofloor=nearest(pos&(yc>.05))
print('eligible',len(el),' nearest occupied-voxel centre distance median (all) %.3f  (excluding floor layer [0,5cm)) %.3f'%(np.median(dall),np.median(dnofloor)))
print('fraction whose nearest is a floor-layer voxel:',np.mean(dall<dnofloor-1e-9))
print('p10/50/90 excluding floor layer',np.round(np.percentile(dnofloor,[10,50,90]),3))
