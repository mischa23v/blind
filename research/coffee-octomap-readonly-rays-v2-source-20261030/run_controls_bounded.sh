#!/usr/bin/env bash
# Source-only prepared launcher. Explicit root source/build/control admission required.
set -euo pipefail
if [[ $# -ne 6 ]]; then
  echo 'usage: run_controls_bounded.sh REVIEWED_PYTHON LIBRARY EXPECTED_LIBRARY_SHA BUILD_RECEIPT EXPECTED_RECEIPT_SHA FRESH_OUTPUT_DIR' >&2
  exit 2
fi
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export COFFEE_RAY_OUTER_GUARD=180
exec timeout --signal=TERM --kill-after=2s 178s "$1" -I -B "$here/run_controls.py" \
  --library "$2" --expected-library-sha256 "$3" --build-receipt "$4" \
  --expected-build-receipt-sha256 "$5" --output "$6" --run-native-controls
