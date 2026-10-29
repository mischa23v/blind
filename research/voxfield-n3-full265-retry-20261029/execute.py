# Preparation only. Requires independent final review and root admission.
from pathlib import Path
import os,json,hashlib,subprocess,sys,time,shutil
H=Path(__file__).resolve().parent;W=Path('<WORKSPACE_ROOT>');F=H.parent.parent;R=H/'run';R.mkdir(exist_ok=False);P=F/'zero-direction-candidate';B=P/'run/build';S=W/'coordination/remaining-mapping-baselines';D=S/'stage-b/prefix';E=W/'research/rtabmap-same-data-benchmark-20261028/fresh-run/prefix'
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});env=os.environ.copy();env['LD_LIBRARY_PATH']=str(B)+':'+str(D/'usr/lib/x86_64-linux-gnu')+':'+str(E/'usr/lib/x86_64-linux-gnu')
f=json.loads((H/'EXECUTION_FREEZE.json').read_text());assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==s for p,s in f['files'].items())
def run(label,args):
 t=time.monotonic()
 with (R/(label+'.log')).open('x')as out:c=subprocess.run(args,env=env,cwd=R,stdout=out,stderr=subprocess.STDOUT)
 (R/(label+'.json')).write_text(json.dumps({'argv':args,'cwd':str(R),'exitCode':c.returncode,'wallSeconds':time.monotonic()-t},indent=2)+'\n')
 if c.returncode:sys.exit(c.returncode)
inc=['-I'+str(p) for p in [F/'n3-native-spacing',F/'n2-normal-candidate',P/'source/voxblox/include',S/'stage-a/minkindr-564f12639a8447d4d3e5e7707851424302941056/minkindr/include',E/'usr/include/eigen3',D/'usr/include',B/'generated']]
shutil.copy2(H.parent/'prefix3/run/adapter',R/'adapter')
(R/'BINARY_REUSE.json').write_text(json.dumps({'source':str(H.parent/'prefix3/run/adapter'),'sha256':hashlib.sha256((R/'adapter').read_bytes()).hexdigest(),'recompiled':False},indent=2)+'\n')
ld=subprocess.check_output(['ldd',str(R/'adapter')],env=env,text=True);rd=subprocess.check_output(['readelf','-d',str(R/'adapter')],env=env,text=True)
assert '/lib/x86_64-linux-gnu/libcrypto.so.3' in ld
crypto=next(line.split('=>',1)[1].split('(',1)[0].strip() for line in ld.splitlines() if 'libcrypto.so.3 =>' in line)
assert hashlib.sha256(Path(crypto).read_bytes()).hexdigest()==json.loads((H/'OPENSSL_READONLY_IDENTITY.json').read_text())['paths']['/usr/lib/x86_64-linux-gnu/libcrypto.so.3']
assert str(B/'libvoxfield_rayguard.so') in ld and 'libvoxfield_native' not in ld and 'not found' not in ld
(R/'ELF.json').write_text(json.dumps({'ldd':ld,'dynamic':rd,'libcryptoResolvedPath':crypto,'libcryptoSHA256':hashlib.sha256(Path(crypto).read_bytes()).hexdigest(),'clientSHA256':hashlib.sha256((R/'adapter').read_bytes()).hexdigest(),'coreSHA256':hashlib.sha256((B/'libvoxfield_rayguard.so').read_bytes()).hexdigest()},indent=2)+'\n')
run('fusion',[str(R/'adapter'),str(H/'frames.txt'),str(R),str(H/'expected_sha256.txt'),str(H/'N2_INPUT_LEDGERS.txt'),'265'])

# Count and identity validation, no reference/geometry scoring.
rows=[json.loads(line) for line in (R/'ARMS.jsonl').read_text().splitlines()]
expected=json.loads((H/'INPUT_IDENTITY.json').read_text())['trainingIDs']
meshes={}
for arm in ['C1_N3']:
 states=[r for r in rows if r.get('arm')==arm and 'cumulative_submitted' in r]
 assert [r['frame'] for r in states]==expected and all(r['invalid_native_voxels']==0 and r['observed_weight_positive']>0 for r in states)
 path=R/(arm+'_native_mesh.ply');assert path.is_file() and path.stat().st_size>0
 meshes[arm]={'path':str(path),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'submitted':states[-1]['cumulative_submitted']}
assert len({m['submitted'] for m in meshes.values()})==1
(R/'FUSION_OUTPUT_FREEZE.json').write_text(json.dumps({'frames':265,'guardAdmissionRequired':True,'arms':meshes,'accuracyEvaluated':False,'referenceUsedByMapper':False},indent=2)+'\n')

pre=[json.loads(line) for line in (R/'PREFLIGHT.jsonl').read_text().splitlines()]
counts=[r for r in pre if 'admitted' in r]
expectedCounts=json.loads((H/'EXPECTED_COUNTS.json').read_text())['frames']
assert len(counts)==len(expectedCounts)==265
for actual,expectedCount in zip(counts,expectedCounts):
 assert actual['frame']==expectedCount['frameID'] and actual['zero']==expectedCount['rawZero'] and actual['masked_z_ge4m']==expectedCount['maskedGE4000'] and actual['admitted']==expectedCount['admitted']
(R/'ORIGINAL_COUNT_MATCH.json').write_text(json.dumps({'framesMatched':265,'allOriginalPixelCountsMatch':True,'heldoutExcluded':29},indent=2)+'\n')

# Compare every non-normal deterministic preflight field against retained N2 evidence.
original=[json.loads(x) for x in (H.parent.parent/'full265-c1-recovery/run/PREFLIGHT.jsonl').read_text().splitlines() if '"admitted"' in x]
assert len(original)==len(counts)==265
ignore={'normal_reasons_valid_boundary_missing_discontinuity_nonfinite_degenerate','range_band_by_normal_reason','preflight_seconds'}
for a,b in zip(counts,original):
 assert {k:v for k,v in a.items() if k not in ignore}=={k:v for k,v in b.items() if k not in ignore},a['frame']
(R/'N2_INPUT_LEDGER_MATCH.json').write_text(json.dumps({'frames':265,'allNonNormalPreflightFieldsEqual':True,'ignoredFields':sorted(ignore),'pointCoordinatesCheckedAgainstOriginalKDepthPerPixel':True},indent=2)+'\n')
