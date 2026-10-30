"""Synthetic archive controls only; never opens public capture/holdout data."""
import importlib.util,pathlib,tempfile,tarfile,io,unittest
p=pathlib.Path(__file__).with_name('evaluate.py');s=importlib.util.spec_from_file_location('prepared_evaluator',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class ExtractionTests(unittest.TestCase):
 def make(self,root,items):
  p=root/'synthetic.tar.gz'
  with tarfile.open(p,'w:gz')as t:
   for name,data,kind in items:
    x=tarfile.TarInfo(name);x.size=len(data);x.type=kind;t.addfile(x,io.BytesIO(data)if kind==tarfile.REGTYPE else None)
  return p
 def run_case(self,items,expect_failure=False):
  names={n:f'room_datasets/coffee_room/iphone/long_capture/depth/{n}.png'for n in m.HOLD}
  with tempfile.TemporaryDirectory()as d:
   root=pathlib.Path(d);p=self.make(root,items(names));dest=root/'two'
   if expect_failure:
    with self.assertRaises(ValueError):m.extract_two(p,dest,names)
   else:
    out=m.extract_two(p,dest,names);self.assertEqual(len(out),2);self.assertEqual(sorted(x.name for x in dest.iterdir()),[n+'.png'for n in m.HOLD])
 def test_exact_two_only(self):self.run_case(lambda n:[('unrelated.bin',b'ignore',tarfile.REGTYPE)]+[(v,b'synthetic',tarfile.REGTYPE)for v in n.values()])
 def test_duplicate_refused(self):self.run_case(lambda n:[(next(iter(n.values())),b'x',tarfile.REGTYPE)]*2,True)
 def test_missing_refused(self):self.run_case(lambda n:[],True)
 def test_link_refused(self):self.run_case(lambda n:[(next(iter(n.values())),b'',tarfile.SYMTYPE)],True)
 def test_oversize_refused(self):self.run_case(lambda n:[(next(iter(n.values())),b'x'*(1024**2+1),tarfile.REGTYPE)],True)
if __name__=='__main__':unittest.main(verbosity=2)
