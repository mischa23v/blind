"""Serial tiny fixtures and one phone-only proposal; reuse reviewed tree watchdog.

All run artifacts, caches, logs and the pre-created frozen manifest stay in
run-01. No existing game source/route or world result is written. A completed
technical run may report no feasible loop; it is never a movement success.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import resource
import shutil
import signal
import subprocess
import sys
import time

sys.dont_write_bytecode = True
from freeze_loop import HERE, WS, RUN, FROZEN, BUDGETS, FIXED, read_manifest, verify_manifest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--frozen-sha", required=True)
    args = parser.parse_args()
    read_manifest(args.frozen_sha)
    if RUN.is_symlink() or not RUN.is_dir() or set(p.name for p in RUN.iterdir()) != {"FROZEN.json"}:
        raise RuntimeError("exclusive frozen run directory only; never overwrite a prior attempt")
    helper_path = WS/"blind-koivu-game-07/run_bounded.py"
    if hashlib.sha256(helper_path.read_bytes()).hexdigest() != FIXED[str(helper_path.relative_to(WS))]:
        raise ValueError("watchdog import pin mismatch")
    spec = importlib.util.spec_from_file_location("phone_loop_existing_watchdog", helper_path)
    watchdog = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(watchdog)
    current_tree_usage, output_bytes, kill_group = watchdog.current_tree_usage, watchdog.output_bytes, watchdog.kill_group
    start = time.monotonic()
    cpu0 = current_tree_usage(os.getpid())[1]
    child = None
    failure = None
    completed = []
    phase = "verify-before"
    peak = 0
    cpu = 0.
    peak_output = 0
    last_heartbeat = -math.inf
    after = False
    receipt_allowance = 65536
    heartbeat = RUN/"heartbeat.jsonl"
    heartbeat.touch(exist_ok=False)

    def check():
        nonlocal peak, cpu, peak_output, last_heartbeat
        current, spent = current_tree_usage(os.getpid())
        peak = max(peak, current)
        cpu = max(cpu, spent-cpu0)
        used = output_bytes(RUN)
        peak_output = max(peak_output, used)
        free = shutil.disk_usage(HERE).free
        if (peak > BUDGETS["RSSBytes"] or cpu > BUDGETS["CPUSeconds"]
                or time.monotonic()-start > BUDGETS["wallSeconds"]
                or used > BUDGETS["outputBytes"]-receipt_allowance or free < BUDGETS["freeReserveBytes"]):
            raise RuntimeError("phone-loop sampled resource cap")
        if time.monotonic()-last_heartbeat >= 2:
            with heartbeat.open("a") as f:
                f.write(json.dumps(dict(phase=phase, wallSeconds=time.monotonic()-start,
                    sampledTreeCPUSeconds=cpu, sampledTreeRSSBytes=current, peakSampledRSSBytes=peak,
                    outputBytesBeforeHeartbeat=used, freeBytes=free))+"\n")
            last_heartbeat = time.monotonic()

    def timeout(*_): raise TimeoutError("90-second wall alarm")
    signal.signal(signal.SIGALRM, timeout)
    signal.alarm(BUDGETS["wallSeconds"])
    try:
        if shutil.disk_usage(HERE).free < BUDGETS["freeReserveBytes"]+BUDGETS["outputBytes"]:
            raise RuntimeError("reserve preflight")
        verify_manifest(args.frozen_sha, check)
        env = dict(os.environ)
        for key in ("LD_PRELOAD", "LD_AUDIT", "PYTHONPATH", "PYTHONHOME", "DISPLAY", "WAYLAND_DISPLAY"):
            env.pop(key, None)
        env.update({key: "1" for key in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS", "NUMEXPR_NUM_THREADS", "BLIS_NUM_THREADS")})
        env.update(PYTHONDONTWRITEBYTECODE="1", PYTHONNOUSERSITE="1", PYTHONOPTIMIZE="0", CUDA_VISIBLE_DEVICES="", HIP_VISIBLE_DEVICES="")
        for folder in ("tmp", "cache", "home"): (RUN/folder).mkdir()
        env.update(TMPDIR=str(RUN/"tmp"), XDG_CACHE_HOME=str(RUN/"cache"), MPLCONFIGDIR=str(RUN/"cache/matplotlib"), HOME=str(RUN/"home"))
        commands = [("fixtures", [sys.executable, str(HERE/"test_table_loop.py")]),
                    ("feasibility", [sys.executable, str(HERE/"loop_driver.py"), "--frozen-sha", args.frozen_sha])]
        for name, command in commands:
            phase = "verify-before-"+name
            verify_manifest(args.frozen_sha, check)
            remaining = max(1, int(math.floor(BUDGETS["CPUSeconds"]-cpu)))
            def limits():
                resource.setrlimit(resource.RLIMIT_CPU, (remaining, remaining))
                resource.setrlimit(resource.RLIMIT_FSIZE, (BUDGETS["outputBytes"], BUDGETS["outputBytes"]))
                os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
            with (RUN/(name+".stdout.log")).open("x") as so, (RUN/(name+".stderr.log")).open("x") as se:
                child = subprocess.Popen(command, cwd=HERE, stdout=so, stderr=se, env=env,
                                         start_new_session=True, preexec_fn=limits)
                phase = "running-"+name
                while child.poll() is None: check(); time.sleep(.1)
                code = child.wait()
                kill_group(child)
                child = None
                check()
            completed.append({"mode": name, "exitCode": code})
            phase = "verify-after-"+name
            verify_manifest(args.frozen_sha, check)
            if code != 0: raise RuntimeError(name+" child failed; partial evidence retained")
        phase = "verify-final"
        verify_manifest(args.frozen_sha, check)
        after = True
        artifact_path = RUN/"artifacts/ARTIFACTS.json"
        if artifact_path.stat().st_size > 65536: raise RuntimeError("artifact receipt cap")
        artifacts = json.loads(artifact_path.read_text())
        if artifacts.get("technicalExecutionCompleted") is not True or artifacts.get("physicalAuthority") is not False:
            raise ValueError("technical receipt mismatch")
    except BaseException as error:
        failure = repr(error)
    finally:
        if child is not None: kill_group(child)
        signal.alarm(0)
        try:
            current, spent = current_tree_usage(os.getpid())
            peak = max(peak, current, resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss*1024)
            cpu = max(cpu, spent-cpu0)
            if (peak > BUDGETS["RSSBytes"] or cpu > BUDGETS["CPUSeconds"]
                    or time.monotonic()-start > BUDGETS["wallSeconds"]):
                failure = failure or "terminal phone-loop resource cap"
            receipt = dict(technicalExecutionCompleted=failure is None and after,
                failure=failure, failedPhase=phase if failure else None, modes=completed,
                sourceInputHashesVerifiedBeforeAndAfter=after, frozenSHA256=args.frozen_sha,
                wallSeconds=time.monotonic()-start, sampledCPUSeconds=cpu, peakSampledOrWaitedRSSBytes=peak,
                peakOutputBytesBeforeReceipt=peak_output, budgets=BUDGETS, sampledNotCgroup=True,
                outputAccounting="logical regular-file bytes including manifest, caches and logs",
                movementEpisodesExecuted=0, referenceInputsUsed=False, physicalAuthority=False)
            if failure is None:
                receipt.update(proposalStatus=artifacts["proposalStatus"], loopFeasible=artifacts["loopFeasible"],
                               semanticTarget=artifacts["semanticTarget"], lapEpisodeAuthorized=False)
            data = (json.dumps(receipt, indent=2, allow_nan=False)+"\n").encode()
            if (len(data) > receipt_allowance or output_bytes(RUN)+len(data) > BUDGETS["outputBytes"]
                    or shutil.disk_usage(HERE).free-len(data) < BUDGETS["freeReserveBytes"]):
                raise RuntimeError("terminal receipt output/reserve cap")
            with (RUN/"RUN_RECEIPT.json").open("xb") as f: f.write(data)
            print(json.dumps(receipt), flush=True)
        except BaseException as receipt_error:
            failure = failure or repr(receipt_error)
            print(json.dumps(dict(technicalExecutionCompleted=False, failure=failure,
                                  receiptError=repr(receipt_error), partialEvidenceRetained=True)), file=sys.stderr)
    if failure is not None: raise SystemExit(1)


if __name__ == "__main__": main()
