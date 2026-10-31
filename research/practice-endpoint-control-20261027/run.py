from pathlib import Path
import hashlib,json,os,subprocess,sys
SOURCE='fb879d235f38a3f0121b69b023e8ee14c0ded61c'
PINS={'ios/BlindAssistUITests/LaunchTests.swift':'7678df48b63dd78f3e8dabef81e7042dc821458db59749bcbc8ab585648de6e4',
'ios/BlindAssist/DashboardView.swift':'7c1ee284cb9b0a73ccc64dd18128a82d1864b40b5d234af71f6d1a5680b0ac86',
 'tools/ci/export-practice-layout-screenshots.py':'b8082d8704ff601017703e5f8b83a4600b05c73a15ec494ad9f68031e72ae9ca'}
def main():
 if len(sys.argv)!=2:raise SystemExit('Supply exact pinned source checkout')
 root=Path(sys.argv[1]).resolve();workspace=Path(os.environ['GITHUB_WORKSPACE']).resolve();here=Path(__file__).resolve().parent
 if root!=workspace/'pinned-practice-source' or here.is_relative_to(root):raise SystemExit('Require separate owned source checkout')
 def git(*args):return subprocess.check_output(['git','-C',str(root),*args],text=True,timeout=30).strip()
 if git('rev-parse','HEAD')!=SOURCE or git('status','--porcelain'):raise SystemExit('Exact clean source required')
 for path,sha in PINS.items():
  if hashlib.sha256((root/path).read_bytes()).hexdigest()!=sha:raise SystemExit('Pin mismatch: '+path)
 receipt={'source':SOURCE,'inputHashes':PINS,'productionEdits':False,'diagnosticFiles':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in here.glob('*.py')}}
 out=Path(os.environ['RUNNER_TEMP'])/'blind-practice-endpoint-provenance';out.mkdir(exist_ok=False)
 (out/'provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
 env=dict(os.environ);env['BLIND_ENDPOINT_SOURCE_ROOT']=str(root);env['GITHUB_SHA']=SOURCE
 code=subprocess.call([sys.executable,str(here/'runner.py')],cwd=root,env=env)
 receipt['exitCode']=code
 valid=False
 try:
  receipt['sourceStatusAfter']=git('status','--porcelain')
  # Never treat generated metadata as source-clean; validate its exact package pin.
  allowed='ios/BlindAssist.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
  valid=receipt['sourceStatusAfter'] in ('', '?? '+allowed)
  for path,sha in PINS.items():valid &= hashlib.sha256((root/path).read_bytes()).hexdigest()==sha
  lock=root/allowed
  if lock.exists():
   if lock.is_symlink() or lock.stat().st_size>16384:valid=False
   else:
    raw=lock.read_bytes(); data=json.loads(raw)
    if not isinstance(data,dict):raise ValueError("Generated lock root must be an object")
    expected={'identity':'grdb.swift','kind':'remoteSourceControl','location':'https://github.com/groue/GRDB.swift.git','state':{'revision':'b83108d10f42680d78f23fe4d4d80fc88dab3212','version':'7.11.1'}}
    valid &= data.get('version')==3 and data.get('pins')==[expected] and set(data)<= {'version','originHash','pins'}
    receipt['generatedLock']={'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'expectedPin':expected,'valid':bool(valid)}
 except (OSError, ValueError, subprocess.SubprocessError) as error:
  valid=False
  receipt['sourceIntegrityError']={'stage':'post-run-source-and-generated-lock','type':type(error).__name__}
 receipt['sourceIntegrityPassed']=bool(valid)
 if not valid:code=1
 receipt['finalExitCode']=code
 (out/'provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
 return code
if __name__=='__main__':sys.exit(main())
