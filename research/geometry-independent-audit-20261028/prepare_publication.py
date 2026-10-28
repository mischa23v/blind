#!/usr/bin/env python3
"""Freeze a report and exact public-fixture evidence allowlist against the connector-verified c4ffa28 tree."""
import hashlib,json,re
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE='c4ffa28c07d0a17b513d123de3bec2fd8be93eec'
def load(p):return json.loads(p.read_text())
def info(p):
 b=p.read_bytes()
 return {'path':str(p.relative_to(ROOT)),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'gitBlobSHA':hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()}
d=load(HERE/'REMOTE_DEPENDENCY_TREES.json');assert d['commit']==BASE
remote={x['path']:x for x in d['root']['tree'] if x['type']=='blob'}
remote.update({'research/'+x['path']:x for x in d['research']['tree'] if x['type']=='blob'})
for t in d['scopedTrees']:
 for x in t.get('tree',[]):
  if x['type']=='blob':remote[t['path']+'/'+x['path']]=x
for x in load(HERE/'REMOTE_FIXTURE_ENTRIES.json'):
 remote[x['path']]={'sha':x['sha'],'size':x['size']}
selected={HERE/n for n in ('FULL_REPORT.md','EVIDENCE_SUMMARY.json','REVIEW.json','build_evidence_summary.py','review_report.py','prepare_publication.py','SHA256SUMS.txt')}
selected.update(p for p in (HERE/'evidence/open3d').rglob('*') if p.is_file())
links=[]
for dest in re.findall(r'\]\(([^)]+)\)',(HERE/'FULL_REPORT.md').read_text()):
 if dest.startswith(('http:','https:','#')):continue
 p=(HERE/dest.split('#',1)[0]).resolve();assert p.exists(),dest
 links.append({'link':dest,'path':str(p.relative_to(ROOT))});selected.add(p)
runs=ROOT/'research/native-path-recovery-20261028'
# Closure needed to reproduce the published case recount and early/final equality.
for run in ('40698547633','40706611490','40710093281','40726507227'):
 folder=runs/('run'+run);status=folder/'final-unit-case-statuses-original.json';selected.add(status)
 for r in load(status)['routeDiagnosticEvidence']['reports']:
  selected.add(folder/r['attachmentName'])
 if run!='40698547633':
  selected.add(folder/'early-unit-case-statuses-original.json')
  selected.add(folder/'report-manifest.json')
  selected.add(folder/'terminal-run.json')
for n in ('final-unit-case-statuses-original.json','terminal-run.json'):
 selected.add(runs/'run40721822359'/n)
for name in ('Hallway2','Bedroom3'):
 selected.add(ROOT/'ios/BlindAssistTests/Fixtures/RoomPlanApple'/(name+'.capturedRoom.json'))
reference=ROOT/'research/independent-usd-reference-catalog-20261028-1514'
selected.update(p for p in reference.iterdir() if p.is_file())
selected.update(p for p in (reference/'run40726507227').iterdir() if p.is_file())
selected.update(p for p in (runs/'run40726507227/public-apple-same-export').iterdir() if p.is_file())
selected.add(runs/'run40726507227/local-same-export-verification.json')
selected.add(runs/'run40726507227/terminal-jobs-170921Z.json')
selected.add(runs/'run40726507227/terminal-failure-extract.txt')
selected.add(runs/'run40726507227/ui-audit/evidence.json')
selected.add(runs/'run40726507227/ui-audit/full-audit-ask-issue-1-metadata.json')
selected.add(runs/'run40706611490/blocked-context-views-v3/APPLE-LICENSE.txt')
for p in selected:
 assert p.is_relative_to(ROOT)
 assert p.name=='.gitignore' or p.suffix in ('.md','.json','.txt','.py','.usdz','.bin'),p
 assert not any(x in p.parts for x in ('runtime','staging','arrays','node_modules')),p
 b=p.read_bytes()
 if p.suffix not in ('.usdz','.bin'): b.decode('utf-8');assert b'\0' not in b,p
new=[];existing=[];conflicts=[]
for p in sorted(selected):
 rec=info(p)|{'encoding':'base64' if p.suffix in ('.usdz','.bin') else 'utf-8'};old=remote.get(rec['path'])
 if old:
  if old['sha']!=rec['gitBlobSHA']:conflicts.append({'path':rec['path'],'expected':old['sha'],'local':rec['gitBlobSHA']})
  else:existing.append(rec|{'verification':'Git blob equals base tree; do not upload or overwrite'})
 else:new.append(rec|{'action':'create','classification':'public technical evidence or report; no private child data'})
assert not conflicts,conflicts
reconciliation={'schema':1,'baseCommit':BASE,'remoteVerification':'GitHub connector GET root/research/scoped Git trees plus original public-fixture directory at exact commit; no repository mutation','reportRelativeLinks':links,'newFileCount':len(new),'existingUnchangedDependencyCount':len(existing),'existingUnchangedDependencies':existing,'conflicts':conflicts,'scope':'Direct report links plus evidence-script input closure; historical evidence packages are text/JSON subsets, not their original image/ZIP packages. No screenshot is added.'}
(HERE/'DEPENDENCY_RECONCILIATION.json').write_text(json.dumps(reconciliation,indent=2)+'\n')
new.append(info(HERE/'DEPENDENCY_RECONCILIATION.json')|{'action':'create','classification':'public technical provenance'})
new.sort(key=lambda x:x['path'])
manifest={'schema':1,'status':'reviewed current report/evidence allowlist; same-export import comparison completed, fresh reconstruction benchmarks unfinished','snapshotUTC':'2026-10-28T17:12:00Z','baseCommit':BASE,'publicationOwner':'root only; this task does not commit or push','reportPath':'research/geometry-independent-audit-20261028/FULL_REPORT.md','findings':19,'independentOpenUSDComparison':'COMPLETED; two exact retained public diagnostic exports, independently repeated','pendingNativeRun':40726507227,'nativeRunStateAtSnapshot':'completed/failure; hosted223pass7fail6skip;9classification and capture pass; UI audit failed','physicalAuthority':False,'files':new,'totalFileBytes':sum(x['bytes'] for x in new),'existingDependencyCount':len(existing),'existingDependencyRecord':'research/geometry-independent-audit-20261028/DEPENDENCY_RECONCILIATION.json','excluded':['all screenshots and image files','raw photos or RGB/depth frames','NPZ arrays','archives other than the two SHA-verified public USDZ fixtures','runtimes, wheels, caches, dependencies','all production/app/test/workflow changes','all shared tracker changes'],'privacyReview':'Only original public Apple fixture technical receipts, synthetic UI callback JSON, public Koivu derived technical summaries, public study citations and engineering source/hash metadata. No private child/family details, camera/audio capture or credentials are included.','manifestSelfPublication':'Publish this manifest and its .sha256 sidecar in addition to files; self-hash is not recursively included in its own contents.'}
mp=HERE/'PUBLICATION_MANIFEST.json';mp.write_text(json.dumps(manifest,indent=2)+'\n')
(HERE/'PUBLICATION_MANIFEST.sha256').write_text(hashlib.sha256(mp.read_bytes()).hexdigest()+'  '+mp.name+'\n')
print('NEW',len(new),'files',manifest['totalFileBytes'],'bytes; existing identical',len(existing),'dependencies; links',len(links))
print('Manifest SHA256',hashlib.sha256(mp.read_bytes()).hexdigest())
print('Report SHA256',info(HERE/'FULL_REPORT.md')['sha256'])
