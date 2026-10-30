#!/usr/bin/env python3
"""Stdlib-only exact public-data materialization. No engine/NumPy imports.
Preserves fixed49 prior-selected rows and adds2 exact Coffee C saved-state rows.
"""
import argparse,gzip,hashlib,json,math,pathlib,struct
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
SEL=R/'research/rapier-analytic-comparator-source-20261030/REAL_ROOM_SELECTION.json'
REG=R/'research/conference-replay-input-inventory-20261029/evidence/REGISTRATION_RESULT.json'
COFFEE=W/'coffee-recovered-source/textured.obj';CONF=W/'conference-source-recovery/extracted-001/textured.obj'
FLOOR=-1.6301633051396203

def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def enc(x):return (json.dumps(x,sort_keys=True,separators=(',',':'),allow_nan=False)+'\n').encode()
def require(x,m):
 if not x:raise ValueError(m)
def inputs():
 s=json.loads(SEL.read_text());d={str(SEL):sha(SEL),str(REG):sha(REG)}
 for name,h in s['sources'].items():
  p=W/name;require(sha(p)==h,'selection dependency drift '+name);d[str(p)]=h
 for p,h in [(COFFEE,'f10de085426143ad095fefc713b4966d22fdf08beda9ff9ead759019a0a8306a'),(CONF,'79cfd017b9c88dca840c8ec969208a93593b03f600303d70cc6777b7c55438a1')]:require(sha(p)==h,'mesh mismatch');d[str(p)]=h
 return s,d

def mesh(p,scene):
 r=json.loads(REG.read_text());Q=r['rotationOBJToLevel'];t=r['translationOBJToLevel']
 require(r['scale']==1 and r['acceptedForComparator'] and not r['referenceUsed'],'registration contract')
 vs=[];fs=[];vb=bytearray();fb=bytearray();maxerr=0;originalkeys=set();floatkeys=set()
 for line in p.open():
  x=line.split()
  if not x:continue
  if x[0]=='v':
   require(len(x)==4,'vertex format');v=list(map(float,x[1:]));require(all(map(math.isfinite,v)),'nonfinite')
   if scene=='conference':
    b=[sum(v[j]*Q[i][j] for j in range(3))+t[i] for i in range(3)];v=[b[0],b[2],-b[1]]
   packed=struct.pack('<fff',*v);converted=struct.unpack('<fff',packed)
   originalkeys.add(tuple(v));floatkeys.add(converted);maxerr=max(maxerr,max(abs(a-b)for a,b in zip(v,converted)));vb.extend(packed);vs.append(v)
  elif x[0]=='f':
   require(len(x)==4,'face format');f=[int(y.split('/')[0])-1 for y in x[1:]];fs.append(f);fb.extend(struct.pack('<III',*f))
 expected=(51965,87370) if scene=='coffee' else (18398,29366)
 require((len(vs),len(fs))==expected,'cardinality');require(all(0<=i<len(vs)for f in fs for i in f),'index')
 vh=hashlib.sha256(vb).hexdigest();fh=hashlib.sha256(fb).hexdigest()
 if scene=='conference':require(vh=='50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb' and fh=='2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324','executed Float32 buffer mismatch')
 return bytes(vb),bytes(fb),{'sourceOBJ_SHA256':sha(p),'vertices':len(vs),'triangles':len(fs),'vertexBytesSHA256':vh,'indexBytesSHA256':fh,'maxAbsCoordinateFloat32ConversionMetres':maxerr,'distinctOriginalXYZ':len(originalkeys),'distinctFloat32XYZ':len(floatkeys),'additionalFloat32ExactAliases':len(originalkeys)-len(floatkeys),'sourceTriangleOrdinalWindingPreserved':True,'frame':('original OBJ +Y up; identity normalization in raw VTK arm' if scene=='coffee' else 'historical rigid registration comparator; exact executed Float32 bytes, not calibrated camera frame'),'cameraMeshCalibrationEstablished':False}

def probe(scene,name,index,e,evidence,label=None):
 require(e['kind'] in ('initial','terminal','stationary','translate','turn'),'event kind')
 d=[b-a for a,b in zip(e['a'],e['b'])];n=math.sqrt(sum(x*x for x in d))
 # A cap breach is preserved as an unsupported row, not shortened or dropped.
 return {'id':label or f'{scene}:{name}:{index}','kind':'turn' if e['kind']=='turn' else 'translation' if e['kind']=='translate' else 'stationary','foot':e['a'],'yawRadians':e['yaw'],'endYawRadians':e['yaw']+e['dyaw'],'desiredDelta':d,'sourceEvent':index,'sourceKind':e['kind'],'sourcePath':name,'originalEnd':e['b'],'inputAdmissible':n<=.025+1e-12,'unavailableReason':None if n<=.025+1e-12 else 'source desired displacement exceeds unchanged0.025m cap','independentEvidence':evidence,'physicalAuthority':False}

def selected_probes(s):
 coffee_schedule=json.loads((W/next(n for n in s['sources'] if n.endswith('SCHEDULE_0_8.json'))).read_text())['paths'][0]['events']
 wanted_c={x['eventIndex']:x['kind']for x in s['coffeeRawSourcePath0To8']};wanted_f={n:{x['eventIndex']:x['kind']for x in rows}for n,rows in s['conferenceAllSevenFrozenRequests'].items()}
 coffee=[];conference=[];cstates={}
 cp=W/'coffee-joint-route-body-attempt-001/comparison/CONTACTS.jsonl.gz';fp=W/'conference-body-comparison-attempt-001/comparison/CONTACTS.jsonl.gz'
 with gzip.open(cp,'rt') as f:
  for line in f:
   r=json.loads(line)
   if r['arm']=='A_raw_identity' and r['event'] in wanted_c:
    i=r['event'];e=coffee_schedule[i];require(e['kind']==wanted_c[i]==r['kind'],'Coffee kind');coffee.append(probe('coffee','0_to_8',i,e,{'sourceLogSHA256':sha(cp),'vtk':r['contacts'],'vtkGroundExemptions':False,'coverage':'unknown','support':'unknown'}))
   if r['arm']=='C_ground_follow' and r['event'] in (0,9,10):cstates[r['event']]=r
 with gzip.open(fp,'rt') as f:
  for line in f:
   r=json.loads(line);name=r['path'];i=r['event']
   if name in wanted_f and i in wanted_f[name]:
    e=r['authoredIncrement'];require(e['kind']==wanted_f[name][i],'Conference kind');conference.append(probe('conference',name,i,e,{'sourceLogSHA256':sha(fp),'vtk':r['contacts'],'vtkGroundExemptions':False,'coverage':'unknown','support':'unknown'}))
 require(len(coffee)==7 and len(conference)==42,'fixed49 rows not recovered')
 require([r['sourceEvent']for r in coffee]==list(wanted_c),'Coffee order')
 require([(r['sourcePath'],r['sourceEvent'])for r in conference]==[(n,i)for n,x in wanted_f.items()for i in x],'Conference order')
 # Exact accepted event9 is retained before event10 refusal. Never use rejected proposed end.
 receipt=json.loads((W/'coffee-joint-route-body-attempt-001/comparison/RECEIPT.json').read_text());arm=next(x for x in receipt['arms'] if x['arm']=='C')
 require(arm['status']=='nonGroundCandidateContactStopped' and arm['attemptedEvents']==11 and arm['refusalPhase']=='proposedIncrementContact','C refusal identity')
 last=cstates[9];refused=cstates[10];require(all(not x[k]['nonGroundContactCount']for x in last['contacts']for k in ('actualBody','horizontalMargin')),'C9 not accepted')
 require(any(x[k]['nonGroundContactCount']for x in refused['contacts']for k in ('actualBody','horizontalMargin')),'C10 not refused')
 state=list(last['adjustedEndLocal']);state[1]+=FLOOR;require(state==arm['lastAcceptedSourcePosition'],'C frame mismatch')
 e10=coffee_schedule[10];require(e10['kind']=='turn','C10 kind');yaw=e10['yaw'];prev=coffee_schedule[9];require(abs((prev['yaw']+prev['dyaw'])-yaw)<1e-12,'saved yaw continuity')
 evidence={'sourceLogSHA256':sha(cp),'acceptedEvent9':last,'refusedEvent10':refused,'sourceReceiptSHA256':s['sources']['coffee-joint-route-body-attempt-001/comparison/RECEIPT.json'],'savedStateSourcePosition':state,'normalization':{'localToSourceTranslation':[0,FLOOR,0],'rotation':'identity'},'vtkStaticAtExactlyThisState':'unknown; event9 swept enclosure evidence retained, no new static oracle','coverage':'unknown','support':'historical9-ray support observations only, not full support','physicalAuthority':False}
 stationary={'kind':'stationary','a':state,'b':state,'yaw':yaw,'dyaw':0}
 turn={'kind':'turn','a':state,'b':state,'yaw':yaw,'dyaw':e10['dyaw']}
 coffee.extend([probe('coffee','ground_follow',9,stationary,evidence,'coffee:C_saved_before10:zero'),probe('coffee','ground_follow',10,turn,evidence,'coffee:C_saved_before10:turn')])
 return {'coffee':coffee,'conference':conference}

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',type=pathlib.Path,required=True);a=ap.parse_args();s,before=inputs();a.out.mkdir(exist_ok=False)
 report={'schema':1,'status':'materialized_source_only_no_Rapier_execution','inputSHA256':before,'selectionSHA256':sha(SEL),'scenes':{},'physicalAuthority':False,'rowsSelectedBeforeEngineResults':True}
 probes=selected_probes(s)
 for name,p in [('coffee',COFFEE),('conference',CONF)]:
  v,f,m=mesh(p,name);(a.out/(name+'.vertices.f32')).write_bytes(v);(a.out/(name+'.indices.u32')).write_bytes(f);b=enc(probes[name]);(a.out/(name+'.probes.json')).write_bytes(b);m['probeSHA256']=hashlib.sha256(b).hexdigest();m['probeCount']=len(probes[name]);m['unsupportedOversize']=sum(not p['inputAdmissible']for p in probes[name]);report['scenes'][name]=m
 require(inputs()[1]==before,'inputs changed');report['fixedOriginalRows']=49;report['additionalSavedGroundRows']=2;report['maximumNestedRows']=408
 report['files']={p.name:{'sha256':sha(p),'bytes':p.stat().st_size}for p in sorted(a.out.iterdir())};(a.out/'MATERIALIZATION.json').write_bytes(enc(report));print(json.dumps(report,indent=2))
if __name__=='__main__':main()
