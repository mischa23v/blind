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
        let selected = try SelectedDocumentPDFAdapter.select(bytes: PDFFixtures.pages(["FIRST_SENTINEL", "SECOND_SENTINEL"]))
        XCTAssertEqual(selected.pageCount, 2)
        let first = try SelectedDocumentPDFAdapter.readPage(1, from: selected)
        XCTAssertTrue(first.text.contains("FIRST_SENTINEL")); XCTAssertFalse(first.text.contains("SECOND_SENTINEL"))
        let second = try SelectedDocumentPDFAdapter.readPage(2, from: selected)
        XCTAssertEqual(second.pageNumber, 2); XCTAssertTrue(second.text.contains("SECOND_SENTINEL"))
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

        let copyingOnly = try PDFFixtures.encrypted(userPassword: "", permissions: .allowsContentCopying)
        let copyingDocument = try XCTUnwrap(PDFDocument(data: copyingOnly))
        XCTAssertFalse(copyingDocument.isLocked)
        XCTAssertTrue(copyingDocument.allowsCopying)
        XCTAssertFalse(copyingDocument.allowsContentAccessibility)
        assertFailure(.accessibilityPermissionDenied) { try SelectedDocumentPDFAdapter.select(bytes: copyingOnly) }
    }
    func testColumnsAndTableRemainLiteralTextNotAssociatedMeaning() throws {
        let bytes = PDFFixtures.columns()
        let page = try SelectedDocumentPDFAdapter.readPage(1, from: SelectedDocumentPDFAdapter.select(bytes: bytes))
        XCTAssertEqual(page.text, try XCTUnwrap(PDFDocument(data: bytes)?.page(at: 0)?.string))
        for token in ["Left", "Right", "Item", "Value", "ALPHA", "BETA"] { XCTAssertTrue(page.text.contains(token)) }
        // No assertion that PDFKit recovered row/column associations or diagrams.
    }
    func testSourceReplacementDoesNotMutateSelectedImmutableBytes() throws {
        var original = PDFFixtures.pages(["ORIGINAL_SOURCE"])
        let selected = try SelectedDocumentPDFAdapter.select(bytes: original)
        original = PDFFixtures.pages(["REPLACEMENT_SOURCE"])
        let replacement = try SelectedDocumentPDFAdapter.select(bytes: original)
        XCTAssertNotEqual(selected.sha256, replacement.sha256)
        XCTAssertTrue(try SelectedDocumentPDFAdapter.readPage(1, from: selected).text.contains("ORIGINAL_SOURCE"))
        XCTAssertFalse(try SelectedDocumentPDFAdapter.readPage(1, from: selected).text.contains("REPLACEMENT_SOURCE"))
    }
    func testNSMutableDataAliasCannotMutateFrozenPDFBytesHashOrText() throws {
        let bytes = PDFFixtures.pages(["MUTABLE_ALIAS_ORIGINAL"])
        let mutable = NSMutableData(data: bytes)
        let alias = Data(referencing: mutable)
        let selected = try SelectedDocumentPDFAdapter.select(bytes: alias)
        let originalHash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let originalText = try SelectedDocumentPDFAdapter.readPage(1, from: selected).text
        // Alter the external backing object AFTER selection. Foundation may also
        // protect some bridges, but the adapter must own its explicit snapshot.
        mutable.mutableBytes.initializeMemory(as: UInt8.self, repeating: 0, count: mutable.length)
        XCTAssertNotEqual(Data(referencing: mutable), bytes)
        XCTAssertEqual(selected.bytes, bytes)
        XCTAssertEqual(selected.sha256, originalHash)
        XCTAssertEqual(try SelectedDocumentPDFAdapter.readPage(1, from: selected).text, originalText)
        XCTAssertTrue(originalText.contains("MUTABLE_ALIAS_ORIGINAL"))
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
        let document = try XCTUnwrap(PDFDocument(data: pages(["Permission fixture only."])))
        return try XCTUnwrap(document.dataRepresentation(options: [
            PDFDocumentWriteOption.ownerPasswordOption: "fixture-owner",
            PDFDocumentWriteOption.userPasswordOption: userPassword,
            PDFDocumentWriteOption.accessPermissionsOption: permissions.rawValue
        ]))
    }
    static func oversizedTextLayer() -> Data {
        // A real simple PDF text stream; no layout clipping can hide excess text
        // from the extraction limit. Xref offsets are calculated from actual bytes.
        let body = String(repeating: "fixture ", count: 10_000)
        let stream = "BT /F1 10 Tf 10 10 Td (\(body)) Tj ET"
        let objects = ["<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
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
