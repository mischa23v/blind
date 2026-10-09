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
    /// Live search for a requested target (E14). Returns the matching label and its box centre in the
    /// upright image (x left→right, y top→bottom, 0...1). Text and people use built-in Vision; other
    /// objects need a bundled detector. No guess is made when nothing matches.
    static func locate(target: String, image: CVPixelBuffer, orientation: CGImagePropertyOrientation, arabic: Bool)
        throws -> (label: String, x: Double, y: Double)? {
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .fast
        let supported = try textRequest.supportedRecognitionLanguages()
        textRequest.recognitionLanguages = (arabic ? ["ar-SA", "ar", "en-US"] : ["en-US"]).filter { supported.contains($0) }
        if textRequest.recognitionLanguages.isEmpty { textRequest.recognitionLanguages = ["en-US"] }
        let peopleRequest = VNDetectHumanRectanglesRequest()
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([textRequest, peopleRequest])
        // Vision boxes are normalised with the origin at the bottom left of the upright image.
        let centre = { (box: CGRect) in (Double(box.midX), 1 - Double(box.midY)) }
        for result in textRequest.results ?? [] {
            if let text = result.topCandidates(1).first?.string, LocateCommand.matches(target: target, label: text) {
                let point = centre(result.boundingBox); return (text, point.0, point.1)
            }
        }
        let personWords = ["person", "people", "someone", "شخص"]
        if personWords.contains(where: { LocateCommand.matches(target: target, label: $0) }),
           let person = (peopleRequest.results ?? []).filter({ $0.confidence >= 0.6 }).max(by: { $0.boundingBox.width < $1.boundingBox.width }) {
            let point = centre(person.boundingBox); return (arabic ? "شخص" : "Person", point.0, point.1)
        }
        guard let url = Bundle.main.url(forResource: "Detector", withExtension: "mlmodelc") else { return nil }
        let request = VNCoreMLRequest(model: try VNCoreMLModel(for: MLModel(contentsOf: url)))
        request.imageCropAndScaleOption = .scaleFit
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([request])
        for object in (request.results as? [VNRecognizedObjectObservation] ?? []) where object.confidence > 0.6 {
            if let label = object.labels.first?.identifier, LocateCommand.matches(target: target, label: label) {
                let point = centre(object.boundingBox); return (label, point.0, point.1)
            }
        }
        return nil
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
