#!/usr/bin/env bash
set -euo pipefail
stage=$(cd "$(dirname "$0")/.." && pwd)
if [[ -d "$stage/source" ]]; then
  base=${BLIND_SOURCE_ROOT:-/workspace/scratch/90f3f6703064/blind-selected-document/source}
  overlay="$stage/source"
else
  base=${BLIND_SOURCE_ROOT:-$(cd "$stage/../../.." && pwd)}
  overlay="$base"
fi
work=${BODY_WARNING_WORK:-${TMPDIR:-/tmp}/blind-body-warning-verification}
if ! command -v swift >/dev/null; then
  if [[ -f /workspace/shared/swift-toolchain/env.sh ]]; then source /workspace/shared/swift-toolchain/env.sh
  else echo "A supported Swift toolchain is required." >&2; exit 1; fi
fi
export BODY_PROFILE_STAGE="$overlay"
mkdir -p "$work/Sources/BlindCore" "$work/Sources/NativeBodyProfile" "$work/Tests/BlindCoreTests" "$work/Tests/NativeBodyProfileTests"
python3 - "$base" "$stage" "$work" "$overlay" <<'PY'
from pathlib import Path
import sys,json,hashlib
base,stage,work,overlay=map(Path,sys.argv[1:])
names=['BodyProfile','Geometry','IndoorMap','KeepOutZone','NativeObservation','NavigationSurface','PlacePackage','RecordedRouteHistory','RoomLayout','SavedWorldFrame','SpatialFrameRegistry','SpatialLocalizationLease','SpatialMapInstallation','SpatialRouteOwner','StoredTerrainAssessment','HazardDetector','MonitoringRecovery','GuidanceText','AlertPolicy','BodyCollisionWarning']
manifest={}
for name in names:
 rel=Path('BlindCore/Sources/BlindCore')/(name+'.swift'); p=overlay/rel
 if not p.exists(): p=base/rel
 data=p.read_bytes(); (work/'Sources/BlindCore'/p.name).write_bytes(data);manifest[str(p)]=hashlib.sha256(data).hexdigest()
for name in ['BodyProfileStore','SpatialMapIO']:
 rel=Path('ios/BlindAssist')/(name+'.swift');p=overlay/rel
 if not p.exists():p=base/rel
 data=p.read_bytes();(work/'Sources/NativeBodyProfile'/p.name).write_bytes(data);manifest[str(p)]=hashlib.sha256(data).hexdigest()
for p in [overlay/'BlindCore/Tests/BlindCoreTests/BodyCollisionWarningTests.swift',base/'BlindCore/Tests/BlindCoreTests/BodyProfileTests.swift',base/'BlindCore/Tests/BlindCoreTests/SpatialIntegrationFixture.swift']:
 data=p.read_bytes();(work/'Tests/BlindCoreTests'/p.name).write_bytes(data);manifest[str(p)]=hashlib.sha256(data).hexdigest()
p=base/'BlindCore/Tests/BlindCoreTests/BlindCoreTests.swift';t=p.read_text(); detector=t[:t.index('final class ProtocolTests:')];(work/'Tests/BlindCoreTests/ExactDetectorTests.swift').write_text(detector);manifest[str(p)+'#exact-leading-DetectorTests']=hashlib.sha256(detector.encode()).hexdigest()
for p in (stage/'verification/Tests').glob('*.swift'):
 data=p.read_bytes();(work/'Tests/NativeBodyProfileTests'/p.name).write_bytes(data);manifest[str(p)]=hashlib.sha256(data).hexdigest()
(stage/'verification/compiled-inputs.json').write_text(json.dumps(manifest,indent=2)+'\n')
PY
cat > "$work/Package.swift" <<'PACKAGE'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "BodyWarningVerification", platforms: [.macOS(.v13)], targets: [
.target(name: "BlindCore"),
.target(name: "NativeBodyProfile", dependencies: ["BlindCore"]),
.testTarget(name: "BlindCoreTests", dependencies: ["BlindCore"]),
.testTarget(name: "NativeBodyProfileTests", dependencies: ["BlindCore", "NativeBodyProfile"])])
PACKAGE
swift test --package-path "$work" --scratch-path "$work/.build" --jobs 2
swiftc -frontend -parse "$overlay/ios/BlindAssist/BodyProfileStore.swift" "$overlay/ios/BlindAssist/BodyProfileSettingsView.swift" "$overlay/ios/BlindAssist/DepthSampler.swift" "$overlay/ios/BlindAssist/NavigationModel.swift" "$overlay/ios/BlindAssist/Feedback.swift" "$overlay/ios/BlindAssist/DashboardView.swift"
