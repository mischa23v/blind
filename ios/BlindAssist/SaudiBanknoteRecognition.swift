import Foundation
import CoreML
import Vision
import CoreImage
import CryptoKit
import ImageIO
import BlindCore

/// A reviewed, immutable build profile, not configuration downloaded from a service.
/// Detector exports must expose all eight denomination scores. Classifier exports require
/// all eight scores plus an explicitly trained unknown class and rectangle proposals.
/// Neither a class confidence nor a rectangle proves single-note scene coverage.
struct SaudiBanknoteModelProfile: Sendable {
    enum Architecture: Sendable { case detector, rectangleClassifier }
    let architecture: Architecture
    let resource: String
    let sha256: String
    let modelIdentifier: String
    let evaluationIdentifier: String
    let thresholds: SaudiBanknotePolicy.Thresholds

    // Deliberately unavailable. No licensed, tested Saudi detector has been selected.
    // Do not fill this with arbitrary thresholds or mislabel BankNote-Net as SAR-trained.
    static let selected: SaudiBanknoteModelProfile? = nil
}

/// Apple Vision/Core ML adapter only; no custom recognizer, network, OCR value inference,
/// photograph persistence, transaction totals or authenticity inference.
actor SaudiBanknoteRecognition {
    enum Failure: Error { case unavailable, incompatible }
    private var loaded: VNCoreMLModel?
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let profile: SaudiBanknoteModelProfile?
    init(profile: SaudiBanknoteModelProfile? = SaudiBanknoteModelProfile.selected) { self.profile = profile }

    private func model() throws -> VNCoreMLModel {
        if let loaded { return loaded }
        guard let profile, !profile.modelIdentifier.isEmpty, !profile.evaluationIdentifier.isEmpty,
              profile.sha256.count == 64,
              let source = Bundle.main.url(forResource: profile.resource, withExtension: "mlmodel"),
              try SHA256.hash(data: Data(contentsOf: source, options: .mappedIfSafe))
                .map({ String(format: "%02x", $0) }).joined() == profile.sha256
        else { throw Failure.unavailable }
        let compiled = try MLModel.compileModel(at: source)
        // Keep the compiled temporary asset alive: Core ML may lazily read its resources.
        let config = MLModelConfiguration()
        config.computeUnits = .all
        let result = try VNCoreMLModel(for: MLModel(contentsOf: compiled, configuration: config))
        loaded = result
        return result
    }

    func inspect(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> SaudiBanknotePolicy.Result {
        try Task.checkCancellation()
        guard let profile else { throw Failure.unavailable }
        if profile.architecture == .rectangleClassifier {
            return try classifyRectangle(image: image, orientation: orientation, profile: profile)
        }
        let request = VNCoreMLRequest(model: try model())
        // Full view is retained. Centre-cropping could conceal a second banknote.
        request.imageCropAndScaleOption = .scaleFit
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([request])
        try Task.checkCancellation()
        guard let objects = request.results as? [VNRecognizedObjectObservation], objects.count <= 32 else { throw Failure.incompatible }
        var detections: [SaudiBanknotePolicy.Detection] = []
        for object in objects {
            var scores: [Int: Double] = [:]
            // Exact labels only: "100" can never parse as "1". Unknown labels veto.
            for label in object.labels {
                guard let value = Int(label.identifier), String(value) == label.identifier,
                      SaudiBanknotePolicy.denominations.contains(value), scores[value] == nil else { return .unknown }
                scores[value] = Double(label.confidence)
            }
            let box = object.boundingBox
            detections.append(.init(scores: scores, x: box.minX, y: box.minY, width: box.width, height: box.height))
        }
        return SaudiBanknotePolicy.decide(detections, thresholds: profile.thresholds)
    }

    /// Rectangle detection is a framing proposal, NOT proof that a scene contains only
    /// one banknote. Nested/overlapping/folded notes and unknowns must be tested before
    /// any profile is enabled. A missing/ambiguous proposal always abstains.
    private func classifyRectangle(image: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                                   profile: SaudiBanknoteModelProfile) throws -> SaudiBanknotePolicy.Result {
        let rectangles = VNDetectRectanglesRequest()
        rectangles.maximumObservations = 32
        rectangles.minimumConfidence = 0.3
        rectangles.minimumSize = 0.05
        rectangles.minimumAspectRatio = 0.2
        rectangles.maximumAspectRatio = 1.0
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([rectangles])
        try Task.checkCancellation()
        guard let boxes = rectangles.results, !boxes.isEmpty else { return .unknown }
        guard boxes.count == 1 else { return .multiple }
        let box = boxes[0].boundingBox
        // Reject incomplete/small proposals before running the denomination classifier.
        guard box.minX > 0.02, box.minY > 0.02, box.maxX < 0.98, box.maxY < 0.98 else { return .clipped }
        guard box.width * box.height >= profile.thresholds.minimumArea else { return .tooSmall }
        let upright = CIImage(cvPixelBuffer: image).oriented(orientation)
        let extent = upright.extent
        let crop = CGRect(x: extent.minX + box.minX * extent.width, y: extent.minY + box.minY * extent.height,
                          width: box.width * extent.width, height: box.height * extent.height)
        guard let cg = context.createCGImage(upright, from: crop) else { return .unknown }
        let request = VNCoreMLRequest(model: try model())
        request.imageCropAndScaleOption = .scaleFill // VOC crop resized to 224x224 during training.
        try VNImageRequestHandler(cgImage: cg, orientation: .up).perform([request])
        try Task.checkCancellation()
        guard let labels = request.results as? [VNClassificationObservation], labels.count == 9 else { throw Failure.incompatible }
        var scores: [Int: Double] = [:]
        var unknown: Double?
        for label in labels {
            if label.identifier == "unknown" {
                guard unknown == nil else { return .unknown }
                unknown = Double(label.confidence)
            } else {
                guard let value = Int(label.identifier), String(value) == label.identifier,
                      SaudiBanknotePolicy.denominations.contains(value), scores[value] == nil else { return .unknown }
                scores[value] = Double(label.confidence)
            }
        }
        guard let unknown else { return .unknown }
        return SaudiBanknotePolicy.decide([.init(scores: scores, unknownScore: unknown,
            x: box.minX, y: box.minY, width: box.width, height: box.height)], thresholds: profile.thresholds)
    }

}
