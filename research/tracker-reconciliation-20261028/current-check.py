#!/usr/bin/env python3
"""Validate the dated tracker accounting, not live CI, Swift or device behavior."""
from pathlib import Path
import copy, hashlib, json, sys
HERE = Path(__file__).resolve().parent
EXPECTED_IDS = ['N01','N00','N02','N03','N04','N05','A01','P01','E01','E02','E03','E04','J01','J02','D01','F01']
HISTORICAL = {"historical_assisted_laps": "fdada46b2f8323aa72a54a0bb61cecf33ba72fbd0d69c88fe91bf6981b1e43ca", "matrix": "8468e09fa0bedfc85f0ad182830caa21d9a617fc46b4e8de9d4289ff1d804b20", "component_summary": "2a64bd21ecf9f8ea46098e421cc4e813afe1775639e6caf94480bb2eaada726e", "family_mapping": "885aa84ef0d453c9aa1c9f5840e6b582c9de0b88e01a3096b3e26f4200fa1107"}
def digest(v): return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def check(t):
 rows=t['workstreams'];by={r['id']:r for r in rows};c=t['current_checkpoint']
 assert [r['id'] for r in rows] == EXPECTED_IDS
 assert all(r['accepted_complete'] is False for r in rows)
 groups={k:sum(r['progress_group']==k for r in rows) for k in ['partial_implementation','evaluation_or_device','deferred']}
 assert groups=={'partial_implementation':13,'evaluation_or_device':2,'deferred':1}
 assert {r['id'] for r in rows if r['progress_group']=='evaluation_or_device'}=={'N05','D01'}
 assert by['F01']['state']=='DEFERRED_BY_USER' and by['F01']['progress_group']=='deferred'
 assert c['progress_groups']['accepted_complete']==0
 assert c['accepted_whole_journeys']=={'accepted':0,'required':400,'component_tests_are_not_journeys':True}
 assert c['physical_authority'] is False and c['child_trial_readiness'] is False
 for name,sha in HISTORICAL.items():assert digest(t[name])==sha,name
 def walk(key,active):
  assert key not in active
  for dep in by[key]['depends_on']:assert dep in by;walk(dep,active|{key})
 for key in by:walk(key,set())
 for row in rows:
  for field in ['current_source','current_testing','device_or_data_gate','next_test','current_owner']:assert row[field].strip(),(row['id'],field)
 assert c['published_source']['commit']=='ff0f50df695bfa48fd72697858c574fda653dc4e'
 assert c['published_source']['url'].endswith('/commit/'+c['published_source']['commit'])
 old=c['published_119_tests'];new=c['published_ff0_tests']
 assert old['core']=={'passed':1499,'failed':0,'skipped':1}
 assert old['memory']=={'passed':58,'failed':0}
 assert old['default_app_build']==old['diagnostics_app_build']=='failed'
 assert new['default_app_build']==new['diagnostics_app_build']=='passed'
 seated=new['seated'];assert [seated[k] for k in ['executed','passed','failed','skipped','command_exit']]==[21,13,8,0,65]
 assert seated['exact_source_verified'] and seated['exact_case_set_observed']
 assert seated['failure_records']==27 and seated['unexpected_failure_records']==2
 assert 'unavailable' in seated['strict_acceptance_receipt']
 assert new['full_hosted_units']=='failed_step_at_17:29:47Z; exact aggregate counts and causes not yet collected'
 assert new['overall_native_job']=='in_progress_at_checkpoint; focused seed-radius fixtures running and UI pending'
 assert new['classified']=={'passed':71,'failed':0,'ios_only_exclusions':5,'source_clean_before_after':True}
 assert new['native_run']=='https://github.com/mischa23v/blind/actions/runs/41096090593'
 assert old['native_run']=='https://github.com/mischa23v/blind/actions/runs/41093837152'
 assert c['reviewed_unpublished']['published'] is False
 assert c['reviewed_unpublished']['native_executed_for_candidate'] is False
 assert all(x['status']=='in_progress_not_accepted' for x in c['active_implementation'])
 assert len(c['active_implementation'])==3
 encoded=json.dumps(t)
 assert (chr(47)+'workspace'+chr(47)) not in encoded and ('coordination'+chr(47)) not in encoded
 return ['all 16 IDs retained','0 accepted workstreams and 0/400 whole journeys','13/2/1 groups not percentages',
  'historical laps/matrix/component/family data unchanged','dependency DAG preserved',
  'source/testing/device gates explicit','119 compile failure retained','ff0 exact seated failures retained',
  'failed unit step separate from running overall job','reviewed candidate not marked published/native-tested',
  'three active source slices not accepted','no internal workspace paths']

def negative_controls(t):
 mutations=[
  lambda x:x['workstreams'].pop(),
  lambda x:x['workstreams'][0].update(accepted_complete=True),
  lambda x:x['current_checkpoint']['accepted_whole_journeys'].update(accepted=1),
  lambda x:x['current_checkpoint']['published_119_tests'].update(default_app_build='passed'),
  lambda x:x['current_checkpoint']['published_ff0_tests']['seated'].update(failed=0),
  lambda x:x['current_checkpoint']['published_ff0_tests'].update(full_hosted_units='passed'),
  lambda x:x['current_checkpoint']['reviewed_unpublished'].update(published=True),
  lambda x:x['workstreams'][-1].update(state='ACTIVE'),
  lambda x:x['matrix'].update(arrivals=100),
 ]
 for mutate in mutations:
  altered=copy.deepcopy(t);mutate(altered)
  try:check(altered)
  except AssertionError:continue
  raise AssertionError('damaged tracker accepted')
 return len(mutations)
if __name__=='__main__':
 t=json.loads((HERE/'TRACKER.json').read_text());checks=check(t)
 result={'passed':True,'as_of':t['as_of'],'checks':checks,'rejected_mutations':negative_controls(t),
  'scope':'Saved source/evidence accounting only; no live CI query, native execution, phone accuracy or device acceptance.'}
 print(json.dumps(result,indent=2))
