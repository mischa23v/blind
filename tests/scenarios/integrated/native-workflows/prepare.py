#!/usr/bin/env python3
"""Create ONLY a new scratch test host; never edits the input checkout."""
import hashlib,json,pathlib,shutil,sys
src,out=map(lambda x:pathlib.Path(x).resolve(),sys.argv[1:3]); here=pathlib.Path(__file__).resolve().parent
if out.exists() or out == src or src in out.parents: raise SystemExit('Destination must be new and outside source')
pin_document=json.loads((here/'remote-source-pins.json').read_text())
pins=pin_document['files']
for name,expected in pins.items():
 data=(src/name).read_bytes()
 actual=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
 if actual != expected: raise SystemExit('Reviewed source blob changed: '+name)
p=src/'ios/BlindAssist/NavigationModel.swift'; original=p.read_bytes()
blob=hashlib.sha1(b'blob '+str(len(original)).encode()+b'\0'+original).hexdigest()
if blob != pins['ios/BlindAssist/NavigationModel.swift']: raise SystemExit('Controller changed; explicitly review/rebase seam first')
inventory=[]
for folder in ['BlindCore','BlindMemory','ios','tools']:
 for f in sorted((src/folder).rglob('*')):
  if f.is_file() and not any(v in f.parts for v in ['.build','node_modules']):
   inventory.append({'path':str(f.relative_to(src)), 'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
out.mkdir(parents=True)
(out/'input-source-inventory.json').write_text(json.dumps(inventory,indent=2)+'\n')
for folder in ['BlindCore','BlindMemory','ios','tools']:
 shutil.copytree(src/folder,out/folder,ignore=shutil.ignore_patterns('.build','node_modules','.DS_Store'))
def once(text,a,b):
 if text.count(a)!=1: raise SystemExit('Anchor mismatch: '+a)
 return text.replace(a,b)
s=original.decode()
s=once(s,'    override init() {','''    #if DEBUG && BLIND_WORKFLOW_TESTS
    var workflowReceipts: [WorkflowSnapshot] = []
    var workflowModelInvocationsBlocked = 0
    #endif
    override init() {''')
s=once(s,'        super.init(); session.delegate = self; session.delegateQueue = .main','''        #if DEBUG && BLIND_WORKFLOW_TESTS
        precondition(Bundle.main.bundleIdentifier == "org.blindassist.workflowtests")
        precondition(textOnly)
        #endif
        super.init(); session.delegate = self; session.delegateQueue = .main''')
s=once(s,'        sceneAnswer = text; currentReply = text\n        if textOnly', '''        sceneAnswer = text; currentReply = text
        #if DEBUG && BLIND_WORKFLOW_TESTS
        workflowRecord("code-reply")
        #endif
        if textOnly''')
s=once(s,'    private func answerConversation(_ question: String) {','''    private func answerConversation(_ question: String) {
        #if DEBUG && BLIND_WORKFLOW_TESTS
        workflowModelInvocationsBlocked += 1
        workflowRecord("MODEL_PATH_BLOCKED_NOT_RUN")
        return
        #endif''')
s=once(s,'    func receiveCompanionUtterance(_ text: String, fromVoice: Bool = false) {','''    func receiveCompanionUtterance(_ text: String, fromVoice: Bool = false) {
        #if DEBUG && BLIND_WORKFLOW_TESTS
        workflowRecord((fromVoice ? "input-unverified-microphone:" : "input-trusted-interface:") + text)
        #endif''')
s+='\n'+(here/'NativeWorkflowSeam.swift.txt').read_text()
(out/'ios/BlindAssist/NavigationModel.swift').write_text(s)
# Add test class to already registered app-hosted replay source; no project membership guess.
f=out/'ios/BlindAssistTests/CompanionNativeReplayTests.swift'
f.write_text(f.read_text()+'\n'+(here/'NativeWorkflowRegressionTests.swift').read_text())
# Hardware constructor is suppressed only in the dedicated test compilation.
belt=out/'ios/BlindAssist/BeltLink.swift'; b=belt.read_text()
b=once(b,'        super.init()',"""        super.init()
        #if DEBUG && BLIND_WORKFLOW_TESTS
        return
        #endif""")
b=once(b,'    func connect() { scanning = true; scanIfReady() }',"""    func connect() {
        #if DEBUG && BLIND_WORKFLOW_TESTS
        return
        #else
        scanning = true; scanIfReady()
        #endif
    }""")
b=once(b,'        scanning = false; central.stopScan()',"""        #if DEBUG && BLIND_WORKFLOW_TESTS
        guard central != nil else { return }
        #endif
        scanning = false; central.stopScan()""")
belt.write_text(b)
# Empty test host prevents the ordinary App/Dashboard lifecycle creating a second controller.
app=out/'ios/BlindAssist/BlindAssistApp.swift'
app.write_text("""#if DEBUG && BLIND_WORKFLOW_TESTS
import SwiftUI
@main struct NativeWorkflowTestHost: App {
    var body: some Scene { WindowGroup { Text("Authored workflow regression host") } }
}
#else
"""+app.read_text()+"\n#endif\n")
# Separate bundle identities before generation. Never shared with the actual app.
g=out/'tools/generate-xcode-project.mjs'; text=g.read_text()
if 'CODE_SIGN_ENTITLEMENTS' in text: raise SystemExit('Entitlements require explicit isolation review')
text=text.replace('org.blindassist.mobility','org.blindassist.workflowtests')
text=text.replace('SWIFT_ACTIVE_COMPILATION_CONDITIONS = "','SWIFT_ACTIVE_COMPILATION_CONDITIONS = "BLIND_WORKFLOW_TESTS ')
g.write_text(text)
(out/'workflow-projection.json').write_text(json.dumps({'status':'PREPARED_NATIVE_NOT_RUN','source':'fixed public repository checkout','sourceControllerGitBlob':blob,'sourceCommit':pin_document['commit'], 'sourceVerification':pin_document['verification'],'controllerAdaptations':['observation callback after code reply assignment','block model lane (any call is asserted failure)','DEBUG and dedicated compile flag','test fixture state reset/hazard injection','real memory writer waitForCommit'],'sourceProjectionChanged':True,'actualModelCalls':0,'full400Completed':False},indent=2)+'\n')
print(out)
