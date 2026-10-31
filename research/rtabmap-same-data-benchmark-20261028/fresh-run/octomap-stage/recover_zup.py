import sqlite3,pathlib,json,hashlib,struct,numpy as np,datetime
s=pathlib.Path('/workspace/scratch/90f3f6703064/research/rtabmap-same-data-benchmark-20261028/fresh-run/octomap-stage');d=sqlite3.connect('file:'+str(s/'zup-mapper/map.db')+'?mode=ro',uri=True)
assert d.execute('pragma quick_check').fetchone()[0]=='ok'; rows=d.execute('select id,pose from Node order by id').fetchall();assert len(rows)==265
inp=(s.parent/'adapter/INPUTS.tsv').read_text().splitlines();O=np.array([[0,0,1,0],[-1,0,0,0],[0,-1,0,0],[0,0,0,1.]])
out=[];errors=[]
for (i,blob),line in zip(rows,inp):
 assert len(blob)==48
 n=np.eye(4);n[:3]=np.frombuffer(blob,dtype='<f4').reshape(3,4);p=n@O;expected=np.array(list(map(float,line.split()[9:]))).reshape(3,4);errors.append(float(np.max(abs(p[:3]-expected))));assert errors[-1]<1e-4
 out.append(str(i)+'\t'+'\t'.join(format(v,'.10g')for v in p[:3].flat))
assert [x[0]for x in rows]==list(range(1,266))
f=s/'zup-mapper/RECOVERED_POSES.tsv';f.write_text('\n'.join(out)+'\n')
counts=d.execute('select count(*),sum(length(image)>0),sum(length(depth)>0),sum(length(ground_cells)>0),sum(length(obstacle_cells)>0) from Data').fetchone()
r={'recoveredUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'quickCheck':'ok','databaseNodes':265,'dataCounts':counts,'allNodeOpticalPoseMaxAbsError':max(errors),'databaseSHA256':hashlib.sha256((s/'zup-mapper/map.db').read_bytes()).hexdigest(),'recoveredPosesSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'originalPartialPoseLines':len((s/'zup-mapper/POSES.tsv').read_text().splitlines()),'mapperInputReplay':False,'originalMapperFinalReceiptMissing':True,'processVisibility':'No matching process in current namespace; host-wide absence not established; log unchanged since18:51 across checks','interruptedRunCPUConservativeChargeSeconds':420}
(s/'ZUP_RECOVERY_RECEIPT.json').write_text(json.dumps(r,indent=2)+'\n');(s/'logs/zup-interruption-charge_RESOURCE.json').write_text(json.dumps({'childCPUSeconds':420,'reason':'conservative charge for interrupted265-frame mapping and partial export; actual CPU receipt unavailable'},indent=2)+'\n');print(r)
