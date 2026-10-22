"""Post-hoc ORL enrollment ablation. NOT held-out validation or calibration.

No model/image/vector is written. All configurations use the same probe IDs.
Official OpenCV match performs cosine scoring, separately for each identity;
runner-up means another identity, never another template of the same person.
"""
import argparse
from collections import Counter
import hashlib
import json
import pathlib
import zipfile
import cv2
import numpy as np
from image_smoke import MODEL_FILES, checked_file

THRESHOLDS = (.363, .45, .55, .65)
MARGINS = (.1, .2)
METHODS = ('single', 'max3', 'mean3')


def normalize(vector):
    vector = np.asarray(vector, dtype=np.float32).reshape(1, -1)
    norm = float(np.linalg.norm(vector))
    if not np.isfinite(vector).all() or not np.isfinite(norm) or norm <= 0:
        raise ValueError('Invalid feature')
    return vector / norm


def split(method, historical=False):
    enrollment = {f's{i}/{j}.pgm' for i in range(1, 21)
                  for j in (range(1, 2) if method == 'single' else range(1, 4))}
    probes = [f's{i}/{j}.pgm' for i in range(1, 41)
              for j in range(1, 11) if i > 20 or j >= (2 if historical else 4)]
    assert not enrollment.intersection(probes)
    return enrollment, probes


def decide(scores, threshold, margin):
    ranked = sorted(scores, key=lambda row: (-row[1], row[0]))
    if not ranked:
        return None, 'empty_gallery'
    if ranked[0][1] < threshold:
        return None, 'below_threshold'
    if len(ranked) > 1 and ranked[0][1] - ranked[1][1] < margin:
        return None, 'runner_up'
    return ranked[0][0], 'candidate'


def extract(assets):
    root = assets / 'orl'
    expected = {f's{i}/{j}.pgm' for i in range(1, 41) for j in range(1, 11)}
    if {str(p.relative_to(root)) for p in root.glob('s*/*.pgm')} != expected:
        raise ValueError('Expected exactly original 400-image layout')
    archive = checked_file(root, 'att_faces.zip', '509d763bd2276aa054d260d7f1000e8be212738134f2f83d8ff13bc2adf1c8ec')
    models = {n: checked_file(assets, 'models/' + n, h) for n, h in MODEL_FILES.items()}
    detector = cv2.FaceDetectorYN_create(str(models['face_detection_yunet_2023mar.onnx']), '', (92, 112), .9, .3, 5000)
    recognizer = cv2.FaceRecognizerSF_create(str(models['face_recognition_sface_2021dec.onnx']), '')
    features, observations, hashes = {}, {}, set()
    with zipfile.ZipFile(archive) as original:
        for key in sorted(expected):
            path = root / key
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest != hashlib.sha256(original.read(key)).hexdigest() or digest in hashes:
                raise ValueError('Changed or duplicate image')
            hashes.add(digest)
            image = cv2.imread(str(path), cv2.IMREAD_COLOR)
            if image is None or image.shape != (112, 92, 3):
                raise ValueError('Wrong dimensions')
            if not (np.array_equal(image[:, :, 0], image[:, :, 1]) and np.array_equal(image[:, :, 0], image[:, :, 2])):
                raise ValueError('Expected replicated grayscale BGR')
            _, faces = detector.detect(image)
            count = 0 if faces is None else len(faces)
            record = {'sha256': digest, 'facesDetected': count, 'geometryPass': False}
            if count == 1:
                face = faces[0]
                features[key] = normalize(recognizer.feature(recognizer.alignCrop(image, face)).copy())
                x, y, w, h = (float(v) for v in face[:4])
                landmarks = face[4:14].reshape(5, 2)
                record['geometryPass'] = bool(x >= 0 and y >= 0 and w > 0 and h > 0 and x+w <= 92 and y+h <= 112 and np.all(landmarks >= 0) and np.all(landmarks[:, 0] < 92) and np.all(landmarks[:, 1] < 112))
            observations[key] = record
    return recognizer, features, observations


def evaluate(recognizer, features, observations, method, threshold, margin, geometry=False, historical=False):
    enrollment, probes = split(method, historical)
    gallery = {}
    for i in range(1, 21):
        keys = sorted(k for k in enrollment if k.startswith(f's{i}/'))
        templates = [features[k] for k in keys if k in features and (not geometry or observations[k]['geometryPass'])]
        if templates:
            gallery[i] = [normalize(np.mean(templates, axis=0))] if method == 'mean3' else templates
    rows = []
    for key in probes:
        identity = int(key.split('/')[0][1:])
        scores = []
        if key not in features:
            candidate, reason = None, 'no_unique_face'
        elif geometry and not observations[key]['geometryPass']:
            candidate, reason = None, 'geometry_gate'
        else:
            # match() may normalize its input in-place; copy to preserve shared features.
            scores = [(i, max(float(recognizer.match(features[key].copy(), t.copy(), cv2.FaceRecognizerSF_FR_COSINE)) for t in templates)) for i, templates in gallery.items()]
            candidate, reason = decide(scores, threshold, margin)
        rows.append({'image': key, 'identity': identity, 'known': identity <= 20,
                     'candidate': candidate, 'reason': reason})
    known = [r for r in rows if r['known']]
    unknown = [r for r in rows if not r['known']]
    false_rows = [r for r in rows if r['candidate'] is not None and r['candidate'] != r['identity']]
    summary = {'knownTotal': len(known), 'unknownTotal': len(unknown),
               'knownCorrect': sum(r['candidate'] == r['identity'] for r in known),
               'knownWrong': sum(r['candidate'] is not None and r['candidate'] != r['identity'] for r in known),
               'knownAbstain': sum(r['candidate'] is None for r in known),
               'unknownFalseName': sum(r['candidate'] is not None for r in unknown),
               'unknownAbstain': sum(r['candidate'] is None for r in unknown),
               'namedTotal': sum(r['candidate'] is not None for r in rows),
               'probeTotal': len(rows),
               'falseNameIdentityPairs': dict(Counter(f"s{r['identity']}->s{r['candidate']}" for r in false_rows)),
               'knownAbstentionIdentityGroups': dict(Counter(f"s{r['identity']}" for r in known if r['candidate'] is None)),
               'abstentionReasons': dict(Counter(r['reason'] for r in rows if r['candidate'] is None)),
               'galleryIdentities': len(gallery),
               'availableEnrollmentTemplates': sum(k in features and (not geometry or observations[k]['geometryPass']) for k in enrollment)}
    summary['namingCoverage'] = summary['namedTotal'] / len(rows)
    return {'method': method, 'threshold': threshold, 'margin': margin, 'geometryGate': geometry,
            'summary': summary, 'results': rows}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--assets', type=pathlib.Path, required=True)
    p.add_argument('--output', type=pathlib.Path, required=True)
    args = p.parse_args()
    cv2.setNumThreads(1)
    recognizer, features, observations = extract(args.assets)
    baseline = evaluate(recognizer, features, observations, 'single', .363, .1, historical=True)
    experiments = [evaluate(recognizer, features, observations, method, threshold, margin)
                   for method in METHODS for threshold in THRESHOLDS for margin in MARGINS]
    experiments += [evaluate(recognizer, features, observations, method, .363, .1, geometry=True) for method in METHODS]
    report = {'purpose': __doc__, 'opencv': cv2.__version__, 'models': MODEL_FILES,
              'sourceSha256': hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),
              'protocol': 'Predeclared after consuming original baseline: enrollment single=image1 or max3/mean3=images1..3 of s1..s20. ALL comparative rows use known images4..10 (140) and unknown s21..s40 images1..10 (200). No replacement of failed enrollments. All probe failures remain denominators. Single does not use reserved images2..3.',
              'geometryGateDefinition': 'Enrollment and probes: positive-size box entirely inside original image and all five landmarks inside original image. No pose, blur or identity confidence claim.',
              'thresholds': THRESHOLDS, 'margins': MARGINS,
              'limitations': ['Consumed data, no untouched test or independent threshold calibration. Do not choose app defaults from these results.', 'Controlled grayscale cropped images; correlated identities and images, no demographic or device generalization.', 'Unknown abstention includes detector misses, not evidence of successful recognition.', 'Enrollment gains cannot be inferred by comparing historical180 known probes to fixed140 comparative probes.', 'Geometry checks do not establish face quality, liveness, consent, guardianship or security.', 'No model training, model changes, app changes, images or embeddings exported.'],
              'detection': {'unique': len(features), 'failed': len(observations)-len(features)},
              'observations': observations, 'historicalBaselineReproduction': baseline, 'experiments': experiments}
    args.output.write_text(json.dumps(report, indent=2))
    for row in [baseline] + experiments:
        print(json.dumps({k: row[k] for k in ('method', 'threshold', 'margin', 'geometryGate', 'summary')}))

if __name__ == '__main__':
    main()
