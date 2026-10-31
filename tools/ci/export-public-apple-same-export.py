#!/usr/bin/env python3
"""Export ONLY the two original-public Apple diagnostic inputs for comparison.

Separate from the 1 MiB case-status artifact. Never embeds binary/base64 data,
exports a suite, loads private captures, changes a test verdict, or retries a test.
All six attachments must bind to one exact test invocation and its inventory.
"""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import resource
import signal
import stat
import struct
import subprocess
import sys
import tempfile
import time
import zipfile

TEST = 'SavedRoomRouteMeshAppleFixtureTests/testOriginalAppleSameExportForOpenUSDComparison'
INVENTORY = 'APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json'
MANIFEST = 'APPLE_ROOM_ROUTE_SAME_EXPORT_MANIFEST.json'
ASSET_CAP = 4 * 1024 * 1024
METADATA_CAP = 64 * 1024
INVENTORY_CAP = 128 * 1024
MANIFEST_CAP = 16 * 1024
EXPORT_CAP = 9 * 1024 * 1024
EXPORT_SECONDS = 15
ROOMS = ('Hallway2', 'Bedroom3')
FILES = {INVENTORY:INVENTORY_CAP, MANIFEST:MANIFEST_CAP}
for room in ROOMS:
    FILES['APPLE_ROOM_ROUTE_' + room + '_SAME_EXPORT.usdz'] = ASSET_CAP
    FILES['APPLE_ROOM_ROUTE_' + room + '_SAME_EXPORT_METADATA.bin'] = METADATA_CAP


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    value = importlib.util.module_from_spec(spec)
    previous = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(value)
    finally:
        sys.dont_write_bytecode = previous
    return value


routes = module('same_export_routes', 'native-route-diagnostic-evidence.py')
statuses = module('same_export_statuses', 'export-native-unit-statuses.py')
require = routes.require
Error = routes.EvidenceError


def canonical(identifier):
    if not isinstance(identifier, str): return None
    value = identifier.removesuffix('()').removeprefix('BlindAssistTests/')
    return value if value == TEST else None


def read_bounded(path, cap):
    require(not path.is_symlink(), 'unsupported_symlink')
    info = path.stat()
    require(stat.S_ISREG(info.st_mode) and 0 < info.st_size <= cap, 'file_over_budget')
    with path.open('rb') as stream:
        raw = stream.read(cap + 1)
    require(len(raw) == info.st_size and len(raw) <= cap, 'file_size_changed')
    return raw


def observed_case(path, expected):
    require(isinstance(expected, str) and re.fullmatch(r'[0-9a-f]{40}', expected), 'unverified_source_commit')
    report = routes.decode(read_bounded(path, 1024 * 1024))
    require(isinstance(report, dict) and report.get('complete') is True and report.get('source_verified') is True and
            report.get('aggregate_counts_match') is True and report.get('expected_commit') == expected and
            report.get('source_commit') == expected, 'unverified_case_evidence')
    cases = report.get('cases')
    require(isinstance(cases, list) and 0 < len(cases) <= 10000 and
            type(report.get('case_count')) is int and report['case_count'] == len(cases), 'invalid_case_evidence')
    for case in cases:
        routes.keys(case, {'identifier','result'}, {'identifier','result'})
        require(isinstance(case['identifier'], str) and 0 < len(case['identifier']) <= 512 and
                isinstance(case['result'], str) and case['result'] in statuses.STATUSES, 'invalid_case_evidence')
    counts = report.get('counts')
    require(isinstance(counts, dict) and set(counts) == statuses.STATUSES and all(
            type(counts[status]) is int and counts[status] == sum(case['result'] == status for case in cases)
            for status in statuses.STATUSES), 'case_counts_disagree')
    found = [case for case in cases if canonical(case['identifier']) == TEST]
    require(len(found) == 1, 'test_not_observed' if not found else 'duplicate_test_case')
    require(found[0]['result'] != 'Skipped', 'test_skipped')
    return found[0]


def export_size(directory):
    require(not directory.is_symlink(), 'unsupported_export_entry')
    if not directory.exists(): return
    total = count = 0
    with os.scandir(directory) as entries:
        for entry in entries:
            count += 1
            info = entry.stat(follow_symlinks=False)
            require(count <= 8 and stat.S_ISREG(info.st_mode), 'unsupported_export_entry')
            total += info.st_size
            require(info.st_size <= ASSET_CAP and total <= EXPORT_CAP, 'export_over_budget')


def export_test(bundle, identifier, directory):
    require(canonical(identifier) == TEST, 'unapproved_test_identifier')
    def file_limit(): resource.setrlimit(resource.RLIMIT_FSIZE, (ASSET_CAP, ASSET_CAP))
    process = subprocess.Popen(['xcrun','xcresulttool','export','attachments','--path',str(bundle),
        '--test-id',identifier,'--output-path',str(directory)], stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL, start_new_session=True, preexec_fn=file_limit)
    try:
        deadline = time.monotonic() + EXPORT_SECONDS
        while process.poll() is None:
            export_size(directory)
            require(time.monotonic() < deadline, 'attachment_export_timeout')
            time.sleep(.05)
        export_size(directory)
        require(process.returncode == 0, 'attachment_export_failed')
    finally:
        try: os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError: pass
        process.wait()


def attachment_name(suggested):
    if not isinstance(suggested, str): return None
    for name in FILES:
        if suggested == name: return name
        stem, extension = name.rsplit('.', 1)
        suffix = r'(?:_[0-9]+_[A-Za-z0-9-]{1,100})?'
        # Public.data may acquire a generic data extension from xcresulttool.
        endings = 'json' if extension == 'json' else '(?:' + extension + '|bin|data)'
        pattern = re.escape(stem) + r'(?:\.' + extension + r')?' + suffix + r'\.' + endings
        if re.fullmatch(pattern, suggested): return name
    return None


def attachments(directory):
    export_size(directory)
    manifest = routes.decode(read_bounded(directory / 'manifest.json', 64 * 1024))
    require(isinstance(manifest, list) and len(manifest) == 1 and isinstance(manifest[0], dict), 'unsupported_export_manifest')
    entries = manifest[0].get('attachments')
    require(isinstance(entries, list) and len(entries) == len(FILES), 'attachment_count_mismatch')
    selected = {}
    filenames = set()
    for entry in entries:
        require(isinstance(entry, dict), 'unsupported_attachment_schema')
        name = attachment_name(entry.get('suggestedHumanReadableName'))
        require(name is not None, 'unexpected_test_attachment')
        require(name not in selected, 'duplicate_attachment')
        expected_type = 'public.json' if name.endswith('.json') else 'public.data'
        if 'uniformTypeIdentifier' in entry:
            require(entry['uniformTypeIdentifier'] == expected_type, 'unsupported_attachment_type')
        filename = entry.get('exportedFileName')
        require(isinstance(filename, str) and re.fullmatch(r'[A-Za-z0-9_. -]{1,512}', filename) and
                filename not in ('.','..') and filename not in filenames, 'invalid_attachment_filename')
        path = directory / filename
        require(path.resolve().parent == directory.resolve(), 'attachment_path_escape')
        raw = read_bounded(path, FILES[name])
        if 'payloadSize' in entry:
            require(type(entry['payloadSize']) is int and entry['payloadSize'] == len(raw), 'attachment_size_mismatch')
        selected[name] = raw
        filenames.add(filename)
    require(set(selected) == set(FILES), 'missing_attachment')
    require({entry.name for entry in directory.iterdir()} == filenames | {'manifest.json'}, 'unexpected_export_file')
    return selected


def validate_usdz(raw):
    """Inspect bounded ZIP structure/magic only, without extracting or resolving USD."""
    require(0 < len(raw) <= ASSET_CAP and raw.startswith(b'PK\x03\x04'), 'invalid_usdz_archive')
    end = raw.rfind(b'PK\x05\x06', max(0, len(raw) - 65557))
    require(end >= 0 and end + 22 <= len(raw), 'invalid_usdz_archive')
    _, disk, start_disk, disk_count, count, size, offset, comment = struct.unpack_from('<4s4H2IH', raw, end)
    require(disk == start_disk == 0 and disk_count == count and 1 <= count <= 64 and
            size <= 65536 and offset + size == end and comment == 0 and end + 22 == len(raw), 'unsupported_usdz_directory')
    total = files = 0
    seen = set()
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        require(len(archive.infolist()) == count, 'invalid_usdz_archive')
        for item in archive.infolist():
            name = item.filename.removesuffix('/')
            path = PurePosixPath(name)
            require(0 < len(name) <= 256 and re.fullmatch(r'[A-Za-z0-9_. /-]+', name) and
                    not path.is_absolute() and all(part not in ('.','..') for part in name.split('/')) and
                    name not in seen, 'unsupported_usdz_member')
            seen.add(name)
            mode = stat.S_IFMT(item.external_attr >> 16)
            require(mode in (0, stat.S_IFREG, stat.S_IFDIR) and not (item.flag_bits & 1) and
                    item.compress_type == zipfile.ZIP_STORED and item.file_size == item.compress_size and
                    not item.comment, 'unsupported_usdz_member')
            total += item.file_size
            require(total <= ASSET_CAP, 'usdz_members_over_budget')
            if item.is_dir():
                require(item.file_size == 0, 'unsupported_usdz_member')
                continue
            require(path.suffix.lower() in ('.usd','.usda','.usdc'), 'non_geometry_usdz_member')
            files += 1
            with archive.open(item) as stream:
                magic = stream.read(16)
                require(magic.startswith(b'PXR-USDC') or magic.startswith(b'#usda '), 'unsupported_usd_encoding')
                while stream.read(65536): pass # Complete CRC check; stored bytes and total are bounded.
    require(files > 0, 'missing_usd_layer')
    return {'geometryLayerCount':files,'archiveEntryCount':count,'uncompressedBytes':total}


def validate_metadata(raw, record, inventory, known):
    if record['metadataFormat'] == 'binaryPlist':
        require(raw.startswith(b'bplist00'), 'metadata_format_mismatch')
        values = plistlib.loads(raw)
    else:
        require(record['metadataFormat'] == 'json' and raw.lstrip().startswith(b'{'), 'metadata_format_mismatch')
        values = routes.decode(raw)
    require(isinstance(values, dict) and 0 < len(values) <= 4096, 'unsupported_public_metadata')
    indexed = {}
    for key, value in values.items():
        require(isinstance(key, str) and 0 < len(key.encode()) <= 512 and '\x00' not in key and
                isinstance(value, str) and value.upper() in known, 'unknown_public_metadata_identity')
        indexed[hashlib.sha256(key.encode()).hexdigest()] = (key, value.upper())
    require(inventory['metadataEntryCount'] == len(values) and inventory['metadataByteCount'] == len(raw) and
            inventory['metadataFormat'] == record['metadataFormat'], 'inventory_metadata_mismatch')
    for entry in inventory['metadataEntries']:
        require(entry['keySHA256'] in indexed, 'inventory_metadata_mismatch')
        key, value = indexed[entry['keySHA256']]
        safe = key if re.fullmatch(r'[A-Za-z0-9_. -]{1,128}', key) else '<redacted>'
        require(entry['key'] == safe and entry['valueKind'] == 'string' and entry['uuidValue'] is True and
                entry['knownFeature'] is True and entry.get('uuid') == value, 'inventory_metadata_mismatch')


def validate_payloads(payloads, docs, uuids):
    require(isinstance(payloads, dict) and set(payloads) == set(FILES) and all(
            isinstance(payloads[name], bytes) and 0 < len(payloads[name]) <= cap for name, cap in FILES.items()), 'payload_set_or_budget_mismatch')
    manifest = routes.decode(payloads[MANIFEST])
    required = {'schema','physicalAuthority','exportRole','productionAdapterExport','testIdentifier',
                'inventoryAttachmentName','inventorySHA256','fixtures'}
    routes.keys(manifest, required, required)
    require(manifest['schema'] == 'blind.saved-room-route-same-export.v1' and manifest['physicalAuthority'] is False and
            manifest['exportRole'] == 'diagnostic-export' and manifest['productionAdapterExport'] == 'separate-unretained' and
            manifest['testIdentifier'] == TEST and manifest['inventoryAttachmentName'] == INVENTORY,
            'unsupported_same_export_manifest')
    require(manifest['inventorySHA256'] == hashlib.sha256(payloads[INVENTORY]).hexdigest(), 'inventory_hash_mismatch')
    inventory = routes.validate_metadata_inventory(routes.decode(payloads[INVENTORY]), uuids, docs)
    records = manifest['fixtures']
    require(isinstance(records, list) and len(records) == 2, 'fixture_count_mismatch')
    seen = set()
    summaries = []
    fields = {'fixtureID','sourceSHA256','assetAttachmentName','metadataAttachmentName','assetSHA256',
              'metadataSHA256','metadataFormat','assetByteCount','metadataByteCount'}
    for record in records:
        routes.keys(record, fields, fields)
        room = record['fixtureID']
        require(isinstance(room, str) and room in ROOMS and room not in seen, 'unknown_or_duplicate_fixture')
        seen.add(room)
        require(record['sourceSHA256'] == routes.FIXTURES[room], 'source_hash_mismatch')
        expected_asset = 'APPLE_ROOM_ROUTE_' + room + '_SAME_EXPORT.usdz'
        expected_metadata = 'APPLE_ROOM_ROUTE_' + room + '_SAME_EXPORT_METADATA.bin'
        require(record['assetAttachmentName'] == expected_asset and record['metadataAttachmentName'] == expected_metadata,
                'unexpected_payload_name')
        for kind, name in (('asset',expected_asset),('metadata',expected_metadata)):
            require(type(record[kind+'ByteCount']) is int and record[kind+'ByteCount'] == len(payloads[name]) and
                    0 < len(payloads[name]) <= FILES[name] and
                    record[kind+'SHA256'] == hashlib.sha256(payloads[name]).hexdigest(), 'payload_hash_or_size_mismatch')
        fixture_inventory = next(row for row in inventory['fixtures'] if row['fixtureID'] == room)
        validate_metadata(payloads[expected_metadata], record, fixture_inventory, uuids[room])
        summaries.append({'fixtureID':room,'sourceSHA256':record['sourceSHA256'],
                          'archive':validate_usdz(payloads[expected_asset])})
    return summaries


def main():
    bundle, case_path, output = map(Path, sys.argv[1:4])
    receipt = {'schema':'blind.public-apple-same-export-receipt.v1','status':'not_collected',
        'physicalAuthority':False,'testIdentifier':TEST,'exportRole':'diagnostic-export',
        'productionAdapterExport':'separate-unretained','files':[],
        'limits':{'assetBytesEach':ASSET_CAP,'metadataBytesEach':METADATA_CAP,'inventoryBytes':INVENTORY_CAP,
                  'manifestBytes':MANIFEST_CAP,'temporaryExportBytes':EXPORT_CAP,'exportSeconds':EXPORT_SECONDS}}
    try:
        require(not output.exists() and not output.is_symlink(), 'output_already_exists')
        output.mkdir(mode=0o700, parents=True)
    except (OSError, Error):
        print('PUBLIC_APPLE_SAME_EXPORT=output_unavailable')
        return 1
    try:
        repo = Path(__file__).resolve().parents[2]
        expected = os.environ.get('GITHUB_SHA')
        provenance = statuses.provenance(repo, expected)
        case = observed_case(case_path, expected)
        docs, uuids, hashes = routes.sources(repo)
        receipt.update(sourceCommit=expected,testResult=case['result'],sourceSHA256=hashes)
        with tempfile.TemporaryDirectory(prefix='blind-public-same-export-') as temp:
            directory = Path(temp) / 'attachments'
            export_test(bundle, case['identifier'], directory)
            payloads = attachments(directory)
        summaries = validate_payloads(payloads, docs, uuids)
        require(statuses.provenance(repo, expected) == provenance, 'source_changed_during_export')
        require(routes.sources(repo)[2] == hashes, 'source_hashes_changed_during_export')
        receipt['files'] = [{'name':name,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()} for name,raw in payloads.items()]
        receipt.update(status='complete',fixtures=summaries,sourceVerified=True)
        encoded = json.dumps(receipt, indent=2, allow_nan=False) + '\n'
        require(len(encoded.encode()) <= 16384, 'receipt_over_budget')
        # Publish all six exact payloads plus the complete receipt atomically.
        # On any earlier validation/write failure only the error receipt exists.
        with tempfile.TemporaryDirectory(prefix='.blind-public-same-export-', dir=output.parent) as staging:
            staged = Path(staging)
            for name, raw in payloads.items(): (staged / name).write_bytes(raw)
            (staged / 'receipt.json').write_text(encoded)
            os.replace(staged, output)
    except (ValueError, OSError, KeyError, TypeError, RecursionError, OverflowError,
            subprocess.SubprocessError, zipfile.BadZipFile, plistlib.InvalidFileException) as error:
        # Only fixed codes leave the parser. No raw OS, XML, ZIP or subprocess text.
        receipt['status'] = str(error) if isinstance(error, Error) else 'source_export_or_schema_error'
        receipt['sourceVerified'] = False
        receipt['files'] = []
        encoded = json.dumps(receipt, indent=2, allow_nan=False) + '\n'
        require(len(encoded.encode()) <= 16384, 'receipt_over_budget')
        (output / 'receipt.json').write_text(encoded)
    print('PUBLIC_APPLE_SAME_EXPORT=' + receipt['status'])
    return 0 if receipt['status'] == 'complete' else 1


if __name__ == '__main__':
    if len(sys.argv) != 4:
        print('Expected xcresult, verified unit-case JSON and new dedicated output directory.')
        raise SystemExit(2)
    raise SystemExit(main())
