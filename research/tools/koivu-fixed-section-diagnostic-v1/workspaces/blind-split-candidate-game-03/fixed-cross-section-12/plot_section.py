"""Display fixed measurement receipt; never choose a section from reference results."""
from pathlib import Path
import json,numpy as np,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
HERE=Path(__file__).resolve().parent;GAME=HERE.parent
r=json.loads((HERE/'RESULT.json').read_text());c=np.array(r['sourceAnchorXY']);n=np.array(r['sourceUnitCrossSectionNormal'])
with np.load(GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz')as z,np.load(GAME/'inputs/koivu_5cm_occthres_split0.7.npz')as m:
 o=z['lo'][:2]*.05;mask=m['walk'];ref=(z['ref_n']>0)&np.isfinite(z['ref_floor_h'])&~np.isfinite(z['ref_low_max'])&~np.isfinite(z['ref_body_max'])
fig=plt.figure(figsize=(12,8));gs=fig.add_gridspec(2,2,height_ratios=[3,1]);a=fig.add_subplot(gs[0,0]);b=fig.add_subplot(gs[0,1]);bottom=fig.add_subplot(gs[1,:]);extent=[o[0],o[0]+mask.shape[0]*.05,-o[1]-mask.shape[1]*.05,-o[1]]
for ax,arr,title in [(a,mask,'Supplied phone permissive walk'),(b,ref,'Saved reference vertex-column proxy')]:
 ax.imshow(arr.T[::-1],origin='lower',extent=extent,cmap='gray',vmin=0,vmax=1,alpha=.65);line=np.array([c-2*n,c+2*n]);ax.plot(line[:,0],-line[:,1],c='#0066cc',lw=2);ax.scatter(c[0],-c[1],marker='*',s=100,c='orange',edgecolors='black',zorder=5);ax.set_xlim(c[0]-1.8,c[0]+.8);ax.set_ylim(-c[1]-.9,-c[1]+.9);ax.set_aspect('equal');ax.set_title(title);ax.set_xlabel('Game X (m)');ax.set_ylabel('Game Z = −source Y (m)')
for y,key,color in [(1,'phonePermissiveWalk','#0074b3'),(0,'referenceVertexColumnProxy','#278854')]:
 bottom.plot([-2,2],[y,y],color='#bbb',lw=12,solid_capstyle='butt')
 for v in r['clearRunsByModelProxy'][key]:
  bottom.plot([v['offsetStartMetres'],v['offsetEndMetres']],[y,y],color=color,lw=12,solid_capstyle='butt')
  if v['widthMetres']>.4:bottom.text((v['offsetStartMetres']+v['offsetEndMetres'])/2,y+.18,f"{v['widthMetres']:.3f} m",ha='center',fontsize=11)
bottom.axvline(0,c='orange',ls='--',label='Frame 39 camera anchor');bottom.set_yticks([0,1],['Reference proxy','Phone walk']);bottom.set_ylim(-.4,1.6);bottom.set_xlim(-2,2);bottom.set_xlabel('Signed distance along the SAME frozen cross-section (m)');bottom.legend(loc='lower right',fontsize=8);bottom.grid(axis='x',alpha=.3)
fig.suptitle('One fixed passage section: map disagreement, not a physical clearance measurement',fontsize=14);fig.text(.08,.025,'5 cm source grid. Anchor: original frame 39; section normal to camera displacement from frame 38 to 40.\nReference proxy: floor samples present; no vertices 1.5–180 cm above global plane. Not a triangle-volume test.\nExact photo gap identity and semantic wall/chair boundaries unverified; no route or map changes.',fontsize=9);fig.subplots_adjust(bottom=.18,top=.90,hspace=.45,wspace=.25);fig.savefig(HERE/'FIXED_SECTION_GAME_XZ.png',dpi=150)
