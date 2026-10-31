/** Public-room fixed-pose diagnostics only. No returned movement is ever applied. */
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';
import {loadForAdmittedExecution} from './loader.mjs';
import {runFrozenProbes,makeCallBudget} from './comparator.mjs';
const assert=(v,m)=>{if(!v)throw new Error(m);};
const keys=['--package-root','--data-root','--output','--runtime-contract','--pins-sha256'];
const args=process.argv.slice(2),o={};assert(args.length===10,'exact room arguments');
for(let i=0;i<args.length;i+=2){assert(keys.includes(args[i])&&!Object.hasOwn(o,args[i]),'argument');o[args[i]]=args[i+1];}
assert(keys.every(k=>typeof o[k]==='string')&&/^[a-f0-9]{64}$/.test(o['--pins-sha256']),'missing arguments');
const allowed=new Set(['PATH','LC_ALL','HOME','TMPDIR','UV_THREADPOOL_SIZE','OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','PYTHONDONTWRITEBYTECODE','PYTHONPYCACHEPREFIX']);
assert(Object.keys(process.env).every(k=>allowed.has(k)),'unexpected environment');
assert(o['--runtime-contract']==='managed_sandbox_trusted_official_source','runtime contract');
assert(process.execArgv.includes('--permission')&&!process.execArgv.includes('--permission-audit'),'permission mode');
assert(typeof process.permission?.has==='function'&&!process.permission.has('child')&&!process.permission.has('worker')&&!process.permission.has('fs.read')&&!process.permission.has('fs.write'),'permission bounds');
const out=path.resolve(o['--output']);fs.mkdirSync(out,{recursive:false});
const flags=fs.constants.O_WRONLY|fs.constants.O_CREAT|fs.constants.O_EXCL|fs.constants.O_NOFOLLOW;
const rowFD=fs.openSync(path.join(out,'probe-rows.jsonl'),flags,0o600),wrapFD=fs.openSync(path.join(out,'wrapper-records.jsonl'),flags,0o600);
const encode=x=>JSON.stringify(x)+'\n',hash=x=>crypto.createHash('sha256').update(x).digest('hex');
let outputBytes=0,wrapperCount=0,probeCount=0,unsupportedTurns=0;const budget=makeCallBudget();
function emit(fd,x){const b=Buffer.from(encode(x));assert(outputBytes+b.length<=12*1024*1024,'payload cap');fs.writeSync(fd,b);outputBytes+=b.length;}
const summary={schema:1,scope:'fixed_real_room_probes_only',status:'started',pinsSHA256:o['--pins-sha256'],runtimeContract:o['--runtime-contract'],physicalAuthority:false,movementApplied:false,arrivalEstablished:false,independentHazardOraclePassed:false,analyticControlsHadTwoKnownFailures:true,computedGroundedIsNotSupport:true,namespaceSetupRequested:false,hostSecuritySettingsChanged:false,networkAccessRequestedByProtocol:false,independentlyAirGapped:false,nodePermissionsChecked:true,rlimitASApplied:false};
let failure=null;
try{
 const root=path.resolve(o['--data-root']),m=JSON.parse(fs.readFileSync(path.join(root,'MATERIALIZATION.json'),'utf8'));
 assert(m.status==='materialized_source_only_no_Rapier_execution'&&m.fixedOriginalRows===49&&m.additionalSavedGroundRows===2,'materialization contract');
 const read=name=>{const b=fs.readFileSync(path.join(root,name));assert(b.length===m.files[name].bytes&&hash(b)===m.files[name].sha256,'buffer pin '+name);return b;};
 const R=await loadForAdmittedExecution(o['--package-root'],{rootReviewed:true,aggregateSupervisorActive:true});summary.wasmInitialized=true;summary.wrapperVersion=R.version();
 for(const scene of ['coffee','conference']){
  const vb=read(scene+'.vertices.f32'),ib=read(scene+'.indices.u32'),base=JSON.parse(read(scene+'.probes.json').toString('utf8'));
  // Copy exactly into aligned little-endian typed arrays. Reject another endian runtime.
  assert(new Uint8Array(new Uint32Array([1]).buffer)[0]===1,'little endian runtime required');
  const vertices=new Float32Array(vb.buffer.slice(vb.byteOffset,vb.byteOffset+vb.byteLength)),indices=new Uint32Array(ib.buffer.slice(ib.byteOffset,ib.byteOffset+ib.byteLength));
  assert(base.length===(scene==='coffee'?9:42)&&base.every(p=>p.inputAdmissible),'fixed full admissible inventory');
  for(const envelope of ['body','horizontal_margin'])for(const arm of ['raw_trimesh','two_sided_internal_edges'])for(const inputArm of ['exact_xyz','horizontal_projection']){
   const probes=base.map(p=>({...p,inputArm}));
   const result=runFrozenProbes(R,{vertices,indices,probes,arm,envelope,budget,onResult:row=>{
    assert(row.physicalAuthority===false&&row.movementApplied===false&&row.arrivalEstablished===false,'authority');
    if(row.kind==='turn')unsupportedTurns++;
    assert(probeCount<408&&budget.count<=328,'inventory cap');emit(rowFD,{scene,arm,envelope,inputArm,row});probeCount++;
   }});
   const map=result.importedMapping.originalToEngineVertex;
   emit(wrapFD,{scene,arm,envelope,inputArm,status:result.status,physicalAuthority:false,probeCount:result.results.length,config:result.config,meshReceipt:m.scenes[scene],originalToEngineVertexMapSHA256:hash(Buffer.from(map.buffer,map.byteOffset,map.byteLength)),originalToEngineVertexMapLength:map.length,importedVertices:result.importedMapping.vertexCount,importedTriangles:result.importedMapping.triangleCount,originalTriangleOrdinalPreserved:result.importedMapping.originalTriangleOrdinalPreserved});wrapperCount++;
  }
  assert(hash(Buffer.from(vertices.buffer))===m.scenes[scene].vertexBytesSHA256&&hash(Buffer.from(indices.buffer))===m.scenes[scene].indexBytesSHA256,'input buffers changed');
 }
 assert(wrapperCount===16&&probeCount===408&&budget.count===328&&unsupportedTurns===80,'complete inventory');summary.status='completed_diagnostic_proposals_not_movement';summary.allSelectedRowsRetained=true;
}catch(e){failure=e;summary.status='failed';summary.error=String(e?.message??e).slice(0,2000);}
finally{
 fs.closeSync(rowFD);fs.closeSync(wrapFD);Object.assign(summary,{wrapperCount,probeCount,controllerCalls:budget.count,unsupportedTurns,outputPayloadBytes:outputBytes,nodeVersion:process.version});
 const fd=fs.openSync(path.join(out,'SUMMARY.json'),flags,0o600);try{const b=Buffer.from(encode(summary));assert(b.length<=65536,'summary cap');fs.writeSync(fd,b);}finally{fs.closeSync(fd);}
}
if(failure){console.error('Room diagnostic failed; partial rows retained: '+summary.error);process.exitCode=1;}
