#!/usr/bin/env bash
# Prepared only. Root must externally verify manifest and reviewed native controls first.
set -euo pipefail
if [[ $# -ne 6 ]]; then
 echo 'usage: run_bounded.sh REVIEWED_PYTHON LIBRARY LIBRARY_SHA CONTROLS_RECEIPT CONTROLS_SHA FRESH_OUTPUT_DIR' >&2
 exit 2
fi
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export COFFEE_FINE_FUSED_OUTER_GUARD=180
exec timeout --signal=TERM --kill-after=2s 178s "$1" -B -I "$here/evaluate.py" --library "$2" --library-sha256 "$3" --controls-receipt "$4" --controls-sha256 "$5" --output "$6" --run-heldout
