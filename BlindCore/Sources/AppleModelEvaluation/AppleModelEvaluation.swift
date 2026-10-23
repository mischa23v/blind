import Foundation
import BlindCore

@main struct AppleModelEvaluation {
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else {
            print("Usage: AppleModelEvaluation report.json output.json"); exit(2)
        }
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        guard let report = raw as? [String: Any], let cases = report["cases"] as? [[String: Any]] else { exit(2) }
        var results: [[String: Any]] = []
        for item in cases {
            guard item["hazard"] as? String == "observing", let id = item["id"] as? String,
                  let instructions = item["modelInstructions"] as? String, let prompt = item["modelInput"] as? String,
                  let expected = item["expectedModelIDs"] as? [String] else { continue }
            let start = Date()
            let result = await OnDeviceLanguage.select(instructions: instructions, prompt: prompt, maximumIDs: 3, arabic: item["language"] as? String == "ar")
            results.append(["id": id, "language": item["language"] ?? "en", "modelUsed": result.modelUsed,
                "status": result.status, "ids": result.ids, "expectedIDs": expected,
                "exactMatch": result.status == "completed" && Set(result.ids) == Set(expected),
                "latencyMS": Int(Date().timeIntervalSince(start) * 1000)])
        }
        let output: [String: Any] = ["provider": "Apple on-device Foundation Models", "cloudRequests": 0,
            "available": OnDeviceLanguage.available, "supportsArabic": OnDeviceLanguage.supports(arabic: true),
            "supportsEnglish": OnDeviceLanguage.supports(arabic: false), "results": results]
        try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        print("Apple evaluation saved. Model availability: \(OnDeviceLanguage.available). Inspect results; unavailable is not a pass.")
        if !OnDeviceLanguage.available || results.contains(where: { $0["exactMatch"] as? Bool != true }) { exit(1) }
    }
}
