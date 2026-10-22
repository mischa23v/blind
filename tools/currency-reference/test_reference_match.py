"""Fresh reconstruction tests. Abstract circles/lines, never banknote accuracy."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import numpy as np
from PIL import Image
import reference_match as rm

def abstract(seed=37):
    rng=np.random.default_rng(seed)
    canvas=np.full((240,360),220,np.uint8)
    for _ in range(150):
        p=tuple(int(x) for x in rng.integers([8,8],[352,232]));color=int(rng.integers(10,190))
        rm.cv2.circle(canvas,p,int(rng.integers(2,9)),color,-1)
    for _ in range(45):
        a=tuple(int(x) for x in rng.integers([0,0],[360,240]));b=tuple(int(x) for x in rng.integers([0,0],[360,240]))
        rm.cv2.line(canvas,a,b,int(rng.integers(10,180)),1)
    return canvas

def manifest(root, image=None):
    m={'schema_version':1,'reference_kind':'synthetic_mechanics','currency':'SAR','labels':rm.LABELS[:],'references':[]}
    if image is not None:
        rm.cv2.imwrite(str(root/'ref.png'),image)
        m['references']=[{'id':'abstract-reference','path':'ref.png','sha256':hashlib.sha256((root/'ref.png').read_bytes()).hexdigest(),
                         'label':10,'side':'front','issue':'abstract fixture, not money','material':'paper','physical_note_id':'synthetic',
                         'capture_session_id':'synthetic','source':'generated abstract lines and circles','rights':'generated for tests',
                         'verification':{'verified':True,'verification_kind':'synthetic_fixture','verified_by':'test generator',
                                         'verified_on':'2026-10-22','method':'Not banknote data'}}]
    p=root/'manifest.json';p.write_text(json.dumps(m));return p,m

def write_manifest(path,m): path.write_text(json.dumps(m))

class PurePolicyTests(unittest.TestCase):
    def test_empty_without_query(self):
        with tempfile.TemporaryDirectory() as d:
            p,_=manifest(Path(d));r=rm.run(p,Path(d)/'missing.jpg')
            self.assertEqual(r['decision'],'unknown');self.assertIsNone(r['monetary_answer'])
    def test_duplicate_keys(self):
        with self.assertRaises(rm.InputError):json.loads('{"x":1,"x":2}',object_pairs_hook=rm.strict_json_object)
    def test_frozen_thresholds(self):
        self.assertEqual(rm.POLICY.min_inliers,14);self.assertEqual(rm.POLICY.ratio_test,.72);self.assertEqual(rm.POLICY.min_inlier_ratio,.42)
    def test_label_vocabulary(self):
        with tempfile.TemporaryDirectory() as d:
            p,m=manifest(Path(d));m['labels']=[1,5,10];write_manifest(p,m)
            with self.assertRaises(rm.InputError):rm.load_manifest(p)
    def test_bool_schema_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p,m=manifest(Path(d));m['schema_version']=True;write_manifest(p,m)
            with self.assertRaises(rm.InputError):rm.load_manifest(p)
    def test_path_escape(self):
        with tempfile.TemporaryDirectory() as d:
            for bad in ['../outside','/tmp/outside','https://remote/image']:
                with self.assertRaises(rm.InputError):rm.local_path(Path(d).resolve(),bad)
    def test_hash_mismatch(self):
        with self.assertRaises(rm.InputError):rm.checked_hash(b'abc','0'*64)
    def test_size_limit(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'bytes';p.write_bytes(b'12345')
            with self.assertRaises(rm.InputError):rm.bounded_bytes(p,4)
    def test_rejected_closest_is_unknown(self):
        r=rm.choose([{'label':100,'score':50,'accepted':False,'reference_id':'bad'}]);self.assertEqual(r['decision'],'unknown')
    def test_different_label_margin(self):
        c=[{'label':10,'score':10,'accepted':True,'reference_id':'a'},{'label':100,'score':9,'accepted':False,'reference_id':'b'}]
        self.assertEqual(rm.choose(c)['decision'],'ambiguous')
    def test_same_label_not_runner_up(self):
        c=[{'label':10,'score':10,'accepted':True,'reference_id':'a'},{'label':10,'score':9,'accepted':False,'reference_id':'b'}]
        r=rm.choose(c);self.assertEqual(r['decision'],'denomination_experiment');self.assertIsNone(r['runner_up_different_label'])
    def test_invalid_algorithm(self):
        with self.assertRaises(rm.InputError):rm.create_detector('custom')

@unittest.skipIf(rm.cv2 is None,'OpenCV unavailable; no feature-test claim')
class ManifestImageTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name);self.path,self.m=manifest(self.root,abstract())
    def tearDown(self):self.tmp.cleanup()
    def test_assistant_not_human(self):
        self.m['reference_kind']='private_banknote_photos';self.m['references'][0]['verification']['verification_kind']='assistant_visual_review';write_manifest(self.path,self.m)
        _,r=rm.load_manifest(self.path);self.assertEqual(r[0][0]['verification']['verification_kind'],'assistant_visual_review')
    def test_synthetic_kind_rejected_for_real(self):
        self.m['reference_kind']='private_banknote_photos';write_manifest(self.path,self.m)
        with self.assertRaises(rm.InputError):rm.load_manifest(self.path)
    def test_false_review(self):
        self.m['references'][0]['verification']['verified']=False;write_manifest(self.path,self.m)
        with self.assertRaises(rm.InputError):rm.load_manifest(self.path)
    def test_duplicate_bytes(self):
        self.m['references'].append(copy.deepcopy(self.m['references'][0]));self.m['references'][1]['id']='different';write_manifest(self.path,self.m)
        with self.assertRaises(rm.InputError):rm.load_manifest(self.path)
    def test_wrong_label(self):
        self.m['references'][0]['label']=True;write_manifest(self.path,self.m)
        with self.assertRaises(rm.InputError):rm.load_manifest(self.path)
    def test_tiny_image(self):
        p=self.root/'tiny.png';Image.new('L',(10,10)).save(p)
        with self.assertRaises(rm.InputError):rm.image_from_bytes(p.read_bytes(),800)
    def test_exif_rotation(self):
        p=self.root/'rotated.jpg';exif=Image.Exif();exif[274]=6;Image.new('L',(64,64)).save(p,exif=exif)
        with self.assertRaises(rm.InputError):rm.image_from_bytes(p.read_bytes(),800)
    def test_disjoint_regions(self):
        a={'label':10,'score':20,'accepted':True,'reference_id':'a','quad':[[0,0],[100,0],[100,100],[0,100]]}
        b={**a,'reference_id':'b','quad':[[200,0],[300,0],[300,100],[200,100]]}
        self.assertEqual(rm.choose([a,b])['decision'],'ambiguous')

class FeatureTestBase(unittest.TestCase):
    algorithm='sift'
    def setUp(self):
        if rm.cv2 is None:self.skipTest('OpenCV unavailable; no feature-test claim')
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name);self.ref=abstract();self.path,_=manifest(self.root,self.ref)
        self.query=np.full((480,640),245,np.uint8)
        self.query[100:340,130:490]=self.ref
    def tearDown(self):
        if hasattr(self,'tmp'):self.tmp.cleanup()
    def evaluate(self,query):
        p=self.root/'query.png';rm.cv2.imwrite(str(p),query);return rm.run(self.path,p,self.algorithm)
    def check_positive(self,r):
        self.assertEqual(r['decision'],'denomination_experiment',[(c['inliers'],c['failures']) for c in r['candidates']]);self.assertEqual(r['selected_reference_label'],10);self.assertIsNone(r['monetary_answer'])
    def test_contained(self):self.check_positive(self.evaluate(self.query))
    def test_brightness(self):self.check_positive(self.evaluate(np.uint8(np.clip(self.query.astype(float)*.8+20,0,255))))
    def test_rotation(self):self.check_positive(self.evaluate(np.rot90(self.query).copy()))
    def test_perspective(self):
        src=np.float32([[0,0],[359,0],[359,239],[0,239]]);dst=np.float32([[100,90],[510,110],[500,370],[110,350]])
        q=rm.cv2.warpPerspective(self.ref,rm.cv2.getPerspectiveTransform(src,dst),(640,480),borderValue=245);self.check_positive(self.evaluate(q))
    def test_blank(self):self.assertEqual(self.evaluate(np.full((480,640),245,np.uint8))['decision'],'unknown')
    def test_unrelated(self):
        q=np.full((480,640),245,np.uint8);q[100:340,130:490]=abstract(91);self.assertNotEqual(self.evaluate(q)['decision'],'denomination_experiment')
    def test_self_not_independent(self):
        r=rm.run(self.path,self.root/'ref.png',self.algorithm);self.assertTrue(r['query_matches_reference_bytes']);self.assertFalse(r['query_independence_verified']);self.assertIsNone(r['monetary_answer'])
    def test_deterministic(self):self.assertEqual(self.evaluate(self.query),self.evaluate(self.query))

class SiftTests(FeatureTestBase):algorithm='sift'
class OrbTests(FeatureTestBase):algorithm='orb'
class AkazeTests(FeatureTestBase):algorithm='akaze'
# Do not collect the abstract base as a fourth method.
del FeatureTestBase
if __name__=='__main__':unittest.main()
