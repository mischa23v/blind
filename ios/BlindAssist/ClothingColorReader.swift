import Foundation
import Vision
import CoreImage
import CoreVideo
import ImageIO
import BlindCore

/// Reconstructed from the reviewed source-writing record after workspace loss.
/// Requested-only offline sampling of an interior central patch, not an entire outfit.
/// Caller owns task/session/freshness/hazard cancellation and attention-gated speech.
actor ClothingColorReader {
    private let context = CIContext(options: [.cacheIntermediates: false])
    enum Failure: Error { case image, mask, target }

    func read(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> ClothingColor.Result {
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
        // A person mask includes skin/hair and does not isolate a shirt.
        if (people.results ?? []).contains(where: { $0.confidence >= 0.5 && $0.boundingBox.contains(CGPoint(x: 0.5, y: 0.5)) }) { throw Failure.target }
        guard let observation = masks.results?.first else { throw Failure.mask }
        let mask = observation.instanceMask
        guard CVPixelBufferGetPixelFormatType(mask) == kCVPixelFormatType_OneComponent8,
              CVPixelBufferLockBaseAddress(mask, .readOnly) == kCVReturnSuccess else { throw Failure.mask }
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let maskBase = CVPixelBufferGetBaseAddress(mask) else { throw Failure.mask }
        let mw = CVPixelBufferGetWidth(mask), mh = CVPixelBufferGetHeight(mask), ms = CVPixelBufferGetBytesPerRow(mask)
        guard mw > 8, mh > 8 else { throw Failure.mask }
        func label(_ x: Int, _ y: Int) -> Int {
            Int(maskBase.advanced(by: max(0,min(mh-1,y))*ms).assumingMemoryBound(to: UInt8.self)[max(0,min(mw-1,x))])
        }
        // Select only the centred instance. Never substitute the largest or nearest object.
        let target = label(mw/2,mh/2)
        guard target > 0, observation.allInstances.contains(target) else { throw Failure.target }
        let offsets = [-2,0,2]
        guard offsets.allSatisfy({ dx in offsets.allSatisfy { dy in label(mw/2+dx,mh/2+dy) == target } }) else { throw Failure.target }
        guard CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { throw Failure.image }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw Failure.image }
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        var samples: [ClothingColor.RGB] = []; var candidates = 0
        // Middle 40% only, with mask erosion against boundary/background mixtures.
        for y in (height*3/10)..<(height*7/10) {
            for x in (width*3/10)..<(width*7/10) {
                candidates += 1
                let mx = x*mw/width, my = y*mh/height
                guard offsets.allSatisfy({ dx in offsets.allSatisfy { dy in label(mx+dx,my+dy) == target } }) else { continue }
                let p = base.advanced(by: y*stride+x*4).assumingMemoryBound(to: UInt8.self)
                samples.append(.init(Double(p[2])/255, Double(p[1])/255, Double(p[0])/255))
            }
        }
        try Task.checkCancellation()
        guard candidates > 0, Double(samples.count)/Double(candidates) >= 0.8 else { throw Failure.target }
        return ClothingColor.evaluate(samples)
    }
}
