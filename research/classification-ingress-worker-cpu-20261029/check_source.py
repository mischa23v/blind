#!/usr/bin/env python3
"""Bounded text/hash checks only; not a Swift parser, compiler or native test."""
from pathlib import Path
import re,json,hashlib,difflib
H=Path(__file__).resolve().parent;R=H.parents[1]
PATHS=['research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift','research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift','ios/BlindAssistTests/ClassificationIngressTests.swift','ios/BlindAssistTests/ClassifiedRoomMeshTests.swift']
def release(s):
 out=[];stack=[]
 for line in s.splitlines():
  t=line.strip()
  if t.startswith('#if '):
   stack.append(False if 'DEBUG' in t or (stack and not all(stack)) else True);continue
  if t.startswith('#elseif '):
   assert stack;stack[-1]=False;continue
  if t=='#else':
   assert stack;stack[-1]=not stack[-1];continue
  if t=='#endif':stack.pop();continue
  if all(stack):out.append(line)
 assert not stack
 return re.sub(r'\s+','', '\n'.join(out))
def run():
 checks=[];files=[];patch=''
 for name in PATHS:
  p=R/name;s=p.read_text();old=(H/(p.name+'.before')).read_text()
  # Both runtime files' outer DEBUG blocks remove all nested platform branches.
  if p.name in ['RoomMeshCandidate.swift','MeshCandidateIngress.swift']:
   assert release(s)==release(old),name;checks.append(name+': release token text unchanged')
  else:
   assert s.count('timeout: 10')==old.count('timeout: 10')==2
   assert [x.strip() for x in s.splitlines() if any(v in x for v in ['XCTAssert','XCTFail','XCTUnwrap'])]==[x.strip() for x in old.splitlines() if any(v in x for v in ['XCTAssert','XCTFail','XCTUnwrap'])]
   assert 'box.put($0)\n            done.fulfill()' in s
   checks.append(name+': deadlines, assertions, store/fulfill callbacks unchanged')
  b=p.read_bytes();files.append({'path':name,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()})
  patch+=''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='a/'+name,tofile='b/'+name))
 runtime=(R/PATHS[0]).read_text()
 for token in ['pending<16','diagnosticDeliveryCount<8','diagnosticReceipts.count<64','CLOCK_THREAD_CPUTIME_ID','pthread_threadid_np(nil,&thread)==0','Self.diagnosticDeliveryGate.submit { completion(id,snapshot) }','syntheticTimingCompletion: ((UUID,[DiagnosticStageReceipt])->Void)? = nil']:
  assert token in runtime,token;checks.append('contract: '+token)
 for name in PATHS[2:]:
  s=(R/name).read_text()
  for token in ['at == bt','bc >= ac','return (wall, -1, false)','return (-1, -1, false)']:
   assert token in s,token
  checks.append(name+': CPU identity/monotonicity/missing-pair refusal')
 (H/'SOURCE_RESULT.json').write_text(json.dumps({'kind':'source_only','checks':checks,'checksPassed':len(checks),'swiftCompiled':False,'nativeTestsExecuted':False,'files':files},indent=2)+'\n')
 (H/'instrumentation.patch').write_text(patch)
 print(json.dumps({'checksPassed':len(checks),'files':files,'swiftCompiled':False}))
if __name__=='__main__':run()
