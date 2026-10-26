"""Simulation-only OctoMap-state import into the existing SurfaceCell model.

This adapter does NOT fuse rays, classify by a local probability threshold, fit
a new floor, remove raw observations, search a route, or grant physical rights.
The native producer owns keys/occupancy and the v1 source owns floor/support.
"""
from pathlib import Path
import hashlib,sys
import numpy as np

HERE=Path(__file__).resolve().parent
V1=HERE.parent/'map/map_builder.py'
V1_SHA256='8495c38ea6bf8893d5c064510a5cf4e615071ec11676ee168468ea2b14d95ba2'
if hashlib.sha256(V1.read_bytes()).hexdigest()!=V1_SHA256:
    raise RuntimeError('original floor/support source changed')
sys.path.insert(0,str(V1.parent))
from map_builder import surface_classification


def _integers(value,name,size=None):
    a=np.asarray(value)
    if a.ndim!=1 or a.dtype.kind not in 'iu' or size is not None and len(a)!=size:
        raise ValueError(name+' must be bounded integer vector')
    return a


def query_flags(query,expected=None):
    required={'known','occupied','probability','logOdds','hitScans','freeScans'}
    if set(query)!=required:raise ValueError('exact native query fields required')
    known=_integers(query['known'],'known');n=len(known)
    if n>5000000 or expected is not None and n!=expected:raise ValueError('query count')
    occupied=_integers(query['occupied'],'occupied',n)
    hits=_integers(query['hitScans'],'hitScans',n);frees=_integers(query['freeScans'],'freeScans',n)
    probability=np.asarray(query['probability']);log_odds=np.asarray(query['logOdds'])
    if (probability.shape!=(n,) or log_odds.shape!=(n,)
        or probability.dtype.kind not in 'fiu' or log_odds.dtype.kind not in 'fiu'):
        raise ValueError('native score shape/type')
    if (np.any(known>1) or np.any(occupied>1) or np.any(hits>294) or np.any(frees>294)
        or np.any(known<0) or np.any(occupied<0) or np.any(hits<0) or np.any(frees<0)):
        raise ValueError('native flag/scan bounds')
    k=known.astype(bool);o=occupied.astype(bool)
    if (np.any(o&~k) or not np.isfinite(probability[k]).all() or not np.isfinite(log_odds[k]).all()
        or np.any(probability[k]<0) or np.any(probability[k]>1)):
        raise ValueError('invalid native known/occupied/score state')
    # Occupancy comes ONLY from upstream isNodeOccupied, not a Python threshold.
    return k,o,hits,frees


def classify(ijk,vmin,vmax,vviews,width,height,raw_index,native_query_index,
             native_query,association_complete):
    """raw/native pairs are DISTINCT and refer to measured-endpoint native keys.

    The driver must establish completeness from every original raw voxel member
    using native coordToKeyChecked. A centre query is not equivalent by fiat.
    Missing/incomplete association is unknown and cannot reopen a raw obstacle.
    """
    ijk=np.asarray(ijk);n=len(ijk)
    if (ijk.shape!=(n,3) or ijk.dtype.kind not in 'iu' or n>2000000
        or isinstance(width,bool) or isinstance(height,bool) or not isinstance(width,int)
        or not isinstance(height,int) or width<=0 or height<=0 or width*height>250000):
        raise ValueError('raw voxel/surface dimensions')
    vmin=np.asarray(vmin,dtype=float);vmax=np.asarray(vmax,dtype=float)
    views=_integers(vviews,'source frame counts',n)
    complete=np.asarray(association_complete)
    if (vmin.shape!=(n,) or vmax.shape!=(n,) or complete.shape!=(n,) or complete.dtype!=np.bool_
        or not np.isfinite(vmin).all() or not np.isfinite(vmax).all() or np.any(vmin>vmax)
        or np.any(views<1) or np.any(views>294) or np.any(ijk<0)
        or np.any(ijk[:,0]>=width*2) or np.any(ijk[:,2]>=height*2)):
        raise ValueError('invalid original raw voxel fields')
    raw=_integers(raw_index,'raw association index');native=_integers(native_query_index,'native query index',len(raw))
    known,occupied,hits,frees=query_flags(native_query)
    if (len(raw)>5000000 or np.any(raw<0) or np.any(raw>=n)
        or np.any(native<0) or np.any(native>=len(known))):raise ValueError('association bounds')
    if len(raw):
        order=np.lexsort((native,raw));a=raw[order];b=native[order]
        if np.any((a[1:]==a[:-1])&(b[1:]==b[:-1])):raise ValueError('duplicate raw/native key associations')
    raw=raw.astype(np.int64,copy=False);native=native.astype(np.int64,copy=False)
    count=np.bincount(raw,minlength=n)
    def counts(flag):return np.bincount(raw,weights=np.asarray(flag,dtype=np.uint8)[native],minlength=n)
    known_all=(count>0)&(counts(known)==count)
    occupied_any=counts(occupied)>0
    free_evidence_all=(count>0)&(counts(frees>0)==count)
    hit_evidence_all=(count>0)&(counts(hits>0)==count)
    raw_free=complete&known_all&~occupied_any&free_evidence_all&hit_evidence_all
    # EXACT original frozen v1 support/ground/contradiction implementation.
    support,_,raw_obstacle,contradiction,ground=surface_classification(ijk,vmin,vmax,views,width,height)
    surface=(ijk[:,2]//2)*width+ijk[:,0]//2
    total=width*height
    positive_occupied=np.zeros(total,bool);positive_unresolved=np.zeros(total,bool);below=np.zeros(total,bool)
    positive_occupied[surface[raw_obstacle&occupied_any]]=True
    positive_unresolved[surface[raw_obstacle&~raw_free&~occupied_any]]=True
    below[surface[contradiction]]=True
    # Diagnostic ONLY. The unchanged v1 floor prior is not current support or
    # stair/drop safety, even when a previously seen ground key becomes free.
    ground_free=ground&raw_free
    surface_ground_free=np.zeros(total,bool);surface_ground_free[surface[ground_free]]=True
    blocked=~support|positive_occupied|positive_unresolved|below
    return {'support':support,'blocked':blocked,'rawObstacle':raw_obstacle,'rawGround':ground,
            'rawBelowFloorContradiction':contradiction,'rawKnownFreeWithEvidence':raw_free,
            'rawAssociationCount':count,'rawKnownAll':known_all,'rawOccupiedAny':occupied_any,
            'rawFreeEvidenceAll':free_evidence_all,'rawHitEvidenceAll':hit_evidence_all,
            'surfacePositiveOccupied':positive_occupied,'surfacePositiveUnresolved':positive_unresolved,
            'surfaceBelowFloorContradiction':below,'surfaceMissingSupport':~support,
            'rawGroundNativeFreeWithEvidence':ground_free,
            'surfaceGroundNativeFreeConflict':surface_ground_free,
            'physicalAuthority':False}


def combine_coverage(projected90,native_query90):
    """Re-evaluate original coverage on ALL newly eligible v2 cells first."""
    projected=np.asarray(projected90)
    if projected.ndim!=2 or projected.shape[1]!=90 or projected.dtype!=np.bool_:
        raise ValueError('original90-sample bool coverage required')
    known,occupied,_,frees=query_flags(native_query90,projected.size)
    shape=projected.shape
    known=known.reshape(shape);occupied=occupied.reshape(shape);free=frees.reshape(shape)>0
    native_free=known&~occupied&free
    admitted=projected&native_free
    return {'sampleAdmitted':admitted,'cellClearanceEstimated':admitted.all(axis=1),
            'sampleMissingOriginalProjection':~projected,'sampleNativeUnknown':~known,
            'sampleNativeOccupied':occupied,'sampleNoActualFreeScan':known&~occupied&~free,
            'physicalAuthority':False}
