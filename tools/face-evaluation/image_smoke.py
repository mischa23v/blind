"""Offline, isolated OpenCV smoke test. No app import, network, training, or PAD."""
import argparse, hashlib, json, pathlib, time
import cv2
import numpy as np

MODEL_FILES = {
 'face_detection_yunet_2023mar.onnx': '8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4',
 'face_recognition_sface_2021dec.onnx': '0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79',
}
# Frozen before inspecting image scores: upstream demo cosine threshold, and an
# experimental margin, NOT calibrated on these four people or suitable for an app.
THRESHOLD, MARGIN = 0.363, 0.1

def checked_file(root, relative, expected):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()): raise ValueError('Path outside asset root')
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected: raise ValueError('Asset hash mismatch')
    return path

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--assets', type=pathlib.Path, required=True)
    p.add_argument('--output', type=pathlib.Path, required=True)
    args = p.parse_args()
    cv2.setNumThreads(1)
    models = {name: checked_file(args.assets, 'models/' + name, sha) for name, sha in MODEL_FILES.items()}
    detector = cv2.FaceDetectorYN_create(str(models['face_detection_yunet_2023mar.onnx']), '', (320, 320), 0.9, 0.3, 5000)
    recognizer = cv2.FaceRecognizerSF_create(str(models['face_recognition_sface_2021dec.onnx']), '')
    manifest = json.loads((args.assets / 'images.json').read_text())
    if len({m['sha256'] for m in manifest}) != len(manifest): raise ValueError('Duplicate images across splits')
    enrolled = {m['person'] for m in manifest if m['split'] == 'enroll'}
    if any(m['person'] in enrolled for m in manifest if m['split'] == 'unknown_test'): raise ValueError('Unknown identity leaks into gallery')
    observations, features, gallery = [], {}, {}
    for m in manifest:
        path = checked_file(args.assets, m['path'], m['sha256'])
        image = cv2.imread(str(path))
        if image is None: raise ValueError('Cannot decode ' + m['id'])
        height, width = image.shape[:2]
        scale = min(1., 1024 / max(height, width))
        image = cv2.resize(image, (round(width * scale), round(height * scale)))
        detector.setInputSize((image.shape[1], image.shape[0]))
        start = time.perf_counter()
        _, faces = detector.detect(image)
        count = 0 if faces is None else len(faces)
        record = {'id': m['id'], 'split': m['split'], 'facesDetected': count,
                  'sourceSize': [width, height], 'processedSize': [image.shape[1], image.shape[0]]}
        if count == 1:
            crop = recognizer.alignCrop(image, faces[0])
            feature = recognizer.feature(crop).copy()
            if not np.isfinite(feature).all() or np.linalg.norm(feature) == 0: raise ValueError('Invalid model embedding')
            features[m['id']] = feature
            record.update(detectionScore=float(faces[0][-1]), embeddingDimensions=int(feature.size))
            if m['split'] == 'enroll':
                if m['person'] in gallery: raise ValueError('This smoke protocol uses one enrollment image per person')
                gallery[m['person']] = feature
        else:
            record['status'] = 'abstain_no_unique_face'
        record['cloudCpuElapsedMs'] = (time.perf_counter() - start) * 1000
        observations.append(record)
    if set(gallery) != enrolled: raise ValueError('Enrollment failed; no test claims produced')
    results, negative_scores, positive_scores = [], [], []
    for m in manifest:
        if m['split'] == 'enroll': continue
        truth = m['person'] if m['split'] == 'known_test' else None
        scores = []
        if m['id'] in features:
            for identity, feature in gallery.items():
                score = float(recognizer.match(features[m['id']].copy(), feature.copy(), cv2.FaceRecognizerSF_FR_COSINE))
                if not np.isfinite(score): raise ValueError('Invalid match score')
                scores.append({'identity': identity, 'cosine': score})
                (positive_scores if identity == truth else negative_scores).append(score)
        scores.sort(key=lambda s: s['cosine'], reverse=True)
        accepted, reason = None, 'no_unique_face'
        if scores:
            margin = scores[0]['cosine'] - scores[1]['cosine'] if len(scores) > 1 else None
            if scores[0]['cosine'] < THRESHOLD: reason = 'below_threshold'
            elif margin is not None and margin < MARGIN: reason = 'runner_up'
            else: accepted, reason = scores[0]['identity'], 'experimental_candidate'
        results.append({'id': m['id'], 'truth': truth, 'scores': scores, 'candidate': accepted, 'reason': reason})
    known = [r for r in results if r['truth'] is not None]
    unknown = [r for r in results if r['truth'] is None]
    counts = {'knownProbes': len(known), 'unknownProbes': len(unknown),
      'knownCorrect': sum(r['candidate'] == r['truth'] for r in known),
      'knownWrongIdentity': sum(r['candidate'] is not None and r['candidate'] != r['truth'] for r in known),
      'knownAbstained': sum(r['candidate'] is None for r in known),
      'unknownFalseIdentification': sum(r['candidate'] is not None for r in unknown),
      'unknownAbstained': sum(r['candidate'] is None for r in unknown),
      'matedComparisons': len(positive_scores), 'matedBelowThreshold': sum(s < THRESHOLD for s in positive_scores),
      'nonmatedComparisons': len(negative_scores), 'nonmatedAtOrAboveThreshold': sum(s >= THRESHOLD for s in negative_scores)}
    report = {'status': 'TINY PUBLIC-PORTRAIT SMOKE TEST ONLY; NOT SAFETY VALIDATION',
      'opencv': cv2.__version__, 'modelHashes': MODEL_FILES,
      'threshold': THRESHOLD, 'margin': MARGIN, 'calibrated': False,
      'protocol': 'One enrollment photo each for two identities; separate actual captures for two known probes; two other identities unknown. No tuning, no training.',
      'limits': ['No identity-disjoint calibration set; values frozen before inference.',
        'Possible model training overlap with public figures; not independent benchmark evidence.',
        'Tiny convenient frontal adult portrait sample, not representative of users or camera scenes.',
        'No PAD, liveness, physical guardian binding, child trials, or iOS validation.',
        'Pair comparisons share images and are not independent trials.',
        'All processing local to isolated cloud research runtime, no user or family data.'],
      'counts': counts, 'observations': observations, 'results': results, 'sources': manifest}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2))
    print(json.dumps(counts, indent=2))
if __name__ == '__main__': main()
