#!/usr/bin/env python3
"""Reconstructed explicit source-pixel reference rectification, NOT original bytes.
No note detection, authenticity or recognition claim. Never modifies source.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
import reference_match as rm

def rectify(gray, corners, max_side=800):
    rm.need_cv2()
    quad = np.asarray(corners, dtype=np.float32)
    if quad.shape != (4, 2) or not np.isfinite(quad).all():
        raise rm.InputError('Four finite source-pixel corners required')
    h, w = gray.shape
    if np.any(quad < 0) or np.any(quad[:, 0] > w - 1) or np.any(quad[:, 1] > h - 1):
        raise rm.InputError('Corners must be inside source; do not invent clipped edges')
    if not rm.cv2.isContourConvex(quad) or rm.polygon_area(quad) < 256:
        raise rm.InputError('Ordered convex nondegenerate quadrilateral required')
    if type(max_side) is not int or not 32 <= max_side <= 1200:
        raise rm.InputError('Prepared maximum side must be 32 to 1200')
    width = max(np.linalg.norm(quad[1]-quad[0]), np.linalg.norm(quad[2]-quad[3]))
    height = max(np.linalg.norm(quad[3]-quad[0]), np.linalg.norm(quad[2]-quad[1]))
    scale = min(1., max_side / max(width, height))
    ow, oh = max(32, round(width * scale)), max(32, round(height * scale))
    target = np.float32([[0,0], [ow-1,0], [ow-1,oh-1], [0,oh-1]])
    transform = rm.cv2.getPerspectiveTransform(quad, target)
    return rm.cv2.warpPerspective(gray, transform, (ow,oh), flags=rm.cv2.INTER_LINEAR), transform

def prepare(source, output, corners, reviewer, review_kind, max_side=800):
    if review_kind not in {'assistant_visual_review', 'human_review'}:
        raise rm.InputError('Explicit assistant/human review kind required')
    rm.text_field(reviewer, 'reviewer')
    if output.suffix.lower() != '.png': raise rm.InputError('Output must be PNG')
    receipt_path = Path(str(output) + '.provenance.json')
    if output.exists() or receipt_path.exists() or source.resolve() == output.resolve():
        raise rm.InputError('Source or existing output must not be overwritten')
    data = rm.bounded_bytes(source, rm.MAX_FILE_BYTES)
    gray = rm.image_from_bytes(data, rm.MAX_IMAGE_SIDE)
    prepared, transform = rectify(gray, corners, max_side)
    ok, encoded = rm.cv2.imencode('.png', prepared)
    if not ok: raise rm.InputError('PNG encoding failed')
    pixels = encoded.tobytes()
    receipt = {'schema_version': 1, 'source_status': 'reconstructed_not_original',
               'purpose': 'Private experimental reference-boundary preparation only',
               'source_filename': source.name, 'source_sha256': hashlib.sha256(data).hexdigest(),
               'output_filename': output.name, 'output_sha256': hashlib.sha256(pixels).hexdigest(),
               'source_pixel_corners_tl_tr_br_bl': np.asarray(corners, dtype=float).tolist(),
               'output_size': [prepared.shape[1], prepared.shape[0]], 'source_to_output_homography': transform.tolist(),
               'operations': ['decode grayscale', 'explicit reference quadrilateral rectification with linear interpolation'],
               'reviewer': reviewer, 'review_kind': review_kind, 'opencv_version': rm.cv2.__version__,
               'preparation_source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               'recognition_or_authenticity_claim': False, 'independent_test_sample': False,
               'note': 'Derived reference, not independent query or currency accuracy; source rights apply.'}
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('xb') as stream: stream.write(pixels)
    with receipt_path.open('x') as stream: json.dump(receipt, stream, indent=2, allow_nan=False)
    return receipt

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--corners', required=True)
    parser.add_argument('--reviewer', required=True)
    parser.add_argument('--review-kind', choices=['assistant_visual_review','human_review'], required=True)
    parser.add_argument('--max-side', type=int, default=800)
    args=parser.parse_args()
    try:
        print(json.dumps(prepare(args.source,args.output,json.loads(args.corners),args.reviewer,args.review_kind,args.max_side),indent=2))
    except (rm.InputError, ValueError, OSError) as exc: parser.exit(2, f'Reference preparation rejected: {exc}\n')
if __name__ == '__main__': main()
