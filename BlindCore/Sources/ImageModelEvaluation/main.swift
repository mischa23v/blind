import Foundation
import BlindCore
#if canImport(Vision) && canImport(ImageIO)
import Vision
import ImageIO

// Run on the Mac against the recorded RGB subset. This invokes the ACTUAL Apple
// image classifier, not scripted labels. Runtime support is explicitly reported.
struct Label: Encodable { var identifier: String; var confidence: Float }
struct Result: Encodable {
    var frame: Int; var expectedStairs: Bool?; var stairScore: Float?
    var possibleStairWarning: Bool; var topLabels: [Label]
}
struct Report: Encodable {
    var supportedStairLabels: [String]; var cases: [Result]
    var limitations: [String]
}
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: ImageModelEvaluation dataset-folder output.json")
}
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let probe = VNClassifyImageRequest()
let labels = try probe.supportedIdentifiers().filter(VisualHazard.isStairIdentifier)
var results: [Result] = []
for index in [0, 14, 28, 42, 56, 70, 84, 98, 112, 126, 140, 153] {
    let request = VNClassifyImageRequest()
    try VNImageRequestHandler(url: folder.appendingPathComponent("color_\(index).png"), orientation: .up).perform([request])
    let classified = request.results ?? []
    let score = classified.filter { VisualHazard.isStairIdentifier($0.identifier) }.map(\.confidence).max()
    results.append(Result(frame: index, expectedStairs: index == 112 ? nil : true,
        stairScore: score, possibleStairWarning: (score ?? 0) >= 0.75,
        topLabels: classified.prefix(6).map { Label(identifier: $0.identifier, confidence: $0.confidence) }))
}
let report = Report(supportedStairLabels: labels, cases: results, limitations: [
    "Recorded D435i RGB, not an iPhone walking session; classification only, no localization.",
    "No matched negative set: cannot estimate false-alarm rate or general reliability.",
    "Manual visual expectations; oblique frame 112 excluded. Model scores are not calibrated safety probabilities.",
    "Empty supportedStairLabels means this built-in classifier cannot supply our required stair labels.",
    "No cloud or language model requests. All source images remain local."
])
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(report).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("Evaluated \(results.count) real RGB frames. Supported stair labels: \(labels). Inspect the report; this is not a readiness pass.")
#else
print("ImageModelEvaluation requires Apple's Vision framework on macOS. No image model was executed.")
#endif
