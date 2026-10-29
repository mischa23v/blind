"""Plot saved paths over original mesh only; no new planner or GEOS queries."""
import hashlib
import json
import math
import os
import pathlib
import resource
import tempfile
import time

H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
CACHE=tempfile.TemporaryDirectory(prefix='joint-cost-plot-')
os.environ['MPLCONFIGDIR']=CACHE.name
os.environ['XDG_CACHE_HOME']=CACHE.name
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection
from matplotlib.patches import Rectangle,Circle


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    started=time.monotonic()
    proposal=W/'coffee-clearance-comparison-attempt-003/comparison/PROPOSALS.json'
    mesh=W/'coffee-recovered-source/textured.obj'
    windows_file=R/'research/independent-2d-route-validator-20261029/actual-coffee-0-to-8-attempt002/INPUT_FREEZE.json'
    summary_file=H/'PUBLIC_SAFE_RESULT.json'
    data=json.loads(proposal.read_text());q=data['paths'][0]
    summary=json.loads(summary_file.read_text())
    assert sha(proposal)==summary['proposalSHA256'] and sha(mesh)==data['meshSHA256']
    windows=json.loads(windows_file.read_text())['windows']
    vertices=[];faces=[]
    for line in mesh.open():
        fields=line.split()
        if not fields:continue
        if fields[0]=='v':vertices.append([float(v) for v in fields[1:]])
        elif fields[0]=='f':faces.append([int(v.split('/')[0])-1 for v in fields[1:]])
    vertices=np.asarray(vertices);faces=np.asarray(faces);triangles=vertices[faces]
    floor=-1.6301633051396203
    # Original mesh height bands are VISUALIZATION ONLY, never inferred support.
    heights=triangles[:,:,1].mean(axis=1)-floor
    floor_mask=np.abs(heights)<.04;body_mask=(heights>=.05)&(heights<=1.60)
    old=np.asarray(q['previousManualRepairArmsUnchanged']['clearanceGrid']['pointsXYZ'])
    new=np.asarray(q['manualRepair']['clearanceGrid']['pointsXYZ'])
    old_metrics=summary['arms']['previousCentered'];new_metrics=summary['arms']['jointCentered']
    start=q['baselineArmsUnchanged']['requestedStartXYZ'];goal=q['baselineArmsUnchanged']['requestedGoalXYZ']
    radius=summary['bodyCirclePlusRadialMarginMetres']
    fig,axes=plt.subplots(1,2,figsize=(14,10),sharex=True,sharey=True)
    fig.subplots_adjust(left=.065,right=.98,top=.84,bottom=.29,wspace=.10)
    for index,(ax,path,metrics,color) in enumerate(zip(axes,[old,new],[old_metrics,new_metrics],['#8056a6','#176c9b'])):
        ax.add_collection(PolyCollection(triangles[floor_mask][:,:,[0,2]],facecolors='#d8dce0',edgecolors='none',alpha=.40,rasterized=True))
        ax.add_collection(PolyCollection(triangles[body_mask][:,:,[0,2]],facecolors='#606870',edgecolors='none',alpha=.17,rasterized=True))
        for name,(a,b,c,d) in windows.items():
            ax.add_patch(Rectangle((a,c),b-a,d-c,facecolor='#cf566122',edgecolor='#b53d4c',hatch='///',lw=1.4,zorder=3))
            ax.text((a+b)/2,(c+d)/2,('N' if name.startswith('north') else 'S')+' window',ha='center',va='center',fontsize=10,color='#9b2539',weight='bold',zorder=5)
        if index:
            ax.plot(old[:,0],old[:,2],color='#8056a6',ls='--',lw=1.5,alpha=.65,zorder=5,label='Previous path (reference)')
        ax.plot(path[:,0],path[:,2],color=color,lw=2.8,zorder=6,label=('Previous' if index==0 else 'Joint-ranked')+f" path  {metrics['nativeGridLengthMetres']:.3f} m")
        ax.add_patch(Circle((start[0],start[2]),radius,fill=False,edgecolor='#222222',ls=':',lw=1.4,zorder=8))
        ax.add_patch(Circle((start[0],start[2]),math.hypot(.45,.30)/2,fill=False,edgecolor='#222222',lw=.9,zorder=8))
        ax.scatter([start[0],goal[0]],[start[2],goal[2]],s=35,c='#111111',zorder=9)
        ax.annotate('Start 0',(start[0],start[2]),xytext=(5,-16),textcoords='offset points',fontsize=10,weight='bold')
        ax.annotate('Goal 8',(goal[0],goal[2]),xytext=(-8,11),textcoords='offset points',ha='right',fontsize=10,weight='bold')
        ax.set_xlim(-2.8,2.8);ax.set_ylim(-3.55,3.55);ax.set_aspect('equal')
        ax.set_xlabel('Source OBJ X (m)',fontsize=10);ax.grid(alpha=.12)
        ax.legend(loc='lower right',fontsize=9,framealpha=.95)
        label='Before: native-wall ranking' if index==0 else 'After: joint native + manual ranking'
        ax.set_title(label+f"\nMinimum manual residual: {1000*metrics['minimumSavedResidualBeyondBodyCircleAndMarginMetres']:.2f} mm",fontsize=12,pad=13,color=color)
    axes[0].set_ylabel('Source OBJ Z (m)',fontsize=10)
    fig.suptitle('Coffee 0 → 8: more space around the manual exclusions',fontsize=18,weight='bold',y=.975)
    fig.text(.5,.925,'Actual saved paths · unchanged endpoints and body profile · NOT a validated walking route',ha='center',fontsize=12,color='#8e2435')
    fig.text(.065,.215,'Manual residual beyond body-circle + margin: 3.85 → 129.58 mm. Route adds 0.264 m (+3.64%).',fontsize=12,weight='bold')
    fig.text(.065,.175,'Tradeoff: sampled native-wall p10 proxy falls 0.255 → 0.155 m; its minimum stays 0.122 m.',fontsize=11,color='#8e2435')
    fig.text(.065,.135,'Hatched windows are MANUAL, not measured table outlines. Gray is the original mesh projection, not proved free space/support.',fontsize=10)
    fig.text(.065,.102,'Start circles: body half-diagonal 0.270 m + radial margin 0.150 m = 0.420 m. Equal metre scales; path labels exclude connectors.',fontsize=10)
    fig.text(.065,.069,'New path including requested connectors: 7.541 m. All 143 saved segments have both window checks; no saved window contact.',fontsize=10)
    fig.text(.065,.036,'Full 3D body collision, complete floor support, missing obstacles and live pose remain UNKNOWN. No physical authority.',fontsize=10,weight='bold',color='#8e2435')
    output=H/'coffee-joint-cost-comparison.png';fig.savefig(output,dpi=150,facecolor='white');plt.close(fig)
    receipt={'status':'savedGeometryPlotOnly','inputSHA256':{'mesh':sha(mesh),'proposals':sha(proposal),'windows':sha(windows_file),'publicSummary':sha(summary_file)},
             'outputSHA256':sha(output),'plotSourceSHA256':sha(pathlib.Path(__file__)),
             'meshCounts':[len(vertices),len(faces)],'floorTrianglesShown':int(floor_mask.sum()),'bodyHeightTrianglesShown':int(body_mask.sum()),
             'noNewPlannerOrGeometryQueries':True,'physicalAuthority':False,
             'wallSeconds':time.monotonic()-started,'peakRSSKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
    (H/'PLOT_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt))


if __name__=='__main__':main()
