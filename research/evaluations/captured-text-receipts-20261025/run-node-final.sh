#!/usr/bin/env bash
# Public redacted reproduction template. Original internal tool/dependency/data locations omitted.
# Supply the approved local paths via the required environment variables below.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OWN="$(dirname "$ROOT")"
export HOME="$OWN/home" TMPDIR="$OWN/tmp" XDG_CACHE_HOME="$OWN/cache"
export CLANG_MODULE_CACHE_PATH="$OWN/cache/clang" SWIFT_MODULECACHE_PATH="$OWN/cache/swift" SWIFTPM_MODULECACHE_OVERRIDE="$OWN/cache/swift"
: "${BLIND_SWIFTC:?Supply the approved local path before running this template}"
: "${BLIND_GRDB_PATH:?Supply the approved local path before running this template}"
: "${SQLITE_TEST_SDK:?Supply the approved local path before running this template}"
export BLIND_REGISTRATION_REPLAY_SCRATCH="$ROOT/replay" BLIND_TEST_SCRATCH="$ROOT/test-scratch"
: "${BLIND_RECORDED_TRAJECTORY:?Supply the approved local path before running this template}"
mkdir -p "$HOME" "$TMPDIR" "$XDG_CACHE_HOME" "$SWIFT_MODULECACHE_PATH" "$CLANG_MODULE_CACHE_PATH" "$BLIND_TEST_SCRATCH"
cd "$ROOT/validation"
python - "$ROOT/evidence/node-final-source-before.json" <<'PYHASH'
from pathlib import Path
import hashlib,json,sys
files={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in Path('.').rglob('*') if p.is_file() and '.build' not in p.parts}
Path(sys.argv[1]).write_text(json.dumps(files,sort_keys=True,indent=2)+'\n')
PYHASH
node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs > "$ROOT/evidence/node-aggregate.log" 2>&1
python - "$ROOT/evidence/node-final-source-before.json" <<'PYHASH'
from pathlib import Path
import hashlib,json,sys
before=json.loads(Path(sys.argv[1]).read_text())
changed=[p for p,h in before.items() if not Path(p).is_file() or hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
assert not changed,changed
print(f"Verified {len(before)} source/evidence file hashes unchanged across aggregate")
PYHASH
