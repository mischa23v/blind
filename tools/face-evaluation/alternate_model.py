"""Post-hoc AuraFace embedding comparison on consumed ORL; NOT new validation."""
import argparse,hashlib,json,pathlib,time,zipfile
import cv2,numpy as np
from image_smoke import MODEL_FILES,checked_file
from benchmark import metric

AURA_SHA='a7933ea5330113b01c9b60351d8f4c33003f145d8470ac5f0e52ee2effe25c60'
# Declared before extracting any AuraFace features. Values do not transfer calibration.
THRESHOLDS=[.2,.3,.363,.4,.5,.6,.7]
MARGINS=[0.,.1,.2]

def decide(ranking, threshold, margin):
 if not ranking or ranking[0][1]<threshold:return None
 if len(ranking)>1 and ranking[0][1]-ranking[1][1]<margin:return None
 return ranking[0][0]

def summarize(rows,candidates):
 known=[(r,c) for r,c in zip(rows,candidates) if r['known']]
 unknown=[(r,c) for r,c in zip(rows,candidates) if not r['known']]
 wrong=[r for r,c in unknown if c is not None]
 return {'knownCorrect':metric(sum(c==r['identity'] for r,c in known),len(known)),
 'knownWrong':metric(sum(c is not None and c!=r['identity'] for r,c in known),len(known)),
 'knownAbstain':metric(sum(c is None for r,c in known),len(known)),
 'unknownFalseIdentification':metric(len(wrong),len(unknown)),
 'unknownAbstain':metric(len(unknown)-len(wrong),len(unknown)),
 'unknownIdentitiesWithAnyFalseIdentification':metric(len({r['identity'] for r in wrong}),20),
 'falseUnknownImages':[r['image'] for r in wrong]}

def distribution(values):
 return {'count':len(values),'quantiles':dict(zip(['min','p01','p05','median','p95','p99','max'],[float(v) for v in np.quantile(values,[0,.01,.05,.5,.95,.99,1])]))} if values else {'count':0}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--assets',type=pathlib.Path,required=True);p.add_argument('--baseline-report',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();cv2.setNumThreads(1)
 aura=checked_file(a.assets,'auraface/glintr100.onnx',AURA_SHA)
 archive=zipfile.ZipFile(checked_file(a.assets,'orl/att_faces.zip','509d763bd2276aa054d260d7f1000e8be212738134f2f83d8ff13bc2adf1c8ec'))
 paths={n:checked_file(a.assets,'models/'+n,h) for n,h in MODEL_FILES.items()}
 d=cv2.FaceDetectorYN_create(str(paths['face_detection_yunet_2023mar.onnx']),'',(92,112),.9,.3,5000)
 align=cv2.FaceRecognizerSF_create(str(paths['face_recognition_sface_2021dec.onnx']),'')
 net=cv2.dnn.readNetFromONNX(str(aura));layers=net.getLayerNames()
 if not layers[0].endswith('/conv1/Conv'):raise ValueError('Unexpected graph/preprocessing; re-review exact model')
 baseline=json.loads(a.baseline_report.read_text())
 if baseline['models']!=MODEL_FILES or baseline['threshold']!=.363 or baseline['margin']!=.1:raise ValueError('Wrong baseline report')
 sf={r['image']:r['candidate'] for r in baseline['results']};baseline_images={r['image']:r for r in baseline['observations']}
 features={};observations=[];start=time.perf_counter()
 for i in range(1,41):
  for j in range(1,11):
   key=f's{i}/{j}.pgm';p=a.assets/'orl'/key;sha=hashlib.sha256(p.read_bytes()).hexdigest()
   if sha!=hashlib.sha256(archive.read(key)).hexdigest() or sha!=baseline_images[key]['sha256']:raise ValueError('Input mismatch')
   im=cv2.imread(str(p),cv2.IMREAD_COLOR);_,faces=d.detect(im);count=0 if faces is None else len(faces)
   if count!=baseline_images[key]['facesDetected']:raise ValueError('Detector changed from baseline')
   item={'image':key,'identity':i,'facesDetected':count,'sha256':sha}
   if count==1:
    crop=align.alignCrop(im,faces[0]);assert crop.shape==(112,112,3)
    blob=cv2.dnn.blobFromImage(crop,1/127.5,(112,112),(127.5,127.5,127.5),swapRB=True)
    net.setInput(blob);out=net.forward().reshape(-1)
    if out.shape!=(512,) or not np.isfinite(out).all() or np.linalg.norm(out)==0:raise ValueError('Invalid AuraFace output')
    features[key]=out/np.linalg.norm(out)
   observations.append(item)
  print(f'AuraFace identity{i}/40 completed',flush=True)
 gallery={i:features[f's{i}/1.pgm'] for i in range(1,21) if f's{i}/1.pgm' in features}
 rows=[]
 for item in observations:
  i=item['identity'];key=item['image']
  if i<=20 and key.endswith('/1.pgm'):continue
  scores=[] if key not in features else sorted([(k,float(np.dot(features[key],f))) for k,f in gallery.items()],key=lambda z:z[1],reverse=True)
  rows.append({'image':key,'identity':i,'known':i<=20,'ranking':scores,'baselineSFaceCandidate':sf[key]})
 grid=[]
 for threshold in THRESHOLDS:
  for margin in MARGINS:
   candidates=[decide(r['ranking'],threshold,margin) for r in rows]
   both=[c if c is not None and c==sf[r['image']] else None for r,c in zip(rows,candidates)]
   grid.append({'threshold':threshold,'margin':margin,'auraface':summarize(rows,candidates),'sameIdentityAgreementWithFrozenSFace':summarize(rows,both)})
 positives=[];negatives=[]
 for index,x in enumerate(observations):
  for y in observations[index+1:]:
   if x['image'] not in features or y['image'] not in features:continue
   score=float(np.dot(features[x['image']],features[y['image']]))
   (positives if x['identity']==y['identity'] else negatives).append(score)
 report={'purpose':__doc__,'model':json.loads((a.assets/'auraface/provenance.json').read_text()),'opencv':cv2.__version__,
 'preprocessing':'Same YuNet detection and OpenCV five-point112 crop as baseline; ArcFace standard blob RGB swap, mean127.5/std127.5;512-D L2 normalization. Controlled embedding substitution, not full official fal detection stack reproduction.',
 'thresholds':THRESHOLDS,'margins':MARGINS,'calibrated':False,'selectedBestPolicy':None,
 'gallerySize':len(gallery),'imageCount':400,'identityCount':40,'uniqueFaceDetections':len(features),'unscorableImages':400-len(features),
 'grid':grid,'scorablePairDistributions':{'mated':distribution(positives),'nonmated':distribution(negatives)},
 'observations':observations,'probeScores':rows,'seconds':time.perf_counter()-start,
 'limits':['All ORL data were already consumed: exploratory diagnostics, NOT fresh held-out improvement.',
 'No transfer of SFace calibration: all AuraFace numeric thresholds are arbitrary exploratory anchors.',
 'Same-identity agreement is measured here only; no independence assumption or multiplication of error rates.',
 'Shared detection/alignment creates shared errors; no iOS/PAD/guardian assurance.',
 'Small historical grayscale dataset; demographics/training overlap unknown. Nominal image CIs ignore clustering.',
 'Model publisher Apache2 declaration retained; underlying proprietary training data cannot be independently audited; no production deployment approval.']}
 a.output.write_text(json.dumps(report,indent=2));print(json.dumps({'seconds':report['seconds'],'scorablePairDistributions':report['scorablePairDistributions'],'gridCounts':[(v['threshold'],v['margin'],v['auraface']['knownCorrect']['numerator'],v['auraface']['knownWrong']['numerator'],v['auraface']['knownAbstain']['numerator'],v['auraface']['unknownFalseIdentification']['numerator'],v['sameIdentityAgreementWithFrozenSFace']['knownCorrect']['numerator'],v['sameIdentityAgreementWithFrozenSFace']['unknownFalseIdentification']['numerator']) for v in grid]},indent=2))
if __name__=='__main__':main()
