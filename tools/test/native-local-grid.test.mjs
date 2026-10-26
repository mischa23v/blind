import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read = p => readFile(new URL(`../../${p}`, import.meta.url), 'utf8');
const model = await read('ios/BlindAssist/NavigationModel.swift');
const native = await read('ios/BlindAssist/NativeMapping.swift');
const patch = await read('integration/rtabmap/local-grid.patch');
const bridge = await read('integration/rtabmap/BlindLocalGridBridge.hpp');
const consumer = await read('BlindCore/Sources/BlindCore/NativeLocalGrid.swift');
const requiredOrder = (s,a,b) => { const x=s.indexOf(a),y=s.indexOf(b); assert.ok(x>=0&&y>=0&&x<y, `${a} must exist before ${b}`); };
function admission(source) {
  const start=source.indexOf('func session(_ session: ARSession, didUpdate frame:'); assert.ok(start>=0);
  const frame=source.slice(start);
  requiredOrder(frame,'mapping.trackingLost(at: frame.timestamp)','guard running');
  const fresh='guard FrameTimestampPolicy.isFresh(capturedAt: frame.timestamp, receivedAt: receivedAt) else { return }';
  const deferred=/defer \{\s*if buildPrivateMap, running, !simulation, !places.scanning,[\s\S]*?mapping\.consume\(frame\)\s*\}\s*\}/;
  const match=frame.match(deferred);assert.ok(match,'RTAB work must be deferred with native lifecycle guards');
  requiredOrder(frame,fresh,match[0]);requiredOrder(frame,match[0],'guard let observation = DepthSampler.observation(from: frame) else');
  assert.equal((frame.match(/mapping\.consume\(frame\)/g)??[]).length,1,'no double consume');
  // Swift defer executes on the nil-depth return only after the urgent failure
  // assignment/publish, and on success after urgent detector/body arbitration.
  const missing=frame.slice(frame.indexOf('guard let observation = DepthSampler.observation(from: frame) else'),frame.indexOf('if !observation.trackingNormal'));
  requiredOrder(missing,'phoneDetection = Detection(.uncertain','publish()');requiredOrder(missing,'publish()','return');
  requiredOrder(frame,'let legacyDetection = detector.process(observation)','phoneDetection = BodyCollisionWarning.combining(legacyDetection, with: bodyAssessment)');
  requiredOrder(frame,'phoneDetection = BodyCollisionWarning.combining(legacyDetection, with: bodyAssessment)','calibrationProgress = detector.calibrationProgress; publish()');
  return frame;
}
test('real native frame admission is after freshness and urgent work, independent of nil depth',()=>{admission(model);});
test('frame wiring mutations reject premature, duplicate, stale/future and missing loss handling',()=>{
  const frame=admission(model);const loss='mapping.trackingLost(at: frame.timestamp)';
  assert.throws(()=>admission(model.replaceAll(loss,'')));
  assert.throws(()=>admission(model.replaceAll(loss,'').replace('frame.timestamp - lastProcessed >= 1.0 / 15 else { return }', '$&\n        '+loss)));
  assert.throws(()=>admission(model.replace('guard FrameTimestampPolicy.isFresh(capturedAt: frame.timestamp, receivedAt: receivedAt) else { return }','')));
  assert.throws(()=>admission(model.replace('mapping.consume(frame)','mapping.consume(frame); mapping.consume(frame)')));
  const deferred=frame.match(/defer \{\s*if buildPrivateMap, running, !simulation, !places.scanning,[\s\S]*?mapping\.consume\(frame\)\s*\}\s*\}/)[0];
  assert.throws(()=>admission(model.replace(deferred,deferred.replace('defer {','do {'))));
});
test('native map lifecycle and latest loss capture fence cannot revive an old session',()=>{
  assert.match(native,/localGridGeneration \+= 1; localGridConsumer\.begin\(generation: localGridGeneration\)/);
  assert.match(native,/self\.engine === engine, self\.active/);
  assert.match(native,/frame\.timestamp > minimumGridCapture/);
  assert.match(native,/FrameTimestampPolicy\.isFresh\(capturedAt: \$0, receivedAt: now\) \? \$0 : nil \} \?\? now/);
  requiredOrder(native.slice(native.indexOf('func trackingLost')), 'minimumGridCapture = max', 'guard !gridTrackingLost');
  requiredOrder(native.slice(native.indexOf('func consume')), 'trackingLost(at: frame.timestamp)', 'frame.timestamp - lastFrame >= 0.5');
  assert.match(native,/RunLoop\.main\.add\(gridWatchdog, forMode: \.common\)/);
  assert.match(native,/func stop\(\) \{[\s\S]*?clearLocalGrid\(\)[\s\S]*?engine\.disableLocalGrid\(\)/);
  assert.match(native,/func deleteMapFiles\(\) \{\s*clearLocalGrid\(\)/);
});
test('pinned producer exports actual local grids and capture association before input publication',()=>{
  assert.match(patch,/originalCameraColumnCount==16/);
  assert.match(patch,/originalCameraColumns\.withUnsafeBufferPointer/);
  assert.match(patch,/camera_->getStampEpochOffset\(\)\+stamp,stamp/);
  assert.match(patch,/emitBlindGrid\(\(\(rtabmap::RtabmapEvent\*\)event\)->getStats\(\)\)/);
  assert.match(patch,/getSignaturesData\(\)\.find\(stats\.refImageId\(\)\)/);
  assert.match(patch,/source\.rows!=1\|\|source\.type\(\)!=CV_32FC4/);
  for(const name of ['gridGroundCellsRaw','gridObstacleCellsRaw','gridEmptyCellsRaw'])assert.match(patch,new RegExp(name+'\\(\\)'));
  assert.doesNotMatch(patch,/uncompressData|GetCameraPose\(\)|odomCovariance|localizationCovariance/);
  assert.match(native,/"RGBD\/CreateOccupancyGrid": "true"/);assert.match(native,/"Grid\/3D": "true"/);
  assert.match(native,/engine\.supportsLocalGridRayTracing \? "true" : "false"/);
});
test('callback lifetime and buffers are bounded and explicitly copied before main dispatch',()=>{
  assert.match(bridge,/class CallbackSlot/);
  assert.doesNotMatch(native,/setupCallbacksWithCPP/);
  assert.match(patch,/swiftClassPtr_=nullptr/);assert.match(bridge,/std::lock_guard<std::mutex> lock\(mutex_\)/);
  assert.match(patch,/weak var owner: RTABMap\?/);assert.doesNotMatch(patch,/passUnretained\(self\)/);
  assert.match(patch,/drain prior context before replacing it/);
  assert.match(patch,/All C buffers are copied NOW/);assert.match(patch,/pending = packet/);
  assert.match(patch,/inspected\+\+==BLIND_GRID_MAX_POSES/);
  assert.match(bridge,/std::array<Capture,128>/);assert.match(bridge,/BLIND_GRID_MAX_CELLS = 4096/);
});
test('class absence truncation and geometry corrections cannot become physical clearance',()=>{
  assert.match(consumer,/authorizesPhysicalGuidance: Bool \{ false \}/);
  assert.match(consumer,/tiles = tiles\.compactMapValues/);assert.match(consumer,/guard let pose = poses\[tile.nodeID\]/);
  for(const source of [native,consumer,patch])assert.doesNotMatch(source,/acceptConnectedJourneyCapture\(|acceptRegisteredCapture\(|SpatialLocalizationCapture\(/);
  assert.doesNotMatch(consumer,/\.plan\(|supportHeightError: 0|positionUncertainty:/);
  assert.match(native,/Not walking guidance/);
});

test('C callback never upgrades owner and map geometry has no LLM authority path',()=>{
  const start=patch.indexOf('+        setBlindGridCallbackNative(native_rtabmap,'), end=patch.indexOf('+    func resetLocalGrid');
  assert.ok(start>=0&&end>start);const callback=patch.slice(start,end);
  assert.ok(callback.length>0);assert.match(callback,/box\.enqueue\(copied\)/);
  assert.doesNotMatch(callback,/box\.owner|let owner =|owner\.enqueue/);
  for(const source of [native,bridge,consumer,patch])assert.doesNotMatch(source,/OpenAI|LLMClient|FoundationModels|LanguageModelSession|SystemLanguageModel|generateContent|chat\.completions|responses\.create|generateTrajectory/);
  assert.match(patch,/Resolve owner ONLY on main/);
});
