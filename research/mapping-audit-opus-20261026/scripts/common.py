import json,numpy as np
from PIL import Image
import os
D=os.environ['KOIVU_LONG_CAPTURE'].rstrip('/')+'/'  # extracted room_datasets/koivu/iphone/long_capture
T=json.load(open(D+'transformations.json'))['frames']
def depth(f):return np.array(Image.open(D+f['depth_file_path'][2:])).astype(np.float64)*.001
def rays(f,center_offset=.5,block=False):
  h,w=int(f['h']),int(f['w']);rr,cc=np.indices((h,w),dtype=np.float64)
  if block: # LiDAR sample centre: 4x nearest upscale then 15px crop
    rr=((rr+15)//4)*4+2-15-.5;cc=((cc+15)//4)*4+2-15-.5
  return np.stack(((cc+center_offset-f['cx'])/f['fl_x'],-(rr+center_offset-f['cy'])/f['fl_y'],-np.ones_like(rr)),-1)
def world(f,d,mode='axial',**kw):
  r=rays(f,**kw)
  if mode=='range': r=r/np.linalg.norm(r,axis=-1,keepdims=True)
  c=np.array(f['transform_matrix']);p=(r*d[...,None]).reshape(-1,3)
  return p@c[:3,:3].T+c[:3,3]
