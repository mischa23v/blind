"""One authorized phone-only feasibility call and diagram; no reference/actor."""
from pathlib import Path
import argparse
import hashlib
import json
import sys
import time

sys.dont_write_bytecode = True
from freeze_loop_02 import HERE, GAME, RUN, verify_manifest


def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--frozen-sha", required=True)
    args = parser.parse_args()
    verify_manifest(args.frozen_sha)
    out = RUN/"artifacts"
    out.mkdir(exist_ok=False)
    # No numerical/native imports or recorded data access precede pin verification.
    sys.path.insert(0, str(GAME/"source"))
    import candidate_map
    import table_loop
    if Path(candidate_map.__file__).resolve() != GAME/"source/candidate_map.py" or Path(table_loop.__file__).resolve() != HERE/"table_loop.py":
        raise ValueError("unexpected adapter/module import")
    started = time.monotonic()
    print(json.dumps({"phase": "phone_map_build"}), flush=True)
    with candidate_map.CandidateMap() as model:
        print(json.dumps({"phase": "fixed_phone_only_loop_construction"}), flush=True)
        result = table_loop.propose_loop(model)
        result["technicalMeaning"] = "construction returned; status owns feasibility, not movement success"
        raw = table_loop.proposal_json(result).encode()
        if len(raw) > 7*1024**2: raise RuntimeError("proposal exceeds bounded output allocation")
        with (out/"PROPOSAL.json").open("xb") as f: f.write(raw)
        print(json.dumps({"phase": "construction_returned", "proposalStatus": result["status"]}), flush=True)
        plot = table_loop.write_phone_only_diagnostic(result, model, out/"PHONE_ONLY_DIAGNOSTIC.png")
    verify_manifest(args.frozen_sha)
    artifacts = [{"file": p.name, "bytes": p.stat().st_size, "sha256": sha(p)}
                 for p in (out/"PROPOSAL.json", out/"PHONE_ONLY_DIAGNOSTIC.png")]
    record = dict(technicalExecutionCompleted=True, proposalStatus=result["status"],
                  loopFeasible=result["status"] == "phoneModelLoopFeasibleSemanticTargetUnresolved",
                  semanticTarget=result["semanticTarget"], lapEpisodeAuthorized=False,
                  movementEpisodesExecuted=0, referenceInputsUsed=False, physicalAuthority=False,
                  sourceInputHashesVerifiedBeforeAndAfter=True, frozenSHA256=args.frozen_sha,
                  wallSeconds=time.monotonic()-started, artifacts=artifacts, diagnostic=plot)
    with (out/"ARTIFACTS.json").open("x") as f: json.dump(record, f, indent=2, allow_nan=False); f.write("\n")
    print(json.dumps(record), flush=True)


if __name__ == "__main__": main()
