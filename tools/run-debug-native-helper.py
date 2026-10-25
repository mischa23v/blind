#!/usr/bin/env python3
"""Execute the actual extracted Foundation-only native trace against prebuilt Core.
No Apple APIs are mocked or executed. Does not build Core or install a toolchain.
Usage: python3 tools/run-debug-native-helper.py --products /path/to/debug/products
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--products', required=True, type=Path,
                    help='Existing Debug product directory containing BlindCore.swiftmodule and libBlindCore.a')
parser.add_argument('--swiftc', default='swiftc')
parser.add_argument('--output', type=Path, help='Preserve bounded harness files/results here; otherwise use a temporary directory')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
source_path = root / 'ios/BlindAssist/LocalImageAssistant.swift'
harness_path = root / 'tools/test/DebugNativeSessionTraceHarness.swift'
products = args.products.resolve()
library = products / 'libBlindCore.a'
if not library.is_file() or not (products / 'BlindCore.swiftmodule').exists():
    parser.error('products must contain the actual prebuilt Debug BlindCore module and static library')
compiler = shutil.which(args.swiftc)
if compiler is None:
    parser.error('swiftc was not found; provide an already available official toolchain')
source = source_path.read_text()
marker = '#if DEBUG\n/// Captured diagnostic ownership'
if source.count(marker) != 1:
    parser.error('actual native trace extraction marker is missing or ambiguous')
extracted = 'import Foundation\n@testable import BlindCore\n\n' + source[source.index(marker):]
if not extracted.rstrip().endswith('#endif'):
    parser.error('actual native trace extraction did not end at its DEBUG guard')

def run(output):
    output.mkdir(parents=True, exist_ok=True)
    extracted_path = output / 'ExtractedDebugNativeSessionTrace.swift'
    extracted_path.write_text(extracted)
    executable = output / 'debug-native-helper-harness'
    command = [compiler, '-D', 'DEBUG', '-module-cache-path', str(output / 'module-cache'),
               '-I', str(products), '-L', str(products), '-lBlindCore',
               str(extracted_path), str(harness_path), '-o', str(executable)]
    library_hash = hashlib.sha256(library.read_bytes()).hexdigest()
    subprocess.run(command, check=True)
    result = subprocess.run([str(executable)], capture_output=True, text=True)
    (output / 'result.txt').write_text(result.stdout)
    (output / 'developer-stderr.txt').write_text(result.stderr)
    manifest = {
        'scope': 'Actual extracted Foundation helper + actual Core; no Apple model/audio/UIKit callbacks',
        'native_source_sha256': hashlib.sha256(source.encode()).hexdigest(),
        'extracted_helper_sha256': hashlib.sha256(extracted.encode()).hexdigest(),
        'harness_sha256': hashlib.sha256(harness_path.read_bytes()).hexdigest(),
        'prebuilt_core_sha256': library_hash,
        'core_library_unchanged_during_run': hashlib.sha256(library.read_bytes()).hexdigest() == library_hash,
        'swift_version': subprocess.check_output([compiler, '--version'], text=True).strip(),
        'exit_code': result.returncode,
    }
    (output / 'evidence.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(result.stdout, end='')
    if result.stderr:
        print('Fixed developer stderr receipt captured; no child-visible UI was used.')
    if not manifest['core_library_unchanged_during_run']:
        raise SystemExit('Core product changed during the helper run; rerun against a stable product.')
    raise SystemExit(result.returncode)

if args.output:
    run(args.output.resolve())
else:
    with tempfile.TemporaryDirectory(prefix='blind-debug-native-helper-') as directory:
        run(Path(directory))
