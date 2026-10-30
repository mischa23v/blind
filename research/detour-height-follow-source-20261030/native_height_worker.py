#!/usr/bin/env python3
"""Source-only bounded diagnostic: released local polygon-state height traversal.
Not a controller for a physical person. No applied movement, new routes or reseeding.
"""
import argparse,ctypes as C,hashlib,json,math,os,pathlib,struct,sys,time
H=pathlib.Path(__file__).resolve().parent;REPO=H.parents[1];sys.path.insert(0,str(H))
from schedule_contract import load_schedules,XZ_TOLERANCE_METRES,unchanged_metadata
F=C.POINTER(C.c_float);I=C.POINTER(C.c_int)
class Config(C.Structure):
 _fields_=[(k,C.c_float)for k in ['radius','height','cell_size','cell_height','max_climb','max_slope']]+[(k,C.c_int)for k in ['max_cells','max_nodes']]
class Result(C.Structure):
 _fields_=[(k,C.c_uint32)for k in ['nearestStatus','moveStatus','heightStatus']]+[(k,C.c_int)for k in ['valid','failureStage','visitedCount']]+[(k,C.c_uint64)for k in ['previousRef','resultRef']]+[('horizontalResidual',C.c_double)]+[(k,C.c_float*3)for k in ['previous','projected','actual']]+[('visited',C.c_uint64*4096)]
STAGES={0:'none',1:'invalid_input',2:'nearest_poly_missing_or_status',3:'initial_association_xz_clamped',4:'initial_height_missing_or_status',5:'move_along_surface_status',6:'visited_chain_invalid',7:'movement_xz_clamped',8:'height_missing_or_status',9:'inactive_no_reseed',10:'allocation_failed'}
MESH_SHA={'coffee.vertices.f32':'e373a1dba8872e7d9201ba9e35e3f28598fdc660842a28f7867386b1d40fb503','coffee.indices.u32':'a7f7238114579bebe9951f35b2122559540d4076c3186bee767d2e8a2d096767','conference.vertices.f32':'50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb','conference.indices.u32':'2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324'}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def vector(v):return (C.c_float*3)(*v)
def xyz(v):
 q=list(v);return q if all(math.isfinite(x)for x in q)else None
def residual(a,b):return math.hypot(a[0]-b[0],a[2]-b[2])
def record(r):
 if not 0<=r.visitedCount<=4096:raise ValueError('Native visited count invalid')
 return {'queryExecuted':True,'valid':bool(r.valid),'failureStage':r.failureStage,'reason':STAGES.get(r.failureStage,'unknown_failure'),'nearestStatus':r.nearestStatus,'moveStatus':r.moveStatus,'heightStatus':r.heightStatus,'previousRef':r.previousRef,'resultRef':r.resultRef,'horizontalResidualToFloat32Request':r.horizontalResidual if math.isfinite(r.horizontalResidual)else None,'previousXYZ':xyz(r.previous),'projectedXYZBeforeHeight':xyz(r.projected),'actualXYZ':xyz(r.actual),'visitedReferences':list(r.visited)[:r.visitedCount]}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--mesh-root',type=pathlib.Path,required=True);ap.add_argument('--library',type=pathlib.Path,required=True);ap.add_argument('--library-sha256',required=True);ap.add_argument('--output',type=pathlib.Path,required=True);a=ap.parse_args()
 if a.output.exists()or len(a.library_sha256)!=64:raise ValueError('Fresh output and pinned library required')
 if C.sizeof(C.c_float)!=4 or C.sizeof(C.c_int)!=4 or sys.byteorder!='little':raise ValueError('Native array ABI mismatch')
 def verify():
  if sha(a.library)!=a.library_sha256:raise ValueError('Built library identity changed')
  for n,h in MESH_SHA.items():
   if sha(a.mesh_root/n)!=h:raise ValueError('Fixed original mesh changed')
 verify();schedules=load_schedules(REPO);a.output.mkdir(exist_ok=False);start_time=time.monotonic();payload=0;total=0;calls=0;begin_calls=0
 summary={'schema':1,'status':'started','movementApplied':False,'physicalAuthority':False,'supportEstablished':False,'semanticFloorEstablished':False,'arrivalEstablished':False,'sourceMeshHashes':MESH_SHA,'librarySHA256':a.library_sha256,'config':dict(radius=.225,height=1.75,cell_size=.025,cell_height=.025,max_climb=.025,max_slope=15,max_cells=250000,max_nodes=4096),'xzReportingToleranceMetres':XZ_TOLERANCE_METRES,'footOffsetMetres':0,'stateMethod':'official moveAlongSurface/getPolyHeight; active polygon ref and last native XYZ; not dtPathCorridor or global replan','scenes':[]}
 try:
  lib=C.CDLL(str(a.library.resolve()));lib.bn_build.argtypes=[F,C.c_int,I,C.c_int,C.POINTER(Config)];lib.bn_build.restype=C.c_void_p;lib.bn_destroy.argtypes=[C.c_void_p];lib.bn_destroy.restype=None;lib.bn_last_error.restype=C.c_char_p;lib.bn_excluded_span_count.argtypes=[C.c_void_p];lib.bn_excluded_span_count.restype=C.c_int
  lib.bh_abi_version.restype=C.c_int;lib.bh_result_size.restype=C.c_int
  if lib.bh_abi_version()!=1 or lib.bh_result_size()!=C.sizeof(Result):raise ValueError('Height result ABI mismatch')
  lib.bh_begin.argtypes=[C.c_void_p,F,C.POINTER(Result)];lib.bh_begin.restype=C.c_void_p;lib.bh_step.argtypes=[C.c_void_p,F,C.POINTER(Result)];lib.bh_step.restype=C.c_int;lib.bh_destroy.argtypes=[C.c_void_p];lib.bh_destroy.restype=None
  with (a.output/'events.jsonl').open('x')as out:
   for schedule in schedules:
    scene=schedule['scene'];vb=(a.mesh_root/(scene+'.vertices.f32')).read_bytes();ib=(a.mesh_root/(scene+'.indices.u32')).read_bytes()
    if len(vb)%12 or len(ib)%12 or any(j[0]>=len(vb)//12 for j in struct.iter_unpack('<I',ib)):raise ValueError('Mesh index format')
    v=(C.c_float*(len(vb)//4)).from_buffer_copy(vb);t=(C.c_int*(len(ib)//4)).from_buffer_copy(ib);cfg=Config(.225,1.75,.025,.025,.025,15,250000,4096)
    nav=None;state=None;native_prev=None;failed_reason=None;scene_summary={'scene':scene,'name':schedule['name'],'scheduledEvents':len(schedule['events']),'validEvents':0,'unavailableEvents':0,'firstUnavailableEvent':None,'requestedStartXYZ':schedule['requestedStartXYZ'],'requestedGoalXYZ':schedule['requestedGoalXYZ'],'associationDoesNotRelocateBody':True,'movementApplied':False};summary['scenes'].append(scene_summary)
    try:
     nav=lib.bn_build(v,len(vb)//12,t,len(ib)//12,C.byref(cfg));scene_summary['buildSucceeded']=bool(nav)
     if not nav:failed_reason='historical_build_unavailable';scene_summary['buildError']=lib.bn_last_error().decode(errors='replace')
     else:
      if lib.bn_excluded_span_count(nav)!=0:raise ValueError('Unexpected mesh exclusion')
      for which,requested in [('start',schedule['requestedStartXYZ']),('goal',schedule['requestedGoalXYZ'])]:
       rr=Result();h=lib.bh_begin(nav,vector(requested),C.byref(rr));begin_calls+=1;association=record(rr);actual=association['actualXYZ'];association.update(requestedXYZ=requested,requestedXYZFloat32=list(vector(requested)),horizontalResidualToOriginal=None if actual is None else residual(actual,requested),actorRelocated=False)
       scene_summary[which+'Association']=association
       if which=='start':
        state=h;native_prev=actual
        if not h:failed_reason=association['reason']
        elif actual is None or residual(actual,requested)>XZ_TOLERANCE_METRES:failed_reason='initial_association_original_double_xz_clamped'
       elif h:lib.bh_destroy(h)
     for idx,event in enumerate(schedule['events']):
      if total>=3696 or time.monotonic()-start_time>170:raise RuntimeError('Height worker event/time cap')
      rec={'scene':scene,'name':schedule['name'],'eventIndex':idx,'valid':False,'a':None,'b':None,'actualNativeA':native_prev,'actualNativeB':None,'kind':event['kind'],'yaw':event['yaw'],'dyaw':event['dyaw'],'edge':event['edge'],'originalEvent':event,'queryResult':{'queryExecuted':False,'reason':failed_reason},'unavailableReason':failed_reason,'movementApplied':False,'physicalAuthority':False}
      if failed_reason is None:
       if native_prev is None or residual(native_prev,event['a'])>XZ_TOLERANCE_METRES:failed_reason='original_event_start_xz_discontinuous'
       else:
        # Original desired XZ and original desired Y are passed to the released
        # query. Only returned native height supplies the candidate datum.
        rr=Result();ok=lib.bh_step(state,vector(event['b']),C.byref(rr));calls+=1;q=record(rr);rec['queryResult']=q;rec['actualNativeA']=q['previousXYZ'];rec['actualNativeB']=q['actualXYZ']
        if not ok or not q['valid']:failed_reason=q['reason']
        elif q['actualXYZ']is None or residual(q['actualXYZ'],event['b'])>XZ_TOLERANCE_METRES:failed_reason='original_double_endpoint_xz_clamped'
        elif q['previousXYZ']is None or residual(q['previousXYZ'],event['a'])>XZ_TOLERANCE_METRES:failed_reason='original_double_start_xz_clamped'
        else:
         rec['valid']=True;rec['a']=[event['a'][0],q['previousXYZ'][1],event['a'][2]];rec['b']=[event['b'][0],q['actualXYZ'][1],event['b'][2]];native_prev=q['actualXYZ']
      rec['unavailableReason']=failed_reason
      if not rec['queryResult']['queryExecuted']:rec['queryResult']['reason']=failed_reason
      if rec['valid']:scene_summary['validEvents']+=1
      else:
       scene_summary['unavailableEvents']+=1
       if scene_summary['firstUnavailableEvent']is None:scene_summary['firstUnavailableEvent']=idx
      unchanged_metadata(event,rec);line=json.dumps(rec,separators=(',',':'),allow_nan=False)+'\n';payload+=len(line.encode())
      if payload>16*1024**2:raise RuntimeError('Height evidence output cap')
      out.write(line);out.flush();total+=1
     scene_summary['terminalReason']=failed_reason;scene_summary['status']='fixed_schedule_evaluated_not_movement'
    finally:
     if state:lib.bh_destroy(state)
     if nav:lib.bn_destroy(nav)
   if total!=3696 or calls>3696 or begin_calls>4:raise RuntimeError('Height event/call inventory incomplete')
   summary['status']='completed_local_polygon_height_diagnostic'
 except BaseException as e:summary.update(status='failed',error=type(e).__name__+': '+str(e));raise
 finally:
  try:verify();summary['inputHashesAfterMatch']=True
  except BaseException as e:summary.update(status='failed',postPinError=str(e));raise
  finally:
   summary.update(eventRows=total,stepCalls=calls,beginCalls=begin_calls,outputPayloadBytes=payload,wallSeconds=time.monotonic()-start_time)
   (a.output/'SUMMARY.json').write_text(json.dumps(summary,indent=2,allow_nan=False)+'\n')
if __name__=='__main__':main()
