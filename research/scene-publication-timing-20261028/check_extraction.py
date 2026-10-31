"""Exercise only the bounded log-extraction fragment; never run Apple CI."""
from pathlib import Path
import tempfile,subprocess,json
P=Path(__file__).resolve().parent;R=P.parent.parent
source=(R/'tools/ci/native-apple.sh').read_text();before=(P/'native-apple.sh.before').read_text()
start=source.index("      echo 'OBSERVED_SCENE_TIMING_BEGIN")
end=source.index("      echo 'OBSERVED_SCENE_TIMING_END'",start)+len("      echo 'OBSERVED_SCENE_TIMING_END'\n")
fragment=source[start:end]
assert source[:start]+source[end:]==before
checks=['helper diff exactly bounded extraction only']
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'unit.log'
 p.write_text('PRIVATE_PHOTO_PAYLOAD secretA\nMODEL_REPLY secretB\nxOBSERVED_SCENE_FENCE_PHASE secretC\n'+''.join('OBSERVED_SCENE_FENCE_LATENCY elapsed='+('9'*1700 if i==0 else str(i))+' originalBudget=1.2 functionalCompletion=true\n' for i in range(12)))
 script='set -euo pipefail\nout="$1"\nlabel=unit\nstatus=65\n'+fragment+'test "$status" -eq 65\n'
 result=subprocess.run(['bash','-c',script,'test',directory],capture_output=True,text=True,check=True)
 lines=[l for l in result.stdout.splitlines() if l.startswith('OBSERVED_SCENE_FENCE_')]
 assert len(lines)==8 and max(map(len,lines))<=1500
 assert 'secret' not in result.stdout and 'PRIVATE' not in result.stdout and 'MODEL_REPLY' not in result.stdout
 checks+=['metadata line cap8','character cap1500','unrelated/private/model prefixes excluded','status65 preserved']
 p.write_text('MODEL_REPLY only private content\n')
 result=subprocess.run(['bash','-c',script,'test',directory],capture_output=True,text=True,check=True)
 assert len(result.stdout.splitlines())==2 and 'private' not in result.stdout
 checks+=['no-match grep does not abort failure reporting']
result={'checks_passed':len(checks),'checks':checks,'apple_ci_executed':False}
(P/'EXTRACTION_CHECK_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
