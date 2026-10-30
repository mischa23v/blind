#!/usr/bin/env python3
"""Saved hit-set and paired residual audit; no mapper or dataset raster reads."""
import os
os.environ['OPENBLAS_NUM_THREADS']='1';os.environ['OMP_NUM_THREADS']='1'
import pathlib,json,hashlib,importlib.util,resource
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(120,)*2);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
import numpy as np
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent;A=W/'coffee-fine-fused-heldout-attempt-001';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=R/'research/coffee-fine-fused-heldout-source-20261030/metrics.py';spec=importlib.util.spec_from_file_location('metrics',p);metric=importlib.util.module_from_spec(spec);spec.loader.exec_module(metric)
r=json.loads((A/'RESULT.json').read_text());assert r['status']=='completed-fine-fused-heldout-diagnostic'and r['exactBaselineRecreated']and r['exactCoarseHeldoutEvidenceReproduced']and r['fineMapConstructed'];assert r['baseline']==r['fineBaseline']
primary=json.loads((R/'research/coffee-heldout-depth-result-20261030/RESULT.json').read_text());assert r['primaryResultsRetained']==primary['frames']and r['coarseBaseline']==primary['baseline']and r['extraction']==primary['extraction']
prior=json.loads((R/'research/coffee-heldout-observation-result-20261030/RESULT.json').read_text())
out={'status':'completed-saved-paired-hitset-audit','nativeLibraryLoaded':False,'rasterRead':False,'sourceResultSHA256':sha(A/'RESULT.json'),'frames':[]}
for coarse,fine,previous in zip(r['coarseFrames'],r['frames'],prior['frames']):
 assert coarse['frame']==fine['frame']==previous['frame'];arrays=[]
 for k in previous:
  if k in coarse:assert coarse[k]==previous[k],k
 for c in (coarse,fine):
  assert c['beforeAfterPayloadEqual'];assert sum(c['primaryRayStatuses'].values())==sum(c['observationRayStatuses'].values())==c['fixedGridValid'];assert c['primaryRayStatuses']['origin-unknown']==c['fixedGridValid']
  for field in ('endpointPixelWeighted','endpointDistinctKeyWeighted'):
   q=c[field];assert q['knownOccupied']+q['knownNotOccupied']+q['unknown']==q['total']
  p=A/c['derivedEvidence']['path'];assert sha(p)==c['derivedEvidence']['sha256']
  with np.load(p,allow_pickle=False)as data:a={k:data[k].copy()for k in data.files}
  idx=a['observationPixelIndex'];assert len(idx)==len(np.unique(idx))==c['observationRayStatuses']['observed-hit-visibility-unverified'];assert len(a['primaryPixelIndex'])==0
  for col,field in [('entryAxial','entryAxialResidualMetres'),('centerAxial','centerAxialResidualMetres'),('entryAlongRay','entryAlongRayResidualMetres')]:assert metric.distributions(a[col])==c[field]
  arrays.append(a)
 for k in ('rasterPixels','zeroDepthPixels','rangeExcludedPixels','acceptedPixels','fixedGridCandidates','fixedGridZeroDepth','fixedGridRangeExcluded','fixedGridValid'):assert coarse[k]==fine[k]
 a,b=arrays;common,ai,bi=np.intersect1d(a['observationPixelIndex'],b['observationPixelIndex'],assume_unique=True,return_indices=True);am=~np.isin(a['observationPixelIndex'],common,assume_unique=True);bm=~np.isin(b['observationPixelIndex'],common,assume_unique=True)
 delta=np.abs(b['entryAxial'][bi])-np.abs(a['entryAxial'][ai]);row={'frame':coarse['frame'],'gridValid':coarse['fixedGridValid'],'commonHitPixels':len(common),'lostCoarseHitPixels':int(am.sum()),'newFineHitPixels':int(bm.sum()),'neitherHitPixels':coarse['fixedGridValid']-len(common)-int(am.sum())-int(bm.sum()),'commonEntryCoarseMetres':metric.distributions(a['entryAxial'][ai]),'commonEntryFineMetres':metric.distributions(b['entryAxial'][bi]),'commonAbsoluteEntryChangeFineMinusCoarseMetres':metric.distributions(delta),'commonImproved':int((delta<0).sum()),'commonEqual':int((delta==0).sum()),'commonWorsened':int((delta>0).sum()),'lostHitCoarseEntryMetres':metric.distributions(a['entryAxial'][am]),'newHitFineEntryMetres':metric.distributions(b['entryAxial'][bm])}
 assert row['commonHitPixels']+row['lostCoarseHitPixels']==len(a['observationPixelIndex']);assert row['commonHitPixels']+row['newFineHitPixels']==len(b['observationPixelIndex'])
 out['frames'].append(row)
with(H/'PAIRED_HITSET_AUDIT.json').open('x')as f:json.dump(out,f,indent=2,allow_nan=False);f.write('\n')
for f in out['frames']:
 print(f['frame'],'common/lost/new/neither',f['commonHitPixels'],f['lostCoarseHitPixels'],f['newFineHitPixels'],f['neitherHitPixels'],'improved/equal/worse',f['commonImproved'],f['commonEqual'],f['commonWorsened'])
 for k in ('commonEntryCoarseMetres','commonEntryFineMetres','lostHitCoarseEntryMetres','newHitFineEntryMetres'):print(k,f[k]['absolute']['median']if f[k]['absolute']else None,f[k]['absolute']['p95']if f[k]['absolute']else None)
