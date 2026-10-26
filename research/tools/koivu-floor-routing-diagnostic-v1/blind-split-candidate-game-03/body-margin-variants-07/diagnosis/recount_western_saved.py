"""Independent saved-array reconciliation, no depth processing or geometry queries."""
from pathlib import Path
import hashlib,json
import numpy as np
P=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 out=P/'west-depth-run-01/result';r=json.loads((out/'RESULT.json').read_text())
 with np.load(out/'SELECTED_ENDPOINTS.npz',allow_pickle=False)as z:d={k:z[k]for k in z.files}
 n=len(d['frame']);h=d['level'][:,2];checks=0
 assert all(len(a)==n for a in d.values())and n==r['selectedEndpointCount'];checks+=1
 assert len(r['cells'])==r['uniqueCells']==57 and sum(len(c['cameraFrameRecords'])for c in r['cells'])==71;checks+=1
 assert sum(f['selectedColumnEndpoints']for f in r['frames'])==n and len(r['frames'])==294;checks+=1
 for c in r['cells']:
  i,j=c['sourceIJ'];m=(d['i']==i)&(d['j']==j)
  for name,sel in [('allViews',m),('nearViewsAtMost2m',m&(d['range']<=2))]:
   x=h[sel];s=c[name];assert len(x)==s['heightMetres']['n'];checks+=1
   assert int(np.unique(d['frame'][sel]).size)==s['frames'];checks+=1
   if len(x):assert np.array_equal(np.percentile(x,[5,50,95]),s['heightMetres']['p05_p50_p95']);checks+=1
   bands=[int((x<-.025).sum()),int((abs(x)<=.025).sum()),int(((x>.025)&(x<=.075)).sum()),int((x>.075).sum())]
   assert sum(bands)==len(x)and bands==[s[k]for k in ['belowMinus2p5cm','floorBandInclusive','lowBand2p5To7p5cm','above7p5cm']];checks+=1
  for e in c['measuredEndpointExemplars']:
   q=m&(d['frame']==e['poseIndex'])&(d['row']==e['pixelRowCol'][0])&(d['col']==e['pixelRowCol'][1])
   assert q.sum()==1;idx=int(np.flatnonzero(q)[0]);assert int(d['depthMM'][idx])==e['depthMM']and np.array_equal(d['level'][idx],e['levelXYZMetres']);checks+=1
 result={'passed':True,'checks':checks,'scope':'Saved-array count, disjoint band, percentile and exemplar association checks; not an independent depth/geometry accuracy test',
  'pins':{p.name:sha(p)for p in [out/'RESULT.json',out/'SELECTED_ENDPOINTS.npz',Path(__file__)]}}
 (P/'WESTERN_SAVED_ARRAY_RECOUNT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
