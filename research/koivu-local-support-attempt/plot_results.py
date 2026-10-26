"""Plot saved failed-map evidence; no geometry or classification changes."""
import argparse
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from local_support import paths

def main(ws,out):
    _,branch,_=paths(ws);z=np.load(out/'PHONE_MAP.npz')
    old=np.load(branch/'derived/pipeline-outputs/koivu_5cm_occthres_split0.7.npz')
    origin=z['lo'][:2]*.05;shape=z['walk'].shape
    extent=[origin[0],origin[0]+shape[0]*.05,origin[1],origin[1]+shape[1]*.05]
    fig,axes=plt.subplots(1,3,figsize=(14,6))
    fig.subplots_adjust(left=.055,right=.99,bottom=.15,top=.80,wspace=.25)
    panels=[('Supplied permissive mask\n11,559 cells',old['walk']),('Observed support with view agreement\n8,550 cells',z['support']),('Strict experimental admission\n38 cells; no full-body start',z['walk'])]
    for ax,(title,data)in zip(axes,panels):
        ax.imshow(data.T,origin='lower',extent=extent,cmap='gray',vmin=0,vmax=1,interpolation='nearest')
        ax.set_title(title,fontsize=11,pad=12);ax.set_xlabel('Phone level X (m)');ax.set_ylabel('Phone level Y (m)')
    fig.suptitle('Failed local-support attempt',fontsize=15,y=.97)
    fig.text(.5,.91,'White cells are model candidates, not verified clearance. Body and margins unchanged.',ha='center',fontsize=11)
    fig.savefig(out/'MAP_COMPARISON.png',dpi=130);plt.close(fig)

if __name__=='__main__':
    from pathlib import Path
    p=argparse.ArgumentParser();p.add_argument('--audit-root',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();main(a.audit_root,a.out)
