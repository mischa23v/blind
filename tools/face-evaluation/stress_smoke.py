"""Bounded in-memory synthetic degradation tests; not independent accuracy or PAD."""
import argparse
import itertools
import json
import pathlib
import platform
import cv2
import numpy as np
from image_smoke import MODEL_FILES, THRESHOLD, MARGIN, checked_file

# Declared before execution. Never select thresholds/conditions from observed scores.
CONDITIONS = [
    ('original_photo', 'baseline', 1),
    ('blur_sigma_3', 'blur', 3), ('blur_sigma_7', 'blur', 7), ('blur_sigma_15', 'blur', 15),
    ('brightness_0.25', 'light', .25), ('brightness_0.5', 'light', .5),
    ('brightness_1.5_clipped', 'light', 1.5), ('brightness_2_clipped', 'light', 2),
    ('long_side_256', 'resize', 256), ('long_side_128', 'resize', 128), ('long_side_64', 'resize', 64),
    ('occlude_eye_band', 'occlusion', 'eyes'), ('occlude_lower_face', 'occlusion', 'lower'),
    ('in_plane_roll_minus20', 'roll', -20), ('in_plane_roll_plus20', 'roll', 20),
    ('in_plane_roll_plus45', 'roll', 45),
]

def detect(detector, image):
    detector.setInputSize((image.shape[1], image.shape[0]))
    _, faces = detector.detect(image)
    return [] if faces is None else list(faces)


def transform(image, face, kind, value):
    out = image.copy()
    if kind == 'blur': out = cv2.GaussianBlur(out, (0, 0), value)
    elif kind == 'light': out = np.clip(out.astype(np.float32) * value, 0, 255).astype(np.uint8)
    elif kind == 'resize':
        h, w = out.shape[:2]
        out = cv2.resize(out, (max(1, round(w * value/max(h,w))), max(1, round(h * value/max(h,w)))), interpolation=cv2.INTER_AREA)
    elif kind == 'roll':
        h, w = out.shape[:2]
        matrix = cv2.getRotationMatrix2D((w/2, h/2), value, 1.)
        out = cv2.warpAffine(out, matrix, (w,h), borderMode=cv2.BORDER_CONSTANT)
    elif kind == 'occlusion':
        x,y,w,h = map(float, face[:4])
        # Regions derived once from ORIGINAL detection, not from degraded outcomes.
        lo, hi = (.22,.50) if value == 'eyes' else (.52,1.)
        x1,x2 = max(0,round(x)), min(out.shape[1],round(x+w))
        y1,y2 = max(0,round(y+lo*h)), min(out.shape[0],round(y+hi*h))
        out[y1:y2,x1:x2] = 0
    return out


def counts(rows):
    known = [r for r in rows if r['truth'] is not None]
    unknown = [r for r in rows if r['truth'] is None]
    return dict(probes=len(rows), knownProbes=len(known), unknownProbes=len(unknown),
        detectorErrors=sum(r['reason']=='detector_error' for r in rows),
        embeddingErrors=sum(r['reason']=='embedding_error' for r in rows),
        noFace=sum(r['facesDetected']==0 for r in rows),
        multipleFaces=sum(r['facesDetected'] is not None and r['facesDetected']>1 for r in rows),
        uniqueFace=sum(r['facesDetected']==1 for r in rows),
        knownCorrect=sum(r['candidate']==r['truth'] for r in known),
        knownWrong=sum(r['candidate'] is not None and r['candidate']!=r['truth'] for r in known),
        knownAbstained=sum(r['candidate'] is None for r in known),
        unknownFalseNames=sum(r['candidate'] is not None for r in unknown),
        unknownAbstained=sum(r['candidate'] is None for r in unknown))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets',type=pathlib.Path,required=True)
    parser.add_argument('--output',type=pathlib.Path,required=True)
    args=parser.parse_args()
    if args.output.resolve().is_relative_to(pathlib.Path(__file__).resolve().parents[2]):
        raise ValueError('Report must remain outside repository')
    cv2.setNumThreads(1)
    models={name:checked_file(args.assets,'models/'+name,sha) for name,sha in MODEL_FILES.items()}
    detector=cv2.FaceDetectorYN_create(str(models['face_detection_yunet_2023mar.onnx']),'',(320,320),.9,.3,5000)
    recognizer=cv2.FaceRecognizerSF_create(str(models['face_recognition_sface_2021dec.onnx']),'')
    manifest=json.loads((args.assets/'images.json').read_text())
    if len(set(m['sha256'] for m in manifest)) != len(manifest): raise ValueError('Duplicate source captures')
    enrolled={m['person'] for m in manifest if m['split']=='enroll'}
    if any(m['person'] in enrolled for m in manifest if m['split']=='unknown_test'): raise ValueError('Unknown gallery leak')
    images, original_faces, gallery = {},{},{}
    for m in manifest:
        image=cv2.imread(str(checked_file(args.assets,m['path'],m['sha256'])))
        if image is None: raise ValueError('Undecodable source')
        h,w=image.shape[:2]; scale=min(1.,1024/max(h,w))
        image=cv2.resize(image,(round(w*scale),round(h*scale)))
        faces=detect(detector,image)
        if len(faces)!=1: raise ValueError('Original portrait has no unique face: '+m['id'])
        images[m['id']]=image; original_faces[m['id']]=faces[0]
        if m['split']=='enroll':
            if m['person'] in gallery: raise ValueError('Multiple enrollment captures')
            gallery[m['person']]=recognizer.feature(recognizer.alignCrop(image,faces[0])).copy()
    if set(gallery)!=enrolled: raise ValueError('Enrollment failed')

    def classify(image, row):
        row.update(candidate=None,scores=[],facesDetected=None,reason='detector_error',processedSize=[image.shape[1],image.shape[0]])
        try: faces=detect(detector,image)
        except cv2.error as error:
            row['error']=str(error); return row
        row['facesDetected']=len(faces)
        row['faceBoxes']=[list(map(float,f[:4])) for f in faces]
        if len(faces)!=1:
            row['reason']='no_face' if not faces else 'multiple_faces'; return row
        try:
            feature=recognizer.feature(recognizer.alignCrop(image,faces[0])).copy()
            if not np.isfinite(feature).all() or np.linalg.norm(feature)==0: raise ValueError('Invalid embedding')
            row['scores']=sorted([dict(identity=i,cosine=float(recognizer.match(feature.copy(),f.copy(),cv2.FaceRecognizerSF_FR_COSINE))) for i,f in gallery.items()],key=lambda s:s['cosine'],reverse=True)
            if not all(np.isfinite(s['cosine']) for s in row['scores']): raise ValueError('Invalid score')
        except (cv2.error,ValueError) as error:
            row['reason']='embedding_error'; row['error']=str(error); return row
        best=row['scores'][0]; margin=best['cosine']-row['scores'][1]['cosine'] if len(row['scores'])>1 else None
        row['runnerUpMargin']=margin
        if best['cosine']<THRESHOLD: row['reason']='below_threshold'
        elif margin is not None and margin<MARGIN: row['reason']='runner_up'
        else: row.update(candidate=best['identity'],reason='experimental_candidate')
        return row

    probes=[m for m in manifest if m['split']!='enroll']
    rows=[]
    for condition,kind,value in CONDITIONS:
        for m in probes:
            rows.append(classify(transform(images[m['id']],original_faces[m['id']],kind,value),dict(sourceId=m['id'],condition=condition,truth=m['person'] if m['split']=='known_test' else None)))
    composites=[]
    def tile(m, size):
        im=images[m['id']]; h,w=im.shape[:2]; scale=size/max(h,w)
        return cv2.resize(im,(max(1,round(w*scale)),max(1,round(h*scale))),interpolation=cv2.INTER_AREA)
    for left,right in itertools.combinations(probes,2):
        canvas=np.zeros((512,1024,3),dtype=np.uint8)
        for index,m in enumerate((left,right)):
            im=tile(m,512); h,w=im.shape[:2]; canvas[:h,index*512:index*512+w]=im
        composites.append(classify(canvas,dict(condition='two_portrait_panels',sourceIds=[left['id'],right['id']],truth=None,expectedFaces=2,expectedDecision='abstain_ambiguous_scene')))
    # Explicit detector-count limitation: small second face can go unnoticed.
    left,right=probes[0],probes[-1]
    canvas=np.zeros((512,1024,3),dtype=np.uint8)
    for x,m,size in ((0,left,512),(700,right,32)):
        im=tile(m,size); h,w=im.shape[:2]; canvas[:h,x:x+w]=im
    composites.append(classify(canvas,dict(condition='one_large_one_tiny_portrait',sourceIds=[left['id'],right['id']],truth=None,expectedFaces=2,expectedDecision='abstain_ambiguous_scene')))
    report=dict(status='SYNTHETIC CONDITION STRESS ONLY; NOT PRODUCTION VALIDATION',python=platform.python_version(),opencv=cv2.__version__,numpy=np.__version__,modelHashes=MODEL_FILES,threshold=THRESHOLD,margin=MARGIN,calibrated=False,
        protocol='Exact original enrollment images, unchanged except baseline max-side1024 preprocessing; four distinct held-out captures; all degradations in memory. No training or threshold tuning.',
        conditions=[dict(name=n,type=k,value=v) for n,k,v in CONDITIONS],
        denominators=dict(enrolledIdentities=len(gallery),uniquePeople=len(set(m['person'] for m in manifest)),originalSourceImages=len(manifest),distinctProbeCaptures=len(probes),distinctKnownPeople=2,distinctUnknownPeople=2,transformedObservations=len(rows),compositeScenes=len(composites)),
        counts=counts(rows),byCondition={name:counts([r for r in rows if r['condition']==name]) for name,_,_ in CONDITIONS},rows=rows,
        compositeCounts=dict(scenes=len(composites),detectedMultiple=sum(r['facesDetected'] is not None and r['facesDetected']>1 for r in composites),abstained=sum(r['candidate'] is None for r in composites),namedDespiteTwoSourceFaces=sum(r['candidate'] is not None for r in composites)),composites=composites,
        photoInput=dict(baselineAcceptedKnown=sum(r['candidate']==r['truth'] for r in rows if r['condition']=='original_photo' and r['truth'] is not None),knownPhotoInputs=2,presentationAttackDetection='absent',physicalPrintOrScreenTrialsPerformed=False),
        limits=['Correlated transformations of four probe photos, not64 independent people or encounters.','Synthetic brightness/blur/occlusion/roll do not reproduce real lighting, motion, masks or yaw.','Public figures may overlap model training; convenient tiny adult portraits are not children, relatives or school/pickup/crowd evidence.','Two-photo composites do not test tracking, crossings, identity association or camera video.','A unique DETECTED face does not establish only one real face is present.','Photo input acceptance establishes no PAD barrier, not a measured physical spoof attack rate.','No iOS numerical parity, latency, thermal, battery, guardian authorization or safe-to-follow validation.','Source metadata has rights caveats documented in README; source files unmodified, in-memory transforms never saved or redistributed.'],sources=manifest)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ('denominators','counts','byCondition','compositeCounts','photoInput')},indent=2))

if __name__=='__main__': main()
