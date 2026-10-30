"""Reproduce bounded public/synthetic log receipts; no execution/network calls.

All three source-561 inputs must exist and match their pinned size/SHA-256 before
parsing. The CLI requires both paths and atomically writes only a complete result.
"""
import argparse
import collections
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

MAX_LOG_BYTES = 4 * 1024 * 1024
MAX_OUTPUT_BYTES = 128 * 1024
EXPECTED_INPUTS = [{'revision': '561532e', 'job': 'classified', 'job_id': 123894584687, 'path': 'apple-candidate-561532e/classified-job.log', 'bytes': 78465, 'sha256': '5e281a9df75deec711070f7deba8b2ce47600ad1f5f0af418fcc297c4d751c55'}, {'revision': '561532e', 'job': 'native', 'job_id': 123894584882, 'path': 'apple-candidate-561532e/native-job.log', 'bytes': 636541, 'sha256': 'e20305b5df5a8db89f7f84d7887a4ff1155becc646c00d5097c4dae6f781a3de'}, {'revision': '561532e', 'job': 'seated', 'job_id': 123894584466, 'path': 'apple-candidate-561532e/seated-job.log', 'bytes': 84241, 'sha256': 'e58a90f70503dd5cb3ed7e0f98aaf4cc8168a9e4d416a72f57bf37a64f377f77'}]


def load_inputs(root):
    expected = {item['path'] for item in EXPECTED_INPUTS}
    # Read only the three fixed inputs; separate room-mesh/ingress logs are not inputs.
    observed = {item['path'] for item in EXPECTED_INPUTS if (root / item['path']).exists()}
    if observed != expected:
        raise ValueError('exact three log paths required; missing=' +
                         repr(sorted(expected - observed)) + '; extra=' +
                         repr(sorted(observed - expected)))
    loaded = []
    for item in EXPECTED_INPUTS:
        path = root / item['path']
        if path.is_symlink() or not path.is_file():
            raise ValueError('regular nonsymlink log required: ' + item['path'])
        size = path.stat().st_size
        if size != item['bytes'] or size > MAX_LOG_BYTES:
            raise ValueError('pinned input size mismatch: ' + item['path'])
        with path.open('rb') as stream:
            raw = stream.read(MAX_LOG_BYTES + 1)
        if len(raw) != item['bytes'] or hashlib.sha256(raw).hexdigest() != item['sha256']:
            raise ValueError('pinned input hash mismatch: ' + item['path'])
        loaded.append((item, raw))
    if len(loaded) != 3:
        raise ValueError('exact three validated inputs required')
    return loaded

SUMMARY_FIELDS={'schema','status','complete','source_verified','source_commit','expected_commit','executed','passed','failed','skipped','case_count','case_records_in_input','counts','aggregate_counts_match','totalTestCount','passedTests','failedTests','skippedTests','expectedFailures','commandExit','exit_code','swift_test_exit_code','log_writer_exit_code','ios_session_fixtures_excluded','source_clean_before_and_after','swift_testing_zero_suite_not_counted'}

def parse_inputs(inputs):
    result={'schema':1,'scope':'Existing public/synthetic Apple CI evidence only; no physical-device or live-guidance acceptance','jobs':[]}
    for item, raw in inputs:
      revision=item['revision'];job_name=item['job']
      lines=[re.sub(r'^\ufeff?\d{4}-\d\d-\d\dT[^ ]+ ', '',x) for x in raw.decode('utf-8-sig').splitlines()]
      job={'revision':revision,'job':job_name,'job_id':item['job_id'],'input_log':item['path'],'input_sha256':hashlib.sha256(raw).hexdigest(),'input_bytes':len(raw),'receipts':[]}
      cases=collections.defaultdict(set);assertions=set();phase=[];source_records=[];worker_records=[];aggregate_lines=set();unit_reports=[]
      for line in lines:
       if line.startswith('BLIND_CI_JOB='):
        job['ci_job']=json.loads(line.split('=',1)[1]);job['url']=f"https://github.com/mischa23v/blind/actions/runs/{job['ci_job']['run_id']}/job/{job['job_id']}"
       if line.startswith('BLIND_CI_RECEIPT='):
        value=json.loads(line.split('=',1)[1]);meta=value.get('metadata',{})
        job['receipts'].append({**{k:v for k,v in value.items() if k!='metadata'},'metadata':{k:v for k,v in meta.items() if k in SUMMARY_FIELDS}})
       if line.startswith('NATIVE_UNIT_CASE_STATUSES='):
        value=json.loads(line.split('=',1)[1]);unit_reports.append(value)
       if line.startswith('SEATED_CANDIDATE_TIMING_SUMMARY='):job['timing_summary']=json.loads(line.split('=',1)[1])
       if line.startswith('SEATED_CANDIDATE_PHASE ') and line not in phase:phase.append(line)
       if line.startswith('SEATED_CANDIDATE_SOURCE ') and line not in source_records:source_records.append(line)
       if line.startswith('SEATED_CANDIDATE_WORKER ') and line not in worker_records:worker_records.append(line)
       if re.fullmatch(r'\s*Executed (?:12|58|1463) tests, with .+ seconds',line):aggregate_lines.add(line.strip())
       match=re.fullmatch(r"Test Case '-\[(?:[\w]+\.)?([\w]+) ([\w]+)\]' (passed|failed|skipped) \([^)]*\)\.",line)
       if match:cases[match[1]+'/'+match[2]].add(match[3])
       # Deduplicate repeated grep/tail presentations of the same assertion. Retain
       # only source location, public fixture identity and assertion category.
       match=re.search(r"(?P<location>(?:[\w/.-]+\.swift:\d+|<unknown>:0)): error: -\[(?:[\w]+\.)?(?P<class>\w+) (?P<case>test\w+)\] : (?P<detail>.*)",line)
       if match:
        d=match.groupdict();kind=d['detail'].split(':',1)[0].split(' - ',1)[0]
        kind=re.sub(r'\([^)]*\)', '',kind)
        if 'Asynchronous wait failed' in kind:kind='Asynchronous wait failed'
        elif 'XCTUnwrap failed' in kind:kind='XCTUnwrap failed'
        elif 'XCTAssert' in kind:kind=kind.split(' failed',1)[0]+' failed'
        elif 'Dynamic Type' in kind:kind=d['detail']
        if job_name=='seated' or d['class'] in {'LaunchTests','SavedRoomRouteDiagnosticAppleTests','SavedRoomRouteJourneyAppleTests'}:assertions.add((Path(d['location']).name,d['class']+'/'+d['case'],kind))
      if not all(len(v)==1 for v in cases.values()):raise ValueError('contradictory case status')
      job['direct_distinct_terminal_case_records']=[{'identifier':k,'status':next(iter(v))} for k,v in sorted(cases.items())]
      job['direct_terminal_status_counts']=dict(collections.Counter(x['status'] for x in job['direct_distinct_terminal_case_records']))
      if len(phase)>32 or len(source_records)>64 or len(worker_records)>32 or any(len(x.encode())>4096 for x in phase+source_records+worker_records):raise ValueError('timing record budget exceeded')
      if phase:job['distinct_phase_records']=phase
      if source_records:job['distinct_source_records']=source_records
      job['distinct_worker_records']=worker_records
      if aggregate_lines:job['selected_aggregate_lines']=sorted(aggregate_lines)
      if assertions:job['distinct_assertion_records']=[{'source':a,'identifier':b,'category':c} for a,b,c in sorted(assertions)]
      if unit_reports:
       unit=unit_reports[-1];job['unit_verified_summary']={k:v for k,v in unit.items() if k in SUMMARY_FIELDS}
       job['unit_nonpassing_cases']=[x for x in unit['cases'] if x['result']!='Passed']
       job['unit_tracked_group_cases']=[x for x in unit['cases'] if x['identifier'].startswith(('ClassificationIngressTests/','ClassifiedRoomMeshTests/','ObservedSceneRuntimeTests/'))]
      result['jobs'].append(job)

    if len(result['jobs']) != 3:
        raise ValueError('three parsed jobs required')
    encoded = (json.dumps(result, indent=2) + '\n').encode()
    if len(encoded) >= MAX_OUTPUT_BYTES:
        raise ValueError('output exceeds bound')
    return encoded


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input-root', required=True, type=Path,
                        help='directory containing the apple-candidate-561532e log directory')
    parser.add_argument('--output', required=True, type=Path,
                        help='explicit destination; use a separate temporary file for reproduction')
    args = parser.parse_args(argv)
    temporary = None
    try:
        root = args.input_root.resolve(strict=True)
        if not root.is_dir():
            raise ValueError('input root must be a directory')
        output = args.output.absolute()
        if output.is_symlink() or output.resolve() in {(root / x['path']).resolve() for x in EXPECTED_INPUTS}:
            raise ValueError('output must not alias an input or be a symlink')
        # Validate every input and build the whole receipt before touching output.
        encoded = parse_inputs(load_inputs(root))
        with tempfile.NamedTemporaryFile(prefix='.' + output.name + '.',
                                         dir=output.parent, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(encoded)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, output)
        temporary = None
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, 'No receipt written: ' + str(error) + '\n')
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print(json.dumps({'output': str(output), 'bytes': len(encoded),
                      'sha256': hashlib.sha256(encoded).hexdigest(), 'jobs': 3}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
