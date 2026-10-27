import contextlib,importlib.util,io,json,os,signal,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('ci',Path(__file__).with_name('ci.py'))
ci=importlib.util.module_from_spec(spec);spec.loader.exec_module(ci)
class Diagnostics(unittest.TestCase):
 def run_case(self,script,timeout=2,fail=False):
  with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
   out=Path(directory).resolve()
   with contextlib.redirect_stdout(io.StringIO()):
    if fail:
     with self.assertRaises(RuntimeError):ci.run([sys.executable,'-c',script], 'case',out,timeout)
    else:ci.run([sys.executable,'-c',script], 'case',out,timeout)
   return json.loads((out/'case-receipt.json').read_text())
 def test_success_and_temp(self):
  r=self.run_case("import os,pathlib; p=pathlib.Path(os.environ['TMPDIR'])/'small'; p.write_bytes(b'x'*32)")
  self.assertEqual(r['exitCode'],0);self.assertTrue(r['scratchScanComplete'])
  self.assertTrue(any(x['path']=='tmp/small' for x in r['largestScratchFiles']))
  self.assertEqual((r['fileCapBytes'],r['scratchCapBytes'],r['cpuCapSeconds']),(128<<20,512<<20,300))
 def test_nonzero(self):
  r=self.run_case('raise SystemExit(7)',fail=True);self.assertEqual(r['exitCode'],7);self.assertIsNone(r['terminationSignal'])
 def test_file_size_signal(self):
  # Tiny test-only cap; no production cap change or large allocation.
  with patch.object(ci,'FILE_CAP',1024):
   r=self.run_case("import os,signal;signal.signal(signal.SIGXFSZ,signal.SIG_DFL);f=open(os.environ['TMPDIR']+'/limited','wb');f.write(b'x'*2048);f.flush()",fail=True)
  self.assertEqual(r['exitCode'],-signal.SIGXFSZ);self.assertTrue(r['fileSizeLimitSignal'])
  self.assertEqual(r['terminationSignal'],'SIGXFSZ')
  self.assertEqual(r['largestScratchFiles'][0]['bytes'],1024)
 def test_timeout(self):
  r=self.run_case('import time;time.sleep(2)',timeout=.02,fail=True);self.assertTrue(r['timedOut']);self.assertEqual(r['terminationSignal'],'SIGKILL')
 def test_scanner_no_symlinks(self):
  with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as d:
   out=Path(d);(out/'safe').write_bytes(b'x');(out/'link').symlink_to('/etc/passwd')
   r=ci.scratch_diagnostics(out);self.assertEqual(r['scratchBytesAfterCommand'],1)
   self.assertEqual(r['largestScratchFiles'],[{'path':'safe','bytes':1}])
 def test_caps_and_tail(self):
  with patch.object(ci,'SCRATCH_CAP',100):
   r=self.run_case("print('z'*12000)",fail=True)
  self.assertTrue(r['scratchCapExceeded']);self.assertLessEqual(len(r['logTail']),8192)
 def test_scan_error_fails_closed(self):
  original_scandir=os.scandir
  def deny_paths(path):
   if isinstance(path,Path):raise PermissionError
   return original_scandir(path)
  with patch.object(ci.os,'scandir',side_effect=deny_paths):
   r=self.run_case('pass',fail=True)
  self.assertFalse(r['scratchScanComplete']);self.assertEqual(r['exitCode'],0)
 def test_top_eight(self):
  with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as d:
   out=Path(d)
   for n in range(10):(out/str(n)).write_bytes(b'x'*n)
   r=ci.scratch_diagnostics(out)
   self.assertEqual(len(r['largestScratchFiles']),8)
   self.assertEqual([x['bytes'] for x in r['largestScratchFiles']],list(range(9,1,-1)))
 def test_cache_options(self):
  args=ci.build_cache_options(Path('/scratch'),'host')
  self.assertEqual(args[:4],['--cache-path','/scratch/swiftpm-cache','--manifest-cache','local'])
  self.assertNotIn('--disable-sandbox',args)
if __name__=='__main__':unittest.main()
