#!/usr/bin/env python3
"""Current-source checks only. Never rewrite or claim historical native passes."""
from pathlib import Path
import hashlib,json,importlib.util,ast
H=Path(__file__).resolve().parent;R=H.parents[1]
def require(v,m):
 if not v:raise ValueError(m)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
receipt=json.loads((H/'CURRENT_PIN_RECEIPT.json').read_text())
for path,h in receipt['historical_untouched'].items():require(sha(R/path)==h,'historical changed '+path)
counts={}
for base,manifest in [(R/'research/room-mesh-package-75','APPLE_CURRENT_SOURCE_PINS.json'),(R,'research/mesh-candidate-ingress-83/CURRENT_SOURCE_PINS.json')]:
 rows=json.loads((base/manifest).read_text())['files']
 for path,h in rows.items():require(sha(base/path)==h,'current mismatch '+path)
 counts[manifest]=len(rows)
C=R/'research/live-mesh-classified-bench-20261028';rows=json.loads((C/'CURRENT_INPUT_PINS.json').read_text())['files']
for row in rows:
 p=R/row['path'];require(p.stat().st_size==row['bytes'] and sha(p)==row['sha256'],'classifier current mismatch '+row['path'])
counts['CURRENT_INPUT_PINS.json']=len(rows)
spec=importlib.util.spec_from_file_location('classified_current_contract',C/'check_source.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);checks=m.validate(m.load_sources())
for path in ['research/room-mesh-package-75/apple/ci.py','research/mesh-candidate-ingress-83/apple/ci.py']:
 s=(R/path).read_text();ast.parse(s);require('CEarcut.build' in s and '-fmodule-map-file=' in s,'missing manual link/import bridge '+path);require('missing reviewed CEarcut objects' in s and 'missing SwiftPM CEarcut module map' in s,'missing failclosed dependency checks '+path)
require('APPLE_CURRENT_SOURCE_PINS.json' in (R/'research/room-mesh-package-75/apple/ci.py').read_text(),'stage75 not current')
require("HOME / 'CURRENT_SOURCE_PINS.json'" in (R/'research/mesh-candidate-ingress-83/apple/ci.py').read_text(),'stage83 not current')
result={'kind':'current_source_only','manifest_counts':counts,'classifier_source_contract_checks':len(checks),'historical_manifests_unchanged':True,'runner_python_parse':True,'swift_compiled':False,'native_tests_executed':False,'physicalAuthority':False}
(H/'CURRENT_SOURCE_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
