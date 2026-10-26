import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
const stage=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const root=existsSync(resolve(stage,'source'))?resolve(stage,'source'):resolve(stage,'../../..');
const get=p=>readFileSync(resolve(root,p),'utf8');
const model=get('ios/BlindAssist/NavigationModel.swift');
function body(source, marker) { const start=source.indexOf(marker); assert.ok(start>=0,marker); let i=source.indexOf('{',start)+1,d=1;const a=i;for(;d&&i<source.length;i++){if(source[i]==='{')d++;else if(source[i]==='}')d--;} assert.equal(d,0);return source.slice(a,i-1); }
test('actual frame invokes supplemental geometry only after urgent legacy result',()=>{
 const start=model.indexOf('let legacyDetection = detector.process(observation)');const end=model.indexOf('survey.observe',start);const flow=model.slice(start,end);
 assert.match(flow,/if legacyDetection.hazard.isUrgent/);assert.match(flow,/phoneDetection = legacyDetection/);
 assert.ok(flow.indexOf('} else {')<flow.indexOf('BodyCollisionWarning.assess'));
 assert.match(flow,/DepthSampler.cameraToWorld\(from: frame\)/);assert.match(flow,/now: receivedAt/);
 assert.match(flow,/!bodyHeadingEstimator.mountSlipSuspected/);
 assert.ok(model.indexOf('FrameTimestampPolicy.isFresh')<start);
});
test('startup binds actual private store and mutation retires old detection before publication',()=>{
 assert.match(model,/BodyProfileStore.shared.onProfileChanged/);assert.match(model,/BodyProfileStore.shared.load \{ _ in \}/);
 const retire=body(model,'private func retireBodyWarning(');assert.match(retire,/phoneDetection.reason == .bodyEnvelope/);assert.match(retire,/Detection\(.uncertain/);assert.match(retire,/publish\(\)/);
 assert.match(body(model,'func invalidateNativeLocalizationMount('),/retireBodyWarning\(\)/);
 const store=get('ios/BlindAssist/BodyProfileStore.swift');
 for(const marker of ['func save(','func erase(']){const scope=body(store,marker);assert.ok(scope.indexOf('onProfileChanged?(nil)')<scope.indexOf('io.submit'));}
 const finish=body(store,'private func finish(');assert.ok(finish.indexOf('io.isCurrent')<finish.indexOf('onProfileChanged?(value)'));
});
test('supplement is generic and has neither audio nor wearable direction cue',()=>{
 const feedback=get('ios/BlindAssist/Feedback.swift');assert.match(feedback,/detection.reason != .visualStairs && detection.reason != .bodyEnvelope \{ beacon/);
 assert.match(model,/detection.reason != .visualStairs && detection.reason != .bodyEnvelope \{\s*wearables.send/);
 const warning=get('BlindCore/Sources/BlindCore/BodyCollisionWarning.swift');assert.match(warning,/Detection\(.obstacle, reason: .bodyEnvelope\)/);
 assert.doesNotMatch(warning,/SpatialLocalizationCapture\(|acceptRegisteredCapture|configureConnectedJourney/);
});
test('full matrix passes unchanged; body profile remains local and no extra input page',()=>{
 assert.match(get('ios/BlindAssist/DepthSampler.swift'),/Double\(matrix\[column\]\[row\]\)/);
 const ui=get('ios/BlindAssist/BodyProfileSettingsView.swift');assert.doesNotMatch(ui,/yaw|pitch|roll|uncertainty in/);
 assert.match(ui,/Do not infer them from age or weight/);
 const store=get('ios/BlindAssist/BodyProfileStore.swift');assert.match(store,/isExcludedFromBackup = true/);assert.match(store,/completeFileProtection/);
});

test('session launch, stop, failure and interruption explicitly retire supplemental state',()=>{
 for(const marker of ['private func launch(map:','private func stopCameraMonitoring()','func session(_ session: ARSession, didFailWithError','func sessionWasInterrupted(']) {
   const flow=body(model,marker);assert.match(flow,/retireBodyWarning\(publishChange: false\)/,marker);
 }
 assert.match(body(model,'private func retireBodyWarning('),/bodyWarningAssessment = nil/);
 const frame=body(model,'func session(_ session: ARSession, didUpdate frame: ARFrame)');
 assert.match(frame,/running, !simulation, !places.scanning/);
 assert.ok(frame.indexOf('FrameTimestampPolicy.isFresh')<frame.indexOf('BodyCollisionWarning.assess'));
});

test('body settings expose the exact existing session binding and revision setter',()=>{
 const ui=get('ios/BlindAssist/BodyProfileSettingsView.swift'), dashboard=get('ios/BlindAssist/DashboardView.swift');
 assert.match(ui,/@Binding var fixedMount: Bool/);
 assert.match(ui,/Toggle\("Phone is attached to my body for this session", isOn: \$fixedMount\)/);
 assert.match(ui,/accessibilityIdentifier\("body-profile-session-mount"\)/);
 assert.match(ui,/not calibrated position or safe clearance/);
 assert.match(dashboard,/BodyProfileSettingsView\(fixedMount: \$model.fixedBodyMount,/);
 assert.match(dashboard,/mountControlAvailable: model.running && !model.simulation/);
 assert.match(body(model,'@Published var fixedBodyMount = false'),/invalidateNativeLocalizationMount\(slipped: mountSlipAnnounced\)/);
 assert.match(body(model,'private func launch(map:'),/fixedBodyMount = false/);
});
