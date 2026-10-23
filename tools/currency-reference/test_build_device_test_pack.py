"""Reproducibility/security plumbing, NOT recognition or iPhone accuracy tests.

Set CURRENCY_DEVICE_TEST_DATASET to the local folder containing Saudi Currency/
to additionally rebuild the real sixteen-frame pack and verify every frozen hash.
No downloads or publication occur.
"""
import copy
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import cv2
import numpy as np
from PIL import Image
import build_device_test_pack as p

MANIFEST_SHA256 = '9325cd9d27cde2903a52743f71fcf700e430323a87b46ec2d95b32423c3468e2'


def jpeg(orientation=1, width=96, height=64, seed=1):
    pixels = np.random.default_rng(seed).integers(0,256,(height,width,3),dtype=np.uint8)
    image = Image.fromarray(pixels)
    exif = Image.Exif()
    exif[274] = orientation
    stream = io.BytesIO()
    image.save(stream,format='JPEG',exif=exif)
    return stream.getvalue()


def synthetic_reference(source,orientation=1,size=(96,64)):
    row = copy.deepcopy(p.load_selection()['references'][0])
    gray = cv2.imdecode(np.frombuffer(source,np.uint8),cv2.IMREAD_GRAYSCALE | cv2.IMREAD_IGNORE_ORIENTATION)
    if orientation in (3,6,8):
        gray = cv2.rotate(gray,{3:cv2.ROTATE_180,6:cv2.ROTATE_90_CLOCKWISE,8:cv2.ROTATE_90_COUNTERCLOCKWISE}[orientation])
    scale = min(1,1600/max(gray.shape))
    if scale < 1:
        gray = cv2.resize(gray,(round(gray.shape[1]*scale),round(gray.shape[0]*scale)),interpolation=cv2.INTER_AREA)
    encoded = cv2.imencode('.png',gray,[cv2.IMWRITE_PNG_COMPRESSION,3])[1].tobytes()
    row.update(raw_sha256=p.sha256(source),raw_size=list(size),exif_orientation=orientation,
               normalized_size=list(gray.shape[::-1]),normalized_sha256=p.sha256(encoded))
    return row,encoded


def synthetic_dataset(root):
    dataset = root/'dataset'
    (dataset/'Saudi Currency'/'train').mkdir(parents=True)
    selection = copy.deepcopy(p.load_selection())
    for i,row in enumerate(selection['references']):
        source = jpeg(seed=i)
        r,_ = synthetic_reference(source)
        for key in ('raw_sha256','raw_size','exif_orientation','normalized_size','normalized_sha256'):
            row[key] = r[key]
        row['raw_relative_path'] = f'Saudi Currency/train/synthetic-{i}.jpg'
        row['corners_tl_tr_br_bl'] = [[5,5],[90,5],[90,58],[5,58]]
        (dataset/row['raw_relative_path']).write_bytes(source)
    return dataset,selection


class SelectionTests(unittest.TestCase):
    def test_actual_selection_has_exact_inventory_and_honest_review(self):
        selection = p.load_selection()
        self.assertEqual(len(selection['references']),16)
        self.assertEqual({(r['label'],r['side']) for r in selection['references']},
                         {(label,side) for label in p.LABELS for side in ('front','back')})
        self.assertEqual(selection['review']['verification_kind'],'assistant_visual_review')
        self.assertTrue(all(r['physical_note_id'] is None and r['capture_session_id'] is None for r in selection['references']))

    def test_frozen_native_manifest_hash_and_schema(self):
        data = p.make_manifest(p.load_selection())
        self.assertEqual(p.sha256(data),MANIFEST_SHA256)
        manifest = json.loads(data)
        self.assertEqual(set(manifest),{'schema_version','reference_kind','currency','labels','references'})
        self.assertEqual(manifest['schema_version'],2)
        for row in manifest['references']:
            self.assertEqual(set(row),{'id','path','sha256','label','side','issue','material','physical_note_id',
                             'capture_session_id','source','rights','verification','boundary'})
            self.assertEqual(row['physical_note_id'],'unknown_not_verified')
            self.assertEqual(row['verification']['verification_kind'],'assistant_visual_review')
            self.assertLessEqual(max(row['boundary']['source_size']),1600)
            self.assertIn('10.17632/7sys44td9c.1',row['source'])
            self.assertIn('CC BY 4.0',row['rights'])
            self.assertIn('do not publish images',row['rights'])

    def test_human_review_cannot_be_silently_promoted(self):
        value = p.load_selection()
        value['review']['verification_kind'] = 'human_review'
        with self.assertRaises(p.PackError): p.validate_selection(value)

    def test_normalization_change_is_rejected(self):
        value = p.load_selection()
        value['normalization']['png_compression'] = 0
        with self.assertRaises(p.PackError): p.validate_selection(value)

    def test_duplicate_side_and_missing_coverage_rejected(self):
        value = p.load_selection()
        value['references'][-1] = copy.deepcopy(value['references'][0])
        with self.assertRaises(p.PackError): p.validate_selection(value)

    def test_invented_physical_identity_rejected(self):
        for key in ('physical_note_id','capture_session_id'):
            value = p.load_selection()
            value['references'][0][key] = 'asserted-independent'
            with self.subTest(key=key), self.assertRaises(p.PackError): p.validate_selection(value)

    def test_duplicate_json_keys_and_nonfinite_rejected(self):
        for value in (b'{"a":1,"a":2}',b'{"a":NaN}',b'{"a":Infinity}'):
            with self.subTest(value=value), self.assertRaises(p.PackError): p.strict_json(value)

    def test_unsafe_relative_paths(self):
        for value in ('../x','/x','a/../x','a//x','a/./x','a\\x','a%2fx','a:x','a\x00x'):
            with self.subTest(value=value), self.assertRaises(p.PackError): p.relative_parts(value)

    def test_invalid_boundaries(self):
        invalid = [ [[0,0],[95,63],[95,0],[0,63]], [[0,0],[0,63],[95,63],[95,0]],
                    [[-1,0],[95,0],[95,63],[0,63]], [[0,0],[96,0],[95,63],[0,63]],
                    [[0,0],[20,0],[20,20],[0,20]], [[float('nan'),0],[95,0],[95,63],[0,63]] ]
        for corners in invalid:
            with self.subTest(corners=corners), self.assertRaises(p.PackError): p.check_boundary(corners,[96,64])


class NormalizeTests(unittest.TestCase):
    def test_all_supported_orientations_are_explicit_once(self):
        for orientation in (0,1,3,6,8):
            with self.subTest(orientation=orientation):
                source = jpeg(orientation=orientation)
                row,expected = synthetic_reference(source,orientation)
                self.assertEqual(p.normalize(source,row),expected)

    def test_full_frame_downsample_not_boundary_warp(self):
        source = jpeg(width=1920,height=1080)
        row,expected = synthetic_reference(source,size=(1920,1080))
        row['corners_tl_tr_br_bl'] = [[500,500],[800,500],[800,800],[500,800]]
        with mock.patch.object(cv2,'warpPerspective',side_effect=AssertionError('No double-warp')):
            result = p.normalize(source,row)
        self.assertEqual(result,expected)
        self.assertEqual(cv2.imdecode(np.frombuffer(result,np.uint8),cv2.IMREAD_GRAYSCALE).shape,(900,1600))

    def test_raw_hash_mismatch_rejected_before_decode(self):
        source = jpeg()
        row,_ = synthetic_reference(source)
        row['raw_sha256'] = '0'*64
        with mock.patch.object(cv2,'imdecode') as decode:
            with self.assertRaises(p.PackError): p.normalize(source,row)
            decode.assert_not_called()

    def test_normalized_hash_mismatch_rejected(self):
        source = jpeg()
        row,_ = synthetic_reference(source)
        row['normalized_sha256'] = '0'*64
        with self.assertRaises(p.PackError): p.normalize(source,row)

    def test_header_size_and_orientation_mismatch_rejected_before_decode(self):
        source = jpeg()
        for key,value in [('raw_size',[6000,6000]),('exif_orientation',6)]:
            row,_ = synthetic_reference(source)
            row[key] = value
            with self.subTest(key=key), mock.patch.object(cv2,'imdecode') as decode:
                with self.assertRaises(p.PackError): p.normalize(source,row)
                decode.assert_not_called()

    def test_declared_huge_header_rejected_before_decode(self):
        source = jpeg()
        row,_ = synthetic_reference(source)
        header = mock.MagicMock()
        header.__enter__.return_value = header
        header.format,header.n_frames,header.size = 'JPEG',1,(6000,6000)
        with mock.patch.object(Image,'open',return_value=header), mock.patch.object(cv2,'imdecode') as decode:
            with self.assertRaises(p.PackError): p.normalize(source,row)
            decode.assert_not_called()

    def test_non_jpeg_rejected_before_decode(self):
        source = cv2.imencode('.png',np.zeros((64,96),np.uint8))[1].tobytes()
        row = p.load_selection()['references'][0]
        row['raw_sha256'] = p.sha256(source)
        with mock.patch.object(cv2,'imdecode') as decode:
            with self.assertRaises(p.PackError): p.normalize(source,row)
            decode.assert_not_called()

    def test_opencv_version_is_pinned(self):
        with mock.patch.object(cv2,'__version__','4.13.0'):
            with self.assertRaisesRegex(p.PackError,'Pinned'): p.normalize(b'x',{})

    def test_source_byte_limit(self):
        source = jpeg()
        row,_ = synthetic_reference(source)
        with mock.patch.object(p,'MAX_SOURCE_BYTES',10), mock.patch.object(cv2,'imdecode') as decode:
            with self.assertRaises(p.PackError): p.normalize(source,row)
            decode.assert_not_called()


class FilesystemTests(unittest.TestCase):
    def test_complete_synthetic_build_strict_inventory_and_nooverwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dataset,selection = synthetic_dataset(root)
            output = root/'SaudiBanknoteReferences'
            report = p.build_pack(dataset,output,selection)
            self.assertEqual(report['image_count'],16)
            self.assertEqual(set(x.name for x in output.iterdir()),{'manifest.json','images'})
            self.assertEqual(len(list((output/'images').iterdir())),16)
            manifest = json.loads((output/'manifest.json').read_bytes())
            for row in manifest['references']:
                self.assertEqual(p.sha256((output/row['path']).read_bytes()),row['sha256'])
            before = (output/'manifest.json').read_bytes()
            with self.assertRaisesRegex(p.PackError,'overwrite'): p.build_pack(dataset,output,selection)
            self.assertEqual((output/'manifest.json').read_bytes(),before)

    def test_corrupt_source_leaves_no_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dataset,selection = synthetic_dataset(root)
            (dataset/selection['references'][0]['raw_relative_path']).write_bytes(b'corrupt')
            with self.assertRaises(p.PackError): p.build_pack(dataset,root/'SaudiBanknoteReferences',selection)
            self.assertFalse((root/'SaudiBanknoteReferences').exists())

    def test_symlink_source_file_and_directory_rejected(self):
        for component in ('file','directory','root'):
            with self.subTest(component=component), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                dataset,selection = synthetic_dataset(root)
                if component == 'file':
                    target = dataset/selection['references'][0]['raw_relative_path']
                    saved = root/'source.jpg'
                    target.rename(saved)
                    target.symlink_to(saved)
                elif component == 'directory':
                    target = dataset/'Saudi Currency'
                    saved = root/'original-data'
                    target.rename(saved)
                    target.symlink_to(saved,target_is_directory=True)
                else:
                    saved = root/'linked-dataset'
                    saved.symlink_to(dataset,target_is_directory=True)
                    dataset = saved
                with self.assertRaises(OSError): p.build_pack(dataset,root/'SaudiBanknoteReferences',selection)
                self.assertFalse((root/'SaudiBanknoteReferences').exists())

    def test_symlink_output_and_parent_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dataset,selection = synthetic_dataset(root)
            output = root/'SaudiBanknoteReferences'
            output.symlink_to(root/'nonexistent')
            with self.assertRaises(p.PackError): p.build_pack(dataset,output,selection)
            parent = root/'parent'
            parent.symlink_to(dataset,target_is_directory=True)
            with self.assertRaises(OSError): p.build_pack(dataset,parent/'SaudiBanknoteReferences',selection)

    def test_wrong_name_and_nested_output_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dataset,selection = synthetic_dataset(root)
            for output in (root/'wrong',dataset/'SaudiBanknoteReferences'):
                with self.subTest(output=output), self.assertRaises(p.PackError): p.build_pack(dataset,output,selection)

    def test_bounded_read_rejects_oversize_and_fifo(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'large').write_bytes(b'abc')
            os.mkfifo(root/'pipe')
            fd = p.open_directory(root)
            try:
                for name,limit in [('large',2),('pipe',2)]:
                    with self.subTest(name=name), self.assertRaises(p.PackError): p.bounded_read(fd,name,limit)
            finally:
                os.close(fd)

    def test_total_pack_limit_before_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dataset,selection = synthetic_dataset(root)
            with mock.patch.object(p,'MAX_PACK_BYTES',1):
                with self.assertRaises(p.PackError): p.build_pack(dataset,root/'SaudiBanknoteReferences',selection)
            self.assertFalse((root/'SaudiBanknoteReferences').exists())

    def test_no_follow_at_write_and_exclusive_creation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            saved = root/'saved'
            saved.write_bytes(b'unchanged')
            (root/'target').symlink_to(saved)
            fd = p.open_directory(root)
            try:
                with self.assertRaises(OSError): p.write_new(fd,'target',b'changed')
                with self.assertRaises(OSError): p.write_new(fd,'saved',b'changed')
            finally:
                os.close(fd)
            self.assertEqual(saved.read_bytes(),b'unchanged')


@unittest.skipUnless(os.environ.get('CURRENCY_DEVICE_TEST_DATASET'),'Local real dataset not requested; no image download')
class ActualPrivateDatasetTests(unittest.TestCase):
    def test_actual_selected_sources_reproduce_all_hashes(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)/'SaudiBanknoteReferences'
            result = p.build_pack(Path(os.environ['CURRENCY_DEVICE_TEST_DATASET']),output)
            self.assertEqual(result['manifest_sha256'],MANIFEST_SHA256)
            self.assertEqual(result['total_bytes'],15299295)
            manifest = json.loads((output/'manifest.json').read_bytes())
            selection = {r['id']:r for r in p.load_selection()['references']}
            for row in manifest['references']:
                source = selection[row['id']]
                self.assertEqual(p.sha256((output/row['path']).read_bytes()),source['normalized_sha256'])
                self.assertEqual(row['boundary']['source_size'],source['normalized_size'])
                self.assertEqual(row['boundary']['corners_tl_tr_br_bl'],source['corners_tl_tr_br_bl'])
            self.assertEqual(set(x.relative_to(output).as_posix() for x in output.rglob('*') if x.is_file()),
                             {'manifest.json'} | {r['path'] for r in manifest['references']})

if __name__ == '__main__':
    unittest.main()
