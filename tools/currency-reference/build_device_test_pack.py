#!/usr/bin/env python3
"""Reproduce the private, assistant-reviewed Saudi iPhone developer-test pack.

No network, training, reference rectification, human-review assertion, publication,
or accuracy claim. The native engine alone rectifies the reviewed full frames.
"""
from __future__ import annotations
import argparse
import hashlib
import io
import json
import math
import os
from pathlib import Path
import stat
import warnings

import cv2
import numpy as np
from PIL import Image

LABELS = [1, 5, 10, 20, 50, 100, 200, 500]
SELECTION = Path(__file__).with_name('device_test_reference_selection.json')
MAX_SOURCE_BYTES = 16 * 1024 * 1024
MAX_SOURCE_SIDE = 6000
MAX_SOURCE_PIXELS = 16_000_000
MAX_IMAGE_BYTES = 8 * 1024 * 1024
MAX_MANIFEST_BYTES = 256 * 1024
MAX_PACK_BYTES = 32 * 1024 * 1024
NORMALIZATION = {
    'opencv_version': '4.14.0',
    'decode': 'IMREAD_GRAYSCALE | IMREAD_IGNORE_ORIENTATION',
    'orientation': '0/1 stored pixels; 3 rotate180; 6 rotate90clockwise; 8 rotate90counterclockwise',
    'max_side': 1600,
    'resize': 'INTER_AREA; min(1,1600/max(width,height)); Python round dimensions',
    'png_compression': 3,
    'crop_or_rectify': False,
}

class PackError(ValueError):
    pass


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def valid_hash(value):
    return isinstance(value, str) and len(value) == 64 and all(c in '0123456789abcdef' for c in value)


def valid_text(value):
    return isinstance(value, str) and 0 < len(value.strip()) <= 256 and all(ord(c) >= 32 for c in value)


def relative_parts(value):
    if (not isinstance(value, str) or not value or value.startswith('/')
            or any(c in value for c in '\\:%\x00') or any(ord(c) < 32 for c in value)):
        raise PackError('Unsafe relative path')
    parts = value.split('/')
    if any(p in ('', '.', '..') for p in parts):
        raise PackError('Unsafe relative path')
    return parts


def absolute_path(value):
    value = os.fspath(value)
    if '\x00' in value or '..' in value.split('/'):
        raise PackError('Unsafe filesystem path')
    path = Path(os.path.abspath(value))
    if path == Path('/'):
        raise PackError('Root is not an allowed target')
    return path


def open_directory(path):
    """Walk from / using directory descriptors; never follow a symlink."""
    path = absolute_path(path)
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parts[1:]:
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        return fd
    except BaseException:
        os.close(fd)
        raise


def bounded_read(root_fd, relative, limit):
    parts = relative_parts(relative)
    directory = os.dup(root_fd)
    fd = None
    try:
        for part in parts[:-1]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory)
            os.close(directory)
            directory = child
        fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or not 0 < info.st_size <= limit:
            raise PackError('Input must be a bounded, nonempty regular file')
        with os.fdopen(fd, 'rb') as stream:
            fd = None
            data = stream.read(limit + 1)
        if len(data) != info.st_size or len(data) > limit:
            raise PackError('Input changed during bounded read')
        return data
    finally:
        if fd is not None:
            os.close(fd)
        os.close(directory)


def strict_json(data):
    def object_pairs(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise PackError('Duplicate selection key')
            result[key] = value
        return result
    return json.loads(data, object_pairs_hook=object_pairs,
                      parse_constant=lambda _: (_ for _ in ()).throw(PackError('Nonfinite JSON')))


def check_size(value, max_side, max_pixels):
    if (not isinstance(value, list) or len(value) != 2
            or any(type(x) is not int or not 32 <= x <= max_side for x in value)
            or value[0] * value[1] > max_pixels):
        raise PackError('Invalid bounded image dimensions')


def check_boundary(corners, size):
    if (not isinstance(corners, list) or len(corners) != 4
            or any(not isinstance(p, list) or len(p) != 2 for p in corners)):
        raise PackError('Four reviewed source-pixel corners required')
    for x, y in corners:
        if (type(x) not in (int, float) or type(y) not in (int, float)
                or not math.isfinite(x) or not math.isfinite(y)
                or not 0 <= x <= size[0] - 1 or not 0 <= y <= size[1] - 1):
            raise PackError('Boundary outside normalized full frame')
    edges = [(corners[(i+1)%4][0]-p[0], corners[(i+1)%4][1]-p[1]) for i, p in enumerate(corners)]
    if any(a[0]*b[1]-a[1]*b[0] <= 0 for a,b in zip(edges,edges[1:]+edges[:1])):
        raise PackError('Boundary must be convex, positive-winding, and ordered')
    lengths = [math.hypot(*edge) for edge in edges]
    area = abs(sum(p[0]*corners[(i+1)%4][1]-p[1]*corners[(i+1)%4][0] for i,p in enumerate(corners))) / 2
    if (min(lengths) < 32 or area < .10 * size[0] * size[1]
            or max(lengths[0],lengths[2])/min(lengths[0],lengths[2]) > 3
            or max(lengths[1],lengths[3])/min(lengths[1],lengths[3]) > 3):
        raise PackError('Boundary lacks native minimum edge/area support')


def validate_selection(selection):
    keys = {'schema_version','purpose','normalization','review','attribution','limitations','references'}
    if not isinstance(selection,dict) or set(selection) != keys or type(selection['schema_version']) is not int or selection['schema_version'] != 1:
        raise PackError('Unsupported selection schema')
    if selection['normalization'] != NORMALIZATION:
        raise PackError('Normalization must match the frozen procedure')
    review = selection['review']
    if (not isinstance(review,dict) or set(review) != {'verified','verification_kind','verified_by','verified_on','method'}
            or review['verified'] is not True or review['verification_kind'] != 'assistant_visual_review'
            or review['verified_on'] != '2026-10-23'
            or any(not valid_text(review[k]) for k in ('verification_kind','verified_by','verified_on','method'))):
        raise PackError('Assistant review provenance required; never human review')
    rows = selection['references']
    if not isinstance(rows,list) or len(rows) != 16:
        raise PackError('Exactly sixteen selected references required')
    seen, hashes = set(), set()
    row_keys = {'id','label','side','material','issue','raw_relative_path','raw_sha256','raw_size',
                'exif_orientation','normalized_sha256','normalized_size','corners_tl_tr_br_bl',
                'corner_uncertainty_pixels','material_assessment','reviewed_corner_order',
                'physical_note_id','capture_session_id'}
    for r in rows:
        if not isinstance(r,dict) or set(r) != row_keys:
            raise PackError('Unexpected reference fields')
        label,side = r['label'],r['side']
        if type(label) is not int or label not in LABELS or side not in ('front','back') or (label,side) in seen:
            raise PackError('Duplicate or unsupported label/side')
        seen.add((label,side))
        if r['id'] != f'sar-{label}-{side}-device-test' or r['material'] != 'paper':
            raise PackError('Unexpected device-test reference identity')
        if r['physical_note_id'] is not None or r['capture_session_id'] is not None:
            raise PackError('Physical identity/session are unknown, not invented')
        if not valid_text(r['issue']) or not valid_text(r['material_assessment']):
            raise PackError('Missing bounded descriptive provenance')
        path_parts = relative_parts(r['raw_relative_path'])
        if path_parts[0] != 'Saudi Currency' or not r['raw_relative_path'].lower().endswith('.jpg'):
            raise PackError('Expected selected Saudi Currency JPEG path')
        if not valid_hash(r['raw_sha256']) or not valid_hash(r['normalized_sha256']) or r['normalized_sha256'] in hashes:
            raise PackError('Invalid or repeated image hashes')
        hashes.add(r['normalized_sha256'])
        check_size(r['raw_size'],MAX_SOURCE_SIDE,MAX_SOURCE_PIXELS)
        check_size(r['normalized_size'],1600,1600*1600)
        if type(r['exif_orientation']) is not int or r['exif_orientation'] not in (0,1,3,6,8):
            raise PackError('Unsupported source orientation')
        check_boundary(r['corners_tl_tr_br_bl'],r['normalized_size'])
    return selection


def load_selection(path=SELECTION):
    path = absolute_path(path)
    fd = open_directory(path.parent)
    try:
        return validate_selection(strict_json(bounded_read(fd,path.name,MAX_MANIFEST_BYTES)))
    finally:
        os.close(fd)


def normalize(source, reference):
    if cv2.__version__ != NORMALIZATION['opencv_version']:
        raise PackError('Pinned official OpenCV 4.14.0 is required')
    if not 0 < len(source) <= MAX_SOURCE_BYTES or sha256(source) != reference['raw_sha256']:
        raise PackError('Original source hash/byte limit mismatch')
    # Read only the bounded header before OpenCV allocation; never Image.load().
    with warnings.catch_warnings():
        warnings.simplefilter('error', Image.DecompressionBombWarning)
        with Image.open(io.BytesIO(source)) as header:
            if header.format != 'JPEG' or getattr(header,'n_frames',1) != 1:
                raise PackError('Source must be single-frame JPEG')
            size = list(header.size)
            check_size(size,MAX_SOURCE_SIDE,MAX_SOURCE_PIXELS)
            if size != reference['raw_size'] or header.getexif().get(274,1) != reference['exif_orientation']:
                raise PackError('Source dimensions/orientation differ from review')
    cv2.setNumThreads(1)
    cv2.ocl.setUseOpenCL(False)
    gray = cv2.imdecode(np.frombuffer(source,np.uint8),cv2.IMREAD_GRAYSCALE | cv2.IMREAD_IGNORE_ORIENTATION)
    if gray is None or gray.dtype != np.uint8 or gray.ndim != 2 or list(gray.shape[::-1]) != size:
        raise PackError('JPEG decode differs from bounded header')
    rotation = {3:cv2.ROTATE_180,6:cv2.ROTATE_90_CLOCKWISE,8:cv2.ROTATE_90_COUNTERCLOCKWISE}
    if reference['exif_orientation'] in rotation:
        gray = cv2.rotate(gray,rotation[reference['exif_orientation']])
    scale = min(1.,1600/max(gray.shape))
    if scale < 1:
        gray = cv2.resize(gray,(round(gray.shape[1]*scale),round(gray.shape[0]*scale)),interpolation=cv2.INTER_AREA)
    if list(gray.shape[::-1]) != reference['normalized_size']:
        raise PackError('Normalized dimensions differ from reviewed coordinates')
    ok, encoded = cv2.imencode('.png',gray,[cv2.IMWRITE_PNG_COMPRESSION,3])
    if not ok:
        raise PackError('PNG encoding failed')
    result = encoded.tobytes()
    if len(result) > MAX_IMAGE_BYTES or sha256(result) != reference['normalized_sha256']:
        raise PackError('Normalized hash mismatch; no substitute/rewarp accepted')
    return result


def make_manifest(selection):
    rows = []
    for r in sorted(selection['references'],key=lambda r:(r['label'],r['side'] != 'front')):
        source = ('DOI:10.17632/7sys44td9c.1; Nazmul Ahasan Maruf, Abdullah Basuhail, AHM Adil; '
                  + r['raw_relative_path'])
        rights = ('Dataset CC BY 4.0. Private authorized developer-device evaluation only. '
                  'Banknote reproduction/redistribution permission unresolved; do not publish images. '
                  'Assistant visual review, not human review; unknown physical-note independence.')
        if not valid_text(source) or not valid_text(rights):
            raise PackError('Provenance exceeds native text bounds')
        rows.append({'id':r['id'],'path':f"images/{r['id']}.png",'sha256':r['normalized_sha256'],
            'label':r['label'],'side':r['side'],'issue':r['issue'],'material':r['material'],
            'physical_note_id':'unknown_not_verified','capture_session_id':'unknown_not_verified',
            'source':source,'rights':rights,'verification':dict(selection['review']),
            'boundary':{'source_size':r['normalized_size'],'corners_tl_tr_br_bl':r['corners_tl_tr_br_bl']}})
    manifest = {'schema_version':2,'reference_kind':'private_banknote_photos','currency':'SAR',
                'labels':LABELS,'references':rows}
    data = (json.dumps(manifest,ensure_ascii=False,indent=2,allow_nan=False)+'\n').encode('utf-8')
    if len(data) > MAX_MANIFEST_BYTES:
        raise PackError('Manifest byte limit')
    return data


def write_new(directory,name,data):
    fd = os.open(name,os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,0o600,dir_fd=directory)
    with os.fdopen(fd,'wb') as stream:
        stream.write(data)


def build_pack(dataset,output,selection=None):
    selection = validate_selection(selection) if selection is not None else load_selection()
    dataset,output = absolute_path(dataset),absolute_path(output)
    if output.name != 'SaudiBanknoteReferences' or output == dataset or dataset in output.parents or output in dataset.parents:
        raise PackError('Output must be a separate, new SaudiBanknoteReferences folder')
    parent_fd = open_directory(output.parent)
    source_fd = None
    try:
        # lexists behavior, including broken links, with an anchored directory fd.
        try:
            os.stat(output.name,dir_fd=parent_fd,follow_symlinks=False)
        except FileNotFoundError:
            pass
        else:
            raise PackError('Output already exists; overwrite is forbidden')
        source_fd = open_directory(dataset)
        manifest = make_manifest(selection)
        images = []
        total = len(manifest)
        for r in sorted(selection['references'],key=lambda r:(r['label'],r['side'] != 'front')):
            data = normalize(bounded_read(source_fd,r['raw_relative_path'],MAX_SOURCE_BYTES),r)
            total += len(data)
            if total > MAX_PACK_BYTES:
                raise PackError('Pack exceeds bounded total size')
            images.append((f"{r['id']}.png",data))
        # All source bytes and derived hashes verified before output is created.
        os.mkdir(output.name,mode=0o700,dir_fd=parent_fd)
        pack_fd = os.open(output.name,os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,dir_fd=parent_fd)
        image_fd = None
        written = []
        try:
            os.mkdir('images',mode=0o700,dir_fd=pack_fd)
            image_fd = os.open('images',os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,dir_fd=pack_fd)
            for name,data in images:
                write_new(image_fd,name,data)
                written.append(name)
            write_new(pack_fd,'manifest.json',manifest)  # Commit marker comes last.
        except BaseException:
            # Never remove preexisting paths; only our newly created inventory.
            if image_fd is not None:
                for name in written:
                    os.unlink(name,dir_fd=image_fd)
            raise
        finally:
            if image_fd is not None:
                os.close(image_fd)
            os.close(pack_fd)
        return {'output':str(output),'manifest_sha256':sha256(manifest),'image_count':len(images),
                'total_bytes':total,'verification_kind':'assistant_visual_review',
                'accuracy_claim':False,'production_approved':False}
    finally:
        if source_fd is not None:
            os.close(source_fd)
        os.close(parent_fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dataset',type=Path,required=True,help='Existing folder containing Saudi Currency/')
    parser.add_argument('--output',type=Path,required=True,help='New SaudiBanknoteReferences folder; parent must exist')
    args = parser.parse_args()
    try:
        print(json.dumps(build_pack(args.dataset,args.output),indent=2))
    except (PackError,OSError,ValueError,Image.DecompressionBombWarning,Image.DecompressionBombError) as error:
        parser.exit(2,f'Device-test pack rejected: {error}\n')

if __name__ == '__main__':
    main()
