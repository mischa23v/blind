"""Independent saved-array recount, not a mapping or distance-query rerun."""
import os
os.environ['OPENBLAS_NUM_THREADS']='1'
from pathlib import Path
import hashlib,json,numpy as np
B=Path('research/rtabmap-same-data-benchmark-20261028/fresh-run/octomap-stage'); D=B/'zup-common-surface'; checks=[]
def ck(b,s):
 assert b,s
 checks.append(s)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
r=json.loads((D/'RESULT.json').read_text());v=r['results']['octomap_zup_regenerated']
z=np.load(D/'octomap_zup_regenerated.npz')
for a,k in [('forwardDistanceMetres','forwardUnsignedPointToReferenceTriangle'),('reverseReferencePointDistanceMetres','reverseVisibleReferenceToSampledOutputPoint')]:
 d=z[a];s=v[k];ck(np.isfinite(d).all(),a+' finite');ck(len(d)==s['scheduled']==s['valid'],a+' denominator');ck(s['invalid']==0,a+' invalid')
 for key,expected in [('meanMetres',d.mean()),('medianMetres',np.median(d)),('maxMetres',d.max()),('p95Metres',np.percentile(d,95)),('p99Metres',np.percentile(d,99))]:ck(abs(s[key]-expected)<1e-12,a+' '+key)
 for t,record in s['within'].items():
  n=int((d<=float(t)).sum());ck(n==record['count'],a+' count '+t);ck(abs(n/len(d)-record['fractionOfScheduled'])<1e-15,a+' fraction '+t)
ck(sha(D/'octomap_zup_regenerated.npz')==v['arraySHA256'],'array hash')
ck(sha(D/'reference_samples_faro_metres.npy')==r['referenceSamplesSHA256'],'reference hash')
ck(sha(D/'reference_samples_faro_metres.npy')==sha(B.parent/'common-surface-reader-fixed/reference_samples_faro_metres.npy'),'same earlier reference sample bytes')
ck(len(z['pointsFaroMetres'])==v['common4cmPointCount']==247832,'common4cm count')
p=np.load(D/'octomap_zup_regenerated_decoded_points.npy');ck(len(p)==v['rawOutputPointCount']==325714,'raw occupied endpoint count')
freeze=json.loads((B/'ZUP_PRE_RUN_FREEZE.json').read_text())
for f in freeze['files']:ck(sha(B/f['path'])==f['sha256'],'frozen '+f['path'])
launch=json.loads((B/'ZUP_COMMON_LAUNCH.json').read_text())
for p,h in launch['pins'].items():ck(sha(Path(p))==h,'launch '+Path(p).name)
ck(sha(B/'ZUP_COMMON_LAUNCH.json')==r['launchSHA256'],'launch receipt hash')
report={'status':'passed','checks':checks,'checkCount':len(checks),'resultSHA256':sha(D/'RESULT.json'),'sourceArraySHA256':sha(D/'octomap_zup_regenerated.npz'),'geometryQueriesRepeated':False,'physicalSafetyEstablished':False}
Path('research/rtabmap-same-data-benchmark-20261028/independent-review/octomap-zup-final/METRIC_RECOUNT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
