#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
# Use an already installed Swift >= 5.9 toolchain; do not install dependencies.
# A distinct external scratch path avoids including builds in source archives.
cache="${PHOTO_TEST_CACHE:-/tmp/blind-photo-tests}"
mkdir -p "$cache"/{home,clang,swiftpm,config,security}
export HOME="$cache/home" CLANG_MODULE_CACHE_PATH="$cache/clang" SWIFTPM_MODULECACHE_OVERRIDE="$cache/clang"
python3 "$root/reconstruction/library-photo/generate-controller-tests.py"
swift test --package-path "$root/BlindCore" --scratch-path "$cache/build" --cache-path "$cache/swiftpm" --config-path "$cache/config" --security-path "$cache/security" --jobs 2
node --test --test-concurrency=1 "$root"/tools/test/{selected-photo-reference,reading-integration,ios-lifecycle-regressions,privacy-rule,speech-delivery-contract,debug-native-session,debug-session-log,spatial-route-output,clock-native-callbacks,clock-inquiry,clock-tool-delivery,command-authority}.test.mjs
swiftc -frontend -parse "$root"/ios/BlindAssist/{NavigationModel,ExplorePictureView,SelectedPhotoDecoder,DashboardView,VisionService,Feedback}.swift
