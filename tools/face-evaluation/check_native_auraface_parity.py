#!/usr/bin/env python3
"""Real-photo parity for the native AuraFace preprocessing route, NOT an Apple test.
Requires existing local ORL/model assets; never downloads or writes biometric vectors.
"""
import argparse
import gc
import json
from pathlib import Path
import cv2
import numpy as np


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assets', type=Path, required=True)
    args = parser.parse_args()
    cv2.setNumThreads(1)
    model = str(args.assets / 'auraface/glintr100.onnx')
    detector = cv2.FaceDetectorYN.create(str(args.assets / 'models/face_detection_yunet_2023mar.onnx'), '', (320, 320), 0.9, 0.3, 5000)
    recognizer = cv2.FaceRecognizerSF.create(model, '')
    crops = []
    # Previously used, public research photographs; never used as new held-out evidence.
    for relative in ['s1/1.pgm', 's1/2.pgm', 's2/1.pgm', 's2/2.pgm']:
        frame = cv2.imread(str(args.assets / 'orl' / relative))
        if frame is None:
            raise RuntimeError('Required local ORL photo missing')
        frame = cv2.resize(frame, None, fx=3, fy=3)
        detector.setInputSize((frame.shape[1], frame.shape[0]))
        _, faces = detector.detect(frame)
        if faces is None or len(faces) != 1:
            raise RuntimeError('Expected exactly one face in parity fixture')
        crops.append(recognizer.alignCrop(frame, faces[0]))
    actual = []
    for crop in crops:
        # Mirrors native convertTo(float), subtract Scalar, multiply then feature.
        normalized = crop.astype(np.float32)
        normalized -= np.float32(127.5)
        normalized *= np.float32(1 / 127.5)
        actual.append(recognizer.feature(normalized).copy())
    native_scores = [float(recognizer.match(actual[0].copy(), x.copy(), cv2.FaceRecognizerSF_FR_COSINE)) for x in actual]
    del recognizer
    gc.collect()
    net = cv2.dnn.readNetFromONNX(model)
    expected = []
    for crop in crops:
        net.setInput(cv2.dnn.blobFromImage(crop, 1 / 127.5, (112, 112), (127.5, 127.5, 127.5), swapRB=True))
        expected.append(net.forward().copy())
    reference_scores = [float(np.dot(expected[0].flatten(), x.flatten()) / (np.linalg.norm(expected[0]) * np.linalg.norm(x))) for x in expected]
    max_error = max(float(np.max(np.abs(a - b))) for a, b in zip(actual, expected))
    score_error = max(abs(a - b) for a, b in zip(native_scores, reference_scores))
    assert all(x.shape == (1, 512) and np.isfinite(x).all() for x in actual)
    assert max_error < 1e-5, max_error
    assert score_error < 1e-6, score_error
    # A route parity check at an illustrative threshold, NOT threshold calibration.
    assert [s >= 0.5 for s in native_scores] == [s >= 0.5 for s in reference_scores]
    print(json.dumps({'opencv': cv2.__version__, 'photographs': len(crops), 'dimension': 512,
                      'maxAbsFeatureDifference': max_error, 'maxAbsCosineDifference': score_error,
                      'illustrativeThresholdDecisionParity': True, 'passed': True, 'scope': 'Linux OpenCV real-photo route parity only; no Apple/iPhone validation'}, indent=2))


if __name__ == '__main__':
    main()
