#!/usr/bin/env bash
set -euo pipefail
SOURCE=${1:?source}; OUT=${2:?output}; HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT/package/Sources/FrontierRunner" "$OUT/home" "$OUT/tmp" "$OUT/cache" "$OUT/config"
cp -a "$SOURCE/BlindCore/Sources/BlindCore" "$OUT/package/Sources/"
cp "$HERE/public/main.swift" "$OUT/package/Sources/FrontierRunner/main.swift"
cp "$HERE/public/episodes.json" "$OUT/episodes.json"
cat > "$OUT/package/Package.swift" <<'PACKAGE'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(name:"FrontierHarness",products:[.executable(name:"FrontierRunner",targets:["FrontierRunner"])],targets:[.target(name:"BlindCore",resources:[.copy("Resources/guide-prompt.txt")]),.executableTarget(name:"FrontierRunner",dependencies:["BlindCore"])])
PACKAGE
(cd "$OUT/package" && find Sources -type f -print0 | sort -z | xargs -0 sha256sum) > "$OUT/source-sha256.txt"
if [[ -n "${SWIFT_ENV:-}" ]]; then source "$SWIFT_ENV"; fi
command -v swift >/dev/null || { echo "Swift toolchain required on PATH" >&2; exit 2; }
export TMPDIR="${TMPDIR:-$OUT/tmp}" HOME="$OUT/home" XDG_CACHE_HOME="$OUT/cache" CLANG_MODULE_CACHE_PATH="$OUT/cache/clang"
swift build --package-path "$OUT/package" --jobs 2 --product FrontierRunner --cache-path "$OUT/cache/swift" --config-path "$OUT/config" > "$OUT/build.log" 2>&1
