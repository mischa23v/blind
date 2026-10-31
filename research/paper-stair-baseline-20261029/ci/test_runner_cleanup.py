"""Exercise the exact cleanup function without executing the native runner entry point."""
import ast,os,selectors,signal,subprocess,sys,unittest
from pathlib import Path
source=ast.parse((Path(__file__).parent/'run.py').read_text())
fn=next(n for n in source.body if isinstance(n,ast.FunctionDef) and n.name=='stop_process_group')
ns={'os':os,'signal':signal};exec(compile(ast.Module(body=[fn],type_ignores=[]),'run.py','exec'),ns)
class CleanupTests(unittest.TestCase):
 def test_exited_parent_descendant_holding_pipe_is_retired(self):
  code='import subprocess,sys; subprocess.Popen([sys.executable,"-c","import time;time.sleep(10)"]); print("spawned",flush=True)'
  p=subprocess.Popen([sys.executable,'-c',code],stdout=subprocess.PIPE,start_new_session=True)
  try:
   self.assertEqual(p.stdout.readline(),b'spawned\n');p.wait(timeout=3)
   ns['stop_process_group'](p)
   with selectors.DefaultSelector() as s:
    s.register(p.stdout,selectors.EVENT_READ);self.assertTrue(s.select(3));self.assertEqual(os.read(p.stdout.fileno(),1024),b'')
  finally:ns['stop_process_group'](p);p.stdout.close()
 def test_completed_group_cleanup_is_idempotent(self):
  p=subprocess.Popen([sys.executable,'-c','pass'],start_new_session=True);p.wait(timeout=3)
  ns['stop_process_group'](p);ns['stop_process_group'](p)
if __name__=='__main__':unittest.main()
