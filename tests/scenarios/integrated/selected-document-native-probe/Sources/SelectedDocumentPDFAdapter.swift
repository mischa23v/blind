import Foundation
import PDFKit
import CryptoKit

/// Local accessibility quotation only. No URL, file name, bookmark or PDFKit
/// object survives acquisition. Neither this adapter nor its values are Codable.
enum SelectedDocumentPDFAdapter {
    static let maximumEncodedBytes = 20 * 1024 * 1024
    static let maximumPageUTF8Bytes = 64 * 1024
    static let maximumPageLabelUTF8Bytes = 128

    enum Failure: Error, Equatable, Sendable {
        case filePermissionDenied, malformed, locked, accessibilityPermissionDenied
        case oversizedInput, oversizedPage, invalidPage, noReadableTextLayer
    }
    struct Selection: Sendable {
        let bytes: Data
        let sha256: String
        let pageCount: Int
        fileprivate init(bytes: Data, sha256: String, pageCount: Int) {
            self.bytes = bytes; self.sha256 = sha256; self.pageCount = pageCount
        }
    }
    struct Page: Sendable {
        let text: String
        /// One-based physical page index, not a possibly duplicated printed label.
        let pageNumber: Int
        let pageLabel: String
        let sha256: String
    }

    /// Invoke only with the explicit system picker's URL. Native work is
    /// synchronous and noncancellable: the caller must retain its worker lease
    /// until this function actually returns, even if its owner was withdrawn.
    static func loadSelectedURL(_ url: URL) throws -> Selection {
        guard url.isFileURL, url.startAccessingSecurityScopedResource() else {
            throw Failure.filePermissionDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            result = Result { try readBoundedBytes(coordinatedURL) }
        }
        guard coordinationError == nil, let result else { throw Failure.filePermissionDenied }
        let bytes: Data
        do { bytes = try result.get() }
        catch let failure as Failure { throw failure }
        catch { throw Failure.filePermissionDenied }
        return try select(bytes: bytes)
    }

    private static func readBoundedBytes(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var bytes = Data()
        // Read at most limit + 1, including providers whose size metadata lies or
        // changes. Reject the whole input; never parse a truncated prefix.
        while true {
            let allowance = maximumEncodedBytes + 1 - bytes.count
            guard allowance > 0 else { throw Failure.oversizedInput }
            let next = try handle.read(upToCount: min(64 * 1024, allowance)) ?? Data()
            if next.isEmpty { break }
            bytes.append(next)
            guard bytes.count <= maximumEncodedBytes else { throw Failure.oversizedInput }
        }
        return bytes
    }

    /// Actual bytes are the sole extraction input, also used by native fixtures.
    /// Selection checks structure/security but does not extract any page text.
    static func select(bytes: Data) throws -> Selection {
        guard bytes.count <= maximumEncodedBytes else { throw Failure.oversizedInput }
        guard !bytes.isEmpty else { throw Failure.malformed }
        // Data can wrap externally mutable NSData storage. Value semantics alone
        // do not freeze such aliases: take one bounded owned copy before either
        // PDFKit or hashing observes it. Parse, hash and retain this exact copy.
        let frozen = bytes.withUnsafeBytes { raw in
            Data(bytes: raw.baseAddress!, count: raw.count)
        }
        let document = try accessibleDocument(frozen)
        guard document.pageCount > 0 else { throw Failure.malformed }
        guard document.pageCount <= 10_000 else { throw Failure.oversizedInput }
        return Selection(bytes: frozen, sha256: digest(frozen), pageCount: document.pageCount)
    }

    static func readPage(_ number: Int, from selection: Selection) throws -> Page {
        guard selection.bytes.count <= maximumEncodedBytes else { throw Failure.oversizedInput }
        guard number > 0, number <= selection.pageCount else { throw Failure.invalidPage }
        let document = try accessibleDocument(selection.bytes)
        guard document.pageCount == selection.pageCount,
              let page = document.page(at: number - 1) else { throw Failure.invalidPage }
        let label = page.label ?? String(number)
        guard label.utf8.count <= maximumPageLabelUTF8Bytes else { throw Failure.oversizedPage }
        // PDFKit's text layer is not OCR or visual interpretation. Empty text
        // means no readable text layer, NOT proof that the page is blank.
        guard let text = page.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure.noReadableTextLayer
        }
        guard text.utf8.count <= maximumPageUTF8Bytes else { throw Failure.oversizedPage }
        return Page(text: text, pageNumber: number, pageLabel: label, sha256: selection.sha256)
    }

    private static func accessibleDocument(_ bytes: Data) throws -> PDFDocument {
        guard !bytes.isEmpty, let document = PDFDocument(data: bytes) else { throw Failure.malformed }
        guard !document.isLocked else { throw Failure.locked }
        // Apple distinguishes accessibility extraction from Pasteboard copying.
        // Never substitute allowsCopying, unlock passwords or override permissions.
        guard document.allowsContentAccessibility else { throw Failure.accessibilityPermissionDenied }
        return document
    }
    private static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
