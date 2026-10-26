"""Statistical local floor-support layer (add-only), rules fixed before running.

Per 5 cm column, from LiDAR-native samples of ALL frames (poses = the run's refined poses), with each frame's
measured floor offset removed (estimation only; samples are not deleted), weights 1/sigma(range)^2:
  mode  = 1 cm histogram mode of samples with |h| <= 10 cm
  core  = samples within +-2.5 cm of mode;  s = weighted mean of core;  SE = 1/sqrt(sum w)
  raised = fraction of band samples above s + 2.5 cm + 2 sigma_i ; sunken = fraction below s - 2.5 cm - 2 sigma_i
SUPPORT if n_core >= 30, frames >= 3, |s| <= 2.5 cm, SE <= 5 mm, raised < 0.15, sunken < 0.15,
and every supported 8-neighbour differs by <= 2 cm (otherwise: step edge -> not support).
Obstacle, unknown, below-floor and low-band rules of the map are unchanged; this layer can only add support.
usage: support.py <poses_dir> <run_dir> [inject]   (inject: run fixtures on synthetic geometry instead)
"""
import sys,os,json,time
import numpy as np
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import pipeline as PL
RULE=dict(band=.10,core=.025,max_abs_s=.025,max_se=.005,min_n=30,min_frames=3,max_raised=.15,max_sunken=.15,max_step=.02,sigma_edges=[0,1.0,1.5,2.0,2.5,3.0,3.5,4.5,8.0])
RES=.05

def samples(d,R,t):
    T=json.load(open(os.path.join(d,'transformations.json')))['frames'];C=np.array([f['transform_matrix'] for f in T])
    P,F,_=PL.lidar_samples(d,T);o=np.argsort(F,kind='stable');P=P[o];F=F[o]
    Pl=P@R.T+t;Cl=C[:,:3,3]@R.T+t;return Pl,F,Cl,len(T)

def support_layer(Pl,F,Cl,nfr,lo,H,W,calib_mask):
    h=Pl[:,2].astype(np.float64);off=PL.frame_offsets(h,F,np.c_[Pl[:,:2],h],nfr);h=h-off[F]
    rng=np.linalg.norm(Pl-Cl[F],axis=1)
    band=np.abs(h)<=RULE['band'];i=np.floor(Pl[band,0]/RES).astype(int)-lo[0];j=np.floor(Pl[band,1]/RES).astype(int)-lo[1]
    ok=(i>=0)&(i<H)&(j>=0)&(j<W);col=(i*W+j)[ok];hb=h[band][ok];rb=rng[band][ok];fb=F[band][ok]
    edges=np.array(RULE['sigma_edges']);cal=calib_mask.ravel()[col];sig=[]
    for a,b in zip(edges[:-1],edges[1:]):
        m=cal&(rb>=a)&(rb<b)&(np.abs(hb)<.05);x=hb[m];sig.append(1.4826*np.median(np.abs(x-np.median(x))) if m.sum()>500 else np.nan)
    sig=np.array(sig);sig=np.where(np.isfinite(sig),sig,np.nanmax(sig));si=sig[np.clip(np.searchsorted(edges,rb,side='right')-1,0,len(sig)-1)];w=1/si**2
    o=np.argsort(col,kind='stable');col=col[o];hb=hb[o];w=w[o];si=si[o];fb=fb[o]
    u,st,cnt=np.unique(col,return_index=True,return_counts=True)
    s=np.full(H*W,np.nan);se=np.full(H*W,np.nan);n=np.zeros(H*W,int);nf=np.zeros(H*W,int);rai=np.full(H*W,np.nan);sun=np.full(H*W,np.nan)
    bins=np.arange(-RULE['band'],RULE['band']+1e-9,.01)
    for c,a,k in zip(u,st,cnt):
        x=hb[a:a+k];ww=w[a:a+k];ss=si[a:a+k]
        hist,_=np.histogram(x,bins=bins);mode=bins[np.argmax(hist)]+.005
        core=np.abs(x-mode)<=RULE['core']
        if core.sum()<3:continue
        sv=np.sum(ww[core]*x[core])/np.sum(ww[core]);s[c]=sv;se[c]=1/np.sqrt(np.sum(ww[core]));n[c]=int(core.sum());nf[c]=len(np.unique(fb[a:a+k][core]))
        rai[c]=np.mean(x>sv+RULE['core']+2*ss);sun[c]=np.mean(x<sv-RULE['core']-2*ss)
    s,se,n,nf,rai,sun=(a.reshape(H,W) for a in (s,se,n,nf,rai,sun))
    cand=(n>=RULE['min_n'])&(nf>=RULE['min_frames'])&(np.abs(s)<=RULE['max_abs_s'])&(se<=RULE['max_se'])&(rai<RULE['max_raised'])&(sun<RULE['max_sunken'])
    step=np.zeros_like(cand)
    for di in (-1,0,1):
        for dj in (-1,0,1):
            if di==0 and dj==0:continue
            sh=np.roll(np.roll(s,di,0),dj,1);ch=np.roll(np.roll(cand,di,0),dj,1)
            step|=cand&ch&(np.abs(s-sh)>RULE['max_step'])
    sup=cand&~step
    return sup,dict(s=s,se=se,n=n,frames=nf,raised=rai,sunken=sun,stepEdge=step,candidate=cand,sigma_cm=np.round(sig*100,2).tolist())

def main():
    PL.T0=time.time();d,run=sys.argv[1:3];inject='inject' in sys.argv[3:]
    o=np.load(os.path.join(run,'pipeline2_out.npz'));R=o['R'];t=o['t'];lo=o['lo'];W7=np.load(os.path.join(run,'occthres_split0.7.npz'))
    H,W=W7['walk'].shape;calib=W7['walk']&~W7['lowUnresolvedFlag']
    Pl,F,Cl,nfr=samples(d,R,t)
    if not inject:
        sup,info=support_layer(Pl,F,Cl,nfr,lo,H,W,calib)
        newsup=sup&~W7['support']
        PL.log(stage='support',sigma_cm=info['sigma_cm'],statSupport=int(sup.sum()),occupancySupport=int(W7['support'].sum()),addedSupport=int(newsup.sum()),stepEdges=int(info['stepEdge'].sum()))
        np.save(os.path.join(run,'support_extra.npy'),sup);np.savez(os.path.join(run,'support_layer.npz'),support=sup,**info)
        return
    # ---- fixtures through the actual classifier: synthetic geometry rendered into the real rays ----
    rng=np.random.default_rng(3);base,_=support_layer(Pl,F,Cl,nfr,lo,H,W,calib)
    cand_cols=np.argwhere(base&W7['walk'])
    picks=cand_cols[rng.choice(len(cand_cols),12,replace=False)]
    O=Cl[F];Dv=Pl-O;out=[]
    def render(boxes):
        best=np.ones(len(Pl))
        for b in boxes:
            t0=np.zeros(len(Pl));t1=np.ones(len(Pl))
            for a in range(3):
                with np.errstate(divide='ignore',invalid='ignore'):ta=(b[0][a]-O[:,a])/Dv[:,a];tb=(b[1][a]-O[:,a])/Dv[:,a]
                l_=np.minimum(ta,tb);h_=np.maximum(ta,tb);par=Dv[:,a]==0;ins=(O[:,a]>=b[0][a])&(O[:,a]<=b[1][a])
                l_[par]=np.where(ins[par],-np.inf,np.inf);h_[par]=np.where(ins[par],np.inf,-np.inf);t0=np.maximum(t0,l_);t1=np.minimum(t1,h_)
            hit=(t0<=t1)&(t0<best)&(t0>0);best[hit]=t0[hit]
        return O+Dv*best[:,None]
    fixtures=[('box 10x10 cm, 4 cm high',.10,.04),('box 10x10 cm, 8 cm high',.10,.08),('object 10x10 cm, 1 cm high',.10,.01),('object 20x20 cm, 2 cm high',.20,.02)]
    for k,(name,size,hgt) in enumerate(fixtures):
        for (ci,cj) in picks[3*k:3*k+3]:
            cx,cy=(ci+lo[0]+.5)*RES,(cj+lo[1]+.5)*RES
            Q=render([((cx-size/2,cy-size/2,0.),(cx+size/2,cy+size/2,hgt))])
            sup,_=support_layer(Q,F,Cl,nfr,lo,H,W,calib)
            nb=int(np.ceil(size/2/RES))
            region=sup[ci-nb:ci+nb+1,cj-nb:cj+nb+1]
            out.append(dict(fixture=name,col=[int(ci),int(cj)],supportBefore=bool(base[ci,cj]),centreSupportAfter=bool(sup[ci,cj]),supportedColumnsInFootprintAfter=int(region.sum()),footprintColumns=int(region.size)))
            print(json.dumps(out[-1]),flush=True)
    # drop: lower all samples in a 40x40 cm square by 6 cm (a hole/step down)
    for (ci,cj) in picks[:3]:
        cx,cy=(ci+lo[0]+.5)*RES,(cj+lo[1]+.5)*RES
        Q=Pl.copy();m=(np.abs(Q[:,0]-cx)<=.2)&(np.abs(Q[:,1]-cy)<=.2)&(np.abs(Q[:,2])<.15);Q[m,2]-=.06
        sup,info=support_layer(Q,F,Cl,nfr,lo,H,W,calib)
        inner=sup[ci-3:ci+4,cj-3:cj+4];ring=sup[ci-5:ci+6,cj-5:cj+6].sum()-sup[ci-3:ci+4,cj-3:cj+4].sum()
        out.append(dict(fixture='6 cm drop, 40x40 cm',col=[int(ci),int(cj)],supportedInsideDrop=int(inner.sum()),insideColumns=int(inner.size),stepEdgesFlagged=int(info['stepEdge'][ci-5:ci+6,cj-5:cj+6].sum())))
        print(json.dumps(out[-1]),flush=True)
    json.dump(dict(rules=RULE,fixtures=out),open(os.path.join(run,'SUPPORT_FIXTURES.json'),'w'),indent=1)
if __name__=='__main__':main()
