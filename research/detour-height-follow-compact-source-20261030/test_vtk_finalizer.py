#!/usr/bin/env python3
"""Execute only the exact worker's text finalizer AST with injected failures.
No native import, geometry execution, original artifact writes, or worker main call.
"""
import ast,json,pathlib,sys,tempfile,time,types,unittest
H=pathlib.Path(__file__).resolve().parent
class FinalizerTests(unittest.TestCase):
 def exercise(self,original,catalog_fail=False,pin_fail=False):
  module=ast.parse((H/'vtk_worker.py').read_text());main=next(n for n in module.body if isinstance(n,ast.FunctionDef)and n.name=='main');body=next(n.finalbody for n in main.body if isinstance(n,ast.Try)and n.finalbody)
  source='def simulate():\n try:\n  if original: raise ValueError("original worker failure")\n finally:\n'+''.join('  '+line+'\n'for stmt in body for line in ast.unparse(stmt).splitlines())
  with tempfile.TemporaryDirectory()as tmp:
   out=pathlib.Path(tmp);(out/'CONTACT_ENCODING.json').write_text('{}')
   summary={'status':'failed','error':'ValueError: original worker failure'}if original else{'status':'completed_full_route_diagnostic_only'}
   def encoded(x):
    if catalog_fail and 'triangles'in x:raise OSError('injected catalog serialization failure')
    return(json.dumps(x)+'\n').encode()
   def need(ok,message):
    if not ok:raise ValueError(message)
   def verify():
    if pin_fail:raise OSError('injected pin failure')
   env=dict(original=original,summary=summary,verify=verify,need=need,sha=lambda p:'hash',a=types.SimpleNamespace(output=out,height_events=out/'unused'),height_sha='hash',catalog={},encoded=encoded,payload=1,MAX_BYTES=64*1024**2,count=17,queries=18,triangles=99,time=time,began=time.monotonic(),sys=sys)
   exec(compile(source,'exact-worker-finalizer-only','exec'),env)
   with self.assertRaises((ValueError,RuntimeError))as caught:env['simulate']()
   saved=json.loads((out/'SUMMARY.json').read_text());self.assertEqual(saved['status'],'failed');self.assertEqual(saved['records'],17)
   if original:self.assertEqual(saved['error'],'ValueError: original worker failure');self.assertIsInstance(caught.exception,ValueError)
   else:self.assertIn('Finalization failed',saved['error'])
   if catalog_fail:self.assertFalse(saved['catalogWritten']);self.assertTrue(saved['finalizationErrors'])
   if pin_fail:self.assertIn('injected pin failure',saved['finalizationErrors'][0])
 def test_catalog_failure_preserves_original(self):self.exercise(True,catalog_fail=True)
 def test_catalog_failure_cannot_report_success(self):self.exercise(False,catalog_fail=True)
 def test_pin_failure_preserves_original(self):self.exercise(True,pin_fail=True)
 def test_original_failure_catalog_written(self):self.exercise(True)
if __name__=='__main__':unittest.main()
