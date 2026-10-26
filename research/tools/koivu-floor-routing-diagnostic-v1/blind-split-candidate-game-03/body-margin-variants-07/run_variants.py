"""One call per preregistered profile; caller supplies the approved resource watchdog."""
from pathlib import Path
import argparse, json, sys, time
sys.dont_write_bytecode = True
from margin_variants import PROFILES, evaluate_variant, serialize, sha

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--native-directory", required=True, type=Path)
    p.add_argument("--native-library-sha", required=True)
    p.add_argument("--output", required=True, type=Path)
    a = p.parse_args(); a.output.mkdir(exist_ok=False)
    results = []; start = time.monotonic()
    def execute(name, radius=None):
        attempt = "primary" if radius is None else "proposal0125Fallback"
        print(json.dumps({"phase": "profile_start", "profile": name, "attempt": attempt}), flush=True)
        result = evaluate_variant(name, a.native_directory, a.native_library_sha, radius)
        result["proposalAttempt"] = attempt
        path = a.output/(name+("" if radius is None else ".proposal0125")+".json")
        with path.open("x") as f: json.dump(serialize(result), f, indent=2, allow_nan=False); f.write("\n")
        row = {"profile": name, "proposalAttempt": attempt, "candidateStatus": result["candidate"]["status"],
            "allTargetEnclosure": result["discCentreTopology"]["anyRegionEnclosesAllTarget"],
            "probeEnclosure": result["discCentreTopology"]["anyRegionEnclosesFixedProbe"],
            "eligibleCentres": result["eligibleCentreCount"], "artifact": path.name, "sha256": sha(path)}
        results.append(row); print(json.dumps(row), flush=True)
        return result
    for name in PROFILES:
        result = execute(name)
        if name == "abstract28cmProfile" and result["candidate"]["status"] != "phoneModelLoopFeasibleSemanticTargetUnresolved":
            execute(name, .125)
    with (a.output/"RESULTS.json").open("x") as f:
        json.dump({"profiles": results, "wallSeconds": time.monotonic()-start,
            "movementEpisodesExecuted": 0, "physicalAuthority": False}, f, indent=2); f.write("\n")

if __name__ == "__main__": main()
