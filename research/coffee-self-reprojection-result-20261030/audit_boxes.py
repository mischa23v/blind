#!/usr/bin/env python3
"""Independent analytical slab audit of saved rays/boxes; no native library or raster reads."""
import os
for k in ('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS'):os.environ[k]='1'
import pathlib,json,hashlib,importlib.util,resource
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(120,)*2);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
import numpy as np
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent;A=W/'coffee-self-reprojection-attempt-001'
def load(p,name):
 s=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();metric=load(R/'research/coffee-self-reprojection-source-20261030/metrics.py','metric');pose=load(R/'research/coffee-shared-pose-occupancy-source-20261029/pose_contract.py','pose')
r=json.loads((A/'RESULT.json').read_text());metadata=json.loads((W/'coffee-recovered-source/transformations.json').read_text());frames={pathlib.Path(x['file_path']).stem:x for x in metadata['frames']};out={'status':'incomplete','nativeLibraryLoaded':False,'rasterRead':False,'sourceResultSHA256':sha(A/'RESULT.json'),'cases':[]}
for c in r['cases']:
 p=A/c['derivedEvidence']['path'];assert sha(p)==c['derivedEvidence']['sha256'];f=frames[c['frame']];t,origin=pose.frame_contract(f);inv=np.asarray(metric.inverse3([row[:3]for row in t[:3]]));rot=np.asarray([x[:3]for x in t[:3]])
 with np.load(p,allow_pickle=False)as d:idx=d['pixelIndex'];centers=d['observedCenter'];savedentry=d['entryAxial'];savedcenter=d['centerAxial']
 rr=idx//738;cc=idx%738;direction=np.column_stack(((cc-f['cx'])/f['fl_x'],(rr-f['cy'])/f['fl_y'],np.ones(len(idx))))@rot.T;nd=direction.astype(np.float32).astype(np.float64);no=np.asarray(origin,dtype=np.float32).astype(np.float64)
 center32=centers.astype(np.float32);low=(center32-np.float32(.025)).astype(np.float64);high=(center32+np.float32(.025)).astype(np.float64)
 assert (nd!=0).all() # actual fixed rays: fail rather than invent parallel handling
 t0=(low-no)/nd;t1=(high-no)/nd;near=np.minimum(t0,t1);far=np.maximum(t0,t1);enter=near.max(axis=1);leave=far.min(axis=1);intersects=(enter<=leave)&(leave>=0)
 predicted=no+enter[:,None]*nd;z=(centers-np.asarray(origin))@inv[2]-savedcenter;analytic=(predicted-np.asarray(origin))@inv[2]-z
 # Entry face is axis-aligned voxel face, not a fitted physical floor/object normal.
 axis=near.argmax(axis=1);cosine=np.abs(nd[np.arange(len(nd)),axis])/np.linalg.norm(nd,axis=1)
 out['cases'].append({'frame':c['frame'],'kind':c['kind'],'hits':len(idx),'analyticalBoxIntersections':int(intersects.sum()),'nonIntersections':int((~intersects).sum()),'analyticMinusSavedEntryAxialMetres':metric.distributions(analytic-savedentry),'voxelEntryFaceAbsCosine':metric.distributions(cosine),'normalMeaning':'axis-aligned voxel face only, not observed physical surface normal'})
out['status']='completed-analytical-box-audit'
with(H/'ANALYTICAL_BOX_AUDIT.json').open('x')as f:json.dump(out,f,indent=2,allow_nan=False);f.write('\n')
for c in out['cases']:print(c['kind'],c['frame'],'nonintersection',c['nonIntersections'],'absolute max',c['analyticMinusSavedEntryAxialMetres']['absolute']['max'])
