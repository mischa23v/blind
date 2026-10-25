"""Production extension projection; NOT native PDFKit, UIKit or audio execution."""
from pathlib import Path
import sys

root, output = map(Path, sys.argv[1:3])
source = (root / 'ios/BlindAssist/NavigationModel.swift').read_text()
marker = '// MARK: - Explicit, local selected-PDF page quotation (no camera/appliance authority).'
extension = source[source.index(marker):]
assert extension.count('extension NavigationModel {') == 1
# Visibility-only substitution lets a same-file harness inspect private ownership.
extension = extension.replace('private func ', 'fileprivate func ').replace('private var ', 'fileprivate var ')
redaction = next(line.strip() for line in source.splitlines() if 'let privateReference = speechID.map' in line)
fixtures = root / 'tools/test/fixtures/selected-document'
header = (fixtures / 'Projection.swift').read_text().replace('/* PRODUCTION_PRIVATE_REFERENCE */', redaction)
start = source.index('if self.selectedDocumentSpeechIDs.contains(id) {', source.index('feedback.onRequestedSpeechStarted ='))
end = source.index('            guard let context = self.capturedTextContext()', start)
header = header.replace('/* PRODUCTION_DOCUMENT_STARTED */', source[start:end])
tests = (fixtures / 'ProjectionTests.swift').read_text()
core = root / 'BlindCore/Sources/BlindCore'
evidence = (core / 'CompanionEvidence.swift').read_text()
evidence = evidence[:evidence.index('/// A read of the device')]
start = evidence.index('    /// Attributed RGB snapshot')
end = evidence.index('    public func isCurrent', start)
evidence = evidence[:start] + evidence[end:]
parts = [evidence]
for name in ['CompanionReferenceReading.swift',
             'SelectedDocumentReference.swift', 'NarrationDelivery.swift',
             'SpeechPriority.swift', 'SpeechDeliveryLedger.swift', 'CommandAuthority.swift',
             'SpatialClaimGuard.swift']:
    parts.append((core / name).read_text())
output.write_text('\n'.join(parts) + '\n' + header + '\n' + extension + '\n' + tests)
