#!/usr/bin/env python3
"""Bounded source/real-artifact checks. NOT Swift execution, routing or safety tests."""
import hashlib, json, math
from pathlib import Path
H = Path(__file__).resolve().parent
R = H.parent.parent
PIN = 'e60c008fd5759ebf81863774f8335c27429a20b19253c95b2b6db45291bb44d2'
fixture = H/'Tests/BlindRoomPreviewTests/Fixtures/ROUTE_DIAGNOSTIC.json'
original = R/'research/room-mesh-package-75/ROUTE_DIAGNOSTIC.json'
checks = {}
def check(name, value):
    checks[name] = bool(value)
    assert value, name
check('fixture byte-identical to saved native diagnostic', fixture.read_bytes() == original.read_bytes())
check('frozen diagnostic SHA256', hashlib.sha256(fixture.read_bytes()).hexdigest() == PIN)
data = json.loads(fixture.read_bytes())
check('source has no physical authority', data['physicalAuthority'] is False)
for variant in ('actualOriginal', 'actualReplayed', 'actualExcluded'):
    check(variant+' five saved routes', len(data[variant]) == 5)
    for i, route in enumerate(data[variant]):
        check(f'{variant}/{i} finite 3D and native success',
              all(len(p)==3 and all(math.isfinite(v) for v in p) for p in route['points'])
              and route['status'] & (1<<30) != 0 and route['status'] & (1<<31) == 0)
        check(f'{variant}/{i} exact endpoints', route['points'][0] == route['projected_start']
              and route['points'][-1] == route['projected_goal'])
source = (R/'BlindCore/Sources/BlindCore/RoomMeshPreview.swift').read_text() + (H/'Sources/BlindRoomPreview/RoomMeshPreview.swift').read_text()
check('physical authority immutable false', 'public let physicalAuthority = false' in source)
check('saved unknown support retained', 'archive-does-not-prove-current-floor-support' in source)
check('runtime revision rechecked', source.count('runtime.isCurrent(candidate)') >= 3)
check('saved byte budget enforced', 'data.count <= 2_000_000' in source)
app = (R/'ios/BlindAssist/RecordedRoomRoutePreview.swift').read_text()
room = (R/'ios/BlindAssist/RoomDetailView.swift').read_text()
check('Core test fixture byte-identical', (R/'BlindCore/Tests/BlindCoreTests/Fixtures/recorded-room-route-diagnostic.json').read_bytes() == fixture.read_bytes())
check('actual app link exists', 'RecordedRoomRoutePreview(arabic: model.arabic)' in room)
check('app hash pinned to real artifact', PIN in app)
check('security scope paired', 'startAccessingSecurityScopedResource()' in app and 'stopAccessingSecurityScopedResource()' in app)
check('bounded read before decode', 'read(upToCount: 2_000_001)' in app and 'size <= 2_000_000' in app)
check('inactive/disappear retirement', '.onDisappear { visible = false; retireImport(); clear() }' in app and 'else { retireImport(); clear() }' in app)
check('preview has no physical output owners', all(v not in app for v in ['NavigationModel', 'ConnectedJourneyRuntime', 'SpatialMapInstallation(', 'AVSpeechSynthesizer', 'URLSession']))
check('explicit source hierarchy not current room', 'not your current room' in app and 'MuSHRoom-recorded' in app)
check('file URLs only', 'guard url.isFileURL else' in app)
check('captured presentation token checked before decode', 'let callbackToken = importToken' in app and 'let token = callbackToken, lease.finish(token)' in app)
check('explicit main actor and active view', '@MainActor struct RecordedRoomRoutePreview' in app and 'guard visible, scenePhase == .active' in app)
check('retirement invalidates pending token', 'active = false; pending = nil' in source)
receipt = dict(schema=2, checks=checks, checkCount=len(checks), passed=all(checks.values()),
               swiftCompiled=False, swiftTestsExecuted=False, iOSBuilt=False, physicalAuthority=False,
               routeReplayExecuted=False, sourceSHA256=PIN)
(H/'PORTABLE_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
