"""Supplementary pose algebra, not sensor or world-frame validation."""
import os,resource,json,time
from pathlib import Path
resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(30,30))
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
os.environ['OPENBLAS_NUM_THREADS']='1'
import numpy as np
from PIL import Image
here=Path(__file__).resolve().parent
out=[]
for i in range(4):
 p=np.loadtxt(here.parent/f'7scenes-frame-{i:06d}.pose.txt');r=p[:3,:3]
 d=np.array(Image.open(here.parent/f'7scenes-frame-{i:06d}.depth.png'));v,u=np.nonzero((d>0)&(d<65535));z=d[v,u].astype(float)/1000
 x=np.column_stack(((u-320)*z/585,(v-240)*z/585,z));w=x@r.T+p[:3,3]
 approximate=(w-p[:3,3])@r
 out.append({'frame_index':i,'transpose_as_inverse_roundtrip_max_abs_m':float(np.max(np.abs(approximate-x))),'transpose_vs_general_inverse_rotation_max_abs':float(np.max(np.abs(r.T-np.linalg.inv(r))))})
(here/'POSE_FOLLOWUP.json').write_text(json.dumps({'frames':out,'interpretation':'Nonorthogonality is observed. Cause not established; not evidence of wrong convention, bad sensor, or scale. Inverting axis convention does not itself establish orthogonality. Text precision alone has not been shown to explain residuals.'},indent=2)+'\n')
print(out)
