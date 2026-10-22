#if BLIND_FAMILIAR_PEOPLE
import Vision
import CoreGraphics
import Foundation
import BlindCore

/// Same documented feature-print primitives used by ItemAppearance, NOT its whole-object pipeline.
/// Input is only OpenCV's 112x112 aligned face pixels. Generic image similarity is not a biometric verifier.
/// This object lives entirely inside the existing serial FamiliarInference actor.
enum FamiliarVisionComparison {
    static let revision = VNGenerateImageFeaturePrintRequestRevision2
    static var cropContract: String { "opencv-align112-rgb-up-scaleFill-v1-" + FamiliarModelConfiguration.selected.backendKind }
    static var osVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }
    static func faceImage(alignedRGB: Data) throws -> CGImage {
        guard alignedRGB.count == 112 * 112 * 3,
              let provider = CGDataProvider(data: alignedRGB as CFData),
              let face = CGImage(width: 112, height: 112, bitsPerComponent: 8, bitsPerPixel: 24,
                  bytesPerRow: 112 * 3, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider,
                  decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw FamiliarFaceStore.StoreError.invalid }
        return face
    }
    static func captureQuality(alignedRGB: Data) throws -> Float {
        let request = VNDetectFaceCaptureQualityRequest()
        request.revision = VNDetectFaceCaptureQualityRequestRevision2
        try VNImageRequestHandler(cgImage: faceImage(alignedRGB: alignedRGB), orientation: .up).perform([request])
        guard request.results?.count == 1, let quality = request.results?.first?.faceCaptureQuality,
              quality.isFinite, (0...1).contains(quality) else { throw FamiliarFaceStore.StoreError.invalid }
        return quality
    }
    static func printFace(alignedRGB: Data) throws -> (VNFeaturePrintObservation, FamiliarVisionPrint) {
        let face = try faceImage(alignedRGB: alignedRGB)
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = revision
        request.imageCropAndScaleOption = .scaleFill
        try VNImageRequestHandler(cgImage: face, orientation: .up).perform([request])
        guard let feature = request.results?.first, feature.requestRevision == revision else {
            throw FamiliarFaceStore.StoreError.unavailable
        }
        let archive = try NSKeyedArchiver.archivedData(withRootObject: feature, requiringSecureCoding: true)
        guard archive.count < 65_536 else { throw FamiliarFaceStore.StoreError.invalid }
        return (feature, FamiliarVisionPrint(archive: archive, revision: Int(revision), cropContract: cropContract, osVersion: osVersion))
    }
    /// Missing or incompatible references abort the entire secondary comparison, not just that rival.
    static func distances(probe: VNFeaturePrintObservation, gallery: [FamiliarTemplate]) throws -> [Double] {
        try gallery.map { person in
            let distances = try person.examples.map { example -> Double in
                guard let stored = example.visionPrint, stored.revision == Int(revision),
                      stored.cropContract == cropContract, stored.osVersion == osVersion,
                      stored.archive.count < 65_536,
                      let reference = try NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: stored.archive),
                      reference.requestRevision == revision, probe.requestRevision == reference.requestRevision else {
                    throw FamiliarFaceStore.StoreError.invalid
                }
                var distance: Float = .infinity
                try probe.computeDistance(&distance, to: reference)
                guard distance.isFinite, distance >= 0 else { throw FamiliarFaceStore.StoreError.invalid }
                return Double(distance)
            }
            guard let mean = FamiliarFacePolicy.meanVisionDistance(distances) else { throw FamiliarFaceStore.StoreError.invalid }
            return mean
        }
    }
}
#endif
