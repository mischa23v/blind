import Foundation

public struct SceneObservation: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case text, people, object, range }
    public var id: String
    public var kind: Kind
    public var text: String
    public var confidence: Double
    public var capturedAt: Double
    public var direction: String?
    public init(id: String, kind: Kind, text: String, confidence: Double, capturedAt: Double, direction: String? = nil) {
        self.id = id; self.kind = kind; self.text = text; self.confidence = confidence
        self.capturedAt = capturedAt; self.direction = direction
    }
}


struct Context { let observations: [SceneObservation] }
func baselineRevision(_ answer: String) -> String {
 let context = Context(observations: [])
 let revision = Set(context.observations.map { "\($0.kind.rawValue):\($0.text)" }).sorted().joined(separator: "|")
 return revision.isEmpty ? answer : revision
}
let first = baselineRevision("There may be a chair.")
let second = baselineRevision("A chair might be visible.")
print("Original native revision expression; authored answer paraphrases, zero observations")
print("Expected: no automatic fresh evidence from either answer")
print("Actual: two nonempty unequal revisions: \(first != second && !first.isEmpty && !second.isEmpty)")
if first != second && !first.isEmpty && !second.isEmpty { print("REGRESSION REPRODUCED (expected failure)"); exit(1) }
