# Exact native-v2 physical-iPhone handoff — prepared, not executed

## Preconditions / scope

Use an authorized Mac with Xcode 27 and an authorized physical iPhone compatible with its installed SDK. Use only synthetic fixtures; no live capture, real enrollment/profile files, or production application container. Provisioning, Apple-team use and physical-device access must already be authorized. This packet does not grant permission to create certificates/profiles, enable device settings, sign into accounts or use someone else's device.

Use a separate checkout of exact commit `50d503f03b126c8b6e1533b794dee54c8e35f920`; do not reset an active checkout. The test host has a distinct `org.blindassist.voiceprobe.host` identity and its own test container. If that identifier/team cannot be provisioned, stop and configure authorized unique host/test identifiers only in the disposable generated project through Xcode. Do not change the real Blind Assist project, record location or security guard.

## Prepare and typecheck (Mac terminal)

```sh
# Run in the separately selected exact checkout.
test "$(git rev-parse HEAD)" = 50d503f03b126c8b6e1533b794dee54c8e35f920
export DEVELOPER_DIR=/Applications/Xcode_27.0.app/Contents/Developer
CHECKPOINT="$PWD/reconstruction/checkpoints/2026-10-25-voice-deletion-reviewed"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/voice-native-v2-device.XXXXXX")"
bash "$CHECKPOINT/apple/typecheck.sh"
node --test "$CHECKPOINT/apple/test-probe.mjs"
node "$CHECKPOINT/apple/generate-project.mjs" "$SCRATCH/project"
```

Generator verifies exact native-v2 source pins. It creates a blank SwiftUI host and test-only projection; the three XCTest methods are included only in the probe bundle with `VOICE_ENROLLMENT_TESTING`. The actor's default application directory is unchanged; the probe-only initializer requires a temporary path inside the test host container.

## Authorized device execution

Select the connected physical iPhone in Xcode, ensure it is unlocked and already configured for authorized development. Obtain its actual destination ID via `xcodebuild -project "$SCRATCH/project/VoiceProbe.xcodeproj" -scheme VoiceProbe -showdestinations`; do not guess IDs. Set the pre-authorized team and physical device ID below. Existing signing/provisioning must support the probe host and test bundle. No `-allowProvisioningUpdates` flag is supplied; missing signing setup is a blocker, not authorization for account changes.

```sh
export TEAM_ID='REPLACE_WITH_AUTHORIZED_TEAM'
export IPHONE_UDID='REPLACE_WITH_SELECTED_PHYSICAL_IPHONE_ID'
set -o pipefail
xcodebuild -project "$SCRATCH/project/VoiceProbe.xcodeproj" -scheme VoiceProbe \
  -configuration Debug -jobs 2 -derivedDataPath "$SCRATCH/DerivedData" \
  -destination "platform=iOS,id=$IPHONE_UDID" -destination-timeout 120 \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:VoiceProbeTests -resultBundlePath "$SCRATCH/DeviceTests.xcresult" \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM_ID" \
  test > "$SCRATCH/device-test.log" 2>&1
xcrun xcresulttool get test-results summary --path "$SCRATCH/DeviceTests.xcresult" \
  > "$SCRATCH/device-summary.json"
python3 - "$SCRATCH/device-summary.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
counts = tuple(s.get(k) for k in ('totalTestCount','passedTests','failedTests','skippedTests'))
print('Device probe counts (total, passed, failed, skipped):', counts)
if counts != (3, 3, 0, 0):
    raise SystemExit('Native-v2 probe acceptance not met')
PY
```

Stop on a failed command; do not call compilation, a skipped test or missing-protection error success. Retain exact commit/hash, Xcode/iOS/device versions, exit status, test counts and the `VOICE_PROBE_SECURITY` boolean/type lines locally. Do not upload raw device logs, identifiers, screenshots or app data. Share only reviewed minimal result metadata.

## What a pass would and would not establish

Exactly three passes establish this synthetic representation test plus save/load/recreate/delete/failure-injection scenario run on that device. They do **not** establish lock/unlock enforcement, persistence after actual process death/power loss, full-disk resilience, cloud-backup exclusion behavior, RAM cleanup, host ownership or UI retry integration. Those require a separately designed authorized controlled device protocol before app activation. No speaker matching, authentication, physical guidance, child trial or production readiness is established.

After evidence has been retained, remove only the uniquely created scratch directory and probe app/container when authorized. Never remove production Blind Assist, its private data, or another test's simulator/device contents. No cleanup command here runs automatically.
