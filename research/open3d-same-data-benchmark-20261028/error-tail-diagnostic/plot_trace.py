from pathlib import Path
import json
import numpy as np
from PIL import Image
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
R=Path(__file__).resolve().parent;B=R.parent/'fresh-run/inputs/room_datasets/koivu/iphone/long_capture';j=json.loads((R/'TRAINING_TRACE.json').read_text())
fig,axs=plt.subplots(1,3,figsize=(15,8),constrained_layout=True)
axs[0].imshow(Image.open(B/'images/frame_00074.jpg'));axs[0].set_title('Training 74 RGB: projected suspect points')
d=np.asarray(Image.open(B/'depth/frame_00074.png'))/1000
im=axs[1].imshow(d,vmin=0,vmax=4,cmap='viridis');axs[1].set_title('Training 74 recorded depth (m)');fig.colorbar(im,ax=axs[1],shrink=.6)
axs[2].imshow(Image.open(R/'local-rgb/frame_00228.jpg'));axs[2].set_title('Held-out 228 RGB: source rays')
for i,p in enumerate(j['points'][:3]):
 o=next(o for o in p['observations'] if o['frame']=='frame_00074');x,y=o['projectedPixel']
 for a in axs[:2]:a.scatter([x],[y],s=35,facecolors='none',edgecolors='red');a.annotate(str(i+1),(x,y),xytext=(x+25,y-10),color='red',arrowprops={'arrowstyle':'-','color':'red'})
 x,y=p['pixel'];axs[2].scatter([x],[y],s=35,facecolors='none',edgecolors='red');axs[2].text(x-30,y,str(i+1),color='red')
for a in axs:a.set_xlim(0,738);a.set_ylim(994,0);a.set_xlabel('Original column');a.set_ylabel('Original row')
fig.suptitle('Fixed points under supplied poses — appearance only, not clearance or verified pose consistency')
fig.savefig(R/'local-figures/trace_frame74.png',dpi=120)
