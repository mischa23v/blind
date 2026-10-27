// Bounded Swift SOURCE contracts, not native callback execution or safety proof.
import assert from 'node:assert/strict';

export const frameSignature = 'func session(_ session: ARSession, didUpdate frame: ARFrame)';
export const depthHazardsCall = 'processDepthHazards(observation, frame: frame, receivedAt: receivedAt)';
export const depthHazardsSignature = 'private func processDepthHazards(';
export const withoutComments = source => source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');

export function declaration(source, signature) {
  const start = source.indexOf(signature);
  assert.ok(start >= 0, `Missing declaration: ${signature}`);
  const open = source.indexOf('{', start + signature.length);
  assert.ok(open >= 0, `Missing body: ${signature}`);
  let depth = 0;
  for (let index = open; index < source.length; index++) {
    if (source[index] === '{') depth++;
    if (source[index] === '}' && --depth === 0) return source.slice(start, index + 1);
  }
  assert.fail(`Unclosed declaration: ${signature}`);
}

export function assertDepthHazardsBefore(source, later) {
  const frame = declaration(withoutComments(source), frameSignature);
  const helper = declaration(withoutComments(source), depthHazardsSignature);
  const body = helper.slice(helper.indexOf('{') + 1, -1);
  // The extracted helper must still execute the actual urgent detector first,
  // with direct assignments on both branches. A renamed/empty helper or a Task,
  // defer, conditional bypass, early return or ordinary work cannot substitute.
  const expected = `
        let legacyDetection = detector.process(observation)
        if legacyDetection.hazard.isUrgent {
            bodyWarningAssessment = nil; phoneDetection = legacyDetection
        } else {
            let bodyAssessment = BodyCollisionWarning.assess(observation,
                cameraToWorld: DepthSampler.cameraToWorld(from: frame), profile: bodyWarningProfile,
                fixedMount: fixedBodyMount && !mountSlipAnnounced && !bodyHeadingEstimator.mountSlipSuspected,
                now: receivedAt, floorHeight: detector.floorHeight)
            bodyWarningAssessment = bodyAssessment
            phoneDetection = BodyCollisionWarning.combining(legacyDetection, with: bodyAssessment)
        }`;
  const normalized = text => text.replace(/\s+/g, ' ').trim();
  assert.equal(normalized(body), normalized(expected), 'Actual detector and both synchronous hazard assignments remain intact');
  const call = frame.indexOf(depthHazardsCall), consumer = frame.indexOf(later);
  assert.ok(call >= 0 && consumer > call, `Synchronous depth hazards must precede ${later}`);
  assert.equal(frame.indexOf(depthHazardsCall, call + 1), -1, 'One ordinary-frame depth hazard call');
  const before = frame.slice(frame.indexOf('{') + 1, call);
  const depth = [...before].reduce((value, character) => value + (character === '{' ? 1 : character === '}' ? -1 : 0), 0);
  assert.equal(depth, 0, 'Hazard helper call is not conditionally or asynchronously nested');
  const compilationDepth = before.split('\n').reduce((value, line) =>
    value + (/^\s*#if\b/.test(line) ? 1 : /^\s*#endif\b/.test(line) ? -1 : 0), 0);
  assert.equal(compilationDepth, 0, 'Hazard helper call cannot disappear behind a conditional-compilation gate');
  assert.equal(before.slice(before.lastIndexOf('\n') + 1).trim(), '', 'No await/defer/Task prefix on hazard call');
  assert.match(frame.slice(call + depthHazardsCall.length), /^\s*\n/, 'Hazard call completes as its own statement');
}
