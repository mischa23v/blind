import Foundation
import Vision
import CoreML
import ImageIO
import BlindCore

struct VisualDescription {
    var observations: [SceneObservation]
    /// Detector evidence used to ground model descriptions (VisualGrounding).
    var grounding: VisualGrounding.Frame
}
enum VisionService {
    // Load once per process; each inference receives its own request. No model download
    // occurs at runtime. An incompatible raw-tensor model is explicitly unavailable.
    private static let detectorResourcePresent = Bundle.main.url(forResource: "Detector", withExtension: "mlmodelc") != nil
    private static let detectorModel: Result<VNCoreMLModel, Error> = Result {
        guard let url = Bundle.main.url(forResource: "Detector", withExtension: "mlmodelc") else {
            throw NSError(domain: "BlindAssist.Detector", code: 1)
        }
        return try VNCoreMLModel(for: MLModel(contentsOf: url))
    }
    private static let detectorStatusLock = NSLock()
    private static var detectorOutputRejected = false
    private static func rejectDetectorOutput() {
        detectorStatusLock.lock(); defer { detectorStatusLock.unlock() }
        detectorOutputRejected = true
    }
    private static func detectorRequest() throws -> VNCoreMLRequest {
        do {
            let request = VNCoreMLRequest(model: try detectorModel.get())
            request.imageCropAndScaleOption = .scaleFit
            return request
        } catch { rejectDetectorOutput(); throw error }
    }
    private static func recognizedObjects(_ request: VNCoreMLRequest) -> [VNRecognizedObjectObservation] {
        guard let results = request.results else { return [] }
        guard let objects = results as? [VNRecognizedObjectObservation] else {
            rejectDetectorOutput(); return []
        }
        return objects
    }

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
        let labels = groundingLabels(classifyRequest.results ?? []) + ((try? detectObjects(image: image, orientation: orientation)) ?? [])
        return VisualDescription(observations: observations, grounding: VisualGrounding.Frame(labels: labels, people: people.count))
    }
    /// Classification labels plausible enough to support a model's object mention when they recur.
    private static func groundingLabels(_ results: [VNClassificationObservation]) -> [String] {
        results.filter { $0.confidence >= 0.3 }.prefix(20).map(\.identifier)
    }
    /// Lighter pass for the extra frames: classification, people and the optional detector, no text.
    static func groundingFrame(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> VisualGrounding.Frame {
        let peopleRequest = VNDetectHumanRectanglesRequest()
        let classifyRequest = VNClassifyImageRequest()
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([peopleRequest, classifyRequest])
        let people = (peopleRequest.results ?? []).filter { $0.confidence >= 0.6 }.count
        let labels = groundingLabels(classifyRequest.results ?? []) + ((try? detectObjects(image: image, orientation: orientation)) ?? [])
        return VisualGrounding.Frame(labels: labels, people: people)
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
        guard objectDetectorAvailable else { return nil }
        let request = try detectorRequest()
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([request])
        for object in recognizedObjects(request) where object.confidence > 0.6 {
            if let label = object.labels.first?.identifier, LocateCommand.matches(target: target, label: label) {
                let point = centre(object.boundingBox); return (label, point.0, point.1)
            }
        }
        return nil
    }
    // MARK: Reading tools (Seeing AI-style, 2026-10-22). Vision boxes are normalised with the origin
    // at the bottom left of the upright image; these return top-left coordinates.

    /// Recognised text lines with their centres, for live reading or a whole page.
    static func textLines(image: CVPixelBuffer, orientation: CGImagePropertyOrientation, arabic: Bool, accurate: Bool) throws -> [TextLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = accurate ? .accurate : .fast
        request.usesLanguageCorrection = accurate
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = (arabic ? ["ar-SA", "ar", "en-US"] : ["en-US"]).filter { supported.contains($0) }
        if request.recognitionLanguages.isEmpty { request.recognitionLanguages = ["en-US"] }
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([request])
        return (request.results ?? []).compactMap { box in
            guard let best = box.topCandidates(1).first else { return nil }
            return TextLine(text: best.string, confidence: Double(best.confidence),
                            x: Double(box.boundingBox.midX), y: 1 - Double(box.boundingBox.midY))
        }
    }

    /// The page's four corners, if Vision finds a document.
    static func documentCorners(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [(x: Double, y: Double)]? {
        let request = VNDetectDocumentSegmentationRequest()
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([request])
        guard let page = request.results?.first, page.confidence >= 0.5 else { return nil }
        return [page.topLeft, page.topRight, page.bottomRight, page.bottomLeft].map { (x: Double($0.x), y: 1 - Double($0.y)) }
    }

    /// Cheap, bounded proposal only. A rectangle is NOT evidence of currency or value.
    /// Caller may send the full uncropped frame to the separately gated reference verifier.
    static func currencyRectangleCandidate(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> Bool {
        try Task.checkCancellation()
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 4
        request.minimumConfidence = 0.6
        request.minimumSize = 0.12
        request.minimumAspectRatio = 0.25
        request.maximumAspectRatio = 0.9
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([request])
        try Task.checkCancellation()
        return request.results?.count == 1
    }

    /// The first decoded barcode or QR code in view.
    static func code(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> (payload: String, isQR: Bool)? {
        let request = VNDetectBarcodesRequest()
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([request])
        guard let found = (request.results ?? []).first(where: { !($0.payloadStringValue ?? "").isEmpty }),
              let payload = found.payloadStringValue else { return nil }
        return (payload, found.symbology == .qr)
    }

    /// Detected regions for exploring a picture by touch: text, people, a page and detector objects.
    /// Only what Vision found is listed; nothing is guessed.
    static func exploreRegions(image: CVPixelBuffer, orientation: CGImagePropertyOrientation, arabic: Bool) throws -> [(label: String, rect: CGRect)] {
        try exploreRegions(handler: { VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation) }, arabic: arabic)
    }
    /// Same for a photo chosen from the library (kept in memory only).
    static func exploreRegions(photo: CGImage, orientation: CGImagePropertyOrientation, arabic: Bool) throws -> [(label: String, rect: CGRect)] {
        try exploreRegions(handler: { VNImageRequestHandler(cgImage: photo, orientation: orientation) }, arabic: arabic)
    }
    private static func exploreRegions(handler makeHandler: () -> VNImageRequestHandler, arabic: Bool) throws -> [(label: String, rect: CGRect)] {
        let text = VNRecognizeTextRequest(); text.recognitionLevel = .accurate
        let people = VNDetectHumanRectanglesRequest()
        let page = VNDetectDocumentSegmentationRequest()
        try makeHandler().perform([text, people, page])
        let flip = { (box: CGRect) in CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height) }
        var regions: [(label: String, rect: CGRect)] = []
        for box in text.results ?? [] {
            if let line = box.topCandidates(1).first, line.confidence >= 0.5 {
                regions.append(((arabic ? "نص: " : "Text: ") + line.string, flip(box.boundingBox)))
            }
        }
        for person in (people.results ?? []) where person.confidence >= 0.6 {
            regions.append((arabic ? "شخص" : "Person", flip(person.boundingBox)))
        }
        if let document = page.results?.first, document.confidence >= 0.5 {
            regions.append((arabic ? "صفحة" : "Page", flip(document.boundingBox)))
        }
        if objectDetectorAvailable {
            let request = try detectorRequest()
            try makeHandler().perform([request])
            for object in recognizedObjects(request) where object.confidence > 0.6 {
                if let label = object.labels.first?.identifier { regions.append((label, flip(object.boundingBox))) }
            }
        }
        return regions
    }
    /// Whole-picture categories Vision is fairly sure of, for a hedged overview of a library photo.
    static func photoCategories(photo: CGImage, orientation: CGImagePropertyOrientation) throws -> [String] {
        let request = VNClassifyImageRequest()
        try VNImageRequestHandler(cgImage: photo, orientation: orientation).perform([request])
        return (request.results ?? []).filter { $0.confidence >= 0.5 }.prefix(5).map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
    }

    /// Localized categories only. Whole-image classification is deliberately excluded:
    /// it cannot establish which pixels belong to a remembered object.
    struct ObjectCandidate {
        let label: String
        let confidence: Double
        let box: CGRect // upright, top-left normalized coordinates
    }
    static var objectDetectorAvailable: Bool {
        detectorStatusLock.lock(); defer { detectorStatusLock.unlock() }
        guard !detectorOutputRejected else { return false }
        return detectorResourcePresent
    }
    static func objectCandidates(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [ObjectCandidate] {
        guard objectDetectorAvailable else { return [] }
        let request = try detectorRequest()
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([request])
        return recognizedObjects(request).filter { $0.confidence >= 0.7 }
            .prefix(16).compactMap { object in
                guard let label = object.labels.first, label.confidence >= 0.7 else { return nil }
                let box = object.boundingBox
                return ObjectCandidate(label: label.identifier, confidence: Double(min(object.confidence, label.confidence)),
                    box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
            }
    }

    /// Accept any compatible object-detection model supplied as Detector.mlmodelc.
    /// Built-in human detection/classification work without a downloaded model.
    static func detectObjects(image: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [String] {
        guard objectDetectorAvailable else { return [] }
        let request = try detectorRequest()
        try VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation).perform([request])
        return recognizedObjects(request)
            .filter { $0.confidence > 0.6 }.compactMap { $0.labels.first?.identifier }
    }
}
