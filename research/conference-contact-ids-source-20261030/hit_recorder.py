"""Stdlib-only bounded recorder; never computes or changes geometry/contact counts."""
import hashlib, json
MAX_TOTAL_IDS=200000
MAX_LOGICAL_BYTES=8*1024**2
MAX_TRIANGLES=29366

class FixedHitRecorder:
    def __init__(self,expected):
        if expected['eventCount']!=13704 or expected['totalHitOccurrences']!=108582:
            raise ValueError('exact saved-run count freeze required')
        paths=expected['paths']
        if not isinstance(paths,list) or len(paths)!=7 or [len(row['counts']) for row in paths]!=[1844,2052,1530,1555,2863,1923,1937]:
            raise ValueError('exact seven bounded event lists required')
        for row in paths:
            for pair in row['counts']:
                if not isinstance(pair,list) or len(pair)!=2 or any(type(n) is not int or not 0<=n<=MAX_TRIANGLES for n in pair):
                    raise ValueError('bounded integer hit count required')
        self.expected=expected;self.total=0;self.logical=0;self.candidate_digest=hashlib.sha256();self.candidates=0;self.completed=0;self.active=None
        self.sequence=[(row['name'],n,pair) for row in expected['paths'] for n,pair in enumerate(row['counts'])]
        if len(self.sequence)!=13704 or sum(sum(pair)for _,_,pair in self.sequence)!=108582:
            raise ValueError('count freeze inconsistent')
        if not 108582<=MAX_TOTAL_IDS:raise ValueError('frozen IDs exceed fixed cap before execution')
    def begin_event(self,name,index,box_offset):
        if self.active is not None or self.completed>=len(self.sequence):raise RuntimeError('recorder sequence state')
        ename,eindex,counts=self.sequence[self.completed]
        if (name,index)!=(ename,eindex) or box_offset!=self.completed*2:raise RuntimeError('event/query identity changed')
        self.active={'name':name,'event':index,'firstQuery':box_offset+1,'counts':counts,'ids':[[],[]]}
    def record_hit(self,query,cell_id,reason):
        if self.active is None:raise RuntimeError('hit outside authored increment')
        if type(query) is not int:raise RuntimeError('invalid hit query')
        slot=query-self.active['firstQuery']
        if slot not in (0,1) or type(cell_id) is not int or not 0<=cell_id<MAX_TRIANGLES:
            raise RuntimeError('invalid hit query/original face ID')
        if reason not in ('boundaryIntersection','containedTriangleVertex'):raise RuntimeError('unknown contact reason')
        ids=self.active['ids'][slot]
        if len(ids)>=self.active['counts'][slot]:raise RuntimeError('new query exceeds exact old per-envelope count')
        if self.total>=MAX_TOTAL_IDS:raise RuntimeError('global logged-ID cap; incomplete, not clear')
        ids.append(cell_id);self.total+=1
    def finish_event(self,result):
        if self.active is None:raise RuntimeError('no active increment')
        candidate_pair=[]
        for slot,kind in enumerate(('actualBody','horizontalMargin')):
            r=result[kind]
            if type(r['candidateTriangles']) is not int or not 0<=r['candidateTriangles']<=MAX_TRIANGLES:raise RuntimeError('candidate count outside source bound')
            candidate_pair.append(r['candidateTriangles'])
            ids=self.active['ids'][slot];expected=self.active['counts'][slot]
            if r['groundContactCount']!=0 or r['nonGroundContactCount']!=expected or len(ids)!=expected:
                raise RuntimeError('old per-event all-hit count not reproduced')
            if len(set(ids))!=len(ids):raise RuntimeError('duplicate original ID within query')
            if r['contact'] is not (expected>0):raise RuntimeError('contact/count contradiction')
            if expected and ids[0]!=r['firstReferenceCellID']:raise RuntimeError('first hit identity/order changed')
        record={'path':self.active['name'],'event':self.active['event'],
                'actualBodyTriangleIDs':self.active['ids'][0],
                'horizontalMarginTriangleIDs':self.active['ids'][1]}
        data=(json.dumps(record,separators=(',',':'),allow_nan=False)+'\n').encode()
        if self.logical+len(data)>MAX_LOGICAL_BYTES:raise RuntimeError('hit-ID logical output cap; incomplete')
        self.candidate_digest.update(('%d,%d\n'%tuple(candidate_pair)).encode())
        self.candidates+=sum(candidate_pair)
        self.logical+=len(data);self.completed+=1;self.active=None
        return data
    def summary(self,require_complete=False):
        candidate_match=self.candidates==self.expected['totalCandidateTriangles'] and self.candidate_digest.hexdigest()==self.expected['candidateCountStreamSHA256']
        complete=self.completed==13704 and self.total==108582 and self.active is None and candidate_match
        if require_complete and not complete:raise RuntimeError('complete ID stream not established')
        return {'complete':complete,'completedEvents':self.completed,'loggedHitOccurrences':self.total,
                'expectedHitOccurrences':108582,'candidateTriangles':self.candidates,
                'candidateCountStreamSHA256':self.candidate_digest.hexdigest(),'oldCandidateCountStreamMatched':candidate_match,'allOldPerEventCountsMatched':complete,
                'logicalBytes':self.logical,'fixedIDCap':MAX_TOTAL_IDS,'fixedLogicalByteCap':MAX_LOGICAL_BYTES,
                'geometryOrClassificationChanged':False,'physicalAuthority':False}
