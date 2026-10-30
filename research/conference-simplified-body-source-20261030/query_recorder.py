"""Separate bounded recorder for NEW trajectories; original fixed recorder untouched."""
import hashlib,json
MAX_TOTAL_IDS=200000;MAX_LOGICAL_BYTES=8*1024**2;MAX_TRIANGLES=29366
COUNTS=[796,1101,653,889,1740,1145,1146]
class BoundedQueryHitRecorder:
    def __init__(self,frozen):
        if len(frozen['paths'])!=7 or [p['eventCount']for p in frozen['paths']]!=COUNTS or frozen['totalEvents']!=7470:
            raise ValueError('exact bounded seven-candidate schedule required')
        self.sequence=[(p['name'],n)for p in frozen['paths']for n in range(p['eventCount'])]
        self.total=self.logical=self.completed=self.candidates=0;self.digest=hashlib.sha256();self.active=None
        self.paths=[{'name':p['name'],'completedEvents':0,'arms':{k:{'contactEvents':0,'hitOccurrences':0,'uniqueIDs':set()}for k in ('actualBody','horizontalMargin')}}for p in frozen['paths']]
        self.byname={p['name']:p for p in self.paths}
    def begin_event(self,name,index,box_offset):
        if self.active is not None or self.completed>=7470 or (name,index)!=self.sequence[self.completed] or box_offset!=self.completed*2:
            raise RuntimeError('new-trajectory event/query sequence mismatch')
        self.active={'name':name,'event':index,'firstQuery':box_offset+1,'lastSlot':-1,'ids':[[],[]]}
    def record_hit(self,query,cell_id,reason):
        if self.active is None or type(query)is not int:raise RuntimeError('hit outside event/query')
        slot=query-self.active['firstQuery']
        if slot not in (0,1) or type(cell_id)is not int or not 0<=cell_id<MAX_TRIANGLES or reason not in ('boundaryIntersection','containedTriangleVertex'):
            raise RuntimeError('invalid callback hit identity')
        if slot<self.active['lastSlot']:raise RuntimeError('backwards nominal/margin callback query order')
        self.active['lastSlot']=slot
        if self.total>=MAX_TOTAL_IDS:raise RuntimeError('global logged-ID cap; incomplete')
        if len(self.active['ids'][slot])>=MAX_TRIANGLES:raise RuntimeError('per-query source triangle cap')
        self.active['ids'][slot].append(cell_id);self.total+=1
    def finish_event(self,result):
        if self.active is None:raise RuntimeError('no active query')
        candidate_pair=[];pending=[]
        for slot,kind in enumerate(('actualBody','horizontalMargin')):
            r=result[kind];ids=self.active['ids'][slot];count=r['nonGroundContactCount'];candidates=r['candidateTriangles']
            if type(count)is not int or type(candidates)is not int or not 0<=count<=candidates<=MAX_TRIANGLES or r['groundContactCount']!=0 or len(ids)!=count or len(set(ids))!=len(ids):
                raise RuntimeError('returned query count/complete-ID mismatch')
            if r['contact'] is not bool(ids) or (ids and ids[0]!=r['firstReferenceCellID']) or (not ids and r['firstReferenceCellID'] is not None):
                raise RuntimeError('returned first-hit identity mismatch')
            candidate_pair.append(candidates);pending.append((kind,ids))
        record={'path':self.active['name'],'event':self.active['event'],
                'actualBodyTriangleIDs':self.active['ids'][0],'horizontalMarginTriangleIDs':self.active['ids'][1]}
        data=(json.dumps(record,separators=(',',':'),allow_nan=False)+'\n').encode()
        if self.logical+len(data)>MAX_LOGICAL_BYTES:raise RuntimeError('ID-log logical byte cap; incomplete')
        path=self.byname[self.active['name']]
        for kind,ids in pending:
            a=path['arms'][kind];a['contactEvents']+=bool(ids);a['hitOccurrences']+=len(ids);a['uniqueIDs'].update(ids)
        path['completedEvents']+=1;self.digest.update(('%d,%d\n'%tuple(candidate_pair)).encode())
        self.candidates+=sum(candidate_pair);self.logical+=len(data);self.completed+=1;self.active=None
        return data
    def summary(self,require_complete=False):
        complete=self.completed==7470 and self.active is None
        if require_complete and not complete:raise RuntimeError('all-seven complete recording not established')
        return {'complete':complete,'completedEvents':self.completed,'loggedHitOccurrences':self.total,
          'candidateTriangles':self.candidates,'candidateCountStreamSHA256':self.digest.hexdigest(),
          'returnedQueryCountsMatched':complete,'oldPerEventCountEqualityRequired':False,
          'logicalBytes':self.logical,'fixedIDCap':MAX_TOTAL_IDS,'fixedLogicalByteCap':MAX_LOGICAL_BYTES,
          'geometryOrClassificationChanged':False,'physicalAuthority':False,
          'paths':[{'name':p['name'],'completedEvents':p['completedEvents'],'arms':{k:{
              'contactEvents':a['contactEvents'],'hitOccurrences':a['hitOccurrences'],
              'uniqueFaceCount':len(a['uniqueIDs']),'uniqueIDs':sorted(a['uniqueIDs'])}for k,a in p['arms'].items()}}for p in self.paths]}
