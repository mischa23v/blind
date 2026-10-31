#!/usr/bin/env python3
"""Bounded source-contract checks only; never represents Swift/ARKit execution."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent
paths = ["Package.swift", "Sources/LiveMeshBenchIngress.swift", "Sources/LiveMeshBenchSession.swift",
         "Tests/LiveMeshBenchIngressTests.swift", "Tests/LiveMeshBenchSessionTests.swift", "README.md"]
data = {}
for name in paths:
    value = (ROOT / name).read_bytes()
    assert len(value) <= 64_000, name
    data[name] = value.decode("utf-8")
core = data[paths[1]]
native = data[paths[2]]
checks = []
def check(name, condition):
    assert condition, name
    checks.append(name)

check("only existing local package dependencies", data[paths[0]].count(".package(path:") == 4 and ".package(url:" not in data[paths[0]])
check("real83 reused", "MeshCandidateIngress83(maxAnchors: 128, maxCopies: 1" in core)
check("real82 synchronous capture call present", "return ARKitMeshAdapter82.capture(anchor, context: context, limits: limits)" in native)
check("nonescaping capture API", "capture: (MeshSnapshot82.Context) -> MeshSnapshot82.Capture" in core)
check("no new native camera session", "ARSession()" not in native)
check("native declaration debug and iOS only", native.startswith("#if DEBUG && os(iOS) && canImport(ARKit)"))
check("one explicit camera activation statement", len(re.findall(r"^\s*session\.run\(", native, re.M)) == 1)
check("no physical output dependencies", all(x not in core + native for x in ["SpatialRouteTicket", "SpatialLocalizationCapture", "Feedback(", "AVSpeechSynthesizer", "URLSession"]))
check("monitoring explicitly unavailable", "public let phoneMonitoringAvailable = false" in native and "Phone hazard monitoring is unavailable" in native)
check("physical authority false", "public let authorizesPhysicalGuidance = false" in core and "public let authorizesPhysicalGuidance = false" in native)
check("generation mismatch before copy", "guard active(generation) else { return false }" in core)
check("no reset on terminal wrapper", not re.search(r"func\s+reset\s*\(", core))
check("actual callback sum budget one", "offer(selected, true)" in core and "offer(index, false)" in core and core.count("offer(selected, true)") == 1)
check("callback selection rotates", "next = (selected + 1) % count" in core)
check("callback count bounded", "(0...128).contains(count)" in core and "anchors.count <= 128" in native)
check("omitted revisions remain unknown", "guard copyAllowed else { return .unknownGap" in native)
check("owned copy logical limits explicit", "inputBytes: 1_500_000, decodedBytes: 1_500_000" in native)
check("freshness checked immediately before copy", native.index("guard frameIsCurrent() else") < native.index("return ARKitMeshAdapter82.capture"))
check("frame replay and preactivation cutoff", "frame.timestamp > $0" in native and "frame.timestamp >= beganAt" in native)
check("terminal drain and exact ownership restore", "producer.ingress.stopAndDiscard" in native and "let stillOwned = session.delegate === producer && session.delegateQueue === producerQueue" in native)
check("no nil delegate ABA window", "session.delegate = nil" not in native)
check("raw native ingress not exposed", "public var diagnostics" not in native and "public func requestPreview" in native)
check("deinit drain authored", "deinit {" in native and "let callback = onStopped" in native)
check("eight authored dependency fixtures", len(re.findall(r"func test", data[paths[3]])) == 8)
check("five authored native nonactivated fixtures", len(re.findall(r"func test", data[paths[4]])) == 5 and "session.run(" not in data[paths[4]])
audit = ROOT.parent / "live-navigation-wiring-20261028/README.md"
check("original source audit unchanged", hashlib.sha256(audit.read_bytes()).hexdigest() == "5f50fbd81db06a79d5e7d57cfb5c98ce3df4bca41140d868934f4b4dfcaa0a1a")
result = {"kind": "source_contract_only", "source_dependency_commit": "dc32a9bad9a75566f27924fb9f7aa8fe50a46e95",
          "checks_passed": len(checks), "checks": checks, "swift_compiled": False, "swift_tests_executed": False,
          "native_camera_activated": False, "physical_guidance_authorized": False}
(ROOT / "STATIC_RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({"checks_passed": len(checks), "kind": result["kind"], "swift_tests_executed": False}))
