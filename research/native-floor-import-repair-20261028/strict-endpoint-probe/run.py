#!/usr/bin/env python3
"""Public Apple-host-only bounded compiler/runner; never edits production sources.
Requires a real collector-verified routing attachment and explicit INPUT_PINS.json.
No dependency installation/download, no parameter search, no retry-until-pass.
"""
import hashlib,json,os,pathlib,resource,subprocess,sys,time
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2]
OUT=pathlib.Path(os.environ['RUNNER_TEMP'])/'blind-strict-endpoint-probe';OUT.mkdir(parents=True,exist_ok=True)
START=time.monotonic();DEADLINE=START+300
receipt={'schema':1,'sourceCommit':os.environ.get('GITHUB_SHA'),'physicalAuthority':False,'appActivation':False,'status':'started','commands':[],'sourcePins':{}}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save():
 receipt['elapsedSeconds']=time.monotonic()-START
 (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
def limits():
 resource.setrlimit(resource.RLIMIT_CPU,(120,120));resource.setrlimit(resource.RLIMIT_FSIZE,(128*1024**2,128*1024**2))
def command(args,label,limit=90):
 timeout=min(limit,max(1,DEADLINE-time.monotonic()));before=time.monotonic()
 stdout=OUT/(label+'.stdout.txt');stderr=OUT/(label+'.stderr.txt');row={'label':label,'command':[str(x) for x in args],'timeoutSeconds':timeout}
 receipt['commands'].append(row);save()
 with stdout.open('wb') as out,stderr.open('wb') as err:
  try:
   p=subprocess.run([str(x) for x in args],cwd=ROOT,stdout=out,stderr=err,timeout=timeout,preexec_fn=limits,
                    env={**os.environ,'OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1'})
   row.update(exitCode=p.returncode,wallSeconds=time.monotonic()-before)
  except subprocess.TimeoutExpired:
   row.update(exitCode=None,timedOut=True,wallSeconds=time.monotonic()-before);save();raise
 for p in [stdout,stderr]:row[p.name]={'bytes':p.stat().st_size,'sha256':sha(p)}
 save()
 if row['exitCode']!=0:raise RuntimeError('command failed: '+label)
 return stdout.read_text().strip()
try:
 assert sys.platform=='darwin','Apple host required; no local Swift/Xcode execution'
 assert os.environ.get('GITHUB_REPOSITORY')=='mischa23v/blind'
 head=command(['git','rev-parse','HEAD'],'source-head');assert head==receipt['sourceCommit']
 command(['git','diff','--exit-code'],'tracked-source-clean')
 pins=json.loads((HERE/'SOURCE_PINS.json').read_text())
 for name,digest in pins['files'].items():
  p=ROOT/name;assert sha(p)==digest,('source pin mismatch',name)
 receipt['sourcePins']=pins['files'];save()
 inputs=json.loads((HERE/'INPUT_PINS.json').read_text())
 assert inputs['schema']=='blind.public-verified-contour-inputs.v1' and inputs['physicalAuthority'] is False
 assert inputs['sourceVerified'] is True and len(inputs['captureSourceCommit'])==40 and inputs['captureNativeRun']>0
 geometry=HERE/'PACKED_ROUTING_GEOMETRY.json';requests=HERE/'REQUESTS_49A.json'
 assert geometry.stat().st_size<=131072 and sha(geometry)==inputs['packedGeometrySHA256']
 assert sha(requests)=='e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51'
 receipt['inputPins']=inputs;receipt['requestSHA256']=sha(requests);save()
 sdk=command(['xcrun','--sdk','macosx','--show-sdk-path'],'sdk')
 version=command(['xcodebuild','-version'],'xcode-version');assert version.splitlines()[0]=='Xcode 27.0'
 command(['xcrun','swiftc','--version'],'swift-version')
 c=ROOT/'research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour'
 include=OUT/'include';include.mkdir(exist_ok=True)
 (include/'strict_probe.h').write_bytes((HERE/'strict_probe.h').read_bytes())
 (include/'module.modulemap').write_text('module StrictEndpointProbe { header "strict_probe.h" export * }\n')
 common=['xcrun','clang++','-std=c++14','-O1','-ffp-contract=off','-fno-rtti','-fno-exceptions','-fPIC','-isysroot',sdk,'-target','arm64-apple-macosx14.0','-I',c]
 for component in ['Recast','Detour','DetourCrowd']:common+=['-I',c/'upstream'/component/'Include']
 objects=[]
 for component in ['Recast','Detour','DetourCrowd']:
  for source in sorted((c/'upstream'/component/'Source').glob('*.cpp')):
   obj=OUT/(component+'-'+source.stem+'.o');command(common+['-c',source,'-o',obj],'compile-'+component+'-'+source.stem);objects.append(obj)
 original=(c/'blind_detour_exclusion.cpp').read_text();assert original.count('config.maxSimplificationError = .5f;')==1
 code=original+'\n'+(HERE/'association_appendix.cpp').read_text()
 generated=OUT/'adapter.cpp';generated.write_text(code);obj=OUT/'adapter.o'
 receipt['generatedAdapterSHA256']=sha(generated);save()
 command(common+['-c',generated,'-o',obj],'compile-adapter');objects.append(obj)
 library=OUT/'libstrictendpoint.a';command(['xcrun','ar','rcs',library]+objects,'archive')
 cabi=OUT/'strict-cabi-tests'
 command(common+['-I',c/'include',HERE/'cabi_tests.cpp',library,'-o',cabi],'cabi-tests-compile')
 command([cabi],'cabi-tests-run',30)
 binary=OUT/'strict-endpoint-probe' 
 command(['xcrun','swiftc','-j','1','-num-threads','1','-swift-version','5','-parse-as-library','-sdk',sdk,
  '-target','arm64-apple-macosx14.0','-I',include,'-Xcc','-I'+str(c/'include'),HERE/'main.swift',
  ROOT/'ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift',library,'-lc++','-o',binary],'swift-probe-compile',120)
 command([binary,geometry,requests,OUT/'RESULT.json'],'probe-run',120)
 data=json.loads((OUT/'RESULT.json').read_text());receipt['status']=data['status'];receipt['resultSHA256']=sha(OUT/'RESULT.json')
 # Large build products never become artifacts; only bounded text/JSON evidence.
 for p in OUT.iterdir():
  if p.suffix in ['.o','.a'] or p==binary or p==cabi:p.unlink()
 save();print(json.dumps({'status':receipt['status'],'resultSHA256':receipt['resultSHA256'],'physicalAuthority':False}))
except Exception as error:
 receipt['status']='failed-or-missing-verified-input';receipt['errorType']=type(error).__name__;receipt['error']=str(error)[:1000];save();raise
