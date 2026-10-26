import XCTest
import UIKit
import PDFKit
import CryptoKit
@testable import BlindAssist

/// Real native PDF generation and extraction, not injected text blocks. These
/// checks do not establish audible speech, VoiceOver comprehension or visual order.
@MainActor
final class SelectedDocumentPDFTests: XCTestCase {
    func testEnglishActualBytesHashAndWholePageText() throws {
        let bytes = PDFFixtures.pages(["Fixture only. Wash gently. Do not dry with heat."])
        let selected = try SelectedDocumentPDFAdapter.select(bytes: bytes)
        let page = try SelectedDocumentPDFAdapter.readPage(1, from: selected)
        XCTAssertEqual(selected.bytes, bytes)
        XCTAssertEqual(selected.sha256, SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
        XCTAssertEqual(page.sha256, selected.sha256)
        XCTAssertEqual(page.pageNumber, 1)
        XCTAssertEqual(page.text, try XCTUnwrap(PDFDocument(data: bytes)?.page(at: 0)?.string))
        XCTAssertTrue(page.text.contains("Do not dry with heat."))
    }
    func testArabicAndMixedNumeralsUseActualTextLayer() throws {
        let bytes = PDFFixtures.pages(["نص تجريبي فقط. الصفحة ٢. الرقم 123."])
        let selected = try SelectedDocumentPDFAdapter.select(bytes: bytes)
        let page = try SelectedDocumentPDFAdapter.readPage(1, from: selected)
        XCTAssertEqual(page.text, try XCTUnwrap(PDFDocument(data: bytes)?.page(at: 0)?.string))
        XCTAssertTrue(page.text.unicodeScalars.contains { (0x0600...0x06ff).contains($0.value) })
        XCTAssertTrue(page.text.contains("123"))
    }
    func testExplicitPageIndexDoesNotReadNextPage() throws {
        let bytes = PDFFixtures.pages(["ALPHA", "BETA"])
        let document = try XCTUnwrap(PDFDocument(data: bytes))
        let firstOracle = try XCTUnwrap(document.page(at: 0)?.string)
        let secondOracle = try XCTUnwrap(document.page(at: 1)?.string)
        XCTAssertTrue(firstOracle.contains("ALPHA")); XCTAssertFalse(firstOracle.contains("BETA"))
        XCTAssertTrue(secondOracle.contains("BETA")); XCTAssertFalse(secondOracle.contains("ALPHA"))
        XCTAssertNotEqual(firstOracle, secondOracle)
        let selected = try SelectedDocumentPDFAdapter.select(bytes: bytes)
        XCTAssertEqual(selected.pageCount, 2)
        let first = try SelectedDocumentPDFAdapter.readPage(1, from: selected)
        XCTAssertEqual(first.text, firstOracle)
        XCTAssertTrue(first.text.contains("ALPHA")); XCTAssertFalse(first.text.contains("BETA"))
        let second = try SelectedDocumentPDFAdapter.readPage(2, from: selected)
        XCTAssertEqual(second.text, secondOracle)
        XCTAssertFalse(second.text.contains("ALPHA"))
        XCTAssertEqual(second.pageNumber, 2); XCTAssertTrue(second.text.contains("BETA"))
        assertFailure(.invalidPage) { try SelectedDocumentPDFAdapter.readPage(0, from: selected) }
        assertFailure(.invalidPage) { try SelectedDocumentPDFAdapter.readPage(3, from: selected) }
    }
    func testImageOnlyIsNoReadableTextLayerNotBlank() throws {
        let selected = try SelectedDocumentPDFAdapter.select(bytes: PDFFixtures.imageOnly())
        XCTAssertEqual(selected.pageCount, 1)
        assertFailure(.noReadableTextLayer) { try SelectedDocumentPDFAdapter.readPage(1, from: selected) }
    }
    func testMalformedAndWholeOversizeAreDistinct() {
        assertFailure(.malformed) { try SelectedDocumentPDFAdapter.select(bytes: Data("not a PDF".utf8)) }
        var bytes = PDFFixtures.pages(["Complete PDF prefix must not make oversized input acceptable."])
        bytes.append(Data(repeating: 0, count: SelectedDocumentPDFAdapter.maximumEncodedBytes + 1 - bytes.count))
        assertFailure(.oversizedInput) { try SelectedDocumentPDFAdapter.select(bytes: bytes) }
    }
    func testOversizedPageTextIsRejectedWithoutTruncation() throws {
        let bytes = PDFFixtures.oversizedTextLayer()
        let document = try XCTUnwrap(PDFDocument(data: bytes))
        XCTAssertGreaterThan(try XCTUnwrap(document.page(at: 0)?.string).utf8.count,
                             SelectedDocumentPDFAdapter.maximumPageUTF8Bytes)
        let selected = try SelectedDocumentPDFAdapter.select(bytes: bytes)
        assertFailure(.oversizedPage) { try SelectedDocumentPDFAdapter.readPage(1, from: selected) }
    }
    func testLockedPDFDoesNotTryPasswords() throws {
        let bytes = try PDFFixtures.encrypted(userPassword: "fixture-user", permissions: .allowsContentAccessibility)
        XCTAssertTrue(try XCTUnwrap(PDFDocument(data: bytes)).isLocked)
        assertFailure(.locked) { try SelectedDocumentPDFAdapter.select(bytes: bytes) }
    }
    func testAccessibilityPermissionNotCopyPermission() throws {
        let accessible = try PDFFixtures.encrypted(userPassword: "", permissions: .allowsContentAccessibility)
        let accessibleDocument = try XCTUnwrap(PDFDocument(data: accessible))
        XCTAssertFalse(accessibleDocument.isLocked)
        XCTAssertTrue(accessibleDocument.allowsContentAccessibility)
        XCTAssertFalse(accessibleDocument.allowsCopying)
        let selected = try SelectedDocumentPDFAdapter.select(bytes: accessible)
        XCTAssertFalse(try SelectedDocumentPDFAdapter.readPage(1, from: selected).text.isEmpty)

        // Preserve coverage of the writer's copying-only request without
        // assuming the resulting PDF denies accessibility. The native flag is
        // the oracle; selection must agree with that flag in either case.
        let copyingOnly = try PDFFixtures.encrypted(userPassword: "", permissions: .allowsContentCopying)
        let copyingDocument = try XCTUnwrap(PDFDocument(data: copyingOnly))
        XCTAssertTrue(copyingDocument.isEncrypted)
        XCTAssertFalse(copyingDocument.isLocked)
        XCTAssertTrue(copyingDocument.allowsCopying)
        if copyingDocument.allowsContentAccessibility {
            let copyingSelection = try SelectedDocumentPDFAdapter.select(bytes: copyingOnly)
            XCTAssertEqual(try SelectedDocumentPDFAdapter.readPage(1, from: copyingSelection).text,
                           try XCTUnwrap(copyingDocument.page(at: 0)?.string))
        } else {
            assertFailure(.accessibilityPermissionDenied) {
                try SelectedDocumentPDFAdapter.select(bytes: copyingOnly)
            }
        }

        // Copy permission alone did not produce an accessibility-denied PDF on
        // the tested SDK. Assert the ACTUAL native denial, never infer it.
        let denied = try PDFFixtures.encrypted(userPassword: "", rawPermissions: 0)
        let deniedDocument = try XCTUnwrap(PDFDocument(data: denied))
        XCTAssertTrue(deniedDocument.isEncrypted)
        XCTAssertFalse(deniedDocument.isLocked)
        XCTAssertFalse(deniedDocument.allowsCopying)
        XCTAssertFalse(deniedDocument.allowsContentAccessibility)
        assertFailure(.accessibilityPermissionDenied) { try SelectedDocumentPDFAdapter.select(bytes: denied) }
    }
    func testColumnsAndTableRemainLiteralTextNotAssociatedMeaning() throws {
        let bytes = PDFFixtures.columns()
        let page = try SelectedDocumentPDFAdapter.readPage(1, from: SelectedDocumentPDFAdapter.select(bytes: bytes))
        XCTAssertEqual(page.text, try XCTUnwrap(PDFDocument(data: bytes)?.page(at: 0)?.string))
        for token in ["Left", "Right", "Item", "Value", "ALPHA", "BETA"] { XCTAssertTrue(page.text.contains(token)) }
        // No assertion that PDFKit recovered row/column associations or diagrams.
    }
    func testSourceReplacementDoesNotMutateSelectedImmutableBytes() throws {
        var original = PDFFixtures.pages(["ALPHA"])
        let originalBytes = original
        let oracle = try XCTUnwrap(PDFDocument(data: original)?.page(at: 0)?.string)
        XCTAssertTrue(oracle.contains("ALPHA")); XCTAssertFalse(oracle.contains("BETA"))
        let selected = try SelectedDocumentPDFAdapter.select(bytes: original)
        original = PDFFixtures.pages(["BETA"])
        let replacement = try SelectedDocumentPDFAdapter.select(bytes: original)
        XCTAssertNotEqual(selected.sha256, replacement.sha256)
        XCTAssertEqual(selected.bytes, originalBytes)
        XCTAssertEqual(selected.sha256, SHA256.hash(data: originalBytes).map { String(format: "%02x", $0) }.joined())
        XCTAssertEqual(try SelectedDocumentPDFAdapter.readPage(1, from: selected).text, oracle)
        let replacementOracle = try XCTUnwrap(PDFDocument(data: original)?.page(at: 0)?.string)
        XCTAssertTrue(replacementOracle.contains("BETA")); XCTAssertFalse(replacementOracle.contains("ALPHA"))
        XCTAssertEqual(try SelectedDocumentPDFAdapter.readPage(1, from: replacement).text, replacementOracle)
        XCTAssertTrue(try SelectedDocumentPDFAdapter.readPage(1, from: selected).text.contains("ALPHA"))
        XCTAssertFalse(try SelectedDocumentPDFAdapter.readPage(1, from: selected).text.contains("BETA"))
    }
    func testNSMutableDataAliasCannotMutateFrozenPDFBytesHashOrText() throws {
        let bytes = PDFFixtures.pages(["ALPHA"])
        let mutable = NSMutableData(data: bytes)
        let alias = Data(referencing: mutable)
        let selected = try SelectedDocumentPDFAdapter.select(bytes: alias)
        let originalHash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let originalText = try SelectedDocumentPDFAdapter.readPage(1, from: selected).text
        let oracle = try XCTUnwrap(PDFDocument(data: bytes)?.page(at: 0)?.string)
        XCTAssertTrue(oracle.contains("ALPHA"))
        XCTAssertEqual(originalText, oracle)
        // Alter the external backing object AFTER selection. Foundation may also
        // protect some bridges, but the adapter must own its explicit snapshot.
        mutable.mutableBytes.initializeMemory(as: UInt8.self, repeating: 0, count: mutable.length)
        XCTAssertNotEqual(Data(referencing: mutable), bytes)
        XCTAssertEqual(selected.bytes, bytes)
        XCTAssertEqual(selected.sha256, originalHash)
        XCTAssertEqual(try SelectedDocumentPDFAdapter.readPage(1, from: selected).text, originalText)
        XCTAssertTrue(originalText.contains("ALPHA"))
    }
    func testNonFileSelectionCannotBecomeNetworkAcquisition() {
        assertFailure(.filePermissionDenied) {
            try SelectedDocumentPDFAdapter.loadSelectedURL(URL(string: "https://example.invalid/private.pdf")!)
        }
    }
    func testPickerSuccessThenLateCancelResolvesOnceWithOriginalOwner() {
        let owner = UUID(), url = URL(fileURLWithPath: "/fixture-only/not-read.pdf")
        var picked = 0, cancelled = 0
        let delegate = SelectedDocumentPicker.Coordinator(ownerID: owner, onPicked: { id, result in
            XCTAssertEqual(id, owner); XCTAssertEqual(result, url); picked += 1
        }, onCancelled: { _ in cancelled += 1 })
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: false)
        delegate.documentPicker(picker, didPickDocumentsAt: [url])
        delegate.documentPickerWasCancelled(picker)
        delegate.documentPicker(picker, didPickDocumentsAt: [url])
        XCTAssertEqual(picked, 1); XCTAssertEqual(cancelled, 0)
    }
    func testPickerCancelThenLateSuccessCannotReviveOwner() {
        let owner = UUID(); var picked = 0, cancelled = 0
        let delegate = SelectedDocumentPicker.Coordinator(ownerID: owner, onPicked: { _, _ in picked += 1 },
            onCancelled: { id in XCTAssertEqual(id, owner); cancelled += 1 })
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: false)
        delegate.documentPickerWasCancelled(picker)
        delegate.documentPicker(picker, didPickDocumentsAt: [URL(fileURLWithPath: "/fixture-only/not-read.pdf")])
        XCTAssertEqual(cancelled, 1); XCTAssertEqual(picked, 0)
    }
    private func assertFailure<T>(_ expected: SelectedDocumentPDFAdapter.Failure,
                                  file: StaticString = #filePath, line: UInt = #line,
                                  _ action: () throws -> T) {
        XCTAssertThrowsError(try action(), file: file, line: line) { error in
            XCTAssertEqual(error as? SelectedDocumentPDFAdapter.Failure, expected, file: file, line: line)
        }
    }
}

/// Plain helper, never construct an XCTestCase as a fixture. All source text is
/// authored test content; PDFs are generated in memory and never written out.
@MainActor
private enum PDFFixtures {
    static let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    static func pages(_ texts: [String]) -> Data {
        UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for text in texts {
                context.beginPage()
                (text as NSString).draw(in: CGRect(x: 30, y: 30, width: 550, height: 730),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            }
        }
    }
    static func imageOnly() -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor.yellow.setFill(); context.fill(CGRect(x: 20, y: 20, width: 30, height: 30))
        }
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage(); image.draw(in: CGRect(x: 50, y: 50, width: 100, height: 100))
        }
    }
    static func columns() -> Data {
        UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            for (text, x, y) in [("Left column", 30.0, 30.0), ("Right column", 320.0, 30.0),
                                 ("Item", 30.0, 80.0), ("Value", 320.0, 80.0),
                                 ("ALPHA", 30.0, 120.0), ("BETA", 320.0, 120.0)] {
                (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            }
        }
    }
    static func encrypted(userPassword: String, permissions: PDFAccessPermissions) throws -> Data {
        try encrypted(userPassword: userPassword, rawPermissions: permissions.rawValue)
    }
    // PDFAccessPermissions is an imported enum, not an OptionSet. Zero is the
    // numeric no-permissions value written to the same PDFKit options entry.
    static func encrypted(userPassword: String, rawPermissions: UInt) throws -> Data {
        let document = try XCTUnwrap(PDFDocument(data: pages(["Permission fixture only."])))
        return try XCTUnwrap(document.dataRepresentation(options: [
            PDFDocumentWriteOption.ownerPasswordOption: "fixture-owner",
            PDFDocumentWriteOption.userPasswordOption: userPassword,
            PDFDocumentWriteOption.accessPermissionsOption: rawPermissions
        ]))
    }
    static func oversizedTextLayer() -> Data {
        // A valid tall page with 900 nonoverlapping, wholly in-bounds rows.
        // 100 ASCII characters at 8pt fit within 800pt, starting at x=30.
        // Baselines range 9970...980, at 10pt spacing; page is 1000x10000pt.
        // The native extraction precondition above must exceed 64KiB.
        let row = String(repeating: "fixture ", count: 12) + "text"
        precondition(row.utf8.count == 100)
        let stream = (0..<900).map { index in
            "BT /F1 8 Tf 1 0 0 1 30 \(9970 - index * 10) Tm (\(row)) Tj ET"
        }.joined(separator: "\n")
        let objects = ["<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 1000 10000] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
            "<< /Length \(stream.utf8.count) >>\nstream\n\(stream)\nendstream"]
        var pdf = "%PDF-1.4\n", offsets: [Int] = [0]
        for (index, object) in objects.enumerated() {
            offsets.append(pdf.utf8.count); pdf += "\(index + 1) 0 obj\n\(object)\nendobj\n"
        }
        let start = pdf.utf8.count
        pdf += "xref\n0 6\n0000000000 65535 f \n"
        for offset in offsets.dropFirst() { pdf += String(format: "%010d 00000 n \n", offset) }
        pdf += "trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n\(start)\n%%EOF\n"
        return Data(pdf.utf8)
    }
}
