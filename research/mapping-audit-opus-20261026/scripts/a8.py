import numpy as np
V1=__import__('os').environ['BLIND_REPO']+'/research/koivu-phone-map-negative-result/workspaces/blind-koivu-game-07/map/run-01/map/MAP.npz'
E=__import__('os').environ['BLIND_REPO']+'/research/koivu-octomap-v2/workspaces/blind-koivu-game-07/map-v2/run-01/map/SURFACE_EVIDENCE.npz'
m=np.load(V1);e=np.load(E)
ijk=m['voxelIndices'].astype(int);o=m['voxelOrigin'];yc=o[1]+(ijk[:,1]+.5)*.05
W=int(m['surfaceWidth']);D=int(m['surfaceDepth']);cell=(ijk[:,2]//2)*W+ijk[:,0]//2
assert (e['rawObstacle']==m['voxelObstacle']).all()
pos=e['rawObstacle']&e['rawOccupiedAny']
print('v2 positive-occupied obstacle voxels',pos.sum())
bands=[('floor layer [0,5)cm',(yc>0)&(yc<.05)),('5-30cm',(yc>.05)&(yc<.30)),('30-80cm',(yc>.30)&(yc<.80)),('80-175cm',(yc>.80)&(yc<1.8))]
for n,b in bands:print(f'  {n}: {(pos&b).sum()} voxels, of which max hit<=+4.9cm: {(pos&b&(m["voxelMaximumObservedY"]<.05)).sum()}')
def cells(mask):
  c=np.zeros(W*D,bool);c[cell[mask]]=True;return c
fl=cells(pos&bands[0][1]);other=cells(pos&~bands[0][1])
print('surface cells positively blocked: total',cells(pos).sum(),' ONLY by floor-layer voxels',(fl&~other).sum())
# How many floor-layer voxels are 'obstacle' purely because floor points exceed +3cm, and in how many frames
f=pos&bands[0][1]
print('floor-layer occupied obstacle voxels: frames p10/50/90',np.percentile(m['voxelSourceFrameCount'][f],[10,50,90]),' max Y p10/50/90 (cm)',np.round(np.percentile(m['voxelMaximumObservedY'][f]*100,[10,50,90]),2))
