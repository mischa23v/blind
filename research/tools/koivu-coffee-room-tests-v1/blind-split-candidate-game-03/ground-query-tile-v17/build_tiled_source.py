"""Generate an additive tiled prepass from the exact frozen v6 contact method."""
from pathlib import Path
import hashlib,json,difflib

HERE=Path(__file__).resolve().parent
ORIGINAL=HERE.parent/'ground-obb-v6/oriented_ground_obb_container.py'
EXPECTED='7005ab752d855edfdb1295b401ea8ad9d66516a5813f716f1a7818677bb1c222'
TILER_EXPECTED='9a7015950867f095e2990c117918423496f9d659ca50c5e7f6a0f765e4d18188'
OLD_QUERY='''        self.ids.Reset();self.surface.locator.FindCellsWithinBounds(bounds,self.ids)
        self.box_queries+=1;self.check()
        count=self.ids.GetNumberOfIds()
        if count>self.maximum_candidate_cells:raise GeometryFailure('reference broad-phase candidate cap; not scored clear')
        candidate_ids=np.fromiter((self.ids.GetId(i)for i in range(count)),dtype=np.int64,count=count)
'''
NEW_QUERY='''        self.ids.Reset();candidate_ids=self._tiled_candidates(bounds)
        self.box_queries+=1;self.check()
        count=len(candidate_ids)
        if count>self.maximum_candidate_cells:raise GeometryFailure('reference broad-phase candidate cap; not scored clear')
'''

PREFIX='''"""Tiled negative-query prepass; positives replay the original v6 ordering.

Full original geometry, enclosure, membership, OBB filter and exact predicates
remain. Only a negative result may expose sorted skipped-ground preview IDs.
Any positive prepass returns the original same-box v6 result, preserving first
contact identity/height/reason and near-foot classification. Extra work is
explicit in optimization_rows and cumulative counters; no speed is promised.
"""
from pathlib import Path
import hashlib,sys,time
import numpy as np
import vtk
ROOT=Path(__file__).resolve().parents[1]
V6_SHA='''+repr(EXPECTED)+'''
TILER_SHA='''+repr(TILER_EXPECTED)+'''
for _path,_expected in ((ROOT/'ground-obb-v6/oriented_ground_obb_container.py',V6_SHA),
                        (ROOT/'ground-query-tile-13/tiled_bounds.py',TILER_SHA)):
    if hashlib.sha256(_path.read_bytes()).hexdigest()!=_expected:
        raise RuntimeError('frozen tiled scorer dependency changed: '+str(_path))
sys.path.insert(0,str(ROOT/'ground-obb-v6'))
from oriented_ground_obb_container import GroundOBBReferenceContainer,GeometryFailure
sys.path.insert(0,str(ROOT/'ground-query-tile-13'))
from tiled_bounds import find_cells_tiled,TiledBoundsUnavailable


class GroundTiledReferenceContainer(GroundOBBReferenceContainer):
    def __init__(self,*args,**kwargs):
        self.optimization_rows=[];self._v17_active=None
        super().__init__(*args,**kwargs)

    def _tiled_candidates(self,bounds):
        try:
            ids,receipt=find_cells_tiled(self.surface.locator,bounds,check=self.check,
                                        unique_cap=self.maximum_candidate_cells)
        except TiledBoundsUnavailable as error:
            self._v17_active['tiledFailureDetails']=error.details
            if error.details.get('uniqueIDs',0)>self.maximum_candidate_cells:
                raise GeometryFailure('reference broad-phase candidate cap; not scored clear')from error
            raise GeometryFailure('tiled query unavailable; not scored clear: '+str(error))from error
        self._v17_active['tiledQuery']=receipt
        digest_began=time.perf_counter()
        self._v17_active['sortedCandidateIDsSHA256']=hashlib.sha256(ids.astype('<i8',copy=False).tobytes(order='C')).hexdigest()
        self._v17_active['candidateDigestWallSeconds']=time.perf_counter()-digest_began
        return ids

    def contact_corners(self,corners):
        row={'index':len(self.optimization_rows),'completed':False,'exceptionType':None,
            'tiledQuery':None,'tiledFailureDetails':None,'sortedCandidateIDsSHA256':None,
            'candidateIDEncoding':'sorted unique original IDs, signed int64 little-endian, C order',
            'candidateDigestWallSeconds':None,'candidateDigestIncludedInPrepassTime':True,'prepassWallSeconds':0.,
            'fallbackWallSeconds':0.,'fallbackUsed':False,'fallbackCompleted':False,
            'prepassContact':None,'prepassFirstReferenceCellID':None,
            'prepassExactTriangleTests':0,'fallbackExactTriangleTests':0,
            'prepassBoxQueryDelta':0,'fallbackBoxQueryDelta':0,
            'returnedResultCountsDescribeReturnedPassOnly':True,
            'candidateOrderPolicy':'sorted union prepass; ANY positive replays original native order',
            'permittedNegativeResultDifferenceFields':['skippedGroundCandidateIDsFirst16'],
            'newCollisionGeometry':False,'physicalAuthority':False}
        self._v17_active=row;began=time.perf_counter()
        boxes_before=self.box_queries;triangles_before=self.triangle_queries
        try:
            pre_began=time.perf_counter()
            try:
                prepass=self._tiled_contact_corners(corners)
            finally:
                row['prepassWallSeconds']=time.perf_counter()-pre_began
                row['prepassExactTriangleTests']=self.triangle_queries-triangles_before
                row['prepassBoxQueryDelta']=self.box_queries-boxes_before
            row['prepassContact']=prepass['contact']
            row['prepassFirstReferenceCellID']=prepass['firstReferenceCellID']
            if prepass['contact']:
                row['fallbackUsed']=True;fallback_began=time.perf_counter()
                fallback_boxes=self.box_queries;fallback_triangles=self.triangle_queries
                try:
                    result=GroundOBBReferenceContainer.contact_corners(self,corners)
                finally:
                    row['fallbackWallSeconds']=time.perf_counter()-fallback_began
                    row['fallbackExactTriangleTests']=self.triangle_queries-fallback_triangles
                    row['fallbackBoxQueryDelta']=self.box_queries-fallback_boxes
                row['fallbackCompleted']=True
                if not result['contact']:
                    raise GeometryFailure('positive tiled prepass disagrees with original result; not scored clear')
                for field in ('candidateTriangles','nonGroundContactCount','skippedGroundCandidateCount',
                              'rejectedNonGroundBoundsCandidates','exactNonGroundTriangleTests'):
                    if prepass[field]!=result[field]:
                        raise GeometryFailure('tiled/original contact count disagreement: '+field)
            else:
                result=prepass
            row['returnedContact']=result['contact'];row['returnedFirstReferenceCellID']=result['firstReferenceCellID']
            row['returnedPassExactTriangleTests']=result['exactNonGroundTriangleTests']
            row['completed']=True
            return result
        except BaseException as error:
            row['exceptionType']=type(error).__name__
            raise
        finally:
            row['totalWallSeconds']=time.perf_counter()-began
            row['actualBoxQueryCounterDelta']=self.box_queries-boxes_before
            row['actualExactTriangleCounterDelta']=self.triangle_queries-triangles_before
            # On an interrupted/failed native call, no completed-call count is
            # invented. Successful rows report every tile plus original replay.
            row['nativeBoundsCallsTotal']=(row['tiledQuery']['tileQueries']+int(row['fallbackUsed']))if row['completed']else None
            row['fallbackNativeBoundsCalls']=int(row['fallbackUsed'])if row['completed']else None
            self.optimization_rows.append(row);self._v17_active=None

'''


def main():
    original=ORIGINAL.read_text()
    if hashlib.sha256(original.encode()).hexdigest()!=EXPECTED:raise ValueError('frozen v6 source pin')
    method=original[original.index('    def contact_corners(self,corners):'):]
    if method.count(OLD_QUERY)!=1:raise ValueError('original query anchor changed')
    changed=method.replace('    def contact_corners(self,corners):','    def _tiled_contact_corners(self,corners):',1).replace(OLD_QUERY,NEW_QUERY)
    restored=changed.replace('    def _tiled_contact_corners(self,corners):','    def contact_corners(self,corners):',1).replace(NEW_QUERY,OLD_QUERY)
    if restored!=method:raise ValueError('contact method changed beyond query block')
    generated=PREFIX+changed;target=HERE/'oriented_ground_tiled_container.py'
    if target.exists()and target.read_text()!=generated:raise ValueError('refusing to overwrite different source cut')
    target.write_text(generated)
    (HERE/'QUERY_METHOD.diff').write_text(''.join(difflib.unified_diff(method.splitlines(keepends=True),changed.splitlines(keepends=True),fromfile='frozen-v6-contact',tofile='tiled-prepass-contact')))
    receipt={'originalV6SHA256':EXPECTED,'originalTilerSHA256':TILER_EXPECTED,
        'generatedSHA256':hashlib.sha256(generated.encode()).hexdigest(),
        'contactMethodBytesIdenticalAfterRestoringOnlyQueryBlockAndName':restored==method,
        'positiveResultsUseOriginalUnmodifiedV6Method':True,'geometryChanged':False,'physicalAuthority':False}
    (HERE/'GENERATION_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))


if __name__=='__main__':main()
