"""Independent output-ledger validation; execute only after primary CPU release."""
import os
for k in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS'):os.environ[k]='1'
from pathlib import Path
import argparse,json,hashlib
import numpy as np
p=argparse.ArgumentParser();p.add_argument('output');p.add_argument('--report',required=True);p.add_argument('--leaf-file',choices=['leaves_phone_frame.bin','leaves_dataset_world.bin'],required=True);a=p.parse_args();out=Path(a.output)
checks=[]
def check(v,label):
 if not bool(v):raise AssertionError(label)
 checks.append(label)
def sha(p):
 h=hashlib.sha256()
 with p.open('rb')as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
receipt=dict(x.split('=',1) for x in (out/'RESULT.txt').read_text().splitlines())
leaf=out/a.leaf_file;dtype=np.dtype([('xyz','<f4',(3,)),('size','<f4'),('prob','<f4'),('type','<i4'),('ref','<i4'),('occupied','<i4')])
check(dtype.itemsize==32,'documented 32-byte record size');check(leaf.stat().st_size%32==0,'whole leaf records')
z=np.memmap(leaf,dtype=dtype,mode='r');check(len(z)==int(receipt['leafRecords']),'native leaf count')
check(np.isfinite(z['xyz']).all(),'finite coordinates');check(np.isfinite(z['prob']).all(),'finite probabilities');check(np.all((z['prob']>0)&(z['prob']<1)),'probabilities strictly between zero and one');check(np.all(z['size']>0),'positive leaf sizes');check(np.isin(z['occupied'],[0,1]).all(),'binary occupancy');check(np.isin(z['type'],[-1,0,1,100]).all(),'released native semantic types');check(np.all((z['ref']>=0)&(z['ref']<=265)),'reference ID range')
occ=z['occupied']==1;free=~occ;ground=occ&(z['type']==1);other=occ&(z['type']!=1)
for name,mask,count in [('occupied_leaf_indices.u64',occ,'occupiedLeaves'),('free_leaf_indices.u64',free,'freeLeaves'),('native_ground_occupied_leaf_indices.u64',ground,'nativeGroundOccupiedLeaves'),('other_occupied_leaf_indices.u64',other,'otherOccupiedLeaves')]:
 idx=np.fromfile(out/name,dtype='<u8');check(len(idx)==int(receipt[count]),name+' receipt count');check(np.array_equal(idx,np.flatnonzero(mask)),name+' exact independent category reconstruction')
check(np.all(z['prob'][occ]>=.5-1e-7),'occupied probabilities consistent allowing float export rounding');check(np.all(z['prob'][free]<=.5+1e-7),'free probabilities consistent allowing float export rounding');check(np.all(z['prob']>=.1192-1e-6)and np.all(z['prob']<=.971+1e-6),'frozen probability clamp bounds')
rows=[r.split('\t')for r in (out/'FRAMES.tsv').read_text().splitlines()[1:]];check([int(r[0])for r in rows]==list(range(1,266)),'exact ordered 265 frame records');check(all(int(r[3])==0 for r in rows),'no supplied free-cell grids');check(all(int(r[1])+int(r[2])>0 for r in rows),'every frame supplies observations');check(int(receipt['frames'])==265,'native final frames');check(receipt['unknownPolicy']=='unrepresented_not_free','unknown policy');check(receipt['verifiedFloorSupport']=='false','ground not verified floor support')
report={'status':'passed','checks':checks,'checkCount':len(checks),'leaves':len(z),'freeLeavesRetainingGroundType':int(np.sum(free&(z['type']==1))),'freeLeavesRetainingObstacleType':int(np.sum(free&(z['type']==100))),'probabilityWithin1eMinus7OfThreshold':int(np.sum(abs(z['prob']-.5)<=1e-7)),'sourceHashes':{f.name:sha(f) for f in [leaf,out/'RESULT.txt',out/'FRAMES.tsv',out/'PARAMETERS.tsv']},'nativeMappingIndependentlyRerun':False,'physicalSafetyEstablished':False}
Path(a.report).write_text(json.dumps(report,indent=2,sort_keys=True)+'\n');print(json.dumps(report,indent=2))
