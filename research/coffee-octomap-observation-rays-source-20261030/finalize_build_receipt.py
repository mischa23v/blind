#!/usr/bin/env python3
"""Read-only result verification plus a new compatibility receipt; no native calls."""
import argparse,hashlib,json,os,stat
from pathlib import Path
ROOT=Path(__file__).resolve().parent

def sha(path):
 fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
 try:
  before=os.fstat(fd)
  if not stat.S_ISREG(before.st_mode):raise ValueError('nonregular input')
  with os.fdopen(os.dup(fd),'rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
  after=os.fstat(fd)
  if (before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_size,after.st_mtime_ns,after.st_ctime_ns):raise ValueError('changed input')
  return digest
 finally:os.close(fd)
def require(ok,why):
 if not ok:raise ValueError(why)
def main():
 p=argparse.ArgumentParser();p.add_argument('--expected-guard-receipt-sha256',required=True);a=p.parse_args()
 work=ROOT/'build-observation-01';gp=work/'GUARD_RUN/RESULT.json'
 require(sha(gp)==a.expected_guard_receipt_sha256,'unreviewed guard result')
 g=json.loads(gp.read_text());require(g['status']=='completed-zero-exit','guard failed')
 require(len(g['commands'])==1 and g['commands'][0]['label']=='compile' and g['commands'][0]['exitCode']==0 and g['commands'][0]['groupRetired'] is True,'compile/retirement failed')
 require(g['inputHashesBefore']==g['inputHashesAfter'],'source/toolchain drift')
 require(g['aggregateCPUSeconds']<=120 and g['wallSeconds']<=180 and max(g['peakObservedAggregateRSS'],g['peakFastExitChildRSS'])<=1024**3,'resource breach')
 require(sha(ROOT/'BUILD_RUN_PINS.json')==g['manifestSHA256'],'manifest changed')
 for name,digest in g['inputHashesAfter'].items():
  expanded=name.replace('@SOURCE@',str(ROOT)).replace('@BASE@',str(ROOT.parent/'coffee-octomap-build-source-20261029')).replace('@WORK@',str(work))
  path=Path(expanded) if expanded.startswith('/') else ROOT.parents[1]/expanded
  require(sha(path)==digest,'source/toolchain changed after guard: '+name)
 binary=work/'libblind_octomap.so';digest=sha(binary)
 require(digest==g['executableSHA256']==g['finalPayloadInventory']['libblind_octomap.so']['sha256'],'binary differs from retired inventory')
 result={'buildVariant':'observation-rays-20261030-v1-aggregate','historicalBinaryNotAssumed':True,
         'success':True,'exitCode':0,'failure':None,'sourceUnchanged':True,
         'CPUSeconds':g['aggregateCPUSeconds'],'wallSeconds':g['wallSeconds'],
         'peakSampledOrWaitedTreeRSSBytes':max(g['peakObservedAggregateRSS'],g['peakFastExitChildRSS']),
         'librarySHA256':digest,'libraryBytes':binary.stat().st_size,
         'adapterTranslationUnitSHA256':sha(ROOT/'readonly_rays.cpp'),
         'includedBaselineAdapterSHA256':sha(ROOT.parent/'coffee-octomap-build-source-20261029/octomap_adapter.cpp'),
         'sourceManifestSHA256':sha(ROOT/'MANIFEST.json'),
         'guardReceiptSHA256':sha(gp),'sourcePin':'007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f',
         'sourceFiles':48,'serial':True,'systemInstall':False,'OpenMP':False,'physicalAuthority':False}
 with (work/'BUILD_RECEIPT.json').open('x') as f:json.dump(result,f,indent=2);f.write('\n')
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()
