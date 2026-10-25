#!/usr/bin/env bash
# Optional unsigned native compilation only. No photos, enrollment, accuracy test or redistribution.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ASSETS="${FAMILIAR_CI_ASSETS:?Set FAMILIAR_CI_ASSETS to a private disposable runner directory}"
[[ "$ASSETS" = /* && "$ASSETS" != "$ROOT" && "$ASSETS" != "$ROOT/"* ]] || { echo 'Assets must stay outside checkout'; exit 2; }
[[ "$(uname -s)" = Darwin ]] || { echo 'Actual Apple SDK host required'; exit 2; }
mkdir -p "$ASSETS/models" "$ASSETS/notices"
fetch() {
  local url="$1" file="$2" bytes="$3" sha="$4"
  if [[ ! -f "$file" ]]; then
    curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 2 --max-time 240 --max-filesize "$bytes" "$url" -o "$file.part"
    [[ "$(stat -f '%z' "$file.part")" = "$bytes" ]] || { echo 'Artifact size mismatch'; exit 3; }
    echo "$sha  $file.part" | shasum -a 256 -c -
    mv "$file.part" "$file"
  fi
  [[ "$(stat -f '%z' "$file")" = "$bytes" ]] || exit 3
  echo "$sha  $file" | shasum -a 256 -c -
}
fetch 'https://github.com/opencv/opencv/releases/download/4.14.0/opencv-4.14.0-ios-framework.zip' "$ASSETS/opencv.zip" 75208871 f4f428fa9270adf95b3ed4705eb18ba3028ed2c2777a4f1a002739b869986a6a
fetch 'https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx' "$ASSETS/models/face_detection_yunet_2023mar.onnx" 232589 8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4
fetch 'https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx' "$ASSETS/models/face_recognition_sface_2021dec.onnx" 38696353 0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79
# ditto preserves the official framework's relative internal symlinks.
ditto -x -k "$ASSETS/opencv.zip" "$ASSETS/framework"
cp "$ROOT/ios/BlindAssist/FamiliarNative/MODEL_NOTICES.txt" "$ASSETS/notices/MODEL_NOTICES.txt"
cp "$ROOT/tools/ci/familiar-notices/OpenCV-LICENSE.txt" "$ASSETS/notices/OpenCV-LICENSE.txt"
export FAMILIAR_CI_ASSETS="$ASSETS"
node "$ROOT/tools/ci/familiar-device-project.mjs"
xcodebuild -project "$ROOT/ios/BlindAssistFamiliarBench.xcodeproj" -scheme BlindAssist -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$ASSETS/DerivedData" -jobs 2 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= build
# Never upload the app, framework, models or DerivedData as public artifacts.
# Compilation does not validate camera preprocessing, consent UI, identity accuracy or device behavior.
