import Vision
import CoreML
import ImageIO
import BlindCore

struct VisualDescription {
    var observations: [SceneObservation]
}
enum VisionService {
    static func inspect(image: CVPixelBuffer, orientation: CGImagePropertyOrientation, arabic: Bool, capturedAt: Double) throws -> VisualDescription {
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        let supported = try textRequest.supportedRecognitionLanguages()
        textRequest.recognitionLanguages = (arabic ? ["ar-SA", "ar", "en-US"] : ["en-US"]).filter { supported.contains($0) }
        if textRequest.recognitionLanguages.isEmpty { textRequest.recognitionLanguages = ["en-US"] }
        let peopleRequest = VNDetectHumanRectanglesRequest()
        let classifyRequest = VNClassifyImageRequest()
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([textRequest, peopleRequest, classifyRequest])
        var observations = (textRequest.results ?? []).enumerated().compactMap { index, box -> SceneObservation? in
            guard let text = box.topCandidates(1).first else { return nil }
            return SceneObservation(id: "text-\(index)", kind: .text, text: text.string,
                                    confidence: Double(text.confidence), capturedAt: capturedAt)
        }
        let people = (peopleRequest.results ?? []).filter { $0.confidence >= 0.6 }
        if !people.isEmpty {
            observations.append(SceneObservation(id: "people", kind: .people, text: String(people.count),
                confidence: Double(people.map(\.confidence).min() ?? 0), capturedAt: capturedAt))
        }
        observations += (classifyRequest.results ?? []).prefix(6).enumerated().map { index, result in
            SceneObservation(id: "category-\(index)", kind: .object, text: result.identifier,
                             confidence: Double(result.confidence), capturedAt: capturedAt)
        }
        return VisualDescription(observations: observations)
    }
    /// Accept any compatible object-detection model supplied as Detector.mlmodelc.
    /// Built-in human detection/classification work without a downloaded model.
    static func detectObjects(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [String] {
        guard let url = Bundle.main.url(forResource: "Detector", withExtension: "mlmodelc") else { return [] }
        let model = try VNCoreMLModel(for: MLModel(contentsOf: url))
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFit
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([request])
        return (request.results as? [VNRecognizedObjectObservation] ?? [])
            .filter { $0.confidence > 0.6 }.compactMap { $0.labels.first?.identifier }
    }
}
