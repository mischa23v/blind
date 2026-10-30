"""Portable JSON/source guard controls only; never invokes plutil or Apple tools."""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

H=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('guard',H/'verify-default-project.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
FIXTURE=json.loads((H/'fixtures/default-project-valid.json').read_text())
RAW='OTHER_SWIFT_FLAGS = "'+m.FLAG_VALUE+'";\n'
RAW=RAW*2

class GuardTests(unittest.TestCase):
 def setUp(self):self.p=copy.deepcopy(FIXTURE);self.o=self.p['objects']
 def reject(self,raw=RAW):
  with self.assertRaises((ValueError,TypeError,AttributeError,KeyError)):m.validate_project(self.p,raw)
 def setting(self,target='BlindAssistTests',variant='Debug'):return self.o[target+'-'+variant]['buildSettings']
 def test_exact_two_exclusive_unit_configs(self):
  r=m.validate_project(self.p,RAW);self.assertEqual(r['oracle_flag_configurations'],['Debug','Release']);self.assertEqual(r['oracle_flag_occurrences'],2)
 def test_existing_project_app_list_sharing_is_not_privileged(self):
  self.assertEqual(self.o['project']['buildConfigurationList'],self.o['BlindAssist']['buildConfigurationList']);m.validate_project(self.p,RAW)
 def test_target_order_is_not_assumed(self):self.o['project']['targets'].reverse();m.validate_project(self.p,RAW)
 def test_app_flag_rejected(self):self.setting('BlindAssist')['OTHER_SWIFT_FLAGS']=m.FLAG_VALUE;self.reject()
 def test_ui_flag_rejected(self):self.setting('BlindAssistUITests')['OTHER_SWIFT_FLAGS']=m.FLAG_VALUE;self.reject()
 def test_project_level_flag_rejected(self):self.o['project']['OTHER_SWIFT_FLAGS']=m.FLAG_VALUE;self.reject()
 def test_unknown_orphan_flag_rejected(self):self.o['orphan']={'isa':'XCBuildConfiguration','buildSettings':{'OTHER_SWIFT_FLAGS':m.FLAG_VALUE}};self.reject()
 def test_flag_in_arbitrary_file_string_rejected(self):self.o['file']={'isa':'PBXFileReference','path':m.FLAG};self.reject()
 def test_same_flag_under_wrong_setting_rejected(self):self.setting()['SWIFT_ACTIVE_COMPILATION_CONDITIONS']=m.FLAG;self.reject()
 def test_extra_flag_rejected(self):self.setting()['OTHER_SWIFT_FLAGS']=m.FLAG_VALUE+' -D OTHER';self.reject()
 def test_duplicate_flag_rejected(self):self.setting()['OTHER_SWIFT_FLAGS']=m.FLAG_VALUE+' -D '+m.FLAG;self.reject()
 def test_extra_whitespace_rejected(self):self.setting()['OTHER_SWIFT_FLAGS']=m.FLAG_VALUE+' ';self.reject()
 def test_array_flag_rejected(self):self.setting()['OTHER_SWIFT_FLAGS']=['$(inherited)','-D',m.FLAG];self.reject()
 def test_flag_case_mutation_rejected(self):self.setting()['OTHER_SWIFT_FLAGS']=m.FLAG_VALUE.lower();self.reject()
 def test_conditioned_setting_rejected(self):self.setting()['OTHER_SWIFT_FLAGS[sdk=iphoneos*]']=m.FLAG_VALUE;self.reject()
 def test_other_app_flags_rejected(self):self.setting('BlindAssist')['OTHER_SWIFT_FLAGS']='-D UNREVIEWED';self.reject()
 def test_missing_debug_flag_rejected(self):self.setting().pop('OTHER_SWIFT_FLAGS');self.reject()
 def test_missing_release_flag_rejected(self):self.setting(variant='Release').pop('OTHER_SWIFT_FLAGS');self.reject()
 def test_root_target_missing_rejected(self):self.o['project']['targets'].remove('BlindAssistTests');self.reject()
 def test_orphan_native_target_rejected(self):self.o['orphan-target']=copy.deepcopy(self.o['BlindAssistTests']);self.reject()
 def test_duplicate_target_name_rejected(self):self.o['BlindAssistUITests'].update(name='BlindAssistTests',productName='BlindAssistTests',productType=m.TARGET_TYPES['BlindAssistTests']);self.reject()
 def test_non_unit_product_rejected(self):self.o['BlindAssistTests']['productType']=m.TARGET_TYPES['BlindAssist'];self.reject()
 def test_product_name_mismatch_rejected(self):self.o['BlindAssistTests']['productName']='Other';self.reject()
 def test_wrong_root_type_rejected(self):self.p['rootObject']='BlindAssistTests';self.reject()
 def test_second_project_rejected(self):self.o['second-project']=copy.deepcopy(self.o['project']);self.reject()
 def test_app_shared_unit_list_rejected(self):self.o['BlindAssist']['buildConfigurationList']='BlindAssistTests-list';self.reject()
 def test_project_shared_unit_list_rejected(self):self.o['project']['buildConfigurationList']='BlindAssistTests-list';self.reject()
 def test_ui_shared_unit_configuration_rejected(self):self.o['BlindAssistUITests-list']['buildConfigurations'][0]='BlindAssistTests-Debug';self.reject()
 def test_orphan_shared_unit_configuration_rejected(self):self.o['orphan-list']={'isa':'XCConfigurationList','buildConfigurations':['BlindAssistTests-Debug']};self.reject()
 def test_duplicate_unit_configuration_rejected(self):self.o['BlindAssistTests-list']['buildConfigurations']=['BlindAssistTests-Debug']*2;self.reject()
 def test_extra_unit_configuration_rejected(self):self.o['BlindAssistTests-list']['buildConfigurations'].append('BlindAssist-Debug');self.reject()
 def test_unknown_configuration_name_rejected(self):self.o['BlindAssistTests-Release']['name']='Profile';self.reject()
 def test_duplicate_configuration_name_rejected(self):self.o['BlindAssistTests-Release']['name']='Debug';self.reject()
 def test_wrong_configuration_type_rejected(self):self.o['BlindAssistTests-Debug']['isa']='PBXFileReference';self.reject()
 def test_external_unit_configuration_rejected(self):self.o['BlindAssistTests-Debug']['baseConfigurationReference']='unreviewed.xcconfig';self.reject()
 def test_host_target_association_rejected(self):self.o['project']['attributes']['TargetAttributes']['BlindAssistTests']['TestTargetID']='BlindAssistUITests';self.reject()
 def test_host_settings_rejected(self):self.setting()['TEST_HOST']='$(BUILT_PRODUCTS_DIR)/Other.app/Other';self.reject()
 def test_bundle_loader_rejected(self):self.setting()['BUNDLE_LOADER']='Other';self.reject()
 def test_all_existing_optional_prohibitions_in_any_json_string(self):
  for token in ['BLIND_MESH_CANDIDATE_DIAGNOSTICS','BLIND_DEVELOPER_CLOUD','opencv2','Model.mlmodelc','Model.mlpackage']:
   with self.subTest(token=token):self.o['file']={'isa':'PBXFileReference','path':token};self.reject()
 def test_raw_and_compiled_weight_paths_rejected_in_json(self):
  for token in ['Detector.mlmodel','face_detection_yunet_2023mar.onnx',
                'Detector.MLMODEL','Recognizer.OnNx','Detector.MLMODELC',
                'Detector.MLPACKAGE','OpenCV2.framework']:
   with self.subTest(token=token):
    self.o['file']={'isa':'PBXFileReference','path':'PrivateModels/'+token};self.reject()
 def test_raw_weight_file_types_rejected_in_json(self):
  self.o['file']={'isa':'PBXFileReference','path':'Detector','lastKnownFileType':'file.mlmodel'};self.reject()
 def test_raw_weight_tokens_rejected_in_json_keys(self):
  for token in ['Detector.mlmodel','Recognizer.onnx']:
   with self.subTest(token=token):self.o['file']={token:'value'};self.reject()
 def test_weight_tokens_rejected_in_raw_comments(self):
  for token in ['Detector.mlmodel','Recognizer.onnx','Detector.MLMODEL','Recognizer.OnNx']:
   with self.subTest(token=token):self.reject(raw=RAW+'// '+token)
 def test_model_adapter_source_names_without_weight_extensions_remain_allowed(self):
  self.o['file']={'isa':'PBXFileReference','path':'MLModelAdapter.swift'}
  self.o['notice']={'isa':'PBXFileReference','path':'ONNXRuntimeNotice.swift'}
  m.validate_project(self.p,RAW)
 def test_optional_key_rejected(self):self.o['file']={'BLIND_BACKEND':'value'};self.reject()
 def test_all_existing_raw_prohibitions_preserved_in_comments(self):
  for token in ['BLIND_OTHER','opencv2','x.mlmodelc','x.mlpackage']:
   with self.subTest(token=token):self.reject(raw=RAW+'// '+token)
 def test_raw_extra_oracle_occurrence_rejected(self):self.reject(raw=RAW+'// '+m.FLAG)
 def test_raw_missing_oracle_occurrence_rejected(self):self.reject(raw=RAW.splitlines()[0])
 def test_raw_project_budget(self):self.reject(raw='x'*(m.INPUT_LIMIT+1))
 def test_depth_budget(self):
  child=self.o['deep']={}
  for _ in range(m.DEPTH_LIMIT+1):child['next']={};child=child['next']
  self.reject()
 def test_node_budget(self):self.o['wide']={'values':[0]*m.NODE_LIMIT};self.reject()
 def test_non_scalar_json_type_rejected(self):self.o['other']={'value':1.25};self.reject()
 def test_json_duplicate_key_rejected(self):
  with self.assertRaises(ValueError):json.loads('{"objects":{},"objects":{}}',object_pairs_hook=m.unique_object)
 def invoke(self,project,raw=RAW):
  with tempfile.TemporaryDirectory() as folder:
   p=Path(folder);(p/'project.pbxproj').write_text(raw);(p/'project.json').write_text(project);out=io.StringIO()
   with contextlib.redirect_stdout(out):status=m.main([str(p/'project.pbxproj'),str(p/'project.json')])
   return status,json.loads(out.getvalue().split('=',1)[1])
 def test_cli_valid_receipt(self):
  status,receipt=self.invoke(json.dumps(self.p));self.assertEqual(status,0);self.assertEqual(receipt['status'],'passed');self.assertEqual(len(receipt['raw_project_sha256']),64)
 def test_cli_malformed_json_fail_closed(self):self.assertEqual(self.invoke('{')[0],1)
 def test_cli_failure_has_no_settings_or_error_payload(self):
  self.setting()['OTHER_SWIFT_FLAGS']='private arbitrary setting';status,receipt=self.invoke(json.dumps(self.p));self.assertEqual(status,1);self.assertNotIn('private',json.dumps(receipt));self.assertEqual(receipt['status'],'refused')
 def test_cli_duplicate_keys_fail_closed(self):self.assertEqual(self.invoke('{"objects":{},"objects":{}}')[0],1)
 def test_cli_oversized_json_fail_closed(self):self.assertEqual(self.invoke(' '*(m.INPUT_LIMIT+1))[0],1)
 def test_shared_script_uses_plutil_same_input_no_global_text_rewrite(self):
  text=(H/'native-apple.sh').read_text();self.assertIn('plutil -convert json -o "$out/default-project.json" "$project/project.pbxproj"',text);self.assertIn('python3 -B tools/ci/verify-default-project.py "$project/project.pbxproj" "$out/default-project.json"',text)
 def test_current_committed_raw_project_has_only_two_exact_oracle_tokens(self):
  text=(H.parents[1]/'ios/BlindAssist.xcodeproj/project.pbxproj').read_text();self.assertEqual(m.FORBIDDEN.findall(text),[m.FLAG,m.FLAG]);self.assertEqual(text.count('OTHER_SWIFT_FLAGS = "'+m.FLAG_VALUE+'";'),2)

if __name__=='__main__':unittest.main()
