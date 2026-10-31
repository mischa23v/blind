from pathlib import Path
import numpy as np,json,hashlib
from PIL import Image
H=Path(__file__).resolve().parent;R=H.parent/'fresh-run';O=H.parents[1]/'open3d-same-data-benchmark-20261028';D=O/'fresh-run/inputs/room_datasets/koivu/iphone/long_capture';F=json.loads((O/'fresh-run/FUSION_FROZEN.json').read_text());doc=json.loads((D/'transformations.json').read_text());frames={Path(x['file_path']).stem:x for x in doc['frames']};receipt=json.loads((R/'INPUT_RECEIPT.json').read_text());checks=0
def ck(b):
 global checks
 assert b;checks+=1
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rows=[x.split()for x in (R/'adapter/INPUTS.tsv').read_text().splitlines()];ids=[x[0]for x in rows];train=[x['frameID']for x in F['trainingFrames']];test=(D/'test.txt').read_text().splitlines();ck(ids==train);ck(len(ids)==len(set(ids))==265);ck(len(test)==len(set(test))==29);ck(not set(ids)&set(test));ck(set(ids)|set(test)==set(frames));ck(sha(R/'adapter/INPUTS.tsv')==receipt['tsvSHA256'])
A=np.array([[0,0,-1,0],[-1,0,0,0],[0,1,0,0],[0,0,0,1]],float);B=np.linalg.inv(A);Orot=np.array([[0,0,1,0],[-1,0,0,0],[0,-1,0,0],[0,0,0,1]],float);flip=np.diag([1,-1,-1,1]);ck(np.array_equal(B@Orot,flip));maxerr=0.;samplecount=0
for r in rows:
 f=frames[r[0]];ck(len(r)==21);ck([int(r[3]),int(r[4])]==[f['w'],f['h']]);ck(np.array_equal(np.array(r[5:9],float),np.array([f[k]for k in ['fl_x','fl_y','cx','cy']])))
 C=np.array(f['transform_matrix']);P=np.eye(4);P[:3,:]=np.array(r[9:],float).reshape(3,4);ck(np.array_equal(P,C@flip));node=A@P@flip@B;out=B@node@Orot;ck(np.allclose(out,P,rtol=0,atol=1e-15))
 # Account for adapter float constructor as well as exact algebra.
 Pf=P.astype(np.float32).astype(float);outf=B@(A@Pf@flip@B)@Orot;maxerr=max(maxerr,float(np.max(abs(outf-P))))
 for u,v,z in [(17,211,1.2),(527,803,2.4),(f['cx'],f['cy'],.5)]:
  q=np.array([(u-f['cx'])/f['fl_x']*z,(v-f['cy'])/f['fl_y']*z,z,1]);ck(np.max(abs(B@node@Orot@q-P@q))<1e-12);samplecount+=1
 for path in r[1:3]:ck(Path(path).exists())
for entry in receipt['files']:
 p=Path(entry['path']);ck(sha(p)==entry['sha256']);ck(p.stat().st_size==entry['bytes']);im=Image.open(p);ck(im.size==(738,994));ck(im.getexif().get(274,1)==1)
res={'status':'passed_static_input_and_numpy_checks_not_runtime','checks':checks,'training':265,'excluded':29,'verifiedImages':len(receipt['files']),'asymmetricWorldPointChecks':samplecount,'maximumFloatInputMatrixDifference':maxerr,'mapperSHA256':sha(R/'adapter/mapper.cpp'),'inputTSVSHA256':sha(R/'adapter/INPUTS.tsv'),'sourceRevision':'8cd2f81a735722402d1e220147c4e83a1a746eaf','limitations':['No native C++ fixture executed by this review; no reconstruction.','Native RTAB maxDepth is inclusive4m whereas Open3D baseline cutoff exclusive4m; freeze choice and disclose before execution.','No actual timestamps/IMU/covariance; stamp0 and API identity covariance are conventions not measurements.','Fixed-arm exported poses and signature completeness need runtime assertions.']}
(H/'INPUT_REVIEW.json').write_text(json.dumps(res,indent=2)+'\n');print(json.dumps(res,indent=2))
