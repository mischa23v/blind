import Foundation
import Vision
import CoreImage
import CoreVideo
import ImageIO
import BlindCore

/// Offline appearance sampling of one isolated foreground instance, not an entire outfit.
/// Caller owns request/session/freshness/hazard cancellation and attention-gated speech.
/// Neither this adapter nor its centre-independent mask selection resolves the user's "this".
actor ClothingColorReader {
    private let context = CIContext(options: [.cacheIntermediates: false])
    enum Failure: Error { case image, mask, target }
    enum Inspection: Sendable {
        /// The anonymous bounds apply only to this captured upright image. They are not
        /// identity, proof that an item is held, or physical direction/handling authority.
        case anonymousAppearance(ClothingColor.Result, bounds: ClothingColorTarget.Region)
        case unresolved(ClothingColorTarget.Unresolved)
    }

    /// Compatibility facade. A result still means only anonymous sampled-area appearance.
    /// New contextual callers use inspect() to retain the explicit authority/ambiguity type.
    func read(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> ClothingColor.Result {
        switch try inspect(image: image, orientation: orientation) {
        case .anonymousAppearance(let result, _): return result
        case .unresolved: throw Failure.target
        }
    }

    func inspect(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> Inspection {
        try Task.checkCancellation()
        // Normalize orientation and colour space before BOTH segmentation and pixel sampling.
        let oriented = CIImage(cvPixelBuffer: image).oriented(orientation)
        guard oriented.extent.width > 0, oriented.extent.height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { throw Failure.image }
        let scale = 256.0 / max(oriented.extent.width, oriented.extent.height)
        let width = max(1, Int((oriented.extent.width * scale).rounded())), height = max(1, Int((oriented.extent.height * scale).rounded()))
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
            &buffer) == kCVReturnSuccess, let buffer else { throw Failure.image }
        let normalized = oriented.transformed(by: CGAffineTransform(translationX: -oriented.extent.minX, y: -oriented.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: CGFloat(width)/oriented.extent.width, y: CGFloat(height)/oriented.extent.height))
        context.render(normalized, to: buffer, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: space)
        try Task.checkCancellation()
        let masks = VNGenerateForegroundInstanceMaskRequest()
        let people = VNDetectHumanRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        try handler.perform([masks, people])
        try Task.checkCancellation()
        guard let observation = masks.results?.first else { throw Failure.mask }
        let mask = observation.instanceMask
        guard CVPixelBufferGetPixelFormatType(mask) == kCVPixelFormatType_OneComponent8,
              CVPixelBufferLockBaseAddress(mask, .readOnly) == kCVReturnSuccess else { throw Failure.mask }
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let maskBase = CVPixelBufferGetBaseAddress(mask) else { throw Failure.mask }
        let mw = CVPixelBufferGetWidth(mask), mh = CVPixelBufferGetHeight(mask), ms = CVPixelBufferGetBytesPerRow(mask)
        guard (9...1024).contains(mw), (9...1024).contains(mh), (mw...4096).contains(ms) else { throw Failure.mask }
        let labels = Array(UnsafeBufferPointer(start: maskBase.assumingMemoryBound(to: UInt8.self), count: ms * mh))
        let personRegions = (people.results ?? []).filter { $0.confidence >= 0.5 }.map { person in
            let box = person.boundingBox
            return ClothingColorTarget.Region(x: Double(box.minX), y: Double(1 - box.maxY),
                width: Double(box.width), height: Double(box.height))
        }
        let decision = ClothingColorTarget.select(labels: labels, maskWidth: mw, maskHeight: mh, bytesPerRow: ms,
            validInstances: Set(observation.allInstances), imageWidth: width, imageHeight: height, people: personRegions)
        guard case .anonymous(let selection) = decision else {
            if case .unresolved(let reason) = decision { return .unresolved(reason) }
            throw Failure.target
        }
        try Task.checkCancellation()
        guard CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { throw Failure.image }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw Failure.image }
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let samples = selection.samplePixels.map { sample -> ClothingColor.RGB in
            let p = base.advanced(by: sample.y * stride + sample.x * 4).assumingMemoryBound(to: UInt8.self)
            return .init(Double(p[2])/255, Double(p[1])/255, Double(p[0])/255)
        }
        try Task.checkCancellation()
        return .anonymousAppearance(ClothingColor.evaluate(samples), bounds: selection.bounds)
    }
}
