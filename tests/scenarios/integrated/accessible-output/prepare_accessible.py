#!/usr/bin/env python3
"""Append a native-output-only observer to a fresh isolated regression projection."""
import pathlib,sys,subprocess,json,hashlib,tempfile,shutil
src,out,base=map(lambda x:pathlib.Path(x).resolve(),sys.argv[1:4])
here=pathlib.Path(__file__).resolve().parent
if out.exists(): raise SystemExit('New output required; existing failure evidence never overwritten')
pins=json.loads((here/'accessible-source-pins.json').read_text())
for name,expected in pins['files'].items():
 data=(src/name).read_bytes(); actual=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
 if actual!=expected: raise SystemExit('Source rebase/review required: '+name)
# The accepted three-test recipe remains unchanged and pinned to its original
# source baseline in the repository. Derive a private recipe copy with this
# producer's explicitly reviewed current-source pins; never rewrite that suite.
for name,expected in pins['baseRecipeFiles'].items():
 data=(base/name).read_bytes(); actual=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
 if actual!=expected: raise SystemExit('Base recipe review required: '+name)
with tempfile.TemporaryDirectory(prefix='blind-accessible-base-') as temporary:
 derived=pathlib.Path(temporary)
 for name in pins['baseRecipeFiles']: shutil.copy2(base/name,derived/name)
 base_pin=json.loads((derived/'remote-source-pins.json').read_text())
 base_pin['commit']=pins['commit']
 base_pin['verification']='Explicit accessible-producer current source pins; original three-test recipe preserved'
 base_pin['files']={name:pins['files'][name] for name in base_pin['files']}
 (derived/'remote-source-pins.json').write_text(json.dumps(base_pin,indent=2)+'\n')
 subprocess.run([sys.executable,str(derived/'prepare.py'),str(src),str(out)],check=True)
def once(s,a,b):
 if s.count(a)!=1: raise SystemExit('Unique source anchor missing: '+a)
 return s.replace(a,b)
p=out/'ios/BlindAssist/NavigationModel.swift';s=p.read_text()
s=once(s,'    var workflowModelInvocationsBlocked = 0','''    var workflowModelInvocationsBlocked = 0
    #if BLIND_ACCESSIBLE_OUTPUT_TESTS
    private var accessibleOutputProbeEnabled = false
    #endif''')
s=once(s,'    private func deliverConversationReply(_ text: String) {','''    private var permitsAccessibleOutputProbe: Bool {
        #if DEBUG && BLIND_WORKFLOW_TESTS && BLIND_ACCESSIBLE_OUTPUT_TESTS
        return accessibleOutputProbeEnabled && textOnly &&
            Bundle.main.bundleIdentifier == "org.blindassist.accessibleworkflowtests"
        #else
        return false
        #endif
    }
    private func deliverConversationReply(_ text: String) {''')
s=once(s,'        if textOnly || assistantSession.state != .active {\n            assistantDialogue.record(role: "assistant", text: text)',
'''        if (textOnly && !permitsAccessibleOutputProbe) || assistantSession.state != .active {
            assistantDialogue.record(role: "assistant", text: text)''')
s=once(s,'        guard !textOnly, assistantSession.state == .active,\n              assistantSession.accepts(generation: generation)',
'''        guard (!textOnly || (permitsAccessibleOutputProbe && codeOwned && origin == .trustedInterface)), assistantSession.state == .active,
              assistantSession.accepts(generation: generation)''')
s=once(s,'        guard !textOnly else { return false }\n        // A disconnected private audio route',
'''        // The test exception cannot mint visual, mobility, hazard or untracked output.
        let isolatedCodeReply = permitsAccessibleOutputProbe && candidate.kind == .answer && candidate.requested &&
            narrationID == nil && alert == nil && spatialRouteID == nil && speechID != nil &&
            activeConversationSpeech?.id == speechID && activeConversationSpeech?.codeOwned == true &&
            activeConversationSpeech?.origin == .trustedInterface
        guard !textOnly || isolatedCodeReply else { return false }
        // A disconnected private audio route''')
s+='\n'+(here/'AccessibleOutputSeam.swift.txt').read_text()
s=s.replace('org.blindassist.workflowtests','org.blindassist.accessibleworkflowtests');p.write_text(s)
# Fail closed before any built-in or optional model can be reached by an unexpected path.
model=out/'ios/BlindAssist/LocalImageAssistant.swift'; m=model.read_text()
for signature in [
 '                         onPartial: (@MainActor @Sendable (String) -> Void)? = nil) async -> LocalImageAnswer {',
 '    static func spot(target: String, image: CVPixelBuffer, arabic: Bool, modelContext: CompanionModelContext, requestID: UUID? = nil) async -> String? {',
 '                         situation: [String: Any], wordAllowance: Int, confirmedObjects: [String] = [], modelContext: CompanionModelContext, requestID: UUID? = nil) async -> LocalImageAnswer {'
]:
 m=once(m,signature,signature+'\n        #if DEBUG && BLIND_WORKFLOW_TESTS && BLIND_ACCESSIBLE_OUTPUT_TESTS\n        preconditionFailure("ISOLATION VIOLATION: model execution disabled in accessible output probe")\n        #endif')
model.write_text(m)
p=out/'ios/BlindAssist/Feedback.swift';s=p.read_text()
s=once(s,'    private let speech = AVSpeechSynthesizer()','''    #if DEBUG && BLIND_WORKFLOW_TESTS && BLIND_ACCESSIBLE_OUTPUT_TESTS
    var accessibleOutputObserver: ((AccessibleOutputReceipt) -> Void)? = nil
    #endif
    private let speech = AVSpeechSynthesizer()''')
s=once(s,'            speech.speak(utterance)','''            #if DEBUG && BLIND_WORKFLOW_TESTS && BLIND_ACCESSIBLE_OUTPUT_TESTS
            observeAccessibleOutput("admitted", attempt: attempt, cause: "AVSpeech.enqueue")
            #endif
            speech.speak(utterance)''')
s=once(s,'            case .untracked: break\n            }\n        }\n        if notify { notifyIdle() }','''            case .untracked: break
            }
            #if DEBUG && BLIND_WORKFLOW_TESTS && BLIND_ACCESSIBLE_OUTPUT_TESTS
            // Emitted only after the real ledger result and controller callback.
            // Timers/cancellation remain noncompletion, even if a caller mislabels outcome.
            let confirmed = completion.outcome == .completed &&
                completion.attempt.transport == .synthesized && diagnosticCause == "AVSpeech.didFinish"
            self.observeAccessibleOutput(confirmed ? "completed" : "cancelled", attempt: completion.attempt,
                                         cause: diagnosticCause, outcome: completion.outcome)
            #endif
        }
        if notify { notifyIdle() }''')
s=once(s,'''        if let routeID = currentSpatialRouteID, spatialRoutePermission?(routeID) != true {
            finishActive(outcome: .interrupted, stopSynthesizer: true,
                         diagnosticCause: "route.expiredBeforePlayback"); return
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish''','''        if let routeID = currentSpatialRouteID, spatialRoutePermission?(routeID) != true {
            finishActive(outcome: .interrupted, stopSynthesizer: true,
                         diagnosticCause: "route.expiredBeforePlayback"); return
        }
        #if DEBUG && BLIND_WORKFLOW_TESTS && BLIND_ACCESSIBLE_OUTPUT_TESTS
        observeAccessibleOutput("started", attempt: active, cause: "AVSpeech.didStart")
        #endif
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish''')
s+='\n'+(here/'FeedbackReceipt.swift.txt').read_text();p.write_text(s)
p=out/'ios/BlindAssistTests/CompanionNativeReplayTests.swift';p.write_text(p.read_text().replace('org.blindassist.workflowtests','org.blindassist.accessibleworkflowtests')+'\n'+(here/'NativeAccessibleOutputTests.swift').read_text())
p=out/'tools/generate-xcode-project.mjs';s=p.read_text().replace('org.blindassist.workflowtests','org.blindassist.accessibleworkflowtests').replace('BLIND_WORKFLOW_TESTS ','BLIND_WORKFLOW_TESTS BLIND_ACCESSIBLE_OUTPUT_TESTS ');p.write_text(s)
projection=out/'workflow-projection.json'; metadata=json.loads(projection.read_text())
metadata['sourceCommit']=pins['commit']
metadata['sourceVerification']='Exact accessible-probe checkout plus base and additional source fingerprint checks'
projection.write_text(json.dumps(metadata,indent=2)+'\n')
(out/'accessible-projection.json').write_text(json.dumps({'status':'PREPARED_NATIVE_NOT_RUN','baseline':pins['commit'],'sensorsAndMicRemainTextOnly':True,'output':'Actual controller queue to actual Feedback and AVSpeech callbacks; not driver TTS','actorRun':'NOT RUN','physicalOrAudibilityClaim':False},indent=2)+'\n')
