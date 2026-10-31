#!/usr/bin/env python3
"""Exact source/mutation evidence, not Swift or actual-model runtime execution."""
import json
from pathlib import Path
H=Path(__file__).resolve().parent
R=H.parents[2]
BASE=json.loads((H/'BASELINE_METHODS.json').read_text())
OLD_DETECTION='        detection = continuity.process(AlertPolicy.highest(visual + [phoneDetection] + (simulation ? [] : wearables.detections(at: now))), at: now)'
NEW_DETECTION='''        let nextDetection = continuity.process(AlertPolicy.highest(visual + [phoneDetection] + (simulation ? [] : wearables.detections(at: now))), at: now)
        // Practice keeps processing every tick, but identical presentation values
        // must not invalidate the whole accessibility tree ten times per second.
        // Live publication and all safety/policy work below remain unchanged.
        if !simulation || detection != nextDetection { detection = nextDetection }'''
OLD_PROGRESS='        calibrationProgress = detector.calibrationProgress'
NEW_PROGRESS='''        if calibrationProgress != detector.calibrationProgress {
            calibrationProgress = detector.calibrationProgress
        }'''
def body(s,sig):
    a=s.index(sig); b=s.index('{',a+len(sig)); depth=0
    for i in range(b,len(s)):
        depth+=(s[i]=='{')-(s[i]=='}')
        if depth==0:return s[a:i+1]
    raise AssertionError(sig)
def validate(nav,dashboard):
    for sig,old in BASE.items():
        actual=body(nav,sig)
        if sig=='    private func publish()':
            assert actual.count(NEW_DETECTION)==1
            actual=actual.replace(NEW_DETECTION,OLD_DETECTION)
        if sig=='    private func demoFrame()':
            assert actual.count(NEW_PROGRESS)==1
            actual=actual.replace(NEW_PROGRESS,OLD_PROGRESS)
        assert actual==old, 'unreviewed method difference: '+sig
    # The only two callsites remain startup calibration and the normal watchdog.
    assert nav.count('demoFrame()')==3
    block='''                if model.simulation {
                    Text(t("Practice only · no live camera", "تدريب فقط · دون كاميرا مباشرة"))
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("practice-active-status")
                    Button(t("End practice", "أنهِ التدريب")) { model.endPractice() }
                        .accessibilityIdentifier("end-practice")'''
    assert dashboard.count(block)==1
    assert dashboard.count('Text(t("SIMULATION · generated readings", "محاكاة · قراءات مولدة"))')==1
    assert dashboard.count('.accessibilityIdentifier("practice-active-status")')==1

def main():
    n=(R/'ios/BlindAssist/NavigationModel.swift').read_text(); d=(R/'ios/BlindAssist/DashboardView.swift').read_text()
    validate(n,d)
    monitor=d[d.index('    private var monitor: some View {'):]
    mutations=[
        ('remove simulation scope',n.replace('if !simulation || detection != nextDetection','if detection != nextDetection',1),d),
        ('invert simulation scope',n.replace('if !simulation || detection != nextDetection','if simulation || detection != nextDetection',1),d),
        ('suppress all simulation publication',n.replace('if !simulation || detection != nextDetection','if !simulation',1),d),
        ('remove changed detection delivery',n.replace('detection = nextDetection','_ = nextDetection',1),d),
        ('early return skips policies',n.replace('if !simulation || detection != nextDetection { detection = nextDetection }','guard !simulation || detection != nextDetection else { return }; detection = nextDetection',1),d),
        ('skip continuity',n.replace('let nextDetection = continuity.process(AlertPolicy.highest(visual + [phoneDetection] + (simulation ? [] : wearables.detections(at: now))), at: now)','let nextDetection = phoneDetection',1),d),
        ('drop spatial freshness',n.replace('        spatialRouteOutput.revalidate()\n','',1),d),
        ('drop hazard policy',n.replace('if policy.shouldAnnounce(detection, at: now)','if false',1),d),
        ('drop changed calibration',n.replace('if calibrationProgress != detector.calibrationProgress {','if false {',1),d),
        ('invert calibration change',n.replace('if calibrationProgress != detector.calibrationProgress {','if calibrationProgress == detector.calibrationProgress {',1),d),
        ('slow watchdog',n.replace('Timer(timeInterval: 0.1, repeats: true)','Timer(timeInterval: 1, repeats: true)',1),d),
        ('remove scene expiry',n.replace('self.withObservedScene { $0.revalidate(now: ProcessInfo.processInfo.systemUptime) }','',1),d),
        ('remove watchdog publication',n.replace(body(n,'    private func startWatchdog()'),body(n,'    private func startWatchdog()').replace('            self.publish()\n','',1),1),d),
        ('longer automatic expiry',n.replace('Timer.scheduledTimer(withTimeInterval: 120, repeats: false)','Timer.scheduledTimer(withTimeInterval: 240, repeats: false)',1),d),
        ('unconditional adjacent status',n,d.replace(monitor,monitor.replace('if model.simulation {\n                    Text(t("Practice only · no live camera"','if true {\n                    Text(t("Practice only · no live camera"',1),1)),
        ('remove original top status',n,d.replace('Text(t("SIMULATION · generated readings", "محاكاة · قراءات مولدة"))','Text("Other")',1)),
    ]
    for name,m,v in mutations:
        assert (m,v)!=(n,d),name+' did not mutate'
        try:validate(m,v)
        except (AssertionError,ValueError):pass
        else:raise AssertionError('accepted mutation '+name)
    consumers=[]
    for folder in ['ios/BlindAssist','BlindCore/Sources','BlindMemory/Sources']:
        for p in (R/folder).rglob('*.swift'):
            for token in ['$detection','$calibrationProgress']:
                if token in p.read_text(): consumers.append(str(p.relative_to(R))+':'+token)
    assert not consumers, 'new direct publisher consumer requires review'
    print(json.dumps({'exactBaselineMethods':5,'rejectedMutations':len(mutations),'directPublisherConsumers':consumers,'scope':'source-only; indirect dynamic subscribers not ruled out','swiftExecuted':False,'nativeUIExecuted':False},indent=2))
if __name__=='__main__':main()
