"""First-hit virtual depth rays through a REAL apartment triangle mesh.
Synthetic camera/poses and high-confidence samples; no sunlight/noise/latency model.
"""
import argparse
import json
from pathlib import Path
import numpy as np
from plyfile import PlyData
import trimesh

root=Path(__file__).resolve().parents[1];out=root/'artifacts'/'real-scene'
parser=argparse.ArgumentParser()
parser.add_argument('--width',type=int,default=64)
parser.add_argument('--height',type=int,default=48)
parser.add_argument('--prefix',default='room')
args=parser.parse_args()
if not (2<=args.width<=512 and 2<=args.height<=384):
    parser.error('Ray image size must be between 2x2 and 512x384.')
if not args.prefix or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in args.prefix):
    parser.error('Output prefix must contain only lowercase letters, digits or hyphens.')
p=PlyData.read(out/'apt-initial.ply',known_list_len={'face':{'vertex_indices':3}})
v=p['vertex'];vertices=np.column_stack([v[a] for a in 'xyz'])
mesh=trimesh.Trimesh(vertices=vertices,faces=p['face']['vertex_indices'],process=False)
try:
    from trimesh.ray.ray_pyembree import RayMeshIntersector
    raycaster=RayMeshIntersector(mesh)
    backend='Embree first-hit rays'
except ImportError:
    from trimesh.ray.ray_triangle import RayMeshIntersector
    raycaster=RayMeshIntersector(mesh)
    backend='trimesh triangle first-hit rays (slow)'
print(backend,flush=True)
floor=json.loads((out/'inspection.json').read_text())['estimatedFloorZ']
# Positions chosen from the inspected reconstruction BEFORE detector outcomes.
poses=[('north-furniture',3.5,6.9,0,1,'obstacle'),
       ('west-wall',1.5,6.5,-1,0,'obstacle'),
       ('east-wall',4.9,5.8,1,0,'obstacle'),
       ('south-partition',2.7,4.3,0,-1,'obstacle'),
       ('central-floor',2.6,5.5,0,1,'observing'),
       ('central-floor-south',2.4,7.4,0,-1,'observing')]
cases=[];preview=[]
# Favourable virtual camera: 70 x 70 degree FOV, 50 degrees downward, 64 x 48.
pitch=np.deg2rad(50);u,w=np.meshgrid(np.linspace(-1,1,args.width),np.linspace(-1,1,args.height))
for name,x,y,fx,fy,expected in poses:
    origin=np.array([x,y,floor+1.2]);f=np.array([fx,fy,0.]);up=np.array([0.,0.,1.]);right=np.cross(f,up)
    optical=f*np.cos(pitch)-up*np.sin(pitch)
    image_up=f*np.sin(pitch)+up*np.cos(pitch)
    rays=optical+u.ravel()[:,None]*np.tan(np.deg2rad(35))*right+w.ravel()[:,None]*np.tan(np.deg2rad(35))*image_up
    rays/=np.linalg.norm(rays,axis=1)[:,None]
    hits=[]
    for start in range(0,len(rays),128):
        batch=rays[start:start+128]
        locations,_,_=raycaster.intersects_location(np.tile(origin,(len(batch),1)),batch,multiple_hits=False)
        hits.append(locations[np.linalg.norm(locations-origin,axis=1)<5])
    hits=np.concatenate(hits)
    points=hits[:,[0,2,1]]
    cases.append(dict(id=name,group='real-room-virtual-rays',expected=expected,
        camera=dict(x=x,y=floor+1.2,z=y),forward=dict(x=fx,y=0,z=fy),floor=floor,
        points=np.round(points,5).tolist(),assumptions=f'Real initial apartment mesh; synthetic pose, 70x70 FOV, 50-degree downward camera, {args.width}x{args.height} rays; ideal confidence; manually labelled geometry expectation, no physical trial.'))
    preview.append(dict(id=name,camera=origin.tolist(),direction=f.tolist(),expected=expected,returnedPoints=len(hits),rayBackend=backend,width=args.width,height=args.height))
    print(name,len(hits),flush=True)
(out/f'{args.prefix}-replay-input.json').write_text(json.dumps(cases,separators=(',',':')))
(out/f'{args.prefix}-poses.json').write_text(json.dumps(preview,indent=2))
print('Wrote six real-mesh virtual sensor cases.')
