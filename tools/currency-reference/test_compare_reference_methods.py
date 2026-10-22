"""Reconstructed fresh accounting tests, not historical photo evaluation."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import compare_reference_methods as c
import reference_match as rm
class ComparisonTests(unittest.TestCase):
    def test_correct(self):
        self.assertEqual(c.classify_outcome({'expected_label':10,'must_abstain':False},{'decision':'denomination_experiment','selected_reference_label':10}),{'outcome':'correct_experimental_label','policy_false_accept':False})
    def test_wrong(self):
        r=c.classify_outcome({'expected_label':10,'must_abstain':True},{'decision':'denomination_experiment','selected_reference_label':100});self.assertEqual(r['outcome'],'wrong_label');self.assertTrue(r['policy_false_accept'])
    def test_composite_correct_label_still_error(self):
        r=c.classify_outcome({'expected_label':1,'must_abstain':True},{'decision':'denomination_experiment','selected_reference_label':1});self.assertTrue(r['policy_false_accept'])
    def test_foreign(self):
        r=c.classify_outcome({'expected_label':None,'must_abstain':True},{'decision':'denomination_experiment','selected_reference_label':100});self.assertEqual(r['outcome'],'negative_false_accept')
    def test_unknown_ambiguous(self):
        for d in ['unknown','ambiguous']:self.assertEqual(c.classify_outcome({'expected_label':10,'must_abstain':False},{'decision':d,'selected_reference_label':None})['outcome'],'abstention')
    def test_manifest_hash_and_unknown_identity(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);p=root/'q.jpg';p.write_bytes(b'input hash only')
            q={'id':'q','path':'q.jpg','sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'expected_label':10,'must_abstain':False,'case_role':'known','physical_note_id':None,'capture_session_id':None,'independence_from_references':'unresolved','source':'local','rights':'test','notes':'not real photo'}
            m={'schema_version':1,'evaluation_kind':'development_diagnostic','independence_summary':'unresolved','queries':[q]};mp=root/'q.json';mp.write_text(json.dumps(m));self.assertIsNone(c.load_queries(mp)[1][0][0]['physical_note_id'])
            q['sha256']='0'*64;mp.write_text(json.dumps(m))
            with self.assertRaises(rm.InputError):c.load_queries(mp)
if __name__=='__main__':unittest.main()
