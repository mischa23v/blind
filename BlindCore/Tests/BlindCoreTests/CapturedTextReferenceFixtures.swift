import Foundation
@testable import BlindCore

// Plain test data builder: never instantiate XCTestCase to share fixtures.
struct CapturedTextReferenceFixtures {
    let epoch = UUID(), request = UUID()
    func selection(_ value: inout CapturedTextReference, now: Double = 100) -> CapturedTextReference.Selection {
        value.select(cameraEpoch: epoch, generation: 3, requestID: request,
            issuedAt: 100, capturedAt: 100, orientation: 6, now: now)!
    }
    func source(_ selected: CapturedTextReference.Selection, text: String = "Do not enter. Warning: keep away from the machinery.", media: CompanionReferenceIdentity.Media = .capturedText) -> CompanionReferenceSource {
        let identity = CompanionReferenceIdentity(sourceID: selected.id, revision: UUID(), sha256: String(repeating: "a", count: 64), media: media)
        let evidence = CompanionEvidence(id: "line", kind: .historicalMemory, text: text, source: identity.evidenceSource)
        return .init(identity: identity, toolResult: .init(status: .success, source: identity.evidenceSource, evidence: [evidence]),
            blocks: [.init(evidence: evidence, bodyUTF16Range: NSRange(location: 0, length: text.utf16.count), locator: "line-1")])
    }
    func context(_ value: CapturedTextReference, now: Double = 100.1, epoch other: UUID? = nil, request otherRequest: UUID? = nil, generation: UInt64 = 3,
                 foreground: Bool = true, quiet: Bool = false, hazard: Bool = false, privateAudio: Bool = false) -> CapturedTextReference.Context {
        .init(selection: value.selection!, source: value.source?.identity, cameraEpoch: other ?? epoch, generation: generation,
            requestID: otherRequest ?? request, now: now, foreground: foreground, quiet: quiet, hazard: hazard, privateAudioHeld: privateAudio)
    }
}
