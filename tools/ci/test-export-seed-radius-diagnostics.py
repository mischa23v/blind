"""Pure fixtures only; no xcodebuild/xcresult execution."""
from pathlib import Path
import importlib.util,unittest,json,tempfile,io,contextlib
from unittest.mock import patch
H=Path(__file__).parent;s=importlib.util.spec_from_file_location('diag',H/'export-seed-radius-diagnostics.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
NAME='SeedRadiusVetoAppleTests/testInsufficientWorkBudgetReturnsTypedRefusalNeverStockRoute'
CASES=[{'identifier':x+'()','result':'Passed'} for x in sorted(m.EXPECTED)]
class Tests(unittest.TestCase):
 def test_all8(self):self.assertEqual(len(m.summarize(CASES,{},None,{'exit_code':0})['cases']),8)
 def test_failed_preserved(self):self.assertEqual(m.summarize([{'identifier':NAME,'result':'Failed'}],{},None,{'exit_code':65})['cases'][0]['result'],'Failed')
 def test_exit65_preserved(self):self.assertEqual(m.summarize(None,None,None,{'exit_code':65})['commandExit'],65)
 def test_missing_exit_unknown(self):self.assertIsNone(m.summarize(None,None,None,{})['commandExit'])
 def test_bool_exit_unknown(self):self.assertIsNone(m.summarize(None,None,None,{'exit_code':True})['commandExit'])
 def test_unknown_identity_not_exported(self):self.assertEqual(m.summarize([{'identifier':'Private/name','result':'Failed'}],{},None,{})['unexpectedCaseCount'],1)
 def test_failure_text(self):self.assertEqual(m.summarize(None,{'testFailures':[{'testIdentifier':NAME,'failureText':'XCTAssertTrue failed'}]},None,{})['assertionFailures'][0]['message'],'XCTAssertTrue failed')
 def test_message_shape(self):self.assertEqual(len(m.summarize(None,{'testFailures':[{'testName':NAME,'message':'failed'}]},None,{})['assertionFailures']),1)
 def test_module_prefix(self):self.assertEqual(m.identity('BlindAssistTests/'+NAME+'()'),NAME)
 def test_objc_identity(self):self.assertEqual(m.identity('-[BlindAssistTests.SeedRadiusVetoAppleTests '+NAME.split('/')[1]+']'),NAME)
 def test_unknown_failure_withheld(self):
  x=m.summarize(None,{'testFailures':[{'testName':'Private/name','message':'PRIVATE'}]},None,{})
  self.assertEqual(x['unparsedFailureRecordCount'],1);self.assertEqual(x['assertionFailures'],[])
 def test_unknown_schema_counted(self):self.assertEqual(m.summarize(None,{'testFailures':['PRIVATE']},None,{})['unparsedFailureRecordCount'],1)
 def test_failure_cap(self):self.assertEqual(len(m.summarize(None,{'testFailures':[{'testIdentifier':NAME,'message':'failed'}]*50},None,{})['assertionFailures']),32)
 def test_message_bound(self):self.assertEqual(len(m.message('x'*2000)['message']),768);self.assertTrue(m.message('x'*2000)['truncated'])
 def test_arrays_removed(self):self.assertEqual(m.message('expected [1,2,3]')['message'],'expected [values omitted]')
 def test_paths_removed(self):self.assertNotIn('/Users/runner',m.message('/Users/runner/file failed')['message'])
 def test_control_chars_removed(self):self.assertNotIn('\n',m.message('a\nb')['message'])
 def test_fixed_log_assertion(self):
  log='/Users/runner/SavedRoomStrictEndpointTests.swift:182: error: -[BlindAssistTests.SeedRadiusVetoAppleTests '+NAME.split('/')[1]+'] : XCTAssertTrue failed'
  x=m.summarize(None,None,log,{'exit_code':65});self.assertEqual(x['assertionFailures'][0]['line'],182)
 def test_other_file_log_withheld(self):self.assertEqual(m.summarize(None,None,'Other.swift:1: error: PRIVATE',{})['assertionFailures'],[])
 def test_other_test_log_withheld(self):self.assertEqual(m.summarize(None,None,'SavedRoomStrictEndpointTests.swift:1: error: -[Other testPrivate] : PRIVATE',{})['assertionFailures'],[])
 def test_no_success_authority(self):self.assertIn('never authorizes pass',m.summarize(CASES,{},None,{'exit_code':0})['scope'])
class MainPathTests(unittest.TestCase):
 def run_main(self,command,summary):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);out=root/'output';out.mkdir();fixture=root/'ios/BlindAssistTests/SavedRoomStrictEndpointTests.swift';fixture.parent.mkdir(parents=True)
   fixture.write_bytes((H.parents[1]/'ios/BlindAssistTests/SavedRoomStrictEndpointTests.swift').read_bytes())
   (out/'seed-radius-unit-exit.json').write_text(json.dumps(command))
   (out/'seed-radius-unit.log').write_text('')
   def query(args):return json.dumps(summary if 'summary' in args else {'testNodes':[]}).encode()
   with patch.object(m,'ROOT',root),patch.object(m.sys,'argv',['exporter',str(out)]),patch.object(m.m.native,'provenance',return_value={'actual_head':'a'*40}),patch.object(m.m.native,'query',side_effect=query),patch.object(m.m.native,'cases_from',return_value=CASES),contextlib.redirect_stdout(io.StringIO()):
    self.assertEqual(m.main(),0)
   return json.loads((out/'seed-radius-diagnostics.json').read_text())
 def test_null_command(self):self.assertIsNone(self.run_main(None,{})['commandExit'])
 def test_list_command(self):self.assertEqual(self.run_main([],{})['errors']['command'],'ValueError')
 def test_scalar_command(self):self.assertEqual(self.run_main(65,{})['errors']['command'],'ValueError')
 def test_string_command(self):self.assertEqual(self.run_main('PRIVATE',{})['errors']['command'],'ValueError')
 def test_exit65_survives_unknown_summary(self):self.assertEqual(self.run_main({'exit_code':65},[])['commandExit'],65)
 def test_null_summary_explicit_unknown(self):self.assertTrue(self.run_main({'exit_code':65},None)['summarySchemaUnavailable'])
 def test_array_summary_explicit_unknown(self):self.assertTrue(self.run_main({'exit_code':65},[])['summarySchemaUnavailable'])
 def test_missing_failure_schema_explicit_unknown(self):self.assertTrue(self.run_main({'exit_code':65},{})['failureSchemaUnavailable'])
if __name__=='__main__':unittest.main()
