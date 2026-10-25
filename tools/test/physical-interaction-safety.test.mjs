// Source contracts: withholding paths, not real-world identity/measurement accuracy.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL('../../'+p,import.meta.url),'utf8');
function declaration(source, signature) {
 const start=source.indexOf(signature); assert.ok(start>=0,signature);
 const open=source.indexOf('{',start); let depth=0;
 for(let i=open;i<source.length;i++) {
  if(source[i]==='{') depth++;
  if(source[i]==='}' && --depth===0) return source.slice(start,i+1);
 }
 assert.fail(`Unclosed declaration: ${signature}`);
}
test('unvalidated instance-depth binding cannot speak approach or reach guidance',async()=>{
 const s=await read('ios/BlindAssist/NavigationModel.swift');
 assert.match(s,/private static let objectInteractionGuidanceValidated = false/);
 const find=declaration(s,'private func findWithSensors(');
 const checkSavedGeometry=body=>{
  const start=body.indexOf('if item.scope == nil, Self.objectInteractionGuidanceValidated,');
  const end=body.indexOf('            say(ItemMemory.answer(',start);
  assert.ok(start>=0 && end>start,'Exact saved-item geometry conditional before its answer');
  const spatial=body.slice(start,end);
  assert.match(spatial,/sameFrame, let target = item\.position, let observation = lastObservation/);
  assert.match(spatial,/let here = indoor\.mapPosition\(camera: observation\.camera\)/);
  assert.match(spatial,/let facing = currentBodyForward\(\)\.flatMap\(\{ indoor\.mapDirection\(\$0\) \}\)/);
  assert.match(spatial,/let measured = SpatialFacts\.relation\(from: here, facing: facing, to: target\)/);
  assert.match(spatial,/relation = SpatialFacts\.phrase\(label: item\.name, relation: measured/);
 };
 checkSavedGeometry(find);
 const marker='if item.scope == nil, Self.objectInteractionGuidanceValidated, sameFrame,';
 for(const gate of ['item.scope == nil, ', 'Self.objectInteractionGuidanceValidated, ', 'sameFrame,']) {
  assert.ok(find.includes(marker));
  assert.throws(()=>checkSavedGeometry(find.replace(marker,marker.replace(gate,''))),{name:'AssertionError'},`Missing saved-item geometry gate: ${gate}`);
 }
 assert.match(s,/if !Self.objectInteractionGuidanceValidated \{\s*phrase = ObjectSearch.unconfirmed/);
 assert.match(s,/recordSearch\(target, located: Self.objectInteractionGuidanceValidated && located != nil\)/);
 assert.match(s,/if Self.objectInteractionGuidanceValidated, let located/);
 assert.match(s,/private func updateTrackedTarget\(\) \{\s*guard Self.objectInteractionGuidanceValidated else \{ trackedTarget = nil; return \}/);
 assert.doesNotMatch(s,/If you can reach it, (?:lift|hold)|within reach/);
});
test('saved similarity uses current identity before clearing inflight and gives no pickup authority',async()=>{
 const s=await read('ios/BlindAssist/NavigationModel.swift');
 const start=s.indexOf('private func findItemByLook');const end=s.indexOf('private func verifyHeldItem',start);const b=s.slice(start,end);
 assert.ok(b.indexOf('self.requestID == request')<b.indexOf('self.lookupInFlight = false'));
 assert.match(b,/self.objectViewIsCurrent\(capture\)/);
 assert.match(b,/if !Self.objectInteractionGuidanceValidated[\s\S]*case .same, .similar: self.say\(ObjectSearch.unconfirmed/);
 assert.match(b,/measuredRelation: nil/);
 const search=await read('BlindCore/Sources/BlindCore/ObjectSearch.swift');
 assert.match(search,/I cannot confirm the exact item or safe handling/);
 assert.doesNotMatch(search,/Turn slowly\./);
});
test('foreground sensing defaults on without overriding saved choices or permissions',async()=>{
 const s=await read('ios/BlindAssist/NavigationModel.swift');
 assert.match(s,/object\(forKey: "camera-awareness"\) as\? Bool \?\? true/);
 assert.match(s,/guard !running, !places.scanning, assistantSession.foregroundActive, cameraAwareness, !textOnly/);
 assert.match(s,/AVCaptureDevice.authorizationStatus\(for: .video\)/);
 assert.match(s,/case .notDetermined:[\s\S]*AVCaptureDevice.requestAccess/);
});
test('held-item similarity cannot authorize an exact identity or unsafe pickup',async()=>{
 const s=await read('ios/BlindAssist/NavigationModel.swift');
 const b=s.slice(s.indexOf('private func verifyHeldItem'),s.indexOf('var savedItems:'));
 assert.match(b,/guard Self.objectInteractionGuidanceValidated else/);
 assert.ok(b.indexOf('guard Self.objectInteractionGuidanceValidated')<b.indexOf('case .same:'));
 assert.match(b,/I cannot confirm this is your exact item from this comparison/);
 assert.match(b,/self.objectViewIsCurrent\(capture\)/);
});
test('temperature stays source-owned while local finds can inspect without physical guidance',async()=>{
 const s=await read('ios/BlindAssist/NavigationModel.swift');
 assert.match(s,/routeUnavailableTemperature\(text\)/);
 assert.match(s,/requiresLiveTemperature\(for: question\)/);
 assert.match(s,/I don't have a live weather or thermometer reading/);
 const b=s.slice(s.indexOf('private func routeUnverifiedPhysicalRequest'),s.indexOf('private func answerConversation'));
 assert.match(b,/case \.find\(let object\) = utterance/);
 assert.match(b,/findWithSensors\(target, question: question\)/);
 assert.doesNotMatch(b,/LocalImageAssistant/);
});
test('fresh familiar arrival uses scoped cancellable attention admission',async()=>{
 const s=await read('ios/BlindAssist/NavigationModel.swift');
 assert.match(s,/familiarPeople\.revalidate\(model: self\)\s*familiarPeople\.consume\(model: self\)/);
 const b=s.slice(s.indexOf('familiarPeople.onArrivalHint ='),s.indexOf('wearables.onUpdate'));
 assert.match(b,/familiarCaptureIsCurrent\(hint.capture\)/);
 assert.match(b,/kind: \.social/); assert.match(b,/requested: false, goalRelevant: true/);
 assert.match(b,/speechID: hint.encounterID/);
 assert.match(s,/familiarPeople\.arrivalSpeechFinished\(id\)/);
 const f=await read('ios/BlindAssist/Feedback.swift');
 assert.match(f,/func stopRequestedSpeech\(_ id: UUID\) \{\s*guard delivery.active\?\.destination == \.requested\(id\) else \{ return \}/);
});
