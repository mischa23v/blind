#!/usr/bin/env python3
"""Verify report links and receipt-derived claims; hash this evolving report snapshot."""
from pathlib import Path
import re,json,hashlib
folder=Path(__file__).resolve().parent
root=folder.parents[1]
p=folder/'FULL_REPORT.md'; text=p.read_text(); missing=[]; links=0
for dest in re.findall(r'\]\(([^)]+)\)',text):
    if dest.startswith(('http:','https:','#')): continue
    links+=1
    if not (p.parent/dest.split('#',1)[0]).exists(): missing.append(dest)
assert not missing,missing
assert len(re.findall(r'^### [GCLP]\d\d ',text,re.M))==19
assert '\t' not in text
assert not re.search(r' +$',text,re.M)
e=json.loads((folder/'EVIDENCE_SUMMARY.json').read_text())
assert e['runs'][-1]['counts']=={'Skipped':6,'Passed':223,'Failed':7}
assert [x['outcomes'] for x in e['runs'][-1]['routes']]==[12,6,16]
comparisons=[]
for rid in ('40706611490','40710093281','40726507227'):
    r=root/'research/native-path-recovery-20261028'/('run'+rid)
    early=json.loads((r/'early-unit-case-statuses-original.json').read_text())
    final=json.loads((r/'final-unit-case-statuses-original.json').read_text())
    assert early==final
    for a in final['routeDiagnosticEvidence']['reports']:
        assert json.loads((r/a['attachmentName']).read_text())==a['report']
    comparisons.append({'runID':int(rid),'earlyFinalJSONObjectsEqual':True,'namedReportCopiesMatchEmbeddedOriginals':True})
comparison_path=root/'research/independent-usd-reference-catalog-20261028-1514/run40726507227'
comparison=json.loads((comparison_path/'COMPARISON.json').read_text())
assert comparison['nativeCommit']=='c4ffa28c07d0a17b513d123de3bec2fd8be93eec'
assert sum(f['exactSourceFloat32WorldTransformMatches'] for f in comparison['fixtures'])==24
assert sum(f['sourceAnchorPairCount'] for f in comparison['fixtures'])==133
assert all(f['maxSourceAnchorDistanceDeltaMeters']==0 and f['stageMetersPerUnit']==1 and f['stageUpAxis']=='Y' for f in comparison['fixtures'])
inputs=json.loads((comparison_path/'INPUT_MANIFEST.json').read_text())
for f in inputs['files']:
    p2=root/'research/native-path-recovery-20261028/run40726507227/public-apple-same-export'/f['name']
    assert p2.stat().st_size==f['bytes'] and hashlib.sha256(p2.read_bytes()).hexdigest()==f['sha256']
qa={'schema':1,'scope':'report content/link and derived-count review only; no new native execution; incorporates independently reviewed same-file USDZ comparison','reportWords':len(text.split()),'findingCount':19,'relativeLinksChecked':links,'missingRelativeLinks':missing,'latestHostedCounts':e['runs'][-1]['counts'],'routeOutcomeCounts':[x['outcomes'] for x in e['runs'][-1]['routes']],'originalFixtureSHA256Recomputed':True,'sameExportSevenInputHashesVerified':True,'comparison24TransformsAnd133AnchorsRecounted':True,'semanticEqualityChecks':comparisons,'open3dSectionPeerReview':'Source evidence owner checked P06 counts, domains, metrics and caveats against exact receipts; explicit positive-depth domain and scorer differences clarified','sameExportComparison':e['independentExactUSDZComparison'],'noImplementationFilesChangedByReportTask':True,'notes':['The first evidence-summary derivation failed because one native-build duration is null; corrected aggregation excludes null durations and separately reports the number of measured build receipts. No original evidence was changed.','Source code in the shared checkout can contain unpublished work. Published behavior is attributed to retained exact-source receipts or exact-revision audit records.','Exact diagnostic same-file import comparison completed; fresh raw-input reconstruction comparison and corrective implementation remain unfinished.']}
(folder/'REVIEW.json').write_text(json.dumps(qa,indent=2)+'\n')
files=[folder/n for n in ('FULL_REPORT.md','EVIDENCE_SUMMARY.json','REVIEW.json','build_evidence_summary.py','review_report.py','prepare_publication.py')]
files+=sorted(p for p in (folder/'evidence').rglob('*') if p.is_file())
(folder/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(folder))+'\n' for p in files))
print(f'{len(text.split())} words; {links} valid local links; {len(comparisons)} run evidence equality checks.')
print('FULL_REPORT.md SHA256',hashlib.sha256(p.read_bytes()).hexdigest())
