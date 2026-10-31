"""Stdlib-only regression for the exact Python -I terminal-import failure."""
import hashlib, importlib.util, pathlib, subprocess, sys, tempfile, types, unittest
H=pathlib.Path(__file__).resolve().parent
SOURCE=H.parent/'conference-body-source-20261029'
CONTRACT='f3f5a8bacaaee3f69e7ee51820ce9e848881d46636c5ee9610a772e59a4668ae'
SCHEDULE='eb6bee87b245d10fa7cb07d3a34e9dc4cc45a49e21f2b64440b6ec09bf83bdbd'
def load_guard():
    spec=importlib.util.spec_from_file_location('conference_fixed_guard',H/'run_aggregate_isolated.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

class IsolatedImportTests(unittest.TestCase):
    def test_isolated_mode_ignores_hostile_cwd_and_pythonpath(self):
        with tempfile.TemporaryDirectory() as td:
            for name in ('contracts.py','schedule_source.py'):
                pathlib.Path(td,name).write_text("raise RuntimeError('ambient import must not execute')\n")
            code=f"""import importlib.util,sys
spec=importlib.util.spec_from_file_location('guard',{str(H/'run_aggregate_isolated.py')!r})
guard=importlib.util.module_from_spec(spec);spec.loader.exec_module(guard)
c=guard.load_frozen_contracts({str(SOURCE)!r},{CONTRACT!r},{SCHEDULE!r})
assert sys.flags.isolated==1 and len(c.NAMES)==7 and callable(c.validate_receipt)
assert not any(x in sys.modules for x in ('numpy','vtk','scipy'))
print('ISOLATED_SOURCE_CONTRACT_LOADED')
"""
            result=subprocess.run([sys.executable,'-I','-c',code],cwd=td,
                env={'PYTHONPATH':td},capture_output=True,text=True,timeout=5)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(result.stdout,'ISOLATED_SOURCE_CONTRACT_LOADED\n')
    def test_loader_rejects_altered_source_bytes(self):
        with tempfile.TemporaryDirectory() as td:
            for name in ('contracts.py','schedule_source.py'):
                pathlib.Path(td,name).write_bytes((SOURCE/name).read_bytes())
            with pathlib.Path(td,'contracts.py').open('a') as f:f.write('# changed\n')
            with self.assertRaisesRegex(RuntimeError,'pin mismatch'):
                load_guard().load_frozen_contracts(td,CONTRACT,SCHEDULE)
    def test_loader_restores_existing_schedule_module(self):
        previous=sys.modules.get('schedule_source');sentinel=types.ModuleType('untrusted_sentinel')
        sys.modules['schedule_source']=sentinel
        try:
            c=load_guard().load_frozen_contracts(SOURCE,CONTRACT,SCHEDULE)
            self.assertIs(sys.modules['schedule_source'],sentinel)
            self.assertEqual(len(c.NAMES),7)
            self.assertEqual(c.make_schedule([[0,0,0],[.025,0,0]])['chain'][1],[.025,0,0])
        finally:
            if previous is None:sys.modules.pop('schedule_source',None)
            else:sys.modules['schedule_source']=previous

if __name__=='__main__':unittest.main(verbosity=2)
