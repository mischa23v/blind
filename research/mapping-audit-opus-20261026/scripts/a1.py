import numpy as np,sys
m=np.load(sys.argv[1])
ijk=m['voxelIndices'].astype(int);o=m['voxelOrigin'];V=0.05
vmin=m['voxelMinimumObservedY'];vmax=m['voxelMaximumObservedY'];h=m['voxelHitCount'];f=m['voxelSourceFrameCount']
yc=o[1]+(ijk[:,1]+.5)*V
print('origin',o,'Y layers near floor:')
for yl in sorted(set(np.round(yc,3))):
  if -0.2<yl<0.3:
    s=np.isclose(yc,yl);print(f' yc={yl:+.3f} vox={s.sum():7d} hits={h[s].sum():11d} median hits={np.median(h[s]):6.0f} vmin p50={np.median(vmin[s]):+.3f} vmax p50={np.median(vmax[s]):+.3f}')
W=int(m['surfaceWidth']);D=int(m['surfaceDepth'])
cell=(ijk[:,2]//2)*W+ijk[:,0]//2
obst=m['voxelObstacle'];con=m['voxelFloorContradiction']
# Which cells are blocked only by obstacles whose max is below some height?
def blocked_cells(mask):
  b=np.zeros(W*D,bool);b[cell[mask]]=True;return b
sup=m['surfaceSupport']
print('supported',sup.sum(),'blocked',m['surfaceBlocked'].sum())
print('obstacle voxels',obst.sum(),'contradiction',con.sum())
# For supported cells, what blocks them
bo=blocked_cells(obst);bc=blocked_cells(con)
print('supported & obstacle-blocked',(sup&bo).sum(),' supported & contradiction',(sup&bc).sum())
# obstacles with vmin<=0.10 only (floor-smear zone) vs higher
low=obst&(vmax<=0.10); hi=obst&(vmax>0.10)
print('supported cells blocked ONLY by obstacle voxels with all hits <=0.10m:',(sup&blocked_cells(low)&~blocked_cells(hi)&~bc).sum())
# single-frame / few-hit obstacle voxels
for k in (1,2,3,5):
  weak=obst&(f<=k)
  strong=obst&(f>k)
  print(f'obstacle voxels seen in <= {k} frames: {weak.sum()}; supported cells blocked only by them: {(sup&blocked_cells(weak)&~blocked_cells(strong)&~bc).sum()}')
# hits in floor-layer voxels that are 'obstacle' because vmax just above band
fl=(yc>0)&(yc<0.05)
print('floor-layer voxel [0,0.05): total',fl.sum(),' obstacle',(fl&obst).sum(),' vmax distribution p10/50/90',np.percentile(vmax[fl],[10,50,90]))
fl2=(yc<0)&(yc>-0.05)
print('floor-layer voxel [-0.05,0): total',fl2.sum(),' contradiction',(fl2&con).sum(),' obstacle',(fl2&obst).sum(),' vmin p10/50/90',np.percentile(vmin[fl2],[10,50,90]))
