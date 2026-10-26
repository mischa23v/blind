"""Which D1 low-band obstacle cells (Koivu 5 cm) are supported ONLY by near-range low-band hits from
pose-inconsistent frames (per-frame floor |offset|>2.5 cm or tilt>1.2 deg, from phone data only)?
Then score those cells against the reference (evaluator only)."""
import numpy as np,json,sys
sys.argv=[sys.argv[0]];import cause as C
o=np.load(__import__('os').environ['KOIVU_PIPELINE2_OUT'])
lo=o['lo'];RES=.05;H,W=o['D1__walk'].shape
rows={r['frame']:r for r in json.load(open('per_frame_floor.json'))}
bad=set(f for f,r in rows.items() if abs(r['offset_at_centroid'])>.025 or r['tilt']>1.2)
nofit=set(range(294))-set(rows)
good_hits=np.zeros(H*W,int);bad_hits=np.zeros(H*W,int);nofit_hits=np.zeros(H*W,int)
for i in range(294):
  pl,cam,rng,_=C.frame_pts(i);h=pl[:,2]
  m=(rng<=2.0)&(h>.025)&(h<=.075)
  ii=np.floor(pl[m,0]/RES).astype(int)-lo[0];jj=np.floor(pl[m,1]/RES).astype(int)-lo[1];ok=(ii>=0)&(ii<H)&(jj>=0)&(jj<W)
  c=np.bincount(ii[ok]*W+jj[ok],minlength=H*W)
  if i in bad:bad_hits+=c
  elif i in nofit:nofit_hits+=c
  else:good_hits+=c
gh,bh,nh=(x.reshape(H,W) for x in (good_hits,bad_hits,nofit_hits))
low1=o['D1__low1']&o['D1__support']&~o['D1__highObstacle']
cov=o['ref_n']>0;real=cov&((o['ref_low_max']>=.025)|(o['ref_body_max']>-np.inf))
onlybad=low1&(bh>0)&(gh==0)&(nh==0);anygood=low1&(gh>0)
print('pose-inconsistent frames:',len(bad),' no floor fit:',len(nofit))
print('D1 low-band obstacle cells (supported, not high):',int(low1.sum()))
print('  supported ONLY by inconsistent-frame hits:',int(onlybad.sum()),' -> reference-real:',int((onlybad&real).sum()))
print('  with hits from consistent frames:',int(anygood.sum()),' -> reference-real:',int((anygood&real).sum()))
print('  no near low-band hits at all (far-only evidence):',int((low1&(bh==0)&(gh==0)&(nh==0)).sum()),' -> real:',int((low1&(bh==0)&(gh==0)&(nh==0)&real).sum()))
# western passage cells from the other session's packet, if present
