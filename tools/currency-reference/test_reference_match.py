"""Fresh reconstruction tests. Abstract circles/lines, never banknote accuracy."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
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

@unittest.skipIf(rm.cv2 is None, 'OpenCV unavailable; secondary-scene veto not run')
class SecondarySceneVetoTests(unittest.TestCase):
    """Synthetic policy evidence, not note-count or banknote accuracy tests."""
    def candidate(self, label=100, reference='first', region=0, inliers=30, matches=40,
                  reference_spread=.5, query_spread=.5, grid=8, quad=None, geometry_failures=()):
        ratio = inliers / matches
        score = inliers * ratio * np.sqrt(min(reference_spread, query_spread, 1))
        geometry = list(geometry_failures)
        if (reference_spread < rm.POLICY.min_reference_spread or query_spread < rm.POLICY.min_query_spread
                or grid < rm.POLICY.min_grid_cells):
            geometry.append('insufficient_spatial_support')
        failures = list(geometry)
        if inliers < rm.POLICY.min_inliers: failures.append('insufficient_inliers')
        if ratio < rm.POLICY.min_inlier_ratio: failures.append('insufficient_inlier_ratio')
        if score < rm.POLICY.min_score: failures.append('insufficient_score')
        return {'label': label, 'reference_id': reference, 'region_index': region,
                'ratio_matches': matches, 'inliers': inliers, 'inlier_ratio': ratio, 'score': float(score),
                'reference_spread': reference_spread, 'query_spread': query_spread, 'reference_grid_cells': grid,
                'quad_area_fraction': .3, 'minimum_edge_px': 80., 'reprojection_median_px': .5,
                'quad': quad or [[200.,160.],[800.,160.],[800.,560.],[200.,560.]],
                'accepted': not failures, 'failures': failures, 'geometry_pass': not geometry,
                'geometry_failures': geometry}

    def shifted(self): return [[300.,160.],[900.,160.],[900.,560.],[300.,560.]]

    def test_same_note_alternate_references_are_not_two_notes(self):
        candidates = [self.candidate(), self.candidate(reference='alternate', inliers=29)]
        self.assertEqual(rm.choose(candidates)['decision'], 'denomination_experiment')

    def test_coincident_cross_label_retains_original_score_margin(self):
        best = self.candidate(inliers=80, matches=100)
        self.assertEqual(rm.choose([best, self.candidate(1, reference='one')])['selected_reference_label'], 100)
        close = [self.candidate(), self.candidate(1, reference='one', inliers=29)]
        self.assertEqual(rm.choose(close)['reason'], 'different_denomination_margin_too_small')

    def test_high_overlap_noncoincident_same_and_different_labels_veto(self):
        for label in [100, 1]:
            candidates = [self.candidate(inliers=80, matches=100), self.candidate(label, reference='other', quad=self.shifted())]
            self.assertGreater(rm.region_overlap(*candidates), rm.POLICY.distinct_region_overlap)
            self.assertEqual(rm.choose(candidates)['reason'], 'noncoincident_supported_note_boundaries')

    def test_distinct_regions_from_same_reference_veto_even_coincident(self):
        result = rm.choose([self.candidate(), self.candidate(region=1)])
        self.assertEqual(result['reason'], 'multiple_supported_reference_regions')

    def test_polygon_not_bounding_box_controls_equivalence(self):
        diamond = [[500.,160.],[800.,360.],[500.,560.],[200.,360.]]
        result = rm.choose([self.candidate(), self.candidate(reference='other', quad=diamond)])
        self.assertEqual(result['reason'], 'noncoincident_supported_note_boundaries')

    def test_existing_point_eight_threshold_has_exact_boundary(self):
        first = self.candidate(quad=[[0.,0.],[100.,0.],[100.,100.],[0.,100.]])
        for width, decision in [(80., 'denomination_experiment'), (79.9, 'ambiguous')]:
            second = self.candidate(reference='other', quad=[[0.,0.],[width,0.],[width,100.],[0.,100.]])
            self.assertEqual(rm.choose([first, second])['decision'], decision)
        self.assertEqual(rm.POLICY.min_proposal_overlap, .80)

    def test_each_spatial_support_failure_can_only_veto(self):
        for changes in [{'reference_spread': .19}, {'query_spread': .19}, {'grid': 4}]:
            partial = self.candidate(reference='partial', quad=self.shifted(), **changes)
            original = copy.deepcopy(partial)
            self.assertTrue(rm.partial_support_veto_candidate(partial))
            self.assertEqual(rm.choose([self.candidate(), partial])['decision'], 'ambiguous')
            self.assertEqual(rm.choose([partial])['decision'], 'unknown')
            self.assertEqual(partial, original)

    def test_partial_same_reference_second_region_veto(self):
        partial = self.candidate(region=1, grid=4)
        self.assertEqual(rm.choose([self.candidate(), partial])['reason'], 'multiple_supported_reference_regions')

    def test_partial_coincident_alternate_is_not_automatically_second_note(self):
        partial = self.candidate(reference='partial', grid=4)
        self.assertEqual(rm.choose([self.candidate(), partial])['decision'], 'denomination_experiment')

    def test_other_geometry_failures_never_gain_secondary_support(self):
        for failure in ['nonfinite_or_pole', 'quad_not_convex', 'quad_not_fully_in_frame',
                        'implausible_quad_area', 'insufficient_projected_edge', 'implausible_quad_angles',
                        'implausible_edge_ratio', 'implausible_opposite_edges', 'excessive_projective_distortion',
                        'excessive_reprojection_error']:
            partial = self.candidate(reference='partial', grid=4, quad=self.shifted(), geometry_failures=[failure])
            self.assertFalse(rm.partial_support_veto_candidate(partial), failure)
            self.assertEqual(rm.choose([self.candidate(), partial])['decision'], 'denomination_experiment')

    def test_low_evidence_never_gains_secondary_support(self):
        for changes in [{'inliers':13}, {'inliers':20,'matches':60}, {'reference_spread':.01}]:
            partial = self.candidate(reference='partial', grid=4, quad=self.shifted(), **changes)
            self.assertFalse(rm.partial_support_veto_candidate(partial))
            self.assertEqual(rm.choose([self.candidate(), partial])['decision'], 'denomination_experiment')

    def test_malformed_partial_numbers_do_not_gain_secondary_support(self):
        for field, value in [('score', float('nan')), ('score', 100.), ('inlier_ratio', .9),
                             ('ratio_matches', 1801), ('inliers', True), ('reference_grid_cells', 10),
                             ('minimum_edge_px', 7.99), ('reprojection_median_px', 2.51),
                             ('quad_area_fraction', .039), ('quad_area_fraction', .901),
                             ('reference_spread', 1.1), ('query_spread', float('inf')),
                             ('quad', [[0.,0.],[float('nan'),0.],[100.,100.],[0.,100.]])]:
            partial = self.candidate(reference='partial', grid=4)
            partial[field] = value
            self.assertFalse(rm.partial_support_veto_candidate(partial), field)

    def test_malformed_partial_evidence_rejects_entire_decision_not_only_veto(self):
        for field, value in [('score', float('nan')), ('score', float('inf')), ('score', -1.),
                             ('score', 100.), ('inlier_ratio', .9), ('ratio_matches', 1801),
                             ('inliers', True), ('reference_grid_cells', 10), ('reference_spread', 1.1),
                             ('query_spread', float('inf')), ('minimum_edge_px', '80'),
                             ('reprojection_median_px', float('nan')),
                             ('quad', [[0.,0.],[float('nan'),0.],[100.,100.],[0.,100.]])]:
            for accepted_first in (True, False):
                partial = self.candidate(reference='partial', grid=4)
                partial[field] = value
                candidates = [self.candidate(), partial]
                if not accepted_first:
                    candidates.reverse()
                with self.subTest(field=field, accepted_first=accepted_first), self.assertRaises(rm.InputError):
                    rm.choose(candidates)

    def test_missing_computed_evidence_cannot_silently_remove_secondary_veto(self):
        for field in ('score', 'quad', 'inlier_ratio', 'reference_spread', 'reference_grid_cells',
                      'geometry_failures', 'reprojection_median_px'):
            partial = self.candidate(reference='partial', grid=4, quad=self.shifted())
            del partial[field]
            with self.subTest(field=field), self.assertRaises(rm.InputError):
                rm.choose([self.candidate(), partial])

    def test_generated_empty_failures_without_geometry_remain_valid(self):
        for reason, matches, inliers in [('insufficient_features',0,0), ('insufficient_ratio_matches',3,0),
                                        ('no_homography',25,0), ('insufficient_unique_inliers',25,3)]:
            empty = {'label':100, 'reference_id':'empty', 'reference_keypoints':30, 'score':0.,
                     'accepted':False, 'failures':[reason], 'ratio_matches':matches, 'inliers':inliers}
            with self.subTest(reason=reason):
                self.assertEqual(rm.choose([empty])['decision'], 'unknown')
                self.assertEqual(rm.choose([self.candidate(), empty])['decision'], 'denomination_experiment')

    def test_generated_nonfinite_homography_failure_omits_geometry_but_not_validation(self):
        failed = {'label':100, 'reference_id':'failed', 'reference_keypoints':30, 'score':0.,
                  'accepted':False, 'failures':['nonfinite_or_pole','insufficient_score'],
                  'geometry_pass':False, 'geometry_failures':['nonfinite_or_pole'],
                  'region_index':0, 'ratio_matches':25, 'inliers':20, 'inlier_ratio':.8}
        self.assertEqual(rm.choose([failed])['decision'], 'unknown')
        self.assertEqual(rm.choose([self.candidate(), failed])['decision'], 'denomination_experiment')
        failed['score'] = float('nan')
        with self.assertRaises(rm.InputError):
            rm.choose([self.candidate(), failed])

    def test_stronger_failed_same_label_cannot_be_replaced_by_accepted_one(self):
        partial = self.candidate(reference='partial', inliers=80, matches=100, grid=4)
        self.assertEqual(rm.choose([self.candidate(), partial])['decision'], 'unknown')

    def test_only_partial_candidates_never_accept(self):
        candidates = [self.candidate(grid=4), self.candidate(reference='other', quad=self.shifted(), grid=4)]
        self.assertEqual(rm.choose(candidates)['decision'], 'unknown')

class NativeFeatureParityTests(unittest.TestCase):
    def test_tied_feature_overflow_preserves_order_and_descriptor_alignment(self):
        points=list(range(rm.POLICY.max_features+7))
        descriptors=np.arange(len(points)*3,dtype=np.float32).reshape(-1,3)
        detector=mock.Mock();detector.detectAndCompute.return_value=(points,descriptors)
        gray=np.zeros((32,32),np.uint8)
        actual_points,actual_descriptors=rm.features(detector,gray)
        self.assertEqual(actual_points,points[:1800])
        np.testing.assert_array_equal(actual_descriptors,descriptors[:1800])
        self.assertFalse(np.shares_memory(actual_descriptors,descriptors))
        detector.detectAndCompute.assert_called_once_with(gray,None)
    def test_at_limit_does_not_reorder_or_copy(self):
        points=list(range(1800));descriptors=np.zeros((1800,8),np.uint8)
        detector=mock.Mock();detector.detectAndCompute.return_value=(points,descriptors)
        actual_points,actual_descriptors=rm.features(detector,None)
        self.assertIs(actual_points,points);self.assertIs(actual_descriptors,descriptors)
    def test_empty_descriptors_stay_empty(self):
        detector=mock.Mock();detector.detectAndCompute.return_value=([],None)
        self.assertEqual(rm.features(detector,None),([],None))
    def test_mismatched_or_nonfinite_descriptors_rejected(self):
        for points,descriptors in [([0,1],np.zeros((1,3))),([0],np.array([[np.nan]])),
                                   ([0],np.array([[np.inf]])),(list(range(1801)),None),
                                   (list(range(1801)),np.zeros((1799,2)))]:
            detector=mock.Mock();detector.detectAndCompute.return_value=(points,descriptors)
            with self.subTest(count=len(points)), self.assertRaises(rm.InputError):
                rm.features(detector,None)
    def test_unused_overflow_descriptors_are_discarded_like_native(self):
        descriptors=np.zeros((1801,2),np.float32);descriptors[-1]=np.nan
        detector=mock.Mock();detector.detectAndCompute.return_value=(list(range(1801)),descriptors)
        self.assertEqual(len(rm.features(detector,None)[0]),1800)

@unittest.skipIf(rm.cv2 is None,'OpenCV unavailable; geometry parity not run')
class NativeGeometryParityTests(unittest.TestCase):
    def evidence(self,length):
        source=np.float32([[x,y] for y in [0,15.5,31] for x in [0,15.5,31]])
        h=np.array([[length/31,0,10],[0,length/31,10],[0,0,1]],np.float64)
        target=rm.cv2.perspectiveTransform(source.reshape(-1,1,2),h).reshape(-1,2)
        return rm.geometry_evidence(h,source,target,(32,32),(32,32))
    def test_projected_edge_below_eight_fails_otherwise_valid_geometry(self):
        result=self.evidence(7.99)
        self.assertEqual(result['geometry_failures'],['insufficient_projected_edge'])
        self.assertFalse(result['geometry_pass'])
        self.assertAlmostEqual(result['minimum_edge_px'],7.99,places=6)
    def test_projected_edge_at_eight_passes(self):
        result=self.evidence(8.)
        self.assertTrue(result['geometry_pass'],result['geometry_failures'])
        self.assertEqual(result['minimum_edge_px'],8.)
        self.assertEqual(rm.POLICY.min_quad_edge_px,8.)
    def test_projected_edge_above_eight_passes(self):
        self.assertTrue(self.evidence(8.01)['geometry_pass'])
    def test_native_float32_corner_rounding_controls_boundary_decision(self):
        # Point2f rounds 17.9999998 to 18, giving the native exact edge length 8.
        result=self.evidence(7.9999998)
        self.assertTrue(result['geometry_pass'],result['geometry_failures'])
        self.assertEqual(result['minimum_edge_px'],8.)
        self.assertEqual(result['quad'],[[10.,10.],[18.,10.],[18.,18.],[10.,18.]])
    def test_non_double_homography_rejected_like_native(self):
        points=np.float32([[0,0],[31,0],[31,31],[0,31]])
        result=rm.geometry_evidence(np.eye(3,dtype=np.float32),points,points,(32,32),(64,64))
        self.assertFalse(result['geometry_pass'])
        self.assertEqual(result['geometry_failures'],['nonfinite_or_pole'])

@unittest.skipIf(rm.cv2 is None,'OpenCV unavailable; feature integration not run')
class NativeFeatureIntegrationTests(unittest.TestCase):
    def test_query_and_reference_both_use_bounded_features(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);path,_=manifest(root,abstract())
            points=[rm.cv2.KeyPoint(float(i%100),float(i//100),1) for i in range(1807)]
            descriptors=np.zeros((1807,128),np.float32)
            detector=mock.Mock();detector.detectAndCompute.return_value=(points,descriptors)
            matcher=mock.Mock();matcher.knnMatch.return_value=[]
            with mock.patch.object(rm,'create_detector',return_value=detector), mock.patch.object(rm.cv2,'BFMatcher',return_value=matcher):
                result=rm.run(path,root/'ref.png')
            self.assertEqual(result['query_keypoints'],1800)
            self.assertEqual(result['candidates'][0]['reference_keypoints'],1800)
            query_descriptors,reference_descriptors=matcher.knnMatch.call_args.args
            self.assertEqual(query_descriptors.shape,(1800,128))
            self.assertEqual(reference_descriptors.shape,(1800,128))
            self.assertEqual(detector.detectAndCompute.call_count,2)

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
