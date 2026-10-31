#!/usr/bin/env python3
"""Bounded source contracts only; does NOT execute Swift, localization or a journey."""
from pathlib import Path
import argparse
import json

COORDINATOR = 'BlindCore/Sources/BlindCore/ConnectedJourneyCoordinator.swift'
RUNTIME = 'ios/BlindAssist/ConnectedJourneyRuntime.swift'
TESTS = 'ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift'
METHODS = [
    'testWithdrawnPortalDepartureReplansOnlyFromFreshDestinationEndpoint',
    'testExpiredPortalDepartureReplansOnFreshUpperFloorWithoutRecordingCrossing',
    'testFreshDifferentDestinationNodeDoesNotInventMissingPortalEndpoint',
    'testPortalRecoveryRefusesAmbiguousOrMidLegPoseUntilUniqueEndpointExists',
    'testPortalRecoveryRejectsOldSessionAndRestartRequiresNewLocalization',
    'testInterruptedReversePortalPreservesReturnGoalAndOriginalStart',
    'testGoalChangeDuringPortalInterruptionCannotReviveOldDestination',
]


def method(source, name):
    start = source.index('func ' + name + '(')
    begin = source.index('{', start)
    depth = 1
    for end in range(begin + 1, len(source)):
        depth += (source[end] == '{') - (source[end] == '}')
        if depth == 0:
            return source[start:end + 1]
    raise AssertionError('unterminated method: ' + name)


def check_sources(c, r, t):
    checks = []
    def check(name, value):
        assert value, name
        checks.append(name)
    recovery = method(c, 'retireUnassociatedPortal')
    check('only existing portal itinerary is eligible', 'guard case .portal(_, let from, let to)? = currentLeg' in recovery)
    check('current owner and exact destination binding required',
          'activeBinding == endpoint.binding, endpoint.binding == to.binding' in recovery)
    check('destination floor remains separate', 'endpoint.floorID == to.floorID else { return false }' in recovery)
    check('endpoint match retains exact node room binding floor', all(v in recovery for v in [
        'endpoint.binding == expected.binding', 'endpoint.floorID == expected.floorID',
        'endpoint.nodeID == expected.nodeID', 'expected.roomID == nil || endpoint.roomID == expected.roomID']))
    check('source endpoint retains existing rearm path', 'guard !matches(from) else { return false }' in recovery)
    check('current capture and support checked before retirement',
          '_ = try requireEndpoint(endpoint, now: now)' in recovery and
          recovery.index('_ = try requireEndpoint(endpoint, now: now)') < recovery.index('retirePlan()'))
    check('valid expected portal completion preserved',
          'if matches(to), pendingPortalDestination(now: now) != nil { return false }' in recovery and
          recovery.index('pendingPortalDestination(now: now)') < recovery.index('retirePlan()'))
    check('recovery only retires itinerary without fabricating history pose or geometry',
          all(v not in recovery for v in ['snapshot.', '.append(', '.accept(', 'beginLocalization(',
              'setGoal(', 'position.', 'support =', 'owner =', 'catalog =', 'armedPortal =']))
    check('recovery does not add a route algorithm',
          recovery.count('retirePlan()') == 1 and 'plan(' not in recovery and 'route(' not in recovery)
    accept = method(r, 'accept')
    order = [accept.index(v) for v in ['try owner.accept(capture, support: support, now: now)',
        'if let endpoint = currentEndpoint(capture: capture, support: support)',
        'if canOutput, snapshot.goal?.status == .active, !snapshot.returnClarificationPending',
        'try coordinator?.retireUnassociatedPortal(at: endpoint, now: now)',
        'try coordinator?.plan(from: endpoint, now: now)']]
    check('actual app consumer uses accepted unique endpoint and durable active goal before replan', order == sorted(order))
    check('single actual recovery consumer', r.count('retireUnassociatedPortal(at: endpoint, now: now)') == 1)
    check('runtime retires held output before recovered plan',
          'retireOutput(); routeReassociationReason = nil' in accept and
          accept.index('retireOutput(); routeReassociationReason = nil') < accept.index('try coordinator?.plan(from: endpoint, now: now)'))
    check('recovery status makes no crossing or clearance claim',
          'Replanning from fresh current location; the earlier transition was not verified.' in accept)
    endpoint = method(r, 'currentEndpoint')
    check('ambiguous and non-endpoint poses stay unresolved', 'guard candidates.count == 1 else { return nil }' in endpoint)
    check('endpoint association retains uncertainty and support height',
          'capture.positionUncertainty <= 0.35' in endpoint and 'abs($0.position.y - support.height) <= 0.09' in endpoint)
    required = method(c, 'requireEndpoint')
    check('fresh endpoint requires current exact pose floor room and associated support', all(v in required for v in [
        'owner?.currentPose(now: now)', 'pose.binding == endpoint.binding', 'pose.floorID == endpoint.floorID',
        'endpoint.roomID.map({ pose.roomID == $0 }) ?? true', 'support.captureID == pose.id',
        'support.sessionID == pose.sessionID', 'support.capturedAt == pose.capturedAt']))
    pending = method(c, 'pendingPortalDestination')
    check('original portal source ownership and 120 second bound remain', all(v in pending for v in [
        'id==armedPortal.id,from==armedPortal.from,to==armedPortal.to',
        'snapshot.goal?.revision==armedPortal.goal', 'now>=armedPortal.armedAt', 'now-armedPortal.armedAt<=120 else']))
    completion = method(c, 'completePortal')
    check('original completion still requires exact departure and fresh target', all(v in completion for v in [
        'armedPortal.id == id, armedPortal.from == from, armedPortal.to == to',
        'now - armedPortal.armedAt <= 120 else', 'try requireEndpoint(to, now: now)',
        'portalDepartureCaptureID: armedPortal.sourceCaptureID']))
    withdrawal = method(c, 'withholdNativeEvidence')
    check('withdrawal still drops departure evidence but keeps current owner ledger',
          'owner?.withholdLocalizationEvidence(); support = nil; armedPortal = nil' in withdrawal and
          'loseTracking(' not in withdrawal and 'beginLocalization(' not in withdrawal)
    check('original offroute blocked route reassociation retained', all(v in r for v in [
        'reason == .offRoute || reason == .blockedLeg', 'self.coordinator?.requireRouteReassociation();lastEndpoint=nil']))
    check('current hazards retain independent veto', 'public func retireCurrentObstacleEvidence() { retireOutput() }' in r)
    check('runtime durability and map invalidation gates unchanged',
          'private var canOutput: Bool { !loading && !externalMapPending && !mapValidationBlocked && mapWorkID == nil && durable && !storageError && !commandBlocked }' in r)
    check('restore still creates no live pose or itinerary',
          '// Restoration intentionally creates no owner, pose, itinerary or receipt.' in c and
          'Journey intent restored. Live location is unknown.' in r)
    check('all seven authored hosted regressions present', all('func ' + v + '(' in t for v in METHODS))
    check('lost-source test requires a new capture and unchanged history', all(v in method(t, METHODS[0]) for v in [
        'XCTAssertThrowsError(try runtime.next(now: 1.4))', 'time: 1.5', 'try runtime.snapshot.encoded(), before']))
    check('expired association case is explicitly another floor and beyond original lease', all(v in method(t, METHODS[1]) for v in [
        'upperFloor: true', 'time: 121.31', 'onward.route.spatial.floorID, "upper"']))
    check('ambiguous and no-endpoint authored controls withhold route', all(v in method(t, METHODS[3]) for v in [
        'ambiguousEntry: true', 'position: .init(2,1.3,3)',
        'XCTAssertThrowsError(try runtime.next(now: 1.4))', 'XCTAssertThrowsError(try runtime.next(now: 1.5))']))
    check('old-session stale-capture and restart negatives authored', all(v in method(t, METHODS[4]) for v in [
        'sessionID: departure.sessionID', 'XCTAssertNil(restored.expectedSessionID)',
        'Requested owner is not localization.', 'F.limits.maximumCaptureAge + 0.01']))
    check('reverse return intent survives interrupted portal without inventing another crossing', all(v in method(t, METHODS[5]) for v in [
        'returning.purpose, .returnToStart', 'runtime.goal?.revision, returning.revision',
        'runtime.goal?.status, .arrived', '}.count, associations']))
    check('explicit changed goal cannot revive predecessor', all(v in method(t, METHODS[6]) for v in [
        'nodeID: "m", origin: .trustedInterface', 'XCTAssertNotEqual(runtime.goal?.revision, prior?.revision)',
        'runtime.next(now: 1.4).route.target.id, "m"']))
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    names = check_sources(*[(args.root / p).read_text() for p in [COORDINATOR, RUNTIME, TESTS]])
    print(json.dumps({'checks': len(names), 'names': names, 'authoredHostedMethods': METHODS,
                      'nativeExecuted': False, 'deviceExecuted': False, 'physicalAuthority': False}, indent=2))


if __name__ == '__main__':
    main()
