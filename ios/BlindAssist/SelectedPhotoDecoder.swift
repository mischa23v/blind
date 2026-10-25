import UIKit
import ImageIO
import CryptoKit
import BlindCore

/// ImageIO header inspection precedes pixel decoding. Photos may download an
/// existing iCloud original; this app never uploads or stores selected bytes.
enum SelectedPhotoDecoder {
    struct Decoded { let image: UIImage; let sha256: String }
    static func decode(_ data: Data) -> Decoded? {
        guard !data.isEmpty, data.count <= SelectedPhotoReference.maximumEncodedBytes,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 16_384, height <= 16_384,
              width <= SelectedPhotoReference.maximumSourcePixels / height,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: SelectedPhotoReference.maximumDecodedSide,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary), image.width <= SelectedPhotoReference.maximumDecodedSide,
              image.height <= SelectedPhotoReference.maximumDecodedSide else { return nil }
        return Decoded(image: UIImage(cgImage: image), sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }
}

import CoreTransferable
import UniformTypeIdentifiers

/// Receive an ephemeral system-owned file rather than asking Photos to allocate
/// an unbounded Data representation. Read at most the byte limit plus one byte.
struct SelectedPhotoTransfer: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let values = try received.file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true, let size = values.fileSize,
                  size > 0, size <= SelectedPhotoReference.maximumEncodedBytes else { throw CocoaError(.fileReadTooLarge) }
            let handle = try FileHandle(forReadingFrom: received.file)
            defer { try? handle.close() }
            guard let data = try handle.read(upToCount: SelectedPhotoReference.maximumEncodedBytes + 1),
                  data.count == size, data.count <= SelectedPhotoReference.maximumEncodedBytes else { throw CocoaError(.fileReadTooLarge) }
            return Self(data: data)
        }
    }
}
