#!/usr/bin/env bash
# Prepared launcher, NOT executed by preparer. Root review/admission required.
set -euo pipefail
if [[ $# -ne 6 ]]; then
  echo 'usage: run_bounded.sh REVIEWED_PYTHON DEPTH_DIR POSES_JSON DIAGNOSTIC_DIR LIBRARY FRESH_OUTPUT_DIR' >&2
  exit 2
fi
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export COFFEE_SHARED_OUTER_GUARD=180
# TERM at 178 seconds, mandatory process-group KILL two seconds later.
exec timeout --signal=TERM --kill-after=2s 178s "$1" -I -B "$script_dir/shared_pose.py" \
  --depth-dir "$2" --transformations "$3" --diagnostic-dir "$4" \
  --native-library "$5" --output "$6" --run-shared-map
