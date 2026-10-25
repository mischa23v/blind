#!/usr/bin/env bash
# Minimal repeat of the 32-case tranche. Production source is copied unchanged.
set -euo pipefail
SOURCE=${1:?source root}; OUTPUT=${2:?new output directory}; HERE=$(cd "$(dirname "$0")" && pwd)
[ ! -e "$OUTPUT" ] || { echo 'Output exists; choose a new receipt directory.' >&2; exit 2; }
mkdir -p "$OUTPUT"
OUTPUT=$(cd "$OUTPUT" && pwd)
WORK=${BLIND_SCENARIO_WORK_ROOT:-"$OUTPUT/work"}
mkdir -p "$WORK"; RUN=$(mktemp -d "$WORK/scoped-attention.XXXXXX")
mkdir -p "$RUN/package/Sources" "$RUN/package/Tests/BlindCoreTests" "$RUN/home" "$RUN/cache" "$RUN/config" "$RUN/security" "$RUN/clang" "$RUN/tmp"
cp -a "$SOURCE/BlindCore/Sources/BlindCore" "$RUN/package/Sources/"
cp "$HERE/IntegratedScopedMemoryEpisodeTests.swift" "$HERE/IntegratedAttentionEpisodeTests.swift" "$RUN/package/Tests/BlindCoreTests/"
cat > "$RUN/package/Package.swift" <<'PACKAGE'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(name:"BlindCore",products:[.library(name:"BlindCore",targets:["BlindCore"])],targets:[.target(name:"BlindCore",resources:[.copy("Resources/guide-prompt.txt")]),.testTarget(name:"BlindCoreTests",dependencies:["BlindCore"])])
PACKAGE
(cd "$RUN/package"; find Sources Tests -type f -print0 | sort -z | xargs -0 sha256sum) > "$OUTPUT/input-sha256.txt"
printf '%s\n' "$RUN" > "$OUTPUT/scratch-path.txt"
export HOME="$RUN/home" XDG_CACHE_HOME="$RUN/cache" XDG_CONFIG_HOME="$RUN/config" CLANG_MODULE_CACHE_PATH="$RUN/clang" SWIFTPM_MODULECACHE_OVERRIDE="$RUN/clang" TMPDIR="$RUN/tmp" BLIND_EPISODE_OUTPUT="$OUTPUT"
swift --version > "$OUTPUT/swift-version.txt"
set +e
swift test --package-path "$RUN/package" --jobs 2 --cache-path "$RUN/cache" --config-path "$RUN/config" --security-path "$RUN/security" --filter 'IntegratedScopedMemoryEpisodeTests|IntegratedAttentionEpisodeTests' > "$OUTPUT/swift-test.log" 2>&1
S=$?; set -e
printf '%s\n' "$S" > "$OUTPUT/exit-code.txt"
cat "$OUTPUT/swift-test.log"
exit "$S"
