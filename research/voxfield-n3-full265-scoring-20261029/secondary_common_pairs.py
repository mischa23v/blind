"""Frozen secondary paired-coverage analysis; saved rays only, no mesh query."""
from pathlib import Path
import sys,json,importlib.util
import numpy as np
H=Path(__file__).resolve().parent;W=H.parent.parent;D=H/'C1_N3'
R=W/'research/open3d-same-data-benchmark-20261028/fresh-run'
OLD=W/'coordination/voxfield-recovered-full265-same-protocol-score'
sys.path.insert(0,str(R/'source'))
spec=importlib.util.spec_from_file_location('held',R/'source/blind-koivu-tsdf-heldout-11-evaluate.py')
h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
ids=json.loads((R/'EVALUATOR_FROZEN.json').read_text())['frameIDs']
BANDS=[.02,.05,.1]
def error_summary(error):
 return {'statistics':h.stats(error),'earlyWithinLate':{str(t):{'earlier':int((error<-t).sum()),'within':int((np.abs(error)<=t).sum()),'later':int((error>t).sum())}for t in BANDS}}
def summary(ref,before,after):
 rv=np.isfinite(ref)&(ref>0);bv=np.isfinite(before)&(before>0);av=np.isfinite(after)&(after>0)
 def sub(mask):
  r=rv&mask;common=r&bv&av;gained=r&~bv&av;lost=r&bv&~av;neither=r&~bv&~av
  c={'scheduled':int(mask.sum()),'referencePositive':int(r.sum()),'commonPaired':int(common.sum()),'gainedPaired':int(gained.sum()),'lostPaired':int(lost.sum()),'neitherPaired':int(neither.sum()),'beforePaired':int((r&bv).sum()),'afterPaired':int((r&av).sum())}
  assert sum(c[k]for k in ['commonPaired','gainedPaired','lostPaired','neitherPaired'])==c['referencePositive']
  assert c['beforePaired']==c['commonPaired']+c['lostPaired'] and c['afterPaired']==c['commonPaired']+c['gainedPaired']
  return {'coverage':c,'commonBefore':error_summary(before[common]-ref[common]),'commonAfter':error_summary(after[common]-ref[common]),'gainedAfterOnly':error_summary(after[gained]-ref[gained]),'lostBeforeOnly':error_summary(before[lost]-ref[lost])}
 missing=~rv
 missing_coverage={'referenceMissing':int(missing.sum()),'bothMapperHit':int((missing&bv&av).sum()),'beforeMapperOnly':int((missing&bv&~av).sum()),'afterMapperOnly':int((missing&~bv&av).sum()),'neitherMapperHit':int((missing&~bv&~av).sum())}
 assert sum(missing_coverage[k]for k in ['bothMapperHit','beforeMapperOnly','afterMapperOnly','neitherMapperHit'])==missing_coverage['referenceMissing']
 return {'all':sub(np.ones(len(ref),bool)),'referenceBelow4m':sub(rv&(ref<4)),'referenceAtLeast4m':sub(rv&(ref>=4)),'byReferenceDepth':[{'label':label,**sub(mask)}for label,mask in zip(h.RANGES,h.masks(ref))],'referenceMissingCoverage':missing_coverage}
comparisons={}
after_primary=json.loads((D/'COMMON_GEOMETRY_RESULTS.json').read_text())
def check_primary_counts(secondary,before_primary,after_primary):
 for key in ['all','referenceBelow4m','referenceAtLeast4m']:
  c=secondary[key]['coverage']
  assert c['beforePaired']==before_primary[key]['statistics']['count']
  assert c['afterPaired']==after_primary[key]['statistics']['count']
 for sec,bef,aft in zip(secondary['byReferenceDepth'],before_primary['byReferenceDepth'],after_primary['byReferenceDepth']):
  assert sec['label']==bef['label']==aft['label']
  assert sec['coverage']['scheduled']==bef['scheduled']==aft['scheduled']
  assert sec['coverage']['beforePaired']==bef['statistics']['count'] and sec['coverage']['afterPaired']==aft['statistics']['count']
 c=secondary['all']['coverage'];m=secondary['referenceMissingCoverage'];b=before_primary['availability'];a=after_primary['availability']
 assert b['referenceOnly']==c['gainedPaired']+c['neitherPaired'] and a['referenceOnly']==c['lostPaired']+c['neitherPaired']
 assert b['TSDFOnly']==m['bothMapperHit']+m['beforeMapperOnly'] and a['TSDFOnly']==m['bothMapperHit']+m['afterMapperOnly']
 assert b['neither']==m['afterMapperOnly']+m['neitherMapperHit'] and a['neither']==m['beforeMapperOnly']+m['neitherMapperHit']
for label,old_arm in [('B','B'),('C1_N2','C1')]:
 before_primary=json.loads((OLD/old_arm/'COMMON_GEOMETRY_RESULTS.json').read_text())
 refs=[];befores=[];afters=[];frames=[]
 for name in ids:
  with np.load(R/'evaluation/faro'/(name+'.npz'),allow_pickle=False)as rf,np.load(OLD/old_arm/'evaluation/tsdf'/(name+'.npz'),allow_pickle=False)as bf,np.load(D/'evaluation/tsdf'/(name+'.npz'),allow_pickle=False)as af:
   assert np.array_equal(rf['row'],bf['row'])and np.array_equal(rf['row'],af['row'])
   assert np.array_equal(rf['column'],bf['column'])and np.array_equal(rf['column'],af['column'])
   ref=rf['axialMetres'].copy();before=bf['axialMetres'].copy();after=af['axialMetres'].copy()
   assert len(ref)==len(before)==len(after)==46065
  node=summary(ref,before,after);index=len(frames)
  assert before_primary['frames'][index]['frameID']==after_primary['frames'][index]['frameID']==name
  check_primary_counts(node,before_primary['frames'][index],after_primary['frames'][index])
  frames.append({'frameID':name,**node});refs.append(ref);befores.append(before);afters.append(after)
 ref=np.concatenate(refs);before=np.concatenate(befores);after=np.concatenate(afters);assert len(ref)==1335885
 pooled=summary(ref,before,after);check_primary_counts(pooled,before_primary['pooled'],after_primary['pooled'])
 comparisons[label]={'before':label,'after':'C1_N3','pooled':pooled,'frames':frames}
 del refs,befores,afters,ref,before,after
h.dump(D/'SECONDARY_COMMON_PAIRS.json',{'status':'completed','scope':'Secondary exact-common-paired and paired-coverage-transition analysis, no mesh query','views':29,'scheduledRays':1335885,'pixelOffset':0,'sampleStride':4,'comparisons':comparisons,'fittingPerformed':False,'physicalAuthority':False,'missingHitMeansFree':False,'referenceMissingErrorsImputed':False,'baselineMissingErrorsImputed':False,'newMissingErrorsImputed':False,'limits':['Common-subset errors alone exclude gained/lost paired rays; inspect transition denominators and available-side errors','Reference-missing availability is separate, never assigned a reference depth','No weighted winner, safety percentage, route or hazard inference']})
print('Secondary saved-array comparisons completed for B and C1_N2; no geometry query.')
