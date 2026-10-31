#!/usr/bin/env python3
"""Run actual shell whitelist against bounded synthetic marker mutations."""
from pathlib import Path
import subprocess,tempfile,unittest
R=Path(__file__).resolve().parents[2]
S=(R/'tools/ci/native-apple.sh').read_text()
STAGE=next(x.strip() for x in S.splitlines() if x.strip().startswith('local stage=' )).replace('local stage=', 'stage=',1)
LINE=next(x.strip() for x in S.splitlines() if 'grep -E "^CLASSIFICATION_INGRESS_TIMING ' in x)
UUID='12345678-1234-1234-1234-123456789ABC'
GOOD=f'CLASSIFICATION_INGRESS_TIMING query={UUID} runtime={UUID} event=waitFinished elapsed_ms=10 main_thread=false stages=requestEnqueued:0;workerStarted:2'
def run(lines):
 with tempfile.TemporaryDirectory() as d:
  Path(d,'unit.log').write_text('\n'.join(lines)+'\n')
  return subprocess.run(['bash','-c',STAGE+'\nout="$1"; label=unit\n'+LINE,'test',d],check=True,capture_output=True,text=True).stdout.splitlines()
class Markers(unittest.TestCase):
 def test_valid(self):self.assertEqual(run([GOOD]),[GOOD])
 def test_empty_submitted(self):
  x=GOOD.split(' stages=')[0].replace('waitFinished','submitted')+' stages='
  self.assertEqual(run([x]),[x])
 def test_false_text(self):
  for x in [GOOD+' private=abc',GOOD.replace('workerStarted','roomName'),GOOD.replace('false','unknown'),GOOD.replace('elapsed_ms=10','elapsed_ms=-1'),GOOD.replace('waitFinished','callback'),GOOD.replace(UUID,'secret',1),'prefix '+GOOD]:
   with self.subTest(x=x):self.assertEqual(run([x]),[])
 def test_line_bound(self):self.assertEqual(len(run([GOOD]*90)),80)
 def test_character_bound(self):self.assertEqual(len(run([GOOD+';workerStarted:1'*150])[0]),1800)
if __name__=='__main__':unittest.main()
