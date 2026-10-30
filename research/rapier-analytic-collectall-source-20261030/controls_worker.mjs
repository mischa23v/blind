/**
 * Controls-only worker. SOURCE PREPARED, NOT EXECUTED.
 * Run only by the reviewed aggregate launcher after publication/admission.
 */
import fs from "node:fs";
import path from "node:path";
import {loadForAdmittedExecution} from "./loader.mjs";
import {runPreparedControls} from "./controls.mjs";
import {makeCallBudget} from "./comparator.mjs";
const keys=["--package-root","--output","--runtime-contract","--pins-sha256"];
const args=process.argv.slice(2), options={};
function assert(ok,message){if(!ok)throw new Error(message);}
assert(args.length===8,"exact controls-only arguments required");
for(let i=0;i<args.length;i+=2){assert(keys.includes(args[i])&&!Object.hasOwn(options,args[i]),"unexpected/duplicate argument");options[args[i]]=args[i+1];}
assert(keys.every(k=>typeof options[k]==="string"),"missing argument");
assert(/^[a-f0-9]{64}$/.test(options["--pins-sha256"]),"invalid pin identity");
const allowedEnv=new Set(["PATH","LC_ALL","HOME","TMPDIR","UV_THREADPOOL_SIZE","OMP_NUM_THREADS",
  "OPENBLAS_NUM_THREADS","MKL_NUM_THREADS","PYTHONDONTWRITEBYTECODE","PYTHONPYCACHEPREFIX"]);
assert(Object.keys(process.env).every(k=>allowedEnv.has(k)),"unexpected inherited environment variable");
assert(options["--runtime-contract"]==="managed_sandbox_trusted_official_source","unexpected runtime contract");
// Trusted-source guardrail, not an independent hostile-code or network sandbox.
assert(process.execArgv.includes("--permission") && !process.execArgv.includes("--permission-audit"),
  "restrictive Node permission mode required");
assert(typeof process.permission?.has==="function","Node permission API unavailable");
assert(process.permission.has("child")===false && process.permission.has("worker")===false,
  "child processes/worker threads must not be granted");
assert(process.permission.has("fs.read")===false && process.permission.has("fs.write")===false,
  "unrestricted filesystem permissions forbidden");
const out=path.resolve(options["--output"]);fs.mkdirSync(out,{recursive:false});
const fdFlags=fs.constants.O_WRONLY|fs.constants.O_CREAT|fs.constants.O_EXCL|fs.constants.O_NOFOLLOW;
const wrapperFD=fs.openSync(path.join(out,"wrapper-records.jsonl"),fdFlags,0o600);
const probeFD=fs.openSync(path.join(out,"probe-rows.jsonl"),fdFlags,0o600);
const checkFD=fs.openSync(path.join(out,"assertion-results.jsonl"),fdFlags,0o600);
let outputBytes=0,wrapperCount=0,probeCount=0,checkCount=0,initialized=false,wrapperVersion=null;
const budget=makeCallBudget();
const encode=value=>JSON.stringify(value,(_key,v)=>ArrayBuffer.isView(v)?Array.from(v):v)+"\n";
function emit(fd,value){const b=Buffer.from(encode(value));
  assert(outputBytes+b.length<=12*1024*1024,"worker payload cap");fs.writeSync(fd,b);outputBytes+=b.length;}
const summary={schema:1,scope:"analytic_controls_only",status:"started",pinsSHA256:options["--pins-sha256"],
  runtimeContract:options["--runtime-contract"],nodePermissionsChecked:true,
  independentlyAirGapped:false,namespaceSetupRequested:false,hostSecuritySettingsChanged:false,
  networkAccessRequestedByProtocol:false,networkMonitoringPerformed:false,
  realRoomQueries:0,physicalAuthority:false,movementApplied:false,independentHazardOraclePassed:false};
let failure=null;
try{
  const R=await loadForAdmittedExecution(options["--package-root"],{rootReviewed:true,aggregateSupervisorActive:true});
  initialized=true;wrapperVersion=R.version();
  const result=runPreparedControls(R,record=>{emit(wrapperFD,record);wrapperCount+=1;},budget,
    record=>{emit(probeFD,record);probeCount+=1;},record=>{emit(checkFD,record);checkCount+=1;});
  assert(result.wrapperRecordCount===72&&result.nestedProbeRowCount===108&&result.callCount===104,
    "frozen controls inventory mismatch");
  assert(wrapperCount===72&&probeCount===108&&checkCount===72,"streamed controls inventory mismatch");
  summary.status=result.failedWrapperCount?"controls_failed_assertions":"controls_passed";
  summary.adapterResultStatus=result.status;
  summary.failedWrapperCount=result.failedWrapperCount;summary.assertionFailureCount=result.assertionFailureCount;
  summary.allFixturesAttempted=true;summary.expectationsUnchanged=true;
  if(result.failedWrapperCount) {failure=new Error("Original fixture assertions failed; full inventory retained");summary.error=failure.message;}
}catch(error){failure=error;summary.status="failed";summary.error=String(error?.message??error).slice(0,2000);}
finally{
  fs.closeSync(wrapperFD);fs.closeSync(probeFD);fs.closeSync(checkFD);
  Object.assign(summary,{wrapperCount,probeCount,checkCount,controllerCalls:budget.count,wasmInitialized:initialized,
    wrapperVersion,nodeVersion:process.version,outputPayloadBytes:outputBytes,heapLimitFlagMiB:256,rlimitASApplied:false});
  const fd=fs.openSync(path.join(out,"SUMMARY.json"),fdFlags,0o600);
  try{const b=Buffer.from(encode(summary));assert(b.length<=65536,"summary reserve exceeded");fs.writeSync(fd,b);}
  finally{fs.closeSync(fd);}
}
if(failure){console.error("Controls failed; partial rows retained: "+summary.error);process.exitCode=1;}
else console.log(JSON.stringify({status:summary.status,wrapperCount,probeCount,controllerCalls:budget.count,
  realRoomQueries:0,physicalAuthority:false}));
