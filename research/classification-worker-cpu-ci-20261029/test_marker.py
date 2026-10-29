#!/usr/bin/env python3
"""Execute exact shell filters with synthetic metadata; no native CPU claim."""
from pathlib import Path
import subprocess,tempfile,unittest
R=Path(__file__).resolve().parents[2];S=(R/'tools/ci/native-apple.sh').read_text()
UUID='12345678-1234-1234-1234-123456789ABC'
CPU=f'CLASSIFICATION_WORKER_CPU id={UUID} worker_begin_ms=0 lane=ingress83 worker_wall_ms=23 worker_cpu_us=100 worker_pair_valid=true build_wall_ms=20 build_cpu_us=90 build_pair_valid=true route_wall_ms=1 route_cpu_us=1 route_pair_valid=true retired=false native_failed=false records=12'
def run(lines,prefix='CLASSIFICATION_WORKER_CPU '):
 vars='\n'.join(x.strip().replace('local ','',1) for x in S.splitlines() if x.strip().startswith(('local stage=','local cpuNumber=')))
 command=next(x.strip() for x in S.splitlines() if 'grep -E "^'+prefix in x)
 with tempfile.TemporaryDirectory() as d:
  Path(d,'unit.log').write_text('\n'.join(lines)+'\n')
  return subprocess.run(['bash','-c',vars+'\nout="$1"; label=unit\n'+command,'test',d],check=True,capture_output=True,text=True).stdout.splitlines()
class Marker(unittest.TestCase):
 def test_valid_lanes(self):
  for lane in ['ingress83','runtime75']:
   x=CPU.replace('ingress83',lane);self.assertEqual(run([x]),[x])
 def test_unavailable(self):
  x=CPU.replace('worker_begin_ms=0','worker_begin_ms=-1').replace('worker_cpu_us=100','worker_cpu_us=-1').replace('worker_pair_valid=true','worker_pair_valid=false');self.assertEqual(run([x]),[x])
 def test_reject_extra_or_malformed(self):
  for x in [CPU+' secret=abc','prefix '+CPU,CPU.replace('lane=ingress83','lane=room'),CPU.replace('worker_wall_ms=23','worker_wall_ms=-2'),CPU.replace('retired=false','retired=unknown'),CPU.replace('records=12','records=65'),CPU.replace('records=12','records=-1'),CPU.replace(UUID,'private',1)]:
   with self.subTest(x=x):self.assertEqual(run([x]),[])
 def test_line_bound(self):self.assertEqual(len(run([CPU]*80)),64)
 def test_char_bound(self):
  x=CPU.replace('worker_cpu_us=100','worker_cpu_us='+'9'*2100);self.assertEqual(len(run([x])[0]),2000)
 def test_old_stage_markers_accept_only_new_closed_stages(self):
  x=f'CLASSIFIED_QUERY_STAGE_RECEIPT id={UUID} event=waitFinished stages=workerFinished:5;requestRetired:6'
  self.assertEqual(run([x],'CLASSIFIED_QUERY_STAGE_RECEIPT '),[x]);self.assertEqual(run([x.replace('requestRetired','private')],'CLASSIFIED_QUERY_STAGE_RECEIPT '),[])
  y=f'CLASSIFICATION_INGRESS_TIMING query={UUID} runtime={UUID} event=waitFinished elapsed_ms=6 main_thread=false stages=workerFinished:5;requestRetired:6'
  self.assertEqual(run([y],'CLASSIFICATION_INGRESS_TIMING '),[y])
if __name__=='__main__':unittest.main()
