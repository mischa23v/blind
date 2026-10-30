"""Reproduce bounded public/synthetic log receipts; no execution/network calls.

All six original inputs must exist and match their pinned size/SHA-256 before
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
EXPECTED_INPUTS = [{'revision': '457c3f3', 'job': 'classified', 'job_id': 123871783536, 'path': 'apple-candidate-457c3f3/classified-job.log', 'bytes': 56119, 'sha256': '61c2a524b2a03769eb1bf346a2b2ed8662a62973bca7e1f79fed7818d06d7b4b'}, {'revision': '457c3f3', 'job': 'native', 'job_id': 123871783209, 'path': 'apple-candidate-457c3f3/native-job.log', 'bytes': 635648, 'sha256': '81a8c64bd762543e23adf663bc58569d7818e31d1730fc005db5df2afdccbe9f'}, {'revision': '457c3f3', 'job': 'seated', 'job_id': 123871783531, 'path': 'apple-candidate-457c3f3/seated-job.log', 'bytes': 73637, 'sha256': 'f1c2aeb2df6d3f2e33769ecebd50abc74c6caec2fffc4a1418bca05a2f9cc3d5'}, {'revision': 'b55cf93', 'job': 'classified', 'job_id': 123883432485, 'path': 'apple-candidate-b55cf93/classified-job.log', 'bytes': 76234, 'sha256': '1b4bc037fdf8b7eac2d58c6dc9cf2bfbe6f4a989250ab4b82f7e0d9bfa873237'}, {'revision': 'b55cf93', 'job': 'native', 'job_id': 123883432346, 'path': 'apple-candidate-b55cf93/native-job.log', 'bytes': 616619, 'sha256': 'c7d6f2a759459c4c6dedb535e504371f8935e2b39c5de306ace8045a27453271'}, {'revision': 'b55cf93', 'job': 'seated', 'job_id': 123883432048, 'path': 'apple-candidate-b55cf93/seated-job.log', 'bytes': 80523, 'sha256': 'c8e30f7248ef1bb66813769e8faea28937ba9c0db4b83ca63f000b1ae46b903e'}]


def load_inputs(root):
    expected = {item['path'] for item in EXPECTED_INPUTS}
    observed = {
        str(path.relative_to(root))
        for revision in ('457c3f3', 'b55cf93')
        for path in (root / ('apple-candidate-' + revision)).glob('*-job.log')
    }
    if observed != expected:
        raise ValueError('exact six log paths required; missing=' +
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
    if len(loaded) != 6:
        raise ValueError('exact six validated inputs required')
    return loaded

SUMMARY_FIELDS={'schema','status','complete','source_verified','source_commit','expected_commit','executed','passed','failed','skipped','case_count','case_records_in_input','counts','aggregate_counts_match','totalTestCount','passedTests','failedTests','skippedTests','expectedFailures','commandExit','exit_code','swift_test_exit_code','log_writer_exit_code','ios_session_fixtures_excluded','source_clean_before_and_after','swift_testing_zero_suite_not_counted'}

def parse_inputs(inputs):
    result={'schema':1,'scope':'Existing public/synthetic Apple CI evidence only; no physical-device or live-guidance acceptance','jobs':[]}
    for item, raw in inputs:
      revision=item['revision'];job_name=item['job']
      lines=[re.sub(r'^\ufeff?\d{4}-\d\d-\d\dT[^ ]+ ', '',x) for x in raw.decode('utf-8-sig').splitlines()]
      job={'revision':revision,'job':job_name,'job_id':item['job_id'],'input_log':item['path'],'input_sha256':hashlib.sha256(raw).hexdigest(),'input_bytes':len(raw),'receipts':[]}
      cases=collections.defaultdict(set);assertions=set();phase=[];unit_reports=[]
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
        if job_name=='seated':assertions.add((Path(d['location']).name,d['class']+'/'+d['case'],kind))
      if not all(len(v)==1 for v in cases.values()):raise ValueError('contradictory case status')
      job['direct_distinct_terminal_case_records']=[{'identifier':k,'status':next(iter(v))} for k,v in sorted(cases.items())]
      job['direct_terminal_status_counts']=dict(collections.Counter(x['status'] for x in job['direct_distinct_terminal_case_records']))
      if phase:job['distinct_phase_records']=phase
      if assertions:job['distinct_assertion_records']=[{'source':a,'identifier':b,'category':c} for a,b,c in sorted(assertions)]
      if unit_reports:
       unit=unit_reports[-1];job['unit_verified_summary']={k:v for k,v in unit.items() if k in SUMMARY_FIELDS}
       job['unit_nonpassing_cases']=[x for x in unit['cases'] if x['result']!='Passed']
      result['jobs'].append(job)

    if len(result['jobs']) != 6:
        raise ValueError('six parsed jobs required')
    encoded = (json.dumps(result, indent=2) + '\n').encode()
    if len(encoded) >= MAX_OUTPUT_BYTES:
        raise ValueError('output exceeds bound')
    return encoded


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input-root', required=True, type=Path,
                        help='directory containing the two apple-candidate-* log directories')
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
                      'sha256': hashlib.sha256(encoded).hexdigest(), 'jobs': 6}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
