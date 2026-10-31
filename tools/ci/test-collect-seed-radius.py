"""Synthetic strict receipt parser regressions only; not Apple execution."""
from pathlib import Path
import importlib.util,unittest
P=Path(__file__).parent;s=importlib.util.spec_from_file_location('seated',P/'collect-seed-radius.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
SOURCE=(P.parents[1]/'ios/BlindAssistTests/SavedRoomStrictEndpointTests.swift').read_text()
CASES=[{'identifier':x+'()','result':'Passed'} for x in m.EXPECTED]
SUMMARY={'totalTestCount':14,'passedTests':14,'failedTests':0,'skippedTests':0,'expectedFailures':0}
LOG='\n'.join(f"Test Case '-[BlindAssistTests.{x.split('/')[0]} {x.split('/')[1]}]' "+('started.' if event=='started' else 'passed (0.001 seconds).') for x in m.EXPECTED for event in ['started','passed'])+'\n'
class Tests(unittest.TestCase):
 def reject(self,cases=CASES,summary=SUMMARY,log=LOG,command={'exit_code':0},source=SOURCE):
  with self.assertRaises((ValueError,KeyError)):m.collect(cases,summary,log,command,source)
 def test_exact14(self):self.assertEqual(m.collect(CASES,SUMMARY,LOG,{'exit_code':0},SOURCE)['executed'],14)
 def test_missing_case(self):self.reject(cases=CASES[:-1])
 def test_duplicate_case(self):self.reject(cases=CASES[:-1]+CASES[:1])
 def test_failed_case(self):self.reject(cases=[dict(CASES[0],result='Failed')]+CASES[1:])
 def test_skipped_case(self):self.reject(cases=[dict(CASES[0],result='Skipped')]+CASES[1:])
 def test_other_class(self):self.reject(cases=[dict(CASES[0],identifier='Other/testX()')]+CASES[1:])
 def test_nonzero_exit(self):self.reject(command={'exit_code':65})
 def test_bool_exit_rejected(self):self.reject(command={'exit_code':False})
 def test_missing_exit(self):self.reject(command={})
 def test_bad_summary(self):self.reject(summary=dict(SUMMARY,totalTestCount=7))
 def test_missing_log_pair(self):self.reject(log='\n'.join(LOG.splitlines()[2:]))
 def test_failed_log(self):self.reject(log=LOG.replace('passed','failed',1))
 def test_skipped_log(self):self.reject(log=LOG.replace('passed','skipped',1))
 def test_duplicate_log(self):self.reject(log=LOG+LOG.splitlines()[0]+'\n')
 def test_other_log_class(self):self.reject(log=LOG.replace('BlindAssistTests.SavedRoomStrictEndpointTests','Other.SavedRoomStrictEndpointTests',1))
 def test_other_log_case(self):self.reject(log=LOG.replace(m.EXPECTED[0].split('/')[1],'testUnexpected',1))
 def test_source_rename(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED[0].split('/')[1]+'(', 'func testUnexpected('))
 def test_source_class_removed(self):self.reject(source=SOURCE.replace('SeedRadiusVetoAppleTests','RemovedTests',1))
 def test_empty_log(self):self.reject(log='')
 def test_unqualified_hosted_class(self):self.assertEqual(m.collect(CASES,SUMMARY,LOG.replace('BlindAssistTests.',''),{'exit_code':0},SOURCE)['executed'],14)
 def test_each_new_envelope_case_is_required_and_must_pass(self):
  for index,row in enumerate(CASES):
   if not row['identifier'].startswith('SeedRadiusEnvelopeAppleTests/'):continue
   with self.subTest(case=row['identifier']):
    self.reject(cases=CASES[:index]+CASES[index+1:])
    self.reject(cases=CASES[:index]+[dict(row,result='Failed')]+CASES[index+1:])
    self.reject(cases=CASES[:index]+[dict(row,result='Skipped')]+CASES[index+1:])
 def test_new_envelope_log_class_required(self):self.reject(log=LOG.replace('SeedRadiusEnvelopeAppleTests','UnknownEnvelopeClass'))
if __name__=='__main__':unittest.main()
