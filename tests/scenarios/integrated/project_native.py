#!/usr/bin/env python3
import sys,pathlib,hashlib,json,re
source,package,output=map(pathlib.Path,sys.argv[1:4]); here=pathlib.Path(__file__).parent
runtime=source/'ios/BlindAssist/ConnectedJourneyRuntime.swift'; helpers=source/'ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift'
text=helpers.read_text().replace('@testable import BlindAssist\n',''); pos=text.rfind('}')
methods=(here/'native-recovery-method.swift.txt').read_text()
parts=re.split(r'(?=^    func )',methods,flags=re.M)
added=[]; inherited=[]
for part in parts:
 match=re.search(r'func (\w+)\(',part)
 if not match: continue
 if 'func '+match.group(1)+'(' in text:
  if part.strip() not in text: raise SystemExit('Existing acceptance method differs; explicit review required: '+match.group(1))
  inherited.append(match.group(1))
 else: added.append(part)
text=text[:pos]+''.join(added)+text[pos:]
target=package/'Tests/BlindCoreTests'; (target/'NativeIntegratedRuntimeTests.swift').write_text(text); (target/'ConnectedJourneyRuntime.swift').write_bytes(runtime.read_bytes())
output.mkdir(parents=True,exist_ok=True)
(output/'native-projection-manifest.json').write_text(json.dumps({'adaptation':'Actual native runtime unmodified; existing native test helpers projected into portable test module by removing only @testable import BlindAssist, then append acceptance regressions. Apple frameworks/device not executed.', 'existing_acceptance_methods_not_duplicated':inherited,'runtime_sha256':hashlib.sha256(runtime.read_bytes()).hexdigest(),'helper_source_sha256':hashlib.sha256(helpers.read_bytes()).hexdigest(),'projected_test_sha256':hashlib.sha256(text.encode()).hexdigest(),'acceptance_method_sha256':hashlib.sha256((here/'native-recovery-method.swift.txt').read_bytes()).hexdigest()},indent=2))
