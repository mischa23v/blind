#!/usr/bin/env python3
"""Portable diagnostic-parser controls only; synthetic strings, NOT Swift results."""
import importlib.util
import json
from pathlib import Path

path = Path(__file__).resolve().parent.parent / 'apple/ci.py'
spec = importlib.util.spec_from_file_location('stage86_inert_runner', path)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)  # Import has no build or argument-parsing side effects.


def error(kind, message):
    return '/fixture/' + kind + '-must-not-compile.swift:3:14: error: ' + message + '\n'


named = "'OriginBoundMeshIngress86.ProducerLease' initializer is inaccessible due to 'fileprivate' protection level"
short = "'init' is inaccessible due to 'fileprivate' protection level"
source = 'let forged = OriginBoundMeshIngress86.ProducerLease()\n'
cases = [
    ('named initializer', 'forged-lease', error('forged-lease', named), True),
    ('short initializer with target', 'forged-lease', error('forged-lease', short) + source, True),
    ('short initializer without target', 'forged-lease', error('forged-lease', short), False),
    ('other inaccessible initializer', 'forged-lease', error('forged-lease', named.replace('ProducerLease', 'OtherType')), False),
    ('unrelated module error', 'forged-lease', error('forged-lease', "no such module 'OriginBoundMeshIngress86'") + source, False),
    ('expected error plus unrelated failure', 'forged-lease', error('forged-lease', named) + error('forged-lease', 'unrelated failure'), False),
    ('expected error plus driver failure', 'forged-lease', error('forged-lease', named) + 'error: unexpected driver failure\n', False),
    ('note alone is not an error', 'forged-lease', error('forged-lease', named).replace(': error:', ': note:'), False),
    ('wrong source file', 'forged-lease', error('other-file', named), False),
    ('missing removal lease', 'missing-lease', error('missing-lease', "missing argument for parameter 'lease' in call"), True),
    ('missing ingest lease', 'missing-ingest-lease', error('missing-ingest-lease', "missing argument for parameter 'lease' in call"), True),
    ('wrong missing argument', 'missing-lease', error('missing-lease', "missing argument for parameter 'anchorID' in call"), False),
    ('no getter', 'current-lease', error('current-lease', "value of type 'OriginBoundMeshIngress86' has no member 'currentLease'"), True),
    ('wrong missing member', 'current-lease', error('current-lease', "value of type 'OriginBoundMeshIngress86' has no member 'unrelated'"), False),
    ('toolchain failure', 'forged-lease', "xcrun: error: unable to find utility 'swiftc'\n", False),
    ('empty diagnostic', 'forged-lease', '', False),
]
for label, kind, text, expected in cases:
    assert bool(runner.expected_rejection(kind, text)) == expected, label
print(json.dumps(dict(diagnosticParserChecksPassed=len(cases), syntheticDiagnosticsOnly=True, swiftExecuted=False)))
