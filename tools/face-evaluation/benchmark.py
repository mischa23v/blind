"""Frozen original AT&T/ORL research evaluation. No downloads or app imports."""
import argparse, hashlib, json, math, pathlib, time, zipfile
import cv2
import numpy as np
from image_smoke import MODEL_FILES, checked_file, THRESHOLD, MARGIN

def interval(k, n):
    if not n: return None
    z = 1.959963984540054
    mid = (k / n + z*z/(2*n)) / (1+z*z/n)
    half = z * math.sqrt((k/n)*(1-k/n)/n + z*z/(4*n*n)) / (1+z*z/n)
    return [max(0.,mid-half), min(1.,mid+half)]

def metric(k,n):
    return {'numerator':k,'denominator':n,'fraction':k/n if n else None,'nominalWilson95':interval(k,n)}

def decision(scores):
    ranking = sorted(scores, key=lambda x: x[1], reverse=True)
    if not ranking:return None,'empty_gallery'
    if ranking[0][1] < THRESHOLD:return None,'below_threshold'
    if len(ranking)>1 and ranking[0][1]-ranking[1][1] < MARGIN:return None,'runner_up'
    return ranking[0][0],'experimental_candidate'

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--assets',type=pathlib.Path,required=True)
    p.add_argument('--output',type=pathlib.Path,required=True)
    args=p.parse_args(); cv2.setNumThreads(1)
    root=args.assets/'orl'
    expected={f's{i}/{j}.pgm' for i in range(1,41) for j in range(1,11)}
    found={str(p.relative_to(root)) for p in root.glob('s*/*.pgm')}
    if expected != found:raise ValueError('Expected exactly original400 image layout')
    provenance=json.loads((root/'provenance.json').read_text())
    archive_path=checked_file(root,'att_faces.zip','509d763bd2276aa054d260d7f1000e8be212738134f2f83d8ff13bc2adf1c8ec')
    archive=zipfile.ZipFile(archive_path)
    paths={name:checked_file(args.assets,'models/'+name,sha) for name,sha in MODEL_FILES.items()}
    det=cv2.FaceDetectorYN_create(str(paths['face_detection_yunet_2023mar.onnx']),'',(92,112),.9,.3,5000)
    rec=cv2.FaceRecognizerSF_create(str(paths['face_recognition_sface_2021dec.onnx']),'')
    observations=[];features={}; hashes=set(); start=time.perf_counter()
    for i in range(1,41):
        for j in range(1,11):
            key=f's{i}/{j}.pgm'; path=root/key; sha=hashlib.sha256(path.read_bytes()).hexdigest()
            if hashlib.sha256(archive.read(key)).hexdigest()!=sha:raise ValueError('Extracted file differs from approved archive')
            if sha in hashes:raise ValueError('Duplicate image content')
            hashes.add(sha)
            image=cv2.imread(str(path),cv2.IMREAD_COLOR)
            if image is None or image.shape!=(112,92,3):raise ValueError('Unexpected source dimensions')
            det.setInputSize((92,112));_,faces=det.detect(image)
            count=0 if faces is None else len(faces)
            item={'image':key,'identity':i,'sha256':sha,'facesDetected':count}
            if count==1:
                feature=rec.feature(rec.alignCrop(image,faces[0])).copy().reshape(-1)
                if not np.isfinite(feature).all() or np.linalg.norm(feature)==0:raise ValueError('Invalid embedding')
                features[key]=feature/np.linalg.norm(feature)
                item['faceScore']=float(faces[0,-1])
            observations.append(item)
        print(f'Processed identity{i}/40',flush=True)
    gallery={i:features[f's{i}/1.pgm'] for i in range(1,21) if f's{i}/1.pgm' in features}
    results=[]
    for i in range(1,41):
        for j in range(1,11):
            if i<=20 and j==1:continue
            key=f's{i}/{j}.pgm'; scores=[]
            if key in features:
                scores=[(ident,float(np.dot(features[key],f))) for ident,f in gallery.items()]
                candidate,reason=decision(scores)
            else:candidate,reason=None,'no_unique_face'
            ranked=sorted(scores,key=lambda x:x[1],reverse=True)
            results.append({'image':key,'identity':i,'known':i<=20,'candidate':candidate,'reason':reason,'topTwo':ranked[:2]})
    known=[r for r in results if r['known']];unknown=[r for r in results if not r['known']]
    correct=sum(r['candidate']==r['identity'] for r in known)
    wrong=sum(r['candidate'] is not None and r['candidate']!=r['identity'] for r in known)
    abstained=sum(r['candidate'] is None for r in known)
    fp=sum(r['candidate'] is not None for r in unknown)
    gallery_metrics={'knownCorrect':metric(correct,len(known)),'knownWrongIdentity':metric(wrong,len(known)),
        'knownAbstention':metric(abstained,len(known)),'unknownFalseIdentification':metric(fp,len(unknown)),
        'unknownAbstention':metric(len(unknown)-fp,len(unknown)),
        'unknownIdentitiesWithAnyFalseIdentification':metric(len({r['identity'] for r in unknown if r['candidate'] is not None}),20),
        'knownIdentitiesWithAnyWrongName':metric(len({r['identity'] for r in known if r['candidate'] is not None and r['candidate']!=r['identity']}),20)}
    pairs={'mated':{'all':0,'scorable':0,'falseNonmatch':0,'unscorable':0},'nonmated':{'all':0,'scorable':0,'falseMatch':0,'unscorable':0}}
    for index,a in enumerate(observations):
        for b in observations[index+1:]:
            same=a['identity']==b['identity'];m=pairs['mated' if same else 'nonmated'];m['all']+=1
            if a['image'] not in features or b['image'] not in features:m['unscorable']+=1;continue
            m['scorable']+=1;score=float(np.dot(features[a['image']],features[b['image']]))
            if same and score<THRESHOLD:m['falseNonmatch']+=1
            if not same and score>=THRESHOLD:m['falseMatch']+=1
    pairs['conditionalFMR']=metric(pairs['nonmated']['falseMatch'],pairs['nonmated']['scorable'])
    pairs['conditionalFNMR']=metric(pairs['mated']['falseNonmatch'],pairs['mated']['scorable'])
    pairs['endToEndMatedFailure']=metric(pairs['mated']['falseNonmatch']+pairs['mated']['unscorable'],pairs['mated']['all'])
    report={'dataset':'Original AT&T/ORL Database of Faces','credit':'AT&T Laboratories Cambridge','provenance':provenance,
      'protocol':'Frozen before inference: s1..s20 image1 enrollment; their images2..10 known probes; s21..s40 all10 images unknown probes. Missing enrollments not replaced. Separate all unordered image pairs verification, not official standard split.',
      'opencv':cv2.__version__,'models':MODEL_FILES,'threshold':THRESHOLD,'margin':MARGIN,'calibrated':False,
      'imageCount':400,'identityCount':40,'expectedGallerySize':20,'actualGallerySize':len(gallery),
      'failedEnrollments':[i for i in range(1,21) if i not in gallery],
      'detection':{'unique':len(features),'noFace':sum(r['facesDetected']==0 for r in observations),'multipleFaces':sum(r['facesDetected']>1 for r in observations)},
      'gallery':gallery_metrics,'pairVerification':pairs,'seconds':time.perf_counter()-start,
      'limitations':['Original92x112 grayscale pre-cropped frontal faces replicated into BGR; no substitute boxes or upscaling.',
       'No identity-disjoint calibration; no fitting of thresholds or selection after looking at scores.',
       'Age/era and controlled capture do not represent phone scenes; demographic diversity unverified.',
       'Training overlap cannot be ruled out. This is not Apple Face ID or the full iOS temporal pipeline.',
       'Nominal Wilson intervals assume independent Bernoulli trials; image/pair rows are correlated, so those intervals are descriptive and overstate effective sample size. Identity-event intervals use20 subjects but population sampling is still unrepresentative.',
       'No liveness, spoof attacks, guardian binding, device tests, or child-safety validation.'],
      'observations':observations,'results':results}
    args.output.write_text(json.dumps(report,indent=2))
    print(json.dumps({k:report[k] for k in ['actualGallerySize','failedEnrollments','detection','gallery','pairVerification','seconds']},indent=2))
if __name__=='__main__':main()
