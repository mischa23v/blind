#!/usr/bin/env python3
import json,pathlib,sys,hashlib,fnmatch
stage=pathlib.Path(sys.argv[1]); output=stage/'EXECUTION_SUMMARY.json';catalog={};runs=[]
for run in sorted((stage/'evidence').glob('run-*')):
 log=run/'swift-test.log';exitfile=run/'exit-code.txt'
 if log.exists():runs.append({'run':run.name,'exit_code':int(exitfile.read_text()) if exitfile.exists() else None,'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()})
 for f in sorted(run.glob('*.json')):
  if 'episode' not in f.name:continue
  value=json.loads(f.read_text())
  records=value if isinstance(value,list) else value.get('episodes',[value])
  for record in records:
   if 'id' not in record:continue
   status=record.get('status',record.get('actual_code_result','SEE_XCTEST_ASSERTIONS'))
   catalog[record['id']]={'id':record['id'],'status':status,'receipt':str(f.relative_to(stage)),'steps':len(record.get('steps',[])),'is_full_user_episode':False}
coverage_file=stage/'tests/scenarios/integrated/requirement-coverage.json'
if coverage_file.exists():
 coverage=json.loads(coverage_file.read_text())
 for family in coverage['families']:
  family['executed_family_specific_partial_records']=[x for x in catalog.values() if any(fnmatch.fnmatch(x['id'],p) for p in family['family_specific_partial_episode_patterns'])]
  family['executed_shared_prerequisite_records']=[x for x in catalog.values() if any(fnmatch.fnmatch(x['id'],p) for p in family['shared_prerequisite_episode_patterns'])]
 coverage_file.write_text(json.dumps(coverage,indent=2))
summary={'scope':'Unique traced CODE COMPONENT sequences across multiple source snapshots. NOT full user/model/device episodes, not independent empirical trials, not assertions counted as episodes. Repeated reruns deduplicated by ID; systematic matrices disclosed. Native regression tests with no full episode JSON remain separate.','unique_partial_code_sequences':len(catalog),'full_user_model_device_episodes_completed':0,'total_recorded_steps_latest_per_id':sum(x['steps'] for x in catalog.values()),'status_counts':{s:sum(x['status']==s for x in catalog.values()) for s in sorted(set(x['status'] for x in catalog.values()))},'runs':runs,'episodes':list(catalog.values()),'remaining_requirement':'400 genuine complete integrated episodes across53 families remain incomplete; planned obligations are not executed counts.'}
output.write_text(json.dumps(summary,indent=2));print(json.dumps({k:v for k,v in summary.items() if k not in ['episodes','runs']},indent=2))
