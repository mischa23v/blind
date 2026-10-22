"""Predeclared, label-disjoint Aberdeen calibration and held-out research evaluation."""
import argparse
import collections
import hashlib
import json
import pathlib
import re
import time
import zipfile

import cv2
import numpy as np
from alternate_model import AURA_SHA, THRESHOLDS, MARGINS, decide
from benchmark import metric
from image_smoke import MODEL_FILES, checked_file

ARCHIVE_SHA = '162772fe62940fc27ad00c55a75b41f7f41da7c92d0688b8c8e895eda55a544d'
ANCHOR = {'threshold': 0.363, 'margin': 0.1}


def make_protocol(names):
    groups = collections.defaultdict(list)
    for name in names:
        match = re.fullmatch(r'([a-z_]+)([0-9]+)\.jpg', name)
        if match and not match[1].startswith('clean_'):
            groups[match[1]].append((int(match[2]), name))
    groups = {key: sorted(value) for key, value in groups.items() if len(value) >= 4}
    labels = sorted(groups)
    phases = {}
    for offset, phase in enumerate(['calibration', 'heldout']):
        people = labels[offset::2]
        gallery = people[:10]
        observations = []
        for person in people:
            for index, (_, name) in enumerate(groups[person]):
                observations.append({'image': name, 'identity': person,
                                     'known': person in gallery,
                                     'enrollment': person in gallery and index == 0})
        phases[phase] = {'identities': people, 'galleryIdentities': gallery, 'observations': observations}
    selected = {r['image'] for phase in phases.values() for r in phase['observations']}
    return {'archiveSHA256': ARCHIVE_SHA, 'frozenAnchor': ANCHOR,
            'thresholds': THRESHOLDS, 'margins': MARGINS,
            'selection': 'Calibration only: minimize false unknown names plus wrong known names; maximize known correct; then higher threshold and margin. No held-out tuning.',
            'phases': phases, 'excludedImages': sorted(set(names) - selected),
            'labelCaveat': 'Filename stems are presumed provider identity labels, not independently verified biological identities. Excludes singleton/irregular names and clean_ alias. Training and cross-dataset identity overlap unverified.'}


def summarize(rows, threshold, margin):
    candidates = [decide(row['ranking'], threshold, margin) for row in rows]
    known = [(row, candidate) for row, candidate in zip(rows, candidates) if row['known']]
    unknown = [(row, candidate) for row, candidate in zip(rows, candidates) if not row['known']]
    unknown_people = {row['identity'] for row, _ in unknown}
    errors = [row for row, candidate in unknown if candidate is not None]
    return {'knownCorrect': metric(sum(candidate == row['identity'] for row, candidate in known), len(known)),
            'knownWrong': metric(sum(candidate is not None and candidate != row['identity'] for row, candidate in known), len(known)),
            'knownAbstain': metric(sum(candidate is None for _, candidate in known), len(known)),
            'unknownFalseIdentification': metric(len(errors), len(unknown)),
            'unknownAbstain': metric(len(unknown) - len(errors), len(unknown)),
            'unknownIdentitiesWithAnyFalseIdentification': metric(len({row['identity'] for row in errors}), len(unknown_people)),
            'falseUnknownImages': [row['image'] for row in errors],
            'candidates': candidates}


def select_policy(grid):
    def key(row):
        counts = row['result']
        return (counts['unknownFalseIdentification']['numerator'] + counts['knownWrong']['numerator'],
                -counts['knownCorrect']['numerator'], -row['threshold'], -row['margin'])
    winner = min(grid, key=key)
    return {key: winner[key] for key in ['threshold', 'margin']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets', type=pathlib.Path, required=True)
    parser.add_argument('--protocol', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    archive_path = checked_file(args.assets, 'aberdeen/Aberdeen.zip', ARCHIVE_SHA)
    archive = zipfile.ZipFile(archive_path)
    protocol = make_protocol(archive.namelist())
    hashes = {name: hashlib.sha256(archive.read(name)).hexdigest() for name in archive.namelist()}
    if len(set(hashes.values())) != len(hashes):
        raise ValueError('Duplicate image bytes: revise protocol before inference')
    protocol['imageSHA256'] = hashes
    protocol['modelSHA256'] = {**MODEL_FILES, 'glintr100.onnx': AURA_SHA}
    if args.prepare_only:
        if args.protocol.exists():
            raise ValueError('Refusing to replace existing predeclared protocol')
        args.protocol.write_text(json.dumps(protocol, indent=2) + '\n')
        print('Protocol prepared without model inference', flush=True)
        return
    if protocol != json.loads(args.protocol.read_text()):
        raise ValueError('Archive/selection differs from predeclared protocol')
    cv2.setNumThreads(1)
    models = {name: checked_file(args.assets, 'models/' + name, sha) for name, sha in MODEL_FILES.items()}
    detector = cv2.FaceDetectorYN.create(str(models['face_detection_yunet_2023mar.onnx']), '', (320, 320), .9, .3, 5000)
    sface = cv2.FaceRecognizerSF.create(str(models['face_recognition_sface_2021dec.onnx']), '')
    aura = cv2.dnn.readNetFromONNX(str(checked_file(args.assets, 'auraface/glintr100.onnx', AURA_SHA)))
    selected_policies = {}
    results = {}
    start = time.perf_counter()
    for phase_name, phase in protocol['phases'].items():
        features = {'sface': {}, 'auraface': {}}
        observations = []
        for index, item in enumerate(phase['observations']):
            row = dict(item)
            image = cv2.imdecode(np.frombuffer(archive.read(item['image']), np.uint8), cv2.IMREAD_COLOR)
            count = 0
            if image is None:
                row['status'] = 'decodeFailure'
            else:
                detector.setInputSize((image.shape[1], image.shape[0]))
                _, faces = detector.detect(image)
                count = 0 if faces is None else len(faces)
                row['status'] = 'uniqueFace' if count == 1 else 'noFace' if count == 0 else 'multipleFaces'
                if count == 1:
                    crop = sface.alignCrop(image, faces[0])
                    sf = sface.feature(crop).reshape(-1)
                    aura.setInput(cv2.dnn.blobFromImage(crop, 1 / 127.5, (112, 112), (127.5, 127.5, 127.5), swapRB=True))
                    af = aura.forward().reshape(-1)
                    for name, vector in [('sface', sf), ('auraface', af)]:
                        if not np.all(np.isfinite(vector)) or np.linalg.norm(vector) <= 0:
                            raise ValueError('Invalid embedding; abort rather than hide runtime failure')
                        features[name][item['image']] = vector / np.linalg.norm(vector)
            row['detectedFaceCount'] = count
            observations.append(row)
            if index % 50 == 49:
                print(phase_name, index + 1, '/', len(phase['observations']), flush=True)
        phase_result = {'observations': observations,
                        'statusCounts': dict(collections.Counter(row['status'] for row in observations)),
                        'models': {}}
        for model_name, vectors in features.items():
            gallery = {row['identity']: vectors[row['image']] for row in observations if row['enrollment'] and row['image'] in vectors}
            probe_rows = []
            for row in observations:
                if row['enrollment']:
                    continue
                scores = [] if row['image'] not in vectors else sorted(
                    [(person, float(np.dot(vectors[row['image']], vector))) for person, vector in gallery.items()],
                    key=lambda entry: entry[1], reverse=True)
                probe_rows.append({**row, 'ranking': scores})
            model_result = {'intendedGallerySize': len(phase['galleryIdentities']), 'successfulGallerySize': len(gallery),
                            'failedEnrollmentIdentities': sorted(set(phase['galleryIdentities']) - set(gallery)),
                            'anchor': summarize(probe_rows, **ANCHOR), 'probeScores': probe_rows}
            if phase_name == 'calibration':
                grid = [{'threshold': threshold, 'margin': margin, 'result': summarize(probe_rows, threshold, margin)}
                        for threshold in THRESHOLDS for margin in MARGINS]
                selected_policies[model_name] = select_policy(grid)
                model_result['calibrationGrid'] = grid
            model_result['calibrationSelectedPolicy'] = selected_policies[model_name]
            model_result['selectedPolicyResult'] = summarize(probe_rows, **selected_policies[model_name])
            phase_result['models'][model_name] = model_result
        results[phase_name] = phase_result
        if phase_name == 'calibration':
            calibration_file = args.output.with_suffix('.calibration.json')
            calibration_file.write_text(json.dumps({'protocolSHA256': hashlib.sha256(args.protocol.read_bytes()).hexdigest(),
                                                    'selectedPolicies': selected_policies, 'calibration': phase_result}, indent=2) + '\n')
            print('CALIBRATION FROZEN BEFORE HELDOUT', selected_policies, flush=True)
    report = {'protocolSHA256': hashlib.sha256(args.protocol.read_bytes()).hexdigest(), 'opencv': cv2.__version__,
              'elapsedSeconds': time.perf_counter() - start, 'results': results,
              'limits': ['Identity labels inferred from canonical provider filenames, not independently established.',
                         'Images cluster within identities and acquisition sessions; Wilson query intervals are nominal only.',
                         'No test-set threshold tuning or replacement of failed enrollment/probes.',
                         'Biological cross-dataset identity overlap, training overlap, demographics, PAD and iOS parity unverified.',
                         'Research-use images must not be redistributed with source or reports.']}
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'elapsedSeconds': report['elapsedSeconds'], 'selectedPolicies': selected_policies}), flush=True)


if __name__ == '__main__':
    main()
