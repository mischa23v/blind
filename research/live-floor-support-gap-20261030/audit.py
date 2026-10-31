#!/usr/bin/env python3
"""Read-only, bounded source audit. Does not execute Swift or authorize movement."""
import argparse, hashlib, json, pathlib, re

P = argparse.ArgumentParser()
P.add_argument('--repo', type=pathlib.Path, required=True)
P.add_argument('--overlay', type=pathlib.Path, action='append', default=[], help='Highest priority first')
a = P.parse_args()
here = pathlib.Path(__file__).resolve().parent
pins = json.loads((here / 'SOURCE_PINS.json').read_text())
checks = []
sources = {}
for pin in pins['files']:
    matches = [base / pin['path'] for base in [*a.overlay, a.repo] if (base / pin['path']).is_file()]
    assert matches, pin['path']
    raw = matches[0].read_bytes()
    assert len(raw) <= 1_000_000, pin['path']
    assert hashlib.sha256(raw).hexdigest() == pin['sha256'], 'Source changed: ' + pin['path']
    sources[pin['path']] = raw.decode()
checks.append({'name': 'all exact source pins', 'passed': True, 'files': len(sources)})

def has(path, name, *parts):
    source = sources[path]
    for part in parts:
        assert part in source, (name, part)
    checks.append({'name': name, 'passed': True})

C = 'BlindCore/Sources/BlindCore/'
I = 'ios/BlindAssist/'
has(I+'DepthSampler.swift', 'raw hazard depth/confidence and exact pose', 'frame.sceneDepth', 'depth.confidenceMap', 'NativeDepthObservationPolicy.projection(', 'frame.camera.transform', 'timestamp: frame.timestamp')
has(C+'NativeDepthObservationPolicy.swift', 'current raw sampling limits', 'pixelStride = 2', 'requiredConfidence: UInt8 = 2', 'depthRange = 0.15...5.0', 'minimumHorizontalOpticalLength: Float = 0.25')
has(I+'DepthSampler.swift', 'horizontal heading remains required only for hazard observation', 'guard let forward = NativeDepthObservationPolicy.horizontalForward(')
has(C+'HazardDetector.swift', 'hazard near exclusion and retained datum', '(0.3...2.2).contains(c.ahead)', 'floorHeight = sorted[sorted.count / 2]')
has(C+'GroundGeometryEvidence.swift', 'diagnostic patch exclusion and no motion authority', 'c.ahead >= 0.3', 'authorizesPhysicalGuidance: Bool { false }', 'unvalidated-shadow-v1')
has(C+'LocalPlanner.swift', 'look-ahead start not wearer foot', 'let start = Cell(x: 0, z: Int((0.6 / resolution).rounded()))', 'unobserved ground directly under the wearer')
has(C+'CurrentNavigationHazards.swift', 'hazard receipt has no support authority', 'fullFootprintSupportKnown: Bool { false }', 'authorizesPhysicalGuidance: Bool { false }')
has(I+'NativeARObservationAdapter.swift', 'historical pixels retain original confidence and bounded raster', 'frame.sceneDepth.map', '> 1024', 'NativeDepthPixel(column: column, row: row, metres: metres, confidence: level)')
has(I+'NativeARObservationAdapter.swift', 'historical full pose and acquisition time', 'cameraToSessionWorld: transform(frame.camera.transform)', 'capturedAt: frame.timestamp')
has(C+'NativeObservationPipeline.swift', 'history admission does not renew source timestamps', 'capturedAt - lastAdmitted >= 0.5', 'record.capturedAt == capturedAt')
has(I+'NavigationModel.swift', 'missing calibration is explicit', 'nativeLocalizationCalibrationRevision = "unconfigured"')
has(I+'NavigationModel.swift', 'original-frame mapping and history offers exist', 'mapping.consume(frame)', 'nativeObservations.offer(frame, sessionID: nativeSessionID', 'defer { offerNativeLocalization(frame, now: ProcessInfo.processInfo.systemUptime) }')
has(I+'NativeLocalizationIssuer.swift', 'issuer is withheld not a producer', '.localReferenceOnly : .missingCalibration', 'retireRegisteredOutput?(value.owner)', 'invalidate(.physicalReleaseNotApproved)')
has(C+'NativeLocalizationEvidence.swift', 'actual production measurement prerequisites', 'guard let calibration = measurement.calibration', 'guard let support = measurement.support', 'guard let error = measurement.errorModel', 'case .unvalidated: throw fail(.unvalidatedEvidence)')
has(C+'NativeLocalizationEvidence.swift', 'same-instant source-time restriction exists', 'support.observedAt == c.capturedAt, error.observedAt == c.capturedAt')
has(C+'NativeLocalizationEvidence.swift', 'reference-only owner cannot mint physical bench pair', 'currentOwner.selection.kind != .localSavedFrameReference')
has(C+'NativeLocalizationEvidence.swift', 'candidate association and exact ownership boundary', 'candidate.association.capturedAt == candidate.capturedAt', 'pending == measurement.candidate', 'guard owner == currentOwner')
has(C+'NativeLocalizationEvidence.swift', 'freshness and evidence expiry mandatory', 'fresh(c.capturedAt, now: now)', '[calibration, support, error].allSatisfy', 'expiresAt: min(c.capturedAt + maximumAge')
has(C+'BodyProfile.swift', 'mount metadata is not calibration', 'Not a camera-to-map transform, floor measurement, or body-heading calibration.', 'current measured chest-to-body transform')
has(C+'NativeLocalGrid.swift', 'current pose and historical tiles have separate expiry', 'now - $0.value.capturedAt <= 30', 'now - capturedAt > 0.5', 'Ground/empty labels are not walking support.')
has(I+'NativeMapping.swift', 'mapping refuses floor-support authority', 'never SpatialFloorSupport', 'navigationEvidence(now: Double)')
# Absence checks cover explicit constructor/accept spellings only, not arbitrary Swift data flow.
issuer_code = re.sub(r'//[^\n]*', '', sources[I+'NativeLocalizationIssuer.swift'])
assert not re.search(r'\bacceptRegisteredCapture\s*\(', issuer_code)
checks.append({'name': 'issuer has no explicit acceptRegisteredCapture call', 'passed': True})
print(json.dumps({'scope': 'pinned source inspection only', 'checks': checks, 'passed': len(checks),
                  'swiftExecuted': False, 'deviceExecuted': False, 'physicalAuthority': False}, indent=2))
