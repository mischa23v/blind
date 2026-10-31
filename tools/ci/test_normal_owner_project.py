"""Portable generated-target linkage controls, not an Apple compile/link result."""
import re,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
FILE='NormalOwnerMeshConnectionTests.swift'
def require(x):
 if not x:raise ValueError('normal-owner project ownership')
def validate(project):
 objects=dict(re.findall(r'^([A-F0-9]{24}) = \{ (.+) \};$',project,re.M))
 targets={re.search(r'name = (\w+);',v)[1]:v for v in objects.values() if 'isa = PBXNativeTarget;' in v}
 require(set(targets)=={'BlindAssist','BlindAssistTests','BlindAssistUITests'})
 def entries(body,key):return list(filter(None,re.search(key+r' = \(([^)]*)\)',body)[1].split(',')))
 def products(name):
  body=targets[name];ids=entries(body,'packageProductDependencies') if 'packageProductDependencies' in body else []
  require(len(ids)==len(set(ids)))
  return {re.search(r'productName = (\w+);',objects[i])[1]:i for i in ids}
 app=products('BlindAssist');unit=products('BlindAssistTests');ui=products('BlindAssistUITests')
 require(set(app)=={'BlindCore','BlindMemory','MeshCandidateIngress83','BlindRoomMesh','LiveMeshClassifiedBench','MeshSnapshot82','MeshBufferDecoder81'})
 require(set(unit)=={'BlindCore','BlindMemory','GRDB','MeshCandidateIngress83','BlindRoomMesh','LiveMeshClassifiedBench','MeshSnapshot82','MeshBufferDecoder81'})
 require(not ({'MeshSnapshot82','MeshBufferDecoder81'}&set(ui)))
 for name in ['MeshSnapshot82','MeshBufferDecoder81']:
  require(app[name]!=unit[name])
  pkg=lambda i:re.search(r'package = ([A-F0-9]{24});',objects[i])[1]
  require(pkg(app[name])==pkg(unit[name]))
  for target,product in [('BlindAssist',app[name]),('BlindAssistTests',unit[name])]:
   frameworks=[objects[i] for i in entries(targets[target],'buildPhases') if 'isa = PBXFrameworksBuildPhase;' in objects[i]]
   require(len(frameworks)==1)
   links=entries(frameworks[0],'files');require(len(links)==len(set(links)))
   require(sum(f'productRef = {product};' in objects[i] for i in links)==1)
 refs=[i for i,v in objects.items() if 'isa = PBXFileReference;' in v and f'path = "BlindAssistTests/{FILE}";' in v];require(len(refs)==1)
 builds=[i for i,v in objects.items() if 'isa = PBXBuildFile;' in v and f'fileRef = {refs[0]};' in v];require(len(builds)==1)
 owners=[]
 for name,body in targets.items():
  for phase in entries(body,'buildPhases'):
   if 'isa = PBXSourcesBuildPhase;' in objects[phase] and builds[0] in entries(objects[phase],'files'):owners.append(name)
 require(owners==['BlindAssistTests'])
 for marker in ['BLIND_MESH_CANDIDATE_DIAGNOSTICS','BLIND_J01','BLIND_FOUNDATION_MODELS_V2','.onnx','.mlmodel']:
  require(marker not in project)
 require(project.count('OTHER_SWIFT_FLAGS = "$(inherited) -D BLIND_COLLISION_ORACLE_TESTS"')==2)
 return objects,app,unit,builds[0]
class Tests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.project=(ROOT/'ios/BlindAssist.xcodeproj/project.pbxproj').read_text()
 def test_current_default_linkage_and_unit_membership(self):validate(self.project)
 def mutate_object(self,identity,old,new):
  line=next(x for x in self.project.splitlines() if x.startswith(identity+' = '));require(old in line)
  return self.project.replace(line,line.replace(old,new,1))
 def test_each_app_product_missing_refused(self):
  objects,app,_,_=validate(self.project)
  target=next(i for i,v in objects.items() if 'isa = PBXNativeTarget;' in v and 'name = BlindAssist;' in v)
  for name in ['MeshSnapshot82','MeshBufferDecoder81']:
   with self.subTest(name=name),self.assertRaises(ValueError):validate(self.mutate_object(target,app[name]+',',''))
 def test_each_app_framework_missing_refused(self):
  objects,app,_,_=validate(self.project)
  framework=next(i for i,v in objects.items() if 'isa = PBXFrameworksBuildPhase;' in v and any(f'productRef = {app["MeshSnapshot82"]};' in objects.get(x,'') for x in re.findall('[A-F0-9]{24}',v)))
  for name in ['MeshSnapshot82','MeshBufferDecoder81']:
   build=next(i for i,v in objects.items() if f'productRef = {app[name]};' in v)
   with self.subTest(name=name),self.assertRaises(ValueError):validate(self.mutate_object(framework,build+',',''))
 def test_wrong_app_product_package_refused(self):
  objects,app,unit,_=validate(self.project);old=re.search(r'package = ([A-F0-9]{24});',objects[app['MeshSnapshot82']])[1];wrong=re.search(r'package = ([A-F0-9]{24});',objects[app['MeshBufferDecoder81']])[1]
  with self.assertRaises(ValueError):validate(self.mutate_object(app['MeshSnapshot82'],old,wrong))
 def test_missing_unit_product_refused(self):
  objects,_,unit,_=validate(self.project);target=next(i for i,v in objects.items() if 'isa = PBXNativeTarget;' in v and 'name = BlindAssistTests;' in v)
  with self.assertRaises(ValueError):validate(self.mutate_object(target,unit['MeshSnapshot82']+',',''))
 def test_no_new_package_refs(self):
  self.assertEqual(self.project.count('relativePath = "../research/arkit-mesh-adapter-82"'),1)
  self.assertEqual(self.project.count('relativePath = "../research/native-mesh-decoder-81"'),1)
  self.assertEqual(self.project.count('isa = XCRemoteSwiftPackageReference;'),1)
 def test_hosted_file_cannot_enter_app_source(self):
  objects,_,_,build=validate(self.project);target=next(v for v in objects.values() if 'isa = PBXNativeTarget;' in v and 'name = BlindAssist;' in v);phases=re.search(r'buildPhases = \(([^)]*)\)',target)[1].split(',');sources=next(i for i in phases if i and 'isa = PBXSourcesBuildPhase;' in objects[i])
  with self.assertRaises(ValueError):validate(self.mutate_object(sources,'files = (','files = ('+build+','))
 def test_hosted_file_cannot_leave_unit_source(self):
  objects,_,_,build=validate(self.project);sources=next(i for i,v in objects.items() if 'isa = PBXSourcesBuildPhase;' in v and build in v)
  with self.assertRaises(ValueError):validate(self.mutate_object(sources,build+',',''))
 def test_default_opt_in_flags_refused(self):
  for flag in ['BLIND_MESH_CANDIDATE_DIAGNOSTICS','BLIND_J01','BLIND_FOUNDATION_MODELS_V2']:
   with self.subTest(flag=flag),self.assertRaises(ValueError):validate(self.project+'\n// '+flag)
 def test_unit_oracle_flag_count_unchanged(self):
  with self.assertRaises(ValueError):validate(self.project.replace('OTHER_SWIFT_FLAGS = "$(inherited) -D BLIND_COLLISION_ORACLE_TESTS"','OTHER_SWIFT_FLAGS = "$(inherited)"',1))
if __name__=='__main__':unittest.main()
