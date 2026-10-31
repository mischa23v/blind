"""Bounded saved-geometry plot only; no mapper/planner/GEOS queries."""
import hashlib,json,math,os,pathlib,resource,time
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
os.environ['MPLCONFIGDIR']=str(H/'mpl-cache')
os.environ['XDG_CACHE_HOME']=str(H/'xdg-cache');(H/'xdg-cache').mkdir(exist_ok=True)
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection
from matplotlib.patches import Rectangle,Circle,Patch
from matplotlib.lines import Line2D

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    start=time.monotonic()
    mesh=W/'coffee-recovered-source/textured.obj';proposal=H/'PROPOSALS.json.gz'
    import gzip
    d=json.loads(gzip.decompress(proposal.read_bytes()));q=d['paths'][0];old=q['baselineArmsUnchanged'];repair=q['manualRepair']
    windowsfile=R/'research/independent-2d-route-validator-20261029/actual-coffee-0-to-8-attempt002/INPUT_FREEZE.json'
    windows=json.loads(windowsfile.read_text())['windows']
    if sha(mesh)!=d['meshSHA256']:raise ValueError('mesh changed')
    v=[];f=[]
    for line in mesh.open():
        x=line.split()
        if not x:continue
        if x[0]=='v':v.append([float(z)for z in x[1:]])
        elif x[0]=='f':f.append([int(z.split('/')[0])-1 for z in x[1:]])
    v=np.asarray(v);f=np.asarray(f);tris=v[f];floor=-1.6301633051396203
    # Visualization only: original triangle-centroid height bands, no geometry
    # filling/deletion in planner and no inference that gray/blank means safe.
    heights=tris[:,:,1].mean(axis=1)-floor;floor_mask=np.abs(heights)<.04
    body_mask=(heights>=.05)&(heights<=1.60)
    fig,axes=plt.subplots(1,2,figsize=(13,9),sharex=True,sharey=True)
    fig.subplots_adjust(left=.065,right=.98,top=.86,bottom=.23,wspace=.11)
    styles=[('Original funnel',old['originalNativePoints'],'#be5527','--',2.2),
            ('First centered',old['clearanceGrid']['pointsXYZ'],'#2466a8','-',2.8)]
    repaired=[('Repaired shortest',repair['distanceGrid']['pointsXYZ'],'#398f96','--',2.),
              ('Repaired centered',repair['clearanceGrid']['pointsXYZ'],'#6836a0','-',3.)]
    for ax,arms in zip(axes,[styles,repaired]):
        ax.add_collection(PolyCollection(tris[floor_mask][:,:,[0,2]],facecolors='#d8dce0',edgecolors='none',alpha=.35,rasterized=True))
        ax.add_collection(PolyCollection(tris[body_mask][:,:,[0,2]],facecolors='#606870',edgecolors='none',alpha=.17,rasterized=True))
        for name,(xmin,xmax,zmin,zmax)in windows.items():
            ax.add_patch(Rectangle((xmin,zmin),xmax-xmin,zmax-zmin,facecolor='#cf566122',edgecolor='#b53d4c',hatch='///',lw=1.4,zorder=3))
            ax.text((xmin+xmax)/2,(zmin+zmax)/2,('N'if name.startswith('north')else'S')+' window',ha='center',va='center',fontsize=10,color='#9b2539',weight='bold',zorder=5)
        for name,p,color,ls,lw in arms:
            p=np.asarray(p);ax.plot(p[:,0],p[:,2],color=color,linestyle=ls,lw=lw,zorder=6,label=f'{name}  {sum(math.dist(a,b)for a,b in zip(p,p[1:])):.3f} m')
        s=old['requestedStartXYZ'];g=old['requestedGoalXYZ'];radius=q['edgeFilter']['bodyCircumscribedRadiusPlusMarginMetres']
        ax.add_patch(Circle((s[0],s[2]),radius,fill=False,edgecolor='#262626',ls=':',lw=1.4,zorder=8))
        ax.add_patch(Circle((s[0],s[2]),math.hypot(.45,.30)/2,fill=False,edgecolor='#262626',lw=.9,zorder=8))
        ax.scatter([s[0],g[0]],[s[2],g[2]],s=35,c='#111111',zorder=9)
        ax.annotate('Start 0',(s[0],s[2]),xytext=(5,-16),textcoords='offset points',fontsize=10,weight='bold')
        ax.annotate('Goal 8',(g[0],g[2]),xytext=(-8,11),textcoords='offset points',ha='right',fontsize=10,weight='bold')
        ax.set_xlim(-2.8,2.8);ax.set_ylim(-3.55,3.55);ax.set_aspect('equal');ax.set_xlabel('Source OBJ X (m)');ax.grid(alpha=.12);ax.legend(loc='lower right',fontsize=9,framealpha=.95)
    axes[0].set_ylabel('Source OBJ Z (m)')
    axes[0].set_title('Before: both fail manual body + margin check',fontsize=12,pad=12)
    axes[1].set_title('After: manual-exclusion repair; physical clearance UNKNOWN',fontsize=11,pad=12)
    fig.suptitle('Actual Coffee mesh · fixed start 0 → goal 8',fontsize=18,weight='bold',y=.975)
    fig.text(.5,.925,'Offline source-model debug comparison — NOT a validated walking route',ha='center',fontsize=12,color='#8e2435')
    fig.text(.065,.145,'Hatched rectangles: MANUAL diagnostic windows, not measured table outlines. Gray: original mesh projections only.',fontsize=10)
    fig.text(.065,.113,'Circles at Start: body half-diagonal 0.270 m + separate radial margin 0.150 m = 0.420 m. Equal metre scales.',fontsize=10)
    fig.text(.065,.081,'Repaired routes: no saved 2D window intersection, but only 3.85 mm extra clearance beyond that circle + margin.',fontsize=10,weight='bold',color='#8e2435')
    fig.text(.065,.049,'Body height 1.60 m, full 3D collision, complete floor support, unknown obstacles and live pose remain unverified.',fontsize=10)
    out=H/'coffee-before-after-manual-repair.png';fig.savefig(out,dpi=150,facecolor='white');plt.close(fig)
    receipt={'status':'savedGeometryPlotOnly','inputSHA256':{'mesh':sha(mesh),'proposalsGzip':sha(proposal),'windows':sha(windowsfile)},'outputSHA256':sha(out),'plotSourceSHA256':sha(pathlib.Path(__file__)),'meshCounts':[len(v),len(f)],'floorTrianglesShown':int(floor_mask.sum()),'bodyHeightTrianglesShown':int(body_mask.sum()),'noNewNativeQueries':True,'physicalAuthority':False,'wallSeconds':time.monotonic()-start,'peakRSSKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
    (H/'PLOT_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
if __name__=='__main__':main()
