#!/usr/bin/env bash
set -euo pipefail
SOURCE=${1:?Usage: run.sh source_root output_root}
OUTPUT=${2:?Output root required}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUTPUT"
export TMPDIR="${TMPDIR:-/workspace/shared/blind-test-tmp}"
mkdir -p "$TMPDIR"
RUN=$(mktemp -d "$TMPDIR/blind-integrated.XXXXXX")
printf '%s\n' "$RUN" > "$OUTPUT/scratch-path.txt"
mkdir -p "$RUN/BlindCore"
cp "$SOURCE/BlindCore/Package.swift" "$RUN/BlindCore/Package.swift"
cp -a "$SOURCE/BlindCore/Sources" "$SOURCE/BlindCore/Tests" "$RUN/BlindCore/"
cp "$HERE/IntegratedAttentionEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
cp "$HERE/IntegratedConversationBoundaryEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
cp "$HERE/IntegratedFamiliarEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
cp "$HERE/IntegratedReferenceEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
cp "$HERE/IntegratedSourcedMapEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
if [ -f "$SOURCE/BlindCore/Sources/BlindCore/CompanionMemoryScope.swift" ]; then cp "$HERE/IntegratedScopedMemoryEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"; fi
cp "$HERE/IntegratedShoppingSessionEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
cp "$HERE/IntegratedSpatialAuthorityEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
cp "$HERE/IntegratedClockControlEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
cp "$HERE/IntegratedMemoryEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
cp "$HERE/IntegratedPhotoEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
cp "$HERE/IntegratedEverydayEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
cp "$HERE/IntegratedFeatureEpisodeTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
cp "$HERE/IntegratedEpisodeReplayTests.swift" "$RUN/BlindCore/Tests/BlindCoreTests/"
python3 "$HERE/project_native.py" "$SOURCE" "$RUN/BlindCore" "$OUTPUT"
python3 - "$SOURCE" "$OUTPUT" "$RUN" <<'PY'
import sys,pathlib,hashlib,json,datetime
source=pathlib.Path(sys.argv[1]); out=pathlib.Path(sys.argv[2]); run=pathlib.Path(sys.argv[3]); rows=[]; mismatch=[]
for folder in ['BlindCore/Sources','BlindCore/Tests','ios/BlindAssist']:
 for f in sorted((source/folder).rglob('*')):
  if f.is_file():
   relative=f.relative_to(source); digest=hashlib.sha256(f.read_bytes()).hexdigest(); row={'path':str(relative),'sha256':digest}
   projected=run/relative
   if projected.is_file():
    row['projection_sha256']=hashlib.sha256(projected.read_bytes()).hexdigest()
    if digest != row['projection_sha256']: mismatch.append(str(relative))
   rows.append(row)
(out/'source-manifest.json').write_text(json.dumps({'source':str(source),'recorded_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files':rows,'copy_mismatches':mismatch},indent=2))
if mismatch: raise SystemExit('Source changed while copied; stop and select a frozen source: '+str(mismatch))
PY
mkdir -p "$RUN"/{home,cache,config,security,clang}
export HOME="$RUN/home" XDG_CACHE_HOME="$RUN/cache" XDG_CONFIG_HOME="$RUN/config"
export CLANG_MODULE_CACHE_PATH="$RUN/clang" SWIFTPM_MODULECACHE_OVERRIDE="$RUN/clang"
export BLIND_EPISODE_OUTPUT="$OUTPUT"
swift --version > "$OUTPUT/swift-version.txt"
set +e
swift test --package-path "$RUN/BlindCore" --scratch-path "$RUN/build" --cache-path "$RUN/cache" --config-path "$RUN/config" --security-path "$RUN/security" --jobs 2 --filter "${3:-IntegratedEpisodeReplayTests|IntegratedFeatureEpisodeTests|IntegratedEverydayEpisodeTests|IntegratedPhotoEpisodeTests|IntegratedMemoryEpisodeTests|IntegratedClockControlEpisodeTests|IntegratedSpatialAuthorityEpisodeTests|IntegratedShoppingSessionEpisodeTests|IntegratedReferenceEpisodeTests|IntegratedFamiliarEpisodeTests|IntegratedConversationBoundaryEpisodeTests|IntegratedAttentionEpisodeTests|IntegratedSourcedMapEpisodeTests|IntegratedScopedMemoryEpisodeTests|ConnectedJourneyRuntimeTests.testIntegrated}" 2>&1 | tee "$OUTPUT/swift-test.log"
STATUS=${PIPESTATUS[0]}
set -e
printf '%s\n' "$STATUS" > "$OUTPUT/exit-code.txt"
exit "$STATUS"
