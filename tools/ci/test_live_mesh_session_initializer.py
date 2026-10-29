#!/usr/bin/env python3
"""Exact iOS-only producer/dependency API source contract; not a Swift compile.

The macOS package fixtures exclude LiveMeshBenchSession.swift. This regression
must therefore check the actual iOS call against the actual declared initializer,
not infer iOS compatibility from the package's native aggregate.
"""
from pathlib import Path
import argparse
import re
import unittest


def validate_source_contract(declaration: str, producer: str) -> None:
    declared = re.findall(
        r'public\s+init\(\s*(\w+)\s*:\s*MeshDeliveryRecoveryPolicy\s*=\s*\.legacyStickyGap\b',
        declaration,
    )
    called = re.findall(
        r'\bingress\s*=\s*try\s+LiveMeshBenchIngress\(\s*(\w+)\s*:\s*\.latestValidatedAnchorRevision\s*\)',
        producer,
    )
    if declared != ['deliveryRecoveryPolicy']:
        raise ValueError('Expected one declared deliveryRecoveryPolicy initializer with legacy default')
    if called != declared:
        raise ValueError('iOS producer must use exactly the declared deliveryRecoveryPolicy label and reviewed opt-in')


ROOT = Path(__file__).resolve().parents[2]


class LiveMeshSessionInitializerContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = ROOT / 'research/live-mesh-classified-bench-20261028/Sources'
        cls.declaration = (source / 'LiveMeshBenchIngress.swift').read_text()
        cls.producer = (source / 'LiveMeshBenchSession.swift').read_text()

    def test_current_ios_producer_uses_declared_recovery_label(self):
        validate_source_contract(self.declaration, self.producer)

    def test_old_wrong_call_label_is_rejected(self):
        old = self.producer.replace('LiveMeshBenchIngress(deliveryRecoveryPolicy:',
                                    'LiveMeshBenchIngress(recoveryPolicy:')
        self.assertNotEqual(old, self.producer)
        with self.assertRaises(ValueError):
            validate_source_contract(self.declaration, old)

    def test_declaration_label_drift_is_rejected(self):
        changed = self.declaration.replace('init(deliveryRecoveryPolicy:', 'init(recoveryPolicy:')
        self.assertNotEqual(changed, self.declaration)
        with self.assertRaises(ValueError):
            validate_source_contract(changed, self.producer)

    def test_legacy_policy_is_not_accidentally_selected(self):
        changed = self.producer.replace('.latestValidatedAnchorRevision)', '.legacyStickyGap)')
        self.assertNotEqual(changed, self.producer)
        with self.assertRaises(ValueError):
            validate_source_contract(self.declaration, changed)

    def test_duplicate_call_is_not_silently_accepted(self):
        changed = self.producer + '\ningress = try LiveMeshBenchIngress(deliveryRecoveryPolicy: .latestValidatedAnchorRevision)\n'
        with self.assertRaises(ValueError):
            validate_source_contract(self.declaration, changed)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    ROOT = args.root.resolve()
    unittest.main(argv=[__file__], verbosity=2)
