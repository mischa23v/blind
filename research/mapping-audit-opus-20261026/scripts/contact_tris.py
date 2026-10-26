import os,json,numpy as np,vtk,sys
from vtk.util.numpy_support import vtk_to_numpy
S=os.environ['SCRATCH']+''
for room,ply,icp,run in (('koivu',S+'/data/faro/room_datasets/koivu/gt_mesh.ply',S+'/data/faro/room_datasets/koivu/icp_iphone.json',S+'/runs3/koivu_coloricp'),('coffee',S+'/data/holdout/x/room_datasets/coffee_room/gt_mesh.ply',S+'/data/holdout/x/room_datasets/coffee_room/icp_iphone.json',S+'/runs3/coffee_coloricp')):
  R=json.load(open(f'{S}/v3/{room}/GAME_MERGED.json'))['results'];cells={}
  for r in R:
    fc=r.get('firstContact')
    if fc and fc.get('firstReferenceCellID') is not None:cells.setdefault(fc['firstReferenceCellID'],[]).append((r['runID'],round(max(fc['firstTriangleHeightRelativeToStartFootRange'])*1000,1)))
  rd=vtk.vtkPLYReader();rd.SetFileName(ply);rd.Update();m=rd.GetOutput();P=vtk_to_numpy(m.GetPoints().GetData());C=vtk_to_numpy(m.GetPolys().GetConnectivityArray()).reshape(-1,3)
  o=np.load(run+'/pipeline2_out.npz');A=np.array(json.load(open(icp))['gt_transformation']);Ai=np.linalg.inv(A)
  print('==',room,'distinct contact triangles',len(cells))
  for cid,runs in cells.items():
    T=P[C[cid]].astype(float);T=(T@Ai[:3,:3].T+Ai[:3,3])@o['R'].T+o['t'];n=np.cross(T[1]-T[0],T[2]-T[0]);n/=np.linalg.norm(n)
    tilt=np.degrees(np.arccos(abs(n[2])));area=0.5*np.linalg.norm(np.cross(T[1]-T[0],T[2]-T[0]))*1e6
    print(f'  cell {cid}: facet tilt from horizontal {tilt:5.1f} deg, area {area:6.1f} mm2, height above plane {T[:,2].mean()*1000:+.1f} mm | {len(runs)} runs e.g. {runs[0]}')
