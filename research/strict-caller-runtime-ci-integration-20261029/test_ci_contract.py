import ast, pathlib,unittest
R=pathlib.Path(__file__).resolve().parents[2]
SOURCE=R/'research/mesh-candidate-ingress-83/apple/ci.py'
MARKER='STRICT_ENDPOINT_INGRESS_RESULT: 25 caller-policy checks passed; original83 comparator retained; no physical authority'
def check_marker(log):
 tree=ast.parse(SOURCE.read_text()); main=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='main'); nodes=[]
 for n in ast.walk(main):
  if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='strict_marker' for t in n.targets):nodes.append(n)
  elif isinstance(n,ast.If) and isinstance(n.test,ast.Compare) and 'strict_marker' in ast.unparse(n.test):nodes.append(n)
 if len(nodes)!=2:raise ValueError('exact marker gate absent')
 exec(compile(ast.Module(body=nodes,type_ignores=[]),str(SOURCE),'exec'),{'fixture_log':log})
class MarkerTests(unittest.TestCase):
 def test_exact_marker(self):check_marker(MARKER+'\n')
 def test_missing(self):
  with self.assertRaises(ValueError):check_marker('RESULT: 83 stage83 real-runtime synthetic checks passed\n')
 def test_duplicate(self):
  with self.assertRaises(ValueError):check_marker((MARKER+'\n')*2)
 def test_wrong_count(self):
  with self.assertRaises(ValueError):check_marker(MARKER.replace('25','24'))
 def test_wrong_authority(self):
  with self.assertRaises(ValueError):check_marker(MARKER.replace('no physical authority','physical authority'))
 def test_valid_plus_wrong_count(self):
  with self.assertRaises(ValueError):check_marker(MARKER+'\n'+MARKER.replace('25','24'))
 def test_valid_plus_wrong_authority(self):
  with self.assertRaises(ValueError):check_marker(MARKER+'\n'+MARKER.replace('no physical authority','physical authority'))
if __name__=='__main__':unittest.main()
