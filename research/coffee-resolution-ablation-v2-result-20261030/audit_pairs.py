#!/usr/bin/env python3
"""Read saved arrays only; no mapper or raster reads."""
import os
os.environ['OPENBLAS_NUM_THREADS']='1';os.environ['OMP_NUM_THREADS']='1'
import pathlib,json,hashlib,importlib.util,resource
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(120,)*2);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
import numpy as np
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent;A=W/'coffee-resolution-ablation-attempt-002'
p=R/'research/coffee-resolution-ablation-v2-source-20261030/metrics.py';s=importlib.util.spec_from_file_location('metrics',p);metric=importlib.util.module_from_spec(s);s.loader.exec_module(metric)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();r=json.loads((A/'RESULT.json').read_text());assert r['status']=='completed-fixed-resolution-ablation'and r['allFiveCmBaselinesReproduced']and len(r['cases'])==6
out={'status':'completed-saved-paired-array-audit','nativeLibraryLoaded':False,'rasterRead':False,'sourceResultSHA256':sha(A/'RESULT.json'),'frames':[]}
for n in r['buildFrames']:
 rows=[next(c for c in r['cases']if c['frame']==n and c['kind']==k)for k in ('five_cm','two_point_five_cm')];arrays=[]
 for c in rows:
  assert c['beforeAfterPayloadEqual'];assert sum(c['primaryRayStatuses'].values())==sum(c['observationRayStatuses'].values())==c['fixedGridValid'];assert c['mapBefore']['state']['leaves']<=1000000 and c['mapBefore']['state']['treeNodes']<=1000000
  p=A/c['derivedEvidence']['path'];assert sha(p)==c['derivedEvidence']['sha256']
  with np.load(p,allow_pickle=False)as data:a={k:data[k].copy()for k in data.files}
  assert len(np.unique(a['pixelIndex']))==len(a['pixelIndex'])
  for col,field in [('entryAxial','entryAxialResidualMetres'),('centerAxial','centerAxialResidualMetres'),('entryAlongRay','entryAlongRayResidualMetres')]:assert metric.distributions(a[col])==c[field]
  arrays.append(a)
 for k in ('acceptedPixels','rasterPixels','zeroDepthPixels','rangeExcludedPixels','fixedGridCandidates','fixedGridZeroDepth','fixedGridRangeExcluded','fixedGridValid'):assert rows[0][k]==rows[1][k]
 coarse,fine=arrays;common,ci,fi=np.intersect1d(coarse['pixelIndex'],fine['pixelIndex'],assume_unique=True,return_indices=True);c=coarse['entryAxial'][ci];f=fine['entryAxial'][fi];delta=np.abs(f)-np.abs(c)
 out['frames'].append({'frame':n,'commonHitPixels':len(common),'coarseOnlyHitPixels':len(coarse['pixelIndex'])-len(common),'fineOnlyHitPixels':len(fine['pixelIndex'])-len(common),'commonCoarseEntryResidualMetres':metric.distributions(c),'commonFineEntryResidualMetres':metric.distributions(f),'pairedAbsoluteResidualChangeFineMinusCoarseMetres':metric.distributions(delta),'commonPixelsImproved':int((delta<0).sum()),'commonPixelsEqual':int((delta==0).sum()),'commonPixelsWorsened':int((delta>0).sum()),'coarsePrimaryUnknownBeforeHit':rows[0]['primaryRayStatuses']['unknown-before-hit'],'finePrimaryUnknownBeforeHit':rows[1]['primaryRayStatuses']['unknown-before-hit'],'allEndpointPixelsOccupiedBoth':all(x['endpointPixelWeighted']['knownOccupied']==x['endpointPixelWeighted']['total']for x in rows)})
with(H/'PAIRED_AUDIT.json').open('x')as f:json.dump(out,f,indent=2,allow_nan=False);f.write('\n')
for f in out['frames']:print(f['frame'],f['commonHitPixels'],f['fineOnlyHitPixels'],f['commonPixelsImproved'],f['commonPixelsEqual'],f['commonPixelsWorsened'],f['pairedAbsoluteResidualChangeFineMinusCoarseMetres']['signed']['median'])
