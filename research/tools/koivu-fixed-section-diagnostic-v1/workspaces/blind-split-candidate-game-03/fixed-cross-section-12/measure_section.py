"""Read-only fixed frame39 section; same-segment phone/saved-reference proxies, no mesh queries."""
from pathlib import Path
import json,hashlib
import numpy as np
HERE=Path(__file__).resolve().parent;GAME=HERE.parent;WS=GAME.parent
PATHS={'metadata':GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz','phoneMask':GAME/'inputs/koivu_5cm_occthres_split0.7.npz','poses':WS/'blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 pins={k:{'path':str(p.relative_to(WS)),'sha256':sha(p)}for k,p in PATHS.items()}
 with np.load(PATHS['metadata'],allow_pickle=False)as z,np.load(PATHS['phoneMask'],allow_pickle=False)as m:
  frames=json.loads(PATHS['poses'].read_text())['frames'];cam=np.array([f['transform_matrix']for f in frames])[:,:3,3]@z['R'].T+z['t'];origin=z['lo'][:2]*float(z['res']);res=float(z['res']);shape=m['walk'].shape
  centre=cam[38,:2];tangent=cam[39,:2]-cam[37,:2];tangent/=np.linalg.norm(tangent);normal=np.array([-tangent[1],tangent[0]])
  cuts=[-2.,0.,2.]
  for axis in range(2):
   edge=origin[axis]+np.arange(shape[axis]+1)*res
   values=(edge-centre[axis])/normal[axis];cuts.extend(values[(values>-2)&(values<2)])
  cuts=np.unique(cuts);mid=(cuts[:-1]+cuts[1:])/2;xy=centre+mid[:,None]*normal;ij=np.floor((xy-origin)/res).astype(int);inside=np.all((ij>=0)&(ij<shape),1)
  if not inside.all():raise ValueError('fixed section leaves map domain; not silently clipped')
  ind=tuple(ij.T);floor=np.isfinite(z['ref_floor_h'][ind]);coverage=z['ref_n'][ind]>0;low=np.isfinite(z['ref_low_max'][ind]);body=np.isfinite(z['ref_body_max'][ind]);strict=coverage&floor&~low&~body
  masks={'phonePermissiveWalk':m['walk'][ind],'referenceVertexColumnProxy':strict,'referenceSavedLargestComponentWalk':z['refWalk'][ind],'referenceFloorPresentNoBodyVertices_DIAGNOSTIC_NOT_CLEAR':coverage&floor&~body}
  def runs(v):
   starts=np.flatnonzero(v&~np.r_[False,v[:-1]]);ends=np.flatnonzero(v&~np.r_[v[1:],False])+1
   return [{'offsetStartMetres':float(cuts[s]),'offsetEndMetres':float(cuts[e]),'widthMetres':float(cuts[e]-cuts[s]),'containsAnchor':bool(cuts[s]<=0<=cuts[e]),'clippedAtSectionEndpoint':bool(s==0 or e==len(v)),'sourceStartXY':(centre+cuts[s]*normal).tolist(),'sourceEndXY':(centre+cuts[e]*normal).tolist()}for s,e in zip(starts,ends)]
  rows=[]
  for n,(i,j)in enumerate(ij):rows.append({'offsetIntervalMetres':[float(cuts[n]),float(cuts[n+1])],'sourceIJ':[int(i),int(j)],'phoneWalk':bool(m['walk'][i,j]),'phoneSupport':bool(m['support'][i,j]),'phoneLow1':bool(m['low1'][i,j]),'phoneHighObstacle':bool(m['highObstacle'][i,j]),'phoneHighUnknown':bool(m['highUnknown'][i,j]),'referenceAnyVertexCount':int(z['ref_n'][i,j]),'referenceFloorSamplePresent':bool(floor[n]),'referenceLowBandVertexPresent':bool(low[n]),'referenceBodyBandVertexPresent':bool(body[n])})
  result={'scope':'Same fixed segment, model proxies only; not measured physical passage clearance','selectionRule':'Original frame39 in previously fixed disputed western ROI; original frame38→40 camera displacement defines local aisle tangent. Chosen before reference-column results; not optimized for width. Exact photo gap identity unverified.','anchorFrameIndex1Based':39,'tangentFrames1Based':[38,40],'sourceAnchorXY':centre.tolist(),'sourceUnitTangent':tangent.tolist(),'sourceUnitCrossSectionNormal':normal.tolist(),'segmentOffsetBoundsMetres':[-2,2],'sourceGridResolutionMetres':res,'nativePlannerRasterNotUsed':True,'crossSectionCellTraversal':'exact intersections with source raster edges; interval midpoint identifies cell; no interpolated geometry','clearRunsByModelProxy':{k:runs(v)for k,v in masks.items()},'referenceVertexCoverageLengthMetres':float(np.diff(cuts)[coverage].sum()),'referenceFloorSampleLengthMetres':float(np.diff(cuts)[floor].sum()),'cells':rows,'referenceBandDefinitionsMetres':{'low_halfOpen':[.015,.30],'body_halfOpen':[.30,1.80],'floor_open':[-.06,.06]},'limits':['Reference values are vertex-column summaries, not triangle intersection or continuous-volume clearance.','No vertices does not establish observed free space; reference cleaned/completed and different capture time.','Global floor registration can put floor vertices in low obstacle band.','No chair/table/wall surfaces are semantically identified.','Camera centre and short chronological tangent need not equal body centre or aisle axis.','A single fixed cross-section does not establish a traversable corridor or loop.','Section clipped run lengths are lower bounds within the fixed segment, not complete gap widths.'],'inputPins':pins,'scriptSHA256':sha(Path(__file__)),'newReferenceQueries':0,'mapEdits':0,'routeQueries':0}
 if any(sha(PATHS[k])!=v['sha256']for k,v in pins.items()):raise ValueError('input changed')
 (HERE/'RESULT.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n');print(json.dumps({k:v for k,v in result.items()if k not in ['cells','inputPins']},indent=2))
if __name__=='__main__':main()
