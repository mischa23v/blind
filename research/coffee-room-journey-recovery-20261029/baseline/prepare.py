"""Prepare a new source-only Coffee replay. Never executes imported/native code."""
import argparse, hashlib, json, pathlib, stat, subprocess, zipfile
PIN='c79fbd33171f78608f9eb2a1484fbc9266e3a695'
def sha(b): return hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--repo',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);p.add_argument('--evidence',type=pathlib.Path,required=True);p.add_argument('--mesh',type=pathlib.Path,required=True);a=p.parse_args()
 assert not a.out.exists(), 'fresh directory required';a.out.mkdir(parents=True)
 def git(path):return subprocess.check_output(['git','show',PIN+':'+path],cwd=a.repo)
 manifest=json.loads(git('research/tools/measured-progress-and-coffee-v1/MANIFEST.json')); listed={r['path']:r for r in manifest['files']}; written={}
 def save(name,b):
  q=pathlib.PurePosixPath(name);assert not q.is_absolute() and '..' not in q.parts
  f=a.out/name;f.parent.mkdir(parents=True,exist_ok=True)
  with f.open('xb') as w:w.write(b)
  written[name]={'bytes':len(b),'sha256':sha(b)}
 # Keep historical expected outputs separate; do not unpack the bundled executable.
 wanted=['blind-coffee-native-topology/'+n for n in ['run.py','PROTOCOL.json','FROZEN.json','RESULT.json']]
 wanted+=['blind-coffee-source-readiness/ORIENTATION_AUDIT.json','blind-tabletop-exclusion-planner-66/BUILD_RECEIPT.json','blind-tabletop-exclusion-planner-66/License.txt','blind-tabletop-exclusion-planner-66/native_exclusion.py','blind-tabletop-exclusion-planner-66/blind_detour_exclusion.cpp','blind-tabletop-exclusion-planner-66/clearance_adapter.cpp','blind-clearance-centered-loop-55/planner.py','blind-split-candidate-game-03/body-margin-variants-07/native025/detour_engine.py']
 wanted += [x for x in listed if '/selected/' in x]
 for archive in [a.evidence,a.mesh]:
  with zipfile.ZipFile(archive) as z:
   for name in wanted:
    if name not in z.namelist():continue
    i=z.getinfo(name);r=listed[name];assert i.file_size==r['bytes'] and i.file_size<11000000 and not i.is_dir() and not stat.S_ISLNK(i.external_attr>>16)
    b=z.read(i);assert len(b)==r['bytes'] and sha(b)==r['sha256']
    dest=name
    if name.endswith('/FROZEN.json') or name.endswith('/RESULT.json'):dest='expected/'+name
    save(dest,b)
 assert all((a.out/('expected/'+x if x.endswith(('/FROZEN.json','/RESULT.json')) else x)).exists() for x in wanted)
 old=json.loads((a.out/'blind-tabletop-exclusion-planner-66/BUILD_RECEIPT.json').read_text())
 upstream='blind-split-candidate-game-03/body-margin-variants-07/native025/upstream/'
 paths=git_paths=subprocess.check_output(['git','ls-tree','-r','--name-only',PIN,'tools/navigation-recast/upstream'],cwd=a.repo,text=True).splitlines()
 total=0
 for path in paths:
  rel=path.removeprefix('tools/navigation-recast/upstream/')
  if not (rel.startswith(('Recast/Include/','Recast/Source/','Detour/Include/','Detour/Source/','DetourCrowd/Include/','DetourCrowd/Source/')) and rel.endswith(('.h','.cpp'))):continue
  b=git(path);total+=len(b);assert total<5*1024*1024
  save(upstream+rel,b)
 for oldpath,h in old['sourceSHA256'].items():
  if '/blind-split-candidate-game-03/' in oldpath:rel='blind-split-candidate-game-03/'+oldpath.split('/blind-split-candidate-game-03/',1)[1]
  elif '/blind-tabletop-exclusion-planner-66/' in oldpath:rel='blind-tabletop-exclusion-planner-66/'+oldpath.split('/blind-tabletop-exclusion-planner-66/',1)[1]
  else:raise ValueError('unknown old source prefix')
  assert sha((a.out/rel).read_bytes())==h,rel
 def remap(s):
  for marker in ['/blind-split-candidate-game-03/','/blind-tabletop-exclusion-planner-66/']:
   if marker in s:
    prefix='-I' if s.startswith('-I') else ''
    return prefix+str((a.out/(marker.strip('/')+'/'+s.split(marker,1)[1])).resolve())
  return s
 cmd=[remap(x) for x in old['command']]
 save('BUILD_COMMAND.json',(json.dumps(cmd,indent=2)+'\n').encode())
 save('PREPARED.json',(json.dumps({'repositoryRevision':PIN,'upstreamCommit':'9f4ce64458dfae86e1239c525ddc219c4e9e06f1','sourceFiles':written,'upstreamBytes':total,'historicalSourcesMatch':True,'nativeExecuted':False,'frameContract':'Original OBJ unchanged; candidate Y-up only; no camera alignment or metric calibration claim'},indent=2)+'\n').encode())
 print(json.dumps({'out':str(a.out),'files':len(written),'upstreamBytes':total,'nativeExecuted':False}))
if __name__=='__main__':main()
