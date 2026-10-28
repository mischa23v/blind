import unittest, struct, copy
from compare_full_mesh import near,multiset_match,oriented_equal,words,triples,tol,compare
class ComparatorTests(unittest.TestCase):
    def test_reordered_vertices(self):
        self.assertTrue(multiset_match([[0,0,0],[1,2,3]],[[1,2,3],[0,0,0]],near))
    def test_duplicates_not_deduplicated(self):
        self.assertFalse(multiset_match([[0,0,0],[0,0,0]],[[0,0,0],[1,0,0]],near))
    def test_augmenting_assignment_not_greedy(self):
        self.assertTrue(multiset_match([0,1],[0,1],lambda a,b:a==0 or b==0))
    def test_cyclic_winding_preserved(self):
        a=[[0,0,0],[1,0,0],[0,1,0]]
        self.assertTrue(oriented_equal(a,a[1:]+a[:1]))
        self.assertFalse(oriented_equal(a,list(reversed(a))))
    def test_coherent_scale_is_not_accepted(self):
        self.assertFalse(near([1,2,3],[100,200,300]))
    def test_float32_numerical_only(self):
        self.assertTrue(near([1],[1+2**-23])); self.assertFalse(near([1],[1.001]))
        self.assertEqual(tol(1),64*2**-23)
    def test_nan_bits_rejected(self):
        with self.assertRaises(ValueError): words([0x7fc00000])
    def test_boolean_bits_rejected(self):
        with self.assertRaises(ValueError): words([True])
    def test_unequal_triangle_multiplicity(self):
        a=[[0,0,0],[1,0,0],[0,1,0]]
        self.assertFalse(multiset_match([a,a],[a],oriented_equal))
    def test_no_global_scale_or_translation(self):
        self.assertFalse(multiset_match([[0,0,0]],[[0,0,.16]],near))
class EndToEndSynthetic(unittest.TestCase):
    def setUp(self):
        self.identity='00000000-0000-0000-0000-000000000001'
        matrix=[[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]
        pts=[[0,0,0],[1,0,0],[0,1,0]]
        encode=lambda xs:[struct.unpack('<I',struct.pack('<f',x))[0] for x in xs]
        self.native={'nodeIndex':0,'featureID':self.identity,'localTransformBits':encode(sum(matrix,[])), 'worldTransformBits':encode(sum(matrix,[])),'localPositionBits':encode(sum(pts,[])), 'worldPositionBits':encode(sum(pts,[])),'triangleIndices':[0,1,2]}
        self.inventory={'fixtures':[{'fixtureID':'Synthetic','sourceSHA256':'synthetic','meshParity':{'schema':'blind.public-apple-native-mesh-parity.v1','complete':True,'representation':'raw-diagnostic-export','coordinateEncoding':'float32-bit-patterns-column-major','winding':'ordered-native-triangle-indices','meshes':[self.native]}}]}
        self.reference={'fixtureID':'Synthetic','nativeInventorySHA256':'synthetic-hash','stageMetersPerUnit':1,'metersPerUnitAuthored':True,'upAxisAuthored':True,'stageUpAxis':'Y','nodes':[{'path':'/mesh','localMatrixRows':matrix,'worldMatrixRows':matrix}],'meshes':[{'featureID':self.identity,'path':'/mesh','orientation':'rightHanded','subdivisionScheme':'none','holeIndices':[],'faceVertexCounts':[3],'faceVertexIndices':[0,1,2],'localPositions':pts,'worldPositions':pts}],'usdzSHA256':'synthetic','metadataSHA256':'synthetic','sourceSHA256':'synthetic'}
    def run_compare(self): return compare(self.reference,self.inventory,'synthetic-hash')
    def test_full_positive(self): self.assertTrue(self.run_compare()['allPassed'])
    def test_full_reversed_winding(self):
        self.native['triangleIndices']=[2,1,0]
        self.assertFalse(self.run_compare()['allPassed'])
    def test_full_missing_vertex(self):
        self.native['worldPositionBits'] += [0,0,0]
        self.assertFalse(self.run_compare()['allPassed'])
    def test_manifest_mismatch(self):
        with self.assertRaises(ValueError): compare(self.reference,self.inventory,'wrong')
    def test_native_capture_absent(self):
        del self.inventory['fixtures'][0]['meshParity']
        with self.assertRaises(ValueError): self.run_compare()
    def test_identity_mismatch(self):
        self.native['featureID']='00000000-0000-0000-0000-000000000002'
        with self.assertRaises(ValueError): self.run_compare()
    def test_holes_rejected(self):
        self.reference['meshes'][0]['holeIndices']=[0]
        with self.assertRaises(ValueError): self.run_compare()
    def test_failed_inventory_rejected(self):
        self.inventory['fixtures'][0]['inventoryFailure']='invalidMesh'
        with self.assertRaises(ValueError): self.run_compare()
    def test_subdivision_rejected(self):
        self.reference['meshes'][0]['subdivisionScheme']='catmullClark'
        with self.assertRaises(ValueError): self.run_compare()
    def test_unauthored_units_rejected(self):
        self.reference['metersPerUnitAuthored']=False
        with self.assertRaises(ValueError): self.run_compare()
    def test_duplicate_identity_rejected(self):
        self.inventory['fixtures'][0]['meshParity']['meshes'].append(copy.deepcopy(self.native))
        with self.assertRaises(ValueError): self.run_compare()
if __name__=='__main__': unittest.main()

