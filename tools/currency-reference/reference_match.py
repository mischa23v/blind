#!/usr/bin/env python3
"""Reconstructed 2026-10-22 after workspace loss; NOT original frozen bytes.

Unvalidated no-training evidence-only adapter to official OpenCV feature APIs.
Historical photo outcomes must not be attributed to this reconstruction.
"""
from __future__ import annotations
import argparse
from dataclasses import asdict, dataclass
import hashlib
import io
import json
import math
from pathlib import Path
import re
import sys
import warnings
import numpy as np
from PIL import Image
try:
    import cv2
except ImportError:
    cv2 = None

LABELS = [1, 5, 10, 20, 50, 100, 200, 500]
MAX_REFERENCES = 48
MAX_MANIFEST_BYTES = 256 * 1024
MAX_FILE_BYTES = 8 * 1024 * 1024
MAX_IMAGE_PIXELS = 8_000_000
MAX_IMAGE_SIDE = 4096
DISCLAIMER = ('Reconstructed unvalidated local reference-matching experiment; not banknote accuracy, '
              'authenticity, legal-tender status, single-note proof or a monetary answer. No iPhone integration.')

@dataclass(frozen=True)
class Policy:
    max_query_side: int = 1200
    max_reference_side: int = 800
    max_features: int = 1800
    ratio_test: float = 0.72
    ransac_error_px: float = 3.0
    ransac_iterations: int = 1500
    min_inliers: int = 14
    min_inlier_ratio: float = 0.42
    min_reference_spread: float = 0.20
    min_query_spread: float = 0.20
    min_grid_cells: int = 5
    min_quad_area_fraction: float = 0.04
    max_quad_area_fraction: float = 0.90
    min_quad_angle_deg: float = 25.0
    max_quad_angle_deg: float = 155.0
    max_edge_ratio: float = 6.0
    max_opposite_edge_ratio: float = 3.0
    max_projective_denominator_ratio: float = 3.0
    max_reprojection_median_px: float = 2.5
    min_score: float = 7.0
    min_different_label_score_ratio: float = 1.6
    min_different_label_score_gap: float = 4.0
    distinct_region_overlap: float = 0.25

POLICY = Policy()
# Numeric OpenCV enum values retained to permit schema/policy tests without cv2.
ALGORITHMS = {
    'sift': {'nfeatures': 1800, 'nOctaveLayers': 3, 'contrastThreshold': .04,
             'edgeThreshold': 10, 'sigma': 1.6, 'enable_precise_upscale': False},
    'orb': {'nfeatures': 1800, 'scaleFactor': 1.2, 'nlevels': 8, 'edgeThreshold': 31,
            'firstLevel': 0, 'WTA_K': 2, 'scoreType': 0, 'patchSize': 31, 'fastThreshold': 20},
    'akaze': {'descriptor_type': 5, 'descriptor_size': 0, 'descriptor_channels': 3,
              'threshold': .001, 'nOctaves': 4, 'nOctaveLayers': 4, 'diffusivity': 1, 'max_points': 1800},
}
class InputError(ValueError):
    pass

def need_cv2():
    if cv2 is None:
        raise InputError('Official OpenCV cv2 dependency unavailable; no replacement or download attempted')
    cv2.setNumThreads(1)
    cv2.ocl.setUseOpenCL(False)

def create_detector(algorithm):
    if type(algorithm) is not str or algorithm not in ALGORITHMS:
        raise InputError('Unsupported algorithm; choose sift, orb, or akaze')
    need_cv2()
    return {'sift': cv2.SIFT_create, 'orb': cv2.ORB_create, 'akaze': cv2.AKAZE_create}[algorithm](**ALGORITHMS[algorithm])

def bounded_bytes(path: Path, limit: int):
    if not path.is_file():
        raise InputError('A required local file is absent or not regular')
    with path.open('rb') as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise InputError('Local file exceeds byte limit')
    return data

def strict_json_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise InputError('Duplicate JSON keys forbidden')
        result[key] = value
    return result

def require_fields(obj, fields, name):
    if type(obj) is not dict or set(obj) != fields:
        raise InputError(name + ' must have exactly the documented fields')

def text_field(value, name):
    if type(value) is not str or not value.strip() or len(value) > 256:
        raise InputError(name + ' must be nonempty text up to 256 characters')

def local_path(root, relative):
    text_field(relative, 'path')
    rel = Path(relative)
    if rel.is_absolute() or '..' in rel.parts or ':' in relative:
        raise InputError('Only contained relative local paths are allowed')
    resolved = (root / rel).resolve()
    if not resolved.is_relative_to(root):
        raise InputError('Path escapes manifest directory')
    return resolved

def checked_hash(data, expected):
    if type(expected) is not str or not re.fullmatch(r'[0-9a-f]{64}', expected):
        raise InputError('SHA256 must be lowercase 64-digit hex')
    if hashlib.sha256(data).hexdigest() != expected:
        raise InputError('SHA256 mismatch')

def image_from_bytes(data, max_side):
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as header:
                width, height = header.size
                if header.format not in {'PNG', 'JPEG'} or getattr(header, 'n_frames', 1) != 1:
                    raise InputError('Only single-frame PNG/JPEG inputs are supported')
                if min(width, height) < 32 or max(width, height) > MAX_IMAGE_SIDE or width * height > MAX_IMAGE_PIXELS:
                    raise InputError('Image dimensions exceed bounds or are too small')
                if header.getexif().get(274, 1) != 1:
                    raise InputError('Normalize EXIF orientation locally before hashing')
        need_cv2()
        gray = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_GRAYSCALE | cv2.IMREAD_IGNORE_ORIENTATION)
        if gray is None or gray.shape != (height, width):
            raise InputError('Image decode is inconsistent')
        scale = min(1., max_side / max(width, height))
        if scale < 1:
            gray = cv2.resize(gray, (round(width * scale), round(height * scale)), interpolation=cv2.INTER_AREA)
        return gray
    except InputError:
        raise
    except Exception as exc:
        raise InputError('Image header or decode failed') from exc

def load_manifest(path):
    try:
        manifest = json.loads(bounded_bytes(path, MAX_MANIFEST_BYTES), object_pairs_hook=strict_json_object)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise InputError('Invalid manifest JSON') from exc
    require_fields(manifest, {'schema_version', 'reference_kind', 'currency', 'labels', 'references'}, 'Manifest')
    if type(manifest['schema_version']) is not int or manifest['schema_version'] != 1:
        raise InputError('Unsupported schema')
    if manifest['reference_kind'] not in {'private_banknote_photos', 'synthetic_mechanics'} or manifest['currency'] != 'SAR':
        raise InputError('Unsupported reference kind or currency')
    if manifest['labels'] != LABELS or any(type(x) is not int for x in manifest['labels']):
        raise InputError('Exact eight-label vocabulary required')
    if type(manifest['references']) is not list or len(manifest['references']) > MAX_REFERENCES:
        raise InputError('Reference list exceeds bounds')
    root = path.resolve().parent
    ids, hashes, loaded = set(), set(), []
    fields = {'id', 'path', 'sha256', 'label', 'side', 'issue', 'material', 'physical_note_id',
              'capture_session_id', 'source', 'rights', 'verification'}
    for record in manifest['references']:
        require_fields(record, fields, 'Reference')
        for field in fields - {'label', 'verification'}:
            text_field(record[field], field)
        if type(record['label']) is not int or record['label'] not in LABELS:
            raise InputError('Unsupported denomination label')
        if record['side'] not in {'front', 'back'} or record['material'] not in {'paper', 'polymer'}:
            raise InputError('Unsupported side/material')
        if record['id'] in ids or record['sha256'] in hashes:
            raise InputError('Duplicate reference ID or image bytes')
        verification = record['verification']
        require_fields(verification, {'verified', 'verification_kind', 'verified_by', 'verified_on', 'method'}, 'Verification')
        if verification['verified'] is not True:
            raise InputError('Explicit recorded visual review required; not authentication')
        for field in {'verification_kind', 'verified_by', 'verified_on', 'method'}:
            text_field(verification[field], field)
        kind = verification['verification_kind']
        if kind not in {'human_review', 'assistant_visual_review', 'synthetic_fixture'}:
            raise InputError('Unknown review kind')
        if (kind == 'synthetic_fixture') != (manifest['reference_kind'] == 'synthetic_mechanics'):
            raise InputError('Synthetic/real review kind mismatch')
        data = bounded_bytes(local_path(root, record['path']), MAX_FILE_BYTES)
        checked_hash(data, record['sha256'])
        loaded.append((record, image_from_bytes(data, POLICY.max_reference_side)))
        ids.add(record['id']); hashes.add(record['sha256'])
    return manifest, loaded

def coverage_report(records):
    labels = sorted({r['label'] for r in records})
    return {'reference_count': len(records), 'supplied_labels': labels,
            'missing_labels': [n for n in LABELS if n not in labels],
            'sides': {str(n): sorted({r['side'] for r in records if r['label'] == n}) for n in labels},
            'review_kinds': sorted({r['verification']['verification_kind'] for r in records}),
            'complete_issue_inventory_verified': False}

def polygon_area(points):
    p = np.asarray(points, dtype=float)
    return abs(float(np.dot(p[:, 0], np.roll(p[:, 1], 1)) - np.dot(p[:, 1], np.roll(p[:, 0], 1)))) / 2

def geometry_evidence(h, source, target, reference_shape, query_shape):
    """Reconstructed geometric gate implementation, not byte-identical original."""
    need_cv2()
    rh, rw = reference_shape; qh, qw = query_shape
    corners = np.array([[0, 0], [rw - 1, 0], [rw - 1, rh - 1], [0, rh - 1]], dtype=float)
    base = {'geometry_pass': False, 'geometry_failures': ['nonfinite_or_pole']}
    if h.shape != (3, 3) or not np.isfinite(h).all():
        return base
    homogeneous = np.column_stack([corners, np.ones(4)]) @ h.T
    denom = homogeneous[:, 2]
    if not np.isfinite(homogeneous).all() or min(abs(denom)) < 1e-8 or min(denom) < 0 < max(denom):
        return base
    quad = homogeneous[:, :2] / denom[:, None]
    if not np.isfinite(quad).all():
        return base
    area = polygon_area(quad)
    if area < 1e-8:
        return base
    failures = []
    if not cv2.isContourConvex(np.float32(quad)):
        failures.append('quad_not_convex')
    if np.any(quad < 0) or np.any(quad[:, 0] > qw - 1) or np.any(quad[:, 1] > qh - 1):
        failures.append('quad_not_fully_in_frame')
    fraction = area / (qw * qh)
    if not POLICY.min_quad_area_fraction <= fraction <= POLICY.max_quad_area_fraction:
        failures.append('implausible_quad_area')
    edges = np.linalg.norm(np.roll(quad, -1, axis=0) - quad, axis=1)
    angles = []
    for i in range(4):
        a, b = quad[(i - 1) % 4] - quad[i], quad[(i + 1) % 4] - quad[i]
        angles.append(math.degrees(math.acos(float(np.clip(np.dot(a, b) / max(np.linalg.norm(a) * np.linalg.norm(b), 1e-12), -1, 1)))))
    if min(angles) < POLICY.min_quad_angle_deg or max(angles) > POLICY.max_quad_angle_deg:
        failures.append('implausible_quad_angles')
    if max(edges) / max(min(edges), 1e-8) > POLICY.max_edge_ratio:
        failures.append('implausible_edge_ratio')
    opposite = max(edges[0] / max(edges[2], 1e-8), edges[2] / max(edges[0], 1e-8),
                   edges[1] / max(edges[3], 1e-8), edges[3] / max(edges[1], 1e-8))
    if opposite > POLICY.max_opposite_edge_ratio:
        failures.append('implausible_opposite_edges')
    if max(abs(denom)) / min(abs(denom)) > POLICY.max_projective_denominator_ratio:
        failures.append('excessive_projective_distortion')
    ref_spread = polygon_area(cv2.convexHull(np.float32(source)).reshape(-1, 2)) / (rw * rh)
    query_spread = polygon_area(cv2.convexHull(np.float32(target)).reshape(-1, 2)) / area
    cells = {(min(2, max(0, int(x / rw * 3))), min(2, max(0, int(y / rh * 3)))) for x, y in source}
    if ref_spread < POLICY.min_reference_spread or query_spread < POLICY.min_query_spread or len(cells) < POLICY.min_grid_cells:
        failures.append('insufficient_spatial_support')
    prediction = cv2.perspectiveTransform(np.float32(source).reshape(-1, 1, 2), h).reshape(-1, 2)
    reprojection = float(np.median(np.linalg.norm(prediction - target, axis=1)))
    if not math.isfinite(reprojection) or reprojection > POLICY.max_reprojection_median_px:
        failures.append('excessive_reprojection_error')
    return {'geometry_pass': not failures, 'geometry_failures': failures, 'quad': quad.tolist(),
            'quad_area_fraction': fraction, 'reference_spread': ref_spread, 'query_spread': query_spread,
            'reference_grid_cells': len(cells), 'reprojection_median_px': reprojection}

def match_reference(record, reference, query, detector, query_keypoints, query_descriptors, algorithm='sift'):
    ref_keypoints, ref_descriptors = detector.detectAndCompute(reference, None)
    base = {key: record[key] for key in ['label', 'side', 'issue', 'material']}
    base.update(reference_id=record['id'], reference_keypoints=len(ref_keypoints))
    def empty(reason, matches=0, inliers=0):
        return {**base, 'score': 0., 'accepted': False, 'failures': [reason], 'ratio_matches': matches, 'inliers': inliers}
    if ref_descriptors is None or len(ref_descriptors) < 2 or query_descriptors is None:
        return [empty('insufficient_features')]
    matcher = cv2.BFMatcher(cv2.NORM_L2 if algorithm == 'sift' else cv2.NORM_HAMMING, crossCheck=False)
    pairs = matcher.knnMatch(query_descriptors, ref_descriptors, k=2)
    matches = [pair[0] for pair in pairs if len(pair) == 2 and pair[0].distance < POLICY.ratio_test * pair[1].distance]
    candidates = []
    for region in range(2):
        if len(matches) < 4:
            if not candidates:
                candidates.append(empty('insufficient_ratio_matches', len(matches)))
            break
        src = np.float32([ref_keypoints[m.trainIdx].pt for m in matches])
        dst = np.float32([query_keypoints[m.queryIdx].pt for m in matches])
        cv2.setRNGSeed(12345 + region)
        h, mask = cv2.findHomography(src, dst, cv2.RANSAC, POLICY.ransac_error_px,
                                   maxIters=POLICY.ransac_iterations, confidence=.995)
        if h is None or mask is None:
            candidates.append(empty('no_homography', len(matches))); break
        selected = {}
        for index in np.flatnonzero(mask.ravel()):
            match = matches[index]
            if match.trainIdx not in selected or match.distance < matches[selected[match.trainIdx]].distance:
                selected[match.trainIdx] = int(index)
        indices = sorted(selected.values())
        if len(indices) < 4:
            candidates.append(empty('insufficient_unique_inliers', len(matches), len(indices))); break
        geometry = geometry_evidence(h, src[indices], dst[indices], reference.shape, query.shape)
        ratio = len(indices) / len(matches)
        spread = min(geometry.get('reference_spread', 0), geometry.get('query_spread', 0), 1)
        score = float(len(indices) * ratio * math.sqrt(max(spread, 0)))
        failures = list(geometry['geometry_failures'])
        if len(indices) < POLICY.min_inliers: failures.append('insufficient_inliers')
        if ratio < POLICY.min_inlier_ratio: failures.append('insufficient_inlier_ratio')
        if score < POLICY.min_score: failures.append('insufficient_score')
        candidates.append({**base, 'region_index': region, 'ratio_matches': len(matches), 'inliers': len(indices),
                           'inlier_ratio': ratio, 'score': score, 'accepted': not failures, 'failures': failures, **geometry})
        if not geometry.get('geometry_pass'): break
        quad = np.float32(geometry['quad'])
        remaining = [m for m in matches if cv2.pointPolygonTest(quad, query_keypoints[m.queryIdx].pt, False) < 0]
        if len(remaining) == len(matches): break
        matches = remaining
    return candidates

def region_overlap(a, b):
    need_cv2()
    qa, qb = np.float32(a['quad']), np.float32(b['quad'])
    intersection, _ = cv2.intersectConvexConvex(qa, qb)
    return float(intersection) / max(min(polygon_area(qa), polygon_area(qb)), 1e-8)

def choose(candidates):
    accepted = [c for c in candidates if c['accepted']]
    for i, a in enumerate(accepted):
        for b in accepted[i + 1:]:
            if region_overlap(a, b) < POLICY.distinct_region_overlap:
                return {'decision': 'ambiguous', 'reason': 'multiple_disjoint_reference_regions', 'selected_reference_label': None}
    by_label = {}
    for c in candidates:
        if c['label'] not in by_label or c['score'] > by_label[c['label']]['score']:
            by_label[c['label']] = c
    ranked = sorted(by_label.values(), key=lambda x: (-x['score'], x['label']))
    if not ranked or not ranked[0]['accepted']:
        return {'decision': 'unknown', 'reason': 'insufficient_geometric_evidence', 'selected_reference_label': None}
    best = ranked[0]; second = ranked[1] if len(ranked) > 1 else None
    runner = second['score'] if second else 0.
    margin = best['score'] - runner; ratio = best['score'] / runner if runner > 0 else None
    details = {'best_reference_id': best['reference_id'], 'best_score': best['score'],
               'runner_up_different_label': second['label'] if second else None, 'runner_up_score': runner,
               'score_gap': margin, 'score_ratio': ratio}
    if runner > 0 and (margin < POLICY.min_different_label_score_gap or ratio < POLICY.min_different_label_score_ratio):
        return {'decision': 'ambiguous', 'reason': 'different_denomination_margin_too_small', 'selected_reference_label': None, **details}
    return {'decision': 'denomination_experiment', 'reason': 'experimental_geometric_gates_passed',
            'selected_reference_label': best['label'], **details}

def run(manifest_path, query_path, algorithm='sift'):
    if type(algorithm) is not str or algorithm not in ALGORITHMS: raise InputError('Unsupported algorithm')
    manifest, references = load_manifest(manifest_path)
    result = {'disclaimer': DISCLAIMER, 'monetary_answer': None, 'validated': False, 'source_status': 'reconstructed_not_original',
              'reference_kind': manifest['reference_kind'], 'opencv_version': getattr(cv2, '__version__', None),
              'algorithm': algorithm, 'algorithm_parameters': ALGORITHMS[algorithm],
              'descriptor_distance': 'L2' if algorithm == 'sift' else 'Hamming', 'thresholds': asdict(POLICY),
              'coverage': coverage_report([r for r, _ in references]), 'candidates': []}
    if not references:
        return {**result, 'decision': 'unknown', 'reason': 'no_verified_references', 'selected_reference_label': None}
    cv2.setNumThreads(1); cv2.ocl.setUseOpenCL(False)
    detector = create_detector(algorithm)
    query_bytes = bounded_bytes(query_path, MAX_FILE_BYTES)
    query = image_from_bytes(query_bytes, POLICY.max_query_side)
    result['query_matches_reference_bytes'] = any(hashlib.sha256(query_bytes).hexdigest() == r['sha256'] for r, _ in references)
    result['query_independence_verified'] = False
    keypoints, descriptors = detector.detectAndCompute(query, None)
    candidates = []
    for record, reference in references:
        candidates.extend(match_reference(record, reference, query, detector, keypoints, descriptors, algorithm))
    return {**result, 'query_resized_shape': list(query.shape), 'query_keypoints': len(keypoints), 'candidates': candidates, **choose(candidates)}

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', required=True, type=Path)
    parser.add_argument('--query', required=True, type=Path)
    parser.add_argument('--algorithm', choices=tuple(ALGORITHMS), default='sift')
    args = parser.parse_args(argv)
    try:
        output = run(args.manifest, args.query, args.algorithm)
    except (InputError, OSError) as exc:
        print(json.dumps({'decision': 'unknown', 'reason': 'invalid_or_unavailable_input', 'error': str(exc),
                          'validated': False, 'monetary_answer': None, 'selected_reference_label': None, 'disclaimer': DISCLAIMER}))
        return 2
    except Exception as exc:
        # Decoder/OpenCV errors fail closed; never fall back to an unreviewed label.
        print(json.dumps({'decision': 'unknown', 'reason': 'processing_error', 'error_type': type(exc).__name__,
                          'validated': False, 'monetary_answer': None, 'selected_reference_label': None, 'disclaimer': DISCLAIMER}))
        return 2
    print(json.dumps(output, indent=2, allow_nan=False))
    return 0

if __name__ == '__main__':
    sys.exit(main())
