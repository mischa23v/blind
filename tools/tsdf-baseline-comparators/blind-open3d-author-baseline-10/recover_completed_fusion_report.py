"""Read-only input/output recheck after a native warning prefixed worker JSON.
No reconstruction, parameter change or source/result overwrite.
"""
from pathlib import Path
import hashlib,json,time
ROOT=Path(__file__).resolve().parent
EXPECTED_FROZEN='89e4f8add800d85b772a5314f88c45dbecb1dd5536c0b61c9f5f533727f942d4'
def sha(path):
 h=hashlib.sha256()
 with Path(path).open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def write_new(path,obj):
 with path.open('x') as f:f.write(json.dumps(obj,indent=2,sort_keys=True)+'\n')
def header(path):
 with path.open('rb') as f:
  data=bytearray()
  while not data.endswith(b'end_header\n'):
   b=f.read(1)
   if not b or len(data)>16384:raise ValueError('invalid/oversized PLY header')
   data.extend(b)
 return bytes(data).decode('ascii')
def main():
 start=time.monotonic();out=ROOT/'koivu';frozen_path=ROOT/'KOIVU_FROZEN.json'
 assert sha(frozen_path)==EXPECTED_FROZEN
 frozen=json.loads(frozen_path.read_text());raw=(out/'RESULT.json').read_bytes()
 warning,sep,body=raw.partition(b'\n')
 assert warning==b'\x1b[1;33m[Open3D WARNING] Write Ply clamped color value to valid range\x1b[0;m' and sep
 result=json.loads(body);assert result['integratedFrameCount']==265 and result['excludedTestFrameCount']==29
 failure=json.loads((out/'FAILURE.json').read_text());assert failure['status']=='failed' and 'JSONDecodeError' in failure['error']
 assert len(failure['phases'])==1 and failure['phases'][0]['exitCode']==0
 for p,h in frozen['pins'].items():assert sha(p)==h,p
 for row in result['modules'].values():assert sha(row['path'])==row['sha256']
 frames=[json.loads(s) for s in (out/'FRAMES.jsonl').read_text().splitlines()]
 assert len(frames)==265 and [f['frameID'] for f in frames]==[f['frameID'] for f in frozen['trainingFrames']]
 assert [f['trainingIndex'] for f in frames]==list(range(265))
 for r in frames:assert r['rawZeroPixels']+r['nativeFactoryClippedNonzeroDepthPixels']==r['nativeConvertedZeroDepthPixels'] and r['nativeConvertedZeroDepthPixels']+r['nativeConvertedPositiveDepthPixels']==r['exportedRasterPixels']
 for key in ('exportedRasterPixels','nativeConvertedPositiveDepthPixels','nativeConvertedZeroDepthPixels','nativeFactoryClippedNonzeroDepthPixels'):assert sum(f[key] for f in frames)==result[key]
 ply={}
 for name,h in result['outputSHA256'].items():
  p=out/name;assert sha(p)==h;hdr=header(p);ply[name]={'sha256':h,'bytes':p.stat().st_size,'header':hdr}
 assert f'element vertex {result["vertices"]}\n' in ply['unfiltered-tsdf-mesh.ply']['header']
 assert f'element face {result["triangles"]}\n' in ply['unfiltered-tsdf-mesh.ply']['header']
 assert f'element vertex {result["authorStyleCloudPoints"]}\n' in ply['author-style-initialization-cloud.ply']['header']
 write_new(out/'RECOVERED_RESULT.json',result)
 receipt={'status':'fusion-worker-completed; wrapper-report-parse-failed; saved-report-recovered','noFusionRerun':True,'noSourceOrOriginalResultModified':True,'originalRawStdoutSHA256':sha(out/'RESULT.json'),'originalWrapperFailureSHA256':sha(out/'FAILURE.json'),'preservedNativeWarning':warning.decode('ascii'),'warningEffect':'Native PLY writer reported color clamping; original warning and serialized outputs retained. No geometry thresholds or fusion parameters changed.','recoveredResultSHA256':sha(out/'RECOVERED_RESULT.json'),'frozenSHA256':EXPECTED_FROZEN,'sourceInputPinsReverified':len(frozen['pins']),'nativeModuleHashesReverified':len(result['modules']),'frameRecount':len(frames),'vertices':result['vertices'],'triangles':result['triangles'],'authorStyleCloudPoints':result['authorStyleCloudPoints'],'phase':failure['phases'][0],'sampledPeakRSSBytes':None,'resourceEvidence':'The original watcher returned from the child phase after its cap check; peak RSS was not serialized before the reporting failure. No exact peak is claimed.','PLY':ply,'recoveryWallSeconds':time.monotonic()-start,'physicalAuthority':False,'navigationRuns':0}
 write_new(out/'RECOVERY_RECEIPT.json',receipt);print(json.dumps({k:receipt[k] for k in ('status','sourceInputPinsReverified','frameRecount','vertices','triangles','authorStyleCloudPoints','recoveryWallSeconds')},indent=2))
if __name__=='__main__':main()
