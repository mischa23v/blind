#!/usr/bin/env python3
"""Source/arithmetic controls only. Does not execute Swift or prove sensor validity."""
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
s = (root / "BlindCore/Sources/BlindCore/NativeObservation.swift").read_text()
t = (root / "BlindCore/Tests/BlindCoreTests/NativeObservationTests.swift").read_text()
body = s[s.index("public struct NativeDepthObservation:"):s.index("public struct NativeSurfaceObservation:")]
checks = []
def check(name, result):
    assert result, name
    checks.append(name)
parts = ["(1...16384).contains(width)", "(0...4096).contains(sampledPixelCount)", "(0...sampledPixelCount).contains(invalidPixelCount)", "pixels.count == sampledPixelCount - invalidPixelCount", "sampledPixelCount <= ((width + samplingStride - 1) / samplingStride)"]
check("bounds precede subtraction and lattice arithmetic", [body.index(x) for x in parts] == sorted(body.index(x) for x in parts))
check("unbounded count addition removed", "pixels.count + invalidPixelCount" not in body)
check("ceiling capacity includes height", "((height + samplingStride - 1) / samplingStride)" in body)
check("existing duplicate/confidence checks preserved", "Set(pixels.map" in body and "confidenceAvailable ?" in body)
check("four native regression methods prepared", all(x in t for x in ["testDepthAccountingRejectsHugeInvalidCountWithoutOverflow", "testDepthAccountingRejectsImpossibleInvalidRasterCoverage", "testDepthAccountingUsesCeilingStrideCapacityAndAllowsSparseSubsets", "testDepthAccountingRejectsNegativeAndOverBudgetCounts"]))
def valid(w,h,stride,n,bad,good):
    return (1 <= w <= 16384 and 1 <= h <= 16384 and 1 <= stride <= 16384 and
            0 <= n <= 4096 and 0 <= bad <= n and good == n-bad and
            n <= ((w+stride-1)//stride)*((h+stride-1)//stride))
cases = [("huge invalid",1,1,1,1,2**63-1,1,False), ("impossible invalid lattice",1,1,1,2,2,0,False),
 ("ceiling capacity",5,3,2,6,6,0,True), ("beyond ceiling",5,3,2,7,7,0,False),
 ("sparse subset",4,4,1,1,0,1,True), ("empty subset",5,3,2,0,0,0,True),
 ("negative sampled",1,1,1,-1,0,0,False), ("negative invalid",1,1,1,0,-1,0,False),
 ("invalid exceeds sampled",1,1,1,0,1,0,False), ("sample budget",128,128,1,4097,4097,0,False),
 ("huge sampled",128,128,1,2**63-1,2**63-1,0,False), ("stride exceeds dimensions",1,1,16384,1,1,0,True)]
for name,w,h,stride,n,bad,good,expected in cases: check(name,valid(w,h,stride,n,bad,good)==expected)
print(json.dumps({"scope":"source inspection and independent arithmetic controls", "passed":len(checks),"checks":checks,"swiftExecuted":False,"deviceExecuted":False,"physicalAuthority":False},indent=2))
