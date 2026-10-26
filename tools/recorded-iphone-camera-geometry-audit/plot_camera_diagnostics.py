"""Separate analytical plots of actual arrays and Swift-returned camera points."""
from pathlib import Path
import hashlib,json,sys
import numpy as np
from PIL import Image
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap,BoundaryNorm

ROOT=Path(__file__).resolve().parent

def main():
    manifest=json.loads(Path(sys.argv[1]).read_text());out=Path(sys.argv[2]);summary=json.loads((out/'geometry-result.json').read_text())
    plots=out/'diagnostics';plots.mkdir(exist_ok=False)
    clouds=[np.genfromtxt(out/f['pointFile'],delimiter=',',names=True) for f in summary['frames']]
    xyz=np.concatenate([np.column_stack([a['x_camera_m'],a['y_camera_m'],a['z_camera_m']]) for a in clouds])
    lower=np.minimum(xyz.min(axis=0),0);upper=np.maximum(xyz.max(axis=0),0);pad=np.maximum((upper-lower)*.05,.02);lower-=pad;upper+=pad
    depth_cmap=plt.get_cmap('viridis').copy();depth_cmap.set_bad('#eeeeee');depth_cmap.set_under('#e6952d');depth_cmap.set_over('#d04ab3')
    conf_cmap=ListedColormap(['#777777','#d99a2b','#3675ba','#c64683']);conf_norm=BoundaryNorm([-.5,.5,1.5,2.5,3.5],4)
    admission_cmap=ListedColormap(['#dddddd','#9a7aa0','#3675ba']);admission_norm=BoundaryNorm([-.5,.5,1.5,2.5],3)
    frame_stats=[]
    for source,result,cloud in zip(manifest['frames'],summary['frames'],clouds):
        i=source['id'];h=source['height'];w=source['width'];d=np.fromfile(source['depthPath'],dtype='<f4').reshape(h,w).astype(np.float64);c=np.fromfile(source['confidencePath'],dtype=np.uint8).reshape(h,w)
        finite=np.isfinite(d);positive=finite&(d>0);sampled=np.zeros((h,w),dtype=bool);sampled[::2,::2]=True
        admitted=np.zeros((h,w),dtype=bool);rows=cloud['row'].astype(int);cols=cloud['column'].astype(int);admitted[rows,cols]=True
        if len(cloud)!=result['projectedPoints'] or admitted.sum()!=len(cloud):raise ValueError('point identity count mismatch')
        expected=sampled&(c==2)&finite&(d>=.15)&(d<=5.)
        if not np.array_equal(admitted,expected):raise ValueError('Swift-returned pixel identities differ from source admission cross-check')
        values={'frameID':i,'confidenceCounts012Other':[int((c==v).sum()) for v in range(3)]+[int((c>2).sum())],
            'finitePositive':int(positive.sum()),'zeroDepth':int((d==0).sum()),'negativeDepth':int((finite&(d<0)).sum()),'nonfiniteDepth':int((~finite).sum()),
            'positivePolicyRangeExcluded':int((positive&((d<.15)|(d>5.))).sum()),
            'displayClippedPositiveBelow015':int((positive&(d<.15)).sum()),'displayClippedAbove125':int((positive&(d>1.25)).sum()),
            'attemptedStridePixels':int(sampled.sum()),'admittedAndProjectedPixels':int(admitted.sum()),'unsampledPixels':int((~sampled).sum()),'tiles':[]}
        tile_admission=np.zeros((6,8),dtype=int)
        for tr in range(6):
            for tc in range(8):
                sl=np.s_[tr*32:(tr+1)*32,tc*32:(tc+1)*32];dd=d[sl];cc=c[sl];ff=np.isfinite(dd);pp=ff&(dd>0);ss=sampled[sl];aa=admitted[sl]
                tile={'row':tr,'column':tc,'fullPixels':1024,'confidenceCounts012Other':[int((cc==v).sum()) for v in range(3)]+[int((cc>2).sum())],
                    'finitePositive':int(pp.sum()),'zeroDepth':int((dd==0).sum()),'negativeDepth':int((ff&(dd<0)).sum()),'nonfiniteDepth':int((~ff).sum()),
                    'positivePolicyRangeExcluded':int((pp&((dd<.15)|(dd>5.))).sum()),'strideAttempted':int(ss.sum()),'admitted':int(aa.sum()),'strideRejected':int((ss&~aa).sum()),'unsampled':int((~ss).sum())}
                values['tiles'].append(tile);tile_admission[tr,tc]=aa.sum()
        frame_stats.append(values)
        display=np.ma.array(d,mask=~positive);confidence_display=np.where(c<=2,c,3);admission_display=np.zeros((h,w),dtype=np.uint8);admission_display[sampled]=1;admission_display[admitted]=2
        fig,axes=plt.subplots(2,2,figsize=(11,7),layout='constrained')
        a=axes[0,0].imshow(display,cmap=depth_cmap,vmin=.15,vmax=1.25,origin='upper',interpolation='nearest');fig.colorbar(a,ax=axes[0,0],label='Original axial depth [m]; display only',extend='both')
        axes[0,0].set_title(f'Analytic depth; invalid={values["zeroDepth"]+values["negativeDepth"]+values["nonfiniteDepth"]}\nclipped low/high={values["displayClippedPositiveBelow015"]}/{values["displayClippedAbove125"]}')
        b=axes[0,1].imshow(confidence_display,cmap=conf_cmap,norm=conf_norm,origin='upper',interpolation='nearest');fig.colorbar(b,ax=axes[0,1],ticks=[0,1,2,3],label='Original confidence; 3 means other')
        axes[0,1].set_title('Analytic confidence: 0 low / 1 medium / 2 high\nHigh confidence is not clearance')
        t=axes[1,0].imshow(admission_display,cmap=admission_cmap,norm=admission_norm,origin='upper',interpolation='nearest');fig.colorbar(t,ax=axes[1,0],ticks=[0,1,2],label='0 unsampled / 1 rejected / 2 projected')
        axes[1,0].set_title('Actual shared-policy pixel admission\nNo interpolation or filled holes')
        q=axes[1,1].imshow(tile_admission,cmap='Blues',vmin=0,vmax=256,origin='upper',interpolation='nearest');fig.colorbar(q,ax=axes[1,1],label='Admitted / 256 attempted per tile')
        axes[1,1].set_title('8 × 6 image tiles—not body coverage')
        for ax in axes.flat:ax.set_xlabel('Image column / tile');ax.set_ylabel('Image row / tile')
        fig.suptitle(f'Analytical recorded-data diagnostics · frame {i} · t={source["originalRelativeTimestamp"]:.6f}s\nNot sensor imagery, physical accuracy, obstacle recall or clearance',fontsize=11)
        fig.savefig(plots/f'frame-{i}-depth-confidence-admission.png',dpi=120);plt.close(fig)
        fig=plt.figure(figsize=(8,6),layout='constrained');ax=fig.add_subplot(111,projection='3d')
        ax.scatter(cloud['x_camera_m'],cloud['y_camera_m'],cloud['z_camera_m'],s=1.2,c='#3675ba',alpha=.65,rasterized=True)
        ax.scatter([0],[0],[0],c='#222222',s=30);ax.quiver(0,0,0,0,0,-.15,color='#222222',arrow_length_ratio=.2)
        ax.set(xlabel='Camera X right [m]',ylabel='Camera Y up [m], not gravity',zlabel='Camera Z [m]; forward is negative',xlim=(lower[0],upper[0]),ylim=(lower[1],upper[1]),zlim=(lower[2],upper[2]))
        ax.set_box_aspect(upper-lower);ax.view_init(elev=23,azim=135)
        ax.set_title(f'Analytical camera-point scatter · frame {i}\n{len(cloud):,} actual shared-projection points; no inter-frame registration',fontsize=10)
        fig.savefig(plots/f'frame-{i}-camera-point-scatter.png',dpi=120);plt.close(fig)
    t=[f['originalRelativeTimestamp'] for f in summary['frames']]
    fig,axes=plt.subplots(3,1,figsize=(10,9),layout='constrained')
    for component in ['fx','fy','cx','cy']:
        axes[0].plot(t,[f['actualSharedDepthIntrinsics'][component] for f in summary['frames']],marker='.',label=component)
    axes[0].set_ylabel('Depth-resolution coefficient [px]');axes[0].legend(ncol=4);axes[0].set_title('Actual per-frame intrinsics—not global K repeated')
    for key,label in [('rgbPixelCentreSpan','RGB'),('depthPixelCentreSpan','depth'),('admittedRayEnvelope','admitted ray envelope')]:
        axes[1].plot(t,[f[key]['horizontalDegrees'] for f in summary['frames']],marker='.',label=label+' horizontal')
        axes[1].plot(t,[f[key]['verticalDegrees'] for f in summary['frames']],linestyle='--',label=label+' vertical')
    axes[1].set_ylabel('Intrinsic/observed ray span [degrees]');axes[1].legend(fontsize=7,ncol=2);axes[1].set_title('Pixel-centre ray spans / envelope—not physical lens FoV or filled coverage')
    axes[2].plot(t,[f['projectedPoints'] for f in summary['frames']],marker='o',label='admitted/projected');axes[2].axhline(12288,color='#888888',linestyle=':',label='stride attempted')
    axes[2].set_ylabel('Pixels per frame');axes[2].legend();axes[2].set_xlabel('Original relative timestamp [s]')
    fig.suptitle('Eight-frame camera-relative diagnostics only; no physical accuracy or navigation claim')
    fig.savefig(plots/'eight-frame-summary.png',dpi=120);plt.close(fig)
    result={'scope':'Original array distributions and analytical displays only, not accuracy/recall/body coverage','displayDepthMetres':[.15,1.25],'nativeAdmissionDepthMetres':[.15,5.0],
        'confidenceOrDepthInterpolated':False,'holesFilled':False,'pointCloudFramesRegistered':False,'pointDisplaySubsampled':False,'sharedPointIdentityCrossCheck':True,
        'images':[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(plots.glob('*.png'))],
        'frames':frame_stats}
    (out/'distribution-diagnostics.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'analyticalPNGs':len(result['images']),'frameCount':len(frame_stats),'sharedPointIdentityCrossCheck':True}))

if __name__=='__main__':main()
