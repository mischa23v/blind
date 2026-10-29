#!/usr/bin/env python3
"""Source-only binding generation AFTER successful build and original controls.
No native library load. Exact expected control receipt must be supplied by reviewer.
"""
import argparse,ast,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
OLD='3c0a88593d07540d93dbbc3e404ee44b3f5167ff7bda74f16fc8075aab83b1db'
RETENTION_SHA='ced6ab06a578f7b211d532d978827b8583656a8f3b638d87f368b7cb8ec81e7c'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def main():
 p=argparse.ArgumentParser();p.add_argument('--expected-control-receipt-sha256',required=True);a=p.parse_args()
 controls=ROOT/'build-restored-01/ORIGINAL_CONTROL_RECEIPT.json'
 require(sha(controls)==a.expected_control_receipt_sha256,'unreviewed controls')
 c=json.loads(controls.read_text())
 require(c['success'] and c['testsRun']==16 and c['skipped']==0 and c['failures']==0 and c['errors']==0,'controls not complete')
 require(c['sourceClosureSHA256']==sha(ROOT/'SOURCE_CLOSURE.json'),'source closure changed')
 closure=json.loads((ROOT/'SOURCE_CLOSURE.json').read_text())
 for name,digest in closure['pinnedLocalFiles'].items():require(sha(ROOT/name)==digest,'source drift: '+name)
 build=ROOT/'build-restored-01/BUILD_RECEIPT.json'
 require(sha(build)==c['buildReceiptSHA256'],'build receipt drift')
 b=json.loads(build.read_text());require(b['success'] and b['buildVariant']=='restored-20261029-v2-aggregate','invalid build')
 library=ROOT/'build-restored-01/libblind_octomap.so';digest=sha(library)
 require(digest==c['librarySHA256']==b['librarySHA256'],'library drift')
 original=ROOT.parent/'coffee-table-retention-source-20261029/retention.py'
 require(sha(original)==RETENTION_SHA,'retention source changed; new review required')
 source=original.read_text();wrapper=(ROOT/'octomap_engine.py').read_text()
 require(source.count(OLD)==1 and wrapper.count(OLD)==1,'unexpected native binding pattern')
 require(source.count("pins['vendoredUnchanged']['octomap_engine.py']")==1,'wrapper pin lookup changed')
 source=source.replace(OLD,digest).replace("pins['vendoredUnchanged']['octomap_engine.py']","pins['rebuiltBinding']['octomap_engine.py']")
 wrapper=wrapper.replace(OLD,digest)
 ast.parse(source);ast.parse(wrapper)
 out=ROOT/'build-restored-01/stage-b-binding-v2';out.mkdir(exist_ok=False)
 (out/'retention.py').write_text(source);(out/'octomap_engine.py').write_text(wrapper)
 binding={'variant':'restored-20261029-v2-aggregate','physicalAuthority':False,'librarySHA256':digest,
          'buildReceiptSHA256':sha(build),'originalControlsReceiptSHA256':sha(controls),
          'historicalRetentionSHA256':RETENTION_SHA,'historicalLibrarySHA256':OLD,
          'changes':['retention required library hash','wrapper required library hash','explicit rebuiltBinding pin lookup'],
          'rebuiltBinding':{n:sha(out/n) for n in ['retention.py','octomap_engine.py']}}
 (out/'SOURCE_PINS.json').write_text(json.dumps(binding,indent=2)+'\n')
 print(json.dumps(binding,indent=2))
if __name__=='__main__':main()
