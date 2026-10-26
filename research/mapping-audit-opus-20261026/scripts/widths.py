"""Passage width as a range at foot/body/head height along the recorded camera path, phone map vs reference;
plus room-scale check. Reference = evaluator only (author registration, scale reported, never refitted).

Width at frame i: from the camera's (x,y), march along +-perpendicular to the smoothed travel direction (1 cm
steps) until a blocked column; width = left + right. Bands relative to the level floor plane:
  foot 0.025-0.30 m, body 0.30-1.60 m, head 1.60-1.80 m.
Phone pessimistic: blocked = occupied (either OctoMap tree) OR unknown OR (foot band only) no floor support.
Phone optimistic : blocked = occupied only (unknown passes; never used for walkability).
Reference        : blocked = any mesh vertex in band, or (foot) no reference floor within +-6 cm.
Only frames whose camera column is reference-walkable and that are moving (> 2 cm/frame) are measured.
Camera centre is not a body centre; perpendicular widths are a diagnostic of map inflation, not a clearance claim.
usage: widths.py <poses_dir> <run_dir> <icp.json> <gt_mesh.ply> <map_npz_name> <label>
"""
import sys,os,json,numpy as np
from scipy import ndimage
RES=.05;BANDS={'foot':(.025,.30),'body':(.30,1.60),'head':(1.60,1.80)}

def load_ply_xyz(p):
    with open(p,'rb') as f:
        hdr=b''
        while not hdr.endswith(b'end_header\n'):hdr+=f.readline()
        L=hdr.decode().split('\n');nv=int([l for l in L if l.startswith('element vertex')][0].split()[-1])
        props=[l.split() for l in L if l.startswith('property') and 'list' not in l];tm={'double':'<f8','float':'<f4','uchar':'u1'}
        V=np.fromfile(f,dtype=np.dtype([(q[2],tm[q[1]]) for q in props]),count=nv)
    return np.c_[V['x'],V['y'],V['z']].astype(np.float64)

def main():
    pd,run,icp,ply,mapname,label=sys.argv[1:7]
    o=np.load(os.path.join(run,'pipeline2_out.npz'));R=o['R'];t=o['t'];lo=o['lo'];M=np.load(os.path.join(run,mapname))
    H,W=M['walk'].shape;fc=np.load(os.path.join(run,'fused_clouds.npz'))
    def colband(pts,a,b):
        h=pts[:,2]-RES/2;m=(h>=a)&(h<b);k=np.floor(pts[m]/RES+1e-6).astype(int)[:,:2]-lo[:2];ok=(k[:,0]>=0)&(k[:,0]<H)&(k[:,1]>=0)&(k[:,1]<W);g=np.zeros((H,W),bool);g[k[ok,0],k[ok,1]]=True;return g
    def known(a,b):
        # a column band is 'known' if every 5 cm layer in it has a free or occupied leaf in either tree
        layers=np.arange(int(np.floor(a/RES+.5)),int(np.floor(b/RES-.5))+1);seen=np.ones((H,W),bool)
        for L in layers:
            hh=(L*RES,(L+1)*RES);s=np.zeros((H,W),bool)
            for pts in (fc['occA'],fc['freeA'],fc['occN'],fc['freeN']):s|=colband(pts,hh[0]-RES/2,hh[1]-RES/2)
            seen&=s
        return seen
    phone={};
    for bn,(a,b) in BANDS.items():
        occ=colband(fc['occA'],a,b)|colband(fc['occN'],a,b);kn=known(a,b)
        pess=occ|~kn
        if bn=='foot':pess|=~M['support']
        phone[bn]=(pess,occ)
    # reference columns per band (vertices into the phone level frame through the author registration)
    A=np.array(json.load(open(icp))['gt_transformation']);Ai=np.linalg.inv(A);scale=float(np.linalg.svd(A[:3,:3],compute_uv=False).mean())
    V=load_ply_xyz(ply);P=(V@Ai[:3,:3].T+Ai[:3,3])@R.T+t+[0,0,RES/2]
    ref={};floor=colband(P,-.06,.06)
    for bn,(a,b) in BANDS.items():
        g=colband(P,a,b);ref[bn]=g|(~floor if bn=='foot' else False)
    refwalk=floor&~ref['foot']&~ref['body']&~ref['head']
    C=np.array([f['transform_matrix'] for f in json.load(open(os.path.join(pd,'transformations.json')))['frames']])[:,:3,3]@R.T+t
    xy=C[:,:2];n=len(xy)
    def march(mask,p,dvec):
        dist=0.
        for s in np.arange(.01,4.0,.01):
            q=p+dvec*s;i=int(np.floor(q[0]/RES))-lo[0];j=int(np.floor(q[1]/RES))-lo[1]
            if i<0 or j<0 or i>=H or j>=W or mask[i,j]:return s
        return 4.0
    rows=[]
    for k in range(n):
        a,b=max(0,k-3),min(n-1,k+3);dv=xy[b]-xy[a]
        if np.linalg.norm(dv)<.02*(b-a):continue
        tdir=dv/np.linalg.norm(dv);perp=np.array([-tdir[1],tdir[0]])
        i=int(np.floor(xy[k,0]/RES))-lo[0];j=int(np.floor(xy[k,1]/RES))-lo[1]
        if not(0<=i<H and 0<=j<W) or not refwalk[i,j]:continue
        r={'frame':k,'planner_mask':march(~M['walk'],xy[k],perp)+march(~M['walk'],xy[k],-perp),'ref_allbands':march(~refwalk,xy[k],perp)+march(~refwalk,xy[k],-perp)}
        for bn in BANDS:
            for nm,mask in (('phonePess',phone[bn][0]),('phoneOpt',phone[bn][1]),('ref',ref[bn])):
                r[f'{bn}_{nm}']=march(mask,xy[k],perp)+march(mask,xy[k],-perp)
        rows.append(r)
    res={'label':label,'framesMeasured':len(rows),'registrationScale':scale,'bands':{}}
    for bn in BANDS:
        rw=np.array([r[f'{bn}_ref'] for r in rows]);pp=np.array([r[f'{bn}_phonePess'] for r in rows]);po=np.array([r[f'{bn}_phoneOpt'] for r in rows])
        cap=(rw<3.9)&(pp<3.9)
        res['bands'][bn]=dict(refWidth_m_p10_p50_p90=np.round(np.percentile(rw,[10,50,90]),3).tolist(),phonePess_m_p10_p50_p90=np.round(np.percentile(pp,[10,50,90]),3).tolist(),phoneOpt_m_p10_p50_p90=np.round(np.percentile(po,[10,50,90]),3).tolist(),
            pessMinusRef_m_p10_p50_p90=np.round(np.percentile((pp-rw)[cap],[10,50,90]),3).tolist(),optMinusRef_m_p10_p50_p90=np.round(np.percentile((po-rw)[(rw<3.9)&(po<3.9)],[10,50,90]),3).tolist(),
            refAtLeast075_phonePessBelow075=int(((rw>=.75)&(pp<.75)).sum()),refAtLeast075=int((rw>=.75).sum()),phoneOptWiderThanRef_by_gt5cm=int(((po-rw)>.05).sum()))
    rw=np.array([r['ref_allbands'] for r in rows]);pm=np.array([r['planner_mask'] for r in rows]);cap=(rw<3.9)&(pm<3.9)
    res['plannerMask']=dict(refFreeWidth_m_p10_p50_p90=np.round(np.percentile(rw,[10,50,90]),3).tolist(),plannerFreeWidth_m_p10_p50_p90=np.round(np.percentile(pm,[10,50,90]),3).tolist(),
        plannerMinusRef_m_p10_p50_p90=np.round(np.percentile((pm-rw)[cap],[10,50,90]),3).tolist(),refAtLeast075=int((rw>=.75).sum()),refAtLeast075_plannerBelow075=int(((rw>=.75)&(pm<.75)).sum()),
        plannerWiderThanRef_by_gt5cm=int(((pm-rw)>.05).sum()),note='free width through the camera position perpendicular to travel; planner = walkable mask of the map; ref = reference floor present and no geometry 2.5 cm-1.8 m')
    # room scale: extents of body-band occupancy along its principal axes; ceiling = mode of high occupancy
    occ=np.r_[fc['occA']];h=occ[:,2]-RES/2;wall=occ[(h>.5)&(h<2.0)][:,:2]
    c=wall.mean(0);U,S,Vt=np.linalg.svd(wall-c,full_matrices=False);pr=(wall-c)@Vt.T
    ext=np.percentile(pr,99.5,axis=0)-np.percentile(pr,.5,axis=0)
    hi=h[h>1.8];hist,e=np.histogram(hi,bins=np.arange(1.8,3.2,.02));ceil=float(e[np.argmax(hist)]+.01) if len(hi)>1000 else None
    Vf=V;hv=(P[:,2]-RES/2);wallf=V[(hv>.5)&(hv<2.0)];cf=wallf.mean(0);Uf,Sf,Vtf=np.linalg.svd(wallf-cf,full_matrices=False)
    prf=(wallf-cf)@Vtf.T;extf=np.percentile(prf,99.5,axis=0)-np.percentile(prf,.5,axis=0)
    hif=hv[hv>1.8];histf,ef=np.histogram(hif,bins=np.arange(1.8,3.2,.02));ceilf=float(ef[np.argmax(histf)]+.01) if len(hif)>1000 else None
    res['scale']=dict(phone_extent_m=np.round(ext,3).tolist(),phone_ceiling_m=ceil,reference_extent_metric_m=np.round(extf[:2],3).tolist(),reference_ceiling_in_phone_frame_m=ceilf,
        reference_ceiling_metric_m=None if ceilf is None else round(ceilf*scale,3),published_m=[10,8,2.5],note='extents are 0.5-99.5 percentile spans of 0.5-2.0 m occupancy along principal axes; reference extents measured in original FARO coordinates (metric), phone in phone units')
    json.dump(dict(res=res,rows=rows),open(os.path.join(run,f'WIDTHS_{label}.json'),'w'),indent=1)
    print(json.dumps(res,indent=1))
if __name__=='__main__':main()
